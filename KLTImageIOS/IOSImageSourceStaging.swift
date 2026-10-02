import Darwin
import Foundation
import KLTCore

enum IOSImageStagingError: LocalizedError, Equatable {
    case tooLarge
    case sourceChanged
    case notRegularFile

    var errorDescription: String? {
        switch self {
        case .tooLarge:
            "This image exceeds the 256 MiB encoded-file limit. Choose a smaller original. Current work is unchanged."
        case .sourceChanged:
            "The image changed while it was opening. Try choosing it again. Current work is unchanged."
        case .notRegularFile:
            "The selected image is not a complete regular file. Choose another original. Current work is unchanged."
        }
    }
}

final class IOSStagingCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock(); defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        cancelled = true
    }

    func check() throws {
        if isCancelled { throw CancellationError() }
    }
}

/// Both picker paths are copied through this counted stream before ImageIO
/// receives a stable app-owned URL. The provider URL is never decoded in place.
enum IOSImageSourceStaging {
    private static let prefix = "klt-image-source-"
    private static let legacyPrefix = "klt-photo-"
    private static let chunkSize = 1_048_576

    static func stage(
        from source: URL, checkCancellation: () throws -> Void = { try Task.checkCancellation() }
    ) throws -> URL {
        try copy(from: source, into: FileManager.default.temporaryDirectory,
                 maximumBytes: ImageProcessingLimits.maximumIOSEncodedByteCount,
                 chunkSize: chunkSize, checkCancellation: checkCancellation, afterChunk: { _ in })
    }

    static func removeAbandonedFiles() {
        sweep(in: FileManager.default.temporaryDirectory)
    }

    static func validateOwnedStage(_ url: URL) throws {
        let temporary = FileManager.default.temporaryDirectory.standardizedFileURL
        guard url.deletingLastPathComponent().standardizedFileURL == temporary,
              isOwnedName(url.lastPathComponent) else {
            throw IOSImageStagingError.notRegularFile
        }
        let input = try openInput(url)
        defer { try? input.close() }
        var details = stat()
        guard fstat(input.fileDescriptor, &details) == 0,
              details.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw IOSImageStagingError.notRegularFile
        }
        guard details.st_size >= 0,
              details.st_size <= ImageProcessingLimits.maximumIOSEncodedByteCount else {
            throw IOSImageStagingError.tooLarge
        }
    }

    #if DEBUG
    static func stageForTest(
        from source: URL, into directory: URL, maximumBytes: Int,
        chunkSize: Int = 2, checkCancellation: () throws -> Void = {},
        afterChunk: (Int) throws -> Void = { _ in }
    ) throws -> URL {
        try copy(from: source, into: directory, maximumBytes: maximumBytes,
                 chunkSize: chunkSize, checkCancellation: checkCancellation, afterChunk: afterChunk)
    }

    static func removeAbandonedFiles(in directory: URL) { sweep(in: directory) }
    #endif

    private static func copy(
        from source: URL, into directory: URL, maximumBytes: Int, chunkSize: Int,
        checkCancellation: () throws -> Void, afterChunk: (Int) throws -> Void
    ) throws -> URL {
        precondition(maximumBytes > 0 && chunkSize > 0)
        try checkCancellation()
        let input = try openInput(source)
        defer { try? input.close() }
        var before = stat()
        guard fstat(input.fileDescriptor, &before) == 0,
              before.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG) else {
            throw IOSImageStagingError.notRegularFile
        }
        guard before.st_size >= 0, before.st_size <= maximumBytes else {
            throw IOSImageStagingError.tooLarge
        }

        let destination = directory.appendingPathComponent("\(prefix)\(UUID().uuidString).img")
        let descriptor = open(destination.path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        var output: FileHandle? = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        var completed = false
        defer {
            try? output?.close()
            if !completed { try? FileManager.default.removeItem(at: destination) }
        }

        var copied = 0
        while true {
            try checkCancellation()
            // Read one byte past the boundary so a growing provider cannot
            // bypass a size check made before the stream was opened.
            let request = min(chunkSize, maximumBytes - copied + 1)
            guard let chunk = try input.read(upToCount: request), !chunk.isEmpty else { break }
            guard chunk.count <= maximumBytes - copied else { throw IOSImageStagingError.tooLarge }
            try output?.write(contentsOf: chunk)
            copied += chunk.count
            try afterChunk(copied)
        }
        try checkCancellation()
        var after = stat()
        guard fstat(input.fileDescriptor, &after) == 0,
              copied == before.st_size,
              after.st_size == before.st_size,
              after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec,
              after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec,
              after.st_ctimespec.tv_sec == before.st_ctimespec.tv_sec,
              after.st_ctimespec.tv_nsec == before.st_ctimespec.tv_nsec else {
            throw IOSImageStagingError.sourceChanged
        }
        try output?.close()
        output = nil
        completed = true
        return destination
    }

    private static func sweep(in directory: URL) {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ) else { return }
        for url in urls where isOwnedName(url.lastPathComponent) {
            guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true else { continue }
            try? FileManager.default.removeItem(at: url)
        }
    }

    private static func openInput(_ url: URL) throws -> FileHandle {
        // A provider can change the path before we open it. Hold one descriptor
        // for the whole copy, and avoid blocking on a special file or symlink.
        let descriptor = open(url.path, O_RDONLY | O_CLOEXEC | O_NONBLOCK | O_NOFOLLOW)
        guard descriptor >= 0 else { throw CocoaError(.fileReadUnknown) }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }

    private static func isOwnedName(_ name: String) -> Bool {
        for prefix in [prefix, legacyPrefix] where name.hasPrefix(prefix) {
            let suffix = name.dropFirst(prefix.count)
            let identifier = suffix.split(separator: ".", maxSplits: 1).first.map(String.init) ?? ""
            return UUID(uuidString: identifier) != nil
        }
        return false
    }
}
