import CoreGraphics
import Foundation

public enum AnalysisColorSpace: String, CaseIterable, Identifiable, Sendable {
    case rgb
    case lab

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .rgb: "RGB"
        case .lab: "Lab"
        }
    }
}

public enum AnalysisMatrixMode: String, CaseIterable, Identifiable, Sendable {
    case covariance
    case correlation

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .covariance: "Covariance"
        case .correlation: "Correlation"
        }
    }
}

public enum AnalysisSampleSource: String, CaseIterable, Identifiable, Sendable {
    case wholeImage
    case selectedRegion

    public var id: Self { self }

    public var displayName: String {
        switch self {
        case .wholeImage: "Whole image"
        case .selectedRegion: "Selected region"
        }
    }
}

public struct AnalysisMethod: Equatable, Hashable, Sendable {
    public var colorSpace: AnalysisColorSpace
    public var matrixMode: AnalysisMatrixMode

    public init(colorSpace: AnalysisColorSpace, matrixMode: AnalysisMatrixMode) {
        self.colorSpace = colorSpace
        self.matrixMode = matrixMode
    }

    public static let baseline = AnalysisMethod(colorSpace: .rgb, matrixMode: .covariance)
}

public struct SourcePixelRegion: Equatable, Hashable, Sendable {
    public var x: Int
    public var y: Int
    public var width: Int
    public var height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public enum RegionValidationIssue: Error, Equatable, Sendable {
    case missing
    case nonIntegerValues
    case nonPositiveSize
    case outsideSource(sourceWidth: Int, sourceHeight: Int)
    case fewerThanFourPixels
    case insufficientVariation(stableComponentCount: Int)

    public func message(sourceWidth: Int? = nil, sourceHeight: Int? = nil) -> String {
        switch self {
        case .missing:
            "A selected region is required. Draw on the source image or enter bounds; whole-image statistics will not be substituted."
        case .nonIntegerValues:
            "Enter a whole source-pixel value in every field. Values are kept for correction."
        case .nonPositiveSize:
            "Width and height must both be positive. Values are kept for correction."
        case let .outsideSource(width, height):
            "These bounds extend outside the \(width) × \(height) source. Values are kept for correction."
        case .fewerThanFourPixels:
            "The region must contain at least four source pixels. Values are kept for correction."
        case .insufficientVariation:
            "This region does not contain enough color variation for the selected method. Choose a more varied region."
        }
    }
}

extension RegionValidationIssue: LocalizedError {
    public var errorDescription: String? { message() }
}

public struct ValidatedSourcePixelRegion: Equatable, Hashable, Sendable {
    public let bounds: SourcePixelRegion
    public let pixelCount: Int

    init(bounds: SourcePixelRegion, pixelCount: Int) {
        self.bounds = bounds
        self.pixelCount = pixelCount
    }
}

public enum SourcePixelRegionValidator {
    public static func validate(
        _ region: SourcePixelRegion?,
        sourceWidth: Int,
        sourceHeight: Int
    ) throws -> ValidatedSourcePixelRegion {
        guard let region else { throw RegionValidationIssue.missing }
        guard region.width > 0, region.height > 0 else {
            throw RegionValidationIssue.nonPositiveSize
        }
        guard region.x >= 0, region.y >= 0 else {
            throw RegionValidationIssue.outsideSource(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight
            )
        }

        let (maximumX, xOverflow) = region.x.addingReportingOverflow(region.width)
        let (maximumY, yOverflow) = region.y.addingReportingOverflow(region.height)
        guard !xOverflow, !yOverflow, maximumX <= sourceWidth, maximumY <= sourceHeight else {
            throw RegionValidationIssue.outsideSource(
                sourceWidth: sourceWidth,
                sourceHeight: sourceHeight
            )
        }

        let (pixelCount, countOverflow) = region.width.multipliedReportingOverflow(by: region.height)
        guard !countOverflow, pixelCount >= 4 else {
            throw RegionValidationIssue.fewerThanFourPixels
        }
        return ValidatedSourcePixelRegion(bounds: region, pixelCount: pixelCount)
    }
}

public struct AnalysisInput: Equatable, Hashable, Sendable {
    public var method: AnalysisMethod
    public var sampleSource: AnalysisSampleSource
    public var region: SourcePixelRegion?

    public init(
        method: AnalysisMethod,
        sampleSource: AnalysisSampleSource,
        region: SourcePixelRegion?
    ) {
        self.method = method
        self.sampleSource = sampleSource
        self.region = region
    }

