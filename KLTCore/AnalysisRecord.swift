import CryptoKit
import Foundation

public enum AnalysisRecordError: Error, LocalizedError, Equatable {
    case invalidSource
    case invalidFingerprint
    case invalidRegion
    case invalidValueCount(expected: Int, actual: Int)
    case invalidStableCount
    case nonFiniteValue

    public var errorDescription: String? {
        switch self {
        case .invalidSource, .invalidFingerprint, .invalidRegion,
             .invalidValueCount, .invalidStableCount, .nonFiniteValue:
            "The analysis produced an invalid reproducibility record. Try another method or source image."
        }
    }
}

public struct AnalysisSourceFingerprint: Equatable, Hashable, Sendable {
    public let algorithm: String
    public let value: String

    public init(algorithm: String, value: String) throws {
        guard algorithm == "sha256",
              value.count == 64,
              value.allSatisfy({ $0.isHexDigit && !$0.isUppercase })
        else {
            throw AnalysisRecordError.invalidFingerprint
        }
        self.algorithm = algorithm
        self.value = value
    }

    static func sha256(
        width: Int,
        height: Int,
        rgba8Premultiplied: Data
    ) throws -> AnalysisSourceFingerprint {
        guard width > 0, height > 0 else { throw AnalysisRecordError.invalidSource }

        var hasher = SHA256()
        hasher.update(data: Data("KLTImage.AnalysisSource.v1\0".utf8))
        update(&hasher, unsignedBigEndian: UInt64(width))
        update(&hasher, unsignedBigEndian: UInt64(height))
        hasher.update(data: Data("rgba8-premultiplied-srgb\0".utf8))

        let chunkSize = 1_048_576
        var offset = 0
        while offset < rgba8Premultiplied.count {
            try Task.checkCancellation()
            let end = min(offset + chunkSize, rgba8Premultiplied.count)
            hasher.update(data: rgba8Premultiplied[offset..<end])
            offset = end
        }

        let value = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return try AnalysisSourceFingerprint(algorithm: "sha256", value: value)
    }

    private static func update(_ hasher: inout SHA256, unsignedBigEndian value: UInt64) {
        var encoded = value.bigEndian
        withUnsafeBytes(of: &encoded) { bytes in
            hasher.update(data: Data(bytes))
        }
    }
}

public struct AnalysisSourceDescriptor: Equatable, Sendable {
    public static let pixelFormat = "rgba8-premultiplied-srgb"

    public let displayFilename: String
    public let width: Int
    public let height: Int
    public let analysisPixelFormat: String
    public let fingerprint: AnalysisSourceFingerprint

    public init(
        displayFilename: String,
        width: Int,
        height: Int,
        analysisPixelFormat: String = AnalysisSourceDescriptor.pixelFormat,
        fingerprint: AnalysisSourceFingerprint
    ) throws {
        guard !displayFilename.isEmpty,
              width > 0,
              height > 0,
              analysisPixelFormat == Self.pixelFormat
        else {
            throw AnalysisRecordError.invalidSource
        }
        self.displayFilename = displayFilename
        self.width = width
        self.height = height
        self.analysisPixelFormat = analysisPixelFormat
        self.fingerprint = fingerprint
    }
}

public struct NormalizedAnalysisRegion: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) throws {
        let values = [x, y, width, height]
        guard values.allSatisfy(\.isFinite),
              x >= 0,
              y >= 0,
              width > 0,
              height > 0,
              x + width <= 1.000000000000001,
              y + height <= 1.000000000000001
        else {
            throw AnalysisRecordError.invalidRegion
        }
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct AnalysisRegionRecord: Equatable, Sendable {
    public let normalized: NormalizedAnalysisRegion
    public let sourcePixels: SourcePixelRegion

    public init(normalized: NormalizedAnalysisRegion, sourcePixels: SourcePixelRegion) {
        self.normalized = normalized
        self.sourcePixels = sourcePixels
    }
}

public struct AnalysisConventions: Equatable, Sendable {
    public let channelOrder: [String]
    public let channelUnits: [String]
    public let matrixStorage: String
    public let regionOrigin: String
    public let regionBounds: String

