import Darwin
import Foundation
import KLTCore

enum MethodFileIOError: Error, Equatable, LocalizedError {
    case notRegularFile
    case readFailed
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .notRegularFile:
            "The selected method must be a regular local file, not a folder or symbolic link."
        case .readFailed:
            "The selected method file could not be read. Nothing was imported, replaced, or applied."
        case .writeFailed:
            "The method file's durable save could not be confirmed. No partial file was exposed; the destination contains either the prior complete file or the new complete file. Review it before retrying."
        }
    }
}

enum MethodFileIO {
    enum DurableWriteCheckpoint: CaseIterable, Equatable {
        case beforeTemporaryCreation
        case afterTemporaryCreation
        case afterWrite
        case afterFileSynchronization
        case beforeRename
        case afterRename
        case afterDirectoryOpen
        case afterDirectorySynchronization
        case afterDirectoryClose

        var occursAfterRename: Bool {
            switch self {
            case .afterRename, .afterDirectoryOpen,
                 .afterDirectorySynchronization, .afterDirectoryClose:
                true
            default:
                false
            }
        }
    }

    static func readRegularFile(at url: URL, maximumByteCount: Int) throws -> Data {
        guard url.isFileURL, (0..<Int.max).contains(maximumByteCount) else {
            throw MethodFileIOError.notRegularFile
        }

        var pathMetadata = stat()
        guard lstat(url.path, &pathMetadata) == 0 else {
            throw MethodFileIOError.readFailed
        }
        guard (pathMetadata.st_mode & S_IFMT) == S_IFREG else {
            throw MethodFileIOError.notRegularFile
        }

        let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
        guard descriptor >= 0 else {
            if errno == ELOOP { throw MethodFileIOError.notRegularFile }
            throw MethodFileIOError.readFailed
        }
        defer { close(descriptor) }

        var openedMetadata = stat()
        guard fstat(descriptor, &openedMetadata) == 0,
              (openedMetadata.st_mode & S_IFMT) == S_IFREG else {
            throw MethodFileIOError.notRegularFile
        }
        guard openedMetadata.st_size >= 0 else {
            throw MethodFileIOError.readFailed
        }
        guard openedMetadata.st_size <= maximumByteCount else {
            throw MethodDocumentError.oversized
        }

        var data = Data()
        data.reserveCapacity(min(Int(openedMetadata.st_size), maximumByteCount))
        var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
        while true {
            let remaining = maximumByteCount - data.count
            let requested = min(buffer.count, remaining + 1)
            let count = buffer.withUnsafeMutableBytes { bytes in
                Darwin.read(descriptor, bytes.baseAddress, requested)
            }
            if count == 0 { break }
            if count < 0 {
                if errno == EINTR { continue }
                throw MethodFileIOError.readFailed
            }
            data.append(contentsOf: buffer.prefix(count))
            guard data.count <= maximumByteCount else {
                throw MethodDocumentError.oversized
            }
        }
        return data
    }

    static func durableAtomicWrite(
        _ data: Data,
        to destination: URL,
        failingAt injectedFailure: DurableWriteCheckpoint? = nil
    ) throws {
        guard destination.isFileURL else { throw MethodFileIOError.writeFailed }
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let temporary = directory.appendingPathComponent(
            ".klt-method-\(UUID().uuidString.lowercased()).tmp"
        )
        try failIfRequested(.beforeTemporaryCreation, injectedFailure)
        let descriptor = open(
            temporary.path,
            O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
            0o600
        )
        guard descriptor >= 0 else { throw MethodFileIOError.writeFailed }

        var descriptorIsOpen = true
        var removeTemporary = true
        defer {
            if descriptorIsOpen { close(descriptor) }
            if removeTemporary { try? fileManager.removeItem(at: temporary) }
        }
        try failIfRequested(.afterTemporaryCreation, injectedFailure)

        try data.withUnsafeBytes { rawBuffer in
            guard var pointer = rawBuffer.baseAddress else { return }
            var remaining = rawBuffer.count
            while remaining > 0 {
                let count = Darwin.write(descriptor, pointer, remaining)
                if count < 0, errno == EINTR { continue }
                guard count > 0 else { throw MethodFileIOError.writeFailed }
                remaining -= count
                pointer = pointer.advanced(by: count)
            }
        }
        try failIfRequested(.afterWrite, injectedFailure)
        guard synchronize(descriptor) else { throw MethodFileIOError.writeFailed }
        let fileCloseResult = close(descriptor)
        descriptorIsOpen = false
        guard fileCloseResult == 0 else { throw MethodFileIOError.writeFailed }
        try failIfRequested(.afterFileSynchronization, injectedFailure)

        try failIfRequested(.beforeRename, injectedFailure)
        guard rename(temporary.path, destination.path) == 0 else {
            throw MethodFileIOError.writeFailed
        }
        removeTemporary = false
        try failIfRequested(.afterRename, injectedFailure)

        let directoryDescriptor = open(directory.path, O_RDONLY | O_DIRECTORY | O_CLOEXEC)
        guard directoryDescriptor >= 0 else { throw MethodFileIOError.writeFailed }
        var directoryDescriptorIsOpen = true
        defer {
            if directoryDescriptorIsOpen { _ = close(directoryDescriptor) }
        }
        try failIfRequested(.afterDirectoryOpen, injectedFailure)
        guard synchronize(directoryDescriptor) else { throw MethodFileIOError.writeFailed }
        try failIfRequested(.afterDirectorySynchronization, injectedFailure)
        guard close(directoryDescriptor) == 0 else {
            directoryDescriptorIsOpen = false
            throw MethodFileIOError.writeFailed
        }
        directoryDescriptorIsOpen = false
        try failIfRequested(.afterDirectoryClose, injectedFailure)
    }

    private static func failIfRequested(
        _ checkpoint: DurableWriteCheckpoint,
        _ injectedFailure: DurableWriteCheckpoint?
    ) throws {
        if checkpoint == injectedFailure { throw MethodFileIOError.writeFailed }
    }

    private static func synchronize(_ descriptor: Int32) -> Bool {
        while fsync(descriptor) != 0 {
            if errno != EINTR { return false }
        }
        return true
    }
}
