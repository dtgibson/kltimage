import KLTCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsMethod = false

    var body: some View {
        VStack(spacing: 0) {
            header
            comparisonToolbar
            workspace
            if let source = model.source {
                MetadataStrip(source: source, result: model.enhanced, showsMethod: $showsMethod)
            }
        }
        .background(KLTColor.surface)
        .foregroundStyle(KLTColor.inkStrong)
        .overlay(alignment: .bottom) {
            if let notice = model.exportNotice {
                ExportNotice(text: notice)
                    .padding(.bottom, model.source == nil ? 20 : 114)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: model.exportNotice)
        .background {
            Text(model.statusAnnouncement)
                .accessibilityLabel(model.statusAnnouncement)
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .frame(minWidth: 900, minHeight: 620)
    }

    private var header: some View {
        ZStack {
            VStack(spacing: 2) {
                Text("KLT Image")
                    .font(.plexSans(15, weight: .semibold))
                if let source = model.source {
                    Text("\(model.sourceName) · \(source.width) × \(source.height)")
                        .font(.plexMono(10))
                        .foregroundStyle(KLTColor.inkMuted)
                        .lineLimit(1)
                } else {
                    Text("RGB decorrelation stretch")
                        .font(.plexMono(10))
                        .foregroundStyle(KLTColor.inkMuted)
                }
            }
            .padding(.horizontal, 260)

            HStack(spacing: 8) {
                Spacer()
                if model.isBusy {
                    Button("Cancel", action: model.cancelCurrentOperation)
                        .buttonStyle(SecondaryActionButtonStyle())
                        .keyboardShortcut(.cancelAction)
                        .accessibilityIdentifier("cancel-operation-button")
                        .accessibilityHint("Stops the current local image operation")
                }
                Button(action: model.presentOpenPanel) {
                    Label("Open Image", systemImage: "folder")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .disabled(model.isBusy)
                .accessibilityIdentifier("open-image-button")

                Button(action: model.presentExportPanel) {
                    Label("Export Result", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!model.canExport)
                .accessibilityIdentifier("export-result-button")
            }
            .padding(.trailing, 16)
            .padding(.leading, 78)
        }
        .frame(height: 58)
        .background(KLTColor.surface.opacity(0.96))
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var comparisonToolbar: some View {
        ZStack {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: statusColor.opacity(0.22), radius: 0, x: 0, y: 0)
                    Text(model.statusLabel.uppercased())
                        .font(.plexMono(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(KLTColor.inkMuted)
                    Text("RGB covariance")
                        .font(.plexSans(12, weight: .semibold))
                        .foregroundStyle(KLTColor.ink)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(model.statusLabel). Method: RGB covariance.")

                Spacer()

                zoomControls
            }

            Picker("Image view", selection: $model.comparisonMode) {
                ForEach(ComparisonMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(KLTColor.accent)
            .foregroundStyle(KLTColor.inkStrong)
            // The workspace uses a fixed light scientific palette. Keep the
            // native control in that appearance when macOS itself is dark so
            // unselected segment labels do not become light-on-light.
            .environment(\.colorScheme, .light)
            .padding(1)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(KLTColor.surfaceRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(KLTColor.inkMuted, lineWidth: 1)
            )
            .labelsHidden()
            .frame(width: 254)
            .disabled(!model.canChangePresentation)
            .accessibilityIdentifier("image-view-picker")
            .accessibilityHint("Chooses the original image, split comparison, or enhanced image")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(KLTColor.surfaceTint)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button(action: animatedZoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom out")
            .accessibilityIdentifier("zoom-out-button")
            .keyboardShortcut("-", modifiers: .command)

            Button(action: animatedReset) {
                Text("\(Int((model.zoom * 100).rounded()))%")
                    .font(.plexMono(10))
                    .frame(width: 48)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset synchronized zoom")
            .accessibilityIdentifier("zoom-reset-button")
            .accessibilityValue("\(Int((model.zoom * 100).rounded())) percent")

            Button(action: animatedZoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Zoom in")
            .accessibilityIdentifier("zoom-in-button")
            .keyboardShortcut("+", modifiers: .command)
        }
        .foregroundStyle(model.source == nil ? KLTColor.inkMuted : KLTColor.ink)
        .disabled(model.source == nil)
    }

    @ViewBuilder
    private var workspace: some View {
        if let source = model.source {
            ComparisonCanvas(
                original: source.originalImage,
                enhanced: model.enhanced?.image,
                mode: model.comparisonMode,
                phase: model.phase,
                zoom: $model.zoom,
                pan: $model.pan
            )
        } else {
            EmptyWorkspace(phase: model.phase, openAction: model.presentOpenPanel)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    model.openImage(at: url)
                    return true
                }
        }
    }

    private var statusColor: Color {
        switch model.phase {
        case .ready: KLTColor.success
        case .failed: KLTColor.warning
        case .processing, .exporting: KLTColor.accent
        case .empty: KLTColor.inkMuted
        }
    }

    private func animatedZoomIn() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { model.zoomIn() }
    }

    private func animatedZoomOut() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { model.zoomOut() }
    }

    private func animatedReset() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { model.resetView() }
    }
}

private struct EmptyWorkspace: View {
    let phase: WorkspacePhase
    let openAction: () -> Void

    var body: some View {
        ZStack {
            TechnicalGrid()
            VStack(spacing: 12) {
                Image(systemName: errorMessage == nil ? "photo.on.rectangle.angled" : "exclamationmark.triangle")
                    .font(.system(size: 31, weight: .light))
                    .foregroundStyle(errorMessage == nil ? KLTColor.navy : KLTColor.warning)
                    .accessibilityHidden(true)
                Text(errorMessage == nil ? "Open a photograph to examine its color structure" : "The image did not open")
                    .font(.plexSans(20, weight: .bold))
                    .foregroundStyle(KLTColor.inkStrong)
                Text(errorMessage ?? "JPEG, PNG, TIFF, and HEIC are supported. You can also drop an image here.")
                    .font(.plexSans(13))
                    .foregroundStyle(KLTColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                Button(action: openAction) {
                    Label("Open Image", systemImage: "folder")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .padding(.top, 4)
                .accessibilityIdentifier("empty-open-image-button")
                Text("Your images stay on this Mac.")
                    .font(.plexMono(10))
                    .foregroundStyle(KLTColor.inkMuted)
            }
            .padding(32)
        }
        .accessibilityElement(children: .contain)
    }

    private var errorMessage: String? {
        guard case let .failed(message) = phase else { return nil }
        return message
    }
}

private struct ComparisonCanvas: View {
    let original: CGImage
    let enhanced: CGImage?
    let mode: ComparisonMode
    let phase: WorkspacePhase
    @Binding var zoom: Double
    @Binding var pan: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panAtGestureStart: CGSize?
    @State private var zoomAtGestureStart: Double?

    var body: some View {
        ZStack {
            TechnicalGrid()
            Group {
                switch mode {
                case .original:
                    ImagePane(image: original, label: "Original", accent: false, zoom: zoom, pan: pan)
                case .enhanced:
                    ResultPane(image: enhanced, phase: phase, zoom: zoom, pan: pan)
                case .split:
                    HStack(spacing: 0) {
                        ImagePane(image: original, label: "Original", accent: false, zoom: zoom, pan: pan)
                        Rectangle().fill(KLTColor.divider).frame(width: 1)
                        ResultPane(image: enhanced, phase: phase, zoom: zoom, pan: pan)
                    }
                }
            }
            .transition(.opacity)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(panGesture)
        .simultaneousGesture(magnifyGesture)
        .onTapGesture(count: 2) {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                zoom = 1
                pan = .zero
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: mode)
        .clipped()
        .accessibilityHint("Drag to pan, pinch to zoom, or double-click to fit")
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if panAtGestureStart == nil { panAtGestureStart = pan }
                guard let start = panAtGestureStart else { return }
                pan = CGSize(width: start.width + value.translation.width, height: start.height + value.translation.height)
            }
            .onEnded { _ in panAtGestureStart = nil }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if zoomAtGestureStart == nil { zoomAtGestureStart = zoom }
                guard let start = zoomAtGestureStart else { return }
                zoom = min(8, max(0.25, start * value.magnification))
            }
            .onEnded { _ in zoomAtGestureStart = nil }
    }
}

private struct ImagePane: View {
    let image: CGImage
    let label: String
    let accent: Bool
    let zoom: Double
    let pan: CGSize

    var body: some View {
        GeometryReader { proxy in
            let available = CGSize(width: max(1, proxy.size.width - 48), height: max(1, proxy.size.height - 48))
            let imageSize = CGSize(width: image.width, height: image.height)
            let fitScale = min(available.width / imageSize.width, available.height / imageSize.height)

            ZStack(alignment: .topLeading) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: imageSize.width * fitScale * zoom, height: imageSize.height * fitScale * zoom)
                    .offset(pan)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .shadow(color: KLTColor.navy.opacity(0.16), radius: 12, y: 8)

                PaneLabel(text: label, accent: accent)
                    .padding(14)
            }
            .clipped()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) image pane")
            .accessibilityValue("\(image.width) by \(image.height) pixels at \(Int((zoom * 100).rounded())) percent zoom")
        }
    }
}

private struct ResultPane: View {
    let image: CGImage?
    let phase: WorkspacePhase
    let zoom: Double
    let pan: CGSize

    var body: some View {
        if let image {
            ImagePane(image: image, label: "Enhanced", accent: true, zoom: zoom, pan: pan)
        } else {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 10) {
                    if case .processing = phase {
                        ProgressView()
                            .controlSize(.small)
                        Text("Calculating color components")
                            .font(.plexSans(13, weight: .semibold))
                        Text("RGB covariance · whole image · local only")
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
                    }
                }
                .foregroundStyle(KLTColor.ink)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                PaneLabel(text: "Enhanced", accent: true).padding(14)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Enhanced image pane")
        }
    }
}

private struct PaneLabel: View {
    let text: String
    let accent: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(accent ? KLTColor.accent : KLTColor.inkMuted).frame(width: 6, height: 6)
            Text(text).font(.plexSans(11, weight: .bold))
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

private struct TechnicalGrid: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(KLTColor.canvas))
            var path = Path()
            let spacing: CGFloat = 18
            var x: CGFloat = 0
            while x <= size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(path, with: .color(KLTColor.inkMuted.opacity(0.08)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

private struct MetadataStrip: View {
    let source: DecodedImage
    let result: EnhancedImage?
    @Binding var showsMethod: Bool

    var body: some View {
        HStack(spacing: 0) {
            metadataGroup(title: "SOURCE") {
                Text("\(source.width) × \(source.height) pixels")
                    .font(.plexSans(12, weight: .semibold))
                Text("\(source.sourceFormatName) · 8-bit RGB · converted to sRGB")
                    .font(.plexSans(11))
                    .foregroundStyle(KLTColor.inkMuted)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(KLTColor.line)

            metadataGroup(title: "METHOD") {
                HStack(spacing: 7) {
                    Text("Whole-image covariance")
                        .font(.plexSans(12, weight: .semibold))
                    Button {
                        showsMethod.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(KLTColor.ink)
                    .accessibilityLabel("Show RGB covariance method details")
                    .accessibilityIdentifier("method-details-button")
                    .popover(isPresented: $showsMethod, arrowEdge: .bottom) {
                        MethodPopover(result: result)
                    }
                }
                Text(stabilityText)
                    .font(.plexSans(11))
                    .foregroundStyle(KLTColor.inkMuted)
            }
            .frame(maxWidth: .infinity)

            Divider().overlay(KLTColor.line)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(KLTColor.accentPressed)
                    .frame(width: 24, height: 24)
                    .background(KLTColor.accentSoft, in: RoundedRectangle(cornerRadius: 7))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Exploratory enhancement")
                        .font(.plexSans(12, weight: .semibold))
                    Text("Color differences are amplified for inspection. The result is not, by itself, a scientific measurement.")
                        .font(.plexSans(11))
                        .foregroundStyle(KLTColor.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Exploratory enhancement. Color differences are amplified for inspection. The result is not, by itself, a scientific measurement.")
        }
        .frame(height: 94)
        .background(KLTColor.surfaceRaised)
        .overlay(alignment: .top) { Divider().overlay(KLTColor.line) }
    }

    private func metadataGroup<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.plexMono(10, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(KLTColor.inkMuted)
            content()
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stabilityText: String {
        guard let result else { return "Calculating component stability" }
        if let notice = result.notice { return notice }
        return "\(result.analysis.stableComponentCount) stable components · deterministic result"
    }
}

private struct MethodPopover: View {
    let result: EnhancedImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RGB covariance stretch")
                .font(.plexSans(18, weight: .bold))
            Text("The image is rotated into its principal color components, stable component variances are equalized, then the colors are mapped back to RGB. The source remains unchanged.")
                .font(.plexSans(12))
                .foregroundStyle(KLTColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            methodRow("Sample", "Whole image")
            methodRow("Color space", "sRGB")
            methodRow("Matrix", "Covariance 3 × 3")
            methodRow("Stable components", result.map { String($0.analysis.stableComponentCount) } ?? "Calculating")
            methodRow("Processing", "Local only")
            Text("Alpha is preserved but is not included as a color component.")
                .font(.plexSans(11))
                .foregroundStyle(KLTColor.inkMuted)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(width: 360)
        .background(KLTColor.surfaceRaised)
        .accessibilityElement(children: .contain)
    }

    private func methodRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name).foregroundStyle(KLTColor.inkMuted)
            Spacer()
            Text(value).font(.plexMono(11))
        }
        .font(.plexSans(11))
    }
}

private struct ExportNotice: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "checkmark")
            .font(.plexSans(12, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(KLTColor.navy, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .shadow(color: KLTColor.navy.opacity(0.22), radius: 12, y: 6)
            .accessibilityAddTraits(.isStaticText)
    }
}

#if DEBUG
#Preview("Loaded comparison") {
    ContentView(model: .previewReady())
        .frame(width: 1_220, height: 780)
}

#Preview("Processing") {
    ContentView(model: .previewProcessing())
        .frame(width: 1_220, height: 780)
}

#Preview("Import error") {
    ContentView(model: .previewFailure())
        .frame(width: 1_220, height: 780)
}

#Preview("Empty workspace") {
    ContentView(model: WorkspaceModel())
        .frame(width: 1_220, height: 780)
}
#endif
