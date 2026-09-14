import AppKit
import KLTCore
import SwiftUI

struct AnalysisControlsView: View {
    @Bindable var model: WorkspaceModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var transformSeed: TransformRecipeSnapshot?
    @State private var saveName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heading
                if model.isReplayed {
                    replayedControls
                } else {
                    controlSection(title: "Working space", count: "1 OF 3") {
                        Menu {
                            Section("Standard") {
                                ForEach(model.methodLibrary.standardSpaces) { descriptor in
                                    Button(descriptor.libraryName) {
                                        model.useWorkingSpace(descriptor.revision, name: descriptor.libraryName)
                                    }
                                }
                            }
                            Section("Curated") {
                                ForEach(model.methodLibrary.curatedSpaces) { descriptor in
                                    Button(descriptor.libraryName) {
                                        model.useWorkingSpace(descriptor.revision, name: descriptor.libraryName)
                                    }
                                }
                            }
                            Section("My Spaces") {
                                ForEach(model.methodLibrary.snapshot.userWorkingSpaces) { item in
                                    Button(item.libraryName) { model.useWorkingSpace(item.revision, name: item.libraryName) }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.activeMethodName).font(.plexSans(11, weight: .semibold))
                                    Text("\(model.activeWorkingSpace.identity.kind.rawValue.uppercased()) · \(model.activeWorkingSpace.base.displayName) · V\(model.activeWorkingSpace.definitionVersion)")
                                        .font(.plexMono(8)).foregroundStyle(KLTColor.inkMuted)
                                }
                                Spacer(); Image(systemName: "chevron.up.chevron.down")
                            }
                            .padding(8).background(KLTColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KLTColor.divider))
                        }
                        .menuStyle(.borderlessButton)
                        .accessibilityIdentifier("working-space-picker")
                        .accessibilityLabel("Working space")
                        Picker("Standard working spaces", selection: colorSpaceBinding) {
                            Text("RGB").tag(AnalysisColorSpace.rgb)
                            Text("Lab").tag(AnalysisColorSpace.lab)
                        }
                        .analysisSegmentStyle()
                        .accessibilityIdentifier("color-space-picker")
                        Text("The working space changes the three variables used to calculate this image’s transform.")
                            .controlExplanationStyle()
                    }
                    controlSection(title: "Matrix mode", count: "2 OF 3") {
                        Picker("Matrix mode", selection: matrixModeBinding) {
                            ForEach(AnalysisMatrixMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .analysisSegmentStyle()
                        .accessibilityIdentifier("matrix-mode-picker")
                        Text(matrixExplanation)
                            .controlExplanationStyle()
                    }
                    controlSection(title: "Statistical sample", count: "3 OF 3") {
                        VStack(spacing: 6) {
                            SampleSourceButton(
                                title: "Whole image",
                                detail: "All \(formattedPixelCount) source pixels establish the transform.",
                                selected: model.sampleSource == .wholeImage
                            ) {
                                withAnimation(selectionAnimation) {
                                    model.selectSampleSource(.wholeImage)
                                }
                            }
                            .accessibilityIdentifier("whole-image-sample-button")

                            SampleSourceButton(
                                title: "Selected region",
                                detail: "The rectangle supplies statistics; the complete frame is enhanced.",
                                selected: model.sampleSource == .selectedRegion
                            ) {
                                withAnimation(selectionAnimation) {
                                    model.selectSampleSource(.selectedRegion)
                                }
                            }
                            .accessibilityIdentifier("selected-region-sample-button")
                        }

                        if model.sampleSource == .selectedRegion {
                            RegionEditorView(model: model)
                                .padding(.top, 10)
                                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    saveTransformButton
                }
                methodSummary
            }
        }
        .scrollIndicators(.visible)
        .background(KLTColor.surface)
        .animation(selectionAnimation, value: model.sampleSource)
        .sheet(item: $transformSeed) { seed in
            SaveTransformView(
                seed: seed,
                name: $saveName,
                cancel: { transformSeed = nil },
                save: {
                    Task {
                        do {
                            try await model.saveTransform(seed, name: saveName)
                            transformSeed = nil
                        } catch {
                            model.methodLibrary.reportOperationError(error)
                        }
                    }
                }
            )
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Analysis controls")
                .font(.plexSans(20, weight: .bold))
            Text(model.isReplayed
                 ? "Inspect the frozen method or return to image-specific calculation."
                 : "Choose the coordinates and pixels that calculate a new transform.")
                .font(.plexSans(11))
                .foregroundStyle(KLTColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var replayedControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FROZEN SAVED TRANSFORM")
                .font(.plexMono(9, weight: .semibold)).foregroundStyle(KLTColor.accentPressed)
            Text(model.activeMethodName).font(.plexSans(14, weight: .bold))
            if case let .replayed(recipe, _) = model.methodSelection {
                Text("Origin: \(recipe.originSource.displayFilename)")
                    .font(.plexMono(9)).foregroundStyle(KLTColor.inkMuted)
                Text("\(recipe.originatingAnalysis.matrixMode.displayName) and \(recipe.originatingAnalysis.samplingMode.displayName) are inactive provenance values.")
                    .font(.plexSans(10)).foregroundStyle(KLTColor.inkMuted)
            }
            Text("No values are recalculated from this target.")
                .font(.plexSans(10, weight: .semibold))
            if let diagnostics = model.replayDiagnostics {
                Text("No target statistics · \(diagnostics.clippedFraction.formatted(.percent.precision(.fractionLength(1)))) clipped · local only")
                    .font(.plexMono(8)).foregroundStyle(diagnostics.clippedColorPixelCount > 0 ? KLTColor.warning : KLTColor.inkMuted)
            }
            Button("Calculate for This Image", action: model.calculateForThisImage)
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("calculate-for-this-image-button")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var saveTransformButton: some View {
        Button {
            guard let seed = model.capturedTransformSeed() else { return }
            saveName = "\(model.activeMethodName) transform"
            transformSeed = seed
        } label: {
            Label("Save Calculated Transform", systemImage: "square.and.arrow.down.on.square")
        }
        .buttonStyle(SecondaryActionButtonStyle())
        .disabled(!model.canSaveTransform)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityIdentifier("save-calculated-transform-button")
        .accessibilityHint("Freezes the exact accepted center, transform, inverse, and output mapping")
    }

    private func controlSection<Content: View>(
        title: String,
        count: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(title)
                    .font(.plexSans(12, weight: .semibold))
                    .foregroundStyle(KLTColor.ink)
                Spacer()
                Text(count)
                    .font(.plexMono(9))
                    .foregroundStyle(KLTColor.inkMuted)
            }
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var methodSummary: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "plus.viewfinder")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KLTColor.accentPressed)
                .frame(width: 24, height: 24)
                .background(KLTColor.accentSoft, in: RoundedRectangle(cornerRadius: 7))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.methodText)
                    .font(.plexSans(11, weight: .semibold))
                Text(summaryDetail)
                    .font(.plexSans(9.5))
                    .foregroundStyle(KLTColor.inkMuted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active method: \(model.methodText). \(summaryDetail)")
        .accessibilityIdentifier("active-method-summary")
    }

    private var colorSpaceBinding: Binding<AnalysisColorSpace> {
        Binding(
            get: { model.colorSpace },
            set: { selection in model.selectColorSpace(selection) }
        )
    }

    private var matrixModeBinding: Binding<AnalysisMatrixMode> {
        Binding(
            get: { model.matrixMode },
            set: { selection in model.selectMatrixMode(selection) }
        )
    }

    private var colorSpaceExplanation: String {
        switch model.colorSpace {
        case .rgb: "Uses display-oriented red, green, and blue channel values."
        case .lab: "Separates lightness from two chromatic axes using CIE Lab with D65."
        }
    }

    private var matrixExplanation: String {
        switch model.matrixMode {
        case .covariance: "Preserves each variable's original scale of variation."
        case .correlation: "Normalizes stable variables to unit variance before finding components."
        }
    }

    private var formattedPixelCount: String {
        guard let count = model.source?.pixelCount else { return "the" }
        return count.formatted(.number.notation(.compactName))
    }

    private var summaryDetail: String {
        if model.isReplayed {
            guard let diagnostics = model.replayDiagnostics else {
                return "Frozen recipe · no target statistics"
            }
            return "No target statistics · \(diagnostics.clippedFraction.formatted(.percent.precision(.fractionLength(1)))) clipped · local only"
        }
        switch model.phase {
        case .ready:
            guard let descriptor = model.enhanced?.descriptor else { return "Local processing" }
            return "\(descriptor.stableComponentCount) stable components · local processing"
        case .processing: return "Recalculating full image · local only"
        case .awaitingRegion: return "Awaiting source-pixel bounds · no fallback"
        case .invalidRegion: return "Region needs correction · no fallback"
        case .failed: return "Request needs attention · source preserved"
        case .exporting: return "Exporting current result · local only"
        case .empty, .importing: return "Local processing"
        }
    }

    private var selectionAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.15)
    }
}

