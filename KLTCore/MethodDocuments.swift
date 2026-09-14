import Foundation

public enum MethodDocumentError: Error, Equatable, LocalizedError, Sendable {
    case oversized
    case invalidUTF8
    case malformedJSON
    case duplicateKey(String)
    case excessiveDepth
    case unknownOrMissingField
    case wrongSchema
    case unsupportedVersion
    case invalidArtifact
    case invalidValueCount(field: String, expected: Int, actual: Int)
    case inconsistentLibrary

    public var errorDescription: String? {
        switch self {
        case .oversized: "The method file exceeds the 256 KiB import limit."
        case .invalidUTF8: "The method file must be UTF-8 JSON without a byte-order mark."
        case .malformedJSON: "The method file is not one complete valid JSON document."
        case let .duplicateKey(key): "The method file contains the duplicate field “\(key)”."
        case .excessiveDepth: "The method file exceeds the supported nesting depth."
        case .unknownOrMissingField: "The method file has an unknown or missing field."
        case .wrongSchema: "This file is not the selected KLT Image method artifact type."
        case .unsupportedVersion: "This method file version is not supported."
        case .invalidArtifact: "The method file contains an invalid or inconsistent definition."
        case let .invalidValueCount(field, expected, actual):
            "The method file field “\(field)” must contain exactly \(expected) values; it contains \(actual)."
        case .inconsistentLibrary: "The method library contains conflicting or invalid items."
        }
    }
}

public struct WorkingSpaceInterchange: Equatable, Sendable {
    public let libraryName: String
    public let purpose: String?
    public let revision: WorkingSpaceRevision

    public init(libraryName: String, purpose: String?, revision: WorkingSpaceRevision) {
        self.libraryName = libraryName
        self.purpose = purpose
        self.revision = revision
    }
}

public struct TransformRecipeInterchange: Equatable, Sendable {
    public let libraryName: String
    public let recipe: TransformRecipeSnapshot

    public init(libraryName: String, recipe: TransformRecipeSnapshot) {
        self.libraryName = libraryName
        self.recipe = recipe
    }
}

public struct MethodLibrarySnapshot: Equatable, Sendable {
    public let userWorkingSpaces: [UserWorkingSpaceItem]
    public let savedTransforms: [SavedTransformItem]

    public init(
        userWorkingSpaces: [UserWorkingSpaceItem] = [],
        savedTransforms: [SavedTransformItem] = []
    ) {
        self.userWorkingSpaces = userWorkingSpaces
        self.savedTransforms = savedTransforms
    }

    public static let empty = MethodLibrarySnapshot()
}

public enum WorkingSpaceDocumentCodec {
    public static let schemaIdentifier = "org.kltimage.working-space"
    public static let schemaVersion = 1

    public static func data(for artifact: WorkingSpaceInterchange) throws -> Data {
        guard artifact.revision.identity.kind == .user else { throw MethodDocumentError.invalidArtifact }
        _ = try WorkingSpaceValidator.validate(
            artifact.revision,
            libraryName: artifact.libraryName,
            purpose: artifact.purpose
        )
        return try CanonicalMethodJSON.encode(
            WorkingSpaceDocumentV1(
                schema: schemaIdentifier,
                version: schemaVersion,
                libraryName: artifact.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
                purpose: artifact.purpose,
                definition: WorkingSpaceDefinitionV1(artifact.revision)
            )
        )
    }

    public static func decode(_ data: Data) throws -> WorkingSpaceInterchange {
        try StrictMethodJSON.prepare(data, limit: 262_144)
        let object = try StrictMethodJSON.object(data)
        try StrictMethodJSON.validateWorkingSpace(object)
        let dto = try CanonicalMethodJSON.decode(WorkingSpaceDocumentV1.self, from: data)
        guard dto.schema == schemaIdentifier else { throw MethodDocumentError.wrongSchema }
        guard dto.version == schemaVersion else { throw MethodDocumentError.unsupportedVersion }
        let revision = try dto.definition.value()
        guard revision.identity.kind == .user else { throw MethodDocumentError.invalidArtifact }
        _ = try WorkingSpaceValidator.validate(
            revision,
            libraryName: dto.libraryName,
            purpose: dto.purpose
        )
        return WorkingSpaceInterchange(
            libraryName: dto.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
            purpose: dto.purpose,
            revision: revision
        )
    }
}

