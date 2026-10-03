import Foundation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// The provider is an immutable handle after selection. Only acquire invokes it;
/// its one callback stages within Apple's URL lifetime and always drains the
/// continuation, even after cancellation. No provider URL escapes that callback.
final class BatchPhotoSource: BatchSource, @unchecked Sendable {
    private let provider: NSItemProvider
    private let type: String
    init(provider: NSItemProvider, type: String) { self.provider = provider; self.type = type }
    func acquire(storage: BatchStorage, limits: BatchLimits, stop: BatchStop) async throws -> URL {
        try stop.check()
        return try await withCheckedThrowingContinuation { continuation in
            let progress = provider.loadFileRepresentation(forTypeIdentifier: type) { url, error in
                do {
                    try stop.check()
                    guard let url else { throw error ?? BatchFailure.item("Photos could not provide the complete original. Choose it again or use Files.") }
                    let stage = try BatchIO.stage(url, storage: storage, limit: limits.sourceBytes, stop: stop)
                    if stop.stopReason != nil {
                        try storage.removePrivate(stage); throw CancellationError()
                    }
                    continuation.resume(returning: stage)
                } catch { continuation.resume(throwing: error) }
                stop.attach(nil)
            }
            stop.attach(progress)
        }
    }
}

struct BatchPhotosPicker: UIViewControllerRepresentable {
    let remaining: Int
    let completion: ([BatchInputEntry]) -> Void
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .images; config.preferredAssetRepresentationMode = .current
        config.selection = .ordered; config.selectionLimit = max(1, remaining)
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: ([BatchInputEntry]) -> Void
        init(completion: @escaping ([BatchInputEntry]) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            let entries = results.map { result in
                let provider = result.itemProvider
                let type = provider.registeredTypeIdentifiers.first {
                    guard let type = UTType($0) else { return false }
                    return [UTType.jpeg, .png, .tiff, .heic].contains { type.conforms(to: $0) }
                }
                let name = provider.suggestedName ?? "Photo"
                return BatchInputEntry(name: name,
                                       source: BatchPhotoSource(provider: provider, type: type ?? UTType.image.identifier),
                                       selectionError: type == nil ? "Photos has no complete JPEG, PNG, TIFF, or HEIC representation." : nil)
            }
            completion(entries)
        }
    }
}

struct BatchFilesPicker: UIViewControllerRepresentable {
    let folders: Bool
    let completion: ([URL]) -> Void
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: folders ? [.folder] : [.jpeg, .png, .tiff, .heic], asCopy: false)
        picker.allowsMultipleSelection = !folders; picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: ([URL]) -> Void
        init(completion: @escaping ([URL]) -> Void) { self.completion = completion }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { completion(urls) }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { completion([]) }
    }
}
