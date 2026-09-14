import Foundation

public struct AlgorithmVersion: Equatable, Hashable, Sendable {
    public static let decorrelationStretchV1 = AlgorithmVersion(
        identifier: "org.kltimage.decorrelation-stretch",
        version: 1
    )

    public let identifier: String
    public let version: Int

    public init(identifier: String, version: Int) {
        self.identifier = identifier
        self.version = version
    }
}

public struct OriginatingAnalysis: Equatable, Hashable, Sendable {
    public let matrixMode: AnalysisMatrixMode
    public let samplingMode: AnalysisSampleSource
    public let region: AnalysisRegionRecord?
    public let samplePixelCount: Int

    public init(
        matrixMode: AnalysisMatrixMode,
        samplingMode: AnalysisSampleSource,
        region: AnalysisRegionRecord?,
        samplePixelCount: Int
    ) {
        self.matrixMode = matrixMode
        self.samplingMode = samplingMode
        self.region = region
        self.samplePixelCount = samplePixelCount
    }
}

public enum FrozenOutputMapping: Equatable, Hashable, Sendable {
    case encodedSRGBGlobalRangeV1(
        minimum: Double,
        maximum: Double,
        scale: Double,
        clipsToUnitRange: Bool
    )
    case cieLabD65ToClippedSRGBV1(
        referenceWhite: SIMD3<Double>,
        clipsFiniteOutOfGamutValues: Bool
    )
}

public struct TransformRecipeSnapshot: Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID { identifier }
    public let identifier: UUID
    public let recipeFormatVersion: Int
    public let algorithm: AlgorithmVersion
    public let workingSpace: WorkingSpaceRevision
    public let workingSpaceNameAtCapture: String
    public let originatingAnalysis: OriginatingAnalysis
    public let originSource: AnalysisSourceDescriptor
    public let workingCenter: SIMD3<Double>
    public let transform: Matrix3x3
    public let outputMapping: FrozenOutputMapping
    public let exploratoryUseNotice: String

    public init(
        identifier: UUID,
        recipeFormatVersion: Int = 1,
        algorithm: AlgorithmVersion = .decorrelationStretchV1,
        workingSpace: WorkingSpaceRevision,
        workingSpaceNameAtCapture: String,
        originatingAnalysis: OriginatingAnalysis,
        originSource: AnalysisSourceDescriptor,
        workingCenter: SIMD3<Double>,
        transform: Matrix3x3,
        outputMapping: FrozenOutputMapping,
        exploratoryUseNotice: String = TransformRecipeValidator.exploratoryUseNotice
    ) {
        self.identifier = identifier
        self.recipeFormatVersion = recipeFormatVersion
        self.algorithm = algorithm
        self.workingSpace = workingSpace
        self.workingSpaceNameAtCapture = workingSpaceNameAtCapture
        self.originatingAnalysis = originatingAnalysis
        self.originSource = originSource
        self.workingCenter = workingCenter
        self.transform = transform
        self.outputMapping = outputMapping
        self.exploratoryUseNotice = exploratoryUseNotice
    }
}

public struct SavedTransformItem: Equatable, Sendable, Identifiable {
    public var id: UUID { recipe.identifier }
    public let libraryName: String
    public let recipe: TransformRecipeSnapshot
    public let createdAt: Date
    public let modifiedAt: Date

    public init(
        libraryName: String,
        recipe: TransformRecipeSnapshot,
        createdAt: Date,
        modifiedAt: Date
    ) {
        self.libraryName = libraryName
        self.recipe = recipe
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
}

public enum TransformRecipeValidationIssue: Error, Equatable, LocalizedError, Sendable {
    case unsupportedVersion
    case invalidName
    case invalidWorkingSpace
    case invalidOrigin
    case invalidOriginatingAnalysis
    case nonFiniteValue
    case transformOutOfBounds
    case centerOutOfBounds
    case invalidOutputMapping
    case invalidNotice

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This transform recipe version is not supported."
        case .invalidName: "The transform name must contain 1–80 characters."
        case .invalidWorkingSpace: "The frozen working-space definition is invalid."
        case .invalidOrigin: "The originating source description is invalid."
        case .invalidOriginatingAnalysis: "The originating analysis description is inconsistent."
        case .nonFiniteValue: "Every frozen transform value must be finite."
        case .transformOutOfBounds: "A frozen transform coefficient exceeds ±2,048."
        case .centerOutOfBounds: "A frozen center value exceeds ±100,000."
        case .invalidOutputMapping: "The frozen output mapping is inconsistent."
        case .invalidNotice: "The exploratory-use notice is not the supported KLT Image notice."
        }
    }
}

