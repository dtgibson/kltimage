import Foundation
import KLTCore
import Observation

struct BatchLimits: Sendable {
    let pixels: Int
    let sourceBytes: Int
    let imageBytes: Int
    let temporaryBytes: Int
    static let recordBytes = 1_048_576
    static let capacityReserve = 64 * 1_048_576
    static let current: Self = {
        #if os(iOS)
        Self(pixels: 26_000_000, sourceBytes: 256 * 1_048_576,
             imageBytes: 256 * 1_048_576, temporaryBytes: 768 * 1_048_576)
        #else
        Self(pixels: 64_000_000, sourceBytes: 1_024 * 1_048_576,
             imageBytes: 512 * 1_048_576, temporaryBytes: 2_048 * 1_048_576)
        #endif
    }()
}

enum BatchFailure: Error, LocalizedError {
    case item(String)
    case shared(String)
    var errorDescription: String? {
        switch self { case let .item(message), let .shared(message): message }
    }
    var stopsRun: Bool { if case .shared = self { true } else { false } }
}

#if DEBUG
/// Per-run fault injection for the actual filesystem boundaries. Never persisted
/// or configured by environment; absent from the shipping Release target.
struct BatchTestFaults: Sendable {
    var capacity: (@Sendable (URL, Int) -> Int64?)?
    var publication: (@Sendable (String) throws -> Void)?
}
#endif

/// Synchronized admission is the cancellation boundary. Admitted filesystem
/// operations finish and return their receipts; stop never erases a commit.
final class BatchStop: @unchecked Sendable {
    #if DEBUG
    let testFaults: BatchTestFaults?
    init(testFaults: BatchTestFaults? = nil) { self.testFaults = testFaults }
    #else
    init() {}
    #endif
    private let lock = NSLock()
    private var reason: String?
    private var progress: Progress?
    private var coordinator: NSFileCoordinator?
    var stopReason: String? { lock.withLock { reason } }
    func stop(_ reason: String) {
        let active = lock.withLock { self.reason = self.reason ?? reason; return (progress, coordinator) }
        active.0?.cancel(); active.1?.cancel()
    }
    func attach(_ progress: Progress?) {
        let stopped = lock.withLock { self.progress = progress; return reason != nil }
        if stopped { progress?.cancel() }
    }
    func attachCoordinator(_ coordinator: NSFileCoordinator?) {
        let stopped = lock.withLock { self.coordinator = coordinator; return reason != nil }
        if stopped { coordinator?.cancel() }
    }
    func check() throws {
        if lock.withLock({ reason != nil }) { throw CancellationError() }
        try Task.checkCancellation()
    }
    func admit() throws { try check() }
}

protocol BatchSource: Sendable {
    func acquire(storage: BatchStorage, limits: BatchLimits, stop: BatchStop) async throws -> URL
}

struct BatchInputEntry: Identifiable, Sendable {
    let id: UUID
    let name: String
    let source: any BatchSource
    let selectionError: String?
    init(name: String, source: any BatchSource, selectionError: String? = nil) {
        id = UUID(); self.name = BatchNames.display(name); self.source = source
        self.selectionError = selectionError
    }
}

struct BatchItemIdentity: Equatable, Sendable {
    let run: UUID
    let item: UUID
    let generation: UUID
    let fingerprint: AnalysisSourceFingerprint
    let request: EnhancementExecutionRequest
    let job: UUID
    func accepts(_ completion: Self, stop: BatchStop) -> Bool {
        stop.stopReason == nil && RequestAcceptanceGate.accepts(
            completedJobID: completion.job, completedKey: completion,
            activeJobID: job, currentKey: self)
    }
}

struct BatchItemCompletion: Sendable {
    let identity: BatchItemIdentity
    let image: EnhancedImage
    let record: AnalysisRecordSnapshot
}

struct BatchRunRequest: Sendable {
    let id: UUID
    let entries: [BatchInputEntry]
    let execution: EnhancementExecutionRequest
    let methodName: String
    let modeName: String
    let format: ImageExportFormat
    let includesRecord: Bool
    let destination: BatchFolderGrant
    let folderName: String
    let limits: BatchLimits
}

struct BatchOutcome: Identifiable, Sendable {
    enum Status: String, Sendable {
        case queued = "Queued", acquiring = "Acquiring", processing = "Processing", saving = "Saving"
        case saved = "Saved", warning = "Saved with warning", partial = "Partially saved"
        case failed = "Failed", canceled = "Canceled", notProcessed = "Not processed"
        var settled: Bool { ![.queued, .acquiring, .processing, .saving].contains(self) }
        var successful: Bool { self == .saved || self == .warning }
    }
    let id: UUID
    let ordinal: Int
    let name: String
    var status: Status = .queued
    var reason: String?
    var imageName: String?
    var recordName: String?
}

@MainActor @Observable
final class BatchWorkspaceLease {
    static let shared = BatchWorkspaceLease()
    private(set) var owner: UUID?
    private(set) var surfaceOwner: UUID?
    var isPresented: Bool { surfaceOwner != nil }
    func claimSurface(_ owner: UUID) -> Bool {
        guard surfaceOwner == nil || surfaceOwner == owner else { return false }
        surfaceOwner = owner; return true
    }
    var isHeld: Bool { owner != nil }
    func acquire(_ owner: UUID) -> Bool {
        guard (surfaceOwner == nil || surfaceOwner == owner), self.owner == nil || self.owner == owner else { return false }
        self.owner = owner; return true
    }
    func release(_ owner: UUID) {
        if self.owner == owner { self.owner = nil }
        if surfaceOwner == owner { surfaceOwner = nil }
    }
}

enum BatchNames {
    static func display(_ name: String) -> String {
        let scalars = name.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0) && !"/\\:".unicodeScalars.contains($0)
        }.prefix(255)
        let result = String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty || result == "." || result == ".." ? "image" : result
    }
    static func stem(_ name: String, ordinal: Int, suffix: String = "", limit: Int = 120) -> String {
        var source = display((name as NSString).deletingPathExtension)
        while source.hasPrefix(".") { source.removeFirst() }
        if source.isEmpty { source = "image" }
        let prefix = String(format: "%03d-", ordinal)
        // The longer JSON extension determines the paired filename allowance.
        let tail = "-klt" + suffix
        let allowed = max(1, limit - prefix.utf8.count - tail.utf8.count - "-analysis.json".utf8.count)
        var bounded = ""
        for character in source {
            if bounded.utf8.count + String(character).utf8.count > allowed { break }
            bounded.append(character)
        }
        return prefix + (bounded.isEmpty ? "image" : bounded) + tail
    }
    static func folder(owner: UUID) -> String {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        return "KLT Batch \(formatter.string(from: Date())) \(owner.uuidString)"
    }
    static func temporary(owner: UUID) -> String { "KLT temporary-\(owner.uuidString)-\(UUID().uuidString).part" }
    static func validTemporary(_ name: String, owner: UUID) -> Bool {
        let prefix = "KLT temporary-\(owner.uuidString)-"
        guard name.hasPrefix(prefix), name.hasSuffix(".part") else { return false }
        return UUID(uuidString: String(name.dropFirst(prefix.count).dropLast(5))) != nil
    }
}

/// Counts native work until its callback/task actually returns, even when the
/// interactive model has already acknowledged cancellation.
final class BatchInteractiveWork: @unchecked Sendable {
    static let shared = BatchInteractiveWork()
    private let lock = NSLock()
    private var count = 0
    var busy: Bool { lock.withLock { count > 0 } }
    func begin() { lock.withLock { count += 1 } }
    func end() { lock.withLock { count -= 1 } }
}
