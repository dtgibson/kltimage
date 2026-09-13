import AppKit
import Foundation
import KLTCore
import Observation
import UniformTypeIdentifiers

enum ComparisonMode: String, CaseIterable, Identifiable {
    case original = "Original"
    case split = "Split"
    case enhanced = "Enhanced"

    var id: Self { self }
}

enum WorkspacePhase: Equatable {
    case empty
    case importing
    case awaitingRegion(RegionValidationIssue)
    case invalidRegion(RegionValidationIssue)
    case processing
    case ready
    case exporting
    case failed(String)
}

enum ResultCurrency: Equatable {
    case none
    case current
    case previousUpdating
    case previousNotCurrent
}

struct SourceIdentity: Equatable, Hashable, Sendable {
    let generation: UUID
}

struct AnalysisRequestKey: Equatable, Hashable, Sendable {
    let source: SourceIdentity
    let input: AnalysisInput
}

struct AnalysisJobIdentity: Equatable, Sendable {
    let id: UUID
    let key: AnalysisRequestKey
}

struct CompletedEnhancement: @unchecked Sendable {
    let key: AnalysisRequestKey
    let jobID: UUID
    let value: EnhancedImage
    let record: AnalysisRecord
}

struct AnalysisRecordPresentation: Identifiable, Sendable {
    let id: UUID
    let value: AnalysisRecord
    let suggestedFilename: String
}

struct RegionEditorState: Equatable {
    var committed: SourcePixelRegion?
    var draftX = ""
    var draftY = ""
    var draftWidth = ""
    var draftHeight = ""
    var validationIssue: RegionValidationIssue?

    mutating func setDrafts(from region: SourcePixelRegion) {
        draftX = String(region.x)
        draftY = String(region.y)
        draftWidth = String(region.width)
        draftHeight = String(region.height)
    }
}

enum RegionField: Hashable, Sendable {
    case x
    case y
    case width
    case height
}

@MainActor
private final class ExportFormatAccessoryController: NSObject {
    let view: NSView
    private let picker = NSPopUpButton(frame: .zero, pullsDown: false)
    private weak var panel: NSSavePanel?
    private let sourceStem: String

    var format: ImageExportFormat {
        ImageExportFormat.allCases[picker.indexOfSelectedItem]
    }

    init(panel: NSSavePanel, sourceStem: String) {
        self.panel = panel
        self.sourceStem = sourceStem
        let label = NSTextField(labelWithString: "Format:")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        picker.addItems(withTitles: ImageExportFormat.allCases.map(\.displayName))
        picker.selectItem(at: 0)
        let stack = NSStackView(views: [label, picker])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view = stack
        super.init()
        picker.target = self
        picker.action = #selector(formatChanged)
        formatChanged()
    }

    @objc private func formatChanged() {
        panel?.allowedContentTypes = [format.uniformType]
        panel?.nameFieldStringValue = "\(sourceStem)-klt.\(format.filenameExtension)"
    }
}

@MainActor
@Observable
final class WorkspaceModel {
    private enum ExportKind {
        case image
        case analysisRecord
    }

