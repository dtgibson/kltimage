import KLTCore
import AppKit
import SwiftUI

private enum MethodLibraryTab: String, CaseIterable, Identifiable {
    case spaces = "Working Spaces"
    case recipes = "Saved Transforms"
    var id: Self { self }
}

private struct LibrarySpace: Identifiable {
    let name: String
    let purpose: String
    let revision: WorkingSpaceRevision
    let userItem: UserWorkingSpaceItem?
    let modifiedAt: Date?
    var id: String { revision.identity.identifier }
    var kindName: String { revision.identity.kind.rawValue.capitalized }
}

struct MethodLibraryView: View {
    @Bindable var workspace: WorkspaceModel
    @Bindable private var library: MethodLibraryModel
    let closeAction: () -> Void

    @State private var tab = MethodLibraryTab.spaces
    @State private var selectedSpaceID = WorkingSpaceCatalog.standardRGB.revision.identity.identifier
    @State private var selectedRecipeID: UUID?
    @State private var editorDraft = WorkingSpaceEditorDraft()
    @State private var editingItem: UserWorkingSpaceItem?
    @State private var showsEditor = false
    @State private var renameText = ""
    @State private var renamingSpace: UserWorkingSpaceItem?
    @State private var renamingRecipe: SavedTransformItem?
    @State private var pendingDeleteSpace: UserWorkingSpaceItem?
    @State private var pendingDeleteRecipe: SavedTransformItem?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(workspace: WorkspaceModel, closeAction: @escaping () -> Void) {
        self.workspace = workspace
        _library = Bindable(wrappedValue: workspace.methodLibrary)
        self.closeAction = closeAction
    }