private struct SampleSourceButton: View {
    let title: String
    let detail: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(selected ? KLTColor.accent : KLTColor.surfaceRaised)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(selected ? KLTColor.accent : KLTColor.divider, lineWidth: 1.5))
                    .overlay(Circle().stroke(KLTColor.surfaceRaised, lineWidth: 3).padding(2))
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.plexSans(11, weight: .semibold))
                        .foregroundStyle(KLTColor.inkStrong)
                    Text(detail)
                        .font(.plexSans(9.5))
                        .foregroundStyle(KLTColor.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? KLTColor.accentSoft : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(selected ? KLTColor.accent.opacity(0.38) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(detail)
    }
}

private struct RegionEditorView: View {
    @Bindable var model: WorkspaceModel
    @FocusState private var focusedField: RegionField?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(KLTColor.line)
            HStack {
                Text("Source-pixel bounds")
                    .font(.plexSans(11, weight: .semibold))
                    .foregroundStyle(KLTColor.ink)
                Spacer()
                Button("Apply", action: commitAndApplyRegionDraft)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .controlSize(.small)
                    .accessibilityLabel("Apply bounds")
                    .accessibilityIdentifier("apply-region-button")
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                spacing: 6
            ) {
                regionField("X", range: xRange, field: .x, text: draftBinding(.x))
                regionField("Y", range: yRange, field: .y, text: draftBinding(.y))
                regionField("Width", range: widthRange, field: .width, text: draftBinding(.width))
                regionField("Height", range: heightRange, field: .height, text: draftBinding(.height))
            }
            Text("Origin is the source image's top-left. Drag the rectangle or enter exact integers.")
                .font(.plexSans(9))
                .foregroundStyle(KLTColor.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(pixelCountText)
                    .font(.plexMono(9))
                    .foregroundStyle(KLTColor.inkMuted)
                Spacer()
                Button("Clear region", action: model.clearRegion)
                    .buttonStyle(.plain)
                    .font(.plexSans(10))
                    .foregroundStyle(KLTColor.inkMuted)
                    .accessibilityIdentifier("clear-region-button")
            }

