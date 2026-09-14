import Foundation

public enum AnalysisRecordSnapshot: Equatable, Sendable {
    case legacyV1(AnalysisRecord)
    case extendedV2(ExtendedAnalysisRecord)

    public var executionMode: String {
        switch self {
        case .legacyV1: "calculated"
        case let .extendedV2(record): record.executionMode
        }
    }
}

public struct ExtendedCalculationRecord: Equatable, Sendable {
    public let matrixMode: AnalysisMatrixMode
    public let samplingMode: AnalysisSampleSource
    public let region: AnalysisRegionRecord?
    public let mathematics: AnalysisMathematicsRecord
}

public struct ExtendedReplayRecord: Equatable, Sendable {
    public let recipeNameAtExecution: String
    public let recipe: TransformRecipeSnapshot
    public let diagnostics: ReplayDiagnostics
}

public struct ExtendedAnalysisRecord: Equatable, Sendable {
    public let targetSource: AnalysisSourceDescriptor
    public let executionMode: String
    public let workingSpaceNameAtExecution: String
    public let workingSpace: WorkingSpaceRevision
    public let calculation: ExtendedCalculationRecord?
    public let replay: ExtendedReplayRecord?
    public let hasLimitedVariation: Bool

    public init(
        targetSource: AnalysisSourceDescriptor,
        executionMode: String,
        workingSpaceNameAtExecution: String,
        workingSpace: WorkingSpaceRevision,
        calculation: ExtendedCalculationRecord?,
        replay: ExtendedReplayRecord?,
        hasLimitedVariation: Bool
    ) {
        self.targetSource = targetSource
        self.executionMode = executionMode
        self.workingSpaceNameAtExecution = workingSpaceNameAtExecution
        self.workingSpace = workingSpace
        self.calculation = calculation
        self.replay = replay
        self.hasLimitedVariation = hasLimitedVariation
    }
}

public enum AnalysisRecordRouter {
    public static func make(
        decodedSource: DecodedImage,
        displayFilename: String,
        enhancement: EnhancedImage
    ) throws -> AnalysisRecordSnapshot {
        guard let applied = enhancement.appliedMethod else {
            return .legacyV1(try AnalysisRecord(
                decodedSource: decodedSource,
                displayFilename: displayFilename,
                enhancement: enhancement
            ))
        }
        switch applied {
        case let .calculated(space, name):
            if space.identity.kind == .standard {
                return .legacyV1(try AnalysisRecord(
                    decodedSource: decodedSource,
                    displayFilename: displayFilename,
                    enhancement: enhancement
                ))
            }
            let source = try sourceDescriptor(decodedSource, displayFilename)
            let region = try regionRecord(
                enhancement.descriptor.input.region,
                samplingMode: enhancement.descriptor.input.sampleSource,
                width: source.width,
                height: source.height
            )
            return .extendedV2(ExtendedAnalysisRecord(
                targetSource: source,
                executionMode: "calculated",
                workingSpaceNameAtExecution: name,
                workingSpace: space,
                calculation: ExtendedCalculationRecord(
                    matrixMode: enhancement.descriptor.input.method.matrixMode,
                    samplingMode: enhancement.descriptor.input.sampleSource,
                    region: region,
                    mathematics: try mathematics(enhancement)
                ),
                replay: nil,
                hasLimitedVariation: enhancement.descriptor.hasLimitedVariation
            ))
        case let .replayed(recipe, recipeName, diagnostics):
            return .extendedV2(ExtendedAnalysisRecord(
                targetSource: try sourceDescriptor(decodedSource, displayFilename),
                executionMode: "replayed",
                workingSpaceNameAtExecution: recipe.workingSpaceNameAtCapture,
                workingSpace: recipe.workingSpace,
                calculation: nil,
                replay: ExtendedReplayRecord(
                    recipeNameAtExecution: recipeName,
                    recipe: recipe,
                    diagnostics: diagnostics
                ),
                hasLimitedVariation: false
            ))
        }
    }