    public static let baseline = AnalysisInput(
        method: .baseline,
        sampleSource: .wholeImage,
        region: nil
    )
}

public struct AnalysisDescriptor: Equatable, Hashable, Sendable {
    public let input: AnalysisInput
    public let samplePixelCount: Int
    public let stableVariableCount: Int
    public let stableComponentCount: Int
    public let hasLimitedVariation: Bool

    public init(
        input: AnalysisInput,
        samplePixelCount: Int,
        stableVariableCount: Int,
        stableComponentCount: Int,
        hasLimitedVariation: Bool
    ) {
        self.input = input
        self.samplePixelCount = samplePixelCount
        self.stableVariableCount = stableVariableCount
        self.stableComponentCount = stableComponentCount
        self.hasLimitedVariation = hasLimitedVariation
    }
}

public enum RequestAcceptanceGate {
    public static func accepts<JobID: Equatable, Key: Equatable>(
        completedJobID: JobID,
        completedKey: Key,
        activeJobID: JobID?,
        currentKey: Key?
    ) -> Bool {
        completedJobID == activeJobID && completedKey == currentKey
    }
}

public enum ColorConversionError: Error, LocalizedError, Equatable {
    case nonFiniteColor

    public var errorDescription: String? {
        "The selected color conversion produced an invalid value. Try another method or source image."
    }
}

public enum CIELabD65 {
    private static let referenceWhite = SIMD3<Double>(0.95047, 1, 1.08883)
    private static let delta = 6.0 / 29.0
    private static let deltaCubed = delta * delta * delta
    private static let linearSlope = 1 / (3 * delta * delta)
    private static let decodedPremultipliedSRGB: [Double] = {
        var table = [Double](repeating: 0, count: 256 * 256)
        for alpha in 1...255 {
            let base = alpha << 8
            let inverseAlpha = 1 / Double(alpha)
            for component in 0...255 {
                table[base + component] = decodeSRGB(
                    min(1, Double(component) * inverseAlpha)
                )
            }
        }
        return table
    }()

    public static func fromSRGB(_ rgb: SIMD3<Double>) throws -> SIMD3<Double> {
        guard rgb.x.isFinite, rgb.y.isFinite, rgb.z.isFinite else {
            throw ColorConversionError.nonFiniteColor
        }
        let linear = SIMD3(
            decodeSRGB(rgb.x),
            decodeSRGB(rgb.y),
            decodeSRGB(rgb.z)
        )
        return try fromLinearSRGB(linear)
    }

    @inline(__always)
    static func fromPremultipliedSRGB(
        bytes: UnsafeBufferPointer<UInt8>,
        offset: Int
    ) throws -> SIMD3<Double> {
        let base = Int(bytes[offset + 3]) << 8
        let table = decodedPremultipliedSRGB
        return try fromLinearSRGB(
            SIMD3(
                table[base + Int(bytes[offset])],
                table[base + Int(bytes[offset + 1])],
                table[base + Int(bytes[offset + 2])]
            )
        )
    }

    @inline(__always)
    private static func fromLinearSRGB(_ linear: SIMD3<Double>) throws -> SIMD3<Double> {
        let xyz = SIMD3(
            (0.4124564 * linear.x) + (0.3575761 * linear.y) + (0.1804375 * linear.z),
            (0.2126729 * linear.x) + (0.7151522 * linear.y) + (0.0721750 * linear.z),
            (0.0193339 * linear.x) + (0.1191920 * linear.y) + (0.9503041 * linear.z)
        )
        let scaled = xyz / referenceWhite
        let fx = labForward(scaled.x)
        let fy = labForward(scaled.y)
        let fz = labForward(scaled.z)
        let lab = SIMD3(
            (116 * fy) - 16,
            500 * (fx - fy),
            200 * (fy - fz)
        )
        guard lab.x.isFinite, lab.y.isFinite, lab.z.isFinite else {
            throw ColorConversionError.nonFiniteColor
        }
        return lab
    }