public enum TransformRecipeDocumentCodec {
    public static let schemaIdentifier = "org.kltimage.transform-recipe"
    public static let schemaVersion = 1

    public static func data(for artifact: TransformRecipeInterchange) throws -> Data {
        try TransformRecipeValidator.validate(artifact.recipe, libraryName: artifact.libraryName)
        return try CanonicalMethodJSON.encode(
            TransformRecipeDocumentV1(
                schema: schemaIdentifier,
                version: schemaVersion,
                libraryName: artifact.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
                recipe: TransformRecipeV1(artifact.recipe)
            )
        )
    }

    public static func decode(_ data: Data) throws -> TransformRecipeInterchange {
        try StrictMethodJSON.prepare(data, limit: 262_144)
        let object = try StrictMethodJSON.object(data)
        try StrictMethodJSON.validateRecipe(object)
        let dto = try CanonicalMethodJSON.decode(TransformRecipeDocumentV1.self, from: data)
        guard dto.schema == schemaIdentifier else { throw MethodDocumentError.wrongSchema }
        guard dto.version == schemaVersion else { throw MethodDocumentError.unsupportedVersion }
        let recipe = try dto.recipe.value()
        try TransformRecipeValidator.validate(recipe, libraryName: dto.libraryName)
        return TransformRecipeInterchange(
            libraryName: dto.libraryName.trimmingCharacters(in: .whitespacesAndNewlines),
            recipe: recipe
        )
    }
}

public enum MethodLibraryDocumentCodec {
    public static let schemaIdentifier = "org.kltimage.method-library"
    public static let schemaVersion = 1
    public static let maximumByteCount = 16 * 1_024 * 1_024

    public static func data(for snapshot: MethodLibrarySnapshot) throws -> Data {
        try validate(snapshot)
        let spaces = snapshot.userWorkingSpaces.sorted {
            $0.revision.identity.identifier < $1.revision.identity.identifier
        }.map(UserWorkingSpaceV1.init)
        let recipes = snapshot.savedTransforms.sorted {
            $0.recipe.identifier.uuidString < $1.recipe.identifier.uuidString
        }.map(SavedTransformV1.init)
        return try CanonicalMethodJSON.encode(MethodLibraryDocumentV1(
            schema: schemaIdentifier,
            version: schemaVersion,
            userWorkingSpaces: spaces,
            savedTransforms: recipes
        ))
    }

    public static func decode(_ data: Data) throws -> MethodLibrarySnapshot {
        try StrictMethodJSON.prepare(data, limit: maximumByteCount)
        let object = try StrictMethodJSON.object(data)
        try StrictMethodJSON.validateLibrary(object)
        let dto = try CanonicalMethodJSON.decode(MethodLibraryDocumentV1.self, from: data)
        guard dto.schema == schemaIdentifier else { throw MethodDocumentError.wrongSchema }
        guard dto.version == schemaVersion else { throw MethodDocumentError.unsupportedVersion }
        let snapshot = MethodLibrarySnapshot(
            userWorkingSpaces: try dto.userWorkingSpaces.map { try $0.value() },
            savedTransforms: try dto.savedTransforms.map { try $0.value() }
        )
        try validate(snapshot)
        return snapshot
    }

    public static func validate(_ snapshot: MethodLibrarySnapshot) throws {
        var spaceIDs = Set<String>()
        var normalizedNames = Set<String>()
        for item in snapshot.userWorkingSpaces {
            guard item.revision.identity.kind == .user,
                  spaceIDs.insert(item.revision.identity.identifier).inserted,
                  normalizedNames.insert(WorkingSpaceValidator.normalizedName(item.libraryName)).inserted,
                  item.createdAt <= item.modifiedAt else {
                throw MethodDocumentError.inconsistentLibrary
            }
            _ = try WorkingSpaceValidator.validate(
                item.revision,
                libraryName: item.libraryName,
                purpose: item.purpose
            )
        }
        var recipeIDs = Set<UUID>()
        for item in snapshot.savedTransforms {
            guard recipeIDs.insert(item.recipe.identifier).inserted,
                  normalizedNames.insert(WorkingSpaceValidator.normalizedName(item.libraryName)).inserted,
                  item.createdAt <= item.modifiedAt else {
                throw MethodDocumentError.inconsistentLibrary
            }
            try TransformRecipeValidator.validate(item.recipe, libraryName: item.libraryName)
        }
    }
}