    var body: some View {
        libraryContent
        .environment(\.colorScheme, .light)
        .onExitCommand(perform: closeAction)
        .sheet(isPresented: $showsEditor) {
            WorkingSpaceEditorView(
                draft: $editorDraft,
                editing: editingItem,
                cancel: { showsEditor = false },
                save: saveEditor
            )
        }
        .sheet(item: $library.pendingImport) { pending in
            ImportPreviewView(
                pending: pending,
                incoming: library.incomingSummary(for: pending),
                preflight: library.preflight(for: pending),
                cancel: { library.pendingImport = nil },
                commit: { choice in Task { await library.commitPendingImport(choice) } }
            )
        }
        .sheet(item: $renamingSpace) { item in
            RenameMethodView(
                title: "Rename working space",
                text: $renameText,
                cancel: { renamingSpace = nil },
                commit: {
                    Task {
                        do {
                            try await library.renameSpace(item, to: renameText)
                            renamingSpace = nil
                        } catch {
                            library.reportOperationError(error)
                        }
                    }
                }
            )
        }
        .sheet(item: $renamingRecipe) { item in
            RenameMethodView(
                title: "Rename saved transform",
                text: $renameText,
                cancel: { renamingRecipe = nil },
                commit: {
                    Task {
                        do {
                            try await library.renameRecipe(item, to: renameText)
                            renamingRecipe = nil
                        } catch {
                            library.reportOperationError(error)
                        }
                    }
                }
            )
        }
        .confirmationDialog(
            "Delete this working space? Saved transforms retain their frozen copy. If it is active, RGB will be calculated next.",
            isPresented: Binding(get: { pendingDeleteSpace != nil }, set: { if !$0 { pendingDeleteSpace = nil } })
        ) {
            Button("Delete Working Space", role: .destructive) {
                guard let item = pendingDeleteSpace else { return }
                Task {
                    do {
                        try await workspace.deleteWorkingSpace(item)
                        pendingDeleteSpace = nil
                        selectedSpaceID = WorkingSpaceCatalog.standardRGB.revision.identity.identifier
                    } catch {
                        library.reportOperationError(error)
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteSpace = nil }
        }
        .confirmationDialog(
            "Delete this saved transform? A result already being displayed remains unchanged.",
            isPresented: Binding(get: { pendingDeleteRecipe != nil }, set: { if !$0 { pendingDeleteRecipe = nil } })
        ) {
            Button("Delete Saved Transform", role: .destructive) {
                guard let item = pendingDeleteRecipe else { return }
                Task {
                    do {
                        try await library.deleteRecipe(item)
                        pendingDeleteRecipe = nil
                    } catch {
                        library.reportOperationError(error)
                    }
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteRecipe = nil }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: tab)
    }

    private var libraryContent: some View {
        VStack(spacing: 0) {
            header
            Picker("Method type", selection: $tab) {
                ForEach(MethodLibraryTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .tint(KLTColor.accent)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            Divider()
            HStack(spacing: 0) {
                navigation
                    .frame(minWidth: 250, idealWidth: 300, maxWidth: 320)
                Divider()
                detail
            }
            if let message = library.loadError ?? library.operationError {
                warning(message)
            } else if let message = library.successNotice {
                Text(message)
                    .font(.plexSans(10, weight: .semibold))
                    .foregroundStyle(KLTColor.success)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(
            minWidth: 680,
            idealWidth: 1_010,
            maxWidth: 1_120,
            minHeight: 480,
            idealHeight: 700,
            maxHeight: 820
        )
        .background(KLTColor.surfaceRaised)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Method library").font(.plexSans(22, weight: .bold))
                Text("Working spaces calculate a new transform. Saved transforms replay one accepted calculation unchanged.")
                    .font(.plexSans(11)).foregroundStyle(KLTColor.inkMuted)
            }
            Spacer()
            Button("Import…", action: library.presentImportPanel)
                .buttonStyle(SecondaryActionButtonStyle())
                .accessibilityIdentifier("import-method-button")
            Button(action: closeAction) { Image(systemName: "xmark").frame(width: 26, height: 26) }
                .buttonStyle(.plain)
                .accessibilityLabel("Close method library")
                .accessibilityIdentifier("close-method-library-button")
        }
        .padding(18)
    }

    @ViewBuilder private var navigation: some View {
        ScrollView {
            if tab == .spaces {
                VStack(alignment: .leading, spacing: 14) {
                    spaceGroup("STANDARD", spaces: standardSpaces)
                    spaceGroup("CURATED", spaces: curatedSpaces)
                    spaceGroup("MY SPACES", spaces: userSpaces)
                    Button {
                        editingItem = nil
                        editorDraft = WorkingSpaceEditorDraft(libraryName: "New working space")
                        showsEditor = true
                    } label: { Label("New Working Space", systemImage: "plus") }
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("new-working-space-button")
                }
                .padding(14)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SAVED TRANSFORMS · \(library.snapshot.savedTransforms.count)")
                        .font(.plexMono(9, weight: .semibold)).foregroundStyle(KLTColor.inkMuted)
                    if library.snapshot.savedTransforms.isEmpty {
                        Text("Save an accepted calculated result to create a frozen reusable recipe.")
                            .font(.plexSans(11)).foregroundStyle(KLTColor.inkMuted).padding(.vertical, 8)
                    }
                    ForEach(library.snapshot.savedTransforms) { item in
                        Button { selectedRecipeID = item.id } label: {
                            libraryRow(
                                name: item.libraryName,
                                detail: "\(item.recipe.workingSpaceNameAtCapture) · recipe v\(item.recipe.recipeFormatVersion)",
                                modifiedAt: item.modifiedAt,
                                selected: selectedRecipeID == item.id
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("saved-transform-row-\(item.id.uuidString.lowercased())")
                    }
                }
                .padding(14)
            }
        }
        .background(KLTColor.surface)
    }

    @ViewBuilder private var detail: some View {
        if tab == .spaces, let selectedSpace {
            workingSpaceDetail(selectedSpace)
        } else if tab == .recipes,
                  let selectedRecipeID,
                  let item = library.snapshot.savedTransforms.first(where: { $0.id == selectedRecipeID }) {
            recipeDetail(item)
        } else {
            VStack(spacing: 8) {
                Image(systemName: tab == .spaces ? "slider.horizontal.3" : "square.stack.3d.up")
                    .font(.system(size: 28, weight: .light)).foregroundStyle(KLTColor.inkMuted)
                Text("Select a \(tab == .spaces ? "working space" : "saved transform")")
                    .font(.plexSans(14, weight: .semibold))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var standardSpaces: [LibrarySpace] {
        library.standardSpaces.map { LibrarySpace(name: $0.libraryName, purpose: $0.purpose, revision: $0.revision, userItem: nil, modifiedAt: nil) }
    }
    private var curatedSpaces: [LibrarySpace] {
        library.curatedSpaces.map { LibrarySpace(name: $0.libraryName, purpose: $0.purpose, revision: $0.revision, userItem: nil, modifiedAt: nil) }
    }
    private var userSpaces: [LibrarySpace] {
        library.snapshot.userWorkingSpaces.map { LibrarySpace(name: $0.libraryName, purpose: $0.purpose ?? "User-defined reversible coordinates.", revision: $0.revision, userItem: $0, modifiedAt: $0.modifiedAt) }
    }
    private var selectedSpace: LibrarySpace? {
        (standardSpaces + curatedSpaces + userSpaces).first { $0.id == selectedSpaceID }
    }

    private func spaceGroup(_ title: String, spaces: [LibrarySpace]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) · \(spaces.count)").font(.plexMono(9, weight: .semibold)).foregroundStyle(KLTColor.inkMuted)
            if spaces.isEmpty { Text("No user-defined spaces yet.").font(.plexSans(10)).foregroundStyle(KLTColor.inkMuted) }
            ForEach(spaces) { item in
                Button { selectedSpaceID = item.id } label: {
                    libraryRow(
                        name: item.name,
                        detail: "\(item.revision.base.displayName) · v\(item.revision.definitionVersion) · \(item.kindName)",
                        modifiedAt: item.modifiedAt,
                        selected: selectedSpaceID == item.id
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("working-space-row-\(item.id)")
            }
        }
    }

    private func libraryRow(name: String, detail: String, modifiedAt: Date?, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(name).font(.plexSans(11, weight: .semibold)).foregroundStyle(KLTColor.inkStrong)
            Text(detail).font(.plexMono(8)).foregroundStyle(KLTColor.inkMuted).lineLimit(1)
            if let modifiedAt {
                Text("Modified \(modifiedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.plexSans(9))
                    .foregroundStyle(KLTColor.inkMuted)
                    .lineLimit(1)
                    .accessibilityLabel("Last modified \(modifiedAt.formatted(date: .long, time: .shortened))")
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? KLTColor.accentSoft : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? KLTColor.accent.opacity(0.38) : Color.clear))
        .accessibilityElement(children: .combine)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func workingSpaceDetail(_ item: LibrarySpace) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                detailTitle(item.name, tags: [item.kindName, item.revision.base.displayName, "Definition v\(item.revision.definitionVersion)"])
                Text(item.purpose).font(.plexSans(12)).foregroundStyle(KLTColor.ink)
                technicalValue("Stable identity", item.revision.identity.identifier)
                Text("working = A × base + b").font(.plexMono(12, weight: .semibold))
                matrixView("Forward matrix · 3 × 3 · row-major", item.revision.forward.rowMajorValues, channels: item.revision.workingChannelNames)
                technicalValue("Offset", vectorText(item.revision.offset))
                matrixView("Derived inverse", item.revision.inverse.rowMajorValues, channels: item.revision.baseChannelOrder)
                if let validation = try? WorkingSpaceValidator.validate(item.revision) {
                    technicalValue("Condition number", format(validation.conditionNumber))
                }
                technicalValue("Base channels", item.revision.baseChannelOrder.joined(separator: ", "))
                technicalValue("Units", item.revision.baseChannelUnits.joined(separator: ", "))
                technicalValue("Output behavior", item.revision.outputBehavior.rawValue)
                Text("This space changes exploratory coordinates. It does not rank, detect, or prove a biological feature.")
                    .font(.plexSans(10)).foregroundStyle(KLTColor.inkMuted)
                HStack {
                    if let user = item.userItem {
                        Button("Rename") { renameText = user.libraryName; renamingSpace = user }
                        Button("Edit") { editorDraft = WorkingSpaceEditorDraft(item: user); editingItem = user; showsEditor = true }
                        Button("Duplicate") {
                            Task {
                                do { _ = try await library.duplicateSpace(user) }
                                catch { library.reportOperationError(error) }
                            }
                        }
                        Button("Export Definition") { library.export(user) }
                        Button("Delete", role: .destructive) { pendingDeleteSpace = user }
                    } else {
                        Button("Duplicate") {
                            let descriptor = WorkingSpaceDescriptor(libraryName: item.name, purpose: item.purpose, revision: item.revision)
                            Task {
                                do { _ = try await library.duplicateSpace(descriptor) }
                                catch { library.reportOperationError(error) }
                            }
                        }
                    }
                    Spacer()
                    Button("Use for Calculation") {
                        workspace.useWorkingSpace(item.revision, name: item.name)
                        closeAction()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("use-working-space-button")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(20)
        }
    }

    private func recipeDetail(_ item: SavedTransformItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                detailTitle(item.libraryName, tags: ["Saved Transform", "Recipe v\(item.recipe.recipeFormatVersion)"])
                technicalValue("Origin", "\(item.recipe.originSource.displayFilename) · \(item.recipe.originSource.width) × \(item.recipe.originSource.height)")
                technicalValue("Origin fingerprint", item.recipe.originSource.fingerprint.value)
                technicalValue("Captured working space", item.recipe.workingSpaceNameAtCapture)
                technicalValue("Working-space identity", item.recipe.workingSpace.identity.identifier)
                technicalValue("Definition version", String(item.recipe.workingSpace.definitionVersion))
                technicalValue("Base", item.recipe.workingSpace.base.displayName)
                technicalValue("Base channel order", item.recipe.workingSpace.baseChannelOrder.joined(separator: ", "))
                technicalValue("Base channel units", item.recipe.workingSpace.baseChannelUnits.joined(separator: ", "))
                technicalValue("Working channel names", item.recipe.workingSpace.workingChannelNames.joined(separator: ", "))
                matrixView(
                    "Frozen forward mapping · 3 × 3 · row-major",
                    item.recipe.workingSpace.forward.rowMajorValues,
                    channels: item.recipe.workingSpace.workingChannelNames
                )
                technicalValue("Frozen offset", vectorText(item.recipe.workingSpace.offset))
                matrixView(
                    "Frozen inverse mapping · 3 × 3 · row-major",
                    item.recipe.workingSpace.inverse.rowMajorValues,
                    channels: item.recipe.workingSpace.baseChannelOrder
                )
                technicalValue("Working-space output behavior", item.recipe.workingSpace.outputBehavior.rawValue)
                technicalValue("Originating analysis", "\(item.recipe.originatingAnalysis.matrixMode.displayName) · \(item.recipe.originatingAnalysis.samplingMode.displayName) · \(item.recipe.originatingAnalysis.samplePixelCount.formatted()) px")
                originatingRegion(item.recipe.originatingAnalysis.region)
                technicalValue("Frozen center", vectorText(item.recipe.workingCenter))
                matrixView("Frozen applied transform", item.recipe.transform.rowMajorValues, channels: item.recipe.workingSpace.workingChannelNames)
                frozenOutputMapping(item.recipe.outputMapping)
                technicalValue("Algorithm", "\(item.recipe.algorithm.identifier) · v\(item.recipe.algorithm.version)")
                technicalValue("Matrix storage", "Row-major")
                technicalValue("Alpha policy", "Preserve source alpha byte")
                technicalValue("Byte quantization", "Clamp unit range · premultiply · round nearest")
                technicalValue("Region convention", "Top-left origin · half-open bounds")
                warning("Fixed reuse can amplify noise, compression, lighting mismatch, clipping, or poor contrast. Color management differences and target mismatch can change the appearance. The recipe is never adapted to its target.")
                HStack {
                    Button("Rename") { renameText = item.libraryName; renamingRecipe = item }
                    Button("Duplicate") {
                        Task {
                            do { _ = try await library.duplicateRecipe(item) }
                            catch { library.reportOperationError(error) }
                        }
                    }
                    Button("Export Recipe") { library.export(item) }
                    Button("Delete", role: .destructive) { pendingDeleteRecipe = item }
                    Button("Apply to Another Image") { workspace.applyRecipeToAnotherImage(item); closeAction() }
                    Spacer()
                    Button("Apply to Current Image") { workspace.applyRecipe(item); closeAction() }
                        .buttonStyle(PrimaryActionButtonStyle())
                        .disabled(workspace.source == nil)
                        .accessibilityIdentifier("apply-saved-transform-button")
                }
                .buttonStyle(SecondaryActionButtonStyle())
            }
            .padding(20)
        }
    }

    private func detailTitle(_ title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.plexSans(20, weight: .bold))
            HStack { ForEach(tags, id: \.self) { Text($0.uppercased()).font(.plexMono(8, weight: .semibold)).padding(5).background(KLTColor.surfaceTint, in: RoundedRectangle(cornerRadius: 5)) } }
        }
    }

    private func matrixView(_ title: String, _ values: [Double], channels: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.plexSans(11, weight: .semibold))
            ForEach(0..<3, id: \.self) { row in
                HStack {
                    Text(channels.indices.contains(row) ? channels[row] : "Row \(row + 1)").font(.plexMono(9)).frame(width: 120, alignment: .leading)
                    ForEach(0..<3, id: \.self) { column in
                        Text(format(values[row * 3 + column])).font(.plexMono(10)).frame(maxWidth: .infinity, alignment: .trailing)
                            .accessibilityLabel("Row \(row + 1), column \(column + 1), value \(format(values[row * 3 + column]))")
                    }
                }
            }
        }
        .padding(10).background(KLTColor.surfaceTint).overlay(alignment: .leading) { Rectangle().fill(KLTColor.accent).frame(width: 2) }
    }

    private func technicalValue(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) { Text(title).foregroundStyle(KLTColor.inkMuted); Spacer(); Text(value).font(.plexMono(9)).textSelection(.enabled).multilineTextAlignment(.trailing) }
            .font(.plexSans(10))
    }

    private func warning(_ message: String) -> some View {
        Text(message).font(.plexSans(10)).foregroundStyle(Color(hex: 0x71430F)).padding(10)
            .frame(maxWidth: .infinity, alignment: .leading).background(Color(hex: 0xFBF2E8))
            .overlay(alignment: .leading) { Rectangle().fill(KLTColor.warning).frame(width: 3) }
    }

    @ViewBuilder
    private func originatingRegion(_ region: AnalysisRegionRecord?) -> some View {
        if let region {
            technicalValue(
                "Originating region · source pixels",
                "x \(region.sourcePixels.x), y \(region.sourcePixels.y), w \(region.sourcePixels.width), h \(region.sourcePixels.height)"
            )
            technicalValue(
                "Originating region · normalized",
                [region.normalized.x, region.normalized.y, region.normalized.width, region.normalized.height]
                    .map(format).joined(separator: ", ")
            )
        } else {
            technicalValue("Originating region", "Whole image · no region")
        }
    }

    @ViewBuilder
    private func frozenOutputMapping(_ mapping: FrozenOutputMapping) -> some View {
        switch mapping {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, clips):
            technicalValue("Output mapping", WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue)
            technicalValue("Frozen output range", "minimum \(format(minimum)) · maximum \(format(maximum))")
            technicalValue("Frozen output scale", format(scale))
            technicalValue("Clipping policy", clips ? "Clip mapped values to unit range" : "No unit-range clipping")
        case let .cieLabD65ToClippedSRGBV1(referenceWhite, clips):
            technicalValue("Output mapping", WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue)
            technicalValue("Reference white", vectorText(referenceWhite))
            technicalValue("Clipping policy", clips ? "Clip finite out-of-gamut sRGB values" : "No finite gamut clipping")
        }
    }

    private func saveEditor() {
        Task {
            do {
                let item: UserWorkingSpaceItem
                if let editingItem { item = try await library.updateSpace(editingItem, draft: editorDraft) }
                else { item = try await library.saveNewSpace(editorDraft) }
                selectedSpaceID = item.revision.identity.identifier
                if editingItem != nil {
                    workspace.useUpdatedWorkingSpaceIfActive(item)
                }
                showsEditor = false
            } catch {
                library.reportOperationError(error)
            }
        }
    }

    private func vectorText(_ value: SIMD3<Double>) -> String { [value.x, value.y, value.z].map(format).joined(separator: ", ") }
    private func format(_ value: Double) -> String { String(format: "%.12g", locale: Locale(identifier: "en_US_POSIX"), value) }
}

private struct WorkingSpaceEditorView: View {
    @Binding var draft: WorkingSpaceEditorDraft
    let editing: UserWorkingSpaceItem?
    let cancel: () -> Void
    let save: () -> Void
    @FocusState private var nameIsFocused: Bool

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 14) {
            Text(editing == nil ? "New working space" : "Edit working space")
                .font(.plexSans(20, weight: .bold))
            Text("working = A × base + b · decimal values only · 3 × 3 row-major")
                .font(.plexMono(10)).foregroundStyle(KLTColor.inkMuted)
            TextField("Library name", text: $draft.libraryName)
                .focused($nameIsFocused)
                .accessibilityIdentifier("working-space-library-name")
            TextField("Purpose (optional)", text: $draft.purpose)
                .accessibilityIdentifier("working-space-purpose")
            Picker("Base", selection: $draft.base) { ForEach(WorkingSpaceBase.allCases, id: \.self) { Text($0.displayName).tag($0) } }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("working-space-base-picker")
            ViewThatFits(in: .horizontal) {
                HStack { channelFields }
                VStack { channelFields }
            }
            ScrollView(.horizontal) {
            Grid(horizontalSpacing: 7, verticalSpacing: 7) {
                GridRow {
                    Text("")
                    ForEach(draft.base.channelOrder, id: \.self) { Text($0).font(.plexMono(9)) }
                    Text("offset").font(.plexMono(9))
                }
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        Text(draft.channelNames.indices.contains(row) ? draft.channelNames[row] : "Row \(row + 1)").font(.plexMono(9))
                        ForEach(0..<3, id: \.self) { column in
                            TextField("Value", text: arrayBinding($draft.coefficients, row * 3 + column))
                                .font(.plexMono(10))
                                .frame(minWidth: 72, idealWidth: 92)
                                .accessibilityLabel(coefficientLabel(row: row, column: column))
                                .accessibilityValue(draft.coefficients[row * 3 + column])
                                .accessibilityIdentifier("working-space-coefficient-\(row + 1)-\(column + 1)")
                        }
                        offsetField(row: row)
                    }
                }
            }
            .textFieldStyle(.roundedBorder)
            .padding(.bottom, 2)
            }
            validationFeedback
            Spacer()
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(SecondaryActionButtonStyle())
                    .accessibilityIdentifier("cancel-working-space-button")
                Button("Save", action: save)
                    .buttonStyle(PrimaryActionButtonStyle())
                    .disabled(validation == nil)
                    .accessibilityIdentifier("save-working-space-button")
            }
        }
        .padding(20)
        }
        .frame(
            minWidth: 460,
            idealWidth: 660,
            maxWidth: 760,
            minHeight: 420,
            idealHeight: 510,
            maxHeight: 680
        )
        .background(KLTColor.surfaceRaised).environment(\.colorScheme, .light)
        .onAppear { nameIsFocused = true }
    }

    @ViewBuilder private var channelFields: some View {
        ForEach(0..<3, id: \.self) { index in
            TextField("Channel \(index + 1)", text: arrayBinding($draft.channelNames, index))
                .accessibilityLabel("Working channel \(index + 1) name")
                .accessibilityIdentifier("working-space-channel-\(index + 1)")
        }
    }

    @ViewBuilder
    private func offsetField(row: Int) -> some View {
        if row == 2 {
            ReturnSubmittingTextField(
                text: arrayBinding($draft.offsets, row),
                accessibilityLabel: offsetLabel(row: row),
                accessibilityIdentifier: "working-space-offset-\(row + 1)",
                submit: submitFromFinalOffset
            )
            .frame(minWidth: 72, idealWidth: 92)
        } else {
            configuredOffsetField(row: row)
        }
    }

    private func configuredOffsetField(row: Int) -> some View {
        TextField("Value", text: arrayBinding($draft.offsets, row))
            .font(.plexMono(10))
            .frame(minWidth: 72, idealWidth: 92)
            .accessibilityLabel(offsetLabel(row: row))
            .accessibilityValue(draft.offsets[row])
            .accessibilityIdentifier("working-space-offset-\(row + 1)")
    }

    private func submitFromFinalOffset() {
        guard validation != nil else { return }
        save()
    }

    private func coefficientLabel(row: Int, column: Int) -> String {
        let working = draft.channelNames.indices.contains(row) && !draft.channelNames[row].isEmpty
            ? draft.channelNames[row] : "working channel \(row + 1)"
        let base = draft.base.channelOrder.indices.contains(column)
            ? draft.base.channelOrder[column] : "base channel \(column + 1)"
        return "Coefficient row \(row + 1), \(working), base column \(column + 1), \(base)"
    }

    private func offsetLabel(row: Int) -> String {
        let working = draft.channelNames.indices.contains(row) && !draft.channelNames[row].isEmpty
            ? draft.channelNames[row] : "working channel \(row + 1)"
        return "Offset row \(row + 1), \(working)"
    }

    private var validation: ValidatedWorkingSpace? {
        try? draft.validatedRevision(
            identity: editing?.revision.identity ?? WorkingSpaceIdentity(kind: .user, identifier: UUID.zero.uuidString.lowercased()),
            definitionVersion: (editing?.revision.definitionVersion ?? 0) + 1
        )
    }

    private var validationIssue: String {
        do {
            _ = try draft.validatedRevision(
                identity: editing?.revision.identity ?? WorkingSpaceIdentity(kind: .user, identifier: UUID.zero.uuidString.lowercased()),
                definitionVersion: (editing?.revision.definitionVersion ?? 0) + 1
            )
            return "Definition is reversible."
        } catch { return (error as? LocalizedError)?.errorDescription ?? "Definition is invalid." }
    }

    private var validationFeedback: some View {
        HStack {
            Image(systemName: validation == nil ? "exclamationmark.triangle" : "checkmark.circle")
            Text(validationIssue)
            Spacer()
            if let validation { Text("κ∞ \(String(format: "%.6g", validation.conditionNumber))").font(.plexMono(9)) }
        }
        .font(.plexSans(10)).foregroundStyle(validation == nil ? Color(hex: 0x71430F) : KLTColor.success)
        .padding(10).background(validation == nil ? Color(hex: 0xFBF2E8) : KLTColor.success.opacity(0.06))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(validationAccessibilityLabel)
        .accessibilityIdentifier("working-space-validation")
    }

    private var validationAccessibilityLabel: String {
        guard let validation else { return validationIssue }
        return "\(validationIssue) Condition number \(String(format: "%.6g", validation.conditionNumber))."
    }

    private func arrayBinding(_ binding: Binding<[String]>, _ index: Int) -> Binding<String> {
        Binding(get: { binding.wrappedValue.indices.contains(index) ? binding.wrappedValue[index] : "" }, set: { value in
            guard binding.wrappedValue.indices.contains(index) else { return }
            binding.wrappedValue[index] = value
        })
    }
}