    private(set) var source: DecodedImage?
    private(set) var completedEnhancement: CompletedEnhancement?
    private(set) var phase: WorkspacePhase = .empty
    private(set) var sourceName = ""
    private(set) var exportNotice: String?
    private(set) var exportNoticeIsError = false
    private(set) var colorSpace: AnalysisColorSpace = .rgb
    private(set) var matrixMode: AnalysisMatrixMode = .covariance
    private(set) var sampleSource: AnalysisSampleSource = .wholeImage
    private(set) var regionEditor = RegionEditorState()
    private(set) var currentRequestKey: AnalysisRequestKey?
    private(set) var activeAnalysisJob: AnalysisJobIdentity?
    private(set) var statusAnnouncement = "Open an image to begin." {
        didSet {
            NSAccessibility.post(
                element: NSApplication.shared,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: statusAnnouncement,
                    .priority: NSAccessibilityPriorityLevel.medium.rawValue
                ]
            )
        }
    }

    var comparisonMode: ComparisonMode = .split
    var zoom = 1.0
    var pan = CGSize.zero

    private var sourceIdentity: SourceIdentity?
    private var activeOperation: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var operationID = UUID()
    private var exportKind: ExportKind?

    var enhanced: EnhancedImage? { completedEnhancement?.value }

    var analysisInput: AnalysisInput {
        AnalysisInput(
            method: AnalysisMethod(colorSpace: colorSpace, matrixMode: matrixMode),
            sampleSource: sampleSource,
            region: sampleSource == .selectedRegion ? regionEditor.committed : nil
        )
    }

    var methodText: String {
        "\(colorSpace.displayName) · \(matrixMode.displayName.lowercased()) · \(sampleSource.displayName.lowercased())"
    }

    var canExport: Bool {
        currentCompletedEnhancement != nil
    }

    var currentAnalysisRecord: AnalysisRecordPresentation? {
        guard let result = currentCompletedEnhancement else { return nil }
        return AnalysisRecordPresentation(
            id: result.jobID,
            value: result.record,
            suggestedFilename: suggestedAnalysisRecordFilename
        )
    }

    var canChangePresentation: Bool { source != nil }

    var analysisControlsEnabled: Bool {
        source != nil && phase != .importing && phase != .exporting
    }

    var isBusy: Bool { phase == .importing || phase == .exporting }

    var resultCurrency: ResultCurrency {
        guard let completedEnhancement else { return .none }
        if phase == .processing { return .previousUpdating }
        guard let currentRequestKey, completedEnhancement.key == currentRequestKey else {
            return .previousNotCurrent
        }
        return phase == .ready || phase == .exporting ? .current : .previousNotCurrent
    }

    var statusLabel: String {
        switch phase {
        case .empty: "Awaiting image"
        case .importing: "Reading image"
        case .awaitingRegion: "Awaiting region"
        case .invalidRegion: "Region needs attention"
        case .processing: enhanced == nil ? "Calculating result" : "Updating result"
        case .ready: enhanced?.descriptor.hasLimitedVariation == true ? "Limited variation" : "Result ready"
        case .exporting:
            exportKind == .analysisRecord ? "Exporting record" : "Exporting full resolution"
        case .failed: "Needs attention"
        }
    }

    func presentOpenPanel() {
        guard !isBusy else { return }
        let panel = NSOpenPanel()
        panel.title = "Open an image"
        panel.prompt = "Open Image"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openImage(at: url)
    }

    func openImage(at url: URL) {
        guard phase != .importing, phase != .exporting else { return }

        invalidateActiveOperation()
        noticeTask?.cancel()
        exportNotice = nil
        exportNoticeIsError = false
        exportKind = nil
        source = nil
        sourceIdentity = nil
        completedEnhancement = nil
        currentRequestKey = nil
        activeAnalysisJob = nil
        sourceName = url.lastPathComponent
        sampleSource = .wholeImage
        regionEditor = RegionEditorState()
        comparisonMode = .split
        zoom = 1
        pan = .zero
        phase = .importing
        statusAnnouncement = "Reading \(sourceName) locally."

        let newOperationID = UUID()
        operationID = newOperationID
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                try Task.checkCancellation()
                let decoded = try ImagePipeline.decode(data)
                try Task.checkCancellation()
                await self?.acceptDecodedImage(decoded, operationID: newOperationID)
            } catch is CancellationError {
                await self?.acceptImportCancellation(operationID: newOperationID)
            } catch {
                await self?.acceptImportFailure(error, operationID: newOperationID)
            }
        }
    }

    func selectColorSpace(_ selection: AnalysisColorSpace) {
        guard analysisControlsEnabled, selection != colorSpace else { return }
        colorSpace = selection
        clearMethodDependentValidation()
        requestAnalysis()
    }

    func selectMatrixMode(_ selection: AnalysisMatrixMode) {
        guard analysisControlsEnabled, selection != matrixMode else { return }
        matrixMode = selection
        clearMethodDependentValidation()
        requestAnalysis()
    }

    func selectSampleSource(_ selection: AnalysisSampleSource) {
        guard analysisControlsEnabled, selection != sampleSource else { return }
        sampleSource = selection
        requestAnalysis()
    }

    func updateRegionDraft(_ field: RegionField, value: String) {
        switch field {
        case .x: regionEditor.draftX = value
        case .y: regionEditor.draftY = value
        case .width: regionEditor.draftWidth = value
        case .height: regionEditor.draftHeight = value
        }
    }

    func applyRegionDraft() {
        guard let source else { return }
        guard
            let x = parsedInteger(regionEditor.draftX),
            let y = parsedInteger(regionEditor.draftY),
            let width = parsedInteger(regionEditor.draftWidth),
            let height = parsedInteger(regionEditor.draftHeight)
        else {
            rejectRegion(.nonIntegerValues)
            return
        }
        let region = SourcePixelRegion(x: x, y: y, width: width, height: height)
        do {
            _ = try SourcePixelRegionValidator.validate(
                region,
                sourceWidth: source.width,
                sourceHeight: source.height
            )
            regionEditor.committed = region
            regionEditor.validationIssue = nil
            if sampleSource == .selectedRegion { requestAnalysis() }
        } catch let issue as RegionValidationIssue {
            rejectRegion(issue)
        } catch {
            rejectRegion(.nonIntegerValues)
        }
    }

    func commitPointerRegion(_ region: SourcePixelRegion) {
        guard let source, sampleSource == .selectedRegion else { return }
        regionEditor.setDrafts(from: region)
        do {
            _ = try SourcePixelRegionValidator.validate(
                region,
                sourceWidth: source.width,
                sourceHeight: source.height
            )
            regionEditor.committed = region
            regionEditor.validationIssue = nil
            requestAnalysis()
        } catch let issue as RegionValidationIssue {
            rejectRegion(issue)
        } catch {
            rejectRegion(.nonIntegerValues)
        }
    }

    func clearRegion() {
        regionEditor = RegionEditorState()
        guard sampleSource == .selectedRegion else { return }
        requestAnalysis()
    }

    func presentExportPanel() {
        guard let completedEnhancement = currentCompletedEnhancement else { return }

        let panel = NSSavePanel()
        panel.title = "Export enhanced image"
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let stem = (sourceName as NSString).deletingPathExtension
        let accessory = ExportFormatAccessoryController(panel: panel, sourceStem: stem)
        panel.accessoryView = accessory.view

        guard panel.runModal() == .OK, var url = panel.url else { return }
        let format = accessory.format
        if url.pathExtension.isEmpty { url.appendPathExtension(format.filenameExtension) }
        export(completedEnhancement, to: url, format: format)
    }

    func presentAnalysisRecordExportPanel(_ snapshot: AnalysisRecordPresentation) {
        guard analysisRecordIsCurrent(snapshot) else {
            showExportNotice(
                "The analysis record is no longer current. Wait for the matching result, then export again.",
                isError: true
            )
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export analysis record"
        panel.prompt = "Export JSON"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = snapshot.suggestedFilename

        guard panel.runModal() == .OK, var url = panel.url else { return }
        guard analysisRecordIsCurrent(snapshot) else {
            showExportNotice(
                "The analysis record changed before it could be saved. Wait for the current result, then export again.",
                isError: true
            )
            return
        }
        if url.pathExtension.isEmpty { url.appendPathExtension("klt-analysis.json") }
        exportAnalysisRecord(snapshot, to: url)
    }

    func cancelCurrentOperation() {
        let priorPhase = phase
        let priorExportKind = exportKind
        invalidateActiveOperation()
        switch priorPhase {
        case .importing:
            source = nil
            sourceIdentity = nil
            completedEnhancement = nil
            currentRequestKey = nil
            sourceName = ""
            phase = .empty
            statusAnnouncement = "Image import canceled."
        case .exporting:
            phase = .ready
            statusAnnouncement = priorExportKind == .analysisRecord
                ? "Analysis record export canceled."
                : "Image export canceled."
            exportKind = nil
        default:
            break
        }
    }

    func zoomIn() { zoom = min(8, zoom * 1.25) }
    func zoomOut() { zoom = max(0.25, zoom / 1.25) }
    func resetView() {
        zoom = 1
        pan = .zero
    }

    private func requestAnalysis() {
        guard let source, let sourceIdentity else { return }
        activeOperation?.cancel()
        activeOperation = nil
        activeAnalysisJob = nil

        let input = analysisInput
        let displayFilename = sourceName
        let key = AnalysisRequestKey(source: sourceIdentity, input: input)
        currentRequestKey = key

        if input.sampleSource == .selectedRegion {
            if input.region == nil {
                phase = .awaitingRegion(.missing)
                regionEditor.validationIssue = .missing
                statusAnnouncement = "A selected region is required. No whole-image fallback will be used."
                return
            }
            if let issue = regionEditor.validationIssue {
                if case .insufficientVariation = issue {
                    regionEditor.validationIssue = nil
                } else {
                    phase = .invalidRegion(issue)
                    return
                }
            }
            do {
                _ = try SourcePixelRegionValidator.validate(
                    input.region,
                    sourceWidth: source.width,
                    sourceHeight: source.height
                )
            } catch let issue as RegionValidationIssue {
                rejectRegion(issue)
                return
            } catch {
                rejectRegion(.nonIntegerValues)
                return
            }
        }

        let job = AnalysisJobIdentity(id: UUID(), key: key)
        activeAnalysisJob = job
        phase = .processing
        statusAnnouncement = "Calculating \(methodText) locally from the unchanged source."
        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let result = try ImagePipeline.enhance(source, input: input)
                let record = try AnalysisRecord(
                    decodedSource: source,
                    displayFilename: displayFilename,
                    enhancement: result
                )
                try Task.checkCancellation()
                await self?.acceptEnhancedImage(result, record: record, job: job)
            } catch is CancellationError {
                await self?.acceptAnalysisCancellation(job: job)
            } catch {
                await self?.acceptAnalysisFailure(error, job: job)
            }
        }
    }

    private func clearMethodDependentValidation() {
        if case .insufficientVariation = regionEditor.validationIssue {
            regionEditor.validationIssue = nil
        }
    }

    private func rejectRegion(_ issue: RegionValidationIssue) {
        activeOperation?.cancel()
        activeOperation = nil
        activeAnalysisJob = nil
        regionEditor.validationIssue = issue
        phase = issue == .missing ? .awaitingRegion(issue) : .invalidRegion(issue)
        statusAnnouncement = issue.message()
    }

    private func parsedInteger(_ value: String) -> Int? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private func export(
        _ result: CompletedEnhancement,
        to url: URL,
        format: ImageExportFormat
    ) {
        activeOperation?.cancel()
        phase = .exporting
        exportKind = .image
        exportNotice = nil
        exportNoticeIsError = false
        statusAnnouncement = "Exporting the current full-resolution enhanced image."
        let newOperationID = UUID()
        operationID = newOperationID
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let data = try ImagePipeline.encodedData(for: result.value.image, format: format)
                try Task.checkCancellation()
                try data.write(to: url, options: .atomic)
                try Task.checkCancellation()
                await self?.acceptExport(
                    url: url,
                    format: format,
                    requestKey: result.key,
                    operationID: newOperationID
                )
            } catch is CancellationError {
                await self?.acceptExportCancellation(operationID: newOperationID)
            } catch {
                await self?.acceptExportFailure(error, operationID: newOperationID)
            }
        }
    }

    private func exportAnalysisRecord(
        _ snapshot: AnalysisRecordPresentation,
        to url: URL
    ) {
        activeOperation?.cancel()
        phase = .exporting
        exportKind = .analysisRecord
        exportNotice = nil
        exportNoticeIsError = false
        statusAnnouncement = "Exporting the current analysis record locally."
        let newOperationID = UUID()
        operationID = newOperationID
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()
        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if accessedSecurityScope { url.stopAccessingSecurityScopedResource() }
            }
            do {
                try Task.checkCancellation()
                try AnalysisRecordJSONEncoder.write(snapshot.value, to: url)
                try Task.checkCancellation()
                await self?.acceptAnalysisRecordExport(
                    url: url,
                    snapshotID: snapshot.id,
                    operationID: newOperationID
                )
            } catch is CancellationError {
                await self?.acceptExportCancellation(operationID: newOperationID)
            } catch {
                await self?.acceptAnalysisRecordExportFailure(operationID: newOperationID)
            }
        }
    }

    private func acceptDecodedImage(_ decoded: DecodedImage, operationID: UUID) {
        guard operationID == self.operationID, phase == .importing else { return }
        activeOperation = nil
        source = decoded
        sourceIdentity = SourceIdentity(generation: UUID())
        requestAnalysis()
    }

    private func acceptEnhancedImage(
        _ result: EnhancedImage,
        record: AnalysisRecord,
        job: AnalysisJobIdentity
    ) {
        guard RequestAcceptanceGate.accepts(
            completedJobID: job.id,
            completedKey: job.key,
            activeJobID: activeAnalysisJob?.id,
            currentKey: currentRequestKey
        ) else { return }
        completedEnhancement = CompletedEnhancement(
            key: job.key,
            jobID: job.id,
            value: result,
            record: record
        )
        phase = .ready
        activeOperation = nil
        activeAnalysisJob = nil
        regionEditor.validationIssue = nil
        statusAnnouncement = result.notice
            ?? "Enhancement complete using \(methodText). Original and enhanced images are ready to compare."
    }

    private func acceptAnalysisCancellation(job: AnalysisJobIdentity) {
        guard RequestAcceptanceGate.accepts(
            completedJobID: job.id,
            completedKey: job.key,
            activeJobID: activeAnalysisJob?.id,
            currentKey: currentRequestKey
        ) else { return }
        activeOperation = nil
        activeAnalysisJob = nil
        phase = .failed("The enhancement was canceled. Change a control to try again.")
    }

    private func acceptAnalysisFailure(_ error: Error, job: AnalysisJobIdentity) {
        guard RequestAcceptanceGate.accepts(
            completedJobID: job.id,
            completedKey: job.key,
            activeJobID: activeAnalysisJob?.id,
            currentKey: currentRequestKey
        ) else { return }
        activeOperation = nil
        activeAnalysisJob = nil
        if let issue = error as? RegionValidationIssue {
            regionEditor.validationIssue = issue
            phase = .invalidRegion(issue)
        } else {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "The image operation could not be completed."
            phase = .failed(message)
        }
        statusAnnouncement = (error as? LocalizedError)?.errorDescription
            ?? "The image operation could not be completed."
    }

    private func acceptImportCancellation(operationID: UUID) {
        guard operationID == self.operationID, phase == .importing else { return }
        activeOperation = nil
        sourceName = ""
        phase = .empty
    }

    private func acceptImportFailure(_ error: Error, operationID: UUID) {
        guard operationID == self.operationID, phase == .importing else { return }
        activeOperation = nil
        let message = (error as? LocalizedError)?.errorDescription
            ?? "The image operation could not be completed."
        phase = .failed(message)
        statusAnnouncement = message
    }

    private func acceptExport(
        url: URL,
        format: ImageExportFormat,
        requestKey: AnalysisRequestKey,
        operationID: UUID
    ) {
        guard operationID == self.operationID,
              currentRequestKey == requestKey,
              completedEnhancement?.key == requestKey
        else { return }
        phase = .ready
        activeOperation = nil
        exportKind = nil
        exportNotice = "Exported \(format.displayName) at full resolution"
        exportNoticeIsError = false
        statusAnnouncement = "Enhanced image exported to \(url.lastPathComponent)."
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.exportNotice = nil
        }
    }

    private func acceptExportCancellation(operationID: UUID) {
        guard operationID == self.operationID, phase == .exporting else { return }
        activeOperation = nil
        phase = .ready
        exportKind = nil
    }

    private func acceptExportFailure(_ error: Error, operationID: UUID) {
        guard operationID == self.operationID, phase == .exporting else { return }
        activeOperation = nil
        phase = .ready
        let message = (error as? LocalizedError)?.errorDescription
            ?? "The image operation could not be completed."
        exportKind = nil
        showExportNotice(message, isError: true)
    }

    private func acceptAnalysisRecordExport(
        url: URL,
        snapshotID: UUID,
        operationID: UUID
    ) {
        guard operationID == self.operationID,
              completedEnhancement?.jobID == snapshotID
        else { return }
        phase = .ready
        activeOperation = nil
        exportKind = nil
        showExportNotice("Exported \(url.lastPathComponent)", isError: false)
        statusAnnouncement = "Analysis record exported to \(url.lastPathComponent)."
    }

    private func acceptAnalysisRecordExportFailure(operationID: UUID) {
        guard operationID == self.operationID, phase == .exporting else { return }
        activeOperation = nil
        phase = .ready
        exportKind = nil
        let message = "The analysis record could not be saved at that location. Choose another destination; your image and record are unchanged."
        showExportNotice(message, isError: true)
        statusAnnouncement = message
    }

    private var currentCompletedEnhancement: CompletedEnhancement? {
        guard phase == .ready,
              let completedEnhancement,
              let currentRequestKey,
              completedEnhancement.key == currentRequestKey
        else { return nil }
        return completedEnhancement
    }

    private var suggestedAnalysisRecordFilename: String {
        let stem = (sourceName as NSString).deletingPathExtension
        return "\(stem)-klt.klt-analysis.json"
    }

    private func analysisRecordIsCurrent(_ snapshot: AnalysisRecordPresentation) -> Bool {
        currentCompletedEnhancement?.jobID == snapshot.id
    }

    private func showExportNotice(_ message: String, isError: Bool) {
        exportNotice = message
        exportNoticeIsError = isError
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.exportNotice = nil
            self?.exportNoticeIsError = false
        }
    }

    private func invalidateActiveOperation() {
        activeOperation?.cancel()
        activeOperation = nil
        activeAnalysisJob = nil
        exportKind = nil
        operationID = UUID()
    }
}

