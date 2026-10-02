import CoreGraphics
import KLTCore
import SwiftUI
import UIKit

/// One source-pixel map drives both image layers and the sample outline.
struct RegisteredViewport {
    let source: CGSize
    let canvas: CGSize
    let zoom: CGFloat
    let pan: CGSize

    var fit: CGSize {
        let scale = min(canvas.width / source.width, canvas.height / source.height)
        return CGSize(width: source.width * scale, height: source.height * scale)
    }

    var imageFrame: CGRect {
        CGRect(x: (canvas.width - fit.width * zoom) / 2 + pan.width,
               y: (canvas.height - fit.height * zoom) / 2 + pan.height,
               width: fit.width * zoom, height: fit.height * zoom)
    }

    func sourcePoint(_ viewPoint: CGPoint) -> CGPoint {
        let frame = imageFrame
        return CGPoint(x: (viewPoint.x - frame.minX) / frame.width * source.width,
                       y: (viewPoint.y - frame.minY) / frame.height * source.height)
    }

    func viewRect(_ region: SourcePixelRegion) -> CGRect {
        let frame = imageFrame
        return CGRect(x: frame.minX + CGFloat(region.x) / source.width * frame.width,
                      y: frame.minY + CGFloat(region.y) / source.height * frame.height,
                      width: CGFloat(region.width) / source.width * frame.width,
                      height: CGFloat(region.height) / source.height * frame.height)
    }

    func clampedPan(_ proposed: CGSize) -> CGSize {
        let limitX = max(0, (fit.width * zoom - canvas.width) / 2)
        let limitY = max(0, (fit.height * zoom - canvas.height) / 2)
        return CGSize(width: min(limitX, max(-limitX, proposed.width)),
                      height: min(limitY, max(-limitY, proposed.height)))
    }

    func zoomedPan(factor: CGFloat, around point: CGPoint, newZoom: CGFloat) -> CGSize {
        let relative = CGPoint(x: point.x - canvas.width / 2, y: point.y - canvas.height / 2)
        let proposed = CGSize(width: (pan.width - relative.x) * factor + relative.x,
                              height: (pan.height - relative.y) * factor + relative.y)
        return RegisteredViewport(source: source, canvas: canvas, zoom: newZoom, pan: pan).clampedPan(proposed)
    }
}

private enum TouchPhase { case began, changed, ended }

private struct TouchSurface: UIViewRepresentable {
    var pan: (TouchPhase, CGPoint, CGSize) -> Void
    var pinch: (TouchPhase, CGFloat, CGPoint) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.panned(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinched(_:)))
        pan.delegate = context.coordinator
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(pinch)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.pan = pan
        context.coordinator.pinch = pinch
    }

    func makeCoordinator() -> Coordinator { Coordinator(pan: pan, pinch: pinch) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var pan: (TouchPhase, CGPoint, CGSize) -> Void
        var pinch: (TouchPhase, CGFloat, CGPoint) -> Void
        init(pan: @escaping (TouchPhase, CGPoint, CGSize) -> Void,
             pinch: @escaping (TouchPhase, CGFloat, CGPoint) -> Void) {
            self.pan = pan; self.pinch = pinch
        }
        @objc func panned(_ gesture: UIPanGestureRecognizer) {
            let phase: TouchPhase = gesture.state == .began ? .began :
                gesture.state == .changed ? .changed : .ended
            let translation = gesture.translation(in: gesture.view)
            pan(phase, gesture.location(in: gesture.view),
                CGSize(width: translation.x, height: translation.y))
        }
        @objc func pinched(_ gesture: UIPinchGestureRecognizer) {
            let phase: TouchPhase = gesture.state == .began ? .began :
                gesture.state == .changed ? .changed : .ended
            pinch(phase, gesture.scale, gesture.location(in: gesture.view))
            gesture.scale = 1
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { false }
    }
}

struct RegisteredCanvas: View {
    let workspace: IOSWorkspace
    @Binding var drawingSample: Bool
    @State private var draftRegion: SourcePixelRegion?
    @State private var owner: Owner = .none
    @State private var touchStart = CGPoint.zero
    @State private var panStart = CGSize.zero
    @State private var regionStart: SourcePixelRegion?
    @State private var revealStart = 0.5