private struct ReturnSubmittingTextField: NSViewRepresentable {
    @Binding var text: String
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @ScaledMetric(relativeTo: .caption) private var fontSize: CGFloat = 10
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let submit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, submit: submit)
    }

    func makeNSView(context: Context) -> ReturnSubmittingNSTextField {
        let textField = ReturnSubmittingNSTextField()
        textField.delegate = context.coordinator
        textField.onReturn = { [weak coordinator = context.coordinator] value in
            coordinator?.submit(value)
        }
        textField.placeholderString = "Value"
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.drawsBackground = true
        textField.usesSingleLineMode = true
        textField.lineBreakMode = .byTruncatingTail
        update(textField)
        return textField
    }

    func updateNSView(_ textField: ReturnSubmittingNSTextField, context: Context) {
        context.coordinator.text = $text
        context.coordinator.submit = submit
        if textField.currentEditor() == nil, textField.stringValue != text {
            textField.stringValue = text
        }
        update(textField)
    }

    private func update(_ textField: NSTextField) {
        textField.font = NSFont(name: "IBMPlexMono-Regular", size: fontSize)
            ?? .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textField.appearance = NSAppearance(
            named: colorSchemeContrast == .increased
                ? .accessibilityHighContrastAqua
                : .aqua
        )
        textField.setAccessibilityLabel(accessibilityLabel)
        textField.setAccessibilityValue(text)
        textField.setAccessibilityIdentifier(accessibilityIdentifier)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        var submit: () -> Void

        init(text: Binding<String>, submit: @escaping () -> Void) {
            self.text = text
            self.submit = submit
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.currentEditor()?.string ?? textField.stringValue
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else { return }
            text.wrappedValue = textField.stringValue
        }

        func submit(_ value: String) {
            text.wrappedValue = value
            submit()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            let isReturn = commandSelector == #selector(NSResponder.insertNewline(_:))
                || commandSelector == NSSelectorFromString("insertNewlineIgnoringFieldEditor:")
            guard isReturn else { return false }
            submit(textView.string)
            return true
        }
    }
}

