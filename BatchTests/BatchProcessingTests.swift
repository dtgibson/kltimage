import CoreGraphics
import Darwin
import ImageIO
import XCTest
@testable import KLTCore
#if os(iOS)
@testable import KLTImageIOS
#else
@testable import KLTImage
#endif

final class BatchProcessingTests: XCTestCase {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("batch-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
    private func source(_ width: Int = 13, _ height: Int = 9) throws -> DecodedImage {
        var data = Data(count: width * height * 4)
        data.withUnsafeMutableBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for i in 0..<(width * height) {
                bytes[i * 4] = UInt8((i * 37 + 17) % 256)
                bytes[i * 4 + 1] = UInt8((i * 59 + 41) % 256)
                bytes[i * 4 + 2] = UInt8((i * 83 + 73) % 256)
                bytes[i * 4 + 3] = 255
            }
        }
        let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                            provider: CGDataProvider(data: data as CFData)!, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        return try ImagePipeline.decode(ImagePipeline.encodedData(for: image, format: .png))
    }
    private func request(parent: URL, entries: [BatchInputEntry] = [], records: Bool = true) throws -> BatchRunRequest {
        let id = UUID()
        return BatchRunRequest(id: id, entries: entries, execution: .calculated(.init(.baseline)), methodName: "RGB",
                               modeName: "Calculate each image", format: .png, includesRecord: records,
                               destination: try BatchFolderGrant(parent), folderName: BatchNames.folder(owner: id), limits: .current)
    }

    func testBoundedEncoderPreservesExistingBytesAndOriginalSinkErrors() throws {
        let image = try source().originalImage
        for format in ImageExportFormat.allCases {
            var streamed = Data()
            let count = try ImagePipeline.encode(image, format: format, maximumBytes: 1_048_576) { streamed.append(contentsOf: $0) }
            XCTAssertEqual(count, streamed.count)
            XCTAssertEqual(streamed, try ImagePipeline.encodedData(for: image, format: format))
        }
        var retained = 0
        XCTAssertThrowsError(try ImagePipeline.encode(image, format: .png, maximumBytes: 2) { retained += $0.count }) {
            guard case BoundedImageEncodingError.byteLimit(2) = $0 else { return XCTFail("Lost cap error: \($0)") }
        }
        XCTAssertLessThanOrEqual(retained, 2)
        XCTAssertThrowsError(try ImagePipeline.encode(image, format: .png, maximumBytes: 1_048_576) { _ in throw CancellationError() }) {
            XCTAssertTrue($0 is CancellationError)
        }
    }

