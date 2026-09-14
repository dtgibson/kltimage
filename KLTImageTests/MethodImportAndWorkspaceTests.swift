import CoreGraphics
import Foundation
import ImageIO
import KLTCore
import UniformTypeIdentifiers
import XCTest
@testable import KLTImage

final class MethodImportAndWorkspaceTests: XCTestCase {
    @MainActor
    func testCrossTypeNameConflictIsCopyOnlyAndNeverReplacesRecipe() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recipe = try recipeItem(name: "Shared Method")
        let store = MethodLibraryStore(url: url)
        _ = try await store.replace(with: MethodLibrarySnapshot(savedTransforms: [recipe]))
        let model = MethodLibraryModel(store: store)
        await waitUntilLoaded(model)
        let incoming = PendingMethodImport.workingSpace(WorkingSpaceInterchange(
            libraryName: "  SHARED METHOD ",
            purpose: "Incoming",
            revision: try userSpace()
        ))

        let preflight = model.preflight(for: incoming)
        XCTAssertTrue(preflight.allowsCopy)
        XCTAssertFalse(preflight.allowsReplace)
        XCTAssertEqual(preflight.local?.kind, .savedTransform)

        model.pendingImport = incoming
        await model.commitPendingImport(.replace)
        XCTAssertEqual(model.snapshot.savedTransforms, [recipe])
        XCTAssertTrue(model.snapshot.userWorkingSpaces.isEmpty)
        XCTAssertEqual(
            model.operationError,
            MethodLibraryOperationError.unavailableImportChoice.localizedDescription
        )

