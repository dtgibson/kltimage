import AppKit
import Foundation
import KLTCore
import Observation
import UniformTypeIdentifiers

enum ComparisonMode: String, CaseIterable, Identifiable {
    case original = "Original"
    case split = "Split"
    case enhanced = "Enhanced"

    var id: Self { self }
}

enum WorkspacePhase: Equatable {
    case empty
    case processing
    case ready
    case exporting
    case failed(String)
}

@MainActor
private final class ExportFormatAccessoryController: NSObject {
    let view: NSView
    private let picker = NSPopUpButton(frame: .zero, pullsDown: false)
    private weak var panel: NSSavePanel?
    private let sourceStem: String

    var format: ImageExportFormat {
        ImageExportFormat.allCases[picker.indexOfSelectedItem]
    }

    init(panel: NSSavePanel, sourceStem: String) {
        self.panel = panel
        self.sourceStem = sourceStem
        let label = NSTextField(labelWithString: "Format:")
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        picker.addItems(withTitles: ImageExportFormat.allCases.map(\.displayName))
        picker.selectItem(at: 0)
        let stack = NSStackView(views: [label, picker])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view = stack
        super.init()
        picker.target = self
        picker.action = #selector(formatChanged)
        formatChanged()
    }

    @objc private func formatChanged() {
        panel?.allowedContentTypes = [format.uniformType]
        panel?.nameFieldStringValue = "\(sourceStem)-klt.\(format.filenameExtension)"
    }
}

@MainActor
@Observable
final class WorkspaceModel {
    private(set) var source: DecodedImage?
    private(set) var enhanced: EnhancedImage?
    private(set) var phase: WorkspacePhase = .empty
    private(set) var sourceName = ""
    private(set) var exportNotice: String?
    private(set) var statusAnnouncement = "Open an image to begin." {
        didSet {
            NSAccessibility.post(
                element: NSApplication.shared,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: statusAnnouncement,
                    .priority: NSAccessibilityPriorityLevel.medium.rawValue
                ]
            )
        }
    }
    var comparisonMode: ComparisonMode = .split
    var zoom = 1.0
    var pan = CGSize.zero

    private var activeOperation: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var operationID = UUID()

    var canExport: Bool {
        enhanced != nil && phase == .ready
    }

    var canChangePresentation: Bool {
        enhanced != nil && phase == .ready
    }

    var isBusy: Bool {
        phase == .processing || phase == .exporting
    }

    var statusLabel: String {
        switch phase {
        case .empty: "Awaiting image"
        case .processing: "Calculating color components"
        case .ready:
            enhanced?.notice == nil ? "Result ready" : "Limited variation"
        case .exporting: "Exporting full resolution"
        case .failed: "Needs attention"
        }
    }

    func presentOpenPanel() {
        guard phase != .processing, phase != .exporting else { return }

        let panel = NSOpenPanel()
        panel.title = "Open an image"
        panel.prompt = "Open Image"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openImage(at: url)
    }

    func openImage(at url: URL) {
        guard phase != .processing, phase != .exporting else { return }

        activeOperation?.cancel()
        noticeTask?.cancel()
        exportNotice = nil
        source = nil
        enhanced = nil
        sourceName = url.lastPathComponent
        comparisonMode = .split
        zoom = 1
        pan = .zero
        phase = .processing
        statusAnnouncement = "Calculating color components for \(sourceName)."

        let newOperationID = UUID()
        operationID = newOperationID
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()

        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if accessedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url, options: [.mappedIfSafe])
                try Task.checkCancellation()
                let decoded = try ImagePipeline.decode(data)
                await self?.acceptDecodedImage(decoded, operationID: newOperationID)
                let result = try ImagePipeline.enhance(decoded)
                try Task.checkCancellation()
                await self?.acceptEnhancedImage(result, operationID: newOperationID)
            } catch is CancellationError {
                await self?.acceptCancellation(operationID: newOperationID)
            } catch {
                await self?.acceptFailure(error, operationID: newOperationID)
            }
        }
    }

    func presentExportPanel() {
        guard canExport, let enhanced else { return }

        let panel = NSSavePanel()
        panel.title = "Export enhanced image"
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let stem = (sourceName as NSString).deletingPathExtension
        let accessory = ExportFormatAccessoryController(panel: panel, sourceStem: stem)
        panel.accessoryView = accessory.view

        guard panel.runModal() == .OK, var url = panel.url else { return }
        let format = accessory.format
        if url.pathExtension.isEmpty {
            url.appendPathExtension(format.filenameExtension)
        }
        export(enhanced, to: url, format: format)
    }

    func cancelCurrentOperation() {
        activeOperation?.cancel()
        activeOperation = nil
        operationID = UUID()

        switch phase {
        case .processing:
            source = nil
            enhanced = nil
            sourceName = ""
            phase = .empty
            statusAnnouncement = "Image processing canceled."
        case .exporting:
            phase = .ready
            statusAnnouncement = "Image export canceled."
        default:
            break
        }
    }

    func zoomIn() {
        zoom = min(8, zoom * 1.25)
    }

    func zoomOut() {
        zoom = max(0.25, zoom / 1.25)
    }

    func resetView() {
        zoom = 1
        pan = .zero
    }

    private func export(_ result: EnhancedImage, to url: URL, format: ImageExportFormat) {
        activeOperation?.cancel()
        phase = .exporting
        exportNotice = nil
        statusAnnouncement = "Exporting the full-resolution enhanced image."
        let newOperationID = UUID()
        operationID = newOperationID
        let accessedSecurityScope = url.startAccessingSecurityScopedResource()

        activeOperation = Task.detached(priority: .userInitiated) { [weak self] in
            defer {
                if accessedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try ImagePipeline.encodedData(for: result.image, format: format)
                try Task.checkCancellation()
                try data.write(to: url, options: .atomic)
                try Task.checkCancellation()
                await self?.acceptExport(url: url, format: format, operationID: newOperationID)
            } catch is CancellationError {
                await self?.acceptCancellation(operationID: newOperationID)
            } catch {
                await self?.acceptFailure(error, operationID: newOperationID)
            }
        }
    }

    private func acceptDecodedImage(_ decoded: DecodedImage, operationID: UUID) {
        guard operationID == self.operationID, phase == .processing else { return }
        source = decoded
    }

    private func acceptEnhancedImage(_ result: EnhancedImage, operationID: UUID) {
        guard operationID == self.operationID else { return }
        enhanced = result
        phase = .ready
        activeOperation = nil
        statusAnnouncement = result.notice ?? "Enhancement complete. Original and enhanced images are ready to compare."
    }

    private func acceptExport(url: URL, format: ImageExportFormat, operationID: UUID) {
        guard operationID == self.operationID else { return }
        phase = .ready
        activeOperation = nil
        exportNotice = "Exported \(format.displayName) at full resolution"
        statusAnnouncement = "Enhanced image exported to \(url.lastPathComponent)."

        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            self?.exportNotice = nil
        }
    }

    private func acceptCancellation(operationID: UUID) {
        guard operationID == self.operationID else { return }
        if phase == .exporting {
            phase = .ready
        } else if phase == .processing {
            source = nil
            enhanced = nil
            sourceName = ""
            phase = .empty
        }
        activeOperation = nil
    }

    private func acceptFailure(_ error: Error, operationID: UUID) {
        guard operationID == self.operationID else { return }
        let message = (error as? LocalizedError)?.errorDescription ?? "The image operation could not be completed."
        if phase == .exporting, enhanced != nil {
            phase = .ready
            exportNotice = message
        } else {
            phase = .failed(message)
        }
        activeOperation = nil
        statusAnnouncement = message
    }
}