private enum CanonicalMethodJSON {
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(value)
        data.append(0x0A)
        return data
    }

    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw MethodDocumentError.invalidArtifact }
    }
}

private struct WorkingSpaceDefinitionV1: Codable {
    let identity: IdentityV1
    let definitionVersion: Int
    let base: String
    let baseChannelOrder: [String]
    let baseChannelUnits: [String]
    let workingChannelNames: [String]
    let forwardMatrix: [Double]
    let offset: [Double]
    let inverseMatrix: [Double]
    let outputBehavior: String

    init(_ revision: WorkingSpaceRevision) {
        identity = IdentityV1(kind: revision.identity.kind.rawValue, identifier: revision.identity.identifier)
        definitionVersion = revision.definitionVersion
        base = revision.base.rawValue
        baseChannelOrder = revision.baseChannelOrder
        baseChannelUnits = revision.baseChannelUnits
        workingChannelNames = revision.workingChannelNames
        forwardMatrix = revision.forward.rowMajorValues
        offset = [revision.offset.x, revision.offset.y, revision.offset.z]
        inverseMatrix = revision.inverse.rowMajorValues
        outputBehavior = revision.outputBehavior.rawValue
    }

    func value() throws -> WorkingSpaceRevision {
        guard let kind = WorkingSpaceIdentity.Kind(rawValue: identity.kind),
              let baseValue = WorkingSpaceBase(rawValue: base),
              let behavior = WorkingSpaceOutputBehavior(rawValue: outputBehavior) else {
            throw MethodDocumentError.invalidArtifact
        }
        guard forwardMatrix.count == 9 else {
            throw MethodDocumentError.invalidValueCount(
                field: "forwardMatrix", expected: 9, actual: forwardMatrix.count
            )
        }
        guard offset.count == 3 else {
            throw MethodDocumentError.invalidValueCount(field: "offset", expected: 3, actual: offset.count)
        }
        guard inverseMatrix.count == 9 else {
            throw MethodDocumentError.invalidValueCount(
                field: "inverseMatrix", expected: 9, actual: inverseMatrix.count
            )
        }
        let revision = WorkingSpaceRevision(
            identity: WorkingSpaceIdentity(kind: kind, identifier: identity.identifier),
            definitionVersion: definitionVersion,
            base: baseValue,
            baseChannelOrder: baseChannelOrder,
            baseChannelUnits: baseChannelUnits,
            workingChannelNames: workingChannelNames,
            forward: try Matrix3x3(checked: forwardMatrix),
            offset: SIMD3(offset[0], offset[1], offset[2]),
            inverse: try Matrix3x3(checked: inverseMatrix),
            outputBehavior: behavior
        )
        _ = try WorkingSpaceValidator.validate(revision)
        return revision
    }
}

private struct IdentityV1: Codable {
    let kind: String
    let identifier: String
}

private struct WorkingSpaceDocumentV1: Codable {
    let schema: String
    let version: Int
    let libraryName: String
    let purpose: String?
    let definition: WorkingSpaceDefinitionV1

    enum CodingKeys: String, CodingKey { case schema, version, libraryName, purpose, definition }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(version, forKey: .version)
        try container.encode(libraryName, forKey: .libraryName)
        if let purpose { try container.encode(purpose, forKey: .purpose) }
        else { try container.encodeNil(forKey: .purpose) }
        try container.encode(definition, forKey: .definition)
    }
}

private struct AlgorithmV1: Codable {
    let identifier: String
    let version: Int
}

private struct FingerprintMethodV1: Codable {
    let algorithm: String
    let value: String
}

private struct SourceMethodV1: Codable {
    let filename: String
    let width: Int
    let height: Int
    let analysisPixelFormat: String
    let fingerprint: FingerprintMethodV1

    init(_ source: AnalysisSourceDescriptor) {
        filename = source.displayFilename
        width = source.width
        height = source.height
        analysisPixelFormat = source.analysisPixelFormat
        fingerprint = FingerprintMethodV1(
            algorithm: source.fingerprint.algorithm,
            value: source.fingerprint.value
        )
    }

    func value() throws -> AnalysisSourceDescriptor {
        try AnalysisSourceDescriptor(
            displayFilename: filename,
            width: width,
            height: height,
            analysisPixelFormat: analysisPixelFormat,
            fingerprint: AnalysisSourceFingerprint(algorithm: fingerprint.algorithm, value: fingerprint.value)
        )
    }
}

