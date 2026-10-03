import Darwin
import Foundation
import KLTCore

struct BatchTemporaryReceipt: Codable, Equatable, Sendable {
    let ownerToken: UUID
    let temporaryBasename: String
    let reservedBytes: Int
}

/// All mutable quota/receipt state is locked, including provider callback writes.
/// Reservations are upper bounds made before creation, so a crash can overcount
/// external files but cannot make the next process undercount them.
final class BatchStorage: @unchecked Sendable {
    private struct Document: Codable {
        let schema: String
        let version: Int
        let entries: [BatchTemporaryReceipt]
    }
    static let shared: Result<BatchStorage, Error> = Result { try BatchStorage() }
    let root: URL
    private let receiptURL: URL
    private let lock = NSRecursiveLock()
    private var external: [BatchTemporaryReceipt] = []
    private var privateReservations: [String: Int] = [:]
    private var fault: Error?
    private let limit: Int

    init(base: URL? = nil, limit: Int = BatchLimits.current.temporaryBytes) throws {
        self.limit = limit
        let support = base ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KLTBatchHousekeeping", isDirectory: true)
        root = support.appendingPathComponent("Staging", isDirectory: true)
        receiptURL = support.appendingPathComponent("temporary-reservations.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        for var directory in [support, root] {
            let fd = try BatchIO.openDirectory(directory); close(fd)
            var values = URLResourceValues(); values.isExcludedFromBackup = true
            try directory.setResourceValues(values)
        }
        if FileManager.default.fileExists(atPath: receiptURL.path) {
            let bytes = try MethodFileIO.readRegularFile(at: receiptURL, maximumByteCount: 256 * 1_024)
            let document = try JSONDecoder().decode(Document.self, from: bytes)
            guard document.schema == "org.kltimage.batch-temporary-reservations", document.version == 1,
                  document.entries.count <= 256 else { throw BatchFailure.shared("Temporary cleanup information cannot be read. Keep it intact and contact support.") }
            var seen: Set<String> = []; var total = 0
            for entry in document.entries {
                guard BatchNames.validTemporary(entry.temporaryBasename, owner: entry.ownerToken),
                      seen.insert(entry.temporaryBasename).inserted,
                      entry.reservedBytes >= 0, entry.reservedBytes <= limit,
                      entry.reservedBytes <= limit - total else { throw BatchFailure.shared("Temporary cleanup information is invalid. Keep it intact and contact support.") }
                total += entry.reservedBytes
            }
            external = document.entries
        }
        // Only our randomized direct children. A mismatching file is retained;
        // recognized but nonregular material blocks use instead of following it.
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            guard Self.privateName(url.lastPathComponent) else { continue }
            var info = stat()
            guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
                  unlink(url.path) == 0 else { throw BatchFailure.shared("Private batch temporary files could not be cleaned up. Free storage and reopen KLT Image.") }
        }
    }
    var receipts: [BatchTemporaryReceipt] { lock.withLock { external } }
    var debt: Int { lock.withLock { external.reduce(0) { $0 + $1.reservedBytes } } }
    func requireRoom(_ bytes: Int) throws {
        try lock.withLock {
            if let fault { throw fault }
            let used = external.reduce(0) { $0 + $1.reservedBytes } + privateReservations.values.reduce(0, +)
            guard bytes >= 0, bytes <= limit - used else {
                throw BatchFailure.shared("Temporary storage limit reached. Clean up unfinished temporary output before starting again.")
            }
        }
    }
    func makePrivate(reserving bytes: Int) throws -> URL {
        try lock.withLock {
            try requireRoom(bytes)
            let name = "batch-\(UUID().uuidString).tmp"
            let url = root.appendingPathComponent(name)
            let fd = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard fd >= 0 else { throw BatchFailure.shared("Private temporary storage is unavailable. Free storage and try again.") }
            close(fd); privateReservations[name] = bytes
            return url
        }
    }
    func shrinkPrivate(_ url: URL, to bytes: Int) throws {
        try lock.withLock {
            guard let old = privateReservations[url.lastPathComponent], bytes >= 0, bytes <= old else {
                throw BatchFailure.shared("Temporary storage accounting failed. Stop and reopen the batch.")
            }
            privateReservations[url.lastPathComponent] = bytes
        }
    }
    func removePrivate(_ url: URL) throws {
        try lock.withLock {
            guard url.deletingLastPathComponent() == root, privateReservations[url.lastPathComponent] != nil else {
                throw BatchFailure.shared("An unrecognized temporary file was retained.")
            }
            guard unlink(url.path) == 0 || errno == ENOENT else {
                throw BatchFailure.shared("A private temporary file could not be removed. No more images will start.")
            }
            privateReservations.removeValue(forKey: url.lastPathComponent)
        }
    }
    func reserveExternal(owner: UUID, name: String, bytes: Int) throws {
        try lock.withLock {
            try requireRoom(bytes)
            guard external.count < 256, BatchNames.validTemporary(name, owner: owner),
                  !external.contains(where: { $0.temporaryBasename == name }) else {
                throw BatchFailure.shared("Too many unfinished temporary files. Select their run folders for cleanup.")
            }
            external.append(.init(ownerToken: owner, temporaryBasename: name, reservedBytes: bytes))
            try persist()
        }
    }
    func clearExternal(_ name: String) throws {
        try lock.withLock {
            let previous = external
            external.removeAll { $0.temporaryBasename == name }
            do { try persist() } catch { external = previous; throw error }
        }
    }
    private func persist() throws {
        do {
            let bytes = try JSONEncoder().encode(Document(schema: "org.kltimage.batch-temporary-reservations", version: 1, entries: external))
            guard bytes.count <= 256 * 1_024 else { throw BatchFailure.shared("Temporary cleanup information reached its limit.") }
            try MethodFileIO.durableAtomicWrite(bytes, to: receiptURL)
        } catch {
            let failure = BatchFailure.shared("Temporary cleanup information could not be saved. No more images will start.")
            fault = failure; throw failure
        }
    }
    func cleanupReselected(_ grant: BatchFolderGrant) throws -> Int {
        let matches = receipts.filter { grant.url.lastPathComponent.hasPrefix("KLT Batch ") && grant.url.lastPathComponent.hasSuffix(" " + $0.ownerToken.uuidString) }
        guard !matches.isEmpty else { throw BatchFailure.shared("This is not the associated run folder. Nothing was removed. \(debt) bytes remain reserved.") }
        var released = 0
        try BatchIO.coordinateWrite(grant.url) { url in
            let fd = try BatchIO.openDirectory(url); defer { close(fd) }
            for entry in matches {
                var info = stat()
                let exists = fstatat(fd, entry.temporaryBasename, &info, AT_SYMLINK_NOFOLLOW)
                if exists != 0 {
                    guard errno == ENOENT else { throw BatchFailure.shared("The temporary file could not be verified. Its reservation is retained.") }
                } else {
                    guard info.st_mode & S_IFMT == S_IFREG, info.st_size >= 0,
                          info.st_size <= entry.reservedBytes else { throw BatchFailure.shared("A temporary file no longer matches its receipt. Nothing further was removed.") }
                    guard unlinkat(fd, entry.temporaryBasename, 0) == 0 else { throw BatchFailure.shared("Temporary output could not be removed. Its reservation is retained.") }
                }
                try clearExternal(entry.temporaryBasename); released += entry.reservedBytes
            }
        }
        return released
    }
    private static func privateName(_ name: String) -> Bool {
        name.hasPrefix("batch-") && name.hasSuffix(".tmp") && UUID(uuidString: String(name.dropFirst(6).dropLast(4))) != nil
    }
}

