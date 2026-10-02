import Foundation
import KLTCore
import Observation
import UIKit

enum IOSComparisonMode: String, CaseIterable, Identifiable {
    case original = "Original"
    case sideBySide = "Side by side"
    case slider = "Slider"
    case processed = "Processed"
    var id: Self { self }
}

enum IOSMethodSelection: Equatable, Sendable {
    case calculated(WorkingSpaceSelection, String)
    case replayed(TransformRecipeSnapshot, String)
}

struct IOSResult: @unchecked Sendable {
    let generation: UUID
    let request: EnhancementExecutionRequest
    let job: UUID
    let image: EnhancedImage
    let record: AnalysisRecordSnapshot
}

/// The system document picker may stay open after a result changes. Its file
/// document checks this lease again when SwiftUI asks for the final bytes.
final class IOSExportTicket: @unchecked Sendable {
    private let lock = NSLock()
    private var valid = true

    var isValid: Bool {
        lock.lock(); defer { lock.unlock() }
        return valid
    }

    func invalidate() {
        lock.lock(); defer { lock.unlock() }
        valid = false
    }
}

struct PreparedIOSExport: Sendable {
    let data: Data
    let generation: UUID
    let request: EnhancementExecutionRequest
    let job: UUID
    let ticket: IOSExportTicket
}

@MainActor @Observable
final class IOSWorkspace {
    private(set) var source: DecodedImage?
    private(set) var sourceName = ""
    private(set) var result: IOSResult?
    private(set) var status = "Open an image to begin."
    private(set) var error: String?
    private(set) var isImporting = false
    private(set) var isProcessing = false
    private(set) var isPreparingExport = false
    private(set) var library: MethodLibrarySnapshot = .empty
    private(set) var libraryRecoveryError: String?
    private(set) var libraryMutationInProgress = false
    var comparison: IOSComparisonMode = .sideBySide
    var reveal = 0.5
    var zoom = 1.0
    var pan = CGSize.zero
    var sampleSource: AnalysisSampleSource = .wholeImage { didSet { controlsChanged() } }
    var matrixMode: AnalysisMatrixMode = .covariance { didSet { controlsChanged() } }
    var region: SourcePixelRegion? { didSet { controlsChanged() } }
    var method: IOSMethodSelection = .calculated(.standardRGB, "RGB") { didSet { controlsChanged() } }

    private let store: IOSMethodLibrary
    private var generation = UUID()
    private var importID = UUID()
    private var jobID = UUID()
    private var importTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?
    private var exportTask: Task<Data, Error>?
    private var exportID = UUID()
    private var activeExportTicket: IOSExportTicket?
    private(set) var exportRevision = UUID()
    private let imageEncoder: @Sendable (CGImage, ImageExportFormat) async throws -> Data
    private var lastCalculated: (WorkingSpaceSelection, String) = (.standardRGB, "RGB")
    private var suppressControlUpdate = false

    init(
        store: IOSMethodLibrary = IOSMethodLibrary(),
        imageEncoder: @escaping @Sendable (CGImage, ImageExportFormat) async throws -> Data = {
            try ImagePipeline.encodedData(for: $0, format: $1)
        }
    ) {
        self.store = store
        self.imageEncoder = imageEncoder
    }

    var isReplayed: Bool { if case .replayed = method { true } else { false } }
    var methodName: String {
        switch method {
        case let .calculated(_, name), let .replayed(_, name): name
        }
    }
    var currentResult: IOSResult? {
        guard let result, result.generation == generation,
              result.request == effectiveRequest,
              result.job == jobID else { return nil }
        return result
    }
    var canSaveTransform: Bool {
        guard !isReplayed, let currentResult else { return false }
        return !currentResult.image.descriptor.hasLimitedVariation && !currentResult.image.analysis.isDegenerate
    }
    var effectiveRequest: EnhancementExecutionRequest {
        switch method {
        case let .calculated(space, _):
            .calculated(CalculatedAnalysisRequest(
                workingSpace: space, matrixMode: matrixMode, sampleSource: sampleSource,
                region: sampleSource == .selectedRegion ? region : nil
            ))
        case let .replayed(recipe, _): .replayed(recipe)
        }
    }

    func loadLibrary() async {
        do { library = try await store.load() }
        catch { libraryRecoveryError = IOSLibraryError.recoveryRequired.localizedDescription }
    }

