import AppKit
import Foundation
import KLTCore
import Observation
import UniformTypeIdentifiers

enum PendingMethodImport: Equatable, Identifiable {
    case workingSpace(WorkingSpaceInterchange)
    case savedTransform(TransformRecipeInterchange)

    var id: String {
        switch self {
        case let .workingSpace(value): "space-\(value.revision.identity.identifier)"
        case let .savedTransform(value): "recipe-\(value.recipe.identifier.uuidString)"
        }
    }
}

enum ImportCommitChoice { case add, replace, copy }

enum MethodImportArtifactKind: String, Equatable {
    case workingSpace = "Working Space"
    case savedTransform = "Saved Transform"
}

struct MethodImportSummary: Equatable {
    let kind: MethodImportArtifactKind
    let name: String
    let identity: String
    let version: String
    let detail: String
}

enum MethodImportPreflight: Equatable {
    case add
    case replace(local: MethodImportSummary)
    case copyOnly(local: MethodImportSummary, reason: String)
    case rejected(local: MethodImportSummary?, error: MethodLibraryOperationError)

    var allowsAdd: Bool { self == .add }
    var allowsReplace: Bool {
        if case .replace = self { return true }
        return false
    }
    var allowsCopy: Bool {
        switch self {
        case .replace, .copyOnly: true
        case .add, .rejected: false
        }
    }
    var local: MethodImportSummary? {
        switch self {
        case .add: nil
        case let .replace(local), let .copyOnly(local, _): local
        case let .rejected(local, _): local
        }
    }
}

enum MethodLibraryOperationError: Error, Equatable, LocalizedError {
    case stillLoading
    case recoveryRequired
    case operationInProgress
    case staleWorkingSpaceRevision
    case inconsistentWorkingSpaceRevision
    case inconsistentRecipeIdentity
    case unavailableImportChoice

    var errorDescription: String? {
        switch self {
        case .stillLoading:
            "The method library is still loading. Try again in a moment."
        case .recoveryRequired:
            "The existing method library needs recovery before it can be changed. No stored methods were overwritten."
        case .operationInProgress:
            "Another method-library change is still being saved. Try again when it finishes."
        case .staleWorkingSpaceRevision:
            "This import has an older definition version for the same working space. Import it as a copy instead."
        case .inconsistentWorkingSpaceRevision:
            "The same working-space identity and version contain different mathematics. Correct the definition version or identity before importing."
        case .inconsistentRecipeIdentity:
            "The same saved-transform identity contains different frozen values. Correct the recipe identity before importing."
        case .unavailableImportChoice:
            "The selected import action is no longer valid because the local library changed. Review the import again."
        }
    }
}

@MainActor
@Observable
final class MethodLibraryModel {
    private(set) var snapshot: MethodLibrarySnapshot = .empty
    private(set) var isLoading = true
    private(set) var loadError: String?
    private(set) var operationError: String?
    private(set) var successNotice: String?
    private(set) var isMutating = false
    var pendingImport: PendingMethodImport?

    private let store: MethodLibraryStore

    init(store: MethodLibraryStore = MethodLibraryStore()) {
        self.store = store
        Task { await load() }
    }

    var standardSpaces: [WorkingSpaceDescriptor] {
        [WorkingSpaceCatalog.standardRGB, WorkingSpaceCatalog.standardLabD65]
    }

    var curatedSpaces: [WorkingSpaceDescriptor] { WorkingSpaceCatalog.curated }

    func item(for revision: WorkingSpaceRevision) -> UserWorkingSpaceItem? {
        snapshot.userWorkingSpaces.first { $0.revision.identity == revision.identity }
    }

    func displayName(for revision: WorkingSpaceRevision) -> String {
        item(for: revision)?.libraryName
            ?? WorkingSpaceCatalog.descriptor(for: revision)?.libraryName
            ?? revision.identity.identifier
    }

    func reportOperationError(_ error: Error, fallback: String = "The method-library change was not saved. Current work is unchanged.") {
        operationError = (error as? LocalizedError)?.errorDescription ?? fallback
        successNotice = nil
    }