    func testStableStagingRejectsOverflowChangesAndLinksAndReleasesQuota() throws {
        let base = try directory(); let storage = try BatchStorage(base: base.appendingPathComponent("private"), limit: 200_000)
        let source = base.appendingPathComponent("input.png"); try Data(repeating: 5, count: 70_000).write(to: source)
        XCTAssertThrowsError(try BatchIO.stage(source, storage: storage, limit: 69_999, stop: BatchStop()))
        let stage = try BatchIO.stage(source, storage: storage, limit: 70_000, stop: BatchStop())
        XCTAssertEqual(try Data(contentsOf: stage), try Data(contentsOf: source)); try storage.removePrivate(stage)
        XCTAssertThrowsError(try BatchIO.stage(source, storage: storage, limit: 80_000, stop: BatchStop(), afterChunk: { total in
            if total == 65_536 {
                let handle = try FileHandle(forWritingTo: source); try handle.seekToEnd(); try handle.write(contentsOf: Data([1])); try handle.close()
            }
        }))
        let link = base.appendingPathComponent("link.png"); try FileManager.default.createSymbolicLink(at: link, withDestinationURL: source)
        XCTAssertThrowsError(try BatchIO.stage(link, storage: storage, limit: 80_000, stop: BatchStop()))
        XCTAssertNoThrow(try storage.requireRoom(200_000))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.root.path), [])
    }

    func testScientificParityAndAcceptanceGateForCalculationAndRegionReplay() throws {
        let source = try source(); let target = try self.source(7, 11)
        for selection in [WorkingSpaceSelection.standardRGB, .standardLabD65, .affine(WorkingSpaceCatalog.curated[0].revision)] {
            for matrix in AnalysisMatrixMode.allCases {
                let calculation = CalculatedAnalysisRequest(workingSpace: selection, matrixMode: matrix, sampleSource: .wholeImage, region: nil)
                let identity = BatchItemIdentity(run: UUID(), item: UUID(), generation: UUID(), fingerprint: source.analysisSourceFingerprint, request: .calculated(calculation), job: UUID())
                let batch = try BatchRunner.calculate(source, name: "origin.png", identity: identity, methodName: "Captured")
                let single = try ImagePipeline.enhance(source, request: calculation, workingSpaceName: "Captured")
                XCTAssertEqual(batch.image.rgba8Premultiplied, single.rgba8Premultiplied)
                XCTAssertEqual(batch.record, try AnalysisRecordRouter.make(decodedSource: source, displayFilename: "origin.png", enhancement: single))
                let region = CalculatedAnalysisRequest(workingSpace: selection, matrixMode: matrix, sampleSource: .selectedRegion,
                                                       region: SourcePixelRegion(x: 1, y: 1, width: 8, height: 6))
                let fitted = try ImagePipeline.enhance(source, request: region, workingSpaceName: "Captured")
                let recipe = try TransformRecipeFactory.capture(decodedSource: source, displayFilename: "origin.png", enhancement: fitted)
                let replayID = BatchItemIdentity(run: UUID(), item: UUID(), generation: UUID(), fingerprint: target.analysisSourceFingerprint, request: .replayed(recipe), job: UUID())
                let replay = try BatchRunner.calculate(target, name: "target.png", identity: replayID, methodName: "Pinned")
                let expected = try ImagePipeline.replay(target, recipe: recipe, recipeName: "Pinned")
                XCTAssertEqual(replay.image.rgba8Premultiplied, expected.rgba8Premultiplied)
                XCTAssertEqual(replay.image.replayDiagnostics, expected.replayDiagnostics)
                XCTAssertFalse(identity.accepts(replayID, stop: BatchStop()))
                let stop = BatchStop(); XCTAssertTrue(identity.accepts(identity, stop: stop)); stop.stop("Canceled")
                XCTAssertFalse(identity.accepts(identity, stop: stop))
            }
        }
    }

    func testExclusivePairCollisionAndCancellationPreserveActualCommits() throws {
        for boundary in ["beforeImage", "afterImage", "afterRecord", "collision"] {
            let base = try directory(); let storage = try BatchStorage(base: base.appendingPathComponent("private"))
            let request = try request(parent: base); let stop = BatchStop()
            let publisher = try BatchPublisher(request: request, storage: storage, stop: stop)
            let image = try storage.makePrivate(reserving: 4); try Data([1,2,3,4]).write(to: image)
            let record = try storage.makePrivate(reserving: 2); try Data("{}".utf8).write(to: record)
            let entry = BatchInputEntry(name: "../unsafe:bird.png", source: BatchFileSource(url: image))
            let stem = BatchNames.stem(entry.name, ordinal: 1)
            let sentinel = publisher.url.appendingPathComponent(stem + "-analysis.json")
            var receipt = BatchCommitReceipt(); var injected = false
            do {
                try publisher.publish(image: image, imageBytes: 4, record: record, recordBytes: 2,
                                      entry: entry, ordinal: 1, format: .png, authorize: { try stop.check() }, receipt: &receipt) { phase in
                    if boundary == "collision", phase == "afterImage", !injected {
                        injected = true; try Data("sentinel".utf8).write(to: sentinel)
                    } else if phase == boundary { stop.stop("Batch canceled"); throw CancellationError() }
                }
            } catch { XCTAssertTrue(error is CancellationError, "\(error)") }
            if boundary == "beforeImage" { XCTAssertNil(receipt.imageName); XCTAssertNil(receipt.recordName) }
            else {
                XCTAssertEqual(try Data(contentsOf: publisher.url.appendingPathComponent(try XCTUnwrap(receipt.imageName))), Data([1,2,3,4]))
                if boundary == "afterImage" { XCTAssertNil(receipt.recordName) }
                else { XCTAssertEqual(try Data(contentsOf: publisher.url.appendingPathComponent(try XCTUnwrap(receipt.recordName))), Data("{}".utf8)) }
            }
            if boundary == "collision" {
                XCTAssertEqual(try Data(contentsOf: sentinel), Data("sentinel".utf8))
                XCTAssertEqual(receipt.imageName?.replacingOccurrences(of: ".png", with: ""), receipt.recordName?.replacingOccurrences(of: "-analysis.json", with: ""))
            }
            try publisher.cleanup(); XCTAssertEqual(storage.debt, 0)
        }
    }

    func testCleanupDebtSurvivesRelaunchAndRejectsWrongFolderWithoutTouchingSentinels() throws {
        let base = try directory(); let privateRoot = base.appendingPathComponent("private")
        let owner = UUID(); let folder = base.appendingPathComponent(BatchNames.folder(owner: owner))
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        let name = BatchNames.temporary(owner: owner)
        let original = try BatchStorage(base: privateRoot, limit: 1_000)
        try original.reserveExternal(owner: owner, name: name, bytes: 600)
        try Data(repeating: 1, count: 500).write(to: folder.appendingPathComponent(name))
        let sentinel = folder.appendingPathComponent("saved.png"); try Data([42]).write(to: sentinel)
        let relaunched = try BatchStorage(base: privateRoot, limit: 1_000)
        XCTAssertEqual(relaunched.debt, 600); XCTAssertThrowsError(try relaunched.requireRoom(401))
        XCTAssertThrowsError(try relaunched.cleanupReselected(BatchFolderGrant(base)))
        XCTAssertEqual(relaunched.debt, 600)
        XCTAssertEqual(try relaunched.cleanupReselected(BatchFolderGrant(folder)), 600)
        XCTAssertEqual(try Data(contentsOf: sentinel), Data([42])); XCTAssertEqual(relaunched.debt, 0)
        let receipt = try String(contentsOf: privateRoot.appendingPathComponent("temporary-reservations.json"), encoding: .utf8)
        XCTAssertFalse(receipt.contains(base.path)); XCTAssertFalse(receipt.contains("saved.png"))
        XCTAssertEqual(try BatchStorage(base: privateRoot, limit: 1_000).debt, 0)
    }

    func testSerialRunnerSettlesMixedInputsAndCancellationWithoutAcquiringNext() async throws {
        let base = try directory(); let storage = try BatchStorage(base: base.appendingPathComponent("private"))
        let image = base.appendingPathComponent("image.png")
        try ImagePipeline.encodedData(for: source().originalImage, format: .png).write(to: image)
        let broken = base.appendingPathComponent("broken.png"); try Data("bad".utf8).write(to: broken)
        let entries = [image, broken, image].map { BatchInputEntry(name: $0.lastPathComponent, source: BatchFileSource(url: $0)) }
        let request = try request(parent: base, entries: entries)
        let result = await BatchRunner.run(request, storage: storage, stop: BatchStop(), phase: { _, _ in }, settled: { _ in })
        XCTAssertEqual(result.outcomes.map(\.status), [.saved, .failed, .saved]); XCTAssertNil(result.stopReason)
        XCTAssertEqual(storage.debt, 0); XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.root.path), [])
        let stop = BatchStop(); let stopped = await BatchRunner.run(try self.request(parent: base, entries: entries), storage: storage, stop: stop,
                                                                  phase: { _, _ in }, settled: { _ in stop.stop("Batch canceled") })
        XCTAssertEqual(stopped.outcomes.map(\.status), [.saved, .notProcessed, .notProcessed])
    }

    func testHundredEntriesStaySequentialAndLateCanceledAcquisitionDrains() async throws {
        let base = try directory(); let storage = try BatchStorage(base: base.appendingPathComponent("private"))
        let input = base.appendingPathComponent("input.png")
        try ImagePipeline.encodedData(for: source(4, 4).originalImage, format: .png).write(to: input)
        let tracker = AcquisitionTracker()
        let entries = (0..<100).map { _ in BatchInputEntry(name: "repeated.png", source: ObservedSource(url: input, tracker: tracker)) }
        let result = await BatchRunner.run(try request(parent: base, entries: entries, records: false), storage: storage,
                                          stop: BatchStop(), phase: { _, _ in }, settled: { _ in })
        XCTAssertEqual(result.outcomes.count, 100)
        XCTAssertTrue(result.outcomes.allSatisfy { $0.status == .saved })
        XCTAssertEqual(Set(result.outcomes.compactMap(\.imageName)).count, 100)
        XCTAssertEqual(tracker.snapshot.started, 100); XCTAssertEqual(tracker.snapshot.peak, 1)
        XCTAssertEqual(tracker.snapshot.leftover, 0); XCTAssertEqual(storage.debt, 0)
        let lateTracker = AcquisitionTracker(); let stop = BatchStop()
        let lateEntries = (0..<2).map { _ in BatchInputEntry(name: "late.png", source: ObservedSource(url: input, tracker: lateTracker, delay: true)) }
        let request = try request(parent: base, entries: lateEntries)
        let worker = Task { await BatchRunner.run(request, storage: storage, stop: stop, phase: { _, _ in }, settled: { _ in }) }
        while lateTracker.snapshot.started == 0 { try await Task.sleep(for: .milliseconds(5)) }
        stop.stop("Batch interrupted"); worker.cancel()
        let interrupted = await worker.value
        XCTAssertEqual(interrupted.stopReason, "Batch interrupted")
        XCTAssertEqual(interrupted.outcomes.map(\.status), [.canceled, .notProcessed])
        XCTAssertEqual(lateTracker.snapshot.started, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.root.path), [])
    }

    #if DEBUG
    func testRunnerCapacityPermissionAndPostImageFaultsReportActualFiles() async throws {
        let base = try directory(); let input = base.appendingPathComponent("input.png")
        try ImagePipeline.encodedData(for: source().originalImage, format: .png).write(to: input)
        for fault in ["low-at-start", "low-before-save", "unknown", "permission", "partial"] {
            let storage = try BatchStorage(base: base.appendingPathComponent("private-" + fault))
            let tracker = AcquisitionTracker()
            let entries = (0..<2).map { _ in BatchInputEntry(name: "input.png", source: ObservedSource(url: input, tracker: tracker)) }
            let run = try request(parent: base, entries: entries)
            let stop = BatchStop(testFaults: BatchTestFaults(capacity: { _, pending in
                if fault == "unknown" { return nil }
                if fault == "low-at-start" || (fault == "low-before-save" && pending > 0) { return 1 }
                return Int64.max
            }, publication: { phase in
                if fault == "partial", phase == "afterImage" { throw CocoaError(.fileWriteNoPermission) }
            }))
            let result = await BatchRunner.run(run, storage: storage, stop: stop, phase: { _, phase in
                if fault == "permission", phase == .saving {
                    // Real destination loss at the runner boundary, not a mocked outcome.
                    try? FileManager.default.moveItem(at: base.appendingPathComponent(run.folderName),
                                                     to: base.appendingPathComponent("revoked-" + run.id.uuidString))
                }
            }, settled: { _ in })
            switch fault {
            case "low-at-start":
                XCTAssertEqual(tracker.snapshot.started, 0)
                XCTAssertEqual(result.outcomes.map(\.status), [.notProcessed, .notProcessed])
            case "unknown":
                XCTAssertEqual(result.outcomes.map(\.status), [.saved, .saved]); XCTAssertNil(result.stopReason)
            case "partial":
                XCTAssertEqual(result.outcomes.map(\.status), [.partial, .notProcessed])
                let row = result.outcomes[0]; let folder = try XCTUnwrap(result.folder)
                let name = try XCTUnwrap(row.imageName)
                let saved = try ImagePipeline.decode(at: folder.appendingPathComponent(name))
                XCTAssertEqual(saved.width, 13); XCTAssertEqual(saved.height, 9)
                XCTAssertNil(row.recordName)
                XCTAssertTrue(row.reason?.contains("analysis JSON missing") == true)
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), [name])
            default:
                XCTAssertEqual(result.outcomes.map(\.status), [.failed, .notProcessed])
                XCTAssertEqual(tracker.snapshot.started, 1)
                XCTAssertNil(result.outcomes[0].imageName)
            }
            if fault != "unknown" { XCTAssertNotNil(result.stopReason) }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.root.path), [])
            if fault != "permission" { XCTAssertEqual(storage.debt, 0) }
        }
    }

    #endif

    @MainActor func testPopulatedWorkspacePreservedThroughCompleteFailCancelAndDismiss() async throws {
        let base = try directory(); let input = base.appendingPathComponent("workspace.png")
        try ImagePipeline.encodedData(for: source().originalImage, format: .png).write(to: input)
        let bad = base.appendingPathComponent("broken.png"); try Data("broken".utf8).write(to: bad)
        let region = SourcePixelRegion(x: 1, y: 1, width: 8, height: 6)
        #if os(iOS)
        let workspace = IOSWorkspace(store: IOSMethodLibrary(url: base.appendingPathComponent("library.json")))
        workspace.importImage(input)
        try await eventually { workspace.currentResult != nil && !workspace.batchBusy }
        workspace.matrixMode = .correlation; workspace.sampleSource = .selectedRegion; workspace.setRegion(region)
        try await eventually { workspace.currentResult != nil && !workspace.batchBusy && !BatchInteractiveWork.shared.busy }
        workspace.comparison = .slider; workspace.reveal = 0.31
        let accepted = try XCTUnwrap(workspace.currentResult)
        let method = workspace.method; let library = workspace.library
        #else
        let workspace = WorkspaceModel(methodLibrary: MethodLibraryModel(store: MethodLibraryStore(url: base.appendingPathComponent("library.json"))))
        workspace.openImage(at: input)
        try await eventually { workspace.phase == .ready && !BatchInteractiveWork.shared.busy }
        workspace.selectMatrixMode(.correlation); workspace.selectSampleSource(.selectedRegion); workspace.commitPointerRegion(region)
        try await eventually { workspace.phase == .ready && !BatchInteractiveWork.shared.busy }
        workspace.comparisonMode = .slider; workspace.comparisonReveal = 0.31
        let accepted = try XCTUnwrap(workspace.completedEnhancement)
        let method = workspace.methodSelection; let library = workspace.methodLibrary.snapshot
        workspace.updateRegionDraft(.width, value: "5") // Unapplied draft makes a forbidden Apply observable.
        let regionEditor = workspace.regionEditor
        #endif
        workspace.zoom = 2.75; workspace.pan = CGSize(width: 17, height: -23)
        let original = try XCTUnwrap(workspace.source)
        let record = try AnalysisRecordSnapshotJSONEncoder.data(for: accepted.record)
        for outcome in ["complete", "fail", "cancel", "dismiss"] {
            let gate = AcquisitionGate(); defer { gate.release() }
            let model = BatchModel(library: { library }, workspaceBusy: { false })
            await model.prepare(); XCTAssertTrue(model.ready)
            XCTAssertTrue(BatchWorkspaceLease.shared.isHeld)
            let source: any BatchSource = outcome == "cancel" || outcome == "dismiss"
                ? GatedSource(url: input, gate: gate) : BatchFileSource(url: outcome == "fail" ? bad : input)
            model.add([BatchInputEntry(name: "batch.png", source: source)], generation: model.selectionGeneration)
            model.chooseDestination(base); model.includesRecord = true
            // Exercise real entry points while batch owns the workspace.
            workspace.zoom = 9; workspace.pan = .zero
            #if os(iOS)
            workspace.matrixMode = .covariance; workspace.clearRegion(); workspace.importImage(bad)
            #else
            workspace.selectMatrixMode(.covariance); workspace.updateRegionDraft(.x, value: "99"); workspace.applyRegionDraft(); workspace.clearRegion(); workspace.commitPointerRegion(.init(x: 0, y: 0, width: 2, height: 2)); workspace.openImage(at: bad)
            #endif
            model.start(); XCTAssertTrue(model.running)
            var closed = false
            if outcome == "cancel" || outcome == "dismiss" {
                try await eventually { gate.started }
                if outcome == "dismiss" { model.dismiss { closed = true } } else { model.stop(interrupted: true) }
                XCTAssertTrue(model.stopping); XCTAssertFalse(model.finished); XCTAssertFalse(closed)
                XCTAssertTrue(BatchWorkspaceLease.shared.isHeld)
                gate.release()
            }
            try await eventually { model.finished }
            XCTAssertEqual(model.outcomes.first?.status, outcome == "complete" ? .saved : outcome == "fail" ? .failed : .canceled)
            if outcome == "cancel" { XCTAssertEqual(model.heading, "Batch interrupted") }
            if outcome != "dismiss" { model.dismiss { closed = true } }
            XCTAssertTrue(closed); XCTAssertFalse(BatchWorkspaceLease.shared.isHeld)
            XCTAssertTrue(workspace.source?.originalImage === original.originalImage)
            XCTAssertEqual(workspace.source?.analysisSourceFingerprint, original.analysisSourceFingerprint)
            XCTAssertEqual(workspace.zoom, 2.75); XCTAssertEqual(workspace.pan, CGSize(width: 17, height: -23))
            #if os(iOS)
            let current = try XCTUnwrap(workspace.currentResult)
            XCTAssertEqual(current.generation, accepted.generation); XCTAssertEqual(current.job, accepted.job)
            XCTAssertEqual(current.request, accepted.request); XCTAssertEqual(workspace.method, method)
            XCTAssertEqual(workspace.region, region); XCTAssertEqual(workspace.sampleSource, .selectedRegion)
            XCTAssertEqual(workspace.comparison, .slider); XCTAssertEqual(workspace.reveal, 0.31)
            XCTAssertEqual(workspace.library, library)
            #else
            let current = try XCTUnwrap(workspace.completedEnhancement)
            XCTAssertEqual(current.key, accepted.key); XCTAssertEqual(current.jobID, accepted.jobID)
            XCTAssertEqual(workspace.currentRequestKey, accepted.key); XCTAssertEqual(workspace.methodSelection, method)
            XCTAssertEqual(workspace.regionEditor, regionEditor); XCTAssertEqual(workspace.regionEditor.committed, region); XCTAssertEqual(workspace.sampleSource, .selectedRegion)
            XCTAssertEqual(workspace.comparisonMode, .slider); XCTAssertEqual(workspace.comparisonReveal, 0.31)
            XCTAssertEqual(workspace.methodLibrary.snapshot, library)
            #endif
            XCTAssertEqual(try AnalysisRecordSnapshotJSONEncoder.data(for: current.record), record)
        }
    }

    @MainActor func testRunningRecipeSurvivesLibraryRenameReplacementAndDeletion() async throws {
        let base = try directory(); let original = try source(); let target = try source(7, 11)
        let recipe = try TransformRecipeFactory.capture(decodedSource: original, displayFilename: "origin.png", enhancement: ImagePipeline.enhance(original))
        let selected = SavedTransformItem(libraryName: "Captured recipe", recipe: recipe, createdAt: Date(), modifiedAt: Date())
        var library = MethodLibrarySnapshot(savedTransforms: [selected])
        let input = base.appendingPathComponent("target.png")
        try ImagePipeline.encodedData(for: target.originalImage, format: .png).write(to: input)
        let gate = AcquisitionGate(); defer { gate.release() }
        let model = BatchModel(library: { library }, workspaceBusy: { false })
        await model.prepare(); model.mode = .replay; model.recipeID = recipe.id; model.includesRecord = true
        model.add([BatchInputEntry(name: "target.png", source: GatedSource(url: input, gate: gate)),
                   BatchInputEntry(name: "target-again.png", source: BatchFileSource(url: input))], generation: model.selectionGeneration)
        model.chooseDestination(base); model.start()
        try await eventually { gate.started }
        let frozen = try XCTUnwrap(model.run)
        library = MethodLibrarySnapshot(savedTransforms: [SavedTransformItem(libraryName: "Renamed", recipe: recipe, createdAt: Date(), modifiedAt: Date())])
        library = .empty
        model.mode = .calculate; model.matrix = .correlation
        gate.release(); try await eventually { model.finished }
        XCTAssertEqual(model.outcomes.map(\.status), [.saved, .saved]); XCTAssertEqual(frozen.execution, .replayed(recipe))
        let folder = try XCTUnwrap(model.resultFolder)
        for row in model.outcomes {
            let record = try Data(contentsOf: folder.appendingPathComponent(try XCTUnwrap(row.recordName)))
            let identity = BatchItemIdentity(run: frozen.id, item: row.id, generation: UUID(), fingerprint: target.analysisSourceFingerprint, request: .replayed(recipe), job: UUID())
            let expected = try BatchRunner.calculate(target, name: row.name, identity: identity, methodName: "Captured recipe")
            XCTAssertEqual(record, try AnalysisRecordSnapshotJSONEncoder.data(for: expected.record))
            let output = try ImagePipeline.decode(at: folder.appendingPathComponent(try XCTUnwrap(row.imageName)))
            XCTAssertEqual(output.rgba8Premultiplied, expected.image.rgba8Premultiplied)
        }
        model.dismiss {}
    }

    func testDestinationLabelUsesLocalizedNameWithoutExposingProviderStorage() {
        XCTAssertEqual(BatchDestinationLabel.describe(basename: "File Provider Storage", localizedName: "On My iPhone"), "On My iPhone")
        XCTAssertEqual(BatchDestinationLabel.describe(basename: "Survey photographs", localizedName: nil), "Survey photographs")
        let fallback = BatchDestinationLabel.describe(basename: "File Provider Storage", localizedName: "/private/var/mobile/Containers/Shared/AppGroup/secret")
        XCTAssertFalse(fallback.contains("/")); XCTAssertFalse(fallback.contains("Storage"))
        XCTAssertFalse(BatchDestinationLabel.describe(basename: UUID().uuidString, localizedName: nil).contains("-"))
    }

    @MainActor private func eventually(_ condition: () -> Bool) async throws {
        for _ in 0..<500 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("The expected asynchronous boundary did not settle within five seconds")
        throw CancellationError()
    }

    @MainActor func testSetupBoundDefaultsAndNoWorkspaceMutationWhileLeaseHeld() async throws {
        let model = BatchModel(library: { .empty }, workspaceBusy: { false })
        let base = try directory(); let item = BatchInputEntry(name: "same.png", source: BatchFileSource(url: base.appendingPathComponent("same.png")))
        XCTAssertEqual(model.mode, .calculate); XCTAssertEqual(model.format, .png); XCTAssertFalse(model.includesRecord)
        model.add(Array(repeating: item, count: 100), generation: model.selectionGeneration)
        model.add([item], generation: model.selectionGeneration)
        XCTAssertEqual(model.entries.count, 100); XCTAssertNotNil(model.notice)
        XCTAssertTrue(BatchWorkspaceLease.shared.acquire(model.id))
        #if os(iOS)
        let workspace = IOSWorkspace(); workspace.matrixMode = .correlation
        XCTAssertEqual(workspace.matrixMode, .covariance)
        #else
        let workspace = WorkspaceModel(); workspace.openImage(at: base.appendingPathComponent("none.png"))
        XCTAssertEqual(workspace.phase, .empty)
        #endif
        model.dismiss {}; XCTAssertFalse(BatchWorkspaceLease.shared.isHeld)
    }
}

