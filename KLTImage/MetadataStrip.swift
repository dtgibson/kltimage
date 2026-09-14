import AppKit
import KLTCore
import SwiftUI

private enum ExploratoryGuidanceCopy {
    static let title = "Exploratory enhancement"
    static let detail = "Color differences are amplified for inspection. Coordinate choice, color management, and target mismatch during fixed reuse can amplify noise, compression, lighting differences, clipping, low contrast, or gamut loss. The result is not, by itself, a scientific measurement."
}

struct MetadataStrip: View {
    let source: DecodedImage
    @Bindable var model: WorkspaceModel
    @Binding var showsMethod: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var methodDetailsFocusRequest = 0
    @State private var presentedRecord: AnalysisRecordPresentation?
    @FocusState private var recordTriggerIsFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
            metadataGroup(title: "SOURCE") {
                Text("\(source.width) × \(source.height) pixels")
                    .font(.plexSans(12, weight: .semibold))
                Text("\(source.sourceFormatName) · 8-bit RGB · converted to sRGB")
                    .font(.plexSans(11))
                    .foregroundStyle(KLTColor.inkMuted)
            }
            .frame(width: 240)

            Divider().overlay(KLTColor.line)

            metadataGroup(title: "ACTIVE METHOD") {
                HStack(spacing: 7) {
                    Text(model.methodText)
                        .font(.plexSans(12, weight: .semibold))
                        .lineLimit(1)
                    FocusableIconButton(
                        systemName: "info.circle",
                        accessibilityLabel: "Show \(model.methodText) details",
                        accessibilityIdentifier: "method-details-button",
                        focusRequest: methodDetailsFocusRequest,
                        allowsFocusRequests: !showsMethod
                    ) {
                        showsMethod = true
                    }
                    .frame(width: 18, height: 18)
                    .popover(isPresented: $showsMethod, arrowEdge: .bottom) {
                        MethodPopover(model: model, isPresented: $showsMethod)
                    }
                }
                Text(stabilityText)
                    .font(.plexSans(11))
                    .foregroundStyle(KLTColor.inkMuted)
                    .lineLimit(1)
            }
            .frame(width: 280)

            if geometry.size.width >= 1_040 || model.currentAnalysisRecord == nil {
                Divider().overlay(KLTColor.line)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(KLTColor.accentPressed)
                        .frame(width: 24, height: 24)
                        .background(KLTColor.accentSoft, in: RoundedRectangle(cornerRadius: 7))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ExploratoryGuidanceCopy.title)
                            .font(.plexSans(12, weight: .semibold))
                            .accessibilityHidden(true)
                        Text(ExploratoryGuidanceCopy.detail)
                            .font(.plexSans(11))
                            .foregroundStyle(KLTColor.inkMuted)
                            .lineLimit(2)
                            .accessibilityLabel(ExploratoryGuidanceCopy.detail)
                            .accessibilityIdentifier("exploratory-guidance-detail")
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(ExploratoryGuidanceCopy.title)
                .accessibilityIdentifier("exploratory-guidance")
            }

            if let record = model.currentAnalysisRecord {
                Divider().overlay(KLTColor.line)

                HStack(spacing: 10) {
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("\(model.executionModeText) RECORD · CURRENT")
                            .font(.plexMono(9, weight: .semibold))
                            .tracking(0.55)
                            .foregroundStyle(KLTColor.success)
                            .lineLimit(1)
                        Text("Source, settings, matrices, transform")
                            .font(.plexSans(9))
                            .foregroundStyle(KLTColor.inkMuted)
                            .lineLimit(1)
                    }
                    Button {
                        presentedRecord = presentedRecord == nil ? record : nil
                    } label: {
                        Label("Analysis Record", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .focused($recordTriggerIsFocused)
                    .accessibilityIdentifier("analysis-record-button")
                    .accessibilityHint("Shows the source, settings, matrices, transform, and JSON export for the current result")
                }
                .padding(.horizontal, 16)
                .fixedSize(horizontal: true, vertical: false)
                .popover(
                    item: $presentedRecord,
                    attachmentAnchor: .point(.topLeading),
                    arrowEdge: .bottom
                ) { snapshot in
                    AnalysisRecordView(
                        snapshot: snapshot,
                        closeAction: { presentedRecord = nil },
                        exportAction: model.presentAnalysisRecordExportPanel
                    )
                }
                .accessibilityElement(children: .contain)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
            }
            }
        }
        .frame(height: 94)
        .background(KLTColor.surfaceRaised)
        .overlay(alignment: .top) { Divider().overlay(KLTColor.line) }
        .onChange(of: showsMethod) { wasPresented, isPresented in
            guard wasPresented, !isPresented else { return }
            methodDetailsFocusRequest &+= 1
        }
        .onChange(of: model.currentAnalysisRecord?.id) { _, currentID in
            guard let presentedRecord, presentedRecord.id != currentID else { return }
            self.presentedRecord = nil
        }
        .onChange(of: presentedRecord?.id) { previousID, currentID in
            guard previousID != nil, currentID == nil else { return }
            recordTriggerIsFocused = true
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.15),
            value: model.currentAnalysisRecord?.id
        )
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
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stabilityText: String {
        if model.isReplayed {
            guard let diagnostics = model.replayDiagnostics else { return "Frozen recipe · no target statistics" }
            return diagnostics.sameAsOrigin
                ? "Replayed unchanged · same as origin"
                : "Replayed unchanged · different source · \(diagnostics.clippedFraction.formatted(.percent.precision(.fractionLength(1)))) clipped"
        }
        switch model.phase {
        case .processing:
            return model.enhanced == nil
                ? "Calculating component stability"
                : "Previous result · updating from unchanged source"
        case .awaitingRegion, .invalidRegion:
            return "Region statistics · full-image transform · not current"
        case .failed:
            return "Previous result retained · not current"
        default:
            guard let descriptor = model.enhanced?.descriptor else { return "Calculating component stability" }
            let sample = descriptor.input.sampleSource == .selectedRegion
                ? "Region statistics · full-image transform"
                : "Whole-image statistics · full-image transform"
            return "\(sample) · \(descriptor.stableComponentCount) stable components"
        }
    }
}

