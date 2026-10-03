import Darwin
import Foundation
import ImageIO
import KLTCore
import UniformTypeIdentifiers

struct BatchRunResult: Sendable {
    let outcomes: [BatchOutcome]
    let stopReason: String?
    let folder: URL?
}

enum BatchRunner {
    static func run(_ request: BatchRunRequest, storage: BatchStorage, stop: BatchStop,
                    prepared: @escaping @Sendable (URL) -> Void = { _ in },
                    phase: @escaping @Sendable (Int, BatchOutcome.Status) -> Void,
                    settled: @escaping @Sendable (BatchOutcome) -> Void) async -> BatchRunResult {
        var rows = request.entries.enumerated().map { BatchOutcome(id: $0.element.id, ordinal: $0.offset + 1, name: $0.element.name) }
        let publisher: BatchPublisher
        do { publisher = try BatchPublisher(request: request, storage: storage, stop: stop) }
        catch {
            let reason = stop.stopReason ?? "Stopped: \(error.localizedDescription)"
            for index in rows.indices { rows[index].status = .notProcessed; rows[index].reason = reason }
            return BatchRunResult(outcomes: rows, stopReason: reason, folder: nil)
        }
        prepared(publisher.url)
        for index in request.entries.indices {
            if stop.stopReason != nil { break }
            let entry = request.entries[index]
            var row = rows[index]
            var stage: URL?
            do {
                try stop.admit()
                if let selectionError = entry.selectionError { throw BatchFailure.item(selectionError) }
                phase(index, .acquiring)
                stage = try await entry.source.acquire(storage: storage, limits: request.limits, stop: stop)
                try stop.check()
                phase(index, .processing)
                row = autoreleasepool { process(request, entry: entry, ordinal: index + 1,
                                               sourceURL: stage!, storage: storage, publisher: publisher,
                                               stop: stop, phase: { phase(index, $0) }) }
                // process owns and removes the acquired source, including its failure paths.
                stage = nil
            } catch {
                row.status = stop.stopReason != nil || error is CancellationError ? .canceled : .failed
                row.reason = error is CancellationError ? stop.stopReason : error.localizedDescription
                if let failure = error as? BatchFailure, failure.stopsRun { stop.stop("Stopped: \(failure.localizedDescription)") }
            }
            if let stage {
                do { try storage.removePrivate(stage) }
                catch { stop.stop("Stopped: \(error.localizedDescription)") }
            }
            rows[index] = row; settled(row)
        }
        do { try publisher.cleanup() }
        catch { stop.stop("Stopped: \(error.localizedDescription)") }
        if !rows.contains(where: { $0.imageName != nil }) { publisher.removeIfEmpty() }
        for index in rows.indices where !rows[index].status.settled {
            rows[index].status = .notProcessed; rows[index].reason = stop.stopReason ?? "The batch stopped before this image began."
        }
        return BatchRunResult(outcomes: rows, stopReason: stop.stopReason, folder: publisher.url)
    }

