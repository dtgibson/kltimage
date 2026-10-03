// Architecture feasibility only. Not compiled into the product.
import Darwin
import Foundation
import CoreGraphics
import ImageIO
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

@MainActor
func makeFolderPicker() -> UIDocumentPickerViewController {
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
    picker.allowsMultipleSelection = false
    return picker
}
#endif

func publishExclusively(from source: URL, to destination: URL) -> Int32 {
    source.withUnsafeFileSystemRepresentation { sourcePath in
        destination.withUnsafeFileSystemRepresentation { destinationPath in
            renameatx_np(AT_FDCWD, sourcePath!, AT_FDCWD, destinationPath!, UInt32(RENAME_EXCL))
        }
    }
}

func imageDestination(consumer: CGDataConsumer) -> CGImageDestination? {
    CGImageDestinationCreateWithDataConsumer(consumer, "public.png" as CFString, 1, nil)
}

#if os(macOS)
let root = FileManager.default.temporaryDirectory.appendingPathComponent("klt-batch-architecture-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: root) }
let staged = root.appendingPathComponent("KLT temporary-proof.part")
let final = root.appendingPathComponent("001-proof-klt.png")
let preparedBytes = Data("complete staged bytes".utf8)
let existingBytes = Data("existing destination sentinel".utf8)
try preparedBytes.write(to: staged)
try existingBytes.write(to: final)
let collisionResult = publishExclusively(from: staged, to: final)
let collisionErrno = errno
precondition(collisionResult == -1 && collisionErrno == EEXIST)
precondition(try! Data(contentsOf: staged) == preparedBytes)
precondition(try! Data(contentsOf: final) == existingBytes)
let unused = root.appendingPathComponent("001-proof-klt-2.png")
precondition(publishExclusively(from: staged, to: unused) == 0)
precondition(try! Data(contentsOf: unused) == preparedBytes)
precondition(!FileManager.default.fileExists(atPath: staged.path))
print("PASS: exclusive rename rejects an existing destination, preserves both files, and publishes complete bytes at an unused name.")
print("Scope: this Mac's temporary filesystem only; no provider, simulator runtime, or physical device exercised.")
#endif