    private static func sourceDescriptor(_ source: DecodedImage, _ filename: String) throws -> AnalysisSourceDescriptor {
        try AnalysisSourceDescriptor(
            displayFilename: filename,
            width: source.width,
            height: source.height,
            fingerprint: source.analysisSourceFingerprint
        )
    }

    private static func regionRecord(
        _ region: SourcePixelRegion?,
        samplingMode: AnalysisSampleSource,
        width: Int,
        height: Int
    ) throws -> AnalysisRegionRecord? {
        guard samplingMode == .selectedRegion else { return nil }
        let validated = try SourcePixelRegionValidator.validate(region, sourceWidth: width, sourceHeight: height)
        let bounds = validated.bounds
        return AnalysisRegionRecord(
            normalized: try NormalizedAnalysisRegion(
                x: Double(bounds.x) / Double(width),
                y: Double(bounds.y) / Double(height),
                width: Double(bounds.width) / Double(width),
                height: Double(bounds.height) / Double(height)
            ),
            sourcePixels: bounds
        )
    }

    private static func mathematics(_ enhancement: EnhancedImage) throws -> AnalysisMathematicsRecord {
        let output: AnalysisOutputMappingRecord
        switch enhancement.analysis.outputMapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            output = .rgbGlobalRange(minimum: minimum, maximum: maximum, scale: scale)
        case .labD65ToSRGB:
            output = .labD65ToSRGB(clipsFiniteOutOfGamutValues: true)
        case .limitedVariationIdentity:
            output = .limitedVariationIdentity
        }
        return try AnalysisMathematicsRecord(
            samplePixelCount: enhancement.descriptor.samplePixelCount,
            mean: AnalysisVector3(enhancement.analysis.mean),
            covariance: AnalysisMatrix3(enhancement.analysis.covariance),
            analysisMatrix: AnalysisMatrix3(enhancement.analysis.analysisMatrix),
            eigenvalues: AnalysisVector3(enhancement.analysis.eigenvalues),
            eigenvectors: AnalysisMatrix3(enhancement.analysis.eigenvectors),
            transform: AnalysisMatrix3(enhancement.analysis.transform),
            stableVariableCount: enhancement.analysis.stableVariableCount,
            stableComponentCount: enhancement.analysis.stableComponentCount,
            outputMapping: output
        )
    }
}

public enum AnalysisRecordSnapshotJSONEncoder {
    public static func data(for snapshot: AnalysisRecordSnapshot) throws -> Data {
        switch snapshot {
        case let .legacyV1(record):
            return try AnalysisRecordJSONEncoder.data(for: record)
        case let .extendedV2(record):
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
            var data = try encoder.encode(AnalysisDocumentV2(record))
            data.append(0x0A)
            return data
        }
    }

    public static func write(_ snapshot: AnalysisRecordSnapshot, to url: URL) throws {
        try data(for: snapshot).write(to: url, options: .atomic)
    }
}

private struct AnalysisDocumentV2: Encodable {
    let schema = AnalysisRecordJSONEncoder.schemaIdentifier
    let version = 2
    let targetSource: V2Source
    let execution: V2Execution
    let conventions: V2Conventions
    let calculation: V2Calculation?
    let replay: V2Replay?
    let interpretation: V2Interpretation

    init(_ record: ExtendedAnalysisRecord) {
        targetSource = V2Source(record.targetSource)
        execution = V2Execution(record)
        conventions = V2Conventions(record.workingSpace)
        calculation = record.calculation.map(V2Calculation.init)
        replay = record.replay.map(V2Replay.init)
        interpretation = V2Interpretation(
            limitedVariation: record.hasLimitedVariation,
            exploratoryUseNotice: TransformRecipeValidator.exploratoryUseNotice
        )
    }

    enum CodingKeys: String, CodingKey {
        case schema, version, targetSource, execution, conventions, calculation, replay, interpretation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schema, forKey: .schema)
        try container.encode(version, forKey: .version)
        try container.encode(targetSource, forKey: .targetSource)
        try container.encode(execution, forKey: .execution)
        try container.encode(conventions, forKey: .conventions)
        if let calculation { try container.encode(calculation, forKey: .calculation) }
        else { try container.encodeNil(forKey: .calculation) }
        if let replay { try container.encode(replay, forKey: .replay) }
        else { try container.encodeNil(forKey: .replay) }
        try container.encode(interpretation, forKey: .interpretation)
    }
}

