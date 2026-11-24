import Foundation
import KLTCore

actor MethodLibraryStore {
    static func defaultURL(fileManager: FileManager = .default) throws -> URL {
#if DEBUG
        if let override = ProcessInfo.processInfo.environment["KLT_UI_TEST_METHOD_LIBRARY_PATH"],
           !override.isEmpty {
            if (override as NSString).isAbsolutePath {
                return URL(fileURLWithPath: override, isDirectory: false)
            }
            return fileManager.temporaryDirectory.appendingPathComponent(
                (override as NSString).lastPathComponent,
                isDirectory: false
            )
        }
#endif
        let support = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return support
            .appendingPathComponent("com.kltimage.mac", isDirectory: true)
            .appendingPathComponent("MethodLibrary", isDirectory: true)
            .appendingPathComponent("library.json", isDirectory: false)
    }

    private let url: URL
    private var snapshot: MethodLibrarySnapshot = .empty
    private var didLoad = false

    init(url: URL? = nil) {
        self.url = url ?? (try! Self.defaultURL())
    }

    #if DEBUG
    private var writeFailure: MethodFileIO.DurableWriteCheckpoint?

    init(url: URL, writeFailure: MethodFileIO.DurableWriteCheckpoint) {
        self.url = url
        self.writeFailure = writeFailure
    }
    #endif

    func load() throws -> MethodLibrarySnapshot {
        if didLoad { return snapshot }
        guard FileManager.default.fileExists(atPath: url.path) else {
            didLoad = true
            snapshot = .empty
            return snapshot
        }
        let data = try MethodFileIO.readRegularFile(
            at: url,
            maximumByteCount: MethodLibraryDocumentCodec.maximumByteCount, sizeError: .oversizedLibrary
        )
        snapshot = try MethodLibraryDocumentCodec.decode(data)
        didLoad = true
        return snapshot
    }

    func replace(with proposed: MethodLibrarySnapshot) throws -> MethodLibrarySnapshot {
        let data = try MethodLibraryDocumentCodec.data(for: proposed)
        #if DEBUG
        try MethodFileIO.durableAtomicWrite(data, to: url, failingAt: writeFailure)
        #else
        try MethodFileIO.durableAtomicWrite(data, to: url)
        #endif
        snapshot = proposed
        didLoad = true
        return proposed
    }
}
