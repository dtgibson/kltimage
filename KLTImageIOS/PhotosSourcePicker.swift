import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct PhotosSourcePicker: UIViewControllerRepresentable {
    let completion: (Result<PhotoOriginal, Error>) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }
    static func dismantleUIViewController(_ controller: PHPickerViewController, coordinator: Coordinator) {
        coordinator.cancelActiveStage()
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (Result<PhotoOriginal, Error>) -> Void
        private var activeStage: IOSStagingCancellation?
        init(completion: @escaping (Result<PhotoOriginal, Error>) -> Void) { self.completion = completion }

        func cancelActiveStage() {
            activeStage?.cancel()
            activeStage = nil
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            cancelActiveStage()
            guard let provider = results.first?.itemProvider else {
                picker.dismiss(animated: true)
                completion(.failure(CancellationError()))
                return
            }
            let types = provider.registeredTypeIdentifiers
            guard let type = types.first(where: {
                guard let candidate = UTType($0) else { return false }
                return candidate.conforms(to: .jpeg) || candidate.conforms(to: .png)
                    || candidate.conforms(to: .tiff) || candidate.conforms(to: .heic)
            }) else {
                completion(.failure(PhotoImportError.noOriginal))
                return
            }
            let suggestedName = provider.suggestedName ?? "Photo"
            let cancellation = IOSStagingCancellation()
            activeStage = cancellation
            // loadFileRepresentation supplies a complete provider file, not a UIImage preview.
            provider.loadFileRepresentation(forTypeIdentifier: type) { temporary, error in
                guard let temporary else {
                    DispatchQueue.main.async {
                        if !cancellation.isCancelled {
                            self.completion(.failure(error ?? PhotoImportError.noOriginal))
                        }
                    }
                    return
                }
                let suffix = UTType(type)?.preferredFilenameExtension ?? "image"
                do {
                    let destination = try IOSImageSourceStaging.stage(
                        from: temporary, checkCancellation: { try cancellation.check() }
                    )
                    let name = (suggestedName as NSString).pathExtension.isEmpty
                        ? suggestedName + "." + suffix : suggestedName
                    DispatchQueue.main.async {
                        if cancellation.isCancelled {
                            try? FileManager.default.removeItem(at: destination)
                        } else {
                            self.completion(.success(PhotoOriginal(url: destination, name: name)))
                        }
                    }
                } catch {
                    DispatchQueue.main.async {
                        if !cancellation.isCancelled { self.completion(.failure(error)) }
                    }
                }
            }
        }
    }
}

struct PhotoOriginal {
    let url: URL
    let name: String
}

private enum PhotoImportError: LocalizedError {
    case noOriginal
    var errorDescription: String? {
        "Photos could not provide a complete JPEG, PNG, TIFF, or HEIC original. Choose another image or use Files."
    }
}
