import KLTCore
import SwiftUI

struct ContentView: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsMethod = false
    @State private var showsLibrary = false

    var body: some View {
        VStack(spacing: 0) {
            header
            comparisonToolbar
            workspace
            if let source = model.source {
                MetadataStrip(
                    source: source,
                    model: model,
                    showsMethod: $showsMethod
                )
            }
        }
        .background(KLTColor.surface)
        .foregroundStyle(KLTColor.inkStrong)
        .environment(\.colorScheme, .light)
        .overlay(alignment: .bottom) {
            if let notice = model.exportNotice {
                ExportNotice(text: notice, isError: model.exportNoticeIsError)
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
        .sheet(isPresented: $showsLibrary) {
            MethodLibraryView(workspace: model, closeAction: { showsLibrary = false })
        }
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
                    Text("RGB and Lab decorrelation stretch")
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
                        .accessibilityHint("Stops the current local file operation")
                }
                Button {
                    showsLibrary = true
                } label: {
                    Label("Methods", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("methods-button")
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
                .accessibilityHint("Exports only the current full-resolution result without the sample overlay")
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
                    Text(model.statusLabel.uppercased())
                        .font(.plexMono(10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(KLTColor.inkMuted)
                    Text(model.executionModeText)
                        .font(.plexMono(9, weight: .semibold))
                        .foregroundStyle(KLTColor.accentPressed)
                    Text(model.methodText)
                        .font(.plexSans(12, weight: .semibold))
                        .foregroundStyle(KLTColor.ink)
                        .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(model.statusLabel). Requested method: \(model.methodText).")
                .accessibilityIdentifier("analysis-status")

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
            .frame(width: 390)
            .disabled(!model.canChangePresentation)
            .accessibilityIdentifier("image-view-picker")
            .accessibilityHint("Chooses Original, Side-by-Side, Slider, or Processed display without recalculating")
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(KLTColor.surfaceTint)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Button(action: animatedZoomOut) {
                Image(systemName: "minus.magnifyingglass").frame(width: 24, height: 24)
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
            .accessibilityLabel("Fit synchronized images")
            .accessibilityIdentifier("zoom-reset-button")
            .accessibilityValue("\(Int((model.zoom * 100).rounded())) percent")

            Button(action: animatedZoomIn) {
                Image(systemName: "plus.magnifyingglass").frame(width: 24, height: 24)
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
        if model.source != nil {
            HStack(spacing: 0) {
                AnalysisControlsView(model: model)
                    .frame(width: 270)
                Rectangle().fill(KLTColor.line).frame(width: 1)
                ComparisonCanvas(model: model)
            }
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
        case .awaitingRegion, .invalidRegion, .failed: KLTColor.warning
        case .processing, .importing, .exporting: KLTColor.accent
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
                if phase == .importing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: errorMessage == nil ? "photo.on.rectangle.angled" : "exclamationmark.triangle")
                        .font(.system(size: 31, weight: .light))
                        .foregroundStyle(errorMessage == nil ? KLTColor.navy : KLTColor.warning)
                        .accessibilityHidden(true)
                }
                Text(title)
                    .font(.plexSans(20, weight: .bold))
                    .foregroundStyle(KLTColor.inkStrong)
                Text(message)
                    .font(.plexSans(13))
                    .foregroundStyle(KLTColor.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
                if phase != .importing {
                    Button(action: openAction) {
                        Label("Open Image", systemImage: "folder")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .padding(.top, 4)
                    .accessibilityIdentifier("empty-open-image-button")
                }
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

    private var title: String {
        if phase == .importing { return "Reading image" }
        return errorMessage == nil
            ? "Open a photograph to examine its color structure"
            : "The image did not open"
    }

    private var message: String {
        if phase == .importing { return "Preparing the unchanged source for local analysis." }
        return errorMessage ?? "JPEG, PNG, TIFF, and HEIC are supported. You can also drop an image here."
    }
}

struct TechnicalGrid: View {
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

private struct ExportNotice: View {
    let text: String
    let isError: Bool

    var body: some View {
        Label(text, systemImage: isError ? "exclamationmark.triangle" : "checkmark")
            .font(.plexSans(12, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 13)
            .frame(height: 38)
            .background(
                isError ? KLTColor.warning : KLTColor.navy,
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .shadow(color: KLTColor.navy.opacity(0.22), radius: 12, y: 6)
            .accessibilityAddTraits(.isStaticText)
    }
}

#if DEBUG
#Preview("Loaded comparison") {
    ContentView(model: .previewReady()).frame(width: 1_220, height: 780)
}

#Preview("Processing") {
    ContentView(model: .previewProcessing()).frame(width: 1_220, height: 780)
}

#Preview("Import error") {
    ContentView(model: .previewFailure()).frame(width: 1_220, height: 780)
}

#Preview("Empty workspace") {
    ContentView(model: WorkspaceModel()).frame(width: 1_220, height: 780)
}
#endif
