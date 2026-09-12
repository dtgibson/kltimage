import AppKit
import KLTCore
import SwiftUI

struct ComparisonCanvas: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panAtGestureStart: CGSize?
    @State private var zoomAtGestureStart: Double?
    @State private var regionEditInProgress = false

    var body: some View {
        ZStack {
            TechnicalGrid()
            Group {
                switch model.comparisonMode {
                case .original:
                    originalPane
                case .enhanced:
                    resultPane
                case .split:
                    HStack(spacing: 0) {
                        originalPane
                        Rectangle().fill(KLTColor.divider).frame(width: 1)
                        resultPane
                    }
                }
            }
            .transition(.opacity)

            if let bannerMessage {
                StatusBanner(message: bannerMessage)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(panGesture)
        .simultaneousGesture(magnifyGesture)
        .onTapGesture(count: 2) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                model.resetView()
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.comparisonMode)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: bannerMessage)
        .clipped()
        .accessibilityHint("Drag outside an active sample to pan, pinch to zoom, or double-click to fit")
    }

    private var originalPane: some View {
        ImagePane(
            image: model.source!.originalImage,
            label: "Original",
            stateLabel: "SOURCE",
            accent: false,
            zoom: model.zoom,
            pan: model.pan,
            region: model.regionEditor.committed,
            sampleIsActive: model.sampleSource == .selectedRegion,
            isEditable: model.sampleSource == .selectedRegion,
            commitRegion: model.commitPointerRegion,
            setRegionEditInProgress: handleRegionEditState
        )
    }

    private var resultPane: some View {
        ResultPane(
            image: model.enhanced?.image,
            phase: model.phase,
            currency: model.resultCurrency,
            methodText: model.methodText,
            zoom: model.zoom,
            pan: model.pan,
            region: model.regionEditor.committed,
            sampleIsActive: model.sampleSource == .selectedRegion,
            setRegionEditInProgress: handleRegionEditState
        )
    }

    private var bannerMessage: String? {
        switch model.phase {
        case .awaitingRegion:
            "Select a region on the image or enter source-pixel bounds. KLT Image will not substitute whole-image statistics."
        case let .invalidRegion(issue): issue.message()
        case let .failed(message): message
        default: nil
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !regionEditInProgress else { return }
                if panAtGestureStart == nil { panAtGestureStart = model.pan }
                guard let start = panAtGestureStart else { return }
                model.pan = CGSize(
                    width: start.width + value.translation.width,
                    height: start.height + value.translation.height
                )
            }
            .onEnded { _ in panAtGestureStart = nil }
    }

    private func handleRegionEditState(_ isActive: Bool) {
        guard isActive != regionEditInProgress else { return }
        if isActive, let start = panAtGestureStart {
            model.pan = start
            panAtGestureStart = nil
        }
        regionEditInProgress = isActive
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomAtGestureStart == nil { zoomAtGestureStart = model.zoom }
                guard let start = zoomAtGestureStart else { return }
                model.zoom = min(8, max(0.25, start * value.magnification))
            }
            .onEnded { _ in zoomAtGestureStart = nil }
    }
}

private struct ResultPane: View {
    let image: CGImage?
    let phase: WorkspacePhase
    let currency: ResultCurrency
    let methodText: String
    let zoom: Double
    let pan: CGSize
    let region: SourcePixelRegion?
    let sampleIsActive: Bool
    let setRegionEditInProgress: (Bool) -> Void

    var body: some View {
        ZStack {
            if let image {
                ImagePane(
                    image: image,
                    label: "Enhanced",
                    stateLabel: currencyText,
                    accent: currency == .current,
                    zoom: zoom,
                    pan: pan,
                    region: region,
                    sampleIsActive: sampleIsActive,
                    isEditable: false,
                    commitRegion: { _ in },
                    setRegionEditInProgress: setRegionEditInProgress
                )
                if phase == .processing {
                    Color(hex: 0x142A36, alpha: 0.24)
                    ProgressPlate(methodText: methodText)
                }
            } else {
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 10) {
                        if phase == .processing {
                            ProgressView().controlSize(.small)
                            Text("Calculating full image")
                                .font(.plexSans(13, weight: .semibold))
                            Text(methodText + " · local only")
                                .font(.plexMono(10))
                                .foregroundStyle(KLTColor.inkMuted)
                        } else if case let .failed(message) = phase {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(KLTColor.warning)
                                .accessibilityHidden(true)
                            Text(message)
                                .font(.plexSans(13, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 420)
                        } else {
                            Text("A current result will appear here")
                                .font(.plexSans(12, weight: .semibold))
                                .foregroundStyle(KLTColor.inkMuted)
                        }
                    }
                    .foregroundStyle(KLTColor.ink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    PaneLabel(text: "Enhanced", state: currencyText, accent: false)
                        .padding(14)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Enhanced image pane. \(currencyText).")
            }
        }
        .clipped()
    }

    private var currencyText: String {
        switch currency {
        case .none: "PENDING"
        case .current: "CURRENT"
        case .previousUpdating: "PREVIOUS · UPDATING"
        case .previousNotCurrent: "PREVIOUS · NOT CURRENT"
        }
    }
}

private struct ImagePane: View {
    let image: CGImage
    let label: String
    let stateLabel: String
    let accent: Bool
    let zoom: Double
    let pan: CGSize
    let region: SourcePixelRegion?
    let sampleIsActive: Bool
    let isEditable: Bool
    let commitRegion: (SourcePixelRegion) -> Void
    let setRegionEditInProgress: (Bool) -> Void