private struct V2Fingerprint: Encodable { let algorithm: String; let value: String }
private struct V2Source: Encodable {
    let filename: String
    let width: Int
    let height: Int
    let analysisPixelFormat: String
    let fingerprint: V2Fingerprint
    init(_ value: AnalysisSourceDescriptor) {
        filename = value.displayFilename; width = value.width; height = value.height
        analysisPixelFormat = value.analysisPixelFormat
        fingerprint = V2Fingerprint(algorithm: value.fingerprint.algorithm, value: value.fingerprint.value)
    }
}
private struct V2Identity: Encodable { let kind: String; let identifier: String }
private struct V2WorkingSpace: Encodable {
    let identity: V2Identity
    let definitionVersion: Int
    let base: String
    let baseChannelOrder: [String]
    let baseChannelUnits: [String]
    let workingChannelNames: [String]
    let forwardMatrix: [Double]
    let offset: [Double]
    let inverseMatrix: [Double]
    let outputBehavior: String
    init(_ value: WorkingSpaceRevision) {
        identity = V2Identity(kind: value.identity.kind.rawValue, identifier: value.identity.identifier)
        definitionVersion = value.definitionVersion; base = value.base.rawValue
        baseChannelOrder = value.baseChannelOrder; baseChannelUnits = value.baseChannelUnits
        workingChannelNames = value.workingChannelNames; forwardMatrix = value.forward.rowMajorValues
        offset = [value.offset.x, value.offset.y, value.offset.z]
        inverseMatrix = value.inverse.rowMajorValues; outputBehavior = value.outputBehavior.rawValue
    }
}
private struct V2Algorithm: Encodable { let identifier: String; let version: Int }
private struct V2Execution: Encodable {
    let mode: String
    let algorithm = V2Algorithm(identifier: AlgorithmVersion.decorrelationStretchV1.identifier, version: 1)
    let workingSpaceNameAtExecution: String
    let workingSpace: V2WorkingSpace
    init(_ value: ExtendedAnalysisRecord) {
        mode = value.executionMode; workingSpaceNameAtExecution = value.workingSpaceNameAtExecution
        workingSpace = V2WorkingSpace(value.workingSpace)
    }
}
private struct V2Conventions: Encodable {
    let baseChannelOrder: [String]
    let baseChannelUnits: [String]
    let workingChannelOrder: [String]
    let matrixStorage = "row-major"
    let regionOrigin = "top-left"
    let regionBounds = "half-open"
    init(_ value: WorkingSpaceRevision) {
        baseChannelOrder = value.baseChannelOrder; baseChannelUnits = value.baseChannelUnits
        workingChannelOrder = value.workingChannelNames
    }
}
private struct V2NormalizedRegion: Encodable { let x: Double; let y: Double; let width: Double; let height: Double }
private struct V2PixelRegion: Encodable { let x: Int; let y: Int; let width: Int; let height: Int }
private struct V2Region: Encodable {
    let normalized: V2NormalizedRegion
    let sourcePixels: V2PixelRegion
    init(_ value: AnalysisRegionRecord) {
        normalized = V2NormalizedRegion(x: value.normalized.x, y: value.normalized.y, width: value.normalized.width, height: value.normalized.height)
        sourcePixels = V2PixelRegion(x: value.sourcePixels.x, y: value.sourcePixels.y, width: value.sourcePixels.width, height: value.sourcePixels.height)
    }
}
private struct V2OutputMapping: Encodable {
    let kind: String
    let minimum: Double?
    let maximum: Double?
    let scale: Double?
    let clipsToUnitRange: Bool?
    let referenceWhite: [Double]?
    let clipsFiniteOutOfGamutValues: Bool?
    init(_ value: AnalysisOutputMappingRecord) {
        switch value {
        case let .rgbGlobalRange(minimum, maximum, scale):
            kind = WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue
            self.minimum = minimum; self.maximum = maximum; self.scale = scale; clipsToUnitRange = true
            referenceWhite = nil; clipsFiniteOutOfGamutValues = nil
        case let .labD65ToSRGB(clips):
            kind = WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue
            minimum = nil; maximum = nil; scale = nil; clipsToUnitRange = nil
            referenceWhite = [0.95047, 1, 1.08883]; clipsFiniteOutOfGamutValues = clips
        case .limitedVariationIdentity:
            kind = "limited-variation-identity"; minimum = nil; maximum = nil; scale = nil
            clipsToUnitRange = nil; referenceWhite = nil; clipsFiniteOutOfGamutValues = nil
        }
    }
    init(_ value: FrozenOutputMapping) {
        switch value {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, clips):
            kind = WorkingSpaceOutputBehavior.encodedSRGBGlobalRangeV1.rawValue
            self.minimum = minimum; self.maximum = maximum; self.scale = scale; clipsToUnitRange = clips
            referenceWhite = nil; clipsFiniteOutOfGamutValues = nil
        case let .cieLabD65ToClippedSRGBV1(white, clips):
            kind = WorkingSpaceOutputBehavior.cieLabD65ToClippedSRGBV1.rawValue
            minimum = nil; maximum = nil; scale = nil; clipsToUnitRange = nil
            referenceWhite = [white.x, white.y, white.z]; clipsFiniteOutOfGamutValues = clips
        }
    }
}
private struct V2Calculation: Encodable {
    let matrixMode: String; let samplingMode: String; let region: V2Region?
    let samplePixelCount: Int; let workingMean: [Double]; let covariance: [Double]
    let analysisMatrix: [Double]; let eigenvalues: [Double]; let eigenvectors: [Double]
    let workingTransform: [Double]; let stableVariableCount: Int; let stableComponentCount: Int
    let outputMapping: V2OutputMapping
    init(_ value: ExtendedCalculationRecord) {
        matrixMode = value.matrixMode.rawValue; samplingMode = value.samplingMode.rawValue
        region = value.region.map(V2Region.init); samplePixelCount = value.mathematics.samplePixelCount
        workingMean = value.mathematics.mean.values; covariance = value.mathematics.covariance.values
        analysisMatrix = value.mathematics.analysisMatrix.values; eigenvalues = value.mathematics.eigenvalues.values
        eigenvectors = value.mathematics.eigenvectors.values; workingTransform = value.mathematics.transform.values
        stableVariableCount = value.mathematics.stableVariableCount; stableComponentCount = value.mathematics.stableComponentCount
        outputMapping = V2OutputMapping(value.mathematics.outputMapping)
    }