#if DEBUG
extension WorkspaceModel {
    static func previewReady() -> WorkspaceModel {
        let model = WorkspaceModel()
        guard let data = previewImageData(),
              let source = try? ImagePipeline.decode(data),
              let enhanced = try? ImagePipeline.enhance(source)
        else { return model }
        let sourceIdentity = SourceIdentity(generation: UUID())
        let key = AnalysisRequestKey(source: sourceIdentity, input: .baseline)
        guard let record = try? AnalysisRecord(
            decodedSource: source,
            displayFilename: "starling-feather.png",
            enhancement: enhanced
        ) else { return model }
        model.source = source
        model.sourceIdentity = sourceIdentity
        model.currentRequestKey = key
        model.completedEnhancement = CompletedEnhancement(
            key: key,
            jobID: UUID(),
            value: enhanced,
            record: record
        )
        model.sourceName = "starling-feather.png"
        model.phase = .ready
        model.statusAnnouncement = "Enhancement complete."
        return model
    }

    static func previewProcessing() -> WorkspaceModel {
        let model = previewReady()
        model.phase = .processing
        model.statusAnnouncement = "Updating the enhancement."
        return model
    }

    static func previewFailure() -> WorkspaceModel {
        let model = WorkspaceModel()
        model.phase = .failed("This image could not be read. Try a JPEG, PNG, TIFF, or HEIC file.")
        model.statusAnnouncement = "The image could not be read."
        return model
    }

    private static func previewImageData() -> Data? {
        let width = 160
        let height = 110
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let bytes = bitmap.bitmapData else { return nil }

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let nx = Double(x) / Double(width - 1)
                let ny = Double(y) / Double(height - 1)
                bytes[index] = UInt8((40 + (170 * nx)).rounded())
                bytes[index + 1] = UInt8((55 + (130 * ny)).rounded())
                bytes[index + 2] = UInt8((75 + (120 * (1 - nx * ny))).rounded())
                bytes[index + 3] = 255
            }
        }
        return bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
    }
}
#endif
