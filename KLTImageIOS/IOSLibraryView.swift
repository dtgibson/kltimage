import KLTCore
import SwiftUI
import UniformTypeIdentifiers

struct IOSLibraryView: View {
    let workspace: IOSWorkspace
    let export: (Data, UTType, String) -> Void
    @State private var editor: SpaceEditorState?
    @State private var inspection: String?
    @State private var importing = false
    @State private var incoming: IOSMethodImport?
    @State private var conflict = false
    @State private var renameSpace: UserWorkingSpaceItem?
    @State private var renameRecipe: SavedTransformItem?
    @State private var nameDraft = ""
    @State private var deleteSpace: UserWorkingSpaceItem?
    @State private var deleteRecipe: SavedTransformItem?
    @State private var saveRecipePrompt = false

    private var canMutate: Bool { workspace.libraryRecoveryError == nil }

    var body: some View {
        List {
            if let recovery = workspace.libraryRecoveryError {
                Section { Text(recovery).foregroundStyle(IOSPalette.warning) }
            }
            Section("Standard") {
                ForEach([WorkingSpaceCatalog.standardRGB, WorkingSpaceCatalog.standardLabD65]) { item in
                    builtInRow(item)
                }
            }
            Section("Curated") {
                ForEach(WorkingSpaceCatalog.curated) { item in builtInRow(item) }
            }
            Section("User working spaces") {
                if workspace.library.userWorkingSpaces.isEmpty { Text("No user spaces yet.").foregroundStyle(IOSPalette.inkMuted) }
                ForEach(workspace.library.userWorkingSpaces) { item in userSpaceRow(item) }
                Button("Create working space", systemImage: "plus") {
                    editor = SpaceEditorState(item: nil, descriptor: nil)
                }.disabled(!canMutate)
            }
            Section("Saved transforms") {
                if workspace.library.savedTransforms.isEmpty { Text("No saved transforms yet.").foregroundStyle(IOSPalette.inkMuted) }
                ForEach(workspace.library.savedTransforms) { item in recipeRow(item) }
                Button("Save current calculated transform", systemImage: "square.and.arrow.down") {
                    nameDraft = "Saved transform"; saveRecipePrompt = true
                }.disabled(!canMutate || !workspace.canSaveTransform)
            }
            Section {
                Button("Import method document", systemImage: "square.and.arrow.down") { importing = true }
                    .disabled(!canMutate)
                Text("Move methods between Mac and iPhone or iPad through explicit JSON file exchange.")
                    .font(IOSFont.body(11)).foregroundStyle(IOSPalette.inkMuted)
            }
        }
        .font(IOSFont.body())
        .navigationTitle("Method library")
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { outcome in
            switch outcome {
            case let .success(url):
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                do {
                    let data = try MethodFileIO.readRegularFile(at: url, maximumByteCount: 262_144)
                    let parsed = try IOSMethodImport.decode(data)
                    incoming = parsed
                    if hasConflict(parsed) { conflict = true }
                    else { Task { await importValue(parsed, choice: .add) } }
                } catch { workspace.presentError(error.localizedDescription) }
            case let .failure(error): workspace.presentError(error.localizedDescription)
            }
        }
        .confirmationDialog("Import conflict", isPresented: $conflict, titleVisibility: .visible) {
            if let incoming {
                if canReplace(incoming) {
                    Button("Replace existing method") { Task { await importValue(incoming, choice: .replace) } }
                }
                Button("Import as Copy") { Task { await importValue(incoming, choice: .copy) } }
            }
            Button("Cancel", role: .cancel) { incoming = nil }
        } message: {
            Text(conflictDescription)
        }
        .confirmationDialog("Delete method?", isPresented: Binding(
            get: { deleteSpace != nil || deleteRecipe != nil },
            set: { if !$0 { deleteSpace = nil; deleteRecipe = nil } }
        )) {
            Button("Delete", role: .destructive) { Task { await deleteSelected() } }
            Button("Cancel", role: .cancel) { deleteSpace = nil; deleteRecipe = nil }
        } message: { Text("This removes the local library item. Current result pixels are unchanged.") }
        .alert("Rename method", isPresented: Binding(
            get: { renameSpace != nil || renameRecipe != nil },
            set: { if !$0 { renameSpace = nil; renameRecipe = nil } }
        )) {
            TextField("Name", text: $nameDraft)
            Button("Save") { Task { await commitRename() } }
            Button("Cancel", role: .cancel) { renameSpace = nil; renameRecipe = nil }
        }
        .alert("Save transform", isPresented: $saveRecipePrompt) {
            TextField("Name", text: $nameDraft)
            Button("Save") { Task { await saveTransform() } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $editor) { state in
            NavigationStack { WorkingSpaceEditor(state: state, workspace: workspace) }
        }
        .sheet(item: Binding(
            get: { inspection.map { Inspection(text: $0) } },
            set: { if $0 == nil { inspection = nil } }
        )) { detail in
            NavigationStack {
                ScrollView { Text(detail.text).font(IOSFont.mono(11)).frame(maxWidth: .infinity, alignment: .leading).padding() }
                    .navigationTitle("Method detail")
                    .toolbar { Button("Close") { inspection = nil } }
            }
        }
    }

    private func builtInRow(_ item: WorkingSpaceDescriptor) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.libraryName).font(IOSFont.label(14))
                Text("Definition v\(item.revision.definitionVersion) · \(item.revision.base.displayName)")
                    .font(IOSFont.mono(10)).foregroundStyle(IOSPalette.inkMuted)
            }
            Spacer()
            Menu {
                Button("Use") { workspace.chooseSpace(item) }
                Button("Inspect") { inspection = describe(item.revision, name: item.libraryName) }
                Button("Duplicate") { editor = SpaceEditorState(item: nil, descriptor: item) }
                    .disabled(!canMutate)
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
        }
    }

    private func userSpaceRow(_ item: UserWorkingSpaceItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.libraryName).font(IOSFont.label(14))
                Text("User space · definition v\(item.revision.definitionVersion)")
                    .font(IOSFont.mono(10)).foregroundStyle(IOSPalette.inkMuted)
            }
            Spacer()
            Menu {
                Button("Use") { workspace.chooseSpace(item) }
                Button("Inspect") { inspection = describe(item.revision, name: item.libraryName) }
                Button("Edit") { editor = SpaceEditorState(item: item, descriptor: nil) }
                Button("Duplicate") { editor = SpaceEditorState(item: nil, descriptor: WorkingSpaceDescriptor(libraryName: item.libraryName, purpose: item.purpose ?? "", revision: item.revision)) }
                Button("Rename") { nameDraft = item.libraryName; renameSpace = item }
                Button("Export") { exportSpace(item) }
                Button("Delete", role: .destructive) { deleteSpace = item }
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
            .disabled(!canMutate)
        }
    }

    private func recipeRow(_ item: SavedTransformItem) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(item.libraryName).font(IOSFont.label(14))
                Text("Recipe v\(item.recipe.recipeFormatVersion) · origin \(item.recipe.originSource.displayFilename)")
                    .font(IOSFont.mono(10)).foregroundStyle(IOSPalette.inkMuted)
            }
            Spacer()
            Menu {
                Button("Apply to current source") { workspace.applyRecipe(item) }.disabled(workspace.source == nil)
                Button("Inspect") { inspection = "\(item.libraryName)\nOrigin: \(item.recipe.originSource.displayFilename)\nWorking space: \(item.recipe.workingSpaceNameAtCapture)\nFrozen values replay unchanged on the target." }
                Button("Duplicate") { Task { await duplicateRecipe(item) } }
                Button("Rename") { nameDraft = item.libraryName; renameRecipe = item }
                Button("Export") { exportRecipe(item) }
                Button("Delete", role: .destructive) { deleteRecipe = item }
            } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
        }
    }

    private func describe(_ revision: WorkingSpaceRevision, name: String) -> String {
        "\(name)\nDefinition v\(revision.definitionVersion)\nBase: \(revision.base.displayName)\nChannels: \(revision.workingChannelNames.joined(separator: ", "))\nForward matrix (row major): \(revision.forward.rowMajorValues.map { String($0) }.joined(separator: ", "))\nOffset: \(revision.offset)\nOutput: \(revision.outputBehavior.rawValue)"
    }

    private func exportSpace(_ item: UserWorkingSpaceItem) {
        do {
            let bytes = try WorkingSpaceDocumentCodec.data(for: WorkingSpaceInterchange(
                libraryName: item.libraryName, purpose: item.purpose, revision: item.revision
            ))
            export(bytes, .json, "\(item.libraryName).klt-space")
        } catch { workspace.presentError(error.localizedDescription) }
    }

    private func exportRecipe(_ item: SavedTransformItem) {
        do {
            let bytes = try TransformRecipeDocumentCodec.data(for: TransformRecipeInterchange(
                libraryName: item.libraryName, recipe: item.recipe
            ))
            export(bytes, .json, "\(item.libraryName).klt-transform")
        } catch { workspace.presentError(error.localizedDescription) }
    }

    private func hasConflict(_ value: IOSMethodImport) -> Bool {
        let name = WorkingSpaceValidator.normalizedName(value.name)
        if workspace.library.userWorkingSpaces.contains(where: { WorkingSpaceValidator.normalizedName($0.libraryName) == name }) { return true }
        if workspace.library.savedTransforms.contains(where: { WorkingSpaceValidator.normalizedName($0.libraryName) == name }) { return true }
        switch value {
        case let .space(space): return workspace.library.userWorkingSpaces.contains { $0.revision.identity == space.revision.identity }
        case let .recipe(recipe): return workspace.library.savedTransforms.contains { $0.recipe.identifier == recipe.recipe.identifier }
        }
    }

    private func canReplace(_ value: IOSMethodImport) -> Bool {
        switch value {
        case let .space(space):
            if workspace.library.savedTransforms.contains(where: {
                WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(space.libraryName)
            }) { return false }
            let matching = workspace.library.userWorkingSpaces.filter {
                $0.revision.identity == space.revision.identity || WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(space.libraryName)
            }
            return matching.count == 1 && space.revision.definitionVersion >= matching[0].revision.definitionVersion
        case let .recipe(recipe):
            if workspace.library.userWorkingSpaces.contains(where: {
                WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(recipe.libraryName)
            }) { return false }
            let matching = workspace.library.savedTransforms.filter {
                $0.recipe.identifier == recipe.recipe.identifier || WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(recipe.libraryName)
            }
            return matching.count == 1 && matching[0].recipe.identifier == recipe.recipe.identifier
                && matching[0].recipe == recipe.recipe
        }
    }

    private var conflictDescription: String {
        guard let incoming else { return "" }
        let name = WorkingSpaceValidator.normalizedName(incoming.name)
        let local = workspace.library.userWorkingSpaces.first { WorkingSpaceValidator.normalizedName($0.libraryName) == name }
            .map { "Working space · definition v\($0.revision.definitionVersion)" }
            ?? workspace.library.savedTransforms.first { WorkingSpaceValidator.normalizedName($0.libraryName) == name }
                .map { "Saved transform · recipe v\($0.recipe.recipeFormatVersion)" }
            ?? "a matching identity"
        return "Incoming: \(incoming.detail). Local: \(local). Choose an allowed action; current work will not change."
    }

    private func importValue(_ value: IOSMethodImport, choice: IOSImportChoice) async {
        do {
            let proposed = try IOSLibraryMutation.importValue(value, choice: choice, into: workspace.library)
            await workspace.replaceLibrary(proposed)
            incoming = nil
        } catch { workspace.presentError(error.localizedDescription) }
    }

    private func commitRename() async {
        do {
            let name = try IOSLibraryMutation.uniqueName(nameDraft, in: removingSelected())
            let spaces = workspace.library.userWorkingSpaces.map { item in
                guard item.id == renameSpace?.id else { return item }
                return UserWorkingSpaceItem(libraryName: name, purpose: item.purpose, revision: item.revision,
                                            createdAt: item.createdAt, modifiedAt: Date())
            }
            let recipes = workspace.library.savedTransforms.map { item in
                guard item.id == renameRecipe?.id else { return item }
                return SavedTransformItem(libraryName: name, recipe: item.recipe,
                                          createdAt: item.createdAt, modifiedAt: Date())
            }
            await workspace.replaceLibrary(MethodLibrarySnapshot(userWorkingSpaces: spaces, savedTransforms: recipes))
        } catch { workspace.presentError(error.localizedDescription) }
        renameSpace = nil; renameRecipe = nil
    }

    private func removingSelected() -> MethodLibrarySnapshot {
        MethodLibrarySnapshot(
            userWorkingSpaces: workspace.library.userWorkingSpaces.filter { $0.id != renameSpace?.id },
            savedTransforms: workspace.library.savedTransforms.filter { $0.id != renameRecipe?.id }
        )
    }

    private func deleteSelected() async {
        await workspace.replaceLibrary(MethodLibrarySnapshot(
            userWorkingSpaces: workspace.library.userWorkingSpaces.filter { $0.id != deleteSpace?.id },
            savedTransforms: workspace.library.savedTransforms.filter { $0.id != deleteRecipe?.id }
        ))
        deleteSpace = nil; deleteRecipe = nil
    }

    private func duplicateRecipe(_ item: SavedTransformItem) async {
        do {
            let proposed = try IOSLibraryMutation.importValue(
                .recipe(TransformRecipeInterchange(libraryName: item.libraryName, recipe: item.recipe)),
                choice: .copy, into: workspace.library
            )
            await workspace.replaceLibrary(proposed)
        } catch { workspace.presentError(error.localizedDescription) }
    }

    private func saveTransform() async {
        do {
            let name = try IOSLibraryMutation.uniqueName(nameDraft, in: workspace.library)
            let recipe = try workspace.captureRecipe()
            let item = SavedTransformItem(libraryName: name, recipe: recipe, createdAt: Date(), modifiedAt: Date())
            await workspace.replaceLibrary(MethodLibrarySnapshot(
                userWorkingSpaces: workspace.library.userWorkingSpaces,
                savedTransforms: workspace.library.savedTransforms + [item]
            ))
        } catch { workspace.presentError(error.localizedDescription) }
    }
}