    private enum CodingKeys: String, CodingKey {
        case matrixMode, samplingMode, region, samplePixelCount, workingMean, covariance
        case analysisMatrix, eigenvalues, eigenvectors, workingTransform
        case stableVariableCount, stableComponentCount, outputMapping
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrixMode, forKey: .matrixMode)
        try container.encode(samplingMode, forKey: .samplingMode)
        if let region { try container.encode(region, forKey: .region) }
        else { try container.encodeNil(forKey: .region) }
        try container.encode(samplePixelCount, forKey: .samplePixelCount)
        try container.encode(workingMean, forKey: .workingMean)
        try container.encode(covariance, forKey: .covariance)
        try container.encode(analysisMatrix, forKey: .analysisMatrix)
        try container.encode(eigenvalues, forKey: .eigenvalues)
        try container.encode(eigenvectors, forKey: .eigenvectors)
        try container.encode(workingTransform, forKey: .workingTransform)
        try container.encode(stableVariableCount, forKey: .stableVariableCount)
        try container.encode(stableComponentCount, forKey: .stableComponentCount)
        try container.encode(outputMapping, forKey: .outputMapping)
    }
}
private struct V2Originating: Encodable {
    let matrixMode: String; let samplingMode: String; let samplePixelCount: Int; let region: V2Region?
    init(_ value: OriginatingAnalysis) {
        matrixMode = value.matrixMode.rawValue; samplingMode = value.samplingMode.rawValue
        samplePixelCount = value.samplePixelCount; region = value.region.map(V2Region.init)
    }