            RegionFeedback(issue: currentIssue, hasCommittedRegion: model.regionEditor.committed != nil)
        }
        .onSubmit(commitAndApplyRegionDraft)
    }

    private func regionField(
        _ label: String,
        range: String,
        field: RegionField,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.plexMono(9))
                .foregroundStyle(KLTColor.ink)

            TextField(label, text: text)
                .textFieldStyle(.plain)
                .font(.plexMono(10))
                .padding(.horizontal, 7)
                .frame(height: 28)
                .background(KLTColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(fieldIsInvalid(field) ? KLTColor.warning : KLTColor.divider, lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .accessibilityLabel("Region \(label)")
                .accessibilityValue(text.wrappedValue.isEmpty ? "Empty" : text.wrappedValue)
                .accessibilityHint("Valid range \(range). Origin is the source image's top-left. Press Return to apply all bounds.")
                .accessibilityIdentifier("region-\(label.lowercased())-field")

            Text(range)
                .font(.plexMono(8))
                .foregroundStyle(KLTColor.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func draftBinding(_ field: RegionField) -> Binding<String> {
        Binding(
            get: {
                switch field {
                case .x: model.regionEditor.draftX
                case .y: model.regionEditor.draftY
                case .width: model.regionEditor.draftWidth
                case .height: model.regionEditor.draftHeight
                }
            },
            set: { model.updateRegionDraft(field, value: $0) }
        )
    }

    private func commitAndApplyRegionDraft() {
        // A native macOS text field can still own an uncommitted editor when a
        // SwiftUI button receives its click. End editing first so both pointer
        // submission and Return apply the values that are visibly in the fields.
        focusedField = nil
        NSApp.keyWindow?.makeFirstResponder(nil)
        model.applyRegionDraft()
    }

    private var currentIssue: RegionValidationIssue? {
        switch model.phase {
        case let .awaitingRegion(issue), let .invalidRegion(issue): issue
        default: model.regionEditor.validationIssue
        }
    }

    private func fieldIsInvalid(_ field: RegionField) -> Bool {
        guard let issue = currentIssue else { return false }
        return switch issue {
        case .missing, .nonIntegerValues, .outsideSource: true
        case .nonPositiveSize: field == .width || field == .height
        case .fewerThanFourPixels: field == .width || field == .height
        case .insufficientVariation: false
        }
    }

    private var pixelCountText: String {
        guard let region = model.regionEditor.committed else { return "No committed region" }
        let (count, overflow) = region.width.multipliedReportingOverflow(by: region.height)
        return overflow ? "Pixel count unavailable" : "\(count.formatted()) px"
    }

    private var xRange: String { "0–\(max(0, (model.source?.width ?? 1) - 1))" }
    private var yRange: String { "0–\(max(0, (model.source?.height ?? 1) - 1))" }
    private var widthRange: String { "1–\(model.source?.width ?? 1)" }
    private var heightRange: String { "1–\(model.source?.height ?? 1)" }
}

private struct RegionFeedback: View {
    let issue: RegionValidationIssue?
    let hasCommittedRegion: Bool

    var body: some View {
        Text(message)
            .font(.plexSans(9.5))
            .foregroundStyle(issue == nil ? KLTColor.ink : Color(hex: 0x71430F))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 7)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(issue == nil ? KLTColor.success.opacity(0.06) : Color(hex: 0xFFF7ED))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(issue == nil ? KLTColor.success : KLTColor.warning)
                    .frame(width: 3)
            }
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("region-feedback")
    }

    private var message: String {
        if let issue { return issue.message() }
        if hasCommittedRegion {
            return "Region is valid. Its pixels establish the transform; the full image receives it."
        }
        return "Enter bounds or drag on the source image, then apply the region."
    }
}