    @State private var drawProposal: SourcePixelRegion?
    @State private var moveOrigin: SourcePixelRegion?
    @State private var moveProposal: SourcePixelRegion?
    @State private var resizeOrigin: SourcePixelRegion?
    @State private var resizeProposal: SourcePixelRegion?

    var body: some View {
        GeometryReader { proxy in
            let transform = ImageViewportTransform(
                sourceSize: CGSize(width: image.width, height: image.height),
                paneSize: proxy.size,
                zoom: zoom,
                pan: pan
            )
            let displayedRegion = resizeProposal ?? moveProposal ?? drawProposal ?? region

            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: transform.imageRect.width, height: transform.imageRect.height)
                    .position(x: transform.imageRect.midX, y: transform.imageRect.midY)
                    .shadow(color: KLTColor.navy.opacity(0.16), radius: 12, y: 8)

                if isEditable {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(width: transform.imageRect.width, height: transform.imageRect.height)
                        .position(x: transform.imageRect.midX, y: transform.imageRect.midY)
                        .highPriorityGesture(drawGesture(transform))
                        .pointerCursor(.crosshair)
                        .accessibilityHidden(true)
                }

                if let displayedRegion {
                    selectionOverlay(region: displayedRegion, transform: transform)
                }

                PaneLabel(text: label, state: stateLabel, accent: accent)
                    .padding(14)
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) image pane")
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(
                isEditable
                    ? "Drag outside the sample to replace it, drag the rectangle to move it, or edit exact bounds in Analysis controls."
                    : "The sample overlay is informational in this pane."
            )
        }
    }

    @ViewBuilder
    private func selectionOverlay(
        region displayedRegion: SourcePixelRegion,
        transform: ImageViewportTransform
    ) -> some View {
        let rect = transform.sourceToView(displayedRegion)
        if sampleIsActive {
            Path { path in
                path.addRect(transform.imageRect)
                path.addRect(rect)
            }
            .fill(KLTColor.navy.opacity(0.28), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
        }

        Rectangle()
            .fill(sampleIsActive ? KLTColor.accent.opacity(0.08) : Color.clear)
            .frame(width: max(0, rect.width), height: max(0, rect.height))
            .overlay {
                Rectangle()
                    .stroke(
                        sampleIsActive ? KLTColor.accent : KLTColor.divider,
                        style: StrokeStyle(lineWidth: sampleIsActive ? 2 : 1, dash: sampleIsActive ? [] : [5, 4])
                    )
            }
            .position(x: rect.midX, y: rect.midY)
            .contentShape(Rectangle())
            .highPriorityGesture(isEditable && sampleIsActive ? moveGesture(transform) : nil)
            .pointerCursor(isEditable && sampleIsActive ? .openHand : .arrow)

        Text(sampleLabel(for: displayedRegion))
            .font(.plexMono(8, weight: .semibold))
            .tracking(0.4)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 6)
            .frame(height: 20)
            .background(sampleIsActive ? KLTColor.accentPressed : KLTColor.navy, in: RoundedRectangle(cornerRadius: 5))
            .position(x: min(transform.imageRect.maxX - 70, max(transform.imageRect.minX + 70, rect.minX + 70)), y: max(transform.imageRect.minY + 11, rect.minY - 11))
            .allowsHitTesting(false)

        if isEditable && sampleIsActive {
            RoundedRectangle(cornerRadius: 3)
                .fill(KLTColor.accent)
                .frame(width: 12, height: 12)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(KLTColor.surfaceRaised, lineWidth: 2))
                .contentShape(Rectangle().inset(by: -8))
                .position(x: rect.maxX, y: rect.maxY)
                .highPriorityGesture(resizeGesture(transform))
                .pointerCursor(.kltDiagonalResize)
                .accessibilityHidden(true)
        }
    }

    private func drawGesture(_ transform: ImageViewportTransform) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                setRegionEditInProgress(true)
                drawProposal = transform.constrainedRegion(from: value.startLocation, to: value.location)
            }
            .onEnded { value in
                let proposal = transform.constrainedRegion(from: value.startLocation, to: value.location)
                drawProposal = nil
                setRegionEditInProgress(false)
                commitRegion(proposal)
            }
    }

    private func moveGesture(_ transform: ImageViewportTransform) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                setRegionEditInProgress(true)
                NSCursor.closedHand.set()
                if moveOrigin == nil { moveOrigin = region }
                guard let origin = moveOrigin, transform.scale > 0 else { return }
                let deltaX = Int((value.translation.width / transform.scale).rounded())
                let deltaY = Int((value.translation.height / transform.scale).rounded())
                moveProposal = SourcePixelRegion(
                    x: min(image.width - origin.width, max(0, origin.x + deltaX)),
                    y: min(image.height - origin.height, max(0, origin.y + deltaY)),
                    width: origin.width,
                    height: origin.height
                )
            }
            .onEnded { _ in
                let proposal = moveProposal
                moveOrigin = nil
                moveProposal = nil
                setRegionEditInProgress(false)
                NSCursor.openHand.set()
                if let proposal { commitRegion(proposal) }
            }
    }

    private func resizeGesture(_ transform: ImageViewportTransform) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                setRegionEditInProgress(true)
                NSCursor.kltDiagonalResize.set()
                if resizeOrigin == nil { resizeOrigin = region }
                guard let origin = resizeOrigin, transform.scale > 0 else { return }
                let deltaWidth = Int((value.translation.width / transform.scale).rounded())
                let deltaHeight = Int((value.translation.height / transform.scale).rounded())
                resizeProposal = SourcePixelRegion(
                    x: origin.x,
                    y: origin.y,
                    width: min(image.width - origin.x, max(0, origin.width + deltaWidth)),
                    height: min(image.height - origin.y, max(0, origin.height + deltaHeight))
                )
            }
            .onEnded { _ in
                let proposal = resizeProposal
                resizeOrigin = nil
                resizeProposal = nil
                setRegionEditInProgress(false)
                if let proposal { commitRegion(proposal) }
            }
    }

    private func sampleLabel(for region: SourcePixelRegion) -> String {
        guard sampleIsActive else { return "SAVED SAMPLE · INACTIVE" }
        let pixels = Double(max(0, region.width)) * Double(max(0, region.height))
        return String(format: "SAMPLE · %.2f MP", pixels / 1_000_000)
    }

    private var accessibilityValue: String {
        var value = "\(image.width) by \(image.height) pixels at \(Int((zoom * 100).rounded())) percent zoom."
        if let region {
            value += " Sample X \(region.x), Y \(region.y), width \(region.width), height \(region.height)."
            value += sampleIsActive ? " The sample supplies statistics for the full-image transform." : " The saved sample is inactive."
        } else {
            value += " No sample region is defined."
        }
        return value
    }
}