    public init(
        channelOrder: [String],
        channelUnits: [String],
        matrixStorage: String = "row-major",
        regionOrigin: String = "top-left",
        regionBounds: String = "half-open"
    ) throws {
        guard channelOrder.count == 3,
              channelUnits.count == 3,
              matrixStorage == "row-major",
              regionOrigin == "top-left",
              regionBounds == "half-open"
        else {
            throw AnalysisRecordError.invalidSource
        }
        self.channelOrder = channelOrder
        self.channelUnits = channelUnits
        self.matrixStorage = matrixStorage
        self.regionOrigin = regionOrigin
        self.regionBounds = regionBounds
    }

    static func forColorSpace(_ colorSpace: AnalysisColorSpace) throws -> AnalysisConventions {
        switch colorSpace {
        case .rgb:
            try AnalysisConventions(
                channelOrder: ["red", "green", "blue"],
                channelUnits: ["encoded-srgb-[0,1]", "encoded-srgb-[0,1]", "encoded-srgb-[0,1]"]
            )
        case .lab:
            try AnalysisConventions(
                channelOrder: ["L*", "a*", "b*"],
                channelUnits: ["L-star", "a-star", "b-star"]
            )
        }
    }
}

public struct AnalysisVector3: Equatable, Sendable {
    public let values: [Double]

    public init(values: [Double]) throws {
        guard values.count == 3 else {
            throw AnalysisRecordError.invalidValueCount(expected: 3, actual: values.count)
        }
        guard values.allSatisfy(\.isFinite) else { throw AnalysisRecordError.nonFiniteValue }
        self.values = values
    }

    init(_ value: SIMD3<Double>) throws {
        try self.init(values: [value.x, value.y, value.z])
    }
}

public struct AnalysisMatrix3: Equatable, Sendable {
    public let values: [Double]

    public init(values: [Double]) throws {
        guard values.count == 9 else {
            throw AnalysisRecordError.invalidValueCount(expected: 9, actual: values.count)
        }
        guard values.allSatisfy(\.isFinite) else { throw AnalysisRecordError.nonFiniteValue }
        self.values = values
    }

    init(_ value: Matrix3x3) throws {
        try self.init(values: value.rowMajorValues)
    }
}

public enum AnalysisOutputMappingRecord: Equatable, Sendable {
    case rgbGlobalRange(minimum: Double, maximum: Double, scale: Double)
    case labD65ToSRGB(clipsFiniteOutOfGamutValues: Bool)
    case limitedVariationIdentity

    var finiteValues: [Double] {
        switch self {
        case let .rgbGlobalRange(minimum, maximum, scale): [minimum, maximum, scale]
        case .labD65ToSRGB, .limitedVariationIdentity: []
        }
    }
}

public struct AnalysisMathematicsRecord: Equatable, Sendable {
    public let samplePixelCount: Int
    public let mean: AnalysisVector3
    public let covariance: AnalysisMatrix3
    public let analysisMatrix: AnalysisMatrix3
    public let eigenvalues: AnalysisVector3
    public let eigenvectors: AnalysisMatrix3
    public let transform: AnalysisMatrix3
    public let stableVariableCount: Int
    public let stableComponentCount: Int
    public let outputMapping: AnalysisOutputMappingRecord