private struct Inspection: Identifiable { let id = UUID(); let text: String }

struct SpaceEditorState: Identifiable {
    let id = UUID()
    let item: UserWorkingSpaceItem?
    var draft: WorkingSpaceEditorDraft

    init(item: UserWorkingSpaceItem?, descriptor: WorkingSpaceDescriptor?) {
        self.item = item
        if let item { draft = WorkingSpaceEditorDraft(item: item) }
        else if let descriptor {
            draft = WorkingSpaceEditorDraft(
                libraryName: descriptor.libraryName + " Copy", purpose: descriptor.purpose,
                base: descriptor.revision.base, channelNames: descriptor.revision.workingChannelNames,
                coefficients: descriptor.revision.forward.rowMajorValues.map { String($0) },
                offsets: [descriptor.revision.offset.x, descriptor.revision.offset.y, descriptor.revision.offset.z].map { String($0) }
            )
        } else { draft = WorkingSpaceEditorDraft() }
    }
}

private struct WorkingSpaceEditor: View {
    let state: SpaceEditorState
    let workspace: IOSWorkspace
    @Environment(\.dismiss) private var dismiss
    @State private var draft: WorkingSpaceEditorDraft

    init(state: SpaceEditorState, workspace: IOSWorkspace) {
        self.state = state; self.workspace = workspace
        _draft = State(initialValue: state.draft)
    }