private final class AcquisitionTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var active = 0
    private var started = 0
    private var peak = 0
    private var leftover = 0
    var snapshot: (started: Int, peak: Int, leftover: Int) { lock.withLock { (started, peak, leftover) } }
    func begin(leftover: Int) { lock.withLock { active += 1; started += 1; peak = max(peak, active); self.leftover += leftover } }
    func end() { lock.withLock { active -= 1 } }
}
private struct ObservedSource: BatchSource {
    let url: URL
    let tracker: AcquisitionTracker
    var delay = false
    func acquire(storage: BatchStorage, limits: BatchLimits, stop: BatchStop) async throws -> URL {
        tracker.begin(leftover: try FileManager.default.contentsOfDirectory(atPath: storage.root.path).count)
        defer { tracker.end() }
        if delay {
            // Models a noninterruptible provider which supplies its owned stage
            // after cancellation. The runner must drain and clean it, not start next.
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.08) { continuation.resume() }
            }
        }
        return try BatchIO.stage(url, storage: storage, limit: limits.sourceBytes, stop: delay ? BatchStop() : stop)
    }
}

#if BATCH_QA_MEMORY && os(macOS)
// Explicit QA-only compilation flag; absent from normal test and shipping builds.
extension BatchProcessingTests {
    func testQAFullResolutionShortAndHundredItemMemory() async throws {
        let base = try directory()
        let input = base.appendingPathComponent("24mp.png")
        try autoreleasepool {
            try ImagePipeline.encodedData(for: source(6_000, 4_000).originalImage, format: .png).write(to: input)
        }
        let storage = try BatchStorage(base: base.appendingPathComponent("private"))
        var priorSamples: [UInt64] = []
        for count in [3, 100] {
            let trace = QAMemoryTrace()
            let entries = (0..<count).map { _ in BatchInputEntry(name: "24mp.png", source: BatchFileSource(url: input)) }
            let result = await BatchRunner.run(try request(parent: base, entries: entries, records: true), storage: storage,
                                              stop: BatchStop(), phase: { _, _ in }, settled: { row in trace.append(row.ordinal) })
            XCTAssertEqual(result.outcomes.count, count)
            XCTAssertTrue(result.outcomes.allSatisfy { $0.status.successful })
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: storage.root.path), [])
            XCTAssertEqual(storage.debt, 0)
            let values = trace.values
            XCTAssertEqual(values.count, count)
            if count == 3 { priorSamples = values }
            else {
                let warm = priorSamples.max() ?? 0
                let tail = values.suffix(10).max() ?? 0
                print("QA_MEMORY_SUMMARY frame=96000000 shortMax=\(priorSamples.max() ?? 0) firstTenMax=\(values.prefix(10).max() ?? 0) lastTenMax=\(tail) final=\(values.last ?? 0)")
                XCTAssertLessThanOrEqual(values.prefix(10).max() ?? 0, warm + 64 * 1_048_576, "A longer queue retained image buffers beyond the three-item warm-up")
                XCTAssertLessThanOrEqual(tail, warm + 64 * 1_048_576, "Settled-item footprint grew by more than 64 MiB beyond the three-item warm-up")
                let folder = try XCTUnwrap(result.folder)
                let saved = try ImagePipeline.decode(at: folder.appendingPathComponent(try XCTUnwrap(result.outcomes.last?.imageName)))
                XCTAssertEqual(saved.width, 6_000); XCTAssertEqual(saved.height, 4_000)
                XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 200)
            }
        }
    }
}

