import Darwin
import Foundation
import KLTCore

struct BatchCommitReceipt {
    var imageName: String?
    var recordName: String?
    var imageIdentity: stat?
}

/// The serial worker owns this descriptor. Every coordinated operation verifies
/// both the accessor URL and descriptor identity before descriptor-relative IO.
final class BatchPublisher {
    let url: URL
    let owner: UUID
    private let fd: Int32
    private let identity: stat
    private let storage: BatchStorage
    private let stop: BatchStop
    private var temporary: Set<String> = []
    private var temporaryIdentities: [String: stat] = [:]

    init(request: BatchRunRequest, storage: BatchStorage, stop: BatchStop) throws {
        self.owner = request.id; self.storage = storage; self.stop = stop
        var createdURL: URL?; var createdFD: Int32 = -1; var createdInfo = stat()
        try stop.check()
        try BatchIO.capacity(request.destination.url, pending: 0, stop: stop)
        do { try BatchIO.coordinateWrite(request.destination.url, stop: stop) { parentURL in
            let parent = try BatchIO.openDirectory(parentURL); defer { close(parent) }
            try stop.admit()
            var candidate = request.folderName
            var made = false
            for attempt in 0..<16 {
                if attempt > 0 { candidate = request.folderName.replacingOccurrences(of: " \(request.id.uuidString)", with: " \(UUID().uuidString.prefix(8)) \(request.id.uuidString)") }
                if mkdirat(parent, candidate, 0o700) == 0 { made = true; break }
                guard errno == EEXIST else { break }
            }
            guard made else {
                throw BatchFailure.shared("A new run folder could not be created. Choose the folder again and start a new batch.")
            }
            createdURL = parentURL.appendingPathComponent(candidate, isDirectory: true)
            createdFD = openat(parent, candidate, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            guard createdFD >= 0, fstat(createdFD, &createdInfo) == 0 else {
                if createdFD >= 0 { close(createdFD); createdFD = -1 }
                _ = unlinkat(parent, candidate, AT_REMOVEDIR)
                throw BatchFailure.shared("The new run folder could not be opened safely.")
            }
        }
        } catch {
            if createdFD >= 0 {
                if let createdURL {
                    var path = stat()
                    if lstat(createdURL.path, &path) == 0, BatchIO.same(path, createdInfo) { _ = rmdir(createdURL.path) }
                }
                close(createdFD)
            }
            throw error
        }
        guard let createdURL, createdFD >= 0 else { throw BatchFailure.shared("The destination provider cannot create a run folder.") }
        url = createdURL; fd = createdFD; identity = createdInfo
        do { try probe() } catch {
            try? cleanup()
            removeIfEmpty()
            throw error
        }
    }
    deinit { close(fd) }
    private func verify(_ accessor: URL) throws {
        guard accessor.standardizedFileURL == url.standardizedFileURL else {
            throw BatchFailure.shared("The destination moved during saving. Select it again.")
        }
        let current = try BatchIO.openDirectory(accessor); defer { close(current) }
        var details = stat(); var held = stat()
        guard fstat(current, &details) == 0, fstat(fd, &held) == 0,
              BatchIO.same(details, identity), BatchIO.same(held, identity) else {
            throw BatchFailure.shared("The destination folder changed. No further output was saved.")
        }
    }
    private func reserve(_ bytes: Int) throws -> String {
        let name = BatchNames.temporary(owner: owner)
        try storage.reserveExternal(owner: owner, name: name, bytes: bytes)
        temporary.insert(name)
        return name
    }
    private func create(_ name: String) throws -> Int32 {
        let result = openat(fd, name, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard result >= 0 else { throw BatchFailure.shared("The destination cannot create a temporary output file. Choose another folder.") }
        var info = stat()
        guard fstat(result, &info) == 0 else { close(result); throw BatchFailure.shared("Temporary ownership could not be verified.") }
        temporaryIdentities[name] = info
        return result
    }
    private func probe() throws {
        try BatchIO.coordinateWrite(url) { accessor in
            try verify(accessor)
            let first = try reserve(1); let sentinel = try reserve(1); let moved = try reserve(1)
            for name in [first, sentinel] {
                let file = try create(name)
                do { try Data([42]).withUnsafeBytes { try BatchIO.write($0, to: file) }; try BatchIO.sync(file) }
                catch { close(file); throw error }
                guard close(file) == 0 else { throw BatchFailure.shared("The destination cannot close a complete file.") }
            }
            guard renameatx_np(fd, first, fd, moved, UInt32(RENAME_EXCL)) == 0 else {
                throw BatchFailure.shared("This destination does not support safe exclusive saves. Choose another folder.")
            }
            temporaryIdentities[moved] = temporaryIdentities.removeValue(forKey: first)
            temporary.remove(first); try storage.clearExternal(first)
            var before = stat(); _ = fstatat(fd, sentinel, &before, AT_SYMLINK_NOFOLLOW)
            guard renameatx_np(fd, moved, fd, sentinel, UInt32(RENAME_EXCL)) != 0, errno == EEXIST else {
                throw BatchFailure.shared("This destination cannot guarantee that existing files stay unchanged. Choose another folder.")
            }
            var after = stat(); var kept = stat()
            guard fstatat(fd, sentinel, &after, AT_SYMLINK_NOFOLLOW) == 0,
                  fstatat(fd, moved, &kept, AT_SYMLINK_NOFOLLOW) == 0,
                  BatchIO.same(before, after), after.st_size == 1, kept.st_size == 1 else {
                throw BatchFailure.shared("The destination's exclusive-save check failed. Choose another folder.")
            }
            try BatchIO.sync(fd)
        }
        try cleanup()
    }
    func publish(image: URL, imageBytes: Int, record: URL?, recordBytes: Int,
                 entry: BatchInputEntry, ordinal: Int, format: ImageExportFormat,
                 authorize: () throws -> Void, receipt: inout BatchCommitReceipt,
                 checkpoint: (String) throws -> Void = { _ in }) throws {
        let pending = imageBytes + recordBytes
        try BatchIO.capacity(url, pending: pending, stop: stop)
        try storage.requireRoom(pending)
        let imageStage = try stage(image, bytes: imageBytes)
        let recordStage = try record.map { try stage($0, bytes: recordBytes) }
        let nameMax = fpathconf(fd, _PC_NAME_MAX)
        let limit = nameMax > 0 ? min(Int(nameMax), 240) : 120
        for attempt in 0..<24 {
            try authorize()
            let suffix = attempt == 0 ? "" : "-" + UUID().uuidString.prefix(8)
            let stem = BatchNames.stem(entry.name, ordinal: ordinal, suffix: suffix, limit: limit)
            let imageName = stem + "." + format.filenameExtension
            let recordName = stem + "-analysis.json"
            var occupied = stat()
            if fstatat(fd, imageName, &occupied, AT_SYMLINK_NOFOLLOW) == 0 ||
                (recordStage != nil && fstatat(fd, recordName, &occupied, AT_SYMLINK_NOFOLLOW) == 0) { continue }
            try checkpoint("beforeImage")
            do {
                let old = receipt.imageName ?? imageStage
                try move(old, to: imageName, authorize: authorize, expected: receipt.imageIdentity) { info in
                    receipt.imageName = imageName; receipt.imageIdentity = info
                }
            } catch let error as POSIXError where error.code == .EEXIST { continue }
            try checkpoint("afterImage")
            if let recordStage {
                do {
                    try move(recordStage, to: recordName, authorize: authorize) { _ in receipt.recordName = recordName }
                } catch let error as POSIXError where error.code == .EEXIST { continue }
                try checkpoint("afterRecord")
            }
            return
        }
        throw BatchFailure.shared("The destination keeps changing output names. Saved images remain; choose a stable folder for another batch.")
    }
    private func stage(_ source: URL, bytes: Int) throws -> String {
        try stop.check()
        let name = try reserve(bytes)
        try BatchIO.coordinateWrite(url, stop: stop) { accessor in
            try verify(accessor); try BatchIO.capacity(accessor, pending: bytes, stop: stop)
            let file = try create(name)
            do { _ = try BatchIO.copy(source, to: file, limit: bytes, stop: stop) }
            catch { close(file); throw BatchFailure.shared("The destination could not save temporary output: \(error.localizedDescription)") }
            guard close(file) == 0 else { throw BatchFailure.shared("The destination could not close the output file.") }
        }
        return name
    }
    private func move(_ old: String, to new: String, authorize: () throws -> Void,
                      expected: stat? = nil, committed: (stat) -> Void) throws {
        let coordinator = NSFileCoordinator()
        stop.attachCoordinator(coordinator); defer { stop.attachCoordinator(nil) }
        var coordinationError: NSError?; var operationError: Error?
        let source = url.appendingPathComponent(old); let target = url.appendingPathComponent(new)
        coordinator.coordinate(writingItemAt: source, options: .forMoving,
                               writingItemAt: target, options: .forReplacing, error: &coordinationError) { from, to in
            do {
                try verify(from.deletingLastPathComponent()); try verify(to.deletingLastPathComponent())
                guard from.lastPathComponent == old, to.lastPathComponent == new else {
                    throw BatchFailure.shared("The provider changed an output name unexpectedly.")
                }
                var info = stat()
                guard fstatat(fd, old, &info, AT_SYMLINK_NOFOLLOW) == 0, info.st_mode & S_IFMT == S_IFREG,
                      (expected ?? temporaryIdentities[old]).map({ BatchIO.same($0, info) }) == true else {
                    throw BatchFailure.shared("An output changed before publication. It was left untouched.")
                }
                try BatchIO.capacity(url, pending: Int(info.st_size), stop: stop)
                try authorize(); try stop.admit()
                coordinator.item(at: from, willMoveTo: to)
                guard renameatx_np(fd, old, fd, new, UInt32(RENAME_EXCL)) == 0 else {
                    if errno == EEXIST { throw POSIXError(.EEXIST) }
                    throw BatchFailure.shared("The destination cannot publish this complete file safely. Choose another folder.")
                }
                // Commit evidence must precede cancellation checks, notifications,
                // receipt persistence or directory synchronization, all of which can fail.
                committed(info)
                coordinator.item(at: from, didMoveTo: to)
                if temporary.remove(old) != nil { temporaryIdentities.removeValue(forKey: old); try storage.clearExternal(old) }
                try BatchIO.sync(fd)
            } catch { operationError = error }
        }
        if let operationError { throw operationError }
        if let coordinationError { throw coordinationError }
    }
    func cleanup() throws {
        try BatchIO.coordinateWrite(url) { accessor in
            try verify(accessor)
            for name in temporary.sorted() {
                guard let receipt = storage.receipts.first(where: { $0.temporaryBasename == name }) else { continue }
                var info = stat()
                if fstatat(fd, name, &info, AT_SYMLINK_NOFOLLOW) == 0 {
                    guard let owned = temporaryIdentities[name], BatchIO.same(info, owned),
                          info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0, info.st_size <= receipt.reservedBytes,
                          unlinkat(fd, name, 0) == 0 else {
                        throw BatchFailure.shared("Temporary output needs cleanup. Select this run folder to release its storage reservation.")
                    }
                } else if errno != ENOENT { throw BatchFailure.shared("Temporary output could not be verified for cleanup.") }
                try storage.clearExternal(name); temporary.remove(name); temporaryIdentities.removeValue(forKey: name)
            }
        }
    }
    func removeIfEmpty() {
        try? BatchIO.coordinateWrite(url) { accessor in
            try verify(accessor)
            // rmdir is atomic and refuses nonempty directories, including unrelated files.
            _ = rmdir(accessor.path)
        }
    }
}