    func saveNewSpace(_ draft: WorkingSpaceEditorDraft) async throws -> UserWorkingSpaceItem {
        let identity = WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased())
        let validated = try draft.validatedRevision(identity: identity, definitionVersion: 1)
        let now = Date()
        let item = UserWorkingSpaceItem(
            libraryName: draft.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            revision: validated.revision,
            createdAt: now,
            modifiedAt: now
        )
        try await replace(spaces: snapshot.userWorkingSpaces + [item], recipes: snapshot.savedTransforms)
        successNotice = "Saved working space \(item.libraryName)."
        return item
    }

    func updateSpace(_ existing: UserWorkingSpaceItem, draft: WorkingSpaceEditorDraft) async throws -> UserWorkingSpaceItem {
        let validated = try draft.validatedRevision(
            identity: existing.revision.identity,
            definitionVersion: existing.revision.definitionVersion + 1
        )
        let updated = UserWorkingSpaceItem(
            libraryName: draft.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: draft.purpose.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty,
            revision: validated.revision,
            createdAt: existing.createdAt,
            modifiedAt: Date()
        )
        let spaces = snapshot.userWorkingSpaces.map {
            $0.revision.identity == existing.revision.identity ? updated : $0
        }
        try await replace(spaces: spaces, recipes: snapshot.savedTransforms)
        successNotice = "Saved definition version \(updated.revision.definitionVersion)."
        return updated
    }

    func duplicateSpace(_ descriptor: WorkingSpaceDescriptor) async throws -> UserWorkingSpaceItem {
        var draft = WorkingSpaceEditorDraft(
            libraryName: descriptor.libraryName + " Copy",
            purpose: descriptor.purpose,
            base: descriptor.revision.base,
            channelNames: descriptor.revision.workingChannelNames,
            coefficients: descriptor.revision.forward.rowMajorValues.map { String($0) },
            offsets: [descriptor.revision.offset.x, descriptor.revision.offset.y, descriptor.revision.offset.z].map { String($0) }
        )
        draft.libraryName = uniqueSpaceName(draft.libraryName)
        return try await saveNewSpace(draft)
    }

    func duplicateSpace(_ item: UserWorkingSpaceItem) async throws -> UserWorkingSpaceItem {
        var draft = WorkingSpaceEditorDraft(item: item)
        draft.libraryName = uniqueSpaceName(item.libraryName + " Copy")
        return try await saveNewSpace(draft)
    }

    func renameSpace(_ item: UserWorkingSpaceItem, to name: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try WorkingSpaceValidator.validate(item.revision, libraryName: trimmed, purpose: item.purpose)
        let updated = UserWorkingSpaceItem(
            libraryName: trimmed,
            purpose: item.purpose,
            revision: item.revision,
            createdAt: item.createdAt,
            modifiedAt: Date()
        )
        try await replace(
            spaces: snapshot.userWorkingSpaces.map { $0.revision.identity == item.revision.identity ? updated : $0 },
            recipes: snapshot.savedTransforms
        )
    }

    func deleteSpace(_ item: UserWorkingSpaceItem) async throws {
        try await replace(
            spaces: snapshot.userWorkingSpaces.filter { $0.revision.identity != item.revision.identity },
            recipes: snapshot.savedTransforms
        )
        successNotice = "Deleted \(item.libraryName). Saved transforms remain independent."
    }

    func saveRecipe(_ recipe: TransformRecipeSnapshot, name: String) async throws -> SavedTransformItem {
        let now = Date()
        let item = SavedTransformItem(
            libraryName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            recipe: recipe,
            createdAt: now,
            modifiedAt: now
        )
        try TransformRecipeValidator.validate(recipe, libraryName: item.libraryName)
        try await replace(spaces: snapshot.userWorkingSpaces, recipes: snapshot.savedTransforms + [item])
        successNotice = "Saved transform \(item.libraryName)."
        return item
    }

    func renameRecipe(_ item: SavedTransformItem, to name: String) async throws {
        let updated = SavedTransformItem(
            libraryName: name.trimmingCharacters(in: .whitespacesAndNewlines),
            recipe: item.recipe,
            createdAt: item.createdAt,
            modifiedAt: Date()
        )
        try TransformRecipeValidator.validate(updated.recipe, libraryName: updated.libraryName)
        try await replace(
            spaces: snapshot.userWorkingSpaces,
            recipes: snapshot.savedTransforms.map { $0.id == item.id ? updated : $0 }
        )
    }

    func duplicateRecipe(_ item: SavedTransformItem) async throws -> SavedTransformItem {
        let copy = TransformRecipeSnapshot(
            identifier: UUID(),
            recipeFormatVersion: item.recipe.recipeFormatVersion,
            algorithm: item.recipe.algorithm,
            workingSpace: item.recipe.workingSpace,
            workingSpaceNameAtCapture: item.recipe.workingSpaceNameAtCapture,
            originatingAnalysis: item.recipe.originatingAnalysis,
            originSource: item.recipe.originSource,
            workingCenter: item.recipe.workingCenter,
            transform: item.recipe.transform,
            outputMapping: item.recipe.outputMapping,
            exploratoryUseNotice: item.recipe.exploratoryUseNotice
        )
        return try await saveRecipe(copy, name: uniqueRecipeName(item.libraryName + " Copy"))
    }

    func deleteRecipe(_ item: SavedTransformItem) async throws {
        try await replace(
            spaces: snapshot.userWorkingSpaces,
            recipes: snapshot.savedTransforms.filter { $0.id != item.id }
        )
        successNotice = "Deleted \(item.libraryName). The displayed result is unchanged."
    }

    func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.title = "Import a KLT Image method"
        panel.prompt = "Validate"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try MethodFileIO.readRegularFile(at: url, maximumByteCount: 262_144)
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidate: PendingMethodImport
            switch root?["schema"] as? String {
            case WorkingSpaceDocumentCodec.schemaIdentifier:
                candidate = .workingSpace(try WorkingSpaceDocumentCodec.decode(data))
            case TransformRecipeDocumentCodec.schemaIdentifier:
                candidate = .savedTransform(try TransformRecipeDocumentCodec.decode(data))
            case AnalysisRecordJSONEncoder.schemaIdentifier:
                throw ImportUIError.analysisRecord
            default:
                throw MethodDocumentError.wrongSchema
            }
            try stageImport(candidate)
            operationError = nil
            successNotice = nil
        } catch {
            reportOperationError(error, fallback: "Nothing was imported, replaced, or applied.")
            pendingImport = nil
        }
    }

    func commitPendingImport(_ choice: ImportCommitChoice) async {
        guard let pendingImport else { return }
        do {
            let preflight = preflight(for: pendingImport)
            try authorize(choice, for: preflight)
            switch pendingImport {
            case let .workingSpace(value): try await commit(value, choice: choice)
            case let .savedTransform(value): try await commit(value, choice: choice)
            }
            self.pendingImport = nil
        } catch {
            reportOperationError(error, fallback: "Nothing was imported, replaced, or applied.")
        }
    }

    func stageImport(_ pending: PendingMethodImport) throws {
        if case let .rejected(_, error) = preflight(for: pending) { throw error }
        pendingImport = pending
    }

    func incomingSummary(for pending: PendingMethodImport) -> MethodImportSummary {
        switch pending {
        case let .workingSpace(value):
            MethodImportSummary(
                kind: .workingSpace,
                name: value.libraryName,
                identity: value.revision.identity.identifier,
                version: "Definition v\(value.revision.definitionVersion)",
                detail: "\(value.revision.base.displayName) · working = A × base + b"
            )
        case let .savedTransform(value):
            MethodImportSummary(
                kind: .savedTransform,
                name: value.libraryName,
                identity: value.recipe.identifier.uuidString.lowercased(),
                version: "Recipe v\(value.recipe.recipeFormatVersion)",
                detail: "Origin \(value.recipe.originSource.displayFilename) · frozen application"
            )
        }
    }

    func preflight(for pending: PendingMethodImport) -> MethodImportPreflight {
        let normalized = WorkingSpaceValidator.normalizedName(incomingSummary(for: pending).name)
        switch pending {
        case let .workingSpace(value):
            let identityMatch = snapshot.userWorkingSpaces.first {
                $0.revision.identity == value.revision.identity
            }
            if let identityMatch,
               identityMatch.revision.definitionVersion == value.revision.definitionVersion,
               identityMatch.revision != value.revision {
                return .rejected(
                    local: summary(identityMatch),
                    error: .inconsistentWorkingSpaceRevision
                )
            }
            let crossType = snapshot.savedTransforms.first {
                WorkingSpaceValidator.normalizedName($0.libraryName) == normalized
            }
            if let crossType {
                return .copyOnly(
                    local: summary(crossType),
                    reason: "That normalized name belongs to a saved transform. Cross-type replacement is never allowed."
                )
            }
            if let identityMatch,
               value.revision.definitionVersion < identityMatch.revision.definitionVersion {
                return .copyOnly(
                    local: summary(identityMatch),
                    reason: MethodLibraryOperationError.staleWorkingSpaceRevision.localizedDescription
                )
            }
            let sameType = snapshot.userWorkingSpaces.filter {
                $0.revision.identity == value.revision.identity
                    || WorkingSpaceValidator.normalizedName($0.libraryName) == normalized
            }
            if sameType.count == 1, let local = sameType.first {
                return .replace(local: summary(local))
            }
            if let local = sameType.first {
                return .copyOnly(
                    local: summary(local),
                    reason: "More than one local working space conflicts. Importing as a copy preserves every local item."
                )
            }
            return .add

        case let .savedTransform(value):
            let identityMatch = snapshot.savedTransforms.first {
                $0.recipe.identifier == value.recipe.identifier
            }
            if let identityMatch, identityMatch.recipe != value.recipe {
                return .rejected(local: summary(identityMatch), error: .inconsistentRecipeIdentity)
            }
            let crossType = snapshot.userWorkingSpaces.first {
                WorkingSpaceValidator.normalizedName($0.libraryName) == normalized
            }
            if let crossType {
                return .copyOnly(
                    local: summary(crossType),
                    reason: "That normalized name belongs to a working space. Cross-type replacement is never allowed."
                )
            }
            let sameType = snapshot.savedTransforms.filter {
                $0.recipe.identifier == value.recipe.identifier
                    || WorkingSpaceValidator.normalizedName($0.libraryName) == normalized
            }
            if sameType.count == 1, let local = sameType.first {
                return .replace(local: summary(local))
            }
            if let local = sameType.first {
                return .copyOnly(
                    local: summary(local),
                    reason: "More than one local saved transform conflicts. Importing as a copy preserves every local item."
                )
            }
            return .add
        }
    }

    func export(_ item: UserWorkingSpaceItem) {
        presentExportPanel(
            title: "Export working-space definition",
            suggestedName: "\(safeStem(item.libraryName)).klt-space.json"
        ) { url in
            let data = try WorkingSpaceDocumentCodec.data(for: WorkingSpaceInterchange(
                libraryName: item.libraryName,
                purpose: item.purpose,
                revision: item.revision
            ))
            try MethodFileIO.durableAtomicWrite(data, to: url)
        }
    }

    func export(_ item: SavedTransformItem) {
        presentExportPanel(
            title: "Export saved transform",
            suggestedName: "\(safeStem(item.libraryName)).klt-transform.json"
        ) { url in
            let data = try TransformRecipeDocumentCodec.data(for: TransformRecipeInterchange(
                libraryName: item.libraryName,
                recipe: item.recipe
            ))
            try MethodFileIO.durableAtomicWrite(data, to: url)
        }
    }

    private func load() async {
        do {
            snapshot = try await store.load()
            loadError = nil
        } catch {
            snapshot = .empty
            loadError = "The local method library could not be loaded. Standard and curated working spaces remain available; the file was not overwritten."
        }
        isLoading = false
    }

    private func replace(spaces: [UserWorkingSpaceItem], recipes: [SavedTransformItem]) async throws {
        guard !isLoading else { throw MethodLibraryOperationError.stillLoading }
        guard loadError == nil else { throw MethodLibraryOperationError.recoveryRequired }
        guard !isMutating else { throw MethodLibraryOperationError.operationInProgress }
        isMutating = true
        defer { isMutating = false }
        let proposed = MethodLibrarySnapshot(userWorkingSpaces: spaces, savedTransforms: recipes)
        do {
            snapshot = try await store.replace(with: proposed)
            operationError = nil
        } catch {
            reportOperationError(error)
            throw error
        }
    }

    private func commit(_ value: WorkingSpaceInterchange, choice: ImportCommitChoice) async throws {
        var revision = value.revision
        var name = value.libraryName
        var spaces = snapshot.userWorkingSpaces
        if choice == .copy {
            let validated = try WorkingSpaceValidator.makeRevision(
                identity: WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased()),
                definitionVersion: 1,
                base: revision.base,
                workingChannelNames: revision.workingChannelNames,
                forwardValues: revision.forward.rowMajorValues,
                offsetValues: [revision.offset.x, revision.offset.y, revision.offset.z]
            )
            revision = validated.revision
            name = uniqueSpaceName(name + " Copy")
        } else if choice == .replace {
            if let local = spaces.first(where: { $0.revision.identity == revision.identity }) {
                guard revision.definitionVersion >= local.revision.definitionVersion else {
                    throw MethodLibraryOperationError.staleWorkingSpaceRevision
                }
                guard revision.definitionVersion != local.revision.definitionVersion
                        || revision == local.revision else {
                    throw MethodLibraryOperationError.inconsistentWorkingSpaceRevision
                }
            }
            spaces.removeAll {
                $0.revision.identity == revision.identity
                    || WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(name)
            }
        }
        let now = Date()
        spaces.append(UserWorkingSpaceItem(
            libraryName: name,
            purpose: value.purpose,
            revision: revision,
            createdAt: now,
            modifiedAt: now
        ))
        try await replace(spaces: spaces, recipes: snapshot.savedTransforms)
        successNotice = "Imported working space \(name). Current work is unchanged."
    }

    private func commit(_ value: TransformRecipeInterchange, choice: ImportCommitChoice) async throws {
        var recipe = value.recipe
        var name = value.libraryName
        var recipes = snapshot.savedTransforms
        if choice == .copy {
            recipe = TransformRecipeSnapshot(
                identifier: UUID(), recipeFormatVersion: recipe.recipeFormatVersion,
                algorithm: recipe.algorithm, workingSpace: recipe.workingSpace,
                workingSpaceNameAtCapture: recipe.workingSpaceNameAtCapture,
                originatingAnalysis: recipe.originatingAnalysis, originSource: recipe.originSource,
                workingCenter: recipe.workingCenter, transform: recipe.transform,
                outputMapping: recipe.outputMapping, exploratoryUseNotice: recipe.exploratoryUseNotice
            )
            name = uniqueRecipeName(name + " Copy")
        } else if choice == .replace {
            if let local = recipes.first(where: { $0.recipe.identifier == recipe.identifier }),
               local.recipe != recipe {
                throw MethodLibraryOperationError.inconsistentRecipeIdentity
            }
            recipes.removeAll {
                $0.recipe.identifier == recipe.identifier
                    || WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(name)
            }
        }
        let now = Date()
        recipes.append(SavedTransformItem(libraryName: name, recipe: recipe, createdAt: now, modifiedAt: now))
        try await replace(spaces: snapshot.userWorkingSpaces, recipes: recipes)
        successNotice = "Imported saved transform \(name). Current work is unchanged."
    }

    private func uniqueSpaceName(_ base: String) -> String {
        uniqueName(base, existing: allLibraryNames)
    }

    private func uniqueRecipeName(_ base: String) -> String {
        uniqueName(base, existing: allLibraryNames)
    }

    private var allLibraryNames: [String] {
        snapshot.userWorkingSpaces.map(\.libraryName) + snapshot.savedTransforms.map(\.libraryName)
    }

    private func authorize(_ choice: ImportCommitChoice, for preflight: MethodImportPreflight) throws {
        if case let .rejected(_, error) = preflight { throw error }
        let allowed: Bool
        switch choice {
        case .add: allowed = preflight.allowsAdd
        case .replace: allowed = preflight.allowsReplace
        case .copy: allowed = preflight.allowsCopy
        }
        guard allowed else { throw MethodLibraryOperationError.unavailableImportChoice }
    }

    private func summary(_ item: UserWorkingSpaceItem) -> MethodImportSummary {
        MethodImportSummary(
            kind: .workingSpace,
            name: item.libraryName,
            identity: item.revision.identity.identifier,
            version: "Definition v\(item.revision.definitionVersion)",
            detail: "\(item.revision.base.displayName) · working = A × base + b"
        )
    }

    private func summary(_ item: SavedTransformItem) -> MethodImportSummary {
        MethodImportSummary(
            kind: .savedTransform,
            name: item.libraryName,
            identity: item.recipe.identifier.uuidString.lowercased(),
            version: "Recipe v\(item.recipe.recipeFormatVersion)",
            detail: "Origin \(item.recipe.originSource.displayFilename) · frozen application"
        )
    }

    private func uniqueName(_ base: String, existing: [String]) -> String {
        let names = Set(existing.map(WorkingSpaceValidator.normalizedName))
        if !names.contains(WorkingSpaceValidator.normalizedName(base)) { return base }
        for index in 2...999 {
            let candidate = "\(base) \(index)"
            if !names.contains(WorkingSpaceValidator.normalizedName(candidate)) { return candidate }
        }
        return "\(base) \(UUID().uuidString.prefix(6))"
    }

    private func presentExportPanel(title: String, suggestedName: String, write: (URL) throws -> Void) {
        let panel = NSSavePanel()
        panel.title = title
        panel.prompt = "Export"
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            try write(url)
            successNotice = "Exported \(url.lastPathComponent)."
        } catch {
            operationError = "The method could not be saved at that location. The library and current work are unchanged."
        }
    }

    private func safeStem(_ value: String) -> String {
        value.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}

private enum ImportUIError: LocalizedError {
    case analysisRecord
    var errorDescription: String? { "This is an analysis record, not an executable method file. Nothing was imported, replaced, or applied." }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