private final class QAMemoryTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [UInt64] = []
    var values: [UInt64] { lock.withLock { samples } }
    func append(_ ordinal: Int) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let footprint = result == KERN_SUCCESS ? info.phys_footprint : UInt64.max
        lock.withLock { samples.append(footprint) }
        let line = "QA_MEMORY item=\(ordinal) footprint=\(footprint) residentPeak=\(info.resident_size_peak)\n"
        FileHandle.standardOutput.write(Data(line.utf8))
    }
}
#endif

private final class AcquisitionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false
    private var released = false
    var started: Bool { lock.withLock { hasStarted } }
    func wait() async {
        await withCheckedContinuation { continuation in
            let resume = lock.withLock { hasStarted = true; if released { return true }; self.continuation = continuation; return false }
            if resume { continuation.resume() }
        }
    }
    func release() {
        let continuation = lock.withLock { released = true; let value = self.continuation; self.continuation = nil; return value }
        continuation?.resume()
    }
}
private struct GatedSource: BatchSource {
    let url: URL
    let gate: AcquisitionGate
    func acquire(storage: BatchStorage, limits: BatchLimits, stop: BatchStop) async throws -> URL {
        await gate.wait()
        return try BatchIO.stage(url, storage: storage, limit: limits.sourceBytes, stop: stop)
    }
}