    private enum Owner {
        case none, canvas, divider, create, move
        case resizeTopLeft, resizeTopRight, resizeBottomLeft, resizeBottomRight
        var isRegionEdit: Bool {
            switch self {
            case .create, .move, .resizeTopLeft, .resizeTopRight, .resizeBottomLeft, .resizeBottomRight: true
            default: false
            }
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                LinearGradient(colors: [IOSPalette.surfaceTint, IOSPalette.canvas],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if let source = workspace.source {
                    switch workspace.comparison {
                    case .original:
                        imagePane(original: source.originalImage, processed: nil, size: size, region: true)
                    case .processed:
                        imagePane(original: nil, processed: workspace.currentResult?.image.image, size: size, region: false)
                    case .slider:
                        imagePane(original: source.originalImage, processed: workspace.currentResult?.image.image,
                                  size: size, region: true)
                    case .sideBySide:
                        HStack(spacing: 1) {
                            imagePane(original: source.originalImage, processed: nil,
                                      size: CGSize(width: (size.width - 1) / 2, height: size.height), region: true)
                            imagePane(original: nil, processed: workspace.currentResult?.image.image,
                                      size: CGSize(width: (size.width - 1) / 2, height: size.height), region: false)
                        }
                    }
                    touchLayer(size: size)
                    VStack {
                        HStack {
                            Text("\(Int(workspace.zoom * 100))%")
                            Spacer()
                            Text(workspace.currentResult == nil ? "WAITING" : workspace.isReplayed ? "REPLAYED" : "CALCULATED")
                        }
                        .font(IOSFont.mono(10))
                        .padding(8)
                        .background(IOSPalette.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
                        Spacer()
                    }.padding(12).allowsHitTesting(false)
                } else {
                    ContentUnavailableView("No image open", systemImage: "photo.artframe",
                                           description: Text("Choose a full-resolution image from Photos or Files."))
                }
            }
            .clipped()
        }
        .accessibilityLabel("Registered comparison image, zoom \(Int(workspace.zoom * 100)) percent")
    }

    @ViewBuilder private func imagePane(
        original: CGImage?, processed: CGImage?, size: CGSize, region: Bool
    ) -> some View {
        let source = workspace.source!
        let viewport = RegisteredViewport(
            source: CGSize(width: source.width, height: source.height), canvas: size,
            zoom: workspace.zoom, pan: workspace.pan
        )
        ZStack(alignment: .topLeading) {
            IOSPalette.canvas
            if let original { layer(original, frame: viewport.imageFrame) }
            if let processed {
                ZStack(alignment: .topLeading) { layer(processed, frame: viewport.imageFrame) }
                    .frame(width: size.width, height: size.height)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: workspace.comparison == .slider ? size.width * workspace.reveal : size.width)
                    }
            }
            if region, let sample = draftRegion ?? workspace.region {
                let rect = viewport.viewRect(sample)
                Rectangle().strokeBorder(IOSPalette.accent, lineWidth: 2)
                    .background(IOSPalette.accent.opacity(0.1))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                ForEach(0..<4, id: \.self) { corner in
                    Circle().fill(IOSPalette.surface).stroke(IOSPalette.accent, lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .position(
                            x: corner.isMultiple(of: 2) ? rect.minX : rect.maxX,
                            y: corner < 2 ? rect.minY : rect.maxY
                        )
                }
            }
            if workspace.comparison == .slider, processed != nil {
                Rectangle().fill(IOSPalette.surface)
                    .frame(width: 2, height: size.height)
                    .position(x: size.width * workspace.reveal, y: size.height / 2)
                Text("◀  ▶").font(IOSFont.mono(10)).padding(8)
                    .background(IOSPalette.surface, in: Capsule())
                    .position(x: size.width * workspace.reveal, y: size.height / 2)
                    .accessibilityLabel("Reveal processed image")
                    .accessibilityValue("\(Int(workspace.reveal * 100)) percent")
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: workspace.reveal = min(1, workspace.reveal + 0.1)
                        case .decrement: workspace.reveal = max(0, workspace.reveal - 0.1)
                        @unknown default: break
                        }
                    }
            }
            VStack {
                Spacer()
                HStack {
                    Text(original == nil ? "PROCESSED" : "ORIGINAL")
                    Spacer()
                    if original != nil, processed != nil { Text("PROCESSED") }
                }
                .font(IOSFont.mono(10))
                .padding(6)
                .background(IOSPalette.surface.opacity(0.9), in: RoundedRectangle(cornerRadius: 5))
                .padding(8)
            }
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    private func layer(_ image: CGImage, frame: CGRect) -> some View {
        Image(decorative: image, scale: 1)
            .resizable()
            .interpolation(.high)
            .frame(width: frame.width, height: frame.height)
            .position(x: frame.midX, y: frame.midY)
    }

    private func touchLayer(size: CGSize) -> some View {
        TouchSurface(
            pan: { phase, location, translation in handlePan(phase, location: location, translation: translation, size: size) },
            pinch: { phase, scale, location in handlePinch(phase, scale: scale, location: location, size: size) }
        )
        .accessibilityHidden(true)
    }

