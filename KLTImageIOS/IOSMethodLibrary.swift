import Foundation
import KLTCore

/// The iOS container owns its own v1 store. A failed load never rewrites the file.
actor IOSMethodLibrary {
    private let url: URL
    private var current: MethodLibrarySnapshot = .empty
    private var loaded = false
    private var readOnly = false

    init(url: URL? = nil) {
        if let url { self.url = url }
        else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.url = support.appendingPathComponent("MethodLibrary/library.json")
        }
    }

    func load() throws -> MethodLibrarySnapshot {
        if loaded { return current }
        guard FileManager.default.fileExists(atPath: url.path) else {
            loaded = true
            return current
        }
        do {
            let data = try MethodFileIO.readRegularFile(
                at: url, maximumByteCount: MethodLibraryDocumentCodec.maximumByteCount
            )
            current = try MethodLibraryDocumentCodec.decode(data)
            loaded = true
            return current
        } catch {
            readOnly = true
            throw error
        }
    }

    func replace(_ proposed: MethodLibrarySnapshot) throws -> MethodLibrarySnapshot {
        if !loaded {
            do { _ = try load() }
            catch { throw IOSLibraryError.recoveryRequired }
        }
        guard !readOnly else { throw IOSLibraryError.recoveryRequired }
        try MethodLibraryDocumentCodec.validate(proposed)
        let data = try MethodLibraryDocumentCodec.data(for: proposed)
        try MethodFileIO.durableAtomicWrite(data, to: url)
        current = proposed
        loaded = true
        return proposed
    }
}

enum IOSLibraryError: LocalizedError {
    case recoveryRequired
    case nameConflict
    case incompatibleReplacement
    case unsupportedMethod
    case analysisRecord
    case corruptDocument

    var errorDescription: String? {
        switch self {
        case .recoveryRequired: "The saved method library cannot be read. Its file was left untouched. Standard and curated spaces remain available; recover the library before making changes."
        case .nameConflict: "A method with that name already exists. Choose a different name."
        case .incompatibleReplacement: "Replace is available only for the same method type and a compatible version."
        case .unsupportedMethod: "This is not a supported working space or saved transform. Nothing was imported."
        case .analysisRecord: "This is an analysis record, not an executable method. Nothing was imported."
        case .corruptDocument: "The method document is corrupt or has unsupported fields or values. Nothing was imported."
        }
    }
}

enum IOSMethodImport: Sendable {
    case space(WorkingSpaceInterchange)
    case recipe(TransformRecipeInterchange)

    var name: String {
        switch self {
        case let .space(value): value.libraryName
        case let .recipe(value): value.libraryName
        }
    }

    var detail: String {
        switch self {
        case let .space(value): "Working space · definition v\(value.revision.definitionVersion)"
        case let .recipe(value): "Saved transform · recipe v\(value.recipe.recipeFormatVersion)"
        }
    }

    static func decode(_ data: Data) throws -> IOSMethodImport {
        // Each codec performs the same strict size, duplicate-key and schema checks as macOS.
        guard data.count <= 262_144 else {
            throw MethodDocumentError.oversized
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let schema = object["schema"] as? String else {
            throw IOSLibraryError.corruptDocument
        }
        switch schema {
        case WorkingSpaceDocumentCodec.schemaIdentifier:
            return .space(try WorkingSpaceDocumentCodec.decode(data))
        case TransformRecipeDocumentCodec.schemaIdentifier:
            return .recipe(try TransformRecipeDocumentCodec.decode(data))
        case AnalysisRecordJSONEncoder.schemaIdentifier:
            throw IOSLibraryError.analysisRecord
        default: throw IOSLibraryError.unsupportedMethod
        }
    }
}

enum IOSImportChoice { case add, replace, copy }

enum IOSLibraryMutation {
    static func uniqueName(_ requested: String, in snapshot: MethodLibrarySnapshot) throws -> String {
        let name = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = Set((snapshot.userWorkingSpaces.map(\.libraryName) + snapshot.savedTransforms.map(\.libraryName))
            .map(WorkingSpaceValidator.normalizedName))
        guard !existing.contains(WorkingSpaceValidator.normalizedName(name)) else { throw IOSLibraryError.nameConflict }
        return name
    }