    @discardableResult
    func replaceLibrary(_ proposed: MethodLibrarySnapshot) async -> Bool {
        guard !libraryMutationInProgress else {
            error = "Finish the current library change before making another."
            return false
        }
        libraryMutationInProgress = true
        defer { libraryMutationInProgress = false }
        do {
            library = try await store.replace(proposed)
            status = "Method library saved. Current image is unchanged."
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    func chooseSpace(_ descriptor: WorkingSpaceDescriptor) {
        let selection: WorkingSpaceSelection
        switch descriptor.revision.identity.kind {
        case .standard:
            selection = descriptor.revision.base == .encodedSRGB ? .standardRGB : .standardLabD65
        case .curated, .user: selection = .affine(descriptor.revision)
        }
        lastCalculated = (selection, descriptor.libraryName)
        method = .calculated(selection, descriptor.libraryName)
    }

    func chooseSpace(_ item: UserWorkingSpaceItem) {
        lastCalculated = (.affine(item.revision), item.libraryName)
        method = .calculated(.affine(item.revision), item.libraryName)
    }

    func applyRecipe(_ item: SavedTransformItem) {
        method = .replayed(item.recipe, item.libraryName)
    }

    func calculateForThisImage() {
        method = .calculated(lastCalculated.0, lastCalculated.1)
    }

    /// A pending replacement never clears the accepted source or result.
    func importImage(_ url: URL, displayName: String? = nil, removeAfterImport: Bool = false) {
        importTask?.cancel()
        let id = UUID()
        importID = id
        isImporting = true
        error = nil
        status = "Opening the full-resolution source…"
        let name = displayName ?? url.lastPathComponent
        importTask = Task.detached(priority: .userInitiated) { [weak self] in
            let access = url.startAccessingSecurityScopedResource()
            var stagedURL: URL? = removeAfterImport ? url : nil
            defer {
                if access { url.stopAccessingSecurityScopedResource() }
                if let stagedURL { try? FileManager.default.removeItem(at: stagedURL) }
            }
            do {
                // Photos has already completed a counted stage in its provider
                // callback. Files is staged here while its security scope is open.
                if removeAfterImport {
                    try IOSImageSourceStaging.validateOwnedStage(url)
                } else {
                    stagedURL = try IOSImageSourceStaging.stage(from: url)
                }
                guard let stagedURL else { throw IOSImageStagingError.notRegularFile }
                let image = try ImagePipeline.decode(
                    at: stagedURL, maximumPixelCount: ImageProcessingLimits.maximumIOSPixelCount
                )
                try Task.checkCancellation()
                await self?.acceptImport(image, name: name, id: id)
            } catch {
                await self?.rejectImport(error, id: id)
            }
        }
    }

    private func acceptImport(_ image: DecodedImage, name: String, id: UUID) {
        guard importID == id else { return }
        invalidateExport()
        generation = UUID()
        source = image
        sourceName = name
        result = nil
        isImporting = false
        suppressControlUpdate = true
        sampleSource = .wholeImage
        region = nil
        method = .calculated(lastCalculated.0, lastCalculated.1)
        suppressControlUpdate = false
        comparison = .sideBySide
        reveal = 0.5
        zoom = 1
        pan = .zero
        status = "\(name), \(image.width) × \(image.height) pixels. Calculating locally."
        runAnalysis()
    }

    private func rejectImport(_ failure: Error, id: UUID) {
        guard importID == id else { return }
        isImporting = false
        if failure is CancellationError { status = "Image selection canceled. Current work is unchanged."; return }
        if let pipelineError = failure as? ImagePipelineError, pipelineError == .imageTooLarge {
            error = "This source exceeds the 26-million-pixel iPhone and iPad limit. Choose a smaller original. Current work is unchanged."
        } else if let stagingError = failure as? IOSImageStagingError, stagingError == .tooLarge {
            error = stagingError.localizedDescription
        } else {
            error = "The complete image could not be opened. Try again or choose another JPEG, PNG, TIFF, or HEIC source. Current work is unchanged."
        }
    }

    private func controlsChanged() {
        guard !suppressControlUpdate, source != nil else { return }
        if case let .calculated(space, name) = method { lastCalculated = (space, name) }
        runAnalysis()
    }

    func runAnalysis() {
        guard let source else { return }
        invalidateExport()
        analysisTask?.cancel()
        jobID = UUID()
        result = nil
        error = nil
        let request = effectiveRequest
        if case let .calculated(calculation) = request,
           calculation.sampleSource == .selectedRegion {
            do {
                _ = try SourcePixelRegionValidator.validate(
                    calculation.region, sourceWidth: source.width, sourceHeight: source.height
                )
            } catch {
                isProcessing = false
                self.error = error.localizedDescription
                status = "Edit the source-pixel sample to continue."
                return
            }
        }
        let id = jobID
        let sourceGeneration = generation
        let name = sourceName
        let methodName = methodName
        isProcessing = true
        status = isReplayed ? "Replaying frozen transform…" : "Calculating from the unchanged source…"
        analysisTask = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let image: EnhancedImage
                switch request {
                case let .calculated(calculation):
                    image = try ImagePipeline.enhance(source, request: calculation, workingSpaceName: methodName)
                case let .replayed(recipe):
                    image = try ImagePipeline.replay(source, recipe: recipe, recipeName: methodName)
                }
                let record = try AnalysisRecordRouter.make(
                    decodedSource: source, displayFilename: name, enhancement: image
                )
                try Task.checkCancellation()
                await self?.acceptAnalysis(image, record: record, generation: sourceGeneration, request: request, job: id)
            } catch {
                await self?.rejectAnalysis(error, generation: sourceGeneration, request: request, job: id)
            }
        }
    }