    public init(
        samplePixelCount: Int,
        mean: AnalysisVector3,
        covariance: AnalysisMatrix3,
        analysisMatrix: AnalysisMatrix3,
        eigenvalues: AnalysisVector3,
        eigenvectors: AnalysisMatrix3,
        transform: AnalysisMatrix3,
        stableVariableCount: Int,
        stableComponentCount: Int,
        outputMapping: AnalysisOutputMappingRecord
    ) throws {
        guard samplePixelCount > 0 else { throw AnalysisRecordError.invalidSource }
        guard (0...3).contains(stableVariableCount),
              (0...3).contains(stableComponentCount)
        else {
            throw AnalysisRecordError.invalidStableCount
        }
        guard outputMapping.finiteValues.allSatisfy(\.isFinite) else {
            throw AnalysisRecordError.nonFiniteValue
        }
        self.samplePixelCount = samplePixelCount
        self.mean = mean
        self.covariance = covariance
        self.analysisMatrix = analysisMatrix
        self.eigenvalues = eigenvalues
        self.eigenvectors = eigenvectors
        self.transform = transform
        self.stableVariableCount = stableVariableCount
        self.stableComponentCount = stableComponentCount
        self.outputMapping = outputMapping
    }
}

public struct AnalysisRecord: Equatable, Sendable {
    public let source: AnalysisSourceDescriptor
    public let input: AnalysisInput
    public let region: AnalysisRegionRecord?
    public let conventions: AnalysisConventions
    public let mathematics: AnalysisMathematicsRecord
    public let hasLimitedVariation: Bool

    public init(
        source: AnalysisSourceDescriptor,
        input: AnalysisInput,
        region: AnalysisRegionRecord?,
        conventions: AnalysisConventions,
        mathematics: AnalysisMathematicsRecord,
        hasLimitedVariation: Bool
    ) throws {
        switch input.sampleSource {
        case .wholeImage:
            guard region == nil else { throw AnalysisRecordError.invalidRegion }
        case .selectedRegion:
            guard region?.sourcePixels == input.region else { throw AnalysisRecordError.invalidRegion }
        }
        self.source = source
        self.input = input
        self.region = region
        self.conventions = conventions
        self.mathematics = mathematics
        self.hasLimitedVariation = hasLimitedVariation
        try validateForEncoding()
    }

    public init(
        decodedSource: DecodedImage,
        displayFilename: String,
        enhancement: EnhancedImage
    ) throws {
        let source = try AnalysisSourceDescriptor(
            displayFilename: displayFilename,
            width: decodedSource.width,
            height: decodedSource.height,
            fingerprint: decodedSource.analysisSourceFingerprint
        )
        let input = enhancement.descriptor.input
        let region: AnalysisRegionRecord?
        switch input.sampleSource {
        case .wholeImage:
            region = nil
        case .selectedRegion:
            let validated = try SourcePixelRegionValidator.validate(
                input.region,
                sourceWidth: decodedSource.width,
                sourceHeight: decodedSource.height
            )
            let bounds = validated.bounds
            region = AnalysisRegionRecord(
                normalized: try NormalizedAnalysisRegion(
                    x: Double(bounds.x) / Double(decodedSource.width),
                    y: Double(bounds.y) / Double(decodedSource.height),
                    width: Double(bounds.width) / Double(decodedSource.width),
                    height: Double(bounds.height) / Double(decodedSource.height)
                ),
                sourcePixels: bounds
            )
        }

        let outputMapping: AnalysisOutputMappingRecord
        switch enhancement.analysis.outputMapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            outputMapping = .rgbGlobalRange(minimum: minimum, maximum: maximum, scale: scale)
        case .labD65ToSRGB:
            outputMapping = .labD65ToSRGB(clipsFiniteOutOfGamutValues: true)
        case .limitedVariationIdentity:
            outputMapping = .limitedVariationIdentity
        }

