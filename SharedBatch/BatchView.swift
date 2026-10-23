import KLTCore
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BatchView: View {
    @State var model: BatchModel
    let close: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsAll = false
    @State private var confirmClose = false
    @State private var picker: PickerKind?
    @AccessibilityFocusState private var headingFocused: Bool
    #if os(iOS)
    @State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    private enum PickerKind: String, Identifiable { case files, photos, folder, cleanup
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            #if os(iOS)
            GeometryReader { geometry in
                if textSize.isAccessibilitySize || geometry.size.height < 600 {
                    scrollingMobileLayout(width: geometry.size.width)
                } else {
                    standardLayout
                }
            }
            #else
            standardLayout
            #endif
        }
        #if os(iOS)
        .disclosureGroupStyle(BatchDisclosureStyle())
        .toggleStyle(BatchToggleStyle())
        #endif
        .font(.plexSans(14)).foregroundStyle(KLTColor.inkStrong)
        .background(KLTColor.surface).tint(KLTColor.accent).preferredColorScheme(.light)
        .interactiveDismissDisabled()
        .task { await model.prepare() }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.mode)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.finished)
        .onChange(of: model.finished) { _, finished in if finished { headingFocused = true; endBackgroundTask() } }
        .onChange(of: scenePhase) { _, phase in
            #if os(iOS)
            if phase == .background && model.running {
                backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Stop batch") { model.stop(interrupted: true); endBackgroundTask() }
                model.stop(interrupted: true)
            }
            #endif
        }
        .confirmationDialog("Stop this batch and close?", isPresented: $confirmClose, titleVisibility: .visible) {
            Button("Keep processing", role: .cancel) {}
            Button("Stop and close", role: .destructive) { model.dismiss(close) }
        } message: { Text("Saved files stay in the run folder. The current operation must finish stopping before the list and outcome clear.") }
        #if os(iOS)
        .sheet(item: $picker, onDismiss: { model.picking = false }) { kind in
            if kind == .photos {
                BatchPhotosPicker(remaining: 100 - model.entries.count) { entries in
                    model.add(entries, generation: model.selectionGeneration); picker = nil
                }
            } else {
                BatchFilesPicker(folders: kind != .files) { urls in
                    accept(urls, kind: kind); picker = nil
                }
            }
        }
        #else
        .frame(minWidth: 760, idealWidth: 1060, maxWidth: .infinity, minHeight: 600, idealHeight: 760)
        .background(BatchMacWindowGuard(model: model, close: close))
        #endif
    }
    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("KLT IMAGE").font(.plexMono(10, weight: .semibold)).tracking(1).foregroundStyle(KLTColor.inkMuted)
            Text(model.heading).font(.plexSans(20, weight: .bold)).accessibilityAddTraits(.isHeader)
                .accessibilityFocused($headingFocused)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var standardLayout: some View {
        VStack(spacing: 0) {
            headerLayout {
                heading
                if !stacksHeader { Spacer(minLength: 8) }
                Button("Close", action: requestClose).keyboardShortcut(.cancelAction)
                    .buttonStyle(BatchActionStyle(kind: .secondary))
                    .accessibilityIdentifier("batch-close")
            }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(KLTColor.surfaceRaised)
            Divider()
            GeometryReader { geometry in
                ScrollView { batchContent(width: geometry.size.width) }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { footer() }
    }

    #if os(iOS)
    /// Large instructions and titles must scroll instead of consuming the
    /// setup viewport. Only dismissal and an active stop action remain pinned.
    private func scrollingMobileLayout(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button(action: requestClose) {
                    Image(systemName: "xmark").font(.system(size: 20, weight: .semibold))
                        .frame(width: 44, height: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).accessibilityLabel("Close")
                .accessibilityIdentifier("batch-close").keyboardShortcut(.cancelAction)
                Spacer(minLength: 0)
                if model.running {
                    Button { model.stop() } label: {
                        Image(systemName: "stop.circle").font(.system(size: 24))
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).disabled(model.stopping)
                    .accessibilityLabel(model.stopping ? "Stopping…" : "Cancel batch")
                    .accessibilityIdentifier("batch-cancel")
                }
            }.padding(.horizontal, 16).padding(.vertical, 6).background(KLTColor.surfaceRaised)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heading.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                    Divider()
                    batchContent(width: width)
                    footer(showsRunningAction: false)
                }
            }
            .accessibilityIdentifier("batch-scroll-content")
        }
    }
    #endif

    private func batchContent(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if let notice = model.notice { Text(notice).foregroundStyle(KLTColor.ink).accessibilityIdentifier("batch-notice") }
            if !model.receipts.isEmpty { cleanupSection }
            if model.waiting {
                Text("Waiting for the current operation…")
                Text("The current image stays unchanged. Finish or cancel that operation before setting up a batch.")
                    .foregroundStyle(KLTColor.inkMuted)
            } else if model.running || model.finished { outcomes }
            else if width >= 900 && !textSize.isAccessibilitySize {
                HStack(alignment: .top, spacing: 24) {
                    sources(compact: false).frame(width: (width - 72) * 0.4)
                    Divider()
                    settings.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else { sources(compact: true); Divider(); settings }
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sources(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { sectionTitle("Images"); Spacer(); Text("\(model.entries.count) / 100").font(.plexMono(12)) }
            Text("Up to 100 images per batch").foregroundStyle(KLTColor.inkMuted)
            #if os(iOS)
            VStack(alignment: .leading, spacing: 4) { addButtons }
            #else
            ViewThatFits(in: .horizontal) {
                HStack { addButtons }
                VStack(alignment: .leading) { addButtons }
            }
            #endif
            if model.entries.isEmpty {
                Text("Choose your photographs").font(.plexSans(16, weight: .semibold)).padding(.top, 16)
                Text("Add JPEG, PNG, TIFF, or HEIC files. Your original images stay unchanged.")
            }
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(model.entries.enumerated()).prefix(compact && !showsAll ? 2 : 100), id: \.element.id) { index, entry in
                    Divider()
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%03d", index + 1)).font(.plexMono(11)).foregroundStyle(KLTColor.inkMuted)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name).font(.plexSans(14, weight: .semibold))
                            Text(entry.selectionError ?? "Not checked").font(.plexSans(12)).foregroundStyle(KLTColor.inkMuted)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        Button { model.entries.removeAll { $0.id == entry.id } } label: { Image(systemName: "xmark").frame(minWidth: removeWidth, minHeight: 44).contentShape(Rectangle()) }
                            .buttonStyle(.plain).accessibilityLabel("Remove \(index + 1), \(entry.name)")
                    }.padding(.vertical, 8)
                }
            }
            if compact && model.entries.count > 2 {
                Button(showsAll ? "Show fewer images" : "Show all \(model.entries.count) images") { showsAll.toggle() }
                    .batchQuietAction()
            }
            Text("Each source is read when its turn begins, not when selected.").font(.plexSans(12)).foregroundStyle(KLTColor.ink)
            DisclosureGroup("Resource limits") {
                let limits = BatchLimits.current
                Text("\(limits.pixels / 1_000_000) million oriented pixels per image. Source: \(limits.sourceBytes / 1_048_576) MiB. Encoded image: \(limits.imageBytes / 1_048_576) MiB. JSON: 1 MiB. All temporary storage: \(limits.temporaryBytes / 1_048_576) MiB, including unfinished output. No downsampling or reduced quality.")
                    .font(.plexSans(12)).padding(.top, 8)
            }
        }
    }
    @ViewBuilder private var addButtons: some View {
        Button("Add files…") { choose(.files) }.batchQuietAction().disabled(model.entries.count == 100 || model.picking)
        #if os(iOS)
        Button("Add from Photos…") { choose(.photos) }.batchQuietAction().disabled(model.entries.count == 100 || model.picking)
        #endif
        Button("Clear") { model.entries = [] }.batchQuietAction().disabled(model.entries.isEmpty || model.picking)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Processing method")
                ForEach(BatchModel.Mode.allCases, id: \.self) { mode in
                    Button { model.mode = mode } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: model.mode == mode ? "largecircle.fill.circle" : "circle").padding(.top, 2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.rawValue).font(.plexSans(15, weight: .semibold))
                                Text(mode == .calculate ? "Fit a new transform from each image's own whole-image statistics." : "Apply one saved transform unchanged. No target statistics are fitted.")
                                    .font(.plexSans(13)).foregroundStyle(KLTColor.ink)
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.padding(12).background(model.mode == mode ? KLTColor.accentSoft : KLTColor.surfaceRaised, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                }
                if model.mode == .calculate {
                    batchPicker("Working space", value: model.spaces.first { $0.id.identifier == model.spaceID }?.libraryName ?? "Choose", selection: $model.spaceID) {
                        ForEach(model.spaces) { Text($0.libraryName).tag($0.id.identifier) }
                    }
                    batchPicker("Matrix", value: model.matrix == .covariance ? "Covariance" : "Correlation", selection: $model.matrix) {
                        Text("Covariance").tag(AnalysisMatrixMode.covariance)
                        Text("Correlation").tag(AnalysisMatrixMode.correlation)
                    }
                    Text("Whole-image statistics").font(.plexSans(14, weight: .semibold))
                    Text("Each fit is independent. Matching settings do not establish quantitative color comparability.").font(.plexSans(12))
                } else {
                    batchPicker("Saved transform", value: model.selectedRecipe?.libraryName ?? "Choose a transform", selection: $model.recipeID) {
                        Text("Choose a transform").tag(UUID?.none)
                        ForEach(model.recipes) { Text($0.libraryName).tag(Optional($0.id)) }
                    }
                    if model.recipes.isEmpty {
                        Text("No saved transforms yet").font(.plexSans(14, weight: .semibold))
                        Text("Create a transform from a result, or import a transform in Methods. Close Batch to use that workflow. Analysis JSON cannot be replayed.").font(.plexSans(12))
                    }
                    if let recipe = model.selectedRecipe {
                        DisclosureGroup("Captured origin and method") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(recipe.recipe.originSource.displayFilename)
                                Text("\(recipe.recipe.originSource.width) × \(recipe.recipe.originSource.height) · \(recipe.recipe.workingSpaceNameAtCapture)")
                                Text("\(recipe.recipe.originatingAnalysis.matrixMode.rawValue) · \(recipe.recipe.originatingAnalysis.samplingMode.rawValue)")
                                if let region = recipe.recipe.originatingAnalysis.region {
                                    Text("Origin region: x \(region.sourcePixels.x), y \(region.sourcePixels.y), \(region.sourcePixels.width) × \(region.sourcePixels.height) pixels")
                                    Text("The saved region describes the original fit. It is not applied to these images.")
                                }
                            }.font(.plexSans(12)).padding(.top, 8)
                        }
                    }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("Save results")
                batchPicker("Format", value: model.format.displayName, selection: $model.format) {
                    ForEach(ImageExportFormat.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
                Text(model.format == .jpeg ? "Full source resolution · JPEG is lossy and does not preserve transparency. Quality 94%." : "Full source resolution · Transparency preserved").font(.plexSans(12))
                Toggle("Include analysis JSON", isOn: $model.includesRecord)
                Text("One record beside each image, tied to its exact result.").font(.plexSans(12)).foregroundStyle(KLTColor.inkMuted)
                Text(model.destination == nil ? "Choose an output folder" : model.destinationDescription).font(.plexSans(14, weight: .semibold)).textSelection(.enabled)
                Button(model.destination == nil ? "Choose folder…" : "Change folder…") { choose(.folder) }
                    .batchQuietAction()
                DisclosureGroup("New run folder") { Text(model.proposedFolder).font(.plexMono(11)).textSelection(.enabled).padding(.top, 8) }
                Text("A new folder is created at Start. Existing files are never replaced.").font(.plexSans(12))
                Text("Temporary output files can appear in the selected run folder while saving. Cloud syncing is managed by your provider.").font(.plexSans(12)).foregroundStyle(KLTColor.inkMuted)
            }
        }
    }
    private var outcomes: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.stopping { Text("Waiting for the active operation and temporary-file cleanup. No more images will start.") }
            if let run = model.run {
                Text("\(run.modeName) · \(run.methodName)").font(.plexSans(16, weight: .semibold))
                Text("\(run.format.displayName)\(run.includesRecord ? " + analysis JSON" : " · No analysis JSON")")
                Text(model.runDestinationDescription).font(.plexSans(14, weight: .semibold)).textSelection(.enabled)
                Text(model.resultFolder?.lastPathComponent ?? run.folderName).font(.plexMono(11))
                    .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
            }
            if model.running {
                ProgressView(value: Double(model.settledCount), total: Double(max(1, model.outcomes.count)))
                    .accessibilityLabel("Settled images").animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.settledCount)
                Text("\(model.settledCount) of \(model.outcomes.count) settled")
            }
            Text("Total \(model.outcomes.count) · Successful \(model.outcomes.filter { $0.status.successful }.count) · Partial \(count(.partial)) · Failed \(count(.failed)) · Canceled \(count(.canceled)) · Not processed \(count(.notProcessed))")
                .font(.plexSans(14, weight: .semibold)).accessibilityIdentifier("batch-counts")
            sectionTitle("Image outcomes")
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(model.outcomes) { row in
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(String(format: "%03d", row.ordinal)) · \(row.name)").font(.plexSans(14, weight: .semibold))
                        Text(row.status.rawValue).font(.plexMono(12))
                        if let reason = row.reason { Text(reason) }
                        if let image = row.imageName { Text(image).font(.plexMono(11)).textSelection(.enabled) }
                        if let record = row.recordName { Text(record).font(.plexMono(11)).textSelection(.enabled) }
                        if row.status == .failed { Text("No output saved").foregroundStyle(KLTColor.inkMuted) }
                    }.padding(.vertical, 12).accessibilityElement(children: .combine)
                }
            }
        }
    }
    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Temporary output needs cleanup")
            Text("\(model.debt) bytes reserved of \(BatchLimits.current.temporaryBytes) bytes.")
            Text("Select the associated KLT Batch folder to remove only KLT Image's unfinished temporary files. Saved images and other files stay in place.")
            DisclosureGroup("Identify the folder") {
                ForEach(Array(Set(model.receipts.map(\.ownerToken))).sorted(by: { $0.uuidString < $1.uuidString }), id: \.self) {
                    Text($0.uuidString).font(.plexMono(11)).textSelection(.enabled)
                }
            }
            Button("Select run folder…") { choose(.cleanup) }.batchQuietAction().disabled(model.running || model.picking)
        }.padding(16).background(KLTColor.surfaceTint, in: RoundedRectangle(cornerRadius: 8))
    }
    private func footer(showsRunningAction: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            VStack(alignment: .leading, spacing: 12) {
                #if os(iOS)
                Text("Keep KLT Image open in the foreground").font(.plexSans(12, weight: .semibold))
                #endif
                if model.running {
                    if showsRunningAction {
                        Button(model.stopping ? "Stopping…" : "Cancel batch") { model.stop() }
                            .disabled(model.stopping).buttonStyle(BatchActionStyle(kind: .secondary)).accessibilityIdentifier("batch-cancel")
                    }
                } else if model.finished {
                    Button("Return to setup") { model.returnToSetup(); headingFocused = true }
                        .buttonStyle(BatchActionStyle(kind: .primary)).accessibilityIdentifier("batch-return")
                } else {
                    if let reason = model.disabledReason { Text(reason).font(.plexSans(12)) }
                    Button("Start batch · \(model.entries.count)", action: model.start)
                        .disabled(model.disabledReason != nil).buttonStyle(BatchActionStyle(kind: .primary)).accessibilityIdentifier("batch-start")
                }
            }.padding(.horizontal, 24).padding(.bottom, 16)
        }.background(KLTColor.surfaceRaised)
    }
    @ViewBuilder private func batchPicker<Selection: Hashable, Options: View>(
        _ title: String, value: String, selection: Binding<Selection>, @ViewBuilder options: () -> Options
    ) -> some View {
        #if os(iOS)
        Menu {
            Picker(title, selection: selection, content: options)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.plexSans(12)).foregroundStyle(KLTColor.inkMuted)
                HStack { Text(value); Image(systemName: "chevron.down") }
            }.fixedSize(horizontal: false, vertical: true)
        }.buttonStyle(BatchActionStyle(kind: .secondary))
        #else
        Picker(title, selection: selection, content: options)
        #endif
    }
    private var stacksHeader: Bool {
        #if os(iOS)
        textSize.isAccessibilitySize
        #else
        false
        #endif
    }
    private var headerLayout: AnyLayout {
        stacksHeader ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
    }
    private var removeWidth: CGFloat {
        #if os(iOS)
        44
        #else
        32
        #endif
    }
    private func sectionTitle(_ text: String) -> some View { Text(text).font(.plexSans(16, weight: .semibold)).accessibilityAddTraits(.isHeader) }
    private func count(_ status: BatchOutcome.Status) -> Int { model.outcomes.filter { $0.status == status }.count }
    private func requestClose() { if model.running { confirmClose = true } else { model.dismiss(close) } }
    private func choose(_ kind: PickerKind) {
        model.picking = true; model.selectionGeneration = UUID()
        #if os(macOS)
        let generation = model.selectionGeneration
        let panel = NSOpenPanel(); panel.canChooseFiles = kind == .files; panel.canChooseDirectories = kind != .files
        panel.allowsMultipleSelection = kind == .files
        if kind == .files { panel.allowedContentTypes = [.jpeg, .png, .tiff, .heic] }
        panel.begin { response in
            guard model.selectionGeneration == generation else { return }
            if response == .OK { accept(panel.urls, kind: kind) }
            model.picking = false
        }
        #else
        picker = kind
        #endif
    }
    private func accept(_ urls: [URL], kind: PickerKind) {
        model.picking = false
        if kind == .files { model.add(urls.map { BatchInputEntry(name: $0.lastPathComponent, source: BatchFileSource(url: $0)) }, generation: model.selectionGeneration) }
        else if let url = urls.first { if kind == .cleanup { model.cleanup(url) } else { model.chooseDestination(url) } }
    }
    private func endBackgroundTask() {
        #if os(iOS)
        if backgroundTask != .invalid { UIApplication.shared.endBackgroundTask(backgroundTask); backgroundTask = .invalid }
        #endif
    }
}

