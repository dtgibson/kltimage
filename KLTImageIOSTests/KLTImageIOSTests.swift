import Foundation
import XCTest
import KLTCore
@testable import KLTImageIOS

final class KLTImageIOSTests: XCTestCase {
    @MainActor
    func testWorkspaceAcceptsOneMatchingResultAndExportsItsRecord() async throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAYAAAD+Bd/7AAAAAXNSR0IB2cksfwAAAFBlWElmTU0AKgAAAAgAAgESAAMAAAABAAEAAIdpAAQAAAABAAAAJgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAACKADAAQAAAABAAAABgAAAAA4aestAAAAn0lEQVQIHR1NyxGCMBQcZ3LYo4JMCjA/7ACiBXhTyIHOAjRGoARiEa4c3ry3b3+nc/16m7aX+slpgtSPXir/kcYT+yDFfZmgyh66ytwRJvH2O3Q5wfEv3DZCN/EQmSJDF8QUuTLDXOIg7ELXtkO1E8mOzh12pahlEg2iThE3RtkUoPwIV5H4V6aRpgBh1xmq+MKw31GkGX3UXLvBbFn+ANf2M2AGpmb4AAAAAElFTkSuQmCC")!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try png.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let workspace = IOSWorkspace(imageEncoder: { _, _ in
            try await Task.sleep(for: .seconds(30))
            return Data()
        })
        workspace.importImage(url, displayName: "field-source.png")
        for _ in 0..<100 where workspace.currentResult == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        let first = try XCTUnwrap(workspace.currentResult)
        XCTAssertEqual(workspace.sourceName, "field-source.png")
        XCTAssertEqual(workspace.source?.width, 8)
        XCTAssertEqual(workspace.source?.height, 6)
        let record = try await workspace.prepareRecordExport()
        XCTAssertTrue(String(decoding: record, as: UTF8.self).contains("field-source.png"))
        workspace.matrixMode = .correlation
        XCTAssertNil(workspace.currentResult)
        for _ in 0..<100 where workspace.currentResult == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertNotEqual(workspace.currentResult?.job, first.job)
        XCTAssertEqual(workspace.currentResult?.request, workspace.effectiveRequest)

        let preparedRecord = try await workspace.prepareRecordFileExport()
        XCTAssertTrue(workspace.isCurrent(preparedRecord))
        workspace.matrixMode = .covariance
        XCTAssertFalse(workspace.isCurrent(preparedRecord))
        XCTAssertThrowsError(try ExportFile(prepared: preparedRecord).validatedData())
        for _ in 0..<100 where workspace.currentResult == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        _ = try XCTUnwrap(workspace.currentResult)

        let canceledRecord = try await workspace.prepareRecordFileExport()
        workspace.cancel()
        XCTAssertFalse(workspace.isCurrent(canceledRecord))
        XCTAssertThrowsError(try ExportFile(prepared: canceledRecord).validatedData())

        let exporting = Task { try await workspace.prepareImageFileExport(.png) }
        for _ in 0..<100 where !workspace.isPreparingExport {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(workspace.isPreparingExport)
        workspace.cancel()
        do {
            _ = try await exporting.value
            XCTFail("A canceled export returned bytes")
        } catch is CancellationError {
        } catch {
            XCTFail("Expected cancellation, got \(error)")
        }
        XCTAssertFalse(workspace.isPreparingExport)

        let sourceBoundRecord = try await workspace.prepareRecordFileExport()
        XCTAssertTrue(workspace.isCurrent(sourceBoundRecord))
        let photoStage = try IOSImageSourceStaging.stage(from: url)
        workspace.importImage(photoStage, displayName: "replacement.png", removeAfterImport: true)
        for _ in 0..<100 where workspace.sourceName != "replacement.png" {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(workspace.sourceName, "replacement.png")
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoStage.path))
        XCTAssertFalse(workspace.isCurrent(sourceBoundRecord))
        XCTAssertThrowsError(try ExportFile(prepared: sourceBoundRecord).validatedData())

        for _ in 0..<100 where workspace.currentResult == nil {
            try await Task.sleep(for: .milliseconds(20))
        }
        let acceptedJob = try XCTUnwrap(workspace.currentResult).job
        let oversized = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        XCTAssertTrue(FileManager.default.createFile(atPath: oversized.path, contents: nil))
        defer { try? FileManager.default.removeItem(at: oversized) }
        let oversizedHandle = try FileHandle(forWritingTo: oversized)
        try oversizedHandle.truncate(atOffset: UInt64(ImageProcessingLimits.maximumIOSEncodedByteCount) + 1)
        try oversizedHandle.close()
        workspace.importImage(oversized, displayName: "oversized.png")
        for _ in 0..<100 where workspace.isImporting {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(workspace.sourceName, "replacement.png")
        XCTAssertEqual(workspace.currentResult?.job, acceptedJob)
        XCTAssertTrue(workspace.error?.contains("256 MiB") == true)
    }

    func testRegisteredViewportPreservesSourceCoordinatesUnderZoomAndPan() {
        let source = CGSize(width: 4_608, height: 2_592)
        let canvas = CGSize(width: 390, height: 390)
        let initial = RegisteredViewport(source: source, canvas: canvas, zoom: 1, pan: .zero)
        let point = CGPoint(x: 250, y: 195)
        let before = initial.sourcePoint(point)
        let newZoom: CGFloat = 2
        let newPan = initial.zoomedPan(factor: 2, around: point, newZoom: newZoom)
        let zoomed = RegisteredViewport(source: source, canvas: canvas, zoom: newZoom, pan: newPan)
        let after = zoomed.sourcePoint(point)
        XCTAssertEqual(after.x, before.x, accuracy: 0.001)
        XCTAssertEqual(after.y, before.y, accuracy: 0.001)
        let region = SourcePixelRegion(x: 1_000, y: 500, width: 900, height: 600)
        let viewRegion = zoomed.viewRect(region)
        XCTAssertEqual(zoomed.sourcePoint(viewRegion.origin).x, 1_000, accuracy: 0.001)
        XCTAssertEqual(zoomed.sourcePoint(viewRegion.origin).y, 500, accuracy: 0.001)
    }

    func testCorruptIOSStoreIsNotReplaced() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.json")
        let corrupt = Data("{future or corrupt}".utf8)
        try corrupt.write(to: url)
        let store = IOSMethodLibrary(url: url)
        do { _ = try await store.load(); XCTFail("Corrupt store loaded") } catch {}
        do { _ = try await store.replace(.empty); XCTFail("Corrupt store was replaced") } catch {}
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testFirstMutationWritesCanonicalStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.json")
        let store = IOSMethodLibrary(url: url)
        let initial = try await store.load()
        XCTAssertEqual(initial, .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        _ = try await store.replace(.empty)
        XCTAssertEqual(try MethodLibraryDocumentCodec.decode(Data(contentsOf: url)), .empty)
    }

    func testImportReplaceCannotDeleteASecondSpaceWithTheIncomingName() throws {
        let firstID = WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased())
        let secondID = WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased())
        let firstRevision = try WorkingSpaceEditorDraft(libraryName: "First")
            .validatedRevision(identity: firstID, definitionVersion: 1).revision
        let secondRevision = try WorkingSpaceEditorDraft(libraryName: "Second")
            .validatedRevision(identity: secondID, definitionVersion: 1).revision
        let now = Date()
        let first = UserWorkingSpaceItem(libraryName: "First", purpose: nil,
                                         revision: firstRevision, createdAt: now, modifiedAt: now)
        let second = UserWorkingSpaceItem(libraryName: "Second", purpose: nil,
                                          revision: secondRevision, createdAt: now, modifiedAt: now)
        let library = MethodLibrarySnapshot(userWorkingSpaces: [first, second])
        let incoming = IOSMethodImport.space(WorkingSpaceInterchange(
            libraryName: "Second", purpose: nil, revision: firstRevision
        ))

        XCTAssertThrowsError(try IOSLibraryMutation.importValue(incoming, choice: .replace, into: library))
        XCTAssertEqual(library.userWorkingSpaces.count, 2)
    }

    func testMutationBeforeLoadDoesNotOverwriteCorruptStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("library.json")
        let corrupt = Data("{future or corrupt}".utf8)
        try corrupt.write(to: url)
        let store = IOSMethodLibrary(url: url)

        do {
            _ = try await store.replace(.empty)
            XCTFail("A corrupt store was overwritten before its first load")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: url), corrupt)
    }

    func testEncodedSourceBoundRejectsStaticAndGrowingProvider() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("provider.png")
        try Data(repeating: 0x42, count: 6).write(to: source)

        XCTAssertThrowsError(try IOSImageSourceStaging.stageForTest(
            from: source, into: directory, maximumBytes: 4
        )) { XCTAssertEqual($0 as? IOSImageStagingError, .tooLarge) }

        try Data(repeating: 0x42, count: 3).write(to: source)
        XCTAssertThrowsError(try IOSImageSourceStaging.stageForTest(
            from: source, into: directory, maximumBytes: 4, afterChunk: { copied in
                if copied == 2 {
                    let writer = try FileHandle(forWritingTo: source)
                    try writer.seekToEnd()
                    try writer.write(contentsOf: Data(repeating: 0x43, count: 3))
                    try writer.close()
                }
            }
        )) { XCTAssertEqual($0 as? IOSImageStagingError, .tooLarge) }
        XCTAssertEqual(try stagedFiles(in: directory).count, 0)
    }

    func testPartialStageIsRemovedOnErrorAndCancellation() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("provider.png")
        try Data(repeating: 0x42, count: 6).write(to: source)

        enum InjectedFailure: Error { case midCopy }
        XCTAssertThrowsError(try IOSImageSourceStaging.stageForTest(
            from: source, into: directory, maximumBytes: 10,
            afterChunk: { if $0 == 2 { throw InjectedFailure.midCopy } }
        ))
        XCTAssertEqual(try stagedFiles(in: directory).count, 0)

        var checks = 0
        XCTAssertThrowsError(try IOSImageSourceStaging.stageForTest(
            from: source, into: directory, maximumBytes: 10,
            checkCancellation: {
                checks += 1
                if checks >= 3 { throw CancellationError() }
            }
        )) { XCTAssertTrue($0 is CancellationError) }
        XCTAssertEqual(try stagedFiles(in: directory).count, 0)
    }

    func testLaunchRecoveryRemovesOnlyOwnedSourceFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let old = directory.appendingPathComponent("klt-photo-\(UUID().uuidString).heic")
        let current = directory.appendingPathComponent("klt-image-source-\(UUID().uuidString).img")
        let unrelated = directory.appendingPathComponent("notes.tmp")
        let decoy = directory.appendingPathComponent("klt-photo-not-a-uuid.heic")
        for url in [old, current, unrelated, decoy] { try Data([0x42]).write(to: url) }

        IOSImageSourceStaging.removeAbandonedFiles(in: directory)
        XCTAssertFalse(FileManager.default.fileExists(atPath: old.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: current.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: decoy.path))
    }

    private func stagedFiles(in directory: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("klt-image-source-") }
    }
}