private extension View {
    func analysisSegmentStyle() -> some View {
        pickerStyle(.segmented)
            .labelsHidden()
            .tint(KLTColor.accent)
            .foregroundStyle(KLTColor.inkStrong)
            .environment(\.colorScheme, .light)
            .padding(1)
            .background(KLTColor.surfaceTint, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(KLTColor.line, lineWidth: 1))
    }

    func controlExplanationStyle() -> some View {
        font(.plexSans(10))
            .foregroundStyle(KLTColor.inkMuted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SaveTransformView: View {
    let seed: TransformRecipeSnapshot
    @Binding var name: String
    let cancel: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save calculated transform").font(.plexSans(20, weight: .bold))
            Text("Freeze the exact accepted calculation for deterministic replay.")
                .font(.plexSans(11)).foregroundStyle(KLTColor.inkMuted)
            TextField("Transform name", text: $name)
                .accessibilityIdentifier("transform-name-field")
            VStack(alignment: .leading, spacing: 5) {
                Text("\(seed.workingSpaceNameAtCapture) · definition v\(seed.workingSpace.definitionVersion)")
                Text("\(seed.originSource.displayFilename) · \(seed.originatingAnalysis.matrixMode.displayName) · \(seed.originatingAnalysis.samplingMode.displayName)")
                Text("center · transform · inverse · output mapping")
            }
            .font(.plexMono(9)).foregroundStyle(KLTColor.inkMuted)
            HStack {
                Spacer()
                Button("Cancel", action: cancel).buttonStyle(SecondaryActionButtonStyle())
                Button("Save Transform", action: save)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.unicodeScalars.count > 80)
                    .accessibilityIdentifier("confirm-save-transform-button")
            }
        }
        .padding(20).frame(width: 480).background(KLTColor.surfaceRaised).environment(\.colorScheme, .light)
    }
}