private struct NormalizedMethodRegionV1: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct SourcePixelsMethodV1: Codable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

private struct RegionMethodV1: Codable {
    let normalized: NormalizedMethodRegionV1
    let sourcePixels: SourcePixelsMethodV1

    init(_ region: AnalysisRegionRecord) {
        normalized = NormalizedMethodRegionV1(
            x: region.normalized.x,
            y: region.normalized.y,
            width: region.normalized.width,
            height: region.normalized.height
        )
        sourcePixels = SourcePixelsMethodV1(
            x: region.sourcePixels.x,
            y: region.sourcePixels.y,
            width: region.sourcePixels.width,
            height: region.sourcePixels.height
        )
    }

    func value() throws -> AnalysisRegionRecord {
        AnalysisRegionRecord(
            normalized: try NormalizedAnalysisRegion(
                x: normalized.x,
                y: normalized.y,
                width: normalized.width,
                height: normalized.height
            ),
            sourcePixels: SourcePixelRegion(
                x: sourcePixels.x,
                y: sourcePixels.y,
                width: sourcePixels.width,
                height: sourcePixels.height
            )
        )
    }
}

private struct OriginatingAnalysisV1: Codable {
    let matrixMode: String
    let samplingMode: String
    let samplePixelCount: Int
    let region: RegionMethodV1?

    init(_ value: OriginatingAnalysis) {
        matrixMode = value.matrixMode.rawValue
        samplingMode = value.samplingMode.rawValue
        samplePixelCount = value.samplePixelCount
        region = value.region.map(RegionMethodV1.init)
    }

    func value() throws -> OriginatingAnalysis {
        guard let matrix = AnalysisMatrixMode(rawValue: matrixMode),
              let sampling = AnalysisSampleSource(rawValue: samplingMode) else {
            throw MethodDocumentError.invalidArtifact
        }
        return OriginatingAnalysis(
            matrixMode: matrix,
            samplingMode: sampling,
            region: try region?.value(),
            samplePixelCount: samplePixelCount
        )
    }

    enum CodingKeys: String, CodingKey { case matrixMode, samplingMode, samplePixelCount, region }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrixMode, forKey: .matrixMode)
        try container.encode(samplingMode, forKey: .samplingMode)
        try container.encode(samplePixelCount, forKey: .samplePixelCount)
        if let region { try container.encode(region, forKey: .region) }
        else { try container.encodeNil(forKey: .region) }
    }
}

private struct FrozenOutputMappingV1: Codable {
    let kind: String
    let minimum: Double?
    let maximum: Double?
    let scale: Double?
    let clipsToUnitRange: Bool?
    let referenceWhite: [Double]?
    let clipsFiniteOutOfGamutValues: Bool?

    init(_ value: FrozenOutputMapping) {
        switch value {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, clips):
            kind = WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue
            self.minimum = minimum
            self.maximum = maximum
            self.scale = scale
            clipsToUnitRange = clips
            referenceWhite = nil
            clipsFiniteOutOfGamutValues = nil
        case let .cieLabD65ToClippedSRGBV1(white, clips):
            kind = WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue
            minimum = nil
            maximum = nil
            scale = nil
            clipsToUnitRange = nil
            referenceWhite = [white.x, white.y, white.z]
            clipsFiniteOutOfGamutValues = clips
        }
    }

    func value() throws -> FrozenOutputMapping {
        switch kind {
        case WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue:
            guard let minimum, let maximum, let scale, let clipsToUnitRange,
                  referenceWhite == nil, clipsFiniteOutOfGamutValues == nil else {
                throw MethodDocumentError.invalidArtifact
            }
            return .encodedSRGBGlobalRangeV1(
                minimum: minimum, maximum: maximum, scale: scale, clipsToUnitRange: clipsToUnitRange
            )
        case WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue:
            guard minimum == nil, maximum == nil, scale == nil, clipsToUnitRange == nil,
                  let referenceWhite, referenceWhite.count == 3,
                  let clipsFiniteOutOfGamutValues else {
                throw MethodDocumentError.invalidArtifact
            }
            return .cieLabD65ToClippedSRGBV1(
                referenceWhite: SIMD3(referenceWhite[0], referenceWhite[1], referenceWhite[2]),
                clipsFiniteOutOfGamutValues: clipsFiniteOutOfGamutValues
            )
        default: throw MethodDocumentError.invalidArtifact
        }
    }
}