    private func paneContext(_ location: CGPoint, size: CGSize) -> (RegisteredViewport, CGPoint) {
        guard let source = workspace.source else {
            fatalError("Touch surface requires source")
        }
        let side = workspace.comparison == .sideBySide
        let width = side ? (size.width - 1) / 2 : size.width
        let local = CGPoint(x: side && location.x >= width ? location.x - width - 1 : location.x,
                            y: location.y)
        let viewport = RegisteredViewport(
            source: CGSize(width: source.width, height: source.height),
            canvas: CGSize(width: width, height: size.height),
            zoom: workspace.zoom, pan: workspace.pan
        )
        return (viewport, local)
    }

    private func handlePan(_ phase: TouchPhase, location: CGPoint, translation: CGSize, size: CGSize) {
        guard workspace.source != nil else { return }
        let (viewport, local) = paneContext(location, size: size)
        switch phase {
        case .began:
            touchStart = local
            panStart = workspace.pan
            regionStart = workspace.region
            revealStart = workspace.reveal
            if drawingSample, let region = workspace.region {
                let rect = viewport.viewRect(region)
                if hypot(local.x - rect.minX, local.y - rect.minY) < 30 { owner = .resizeTopLeft }
                else if hypot(local.x - rect.maxX, local.y - rect.minY) < 30 { owner = .resizeTopRight }
                else if hypot(local.x - rect.minX, local.y - rect.maxY) < 30 { owner = .resizeBottomLeft }
                else if hypot(local.x - rect.maxX, local.y - rect.maxY) < 30 { owner = .resizeBottomRight }
                else if rect.insetBy(dx: -12, dy: -12).contains(local) { owner = .move }
                else { owner = .create }
            } else if drawingSample { owner = .create }
            else if workspace.comparison == .slider && abs(location.x - size.width * workspace.reveal) <= 34 {
                owner = .divider
            } else { owner = .canvas }
        case .changed:
            switch owner {
            case .divider:
                workspace.reveal = min(1, max(0, revealStart + translation.width / size.width))
            case .canvas:
                workspace.pan = viewport.clampedPan(CGSize(width: panStart.width + translation.width,
                                                            height: panStart.height + translation.height))
            case .create, .move, .resizeTopLeft, .resizeTopRight, .resizeBottomLeft, .resizeBottomRight:
                draftRegion = transformedRegion(translation: translation, viewport: viewport)
            case .none: break
            }
        case .ended:
            if let draftRegion, owner.isRegionEdit {
                workspace.setRegion(draftRegion)
                drawingSample = false
            }
            draftRegion = nil
            owner = .none
        }
    }

    private func transformedRegion(translation: CGSize, viewport: RegisteredViewport) -> SourcePixelRegion? {
        let end = CGPoint(x: touchStart.x + translation.width, y: touchStart.y + translation.height)
        let startPixel = viewport.sourcePoint(touchStart)
        let endPixel = viewport.sourcePoint(end)
        let dx = Int((endPixel.x - startPixel.x).rounded())
        let dy = Int((endPixel.y - startPixel.y).rounded())
        switch owner {
        case .create:
            return SourcePixelRegion(x: Int(min(startPixel.x, endPixel.x).rounded()),
                                     y: Int(min(startPixel.y, endPixel.y).rounded()),
                                     width: abs(dx), height: abs(dy))
        case .move:
            guard let regionStart else { return nil }
            return SourcePixelRegion(x: regionStart.x + dx, y: regionStart.y + dy,
                                     width: regionStart.width, height: regionStart.height)
        case .resizeTopLeft:
            guard let regionStart else { return nil }
            return SourcePixelRegion(x: regionStart.x + dx, y: regionStart.y + dy,
                                     width: regionStart.width - dx, height: regionStart.height - dy)
        case .resizeTopRight:
            guard let regionStart else { return nil }
            return SourcePixelRegion(x: regionStart.x, y: regionStart.y + dy,
                                     width: regionStart.width + dx, height: regionStart.height - dy)
        case .resizeBottomLeft:
            guard let regionStart else { return nil }
            return SourcePixelRegion(x: regionStart.x + dx, y: regionStart.y,
                                     width: regionStart.width - dx, height: regionStart.height + dy)
        case .resizeBottomRight:
            guard let regionStart else { return nil }
            return SourcePixelRegion(x: regionStart.x, y: regionStart.y,
                                     width: regionStart.width + dx, height: regionStart.height + dy)
        default: return nil
        }
    }

    private func handlePinch(_ phase: TouchPhase, scale: CGFloat, location: CGPoint, size: CGSize) {
        guard workspace.source != nil, owner == .none || owner == .canvas else { return }
        guard phase == .changed else { return }
        let (viewport, local) = paneContext(location, size: size)
        let newZoom = min(4, max(1, workspace.zoom * scale))
        let factor = newZoom / workspace.zoom
        workspace.pan = viewport.zoomedPan(factor: factor, around: local, newZoom: newZoom)
        workspace.zoom = newZoom
    }
}