public enum TransformRecipeValidator {
    public static let exploratoryUseNotice = "Color differences are amplified for inspection. The result is not, by itself, a scientific measurement."
    public static let d65ReferenceWhite = SIMD3<Double>(0.95047, 1, 1.08883)

    @discardableResult
    public static func validate(
        _ recipe: TransformRecipeSnapshot,
        libraryName: String? = nil
    ) throws -> TransformRecipeSnapshot {
        guard recipe.recipeFormatVersion == 1,
              recipe.algorithm == .decorrelationStretchV1 else {
            throw TransformRecipeValidationIssue.unsupportedVersion
        }
        if let libraryName {
            let trimmed = libraryName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, trimmed.unicodeScalars.count <= 80,
                  !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
                throw TransformRecipeValidationIssue.invalidName
            }
        }
        do {
            _ = try WorkingSpaceValidator.validate(recipe.workingSpace)
        } catch {
            throw TransformRecipeValidationIssue.invalidWorkingSpace
        }
        let originPixelCount = recipe.originSource.width.multipliedReportingOverflow(
            by: recipe.originSource.height
        )
        let originFilename = recipe.originSource.displayFilename
        guard recipe.originSource.width > 0, recipe.originSource.height > 0,
              !originPixelCount.overflow,
              originPixelCount.partialValue <= ImageProcessingLimits.maximumPixelCount,
              recipe.originSource.analysisPixelFormat == AnalysisSourceDescriptor.pixelFormat,
              validDisplayString(recipe.workingSpaceNameAtCapture, maximum: 80),
              validOriginFilename(originFilename) else {
            throw TransformRecipeValidationIssue.invalidOrigin
        }
        guard recipe.originatingAnalysis.samplePixelCount > 0,
              recipe.originatingAnalysis.samplePixelCount <= originPixelCount.partialValue else {
            throw TransformRecipeValidationIssue.invalidOriginatingAnalysis
        }
        switch recipe.originatingAnalysis.samplingMode {
        case .wholeImage:
            guard recipe.originatingAnalysis.region == nil else {
                throw TransformRecipeValidationIssue.invalidOriginatingAnalysis
            }
        case .selectedRegion:
            guard let region = recipe.originatingAnalysis.region else {
                throw TransformRecipeValidationIssue.invalidOriginatingAnalysis
            }
            do {
                let validated = try SourcePixelRegionValidator.validate(
                    region.sourcePixels,
                    sourceWidth: recipe.originSource.width,
                    sourceHeight: recipe.originSource.height
                )
                let bounds = validated.bounds
                let area = bounds.width.multipliedReportingOverflow(by: bounds.height)
                guard !area.overflow,
                      recipe.originatingAnalysis.samplePixelCount <= area.partialValue,
                      normalizedRegionMatches(
                        region.normalized,
                        bounds: bounds,
                        sourceWidth: recipe.originSource.width,
                        sourceHeight: recipe.originSource.height
                      ) else {
                    throw TransformRecipeValidationIssue.invalidOriginatingAnalysis
                }
            } catch let issue as TransformRecipeValidationIssue {
                throw issue
            } catch {
                throw TransformRecipeValidationIssue.invalidOriginatingAnalysis
            }
        }
        let center = [recipe.workingCenter.x, recipe.workingCenter.y, recipe.workingCenter.z]
        guard center.allSatisfy(\.isFinite), recipe.transform.isFinite else {
            throw TransformRecipeValidationIssue.nonFiniteValue
        }
        guard center.allSatisfy({ abs($0) <= 100_000 }) else {
            throw TransformRecipeValidationIssue.centerOutOfBounds
        }
        guard recipe.transform.maximumAbsoluteElement <= 2_048 else {
            throw TransformRecipeValidationIssue.transformOutOfBounds
        }
        switch recipe.outputMapping {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, clips):
            let values = [minimum, maximum, scale]
            let range = maximum - minimum
            guard values.allSatisfy(\.isFinite), values.allSatisfy({ abs($0) <= 1_000_000_000 }),
                  clips, range > 1e-12, scale > 0 else {
                throw TransformRecipeValidationIssue.invalidOutputMapping
            }
            let expected = 1 / range
            guard abs(scale - expected) <= 1e-12 * max(1, abs(expected)) else {
                throw TransformRecipeValidationIssue.invalidOutputMapping
            }
            guard recipe.workingSpace.outputBehavior == .encodedSRGBGlobalRangeV1 else {
                throw TransformRecipeValidationIssue.invalidOutputMapping
            }
        case let .cieLabD65ToClippedSRGBV1(referenceWhite, clips):
            guard referenceWhite == d65ReferenceWhite, clips,
                  recipe.workingSpace.outputBehavior == .cieLabD65ToClippedSRGBV1 else {
                throw TransformRecipeValidationIssue.invalidOutputMapping
            }
        }
        guard recipe.exploratoryUseNotice == exploratoryUseNotice else {
            throw TransformRecipeValidationIssue.invalidNotice
        }
        return recipe
    }

    private static func validDisplayString(_ value: String, maximum: Int) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let scalars = trimmed.unicodeScalars
        return (1...maximum).contains(scalars.count)
            && !scalars.contains { $0.value == 0 || CharacterSet.controlCharacters.contains($0) }
    }

    private static func validOriginFilename(_ value: String) -> Bool {
        validDisplayString(value, maximum: 255) && !value.contains("/")
    }

    private static func normalizedRegionMatches(
        _ normalized: NormalizedAnalysisRegion,
        bounds: SourcePixelRegion,
        sourceWidth: Int,
        sourceHeight: Int
    ) -> Bool {
        let expected = [
            Double(bounds.x) / Double(sourceWidth),
            Double(bounds.y) / Double(sourceHeight),
            Double(bounds.width) / Double(sourceWidth),
            Double(bounds.height) / Double(sourceHeight)
        ]
        let actual = [normalized.x, normalized.y, normalized.width, normalized.height]
        return zip(actual, expected).allSatisfy { abs($0 - $1) <= 1e-12 }
    }
}