    private func acceptAnalysis(
        _ image: EnhancedImage, record: AnalysisRecordSnapshot,
        generation: UUID, request: EnhancementExecutionRequest, job: UUID
    ) {
        guard generation == self.generation,
              RequestAcceptanceGate.accepts(completedJobID: job, completedKey: request,
                                            activeJobID: jobID, currentKey: effectiveRequest) else { return }
        result = IOSResult(generation: generation, request: request, job: job, image: image, record: record)
        isProcessing = false
        status = image.notice ?? (isReplayed ? "Replayed saved transform." : "Calculated for this image.")
    }

    private func rejectAnalysis(_ failure: Error, generation: UUID, request: EnhancementExecutionRequest, job: UUID) {
        guard generation == self.generation, job == jobID, request == effectiveRequest else { return }
        isProcessing = false
        if failure is CancellationError { status = "Processing canceled. Unchanged source remains available." }
        else {
            error = failure.localizedDescription
            status = "The result could not be produced. Adjust the method or sample and try again."
        }
    }

    func cancel() {
        let wasProcessing = isProcessing
        importTask?.cancel(); analysisTask?.cancel(); invalidateExport()
        importID = UUID()
        if wasProcessing { jobID = UUID() }
        isImporting = false; isProcessing = false; isPreparingExport = false
        status = "Canceled. Current accepted work is unchanged."
    }

    func fit() { zoom = 1; pan = .zero }
    func zoomIn() { zoom = min(4, zoom * 1.25) }
    func zoomOut() { zoom = max(1, zoom / 1.25); if zoom == 1 { pan = .zero } }

    func setRegion(_ proposed: SourcePixelRegion) {
        guard let source else { return }
        do {
            _ = try SourcePixelRegionValidator.validate(
                proposed, sourceWidth: source.width, sourceHeight: source.height
            )
            error = nil
            suppressControlUpdate = true
            region = proposed
            sampleSource = .selectedRegion
            suppressControlUpdate = false
            runAnalysis()
        } catch {
            invalidateExport()
            analysisTask?.cancel()
            jobID = UUID()
            result = nil
            isProcessing = false
            self.error = error.localizedDescription
        }
    }

    func clearRegion() { region = nil; sampleSource = .wholeImage }

    func captureRecipe() throws -> TransformRecipeSnapshot {
        guard canSaveTransform, let source, let result = currentResult else {
            throw IOSWorkspaceError.noCurrentResult
        }
        return try TransformRecipeFactory.capture(
            decodedSource: source, displayFilename: sourceName, enhancement: result.image
        )
    }

    func prepareImageExport(_ format: ImageExportFormat) async throws -> Data {
        try await prepareImageFileExport(format).data
    }

    func prepareImageFileExport(_ format: ImageExportFormat) async throws -> PreparedIOSExport {
        guard let result = currentResult else { throw IOSWorkspaceError.noCurrentResult }
        let imageEncoder = self.imageEncoder
        return try await prepareFileExport(result) {
            try await imageEncoder(result.image.image, format)
        }
    }

    func prepareRecordExport() async throws -> Data {
        try await prepareRecordFileExport().data
    }

    func prepareRecordFileExport() async throws -> PreparedIOSExport {
        guard let result = currentResult else { throw IOSWorkspaceError.noCurrentResult }
        return try await prepareFileExport(result) {
            try AnalysisRecordSnapshotJSONEncoder.data(for: result.record)
        }
    }

    func isCurrent(_ prepared: PreparedIOSExport) -> Bool {
        guard let result = currentResult else { return false }
        return prepared.ticket.isValid && result.generation == prepared.generation
            && result.request == prepared.request && result.job == prepared.job
    }

    private func prepareFileExport(
        _ result: IOSResult, encode: @escaping @Sendable () async throws -> Data
    ) async throws -> PreparedIOSExport {
        invalidateExport()
        let id = exportID
        isPreparingExport = true
        let task = Task.detached(priority: .userInitiated) { try await encode() }
        exportTask = task
        defer {
            if exportID == id {
                exportTask = nil
                isPreparingExport = false
            }
        }
        let data = try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
        try Task.checkCancellation()
        guard exportID == id else { throw CancellationError() }
        let prepared = PreparedIOSExport(
            data: data, generation: result.generation, request: result.request,
            job: result.job, ticket: IOSExportTicket()
        )
        guard isCurrent(prepared) else { throw IOSWorkspaceError.staleResult }
        activeExportTicket = prepared.ticket
        return prepared
    }

    private func invalidateExport() {
        exportTask?.cancel()
        exportTask = nil
        exportID = UUID()
        activeExportTicket?.invalidate()
        activeExportTicket = nil
        isPreparingExport = false
        exportRevision = UUID()
    }

    func presentError(_ message: String) { error = message }
    func dismissError() { error = nil }
}

enum IOSWorkspaceError: LocalizedError {
    case noCurrentResult, staleResult
    var errorDescription: String? {
        switch self {
        case .noCurrentResult: "A current result is required for this action."
        case .staleResult: "The method or source changed. Make a new result before exporting."
        }
    }
}