/// Owns one explicit picker grant. No bookmark is created. The run retains this
/// lease through all callbacks and outcome review; replacing setup releases it.
final class BatchFolderGrant: @unchecked Sendable {
    let url: URL
    private let scoped: Bool
    init(_ url: URL) throws {
        scoped = url.startAccessingSecurityScopedResource()
        guard scoped || BatchIO.isContainerURL(url) else {
            throw BatchFailure.shared("The folder permission is unavailable. Choose the folder again.")
        }
        self.url = url
    }
    deinit { if scoped { url.stopAccessingSecurityScopedResource() } }
}

struct BatchFileSource: BatchSource {
    let url: URL
    func acquire(storage: BatchStorage, limits: BatchLimits, stop: BatchStop) async throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard scoped || BatchIO.isContainerURL(url) else { throw BatchFailure.item("Image access was lost. Select this image again.") }
        return try BatchIO.coordinateRead(url, stop: stop) { coordinated in
            try BatchIO.stage(coordinated, storage: storage, limit: limits.sourceBytes, stop: stop)
        }
    }
}

enum BatchIO {
    static func isContainerURL(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let roots = [NSHomeDirectory(), FileManager.default.temporaryDirectory.path]
        return roots.contains { path.hasPrefix($0.hasSuffix("/") ? $0 : $0 + "/") }
    }
    static func openDirectory(_ url: URL) throws -> Int32 {
        guard url.isFileURL else { throw BatchFailure.shared("Choose a supported local or Files folder.") }
        var fd = open("/", O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard fd >= 0 else { throw BatchFailure.shared("The folder could not be opened.") }
        for component in url.pathComponents.dropFirst() {
            let next = openat(fd, component, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            close(fd)
            guard next >= 0 else { throw BatchFailure.shared("The folder is unavailable or contains a symbolic link. Choose another folder.") }
            fd = next
        }
        return fd
    }
    static func coordinateRead<T>(_ url: URL, stop: BatchStop? = nil, action: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(); var error: NSError?; var result: Result<T, Error>?
        stop?.attachCoordinator(coordinator); defer { stop?.attachCoordinator(nil) }
        coordinator.coordinate(readingItemAt: url, options: [], error: &error) { accessor in result = Result { try action(accessor) } }
        if let error { throw error }
        guard let result else { throw BatchFailure.item("The source provider did not supply a complete file.") }
        return try result.get()
    }
    static func coordinateWrite<T>(_ url: URL, stop: BatchStop? = nil, action: (URL) throws -> T) throws -> T {
        let coordinator = NSFileCoordinator(); var error: NSError?; var result: Result<T, Error>?
        stop?.attachCoordinator(coordinator); defer { stop?.attachCoordinator(nil) }
        coordinator.coordinate(writingItemAt: url, options: .forMerging, error: &error) { accessor in result = Result { try action(accessor) } }
        if let error { throw error }
        guard let result else { throw BatchFailure.shared("The destination provider did not authorize a write.") }
        return try result.get()
    }
    static func write(_ bytes: UnsafeRawBufferPointer, to fd: Int32) throws {
        guard var pointer = bytes.baseAddress else { return }
        var remaining = bytes.count
        while remaining > 0 {
            let count = Darwin.write(fd, pointer, remaining)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw BatchFailure.shared("Storage could not accept the output. Free space or choose another destination.") }
            remaining -= count; pointer = pointer.advanced(by: count)
        }
    }
    static func sync(_ fd: Int32) throws {
        while fsync(fd) != 0 {
            if errno != EINTR { throw BatchFailure.shared("The destination cannot confirm a complete write. Choose another folder.") }
        }
    }
    static func same(_ a: stat, _ b: stat) -> Bool { a.st_dev == b.st_dev && a.st_ino == b.st_ino }
    static func stage(_ source: URL, storage: BatchStorage, limit: Int, stop: BatchStop,
                      afterChunk: (Int) throws -> Void = { _ in }) throws -> URL {
        let target = try storage.makePrivate(reserving: limit)
        do {
            let fd = open(target.path, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
            guard fd >= 0 else { throw BatchFailure.shared("Temporary storage is unavailable.") }
            defer { close(fd) }
            let size = try copy(source, to: fd, limit: limit, stop: stop, afterChunk: afterChunk)
            try storage.shrinkPrivate(target, to: size)
            return target
        } catch {
            try storage.removePrivate(target)
            throw error
        }
    }
    static func copy(_ source: URL, to output: Int32, limit: Int, stop: BatchStop,
                     afterChunk: (Int) throws -> Void = { _ in }) throws -> Int {
        try stop.check()
        let input = open(source.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
        guard input >= 0 else { throw BatchFailure.item("The source is unavailable. Choose the complete original again.") }
        defer { close(input) }
        var before = stat()
        guard fstat(input, &before) == 0, before.st_mode & S_IFMT == S_IFREG else {
            throw BatchFailure.item("Choose a complete regular image file, not a folder, link, or special file.")
        }
        guard before.st_size >= 0, before.st_size <= limit else {
            throw BatchFailure.item("The image exceeds the \(limit / 1_048_576) MiB encoded-source limit.")
        }
        var buffer = [UInt8](repeating: 0, count: 65_536); var total = 0
        while true {
            try stop.check()
            let count = read(input, &buffer, min(buffer.count, limit - total + 1))
            if count < 0 && errno == EINTR { continue }
            guard count >= 0 else { throw BatchFailure.item("The complete source could not be read. Select it again.") }
            if count == 0 { break }
            guard count <= limit - total else { throw BatchFailure.item("The image exceeds the \(limit / 1_048_576) MiB encoded-source limit.") }
            try stop.check()
            try buffer.withUnsafeBytes { try write(UnsafeRawBufferPointer(rebasing: $0[..<count]), to: output) }
            total += count; try afterChunk(total)
        }
        var after = stat(); var path = stat()
        guard fstat(input, &after) == 0, lstat(source.path, &path) == 0,
              same(before, after), same(before, path), path.st_mode & S_IFMT == S_IFREG,
              total == before.st_size, before.st_size == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec,
              before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec,
              before.st_ctimespec.tv_sec == after.st_ctimespec.tv_sec,
              before.st_ctimespec.tv_nsec == after.st_ctimespec.tv_nsec else {
            throw BatchFailure.item("The source changed while being acquired. Select it again.")
        }
        try stop.check(); try sync(output)
        return total
    }
    static func capacity(_ url: URL, pending: Int, stop: BatchStop? = nil) throws {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        var available = values?.volumeAvailableCapacityForImportantUsage ?? values?.volumeAvailableCapacity.map(Int64.init)
        #if DEBUG
        if let capacity = stop?.testFaults?.capacity { available = capacity(url, pending) }
        #endif
        if let available, available < Int64(pending + BatchLimits.capacityReserve) {
            throw BatchFailure.shared("Not enough destination space. Free space or choose another folder; 64 MiB must remain available.")
        }
    }
}

/// Presentation only. URLs remain unchanged for grants and all filesystem work.
/// Provider storage roots and opaque identifiers are never useful location names.
enum BatchDestinationLabel {
    static func resolve(_ url: URL) -> String {
        let localized = try? url.resourceValues(forKeys: [.localizedNameKey]).localizedName
        return describe(basename: url.lastPathComponent, localizedName: localized)
    }
    static func describe(basename: String, localizedName: String?) -> String {
        for candidate in [localizedName, basename].compactMap({ $0 }) {
            let name = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.unicodeScalars.count <= 255,
                  !name.contains("/"), !name.contains("\\"),
                  !name.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                  UUID(uuidString: name) == nil,
                  !["file provider storage", "appgroup", "containers", "shared", ".", ".."].contains(name.lowercased()) else { continue }
            return name
        }
        #if os(iOS)
        return "Selected Files folder"
        #else
        return "Selected folder"
        #endif
    }
}