public struct ReplayDiagnostics: Equatable, Sendable {
    public let sameAsOrigin: Bool
    public let evaluatedPixelCount: Int
    public let clippedColorPixelCount: Int
    public let clippedFraction: Double
    public let minimumMappedComponent: Double?
    public let maximumMappedComponent: Double?
    public let mappedRange: Double?

    public init(
        sameAsOrigin: Bool,
        evaluatedPixelCount: Int,
        clippedColorPixelCount: Int,
        clippedFraction: Double,
        minimumMappedComponent: Double?,
        maximumMappedComponent: Double?,
        mappedRange: Double?
    ) {
        self.sameAsOrigin = sameAsOrigin
        self.evaluatedPixelCount = evaluatedPixelCount
        self.clippedColorPixelCount = clippedColorPixelCount
        self.clippedFraction = clippedFraction
        self.minimumMappedComponent = minimumMappedComponent
        self.maximumMappedComponent = maximumMappedComponent
        self.mappedRange = mappedRange
    }

    public var hasSubstantialClipping: Bool { clippedFraction >= 0.01 }
    public var hasLowContrast: Bool { mappedRange.map { $0 < 0.05 } ?? false }
}

public enum AppliedMethodSnapshot: Equatable, Sendable {
    case calculated(workingSpace: WorkingSpaceRevision, workingSpaceName: String)
    case replayed(recipe: TransformRecipeSnapshot, recipeName: String, diagnostics: ReplayDiagnostics)