    private static func process(_ request: BatchRunRequest, entry: BatchInputEntry, ordinal: Int,
                                sourceURL: URL, storage: BatchStorage, publisher: BatchPublisher,
                                stop: BatchStop, phase: (BatchOutcome.Status) -> Void) -> BatchOutcome {
        var row = BatchOutcome(id: entry.id, ordinal: ordinal, name: entry.name)
        var privateFiles = [sourceURL]; var receipt = BatchCommitReceipt(); var warning: String?
        do {
            try stop.check()
            guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary),
                  let rawType = CGImageSourceGetType(imageSource), let type = UTType(rawType as String),
                  [UTType.jpeg, .png, .tiff, .heic].contains(where: { type.conforms(to: $0) }) else {
                throw BatchFailure.item("Choose a complete JPEG, PNG, TIFF, or HEIC original.")
            }
            let source: DecodedImage
            do { source = try ImagePipeline.decode(at: sourceURL, maximumPixelCount: request.limits.pixels) }
            catch ImagePipelineError.imageTooLarge { throw BatchFailure.item("This image exceeds the \(request.limits.pixels / 1_000_000)-million-pixel limit. No smaller substitute was used.") }
            try storage.removePrivate(sourceURL); privateFiles.removeAll { $0 == sourceURL }
            try stop.check()
            let identity = BatchItemIdentity(run: request.id, item: entry.id, generation: UUID(),
                                             fingerprint: source.analysisSourceFingerprint,
                                             request: request.execution, job: UUID())
            let completion = try calculate(source, name: entry.name, identity: identity, methodName: request.methodName)
            warning = completion.image.notice
            let authorize = {
                guard identity.accepts(completion.identity, stop: stop) else { throw CancellationError() }
                try stop.check()
            }
            try authorize(); phase(.saving)
            let image = try storage.makePrivate(reserving: request.limits.imageBytes); privateFiles.append(image)
            let file = open(image.path, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
            guard file >= 0 else { throw BatchFailure.shared("Private output storage is unavailable.") }
            let imageBytes: Int
            do {
                imageBytes = try ImagePipeline.encode(completion.image.image, format: request.format,
                                                      maximumBytes: request.limits.imageBytes) { bytes in
                    try stop.check(); try BatchIO.write(bytes, to: file)
                }
                try BatchIO.sync(file)
            } catch { close(file); throw error }
            guard close(file) == 0 else { throw BatchFailure.shared("The encoded output could not be closed.") }
            try storage.shrinkPrivate(image, to: imageBytes)
            var recordURL: URL?; var recordBytes = 0
            if request.includesRecord {
                let bytes = try AnalysisRecordSnapshotJSONEncoder.data(for: completion.record)
                guard bytes.count <= BatchLimits.recordBytes else { throw BatchFailure.item("The analysis JSON exceeds its 1 MiB limit.") }
                let record = try storage.makePrivate(reserving: bytes.count); privateFiles.append(record)
                let output = open(record.path, O_WRONLY | O_NOFOLLOW | O_CLOEXEC)
                guard output >= 0 else { throw BatchFailure.shared("Private record storage is unavailable.") }
                do { try bytes.withUnsafeBytes { try BatchIO.write($0, to: output) }; try BatchIO.sync(output) }
                catch { close(output); throw error }
                guard close(output) == 0 else { throw BatchFailure.shared("The analysis record could not be closed.") }
                recordURL = record; recordBytes = bytes.count
            }
            #if DEBUG
            let checkpoint: (String) throws -> Void = { phase in try stop.testFaults?.publication?(phase) }
            #else
            let checkpoint: (String) throws -> Void = { _ in }
            #endif
            try publisher.publish(image: image, imageBytes: imageBytes, record: recordURL, recordBytes: recordBytes,
                                  entry: entry, ordinal: ordinal, format: request.format, authorize: authorize, receipt: &receipt, checkpoint: checkpoint)
        } catch {
            row.reason = error is CancellationError ? (stop.stopReason ?? "Batch canceled") : String(error.localizedDescription.prefix(800))
            row.status = stop.stopReason != nil || error is CancellationError ? .canceled : .failed
            if let failure = error as? BatchFailure, failure.stopsRun { stop.stop("Stopped: \(failure.localizedDescription)") }
            // Coordination/provider failures during saving affect the shared destination.
            else if receipt.imageName != nil || (error as NSError).domain == NSCocoaErrorDomain {
                stop.stop("Stopped: \(error.localizedDescription)")
            }
        }
        row.imageName = receipt.imageName; row.recordName = receipt.recordName
        if receipt.imageName != nil {
            if request.includesRecord && receipt.recordName == nil {
                row.status = .partial; row.reason = "Image saved; analysis JSON missing. " + (row.reason ?? "The save stopped.")
            } else { row.status = warning == nil ? .saved : .warning; row.reason = warning }
        }
        do { try publisher.cleanup() }
        catch { stop.stop("Stopped: \(error.localizedDescription)") }
        for file in privateFiles {
            do { try storage.removePrivate(file) }
            catch { stop.stop("Stopped: \(error.localizedDescription)") }
        }
        return row
    }

    static func calculate(_ source: DecodedImage, name: String, identity: BatchItemIdentity,
                          methodName: String) throws -> BatchItemCompletion {
        let result: EnhancedImage
        switch identity.request {
        case let .calculated(request): result = try ImagePipeline.enhance(source, request: request, workingSpaceName: methodName)
        case let .replayed(recipe): result = try ImagePipeline.replay(source, recipe: recipe, recipeName: methodName)
        }
        return BatchItemCompletion(identity: identity, image: result,
                                   record: try AnalysisRecordRouter.make(decodedSource: source, displayFilename: name, enhancement: result))
    }
}