private struct FrozenApplicationV1: Codable {
    let workingCenter: [Double]
    let transform: [Double]
    let outputMapping: FrozenOutputMappingV1
    let matrixStorage: String
    let alphaPolicy: String
    let byteQuantization: String

    init(_ recipe: TransformRecipeSnapshot) {
        workingCenter = [recipe.workingCenter.x, recipe.workingCenter.y, recipe.workingCenter.z]
        transform = recipe.transform.rowMajorValues
        outputMapping = FrozenOutputMappingV1(recipe.outputMapping)
        matrixStorage = "row-major"
        alphaPolicy = "preserve-source-byte"
        byteQuantization = "clamp-unit-premultiply-round-nearest"
    }
}

private struct InterpretationMethodV1: Codable {
    let exploratoryUseNotice: String
}

private struct TransformRecipeV1: Codable {
    let identifier: String
    let recipeFormatVersion: Int
    let algorithm: AlgorithmV1
    let workingSpaceNameAtCapture: String
    let workingSpace: WorkingSpaceDefinitionV1
    let originSource: SourceMethodV1
    let originatingAnalysis: OriginatingAnalysisV1
    let frozenApplication: FrozenApplicationV1
    let interpretation: InterpretationMethodV1

    init(_ recipe: TransformRecipeSnapshot) {
        identifier = recipe.identifier.uuidString.lowercased()
        recipeFormatVersion = recipe.recipeFormatVersion
        algorithm = AlgorithmV1(identifier: recipe.algorithm.identifier, version: recipe.algorithm.version)
        workingSpaceNameAtCapture = recipe.workingSpaceNameAtCapture
        workingSpace = WorkingSpaceDefinitionV1(recipe.workingSpace)
        originSource = SourceMethodV1(recipe.originSource)
        originatingAnalysis = OriginatingAnalysisV1(recipe.originatingAnalysis)
        frozenApplication = FrozenApplicationV1(recipe)
        interpretation = InterpretationMethodV1(exploratoryUseNotice: recipe.exploratoryUseNotice)
    }

    func value() throws -> TransformRecipeSnapshot {
        guard let id = UUID(uuidString: identifier), id.uuidString.lowercased() == identifier,
              frozenApplication.matrixStorage == "row-major",
              frozenApplication.alphaPolicy == "preserve-source-byte",
              frozenApplication.byteQuantization == "clamp-unit-premultiply-round-nearest" else {
            throw MethodDocumentError.invalidArtifact
        }
        guard frozenApplication.workingCenter.count == 3 else {
            throw MethodDocumentError.invalidValueCount(
                field: "frozenApplication.workingCenter",
                expected: 3,
                actual: frozenApplication.workingCenter.count
            )
        }
        guard frozenApplication.transform.count == 9 else {
            throw MethodDocumentError.invalidValueCount(
                field: "frozenApplication.transform",
                expected: 9,
                actual: frozenApplication.transform.count
            )
        }
        return TransformRecipeSnapshot(
            identifier: id,
            recipeFormatVersion: recipeFormatVersion,
            algorithm: AlgorithmVersion(identifier: algorithm.identifier, version: algorithm.version),
            workingSpace: try workingSpace.value(),
            workingSpaceNameAtCapture: workingSpaceNameAtCapture,
            originatingAnalysis: try originatingAnalysis.value(),
            originSource: try originSource.value(),
            workingCenter: SIMD3(
                frozenApplication.workingCenter[0],
                frozenApplication.workingCenter[1],
                frozenApplication.workingCenter[2]
            ),
            transform: try Matrix3x3(checked: frozenApplication.transform),
            outputMapping: try frozenApplication.outputMapping.value(),
            exploratoryUseNotice: interpretation.exploratoryUseNotice
        )
    }
}

private struct TransformRecipeDocumentV1: Codable {
    let schema: String
    let version: Int
    let libraryName: String
    let recipe: TransformRecipeV1
}

private enum MethodDate {
    static func makeFormatter() -> ISO8601DateFormatter {
        let value = ISO8601DateFormatter()
        value.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        value.timeZone = TimeZone(secondsFromGMT: 0)
        return value
    }