    public var executionMode: String {
        switch self {
        case .calculated: "calculated"
        case .replayed: "replayed"
        }
    }
}

public enum TransformRecipeCaptureError: Error, Equatable, LocalizedError, Sendable {
    case unavailable

    public var errorDescription: String? {
        "Only a current calculated result with full stable variation can be saved as a transform."
    }
}

public enum TransformRecipeFactory {
    public static func capture(
        decodedSource: DecodedImage,
        displayFilename: String,
        enhancement: EnhancedImage,
        identifier: UUID = UUID()
    ) throws -> TransformRecipeSnapshot {
        guard !enhancement.descriptor.hasLimitedVariation,
              !enhancement.analysis.isDegenerate,
              case let .calculated(workingSpace, workingSpaceName)? = enhancement.appliedMethod else {
            throw TransformRecipeCaptureError.unavailable
        }
        let input = enhancement.descriptor.input
        let region: AnalysisRegionRecord?
        if input.sampleSource == .selectedRegion {
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
        } else {
            region = nil
        }
        let origin = try AnalysisSourceDescriptor(
            displayFilename: displayFilename,
            width: decodedSource.width,
            height: decodedSource.height,
            fingerprint: decodedSource.analysisSourceFingerprint
        )
        let outputMapping: FrozenOutputMapping
        switch enhancement.analysis.outputMapping {
        case let .rgbGlobalRange(minimum, maximum, scale):
            outputMapping = .encodedSRGBGlobalRangeV1(
                minimum: minimum,
                maximum: maximum,
                scale: scale,
                clipsToUnitRange: true
            )
        case .labD65ToSRGB:
            outputMapping = .cieLabD65ToClippedSRGBV1(
                referenceWhite: TransformRecipeValidator.d65ReferenceWhite,
                clipsFiniteOutOfGamutValues: true
            )
        case .limitedVariationIdentity:
            throw TransformRecipeCaptureError.unavailable
        }
        let recipe = TransformRecipeSnapshot(
            identifier: identifier,
            workingSpace: workingSpace,
            workingSpaceNameAtCapture: workingSpaceName,
            originatingAnalysis: OriginatingAnalysis(
                matrixMode: input.method.matrixMode,
                samplingMode: input.sampleSource,
                region: region,
                samplePixelCount: enhancement.descriptor.samplePixelCount
            ),
            originSource: origin,
            workingCenter: enhancement.analysis.mean,
            transform: enhancement.analysis.transform,
            outputMapping: outputMapping
        )
        return try TransformRecipeValidator.validate(recipe)
    }
}

public struct CalculatedAnalysisRequest: Equatable, Hashable, Sendable {
    public let workingSpace: WorkingSpaceSelection
    public let matrixMode: AnalysisMatrixMode
    public let sampleSource: AnalysisSampleSource
    public let region: SourcePixelRegion?

    public init(
        workingSpace: WorkingSpaceSelection,
        matrixMode: AnalysisMatrixMode,
        sampleSource: AnalysisSampleSource,
        region: SourcePixelRegion?
    ) {
        self.workingSpace = workingSpace
        self.matrixMode = matrixMode
        self.sampleSource = sampleSource
        self.region = region
    }

    public init(_ input: AnalysisInput) {
        workingSpace = input.method.colorSpace == .rgb ? .standardRGB : .standardLabD65
        matrixMode = input.method.matrixMode
        sampleSource = input.sampleSource
        region = input.region
    }

    public var compatibilityInput: AnalysisInput? {
        guard let colorSpace = workingSpace.compatibilityColorSpace else { return nil }
        return AnalysisInput(
            method: AnalysisMethod(colorSpace: colorSpace, matrixMode: matrixMode),
            sampleSource: sampleSource,
            region: region
        )
    }
}

public enum EnhancementExecutionRequest: Equatable, Hashable, Sendable {
    case calculated(CalculatedAnalysisRequest)
    case replayed(TransformRecipeSnapshot)
}