        try self.init(
            source: source,
            input: input,
            region: region,
            conventions: AnalysisConventions.forColorSpace(input.method.colorSpace),
            mathematics: AnalysisMathematicsRecord(
                samplePixelCount: enhancement.descriptor.samplePixelCount,
                mean: try AnalysisVector3(enhancement.analysis.mean),
                covariance: try AnalysisMatrix3(enhancement.analysis.covariance),
                analysisMatrix: try AnalysisMatrix3(enhancement.analysis.analysisMatrix),
                eigenvalues: try AnalysisVector3(enhancement.analysis.eigenvalues),
                eigenvectors: try AnalysisMatrix3(enhancement.analysis.eigenvectors),
                transform: try AnalysisMatrix3(enhancement.analysis.transform),
                stableVariableCount: enhancement.analysis.stableVariableCount,
                stableComponentCount: enhancement.analysis.stableComponentCount,
                outputMapping: outputMapping
            ),
            hasLimitedVariation: enhancement.descriptor.hasLimitedVariation
        )
    }

    fileprivate func validateForEncoding() throws {
        let vectors = [mathematics.mean, mathematics.eigenvalues]
        let matrices = [
            mathematics.covariance,
            mathematics.analysisMatrix,
            mathematics.eigenvectors,
            mathematics.transform
        ]
        guard vectors.allSatisfy({ $0.values.count == 3 && $0.values.allSatisfy(\.isFinite) }),
              matrices.allSatisfy({ $0.values.count == 9 && $0.values.allSatisfy(\.isFinite) }),
              mathematics.outputMapping.finiteValues.allSatisfy(\.isFinite)
        else {
            throw AnalysisRecordError.nonFiniteValue
        }
    }
}

public enum AnalysisRecordJSONEncoder {
    public static let schemaIdentifier = "org.kltimage.analysis-record"
    public static let schemaVersion = 1
    public static let exploratoryUseNotice = "This record documents an exploratory enhancement. It does not establish a biological or scientific conclusion."

    public static func data(for record: AnalysisRecord) throws -> Data {
        try record.validateForEncoding()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = try encoder.encode(KLTAnalysisDocumentV1(record: record))
        data.append(0x0A)
        return data
    }

    public static func write(_ record: AnalysisRecord, to url: URL) throws {
        try data(for: record).write(to: url, options: .atomic)
    }
}

private struct KLTAnalysisDocumentV1: Encodable {
    let schema = AnalysisRecordJSONEncoder.schemaIdentifier
    let version = AnalysisRecordJSONEncoder.schemaVersion
    let source: SourceV1
    let request: RequestV1
    let conventions: ConventionsV1
    let mathematics: MathematicsV1
    let interpretation: InterpretationV1

    init(record: AnalysisRecord) {
        source = SourceV1(record.source)
        request = RequestV1(record)
        conventions = ConventionsV1(record.conventions)
        mathematics = MathematicsV1(record.mathematics)
        interpretation = InterpretationV1(
            limitedVariation: record.hasLimitedVariation,
            exploratoryUseNotice: AnalysisRecordJSONEncoder.exploratoryUseNotice
        )
    }
}

private struct SourceV1: Encodable {
    let filename: String
    let width: Int
    let height: Int
    let analysisPixelFormat: String
    let fingerprint: FingerprintV1

    init(_ source: AnalysisSourceDescriptor) {
        filename = source.displayFilename
        width = source.width
        height = source.height
        analysisPixelFormat = source.analysisPixelFormat
        fingerprint = FingerprintV1(
            algorithm: source.fingerprint.algorithm,
            value: source.fingerprint.value
        )
    }
}

private struct FingerprintV1: Encodable {
    let algorithm: String
    let value: String
}

private struct RequestV1: Encodable {
    let colorSpace: String
    let matrixMode: String
    let samplingMode: String
    let region: RegionV1?

    init(_ record: AnalysisRecord) {
        colorSpace = record.input.method.colorSpace.rawValue
        matrixMode = record.input.method.matrixMode.rawValue
        samplingMode = record.input.sampleSource.rawValue
        region = record.region.map(RegionV1.init)
    }