private extension View {
    func pointerCursor(_ cursor: NSCursor) -> some View {
        modifier(PointerCursorModifier(cursor: cursor))
    }
}

private struct PointerCursorModifier: ViewModifier {
    let cursor: NSCursor

    func body(content: Content) -> some View {
        content.onContinuousHover { phase in
            switch phase {
            case .active:
                cursor.set()
            case .ended:
                NSCursor.arrow.set()
            }
        }
    }
}

private extension NSCursor {
    @MainActor
    static let kltDiagonalResize: NSCursor = {
        guard let symbol = NSImage(
            systemSymbolName: "arrow.up.left.and.arrow.down.right",
            accessibilityDescription: nil
        ) else {
            return .crosshair
        }
        let configuration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let image = symbol.withSymbolConfiguration(configuration) ?? symbol
        image.size = NSSize(width: 18, height: 18)
        return NSCursor(image: image, hotSpot: NSPoint(x: 9, y: 9))
    }()
}

private struct PaneLabel: View {
    let text: String
    let state: String
    let accent: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(accent ? KLTColor.accent : KLTColor.inkMuted).frame(width: 6, height: 6)
            Text(text).font(.plexSans(11, weight: .bold))
            Text(state)
                .font(.plexMono(8))
                .foregroundStyle(KLTColor.inkMuted)
        }
        .padding(.horizontal, 9)
        .frame(height: 28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(accent ? KLTColor.accent.opacity(0.44) : KLTColor.divider.opacity(0.58), lineWidth: 1)
        )
        .shadow(color: KLTColor.navy.opacity(0.10), radius: 5, y: 3)
    }
}

private struct ProgressPlate: View {
    let methodText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Recalculating full image")
                    .font(.plexSans(11, weight: .semibold))
            }
            Text(methodText)
                .font(.plexMono(9))
                .foregroundStyle(KLTColor.inkMuted)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 13)
        .frame(minWidth: 220, alignment: .leading)
        .background(KLTColor.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.white.opacity(0.48), lineWidth: 1))
        .shadow(color: KLTColor.navy.opacity(0.22), radius: 15, y: 7)
        .accessibilityElement(children: .combine)
    }
}

private struct StatusBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.plexSans(10))
            .foregroundStyle(Color(hex: 0x71430F))
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 430, alignment: .leading)
            .background(Color(hex: 0xFFF9F2).opacity(0.96), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KLTColor.warning.opacity(0.36), lineWidth: 1))
            .shadow(color: KLTColor.navy.opacity(0.16), radius: 12, y: 5)
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("analysis-status-banner")
    }
}