private struct MethodPopover: View {
    @Bindable var model: WorkspaceModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(model.methodText)
                    .font(.plexSans(18, weight: .bold))
                Spacer()
                FocusableIconButton(
                    systemName: "xmark",
                    accessibilityLabel: "Close method details",
                    accessibilityIdentifier: "close-method-details-button",
                    requestsInitialFocus: true,
                    closesOnEscape: true
                ) {
                    isPresented = false
                }
                .frame(width: 24, height: 24)
            }

            Text(methodExplanation)
                .font(.plexSans(12))
                .foregroundStyle(KLTColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            methodRow("Statistics from", statisticsSource)
            methodRow("Applied to", "Full \(sourceDimensions) image")
            methodRow("Stable components", stableComponents)
            methodRow("Processing", "Local only")

            Text("Methods are alternative exploratory views, not ranks of accuracy. Color management, Lab conversion, correlation normalization, output-gamut clipping, noise, compression, lighting, region choice, and target mismatch during fixed reuse can affect what you see.")
                .font(.plexSans(10))
                .foregroundStyle(Color(hex: 0x71430F))
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: 0xFFF8EF))
                .overlay(alignment: .leading) {
                    Rectangle().fill(KLTColor.warning).frame(width: 3)
                }
        }
        .padding(18)
        .frame(width: 390)
        .background(KLTColor.surfaceRaised)
        .accessibilityElement(children: .contain)
    }

    private var methodExplanation: String {
        if case let .replayed(recipe, _) = model.methodSelection {
            return "This saved transform applies an earlier calculation unchanged. The target supplies no covariance, correlation, center, eigensystem, range fit, or gamut fit. Origin: \(recipe.originSource.displayFilename)."
        }
        if model.activeWorkingSpace.identity.kind != .standard {
            return "\(model.activeMethodName) maps \(model.activeWorkingSpace.base.displayName) through the inspectable reversible equation working = A × base + b before calculating a new transform."
        }
        let color = model.colorSpace == .rgb
            ? "RGB works from display-oriented red, green, and blue variables."
            : "CIE 1976 Lab D65 separates lightness from two chromatic axes."
        let matrix = model.matrixMode == .covariance
            ? "Covariance preserves the original variable scale while the transform is derived."
            : "Correlation normalizes each stable variable to unit variance while the transform is derived."
        return color + " " + matrix
    }

    private var statisticsSource: String {
        if case let .replayed(recipe, _) = model.methodSelection {
            return "Frozen from \(recipe.originSource.displayFilename) · target inactive"
        }
        if model.sampleSource == .wholeImage {
            return "Whole image · \(model.source?.pixelCount.formatted() ?? "0") px"
        }
        guard let region = model.regionEditor.committed else { return "Selected region required" }
        let (count, overflow) = region.width.multipliedReportingOverflow(by: region.height)
        return overflow ? "Selected region" : "Selected region · \(count.formatted()) px"
    }

    private var sourceDimensions: String {
        guard let source = model.source else { return "source" }
        return "\(source.width) × \(source.height)"
    }

    private var stableComponents: String {
        if model.isReplayed {
            return "No target statistics"
        }
        guard model.resultCurrency == .current, let result = model.enhanced else {
            return model.phase == .processing ? "Calculating" : "Not current"
        }
        return "\(result.descriptor.stableComponentCount) of 3"
    }

    private func methodRow(_ name: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(KLTColor.inkMuted)
            Spacer()
            Text(value)
                .font(.plexMono(11))
                .multilineTextAlignment(.trailing)
        }
        .font(.plexSans(11))
    }
}