    static func string(_ date: Date) -> String {
        let raw = makeFormatter().string(from: date)
        guard let dot = raw.firstIndex(of: "."), let z = raw.firstIndex(of: "Z") else { return raw }
        let prefix = raw[...dot]
        let fractional = raw[raw.index(after: dot)..<z]
        return prefix + fractional.prefix(3) + "Z"
    }

    static func date(_ string: String) throws -> Date {
        guard string.count >= 24,
              string.dropLast().suffix(4).first == ".",
              let result = makeFormatter().date(from: string) else {
            throw MethodDocumentError.invalidArtifact
        }
        return result
    }
}

private struct UserWorkingSpaceV1: Codable {
    let libraryName: String
    let purpose: String?
    let createdAt: String
    let modifiedAt: String
    let definition: WorkingSpaceDefinitionV1

    init(_ item: UserWorkingSpaceItem) {
        libraryName = item.libraryName
        purpose = item.purpose
        createdAt = MethodDate.string(item.createdAt)
        modifiedAt = MethodDate.string(item.modifiedAt)
        definition = WorkingSpaceDefinitionV1(item.revision)
    }

    func value() throws -> UserWorkingSpaceItem {
        UserWorkingSpaceItem(
            libraryName: libraryName,
            purpose: purpose,
            revision: try definition.value(),
            createdAt: try MethodDate.date(createdAt),
            modifiedAt: try MethodDate.date(modifiedAt)
        )
    }

    enum CodingKeys: String, CodingKey { case libraryName, purpose, createdAt, modifiedAt, definition }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(libraryName, forKey: .libraryName)
        if let purpose { try container.encode(purpose, forKey: .purpose) }
        else { try container.encodeNil(forKey: .purpose) }
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(modifiedAt, forKey: .modifiedAt)
        try container.encode(definition, forKey: .definition)
    }
}

private struct SavedTransformV1: Codable {
    let libraryName: String
    let createdAt: String
    let modifiedAt: String
    let recipe: TransformRecipeV1

    init(_ item: SavedTransformItem) {
        libraryName = item.libraryName
        createdAt = MethodDate.string(item.createdAt)
        modifiedAt = MethodDate.string(item.modifiedAt)
        recipe = TransformRecipeV1(item.recipe)
    }

    func value() throws -> SavedTransformItem {
        SavedTransformItem(
            libraryName: libraryName,
            recipe: try recipe.value(),
            createdAt: try MethodDate.date(createdAt),
            modifiedAt: try MethodDate.date(modifiedAt)
        )
    }
}

private struct MethodLibraryDocumentV1: Codable {
    let schema: String
    let version: Int
    let userWorkingSpaces: [UserWorkingSpaceV1]
    let savedTransforms: [SavedTransformV1]
}

private enum StrictMethodJSON {
    static func prepare(_ data: Data, limit: Int) throws {
        guard data.count <= limit else { throw MethodDocumentError.oversized }
        guard !data.starts(with: [0xEF, 0xBB, 0xBF]), String(data: data, encoding: .utf8) != nil else {
            throw MethodDocumentError.invalidUTF8
        }
        var parser = DuplicateKeyParser(Array(data))
        try parser.parse()
    }