#if DEBUG
extension WorkspaceModel {
    static func previewReady() -> WorkspaceModel {
        let model = WorkspaceModel()
        guard let data = previewImageData(),
              let source = try? ImagePipeline.decode(data),
              let enhanced = try? ImagePipeline.enhance(source)
        else {
            return model
        }
        model.source = source
        model.enhanced = enhanced
        model.sourceName = "starling-feather.png"
        model.phase = .ready
        model.statusAnnouncement = "Enhancement complete."
        return model
    }

    static func previewProcessing() -> WorkspaceModel {
        let model = previewReady()
        model.enhanced = nil
        model.phase = .processing
        model.statusAnnouncement = "Calculating color components."
        return model
    }

    static func previewFailure() -> WorkspaceModel {
        let model = WorkspaceModel()
        model.phase = .failed("This image could not be read. Try a JPEG, PNG, TIFF, or HEIC file.")
        model.statusAnnouncement = "The image could not be read."
        return model
    }

    private static func previewImageData() -> Data? {
        let width = 160
        let height = 110
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ), let bytes = bitmap.bitmapData else {
            return nil
        }

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let nx = Double(x) / Double(width - 1)
                let ny = Double(y) / Double(height - 1)
                bytes[index] = UInt8((40 + (170 * nx)).rounded())
                bytes[index + 1] = UInt8((55 + (130 * ny)).rounded())
                bytes[index + 2] = UInt8((75 + (120 * (1 - nx * ny))).rounded())
                bytes[index + 3] = 255
            }
        }
        return bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
    }
}
#endif