    static func importValue(
        _ incoming: IOSMethodImport, choice: IOSImportChoice, into snapshot: MethodLibrarySnapshot
    ) throws -> MethodLibrarySnapshot {
        var spaces = snapshot.userWorkingSpaces
        var recipes = snapshot.savedTransforms
        let now = Date()
        switch incoming {
        case let .space(value):
            let matches = spaces.filter {
                $0.revision.identity == value.revision.identity ||
                WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(value.libraryName)
            }
            var revision = value.revision
            var name = value.libraryName
            switch choice {
            case .add:
                guard matches.isEmpty else { throw IOSLibraryError.nameConflict }
                name = try uniqueName(name, in: snapshot)
            case .replace:
                guard matches.count == 1,
                      value.revision.definitionVersion >= matches[0].revision.definitionVersion else {
                    throw IOSLibraryError.incompatibleReplacement
                }
                spaces.removeAll { item in matches.contains { $0.id == item.id } }
            case .copy:
                let identity = WorkingSpaceIdentity(kind: .user, identifier: UUID().uuidString.lowercased())
                revision = WorkingSpaceRevision(
                    identity: identity, definitionVersion: revision.definitionVersion,
                    base: revision.base, baseChannelOrder: revision.baseChannelOrder,
                    baseChannelUnits: revision.baseChannelUnits,
                    workingChannelNames: revision.workingChannelNames, forward: revision.forward,
                    offset: revision.offset, inverse: revision.inverse,
                    outputBehavior: revision.outputBehavior
                )
                name = availableCopyName(name, snapshot: snapshot)
            }
            spaces.append(UserWorkingSpaceItem(
                libraryName: name, purpose: value.purpose, revision: revision,
                createdAt: now, modifiedAt: now
            ))
        case let .recipe(value):
            let matches = recipes.filter {
                $0.recipe.identifier == value.recipe.identifier ||
                WorkingSpaceValidator.normalizedName($0.libraryName) == WorkingSpaceValidator.normalizedName(value.libraryName)
            }
            var recipe = value.recipe
            var name = value.libraryName
            switch choice {
            case .add:
                guard matches.isEmpty else { throw IOSLibraryError.nameConflict }
                name = try uniqueName(name, in: snapshot)
            case .replace:
                guard matches.count == 1,
                      matches[0].recipe.identifier == recipe.identifier,
                      matches[0].recipe == recipe else {
                    throw IOSLibraryError.incompatibleReplacement
                }
                recipes.removeAll { item in matches.contains { $0.id == item.id } }
            case .copy:
                recipe = TransformRecipeSnapshot(
                    identifier: UUID(), recipeFormatVersion: recipe.recipeFormatVersion,
                    algorithm: recipe.algorithm, workingSpace: recipe.workingSpace,
                    workingSpaceNameAtCapture: recipe.workingSpaceNameAtCapture,
                    originatingAnalysis: recipe.originatingAnalysis,
                    originSource: recipe.originSource, workingCenter: recipe.workingCenter,
                    transform: recipe.transform, outputMapping: recipe.outputMapping,
                    exploratoryUseNotice: recipe.exploratoryUseNotice
                )
                name = availableCopyName(name, snapshot: snapshot)
            }
            recipes.append(SavedTransformItem(libraryName: name, recipe: recipe, createdAt: now, modifiedAt: now))
        }
        let proposed = MethodLibrarySnapshot(userWorkingSpaces: spaces, savedTransforms: recipes)
        try MethodLibraryDocumentCodec.validate(proposed)
        return proposed
    }

    private static func availableCopyName(_ name: String, snapshot: MethodLibrarySnapshot) -> String {
        for number in 1...999 {
            let candidate = number == 1 ? "\(name) Copy" : "\(name) Copy \(number)"
            if (try? uniqueName(candidate, in: snapshot)) != nil { return candidate }
        }
        return "\(name) \(UUID().uuidString.prefix(6))"
    }
}
