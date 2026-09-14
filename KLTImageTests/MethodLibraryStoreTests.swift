import Foundation
import KLTCore
import XCTest
@testable import KLTImage

final class MethodLibraryStoreTests: XCTestCase {
    func testMissingStoreLoadsAsEmptyWithoutCreatingAFile() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }

        let snapshot = try await MethodLibraryStore(url: url).load()

        XCTAssertEqual(snapshot, .empty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testCorruptAndFutureStoresFailClosedWithoutChangingBytes() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }

        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: url)
        await XCTAssertThrowsErrorAsync(try await MethodLibraryStore(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), corrupt)

        let future = Data(
            "{\"savedTransforms\":[],\"schema\":\"org.kltimage.method-library\",\"userWorkingSpaces\":[],\"version\":2}\n".utf8
        )
        try future.write(to: url)
        await XCTAssertThrowsErrorAsync(try await MethodLibraryStore(url: url).load()) { error in
            XCTAssertEqual(error as? MethodDocumentError, .unsupportedVersion)
        }
        XCTAssertEqual(try Data(contentsOf: url), future)
    }

    func testStoreReplacementIsDurableAndReloadable() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let proposed = try snapshot(count: 2)

        let stored = try await MethodLibraryStore(url: url).replace(with: proposed)
        let reloaded = try await MethodLibraryStore(url: url).load()

        XCTAssertEqual(stored, proposed)
        XCTAssertEqual(reloaded, proposed)
        XCTAssertEqual(try Data(contentsOf: url).last, 0x0A)
        XCTAssertFalse(
            try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .contains { $0.hasPrefix(".klt-method-") }
        )
    }

    func testEveryPrecommitWriteFaultPreservesPriorBytesAndRemovesTemporaryFiles() async throws {
        for checkpoint in MethodFileIO.DurableWriteCheckpoint.allCases where !checkpoint.occursAfterRename {
            let (directory, url) = try temporaryStoreURL()
            defer { try? FileManager.default.removeItem(at: directory) }
            let original = try snapshot(count: 1)
            _ = try await MethodLibraryStore(url: url).replace(with: original)
            let originalBytes = try Data(contentsOf: url)
            let failingStore = MethodLibraryStore(url: url, writeFailure: checkpoint)
            let loaded = try await failingStore.load()
            XCTAssertEqual(loaded, original)

            await XCTAssertThrowsErrorAsync(try await failingStore.replace(with: try snapshot(count: 2))) {
                XCTAssertEqual($0 as? MethodFileIOError, .writeFailed)
            }

            XCTAssertEqual(try Data(contentsOf: url), originalBytes, "Fault at \(checkpoint)")
            XCTAssertFalse(
                try FileManager.default.contentsOfDirectory(atPath: directory.path)
                    .contains { $0.hasPrefix(".klt-method-") },
                "Fault at \(checkpoint) left a temporary file"
            )
        }
    }

    func testEveryPostRenameFaultSurfacesUncertainDurabilityWithACompleteReloadableStore() async throws {
        for checkpoint in MethodFileIO.DurableWriteCheckpoint.allCases where checkpoint.occursAfterRename {
            let (directory, url) = try temporaryStoreURL()
            defer { try? FileManager.default.removeItem(at: directory) }
            let original = try snapshot(count: 1)
            let proposed = try snapshot(count: 2)
            _ = try await MethodLibraryStore(url: url).replace(with: original)
            let failingStore = MethodLibraryStore(url: url, writeFailure: checkpoint)
            let initiallyLoaded = try await failingStore.load()
            XCTAssertEqual(initiallyLoaded, original)

            await XCTAssertThrowsErrorAsync(try await failingStore.replace(with: proposed)) {
                XCTAssertEqual($0 as? MethodFileIOError, .writeFailed)
                XCTAssertTrue($0.localizedDescription.contains("durable save could not be confirmed"))
            }

            XCTAssertEqual(
                try Data(contentsOf: url),
                try MethodLibraryDocumentCodec.data(for: proposed),
                "A post-rename fault at \(checkpoint) must expose only the complete replacement"
            )
            let recovered = try await MethodLibraryStore(url: url).load()
            XCTAssertEqual(
                recovered,
                proposed,
                "A fresh process must recover a valid complete store after \(checkpoint)"
            )
            XCTAssertFalse(
                try FileManager.default.contentsOfDirectory(atPath: directory.path)
                    .contains { $0.hasPrefix(".klt-method-") },
                "Fault at \(checkpoint) left a temporary file"
            )
        }
    }

    func testBoundedReaderRejectsOversizeDirectoryAndSymbolicLink() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let regular = directory.appendingPathComponent("method.json")
        let link = directory.appendingPathComponent("method-link.json")
        try Data("123456789".utf8).write(to: regular)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: regular)

        XCTAssertThrowsError(try MethodFileIO.readRegularFile(at: regular, maximumByteCount: 8)) {
            XCTAssertEqual($0 as? MethodDocumentError, .oversized)
        }
        XCTAssertThrowsError(try MethodFileIO.readRegularFile(at: directory, maximumByteCount: 32)) {
            XCTAssertEqual($0 as? MethodFileIOError, .notRegularFile)
        }
        XCTAssertThrowsError(try MethodFileIO.readRegularFile(at: link, maximumByteCount: 32)) {
            XCTAssertEqual($0 as? MethodFileIOError, .notRegularFile)
        }
        XCTAssertEqual(
            try MethodFileIO.readRegularFile(at: regular, maximumByteCount: 9),
            Data("123456789".utf8)
        )
    }

    func testFiveHundredItemLibraryLoadsUnderOneSecond() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let proposed = try snapshot(count: 500)
        _ = try await MethodLibraryStore(url: url).replace(with: proposed)

        let start = CFAbsoluteTimeGetCurrent()
        let loaded = try await MethodLibraryStore(url: url).load()
        let duration = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(loaded.userWorkingSpaces.count, 500)
        XCTAssertLessThan(duration, 1, "500-item library load took \(duration) seconds")
    }

    @MainActor
    func testModelRejectsSameIdentityAndVersionWithDifferentMathematics() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let original = try snapshot(count: 1)
        let store = MethodLibraryStore(url: url)
        _ = try await store.replace(with: original)
        let model = MethodLibraryModel(store: store)
        await waitUntilLoaded(model)
        let existing = try XCTUnwrap(model.snapshot.userWorkingSpaces.first)
        let conflictingRevision = try WorkingSpaceValidator.makeRevision(
            identity: existing.revision.identity,
            definitionVersion: existing.revision.definitionVersion,
            base: .encodedSRGB,
            workingChannelNames: existing.revision.workingChannelNames,
            forwardValues: Matrix3x3.diagonal(SIMD3(2, 1, 1)).rowMajorValues,
            offsetValues: [0, 0, 0]
        ).revision
        model.pendingImport = .workingSpace(WorkingSpaceInterchange(
            libraryName: existing.libraryName,
            purpose: existing.purpose,
            revision: conflictingRevision
        ))

        await model.commitPendingImport(.replace)

        XCTAssertEqual(model.snapshot, original)
        XCTAssertNotNil(model.pendingImport)
        XCTAssertTrue(model.operationError?.contains("same working-space identity and version") == true)
    }

    @MainActor
    func testModelPersistenceFailureLeavesPriorSnapshotUntouched() async throws {
        let model = MethodLibraryModel(
            store: MethodLibraryStore(url: URL(fileURLWithPath: "/dev/null/library.json"))
        )
        await waitUntilLoaded(model)
        let before = model.snapshot

        do {
            _ = try await model.saveNewSpace(WorkingSpaceEditorDraft(libraryName: "Unsaved space"))
            XCTFail("Expected persistence to fail")
        } catch {
            // Expected: /dev/null cannot contain the library's atomic temporary file.
        }

        XCTAssertEqual(model.snapshot, before)
        XCTAssertNotNil(model.operationError)
    }

    @MainActor
    func testModelReportsUnsavedOutcomeAndKeepsItsLastAcceptedSnapshotAtEveryWriteBoundary() async throws {
        for checkpoint in MethodFileIO.DurableWriteCheckpoint.allCases {
            let (directory, url) = try temporaryStoreURL()
            defer { try? FileManager.default.removeItem(at: directory) }
            let original = try snapshot(count: 1)
            _ = try await MethodLibraryStore(url: url).replace(with: original)
            let model = MethodLibraryModel(
                store: MethodLibraryStore(url: url, writeFailure: checkpoint)
            )
            await waitUntilLoaded(model)

            do {
                _ = try await model.saveNewSpace(
                    WorkingSpaceEditorDraft(libraryName: "Unsaved \(checkpoint)")
                )
                XCTFail("Expected the save to fail at \(checkpoint)")
            } catch {
                XCTAssertEqual(error as? MethodFileIOError, .writeFailed)
            }

            XCTAssertEqual(model.snapshot, original, "Model accepted a failed save at \(checkpoint)")
            XCTAssertTrue(
                model.operationError?.contains("durable save could not be confirmed") == true,
                "No user-visible durability error was recorded at \(checkpoint)"
            )
        }
    }

    @MainActor
    func testModelRejectsOverlappingMutations() async throws {
        let (directory, url) = try temporaryStoreURL()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MethodLibraryStore(url: url)
        _ = try await store.replace(with: try snapshot(count: 500))
        let model = MethodLibraryModel(store: store)
        await waitUntilLoaded(model)
        let first = Task {
            try await model.saveNewSpace(WorkingSpaceEditorDraft(libraryName: "First mutation"))
        }
        for _ in 0..<100 where !model.isMutating { await Task.yield() }

        do {
            _ = try await model.saveNewSpace(WorkingSpaceEditorDraft(libraryName: "Second mutation"))
            XCTFail("Expected the overlapping mutation to be rejected")
        } catch {
            XCTAssertEqual(error as? MethodLibraryOperationError, .operationInProgress)
        }
        _ = try await first.value
        XCTAssertEqual(model.snapshot.userWorkingSpaces.count, 501)
    }

    private func temporaryStoreURL() throws -> (URL, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, directory.appendingPathComponent("library.json"))
    }

    private func snapshot(count: Int) throws -> MethodLibrarySnapshot {
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000.123)
        let spaces = try (0..<count).map { index in
            let identifier = String(format: "00000000-0000-0000-0000-%012x", index + 1)
            let revision = try WorkingSpaceValidator.makeRevision(
                identity: WorkingSpaceIdentity(kind: .user, identifier: identifier),
                definitionVersion: 1,
                base: .encodedSRGB,
                workingChannelNames: ["one", "two", "three"],
                forwardValues: Matrix3x3.identity.rowMajorValues,
                offsetValues: [0, 0, 0]
            ).revision
            return UserWorkingSpaceItem(
                libraryName: "Space \(index + 1)",
                purpose: nil,
                revision: revision,
                createdAt: timestamp,
                modifiedAt: timestamp
            )
        }
        return MethodLibrarySnapshot(userWorkingSpaces: spaces)
    }

    @MainActor
    private func waitUntilLoaded(_ model: MethodLibraryModel) async {
        for _ in 0..<1_000 where model.isLoading { await Task.yield() }
        XCTAssertFalse(model.isLoading)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in },
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