    var body: some View {
        Form {
            Section("Definition") {
                TextField("Name", text: $draft.libraryName)
                TextField("Purpose", text: $draft.purpose)
                Picker("Base", selection: $draft.base) {
                    ForEach(WorkingSpaceBase.allCases, id: \.self) { Text($0.displayName).tag($0) }
                }
            }
            Section("Channels") {
                ForEach(0..<3, id: \.self) { index in
                    TextField("Channel \(index + 1)", text: $draft.channelNames[index])
                }
            }
            Section("Forward matrix · row major") {
                ForEach(0..<9, id: \.self) { index in
                    TextField("Coefficient \(index + 1)", text: $draft.coefficients[index])
                        .keyboardType(.numbersAndPunctuation)
                }
            }
            Section("Offset") {
                ForEach(0..<3, id: \.self) { index in
                    TextField("Offset \(index + 1)", text: $draft.offsets[index])
                        .keyboardType(.numbersAndPunctuation)
                }
            }
        }
        .navigationTitle(state.item == nil ? "Create working space" : "Edit working space")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) { Button("Save") { Task { await save() } } }
        }
    }

    private func save() async {
        do {
            let identity = state.item?.revision.identity
                ?? WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased())
            let version = (state.item?.revision.definitionVersion ?? 0) + 1
            let valid = try draft.validatedRevision(identity: identity, definitionVersion: version)
            let others = workspace.library.userWorkingSpaces.filter { $0.id != state.item?.id }
            let name = try IOSLibraryMutation.uniqueName(draft.libraryName,
                in: MethodLibrarySnapshot(userWorkingSpaces: others, savedTransforms: workspace.library.savedTransforms))
            let item = UserWorkingSpaceItem(
                libraryName: name, purpose: draft.purpose.isEmpty ? nil : draft.purpose,
                revision: valid.revision, createdAt: state.item?.createdAt ?? Date(), modifiedAt: Date()
            )
            let saved = await workspace.replaceLibrary(MethodLibrarySnapshot(
                userWorkingSpaces: others + [item], savedTransforms: workspace.library.savedTransforms
            ))
            if saved { dismiss() }
        } catch { workspace.presentError(error.localizedDescription) }
    }
}