    private enum CodingKeys: String, CodingKey {
        case matrixMode, samplingMode, samplePixelCount, region
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(matrixMode, forKey: .matrixMode)
        try container.encode(samplingMode, forKey: .samplingMode)
        try container.encode(samplePixelCount, forKey: .samplePixelCount)
        if let region { try container.encode(region, forKey: .region) }
        else { try container.encodeNil(forKey: .region) }
    }
}
private struct V2Frozen: Encodable {
    let workingCenter: [Double]; let transform: [Double]; let outputMapping: V2OutputMapping
    let matrixStorage = "row-major"; let alphaPolicy = "preserve-source-byte"
    let byteQuantization = "clamp-unit-premultiply-round-nearest"
    init(_ value: TransformRecipeSnapshot) {
        workingCenter = [value.workingCenter.x, value.workingCenter.y, value.workingCenter.z]
        transform = value.transform.rowMajorValues; outputMapping = V2OutputMapping(value.outputMapping)
    }
}
private struct V2RecipeIdentity: Encodable {
    let identifier: String; let recipeFormatVersion: Int; let libraryNameAtExecution: String
}
private struct V2Outcome: Encodable {
    let sameAsOrigin: Bool; let evaluatedPixelCount: Int; let clippedColorPixelCount: Int
    let clippedFraction: Double; let minimumMappedComponent: Double?; let maximumMappedComponent: Double?; let mappedRange: Double?
    init(_ value: ReplayDiagnostics) {
        sameAsOrigin = value.sameAsOrigin; evaluatedPixelCount = value.evaluatedPixelCount
        clippedColorPixelCount = value.clippedColorPixelCount; clippedFraction = value.clippedFraction
        minimumMappedComponent = value.minimumMappedComponent; maximumMappedComponent = value.maximumMappedComponent
        mappedRange = value.mappedRange
    }


    private enum CodingKeys: String, CodingKey {
        case sameAsOrigin, evaluatedPixelCount, clippedColorPixelCount, clippedFraction
        case minimumMappedComponent, maximumMappedComponent, mappedRange
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sameAsOrigin, forKey: .sameAsOrigin)
        try container.encode(evaluatedPixelCount, forKey: .evaluatedPixelCount)
        try container.encode(clippedColorPixelCount, forKey: .clippedColorPixelCount)
        try container.encode(clippedFraction, forKey: .clippedFraction)
        if let minimumMappedComponent {
            try container.encode(minimumMappedComponent, forKey: .minimumMappedComponent)
        } else {
            try container.encodeNil(forKey: .minimumMappedComponent)
        }
        if let maximumMappedComponent {
            try container.encode(maximumMappedComponent, forKey: .maximumMappedComponent)
        } else {
            try container.encodeNil(forKey: .maximumMappedComponent)
        }
        if let mappedRange { try container.encode(mappedRange, forKey: .mappedRange) }
        else { try container.encodeNil(forKey: .mappedRange) }
    }
}
private struct V2Replay: Encodable {
    let recipe: V2RecipeIdentity; let originSource: V2Source; let originatingAnalysis: V2Originating
    let frozenApplication: V2Frozen; let targetOutcome: V2Outcome
    init(_ value: ExtendedReplayRecord) {
        recipe = V2RecipeIdentity(
            identifier: value.recipe.identifier.uuidString.lowercased(),
            recipeFormatVersion: value.recipe.recipeFormatVersion,
            libraryNameAtExecution: value.recipeNameAtExecution
        )
        originSource = V2Source(value.recipe.originSource)
        originatingAnalysis = V2Originating(value.recipe.originatingAnalysis)
        frozenApplication = V2Frozen(value.recipe); targetOutcome = V2Outcome(value.diagnostics)
    }
}
private struct V2Interpretation: Encodable { let limitedVariation: Bool; let exploratoryUseNotice: String }