        await model.commitPendingImport(.copy)
        XCTAssertEqual(model.snapshot.savedTransforms, [recipe])
        XCTAssertEqual(model.snapshot.userWorkingSpaces.count, 1)
        guard let copiedSpace = model.snapshot.userWorkingSpaces.first else { return }
        XCTAssertNotEqual(
            WorkingSpaceValidator.normalizedName(copiedSpace.libraryName),
            WorkingSpaceValidator.normalizedName(recipe.libraryName)
        )
    }

    @MainActor
    func testCrossTypeRecipeNameConflictIsCopyOnlyAndNeverReplacesSpace() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let space = UserWorkingSpaceItem(
            libraryName: "Shared Method",
            purpose: nil,
            revision: try userSpace(),
            createdAt: stamp,
            modifiedAt: stamp
        )
        let store = MethodLibraryStore(url: url)
        _ = try await store.replace(with: MethodLibrarySnapshot(userWorkingSpaces: [space]))
        let model = MethodLibraryModel(store: store)
        await waitUntilLoaded(model)
        let incomingRecipe = try recipeItem(name: "SHARED METHOD")
        let incoming = PendingMethodImport.savedTransform(TransformRecipeInterchange(
            libraryName: incomingRecipe.libraryName,
            recipe: incomingRecipe.recipe
        ))

        let preflight = model.preflight(for: incoming)
        XCTAssertTrue(preflight.allowsCopy)
        XCTAssertFalse(preflight.allowsReplace)
        XCTAssertEqual(preflight.local?.kind, .workingSpace)

        model.pendingImport = incoming
        await model.commitPendingImport(.replace)
        XCTAssertEqual(model.snapshot.userWorkingSpaces, [space])
        XCTAssertTrue(model.snapshot.savedTransforms.isEmpty)
    }

    @MainActor
    func testInconsistentIdentityAndVersionIsRejectedBeforePreviewStaging() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        let revision = try userSpace()
        let existing = UserWorkingSpaceItem(
            libraryName: "Local",
            purpose: nil,
            revision: revision,
            createdAt: stamp,
            modifiedAt: stamp
        )
        let store = MethodLibraryStore(url: url)
        _ = try await store.replace(with: MethodLibrarySnapshot(userWorkingSpaces: [existing]))
        let model = MethodLibraryModel(store: store)
        await waitUntilLoaded(model)
        let conflicting = try WorkingSpaceValidator.makeRevision(
            identity: revision.identity,
            definitionVersion: revision.definitionVersion,
            base: revision.base,
            workingChannelNames: revision.workingChannelNames,
            forwardValues: Matrix3x3.diagonal(SIMD3(2, 1, 1)).rowMajorValues,
            offsetValues: [0, 0, 0]
        ).revision

        XCTAssertThrowsError(try model.stageImport(.workingSpace(WorkingSpaceInterchange(
            libraryName: "Incoming",
            purpose: nil,
            revision: conflicting
        )))) {
            XCTAssertEqual($0 as? MethodLibraryOperationError, .inconsistentWorkingSpaceRevision)
        }
        XCTAssertNil(model.pendingImport)
    }

    @MainActor
    func testFailedOrCanceledRecipeOpenCannotContaminateOrdinaryOpen() async throws {
        let (directory, storeURL) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = WorkspaceModel(methodLibrary: MethodLibraryModel(store: MethodLibraryStore(url: storeURL)))
        let item = try recipeItem(name: "Frozen")
        let invalidURL = directory.appendingPathComponent("invalid.png")
        let validURL = directory.appendingPathComponent("valid.png")
        try Data("not an image".utf8).write(to: invalidURL)
        try fixtureImageData(width: 32, height: 24).write(to: validURL)

        model.openImage(at: invalidURL, applying: item)
        await waitUntil { if case .failed = model.phase { return true }; return false }
        XCTAssertFalse(model.isReplayed)

        model.openImage(at: validURL)
        await waitUntil { model.phase == .ready }
        XCTAssertFalse(model.isReplayed)
        guard case .calculated = model.methodSelection else {
            return XCTFail("An ordinary open must calculate, not replay a stale recipe")
        }

        model.openImage(at: validURL, applying: item)
        model.cancelCurrentOperation()
        model.openImage(at: validURL)
        await waitUntil { model.phase == .ready }
        XCTAssertFalse(model.isReplayed)
    }

    @MainActor
    func testApplyToAnotherImageKeepsCurrentWorkspaceThroughCancellationAndDecodeFailure() async throws {
        let (directory, storeURL) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ControlledDecoder()
        let model = WorkspaceModel(
            methodLibrary: MethodLibraryModel(store: MethodLibraryStore(url: storeURL)),
            decodeImage: gate.decode
        )
        let priorURL = directory.appendingPathComponent("prior.png")
        let replacementURL = directory.appendingPathComponent("replacement.png")
        let invalidURL = directory.appendingPathComponent("invalid.png")
        try fixtureImageData(width: 48, height: 32).write(to: priorURL)
        try fixtureImageData(width: 40, height: 28).write(to: replacementURL)
        try Data("not an image".utf8).write(to: invalidURL)
        let recipe = try recipeItem(name: "Frozen")

        model.openImage(at: priorURL)
        await waitUntil { model.phase == .ready }
        let priorFingerprint = try XCTUnwrap(model.source?.analysisSourceFingerprint)
        let priorRecord = try XCTUnwrap(model.currentAnalysisRecord)

        gate.blockNextDecode()
        model.openImage(at: replacementURL, applying: recipe)
        XCTAssertEqual(gate.waitUntilBlocked(), .success)
        await waitUntil { model.phase == .importing }
        XCTAssertEqual(model.sourceName, priorURL.lastPathComponent)
        XCTAssertEqual(model.source?.analysisSourceFingerprint, priorFingerprint)
        XCTAssertEqual(model.currentAnalysisRecord?.id, priorRecord.id)
        XCTAssertTrue(model.canExport)
        XCTAssertEqual(model.resultCurrency, .current)

        model.cancelCurrentOperation()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertEqual(model.source?.analysisSourceFingerprint, priorFingerprint)
        XCTAssertEqual(model.currentAnalysisRecord?.id, priorRecord.id)
        XCTAssertFalse(model.isReplayed)
        gate.releaseBlockedDecode()
        try? await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(model.source?.analysisSourceFingerprint, priorFingerprint)
        XCTAssertEqual(model.currentAnalysisRecord?.id, priorRecord.id)

        model.openImage(at: invalidURL, applying: recipe)
        await waitUntil { model.phase == .ready && model.exportNoticeIsError }
        XCTAssertEqual(model.source?.analysisSourceFingerprint, priorFingerprint)
        XCTAssertEqual(model.currentAnalysisRecord?.id, priorRecord.id)
        XCTAssertFalse(model.isReplayed)
        XCTAssertTrue(model.exportNotice?.contains("prior image and result are unchanged") == true)
    }

    @MainActor
    func testSupersededApplyDecodeCannotReplaceTheNewerAcceptedSourceOrRecipe() async throws {
        let (directory, storeURL) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let gate = ControlledDecoder()
        let model = WorkspaceModel(
            methodLibrary: MethodLibraryModel(store: MethodLibraryStore(url: storeURL)),
            decodeImage: gate.decode
        )
        let priorURL = directory.appendingPathComponent("prior.png")
        let staleURL = directory.appendingPathComponent("stale.png")
        let currentURL = directory.appendingPathComponent("current.png")
        try fixtureImageData(width: 32, height: 24).write(to: priorURL)
        try fixtureImageData(width: 36, height: 26).write(to: staleURL)
        try fixtureImageData(width: 44, height: 30).write(to: currentURL)
        let staleRecipe = try recipeItem(name: "Stale frozen")
        let currentRecipe = try recipeItem(name: "Current frozen")

        model.openImage(at: priorURL)
        await waitUntil { model.phase == .ready }
        gate.blockNextDecode()
        model.openImage(at: staleURL, applying: staleRecipe)
        XCTAssertEqual(gate.waitUntilBlocked(), .success)
        model.openImage(at: currentURL, applying: currentRecipe)
        await waitUntil { model.phase == .ready && model.sourceName == currentURL.lastPathComponent }
        XCTAssertTrue(model.isReplayed)
        XCTAssertEqual(model.activeMethodName, currentRecipe.libraryName)
        let acceptedRecord = try XCTUnwrap(model.currentAnalysisRecord?.id)

        gate.releaseBlockedDecode()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(model.sourceName, currentURL.lastPathComponent)
        XCTAssertEqual(model.activeMethodName, currentRecipe.libraryName)
        XCTAssertEqual(model.currentAnalysisRecord?.id, acceptedRecord)
    }

    @MainActor
    func testSaveRenameDeleteAndCalculatedReplaySupersessionKeepImmutableCurrentSnapshots() async throws {
        let (directory, storeURL) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let library = MethodLibraryModel(store: MethodLibraryStore(url: storeURL))
        let model = WorkspaceModel(methodLibrary: library)
        await waitUntilLoaded(library)
        let sourceURL = directory.appendingPathComponent("source.png")
        try fixtureImageData(width: 256, height: 192).write(to: sourceURL)
        model.openImage(at: sourceURL)
        await waitUntil { model.phase == .ready }

        let custom = try await library.saveNewSpace(WorkingSpaceEditorDraft(
            libraryName: "Lifecycle space",
            base: .encodedSRGB,
            channelNames: ["one", "two", "three"],
            coefficients: ["1", "0.2", "0", "0", "1", "0.1", "0.05", "0", "1"],
            offsets: ["0.1", "-0.2", "0.3"]
        ))
        model.useWorkingSpace(custom.revision, name: custom.libraryName)
        await waitUntil { model.phase == .ready && model.activeMethodName == custom.libraryName }
        let calculationRecord = try XCTUnwrap(model.currentAnalysisRecord)
        let captured = try XCTUnwrap(model.capturedTransformSeed())

        model.selectMatrixMode(.correlation)
        try await model.saveTransform(captured, name: "Immutable capture")
        let saved = try XCTUnwrap(library.snapshot.savedTransforms.first)
        XCTAssertEqual(saved.recipe, captured, "Saving must use the immutable captured seed, not mutated controls")
        await waitUntil { model.phase == .ready }
        let recordBeforeRename = try XCTUnwrap(model.currentAnalysisRecord?.id)

        try await library.renameSpace(custom, to: "Renamed lifecycle space")
        XCTAssertEqual(model.currentAnalysisRecord?.id, recordBeforeRename)
        XCTAssertEqual(model.activeMethodName, custom.libraryName, "A library-only rename must not recalculate current pixels")

        model.applyRecipe(saved)
        model.useWorkingSpace(custom.revision, name: custom.libraryName)
        await waitUntil { model.phase == .ready && !model.isReplayed }
        XCTAssertEqual(model.activeMethodName, custom.libraryName)

        model.useWorkingSpace(custom.revision, name: custom.libraryName)
        model.applyRecipe(saved)
        await waitUntil { model.phase == .ready && model.isReplayed }
        let replayRecord = try XCTUnwrap(model.currentAnalysisRecord)
        XCTAssertNotEqual(replayRecord.id, calculationRecord.id)

        try await library.deleteRecipe(saved)
        XCTAssertTrue(model.isReplayed)
        XCTAssertEqual(model.currentAnalysisRecord?.id, replayRecord.id)

        model.useWorkingSpace(custom.revision, name: custom.libraryName)
        await waitUntil { model.phase == .ready && !model.isReplayed }
        try await model.deleteWorkingSpace(custom)
        await waitUntil { model.phase == .ready && model.activeWorkingSpace.identity == WorkingSpaceCatalog.standardRGB.revision.identity }
        XCTAssertFalse(model.isReplayed)
        XCTAssertNotEqual(model.currentAnalysisRecord?.id, replayRecord.id)
    }

    @MainActor
    private func waitUntilLoaded(_ model: MethodLibraryModel) async {
        await waitUntil { !model.isLoading }
    }

    @MainActor
    private func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<1_000 {
            if predicate() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Timed out waiting for asynchronous model state")
    }

    private func temporaryStoreURL() throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("library.json"))
    }

    private func userSpace() throws -> WorkingSpaceRevision {
        try WorkingSpaceValidator.makeRevision(
            identity: WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased()),
            definitionVersion: 1,
            base: .encodedSRGB,
            workingChannelNames: ["one", "two", "three"],
            forwardValues: Matrix3x3.identity.rowMajorValues,
            offsetValues: [0, 0, 0]
        ).revision
    }

    private func recipeItem(name: String) throws -> SavedTransformItem {
        let fingerprint = try AnalysisSourceFingerprint(
            algorithm: "sha256",
            value: String(repeating: "a", count: 64)
        )
        let source = try AnalysisSourceDescriptor(
            displayFilename: "origin.png",
            width: 4,
            height: 4,
            fingerprint: fingerprint
        )
        let recipe = TransformRecipeSnapshot(
            identifier: UUID(),
            workingSpace: WorkingSpaceCatalog.standardRGB.revision,
            workingSpaceNameAtCapture: "RGB",
            originatingAnalysis: OriginatingAnalysis(
                matrixMode: .covariance,
                samplingMode: .wholeImage,
                region: nil,
                samplePixelCount: 16
            ),
            originSource: source,
            workingCenter: SIMD3(repeating: 0.5),
            transform: .identity,
            outputMapping: .encodedSRGBGlobalRangeV1(
                minimum: 0,
                maximum: 1,
                scale: 1,
                clipsToUnitRange: true
            )
        )
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        return SavedTransformItem(libraryName: name, recipe: recipe, createdAt: stamp, modifiedAt: stamp)
    }

    private func fixtureImageData(width: Int, height: Int) throws -> Data {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let offset = index * 4
                bytes[offset] = UInt8((index * 31 + 19) % 256)
                bytes[offset + 1] = UInt8((index * 47 + 37) % 256)
                bytes[offset + 2] = UInt8((index * 67 + 71) % 256)
                bytes[offset + 3] = 255
            }
        }
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo,
            provider: CGDataProvider(data: pixels as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .relativeColorimetric
        )!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return output as Data
    }
}

private final class ControlledDecoder: @unchecked Sendable {
    private let lock = NSLock()
    private let blocked = DispatchSemaphore(value: 0)
    private let release = DispatchSemaphore(value: 0)
    private var shouldBlock = false

    func blockNextDecode() {
        lock.withLock { shouldBlock = true }
    }

    func waitUntilBlocked() -> DispatchTimeoutResult {
        blocked.wait(timeout: .now() + 2)
    }

    func releaseBlockedDecode() {
        release.signal()
    }

    func decode(_ data: Data) throws -> DecodedImage {
        let block = lock.withLock { () -> Bool in
            defer { shouldBlock = false }
            return shouldBlock
        }
        if block {
            blocked.signal()
            _ = release.wait(timeout: .now() + 5)
        }
        return try ImagePipeline.decode(data)
    }
}