private struct FocusableIconButton: NSViewRepresentable {
    let systemName: String
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    var focusRequest = 0
    var requestsInitialFocus = false
    var closesOnEscape = false
    var allowsFocusRequests = true
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action, initialFocusRequest: focusRequest)
    }

    func makeNSView(context: Context) -> FocusableButton {
        let button = FocusableButton()
        button.target = context.coordinator
        button.action = #selector(Coordinator.activate)
        button.isBordered = false
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.focusRingType = .default
        button.setAccessibilityIdentifier(accessibilityIdentifier)
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel
        button.closesOnEscape = closesOnEscape
        button.requestsFocusWhenAttached = requestsInitialFocus
        configureImage(on: button)
        return button
    }

    func updateNSView(_ button: FocusableButton, context: Context) {
        context.coordinator.action = action
        button.setAccessibilityLabel(accessibilityLabel)
        button.toolTip = accessibilityLabel
        button.closesOnEscape = closesOnEscape
        configureImage(on: button)

        guard allowsFocusRequests else {
            button.cancelKeyboardFocusRequests()
            return
        }
        guard context.coordinator.lastFocusRequest != focusRequest else { return }
        context.coordinator.lastFocusRequest = focusRequest
        button.requestKeyboardFocus()
    }

    private func configureImage(on button: NSButton) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        button.image = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityLabel)?
            .withSymbolConfiguration(configuration)
        button.contentTintColor = NSColor(srgbRed: 0.10, green: 0.11, blue: 0.12, alpha: 1)
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        var lastFocusRequest: Int

        init(action: @escaping () -> Void, initialFocusRequest: Int) {
            self.action = action
            lastFocusRequest = initialFocusRequest
        }

        @objc func activate() {
            action()
        }
    }
}

private final class FocusableButton: NSButton {
    var requestsFocusWhenAttached = false
    var closesOnEscape = false
    private var remainingFocusAttempts = 0

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if requestsFocusWhenAttached, window != nil {
            requestKeyboardFocus()
        } else if window == nil {
            cancelKeyboardFocusRequests()
        }
    }

    func requestKeyboardFocus() {
        remainingFocusAttempts = 4
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(attemptKeyboardFocus),
            object: nil
        )
        perform(#selector(attemptKeyboardFocus), with: nil, afterDelay: 0)
    }

    func cancelKeyboardFocusRequests() {
        remainingFocusAttempts = 0
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(attemptKeyboardFocus),
            object: nil
        )
    }

    @objc private func attemptKeyboardFocus() {
        guard remainingFocusAttempts > 0 else { return }
        remainingFocusAttempts -= 1

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKey()
            window.makeFirstResponder(self)
            NSAccessibility.post(element: self, notification: .focusedUIElementChanged)
        }

        if remainingFocusAttempts > 0 {
            perform(#selector(attemptKeyboardFocus), with: nil, afterDelay: 0.05)
        }
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 49 || (closesOnEscape && event.keyCode == 53) {
            performClick(nil)
            return
        }
        super.keyDown(with: event)
    }
}