    private enum CodingKeys: String, CodingKey {
        case colorSpace, matrixMode, samplingMode, region
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(colorSpace, forKey: .colorSpace)
        try container.encode(matrixMode, forKey: .matrixMode)
        try container.encode(samplingMode, forKey: .samplingMode)
        if let region {
            try container.encode(region, forKey: .region)
        } else {
            try container.encodeNil(forKey: .region)
        }
    }
}

private struct RegionV1: Encodable {
    let normalized: NormalizedRegionV1
    let sourcePixels: SourcePixelsV1

    init(_ region: AnalysisRegionRecord) {
        normalized = NormalizedRegionV1(
            x: region.normalized.x,
            y: region.normalized.y,
            width: region.normalized.width,
            height: region.normalized.height
        )
        sourcePixels = SourcePixelsV1(
            x: region.sourcePixels.x,
            y: region.sourcePixels.y,
            width: region.sourcePixels.width,
            height: region.sourcePixels.height
        )
    }
}

private struct NormalizedRegionV1: Encodable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

private struct SourcePixelsV1: Encodable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

private struct ConventionsV1: Encodable {
    let channelOrder: [String]
    let channelUnits: [String]
    let matrixStorage: String
    let regionOrigin: String
    let regionBounds: String

    init(_ conventions: AnalysisConventions) {
        channelOrder = conventions.channelOrder
        channelUnits = conventions.channelUnits
        matrixStorage = conventions.matrixStorage
        regionOrigin = conventions.regionOrigin
        regionBounds = conventions.regionBounds
    }
}

private struct MathematicsV1: Encodable {
    let samplePixelCount: Int
    let mean: [Double]
    let covariance: [Double]
    let analysisMatrix: [Double]
    let eigenvalues: [Double]
    let eigenvectors: [Double]
    let transform: [Double]
    let stableVariableCount: Int
    let stableComponentCount: Int
    let outputMapping: OutputMappingV1

    init(_ mathematics: AnalysisMathematicsRecord) {
        samplePixelCount = mathematics.samplePixelCount
        mean = mathematics.mean.values
        covariance = mathematics.covariance.values
        analysisMatrix = mathematics.analysisMatrix.values
        eigenvalues = mathematics.eigenvalues.values
        eigenvectors = mathematics.eigenvectors.values
        transform = mathematics.transform.values
        stableVariableCount = mathematics.stableVariableCount
        stableComponentCount = mathematics.stableComponentCount
        outputMapping = OutputMappingV1(mathematics.outputMapping)
    }
}

private enum OutputMappingV1: Encodable {
    case rgb(minimum: Double, maximum: Double, scale: Double)
    case lab(clipsFiniteOutOfGamutValues: Bool)
    case identity

    init(_ mapping: AnalysisOutputMappingRecord) {
        switch mapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            self = .rgb(minimum: minimum, maximum: maximum, scale: scale)
        case let .labD65ToSRGB(clipsFiniteOutOfGamutValues):
            self = .lab(clipsFiniteOutOfGamutValues: clipsFiniteOutOfGamutValues)
        case .limitedVariationIdentity:
            self = .identity
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, minimum, maximum, scale, clipsToUnitRange, clipsFiniteOutOfGamutValues
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .rgb(minimum, maximum, scale):
            try container.encode("rgbGlobalRange", forKey: .type)
            try container.encode(minimum, forKey: .minimum)
            try container.encode(maximum, forKey: .maximum)
            try container.encode(scale, forKey: .scale)
            try container.encode(true, forKey: .clipsToUnitRange)
        case let .lab(clipsFiniteOutOfGamutValues):
            try container.encode("labD65ToSRGB", forKey: .type)
            try container.encode(
                clipsFiniteOutOfGamutValues,
                forKey: .clipsFiniteOutOfGamutValues
            )
        case .identity:
            try container.encode("limitedVariationIdentity", forKey: .type)
        }
    }
}

private struct InterpretationV1: Encodable {
    let limitedVariation: Bool
    let exploratoryUseNotice: String
}