    static func object(_ data: Data) throws -> [String: Any] {
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MethodDocumentError.malformedJSON
            }
            return object
        } catch let error as MethodDocumentError { throw error }
        catch { throw MethodDocumentError.malformedJSON }
    }

    static func validateWorkingSpace(_ object: [String: Any]) throws {
        try exact(object, ["schema", "version", "libraryName", "purpose", "definition"])
        try validateDefinition(dictionary(object["definition"]))
    }

    static func validateRecipe(_ object: [String: Any]) throws {
        try exact(object, ["schema", "version", "libraryName", "recipe"])
        let recipe = try dictionary(object["recipe"])
        try exact(recipe, ["identifier", "recipeFormatVersion", "algorithm", "workingSpaceNameAtCapture", "workingSpace", "originSource", "originatingAnalysis", "frozenApplication", "interpretation"])
        try exact(try dictionary(recipe["algorithm"]), ["identifier", "version"])
        try validateDefinition(dictionary(recipe["workingSpace"]))
        try validateSource(dictionary(recipe["originSource"]))
        try validateOriginating(dictionary(recipe["originatingAnalysis"]))
        try validateFrozen(dictionary(recipe["frozenApplication"]))
        try exact(try dictionary(recipe["interpretation"]), ["exploratoryUseNotice"])
    }

    static func validateLibrary(_ object: [String: Any]) throws {
        try exact(object, ["schema", "version", "userWorkingSpaces", "savedTransforms"])
        guard let spaces = object["userWorkingSpaces"] as? [Any],
              let transforms = object["savedTransforms"] as? [Any] else {
            throw MethodDocumentError.unknownOrMissingField
        }
        for value in spaces {
            let item = try dictionary(value)
            try exact(item, ["libraryName", "purpose", "createdAt", "modifiedAt", "definition"])
            try validateDefinition(dictionary(item["definition"]))
        }
        for value in transforms {
            let item = try dictionary(value)
            try exact(item, ["libraryName", "createdAt", "modifiedAt", "recipe"])
            let wrapper: [String: Any] = [
                "schema": TransformRecipeDocumentCodec.schemaIdentifier,
                "version": 1,
                "libraryName": item["libraryName"] as Any,
                "recipe": item["recipe"] as Any
            ]
            try validateRecipe(wrapper)
        }
    }

    private static func validateDefinition(_ object: [String: Any]) throws {
        try exact(object, ["identity", "definitionVersion", "base", "baseChannelOrder", "baseChannelUnits", "workingChannelNames", "forwardMatrix", "offset", "inverseMatrix", "outputBehavior"])
        try exact(try dictionary(object["identity"]), ["kind", "identifier"])
    }

    private static func validateSource(_ object: [String: Any]) throws {
        try exact(object, ["filename", "width", "height", "analysisPixelFormat", "fingerprint"])
        try exact(try dictionary(object["fingerprint"]), ["algorithm", "value"])
    }

    private static func validateOriginating(_ object: [String: Any]) throws {
        try exact(object, ["matrixMode", "samplingMode", "samplePixelCount", "region"])
        if !(object["region"] is NSNull) {
            let region = try dictionary(object["region"])
            try exact(region, ["normalized", "sourcePixels"])
            try exact(try dictionary(region["normalized"]), ["x", "y", "width", "height"])
            try exact(try dictionary(region["sourcePixels"]), ["x", "y", "width", "height"])
        }
    }

    private static func validateFrozen(_ object: [String: Any]) throws {
        try exact(object, ["workingCenter", "transform", "outputMapping", "matrixStorage", "alphaPolicy", "byteQuantization"])
        let mapping = try dictionary(object["outputMapping"])
        guard let kind = mapping["kind"] as? String else { throw MethodDocumentError.unknownOrMissingField }
        if kind == WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue {
            try exact(mapping, ["kind", "minimum", "maximum", "scale", "clipsToUnitRange"])
        } else if kind == WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue {
            try exact(mapping, ["kind", "referenceWhite", "clipsFiniteOutOfGamutValues"])
        } else {
            throw MethodDocumentError.invalidArtifact
        }
    }

    private static func dictionary(_ value: Any?) throws -> [String: Any] {
        guard let result = value as? [String: Any] else { throw MethodDocumentError.unknownOrMissingField }
        return result
    }

    private static func exact(_ dictionary: [String: Any], _ expected: Set<String>) throws {
        guard Set(dictionary.keys) == expected else { throw MethodDocumentError.unknownOrMissingField }
    }
}

private struct DuplicateKeyParser {
    private let bytes: [UInt8]
    private var index = 0

    init(_ bytes: [UInt8]) { self.bytes = bytes }

    mutating func parse() throws {
        skipWhitespace()
        try value(depth: 0)
        skipWhitespace()
        guard index == bytes.count else { throw MethodDocumentError.malformedJSON }
    }

    private mutating func value(depth: Int) throws {
        guard depth <= 16, index < bytes.count else {
            if depth > 16 { throw MethodDocumentError.excessiveDepth }
            throw MethodDocumentError.malformedJSON
        }
        switch bytes[index] {
        case 0x7B: try object(depth: depth + 1)
        case 0x5B: try array(depth: depth + 1)
        case 0x22: _ = try string()
        case 0x74: try literal("true")
        case 0x66: try literal("false")
        case 0x6E: try literal("null")
        case 0x2D, 0x30...0x39: try number()
        default: throw MethodDocumentError.malformedJSON
        }
    }

