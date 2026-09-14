import KLTCore
import SwiftUI

private enum AnalysisRecordTab: Int, CaseIterable, Identifiable {
    case summary
    case matrices
    case appliedTransform

    var id: Self { self }

    var title: String {
        switch self {
        case .summary: "Summary"
        case .matrices: "Matrices"
        case .appliedTransform: "Applied transform"
        }
    }
}

struct AnalysisRecordView: View {
    let snapshot: AnalysisRecordPresentation
    let closeAction: () -> Void
    let exportAction: (AnalysisRecordPresentation) -> Void

    var body: some View {
        switch snapshot.value {
        case let .legacyV1(record):
            LegacyAnalysisRecordView(
                snapshot: snapshot,
                record: record,
                closeAction: closeAction,
                exportAction: exportAction
            )
        case let .extendedV2(record):
            ExtendedAnalysisRecordView(
                snapshot: snapshot,
                record: record,
                closeAction: closeAction,
                exportAction: exportAction
            )
        }
    }
}

private struct LegacyAnalysisRecordView: View {
    let snapshot: AnalysisRecordPresentation
    let record: AnalysisRecord
    let closeAction: () -> Void
    let exportAction: (AnalysisRecordPresentation) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = AnalysisRecordTab.summary
    @FocusState private var closeIsFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            tabs
            ScrollView {
                activePanel
                    .id(selectedTab)
                    .transition(.opacity)
            }
            .scrollIndicators(.visible)
            footer
        }
        .frame(width: 620, height: 610)
        .background(KLTColor.surfaceRaised)
        .environment(\.colorScheme, .light)
        .onAppear { closeIsFocused = true }
        .onExitCommand(perform: closeAction)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Analysis record")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Analysis record")
                    .font(.plexSans(24, weight: .bold))
                    .tracking(-0.5)
                Text("The exact source, settings, and numerical transform behind this result.")
                    .font(.plexSans(11))
                    .foregroundStyle(KLTColor.inkMuted)
                Label("CURRENT · MATCHES DISPLAYED RESULT", systemImage: "circle.fill")
                    .font(.plexMono(9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(KLTColor.success)
                    .labelStyle(RecordStateLabelStyle())
                    .accessibilityLabel("Current. Matches displayed result.")
                    .padding(.top, 2)
            }
            Spacer(minLength: 8)
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.plain)
            .focused($closeIsFocused)
            .accessibilityLabel("Close analysis record")
            .accessibilityIdentifier("close-analysis-record-button")
        }
        .padding(.horizontal, 18)
        .padding(.top, 17)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
    }

    private var tabs: some View {
        HStack(spacing: 3) {
            ForEach(AnalysisRecordTab.allCases) { tab in
                Button {
                    select(tab)
                } label: {
                    VStack(spacing: 8) {
                        Text(tab.title)
                            .font(.plexSans(11, weight: .semibold))
                        Rectangle()
                            .fill(selectedTab == tab ? KLTColor.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                }
                .buttonStyle(.plain)
                .foregroundStyle(selectedTab == tab ? KLTColor.inkStrong : KLTColor.inkMuted)
                .accessibilityLabel(tab.title)
                .accessibilityValue(selectedTab == tab ? "Selected" : "Not selected")
                .accessibilityIdentifier("analysis-record-tab-\(tab.rawValue)")
            }
            Spacer()
        }
        .padding(.horizontal, 18)
        .background(
            LinearGradient(
                colors: [KLTColor.surface, KLTColor.surface.opacity(0.68)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .bottom) { Divider().overlay(KLTColor.line) }
        .onMoveCommand { direction in
            switch direction {
            case .left: moveTab(by: -1)
            case .right: moveTab(by: 1)
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Analysis record sections")
    }

    @ViewBuilder
    private var activePanel: some View {
        switch selectedTab {
        case .summary: summaryPanel
        case .matrices: matricesPanel
        case .appliedTransform: appliedTransformPanel
        }
    }

    private var summaryPanel: some View {
        VStack(spacing: 0) {
            RecordSection(title: "Source identity", detail: "DECODED · ORIENTED") {
                LabeledRecordValue(label: "Filename", value: record.source.displayFilename)
                LabeledRecordValue(
                    label: "Dimensions",
                    value: "\(record.source.width) × \(record.source.height) px"
                )
                LabeledRecordValue(label: "Analysis pixels", value: record.source.analysisPixelFormat)
                LabeledRecordValue(
                    label: "Fingerprint",
                    value: "\(record.source.fingerprint.algorithm):\n\(groupedFingerprint)"
                )
            }

            RecordSection(title: "Request", detail: "STABLE VALUES") {
                LabeledRecordValue(label: "Color space", value: colorSpaceDescription)
                LabeledRecordValue(label: "Matrix mode", value: record.input.method.matrixMode.rawValue)
                LabeledRecordValue(label: "Statistics from", value: statisticsDescription)
                RecordMethodExplanation(
                    title: "RGB / LAB",
                    text: "RGB analyzes encoded display channels. Lab (D65) separates L* lightness from the a* and b* chromatic axes.",
                    accessibilityIdentifier: "analysis-record-color-space-explanation"
                )
                RecordMethodExplanation(
                    title: "COVARIANCE / CORRELATION",
                    text: "Covariance keeps each channel's scale of variation. Correlation normalizes stable channels to unit variance before component analysis.",
                    accessibilityIdentifier: "analysis-record-matrix-mode-explanation"
                )
                if let region = record.region {
                    LabeledRecordValue(
                        label: "Pixel bounds",
                        value: "x \(region.sourcePixels.x) · y \(region.sourcePixels.y) · w \(region.sourcePixels.width) · h \(region.sourcePixels.height)"
                    )
                    LabeledRecordValue(
                        label: "Normalized",
                        value: [region.normalized.x, region.normalized.y, region.normalized.width, region.normalized.height]
                            .map(formatNumber)
                            .joined(separator: " · ")
                    )
                }
            }

            RecordSection(title: "Conventions", detail: "SCHEMA V1", hasDivider: false) {
                LabeledRecordValue(label: "Channel order", value: record.conventions.channelOrder.joined(separator: " · "))
                LabeledRecordValue(label: "Units", value: record.conventions.channelUnits.joined(separator: " · "))
                LabeledRecordValue(label: "Matrices", value: "3 × 3 · \(record.conventions.matrixStorage)")
                LabeledRecordValue(
                    label: "Region origin",
                    value: "\(record.conventions.regionOrigin) · \(record.conventions.regionBounds) bounds"
                )
                Label(AnalysisRecordJSONEncoder.exploratoryUseNotice, systemImage: "exclamationmark.triangle")
                    .font(.plexSans(10))
                    .foregroundStyle(Color(hex: 0x71461B))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(hex: 0xFBF2E8), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("analysis-record-exploratory-notice")
                    .padding(.top, 5)
            }
        }
        .padding(.horizontal, 18)
        .textSelection(.enabled)
    }

    private var matricesPanel: some View {
        VStack(spacing: 0) {
            RecordSection(
                title: "Statistical basis",
                detail: "\(record.mathematics.samplePixelCount.formatted()) SAMPLES"
            ) {
                RecordVector(
                    title: "Channel mean",
                    detail: conventionCaption,
                    values: record.mathematics.mean.values,
                    channels: record.conventions.channelOrder
                )
                RecordMatrix(
                    title: "Covariance",
                    detail: covarianceUnitCaption,
                    values: record.mathematics.covariance.values,
                    channels: record.conventions.channelOrder
                )
                RecordMatrix(
                    title: record.input.method.matrixMode.displayName,
                    detail: "Analyzed matrix · \(conventionCaption)",
                    values: record.mathematics.analysisMatrix.values,
                    channels: record.conventions.channelOrder
                )
            }

            RecordSection(title: "Eigensystem", detail: "DESCENDING · COLUMN VECTORS", hasDivider: false) {
                RecordVector(
                    title: "Eigenvalues",
                    detail: "Largest first · \(conventionCaption)",
                    values: record.mathematics.eigenvalues.values,
                    channels: record.conventions.channelOrder
                )
                RecordMatrix(
                    title: "Eigenvectors",
                    detail: "Corresponding columns · deterministic signs · \(conventionCaption)",
                    values: record.mathematics.eigenvectors.values,
                    channels: record.conventions.channelOrder
                )
                LabeledRecordValue(
                    label: "Stable variables",
                    value: "\(record.mathematics.stableVariableCount) of 3"
                )
                LabeledRecordValue(
                    label: "Stable components",
                    value: "\(record.mathematics.stableComponentCount) of 3"
                )
            }
        }
        .padding(.horizontal, 18)
        .textSelection(.enabled)
    }

    private var appliedTransformPanel: some View {
        VStack(spacing: 0) {
            RecordSection(title: "Applied transform", detail: "ROW-MAJOR · \(conventionCaption.uppercased())") {
                RecordMatrix(
                    title: "Transform",
                    detail: "Applied to the full image · \(conventionCaption)",
                    values: record.mathematics.transform.values,
                    channels: record.conventions.channelOrder
                )
                Text("transformed = mean + transform × (pixel − mean)")
                    .font(.plexMono(10))
                    .foregroundStyle(KLTColor.ink)
                    .padding(11)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KLTColor.surfaceTint)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(KLTColor.navy).frame(width: 2)
                    }
                    .accessibilityLabel("Formula. Transformed equals mean plus transform times pixel minus mean.")
            }

            RecordSection(title: "Output mapping", detail: outputMappingCaption) {
                outputMappingRows
            }

            RecordSection(title: "Record integrity", detail: "VERSION 1", hasDivider: false) {
                LabeledRecordValue(label: "Schema", value: AnalysisRecordJSONEncoder.schemaIdentifier)
                LabeledRecordValue(label: "JSON ordering", value: "sorted keys · row-major matrices")
                LabeledRecordValue(label: "Numeric encoding", value: "finite · locale-independent · round-trippable")
                LabeledRecordValue(label: "Volatile values", value: "no path · timestamp · processing UUID")
            }
        }
        .padding(.horizontal, 18)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private var outputMappingRows: some View {
        switch record.mathematics.outputMapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            LabeledRecordValue(label: "Transformed minimum", value: formatNumber(minimum))
            LabeledRecordValue(label: "Transformed maximum", value: formatNumber(maximum))
            LabeledRecordValue(label: "Uniform output scale", value: formatNumber(scale))
            LabeledRecordValue(label: "Clipping", value: "each encoded sRGB channel to [0, 1]")
            LabeledRecordValue(label: "Alpha", value: "source byte preserved exactly")
        case let .labD65ToSRGB(clipsFiniteOutOfGamutValues):
            LabeledRecordValue(label: "Working space", value: "CIE 1976 Lab · D65")
            LabeledRecordValue(label: "Display conversion", value: "Lab → XYZ D65 → encoded sRGB")
            LabeledRecordValue(
                label: "Finite gamut handling",
                value: clipsFiniteOutOfGamutValues
                    ? "clip each encoded sRGB channel to [0, 1]"
                    : "no finite gamut clipping"
            )
            LabeledRecordValue(label: "Alpha", value: "source byte preserved exactly")
        case .limitedVariationIdentity:
            LabeledRecordValue(label: "Output path", value: "limitedVariationIdentity")
            LabeledRecordValue(label: "Transform", value: "identity · source values unchanged")
            LabeledRecordValue(label: "Alpha", value: "source byte preserved exactly")
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Exported records are deterministic and local.")
                    .font(.plexSans(9))
                    .foregroundStyle(KLTColor.inkMuted)
                Text(snapshot.suggestedFilename)
                    .font(.plexMono(9))
                    .foregroundStyle(KLTColor.ink)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                exportAction(snapshot)
            } label: {
                Label("Export JSON", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(SecondaryActionButtonStyle())
            .controlSize(.small)
            .accessibilityIdentifier("export-analysis-record-button")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(KLTColor.surface)
        .overlay(alignment: .top) { Divider().overlay(KLTColor.line) }
    }

    private var groupedFingerprint: String {
        stride(from: 0, to: record.source.fingerprint.value.count, by: 16).map { offset in
            let start = record.source.fingerprint.value.index(
                record.source.fingerprint.value.startIndex,
                offsetBy: offset
            )
            let end = record.source.fingerprint.value.index(
                start,
                offsetBy: min(16, record.source.fingerprint.value.count - offset)
            )
            return String(record.source.fingerprint.value[start..<end])
        }.joined(separator: " ")
    }

    private var colorSpaceDescription: String {
        switch record.input.method.colorSpace {
        case .rgb: "rgb · encoded sRGB"
        case .lab: "lab · CIE 1976 · D65"
        }
    }

    private var statisticsDescription: String {
        if record.input.sampleSource == .wholeImage {
            return "wholeImage · full source population · \(record.mathematics.samplePixelCount.formatted()) px"
        }
        return "selectedRegion · \(record.mathematics.samplePixelCount.formatted()) px"
    }

    private var conventionCaption: String {
        zip(record.conventions.channelOrder, record.conventions.channelUnits)
            .map { "\($0.0) [\($0.1)]" }
            .joined(separator: " · ")
    }

    private var covarianceUnitCaption: String {
        record.input.method.colorSpace == .rgb
            ? "Encoded sRGB covariance · \(conventionCaption)"
            : "Raw Lab covariance · \(conventionCaption)"
    }

    private var outputMappingCaption: String {
        switch record.mathematics.outputMapping {
        case .rgbGlobalRange: "RGB GLOBAL RANGE"
        case .labD65ToSRGB: "LAB D65 → SRGB"
        case .limitedVariationIdentity: "IDENTITY OUTPUT"
        }
    }

    private func select(_ tab: AnalysisRecordTab) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
            selectedTab = tab
        }
    }

    private func moveTab(by offset: Int) {
        let tabs = AnalysisRecordTab.allCases
        guard let current = tabs.firstIndex(of: selectedTab) else { return }
        select(tabs[(current + offset + tabs.count) % tabs.count])
    }
}

private struct RecordMethodExplanation: View {
    let title: String
    let text: String
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(KLTColor.accent)
                .frame(width: 2)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.plexMono(8, weight: .semibold))
                    .tracking(0.45)
                    .foregroundStyle(KLTColor.accentPressed)
                    .accessibilityHidden(true)
                Text(text)
                    .font(.plexSans(9.5))
                    .foregroundStyle(KLTColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KLTColor.surfaceTint, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(text)")
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct RecordStateLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}

private struct RecordSection<Content: View>: View {
    let title: String
    let detail: String
    var hasDivider = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(.plexSans(12, weight: .semibold))
                    .foregroundStyle(KLTColor.ink)
                Spacer()
                Text(detail)
                    .font(.plexMono(8))
                    .tracking(0.35)
                    .foregroundStyle(KLTColor.inkMuted)
                    .multilineTextAlignment(.trailing)
            }
            content()
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) {
            if hasDivider { Divider().overlay(KLTColor.line) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct LabeledRecordValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(label)
                .font(.plexSans(10))
                .foregroundStyle(KLTColor.inkMuted)
                .frame(width: 145, alignment: .leading)
            Text(value)
                .font(.plexMono(10))
                .foregroundStyle(KLTColor.inkStrong)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

private struct RecordVector: View {
    let title: String
    let detail: String
    let values: [Double]
    let channels: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.plexSans(11, weight: .semibold))
                    .foregroundStyle(KLTColor.ink)
                Text(detail)
                    .font(.plexSans(9))
                    .foregroundStyle(KLTColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 120, alignment: .leading)

            HStack(spacing: 10) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Text(formatNumber(value))
                        .font(.plexMono(10))
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityLabel("\(channels[index]) value \(formatNumber(value))")
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .background(KLTColor.surface)
            .overlay(alignment: .leading) {
                Rectangle().fill(KLTColor.divider).frame(width: 2)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct RecordMatrix: View {
    let title: String
    let detail: String
    let values: [Double]
    let channels: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.plexSans(11, weight: .semibold))
                    .foregroundStyle(KLTColor.ink)
                Text(detail)
                    .font(.plexSans(9))
                    .foregroundStyle(KLTColor.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: 120, alignment: .leading)

            VStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { column in
                            let value = values[(row * 3) + column]
                            Text(formatNumber(value))
                                .font(.plexMono(10))
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .accessibilityLabel(
                                    "Row \(row + 1), \(channels[row]); column \(column + 1), \(channels[column]); value \(formatNumber(value))"
                                )
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                LinearGradient(
                    colors: [KLTColor.accentSoft.opacity(0.55), KLTColor.surface.opacity(0.45)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(alignment: .leading) {
                Rectangle().fill(KLTColor.accent).frame(width: 2)
            }
        }
        .padding(.vertical, 3)
    }
}

private func formatNumber(_ value: Double) -> String {
    String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value)
}

private struct ExtendedAnalysisRecordView: View {
    let snapshot: AnalysisRecordPresentation
    let record: ExtendedAnalysisRecord
    let closeAction: () -> Void
    let exportAction: (AnalysisRecordPresentation) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Analysis record")
                        .font(.plexSans(24, weight: .bold))
                    Text(record.executionMode == "replayed" ? "Replayed unchanged" : "Calculated from this image")
                        .font(.plexMono(10, weight: .semibold))
                        .foregroundStyle(KLTColor.success)
                }
                Spacer()
                Button(action: closeAction) { Image(systemName: "xmark").frame(width: 26, height: 26) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close analysis record")
            }
            .padding(18)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    recordSection("Target source") {
                        value("Filename", record.targetSource.displayFilename)
                        value("Dimensions", "\(record.targetSource.width) × \(record.targetSource.height)")
                        value("Fingerprint", record.targetSource.fingerprint.value)
                    }
                    recordSection("Execution") {
                        value("Mode", record.executionMode.capitalized)
                        value("Working space", record.workingSpaceNameAtExecution)
                        value("Stable identity", record.workingSpace.identity.identifier)
                        value("Definition version", String(record.workingSpace.definitionVersion))
                        value("Base", record.workingSpace.base.displayName)
                    }
                    recordSection("Working-space definition") {
                        Text("working = A × base + b")
                            .font(.plexMono(11, weight: .semibold))
                        value("Base channel order", record.workingSpace.baseChannelOrder.joined(separator: ", "))
                        value("Base channel units", record.workingSpace.baseChannelUnits.joined(separator: ", "))
                        value("Working channel order", record.workingSpace.workingChannelNames.joined(separator: ", "))
                        compactMatrix("Forward · row-major", record.workingSpace.forward.rowMajorValues)
                        compactMatrix("Derived inverse · row-major", record.workingSpace.inverse.rowMajorValues)
                        value("Offset", record.workingSpace.offset.values.map(formatNumber).joined(separator: ", "))
                        value("Output behavior", record.workingSpace.outputBehavior.rawValue)
                    }
                    if let calculation = record.calculation {
                        recordSection("Calculated from target") {
                            value("Matrix", calculation.matrixMode.displayName)
                            value("Sample", calculation.samplingMode.displayName)
                            originatingRegion(calculation.region)
                            value("Sample pixels", calculation.mathematics.samplePixelCount.formatted())
                            value(
                                "Working mean",
                                calculation.mathematics.mean.values.map(formatNumber).joined(separator: ", ")
                            )
                            compactMatrix("Covariance · row-major", calculation.mathematics.covariance.values)
                            compactMatrix(
                                "Analysis matrix · row-major",
                                calculation.mathematics.analysisMatrix.values
                            )
                            value(
                                "Eigenvalues · descending",
                                calculation.mathematics.eigenvalues.values.map(formatNumber).joined(separator: ", ")
                            )
                            compactMatrix(
                                "Eigenvectors · column vectors · row-major",
                                calculation.mathematics.eigenvectors.values
                            )
                            value(
                                "Stable variables",
                                "\(calculation.mathematics.stableVariableCount) of 3"
                            )
                            value(
                                "Stable components",
                                "\(calculation.mathematics.stableComponentCount) of 3"
                            )
                            compactMatrix("Applied transform", calculation.mathematics.transform.values)
                            calculationOutputMapping(calculation.mathematics.outputMapping)
                        }
                    }
                    if let replay = record.replay {
                        recordSection("Frozen recipe") {
                            value("Recipe", replay.recipeNameAtExecution)
                            value("Recipe identity", replay.recipe.identifier.uuidString.lowercased())
                            value("Recipe format", "Version \(replay.recipe.recipeFormatVersion)")
                            value("Algorithm", "\(replay.recipe.algorithm.identifier) · v\(replay.recipe.algorithm.version)")
                            value("Origin", replay.recipe.originSource.displayFilename)
                            value("Origin dimensions", "\(replay.recipe.originSource.width) × \(replay.recipe.originSource.height)")
                            value("Origin analysis pixels", replay.recipe.originSource.analysisPixelFormat)
                            value("Origin fingerprint", replay.recipe.originSource.fingerprint.value)
                            value("Origin matrix", replay.recipe.originatingAnalysis.matrixMode.displayName)
                            value("Origin sample", replay.recipe.originatingAnalysis.samplingMode.displayName)
                            value("Origin sample pixels", replay.recipe.originatingAnalysis.samplePixelCount.formatted())
                            originatingRegion(replay.recipe.originatingAnalysis.region)
                            value("Frozen center", replay.recipe.workingCenter.values.map(formatNumber).joined(separator: ", "))
                            compactMatrix("Applied transform", replay.recipe.transform.rowMajorValues)
                            frozenOutputMapping(replay.recipe.outputMapping)
                            value("Matrix storage", "Row-major")
                            value("Alpha policy", "Preserve source alpha byte")
                            value("Byte quantization", "Clamp unit range · premultiply · round nearest")
                            value("Region convention", "Top-left origin · half-open bounds")
                            Text("The target supplied no statistics, center, eigensystem, range fit, or gamut fit.")
                                .font(.plexSans(10))
                                .foregroundStyle(KLTColor.inkMuted)
                        }
                        recordSection("Target-only diagnostics") {
                            value("Same as origin", replay.diagnostics.sameAsOrigin ? "Yes" : "No · different source")
                            value("Clipped pixels", "\(replay.diagnostics.clippedColorPixelCount) of \(replay.diagnostics.evaluatedPixelCount)")
                            value("Clipped fraction", replay.diagnostics.clippedFraction.formatted(.percent.precision(.fractionLength(2))))
                            if let range = replay.diagnostics.mappedRange { value("Mapped range", formatNumber(range)) }
                        }
                    }
                    Label(TransformRecipeValidator.exploratoryUseNotice, systemImage: "exclamationmark.triangle")
                        .font(.plexSans(10))
                        .foregroundStyle(Color(hex: 0x71430F))
                        .padding(10)
                        .background(Color(hex: 0xFBF2E8))
                }
                .padding(18)
            }
            Divider()
            HStack {
                Text("org.kltimage.analysis-record · VERSION 2")
                    .font(.plexMono(9))
                    .foregroundStyle(KLTColor.inkMuted)
                Spacer()
                Button("Export JSON") { exportAction(snapshot) }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("export-analysis-record-button")
            }
            .padding(14)
        }
        .frame(minWidth: 480, idealWidth: 620, maxWidth: 720, minHeight: 420, idealHeight: 610, maxHeight: 760)
        .background(KLTColor.surfaceRaised)
        .environment(\.colorScheme, .light)
        .onExitCommand(perform: closeAction)
    }

    private func recordSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.plexSans(13, weight: .bold))
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func value(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).foregroundStyle(KLTColor.inkMuted)
            Spacer()
            Text(value).font(.plexMono(10)).textSelection(.enabled).multilineTextAlignment(.trailing)
        }
        .font(.plexSans(10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    @ViewBuilder
    private func originatingRegion(_ region: AnalysisRegionRecord?) -> some View {
        if let region {
            value(
                "Origin region · source pixels",
                "x \(region.sourcePixels.x), y \(region.sourcePixels.y), w \(region.sourcePixels.width), h \(region.sourcePixels.height)"
            )
            value(
                "Origin region · normalized",
                [region.normalized.x, region.normalized.y, region.normalized.width, region.normalized.height]
                    .map(formatNumber).joined(separator: ", ")
            )
        } else {
            value("Origin region", "Whole image · no region")
        }
    }

    @ViewBuilder
    private func calculationOutputMapping(_ mapping: AnalysisOutputMappingRecord) -> some View {
        switch mapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            value("Output mapping", WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue)
            value("Output range", "minimum \(formatNumber(minimum)) · maximum \(formatNumber(maximum))")
            value("Output scale", formatNumber(scale))
            value("Clipping policy", "Clip each encoded sRGB channel to the unit range")
        case let .labD65ToSRGB(clips):
            value("Output mapping", WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue)
            value("Reference white", "0.95047, 1, 1.08883")
            value(
                "Clipping policy",
                clips ? "Clip finite out-of-gamut sRGB values" : "No finite gamut clipping"
            )
        case .limitedVariationIdentity:
            value("Output mapping", "limited-variation-identity")
            value("Output behavior", "Identity; source values remain unchanged")
            value("Clipping policy", "No additional clipping")
        }
        value("Alpha policy", "Preserve source alpha byte")
    }

    @ViewBuilder
    private func frozenOutputMapping(_ mapping: FrozenOutputMapping) -> some View {
        switch mapping {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, clips):
            value("Output mapping", WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue)
            value("Frozen output range", "minimum \(formatNumber(minimum)) · maximum \(formatNumber(maximum))")
            value("Frozen output scale", formatNumber(scale))
            value("Clipping policy", clips ? "Clip mapped values to unit range" : "No unit-range clipping")
        case let .cieLabD65ToClippedSRGBV1(referenceWhite, clips):
            value("Output mapping", WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue)
            value("Reference white", referenceWhite.values.map(formatNumber).joined(separator: ", "))
            value("Clipping policy", clips ? "Clip finite out-of-gamut sRGB values" : "No finite gamut clipping")
        }
    }

    private func compactMatrix(_ label: String, _ values: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.plexSans(10, weight: .semibold))
            ForEach(0..<3, id: \.self) { row in
                let text = matrixRow(values, row: row, separator: "   ")
                Text(text)
                    .font(.plexMono(10))
                    .textSelection(.enabled)
                    .accessibilityLabel("Row \(row + 1): \(matrixRow(values, row: row, separator: ", "))")
            }
        }
        .padding(9)
        .background(KLTColor.surfaceTint)
    }

    private func matrixRow(_ values: [Double], row: Int, separator: String) -> String {
        let start = row * 3
        return [values[start], values[start + 1], values[start + 2]]
            .map { formatNumber($0) }
            .joined(separator: separator)
    }
}

private extension SIMD3 where Scalar == Double {
    var values: [Double] { [x, y, z] }
}