    public static func toSRGB(_ lab: SIMD3<Double>) throws -> SIMD3<Double> {
        guard lab.x.isFinite, lab.y.isFinite, lab.z.isFinite else {
            throw ColorConversionError.nonFiniteColor
        }
        let fy = (lab.x + 16) / 116
        let fx = fy + (lab.y / 500)
        let fz = fy - (lab.z / 200)
        let xyz = SIMD3(
            referenceWhite.x * labInverse(fx),
            referenceWhite.y * labInverse(fy),
            referenceWhite.z * labInverse(fz)
        )
        let linear = SIMD3(
            (3.2404542 * xyz.x) - (1.5371385 * xyz.y) - (0.4985314 * xyz.z),
            (-0.9692660 * xyz.x) + (1.8760108 * xyz.y) + (0.0415560 * xyz.z),
            (0.0556434 * xyz.x) - (0.2040259 * xyz.y) + (1.0572252 * xyz.z)
        )
        let rgb = SIMD3(
            encodeSRGB(linear.x),
            encodeSRGB(linear.y),
            encodeSRGB(linear.z)
        )
        guard rgb.x.isFinite, rgb.y.isFinite, rgb.z.isFinite else {
            throw ColorConversionError.nonFiniteColor
        }
        return rgb
    }

    public static func toClippedSRGB(_ lab: SIMD3<Double>) throws -> SIMD3<Double> {
        let rgb = try toSRGB(lab)
        return SIMD3(rgb.x.clampedToUnit, rgb.y.clampedToUnit, rgb.z.clampedToUnit)
    }

    @inline(__always)
    private static func decodeSRGB(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    @inline(__always)
    private static func encodeSRGB(_ value: Double) -> Double {
        value <= 0.0031308 ? 12.92 * value : (1.055 * pow(value, 1 / 2.4)) - 0.055
    }

    @inline(__always)
    private static func labForward(_ value: Double) -> Double {
        value > deltaCubed ? cbrt(value) : (linearSlope * value) + (4 / 29)
    }

    @inline(__always)
    private static func labInverse(_ value: Double) -> Double {
        value > delta ? value * value * value : 3 * delta * delta * (value - (4 / 29))
    }
}

public struct ImageViewportTransform: @unchecked Sendable {
    public let sourceSize: CGSize
    public let paneSize: CGSize
    public let contentInset: CGFloat
    public let zoom: Double
    public let pan: CGSize

    public init(
        sourceSize: CGSize,
        paneSize: CGSize,
        contentInset: CGFloat = 24,
        zoom: Double,
        pan: CGSize
    ) {
        self.sourceSize = sourceSize
        self.paneSize = paneSize
        self.contentInset = contentInset
        self.zoom = zoom
        self.pan = pan
    }

    public var scale: CGFloat {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return 0 }
        let availableWidth = max(1, paneSize.width - (contentInset * 2))
        let availableHeight = max(1, paneSize.height - (contentInset * 2))
        let fit = min(availableWidth / sourceSize.width, availableHeight / sourceSize.height)
        return fit * CGFloat(zoom)
    }

    public var imageRect: CGRect {
        let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return CGRect(
            x: ((paneSize.width - size.width) / 2) + pan.width,
            y: ((paneSize.height - size.height) / 2) + pan.height,
            width: size.width,
            height: size.height
        )
    }

    public func sourceToView(_ region: SourcePixelRegion) -> CGRect {
        CGRect(
            x: imageRect.minX + (CGFloat(region.x) * scale),
            y: imageRect.minY + (CGFloat(region.y) * scale),
            width: CGFloat(region.width) * scale,
            height: CGFloat(region.height) * scale
        )
    }

    public func viewToSource(_ point: CGPoint, constrained: Bool = false) -> CGPoint {
        guard scale > 0 else { return .zero }
        let sourcePoint = CGPoint(
            x: (point.x - imageRect.minX) / scale,
            y: (point.y - imageRect.minY) / scale
        )
        guard constrained else { return sourcePoint }
        return CGPoint(
            x: min(sourceSize.width, max(0, sourcePoint.x)),
            y: min(sourceSize.height, max(0, sourcePoint.y))
        )
    }

    public func constrainedRegion(from start: CGPoint, to end: CGPoint) -> SourcePixelRegion {
        let first = viewToSource(start, constrained: true)
        let second = viewToSource(end, constrained: true)
        let lesserX = snappedFloor(min(first.x, second.x))
        let lesserY = snappedFloor(min(first.y, second.y))
        let greaterX = snappedCeil(max(first.x, second.x))
        let greaterY = snappedCeil(max(first.y, second.y))
        return SourcePixelRegion(
            x: lesserX,
            y: lesserY,
            width: greaterX - lesserX,
            height: greaterY - lesserY
        )
    }

    private func snappedFloor(_ value: CGFloat) -> Int {
        let nearest = value.rounded()
        return Int(abs(value - nearest) < 1e-9 ? nearest : floor(value))
    }

    private func snappedCeil(_ value: CGFloat) -> Int {
        let nearest = value.rounded()
        return Int(abs(value - nearest) < 1e-9 ? nearest : ceil(value))
    }
}