    private mutating func object(depth: Int) throws {
        guard depth <= 16 else { throw MethodDocumentError.excessiveDepth }
        index += 1
        skipWhitespace()
        if consume(0x7D) { return }
        var keys = Set<String>()
        while true {
            skipWhitespace()
            guard index < bytes.count, bytes[index] == 0x22 else { throw MethodDocumentError.malformedJSON }
            let key = try string()
            guard keys.insert(key).inserted else { throw MethodDocumentError.duplicateKey(key) }
            skipWhitespace()
            guard consume(0x3A) else { throw MethodDocumentError.malformedJSON }
            skipWhitespace()
            try value(depth: depth)
            skipWhitespace()
            if consume(0x7D) { return }
            guard consume(0x2C) else { throw MethodDocumentError.malformedJSON }
        }
    }

    private mutating func array(depth: Int) throws {
        guard depth <= 16 else { throw MethodDocumentError.excessiveDepth }
        index += 1
        skipWhitespace()
        if consume(0x5D) { return }
        while true {
            try value(depth: depth)
            skipWhitespace()
            if consume(0x5D) { return }
            guard consume(0x2C) else { throw MethodDocumentError.malformedJSON }
            skipWhitespace()
        }
    }

    private mutating func string() throws -> String {
        let start = index
        index += 1
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x22 {
                index += 1
                guard let result = String(bytes: bytes[start..<index], encoding: .utf8),
                      let decoded = try? JSONDecoder().decode(String.self, from: Data(result.utf8)) else {
                    throw MethodDocumentError.malformedJSON
                }
                return decoded
            }
            if byte < 0x20 { throw MethodDocumentError.malformedJSON }
            if byte == 0x5C {
                index += 1
                guard index < bytes.count else { throw MethodDocumentError.malformedJSON }
                if bytes[index] == 0x75 {
                    guard index + 4 < bytes.count,
                          bytes[(index + 1)...(index + 4)].allSatisfy({
                              (0x30...0x39).contains($0) || (0x41...0x46).contains($0) || (0x61...0x66).contains($0)
                          }) else { throw MethodDocumentError.malformedJSON }
                    index += 4
                } else if ![0x22, 0x5C, 0x2F, 0x62, 0x66, 0x6E, 0x72, 0x74].contains(bytes[index]) {
                    throw MethodDocumentError.malformedJSON
                }
            }
            index += 1
        }
        throw MethodDocumentError.malformedJSON
    }

    private mutating func number() throws {
        let start = index
        if consume(0x2D), index >= bytes.count { throw MethodDocumentError.malformedJSON }
        if consume(0x30) {
            if index < bytes.count, (0x30...0x39).contains(bytes[index]) { throw MethodDocumentError.malformedJSON }
        } else {
            guard index < bytes.count, (0x31...0x39).contains(bytes[index]) else { throw MethodDocumentError.malformedJSON }
            while index < bytes.count, (0x30...0x39).contains(bytes[index]) { index += 1 }
        }
        if consume(0x2E) {
            guard index < bytes.count, (0x30...0x39).contains(bytes[index]) else { throw MethodDocumentError.malformedJSON }
            while index < bytes.count, (0x30...0x39).contains(bytes[index]) { index += 1 }
        }
        if index < bytes.count, bytes[index] == 0x65 || bytes[index] == 0x45 {
            index += 1
            if index < bytes.count, bytes[index] == 0x2B || bytes[index] == 0x2D { index += 1 }
            guard index < bytes.count, (0x30...0x39).contains(bytes[index]) else { throw MethodDocumentError.malformedJSON }
            while index < bytes.count, (0x30...0x39).contains(bytes[index]) { index += 1 }
        }
        guard Double(String(decoding: bytes[start..<index], as: UTF8.self))?.isFinite == true else {
            throw MethodDocumentError.malformedJSON
        }
    }

    private mutating func literal(_ string: String) throws {
        let encoded = Array(string.utf8)
        guard index + encoded.count <= bytes.count,
              Array(bytes[index..<(index + encoded.count)]) == encoded else {
            throw MethodDocumentError.malformedJSON
        }
        index += encoded.count
    }

    private mutating func skipWhitespace() {
        while index < bytes.count, [0x20, 0x09, 0x0A, 0x0D].contains(bytes[index]) { index += 1 }
    }

    private mutating func consume(_ byte: UInt8) -> Bool {
        guard index < bytes.count, bytes[index] == byte else { return false }
        index += 1
        return true
    }
}