@MainActor
private final class ReturnSubmittingNSTextField: NSTextField {
    var onReturn: ((String) -> Void)?

    override func keyDown(with event: NSEvent) {
        guard event.keyCode == 36 || event.keyCode == 76 else {
            super.keyDown(with: event)
            return
        }
        onReturn?(currentEditor()?.string ?? stringValue)
    }

    override func textDidEndEditing(_ notification: Notification) {
        let movement = (notification.userInfo?[NSText.movementUserInfoKey] as? NSNumber)?.intValue
        let value = (notification.object as? NSText)?.string
            ?? currentEditor()?.string
            ?? stringValue
        super.textDidEndEditing(notification)
        if movement == NSTextMovement.return.rawValue {
            onReturn?(value)
        }
    }
}

private struct RenameMethodView: View {
    let title: String
    @Binding var text: String
    let cancel: () -> Void
    let commit: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.plexSans(18, weight: .bold))
            TextField("Name", text: $text)
            HStack { Spacer(); Button("Cancel", action: cancel); Button("Rename", action: commit).disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(20).frame(width: 420).environment(\.colorScheme, .light)
    }
}

private struct ImportPreviewView: View {
    let pending: PendingMethodImport
    let incoming: MethodImportSummary
    let preflight: MethodImportPreflight
    let cancel: () -> Void
    let commit: (ImportCommitChoice) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Validated method import").font(.plexSans(19, weight: .bold))
            comparison("Incoming", incoming)
            if let local = preflight.local { comparison("Local conflict", local) }
            Text("The current source, result, record, and controls remain unchanged.").font(.plexSans(10)).foregroundStyle(KLTColor.inkMuted)
            if let notice { Text(notice).font(.plexSans(10)).foregroundStyle(KLTColor.warning) }
            HStack {
                Button("Cancel", action: cancel).buttonStyle(SecondaryActionButtonStyle())
                Spacer()
                if preflight.allowsCopy {
                    Button("Import as Copy") { commit(.copy) }.buttonStyle(SecondaryActionButtonStyle())
                }
                if preflight.allowsReplace {
                    Button("Replace") { commit(.replace) }.buttonStyle(SecondaryActionButtonStyle())
                }
                if preflight.allowsAdd {
                    Button("Import") { commit(.add) }.buttonStyle(PrimaryActionButtonStyle())
                }
            }
        }.padding(20).frame(minWidth: 420, idealWidth: 560, maxWidth: 680).environment(\.colorScheme, .light)
    }

    private func comparison(_ title: String, _ value: MethodImportSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.plexMono(9, weight: .semibold)).foregroundStyle(KLTColor.inkMuted)
            Text("\(value.kind.rawValue) · \(value.name)").font(.plexSans(12, weight: .semibold))
            Text("\(value.version) · \(value.detail)").font(.plexSans(10))
            Text("Identity · \(value.identity)").font(.plexMono(9)).textSelection(.enabled)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KLTColor.surfaceTint)
        .accessibilityElement(children: .combine)
    }

    private var notice: String? {
        switch preflight {
        case .add: nil
        case .replace: "A same-type stable identity or normalized name conflicts. Nothing is replaced until you choose."
        case let .copyOnly(_, reason): reason
        case let .rejected(_, error): error.localizedDescription
        }
    }
}

private extension UUID {
    static let zero = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
}