/// Mobile hit geometry belongs to the label, so the accessible Button and its
/// tappable content both grow; an outer frame alone only enlarges layout space.
private struct BatchActionStyle: ButtonStyle {
    enum Kind { case primary, secondary, quiet }
    let kind: Kind
    @Environment(\.isEnabled) private var isEnabled
    @ViewBuilder func makeBody(configuration: Configuration) -> some View {
        #if os(iOS)
        configuration.label
            .font(.plexSans(14, weight: .semibold))
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12).padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundStyle(!isEnabled ? KLTColor.inkMuted : kind == .primary ? KLTColor.surfaceRaised : KLTColor.inkStrong)
            .background(background(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                if kind == .secondary { RoundedRectangle(cornerRadius: 8).stroke(KLTColor.divider, lineWidth: 1) }
            }
        #else
        switch kind {
        case .primary: PrimaryActionButtonStyle().makeBody(configuration: configuration)
        case .secondary: SecondaryActionButtonStyle().makeBody(configuration: configuration)
        case .quiet: configuration.label
        }
        #endif
    }
    private func background(pressed: Bool) -> Color {
        switch kind {
        case .primary: !isEnabled ? KLTColor.surfaceTint : pressed ? KLTColor.accentPressed : KLTColor.accent
        case .secondary: pressed ? KLTColor.surfaceTint : KLTColor.surfaceRaised
        case .quiet: pressed ? KLTColor.surfaceTint : .clear
        }
    }
}

#if os(iOS)
/// Preserve the native switch appearance while making its whole labelled row
/// one 44-point action, including the space above and below the switch graphic.
private struct BatchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack {
                configuration.label.fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 12)
                Toggle("", isOn: configuration.$isOn).labelsHidden().toggleStyle(.switch)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

private struct BatchDisclosureStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { configuration.isExpanded.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    configuration.label.fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Image(systemName: configuration.isExpanded ? "chevron.up" : "chevron.down")
                }.frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content }
        }
    }
}
#endif

private extension View {

    @ViewBuilder func batchQuietAction() -> some View {
        #if os(iOS)
        buttonStyle(BatchActionStyle(kind: .quiet))
        #else
        self
        #endif
    }
}
