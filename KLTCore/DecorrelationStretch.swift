import Foundation

public struct RGBAPixel: Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    var rgb: SIMD3<Double> {
        SIMD3(red, green, blue)
    }
}

public struct StretchAnalysis: Sendable {
    public let mean: SIMD3<Double>
    public let covariance: Matrix3x3
    public let analysisMatrix: Matrix3x3
    public let eigenvalues: SIMD3<Double>
    public let eigenvectors: Matrix3x3
    public let transform: Matrix3x3
    public let stableVariableCount: Int
    public let stableComponentCount: Int
    public let outputScale: Double
    public let outputMapping: StretchOutputMapping
    public let isDegenerate: Bool
}

public enum StretchOutputMapping: Equatable, Sendable {
    case rgbGlobalRange(minimum: Double, maximum: Double, scale: Double)
    case labD65ToSRGB
    case limitedVariationIdentity
}

public struct StretchResult: Sendable {
    public let pixels: [RGBAPixel]
    public let analysis: StretchAnalysis
    public let notice: String?
}

public enum DecorrelationStretchError: Error, LocalizedError, Equatable {
    case notEnoughPixels
    case nonFiniteInput

    public var errorDescription: String? {
        switch self {
        case .notEnoughPixels:
            "The image does not contain enough pixels to calculate color variation."
        case .nonFiniteInput:
            "The image contains invalid color values."
        }
    }
}

struct RunningCovariance3: Sendable {
    private(set) var count = 0
    private(set) var mean = SIMD3<Double>(repeating: 0)
    private var moment = Matrix3x3()

    mutating func add(_ value: SIMD3<Double>) throws {
        guard value.x.isFinite, value.y.isFinite, value.z.isFinite else {
            throw DecorrelationStretchError.nonFiniteInput
        }

        count += 1
        let delta = value - mean
        mean += delta / Double(count)
        let updatedDelta = value - mean
        moment[0, 0] += delta.x * updatedDelta.x
        moment[0, 1] += delta.x * updatedDelta.y
        moment[0, 2] += delta.x * updatedDelta.z
        moment[1, 0] += delta.y * updatedDelta.x
        moment[1, 1] += delta.y * updatedDelta.y
        moment[1, 2] += delta.y * updatedDelta.z
        moment[2, 0] += delta.z * updatedDelta.x
        moment[2, 1] += delta.z * updatedDelta.y
        moment[2, 2] += delta.z * updatedDelta.z
    }

    func covariance() throws -> Matrix3x3 {
        guard count >= 2 else {
            throw DecorrelationStretchError.notEnoughPixels
        }
        return moment.divided(by: Double(count - 1))
    }
}

struct StretchPlan: Sendable {
    let mean: SIMD3<Double>
    let covariance: Matrix3x3
    let analysisMatrix: Matrix3x3
    let eigenvalues: SIMD3<Double>
    let eigenvectors: Matrix3x3
    let transform: Matrix3x3
    let stableVariableCount: Int
    let stableComponentCount: Int
    let isDegenerate: Bool

    @inline(__always)
    func transformed(_ value: SIMD3<Double>) -> SIMD3<Double> {
        mean + (transform * (value - mean))
    }
}

public enum DecorrelationStretch {
    static let absoluteVarianceFloor = 1e-12
    static let maximumStableGain = 32.0

    public static func process(
        _ pixels: [RGBAPixel],
        cancellationCheck: @Sendable () throws -> Void = {}
    ) throws -> StretchResult {
        guard !pixels.isEmpty else {
            throw DecorrelationStretchError.notEnoughPixels
        }

        var accumulator = RunningCovariance3()
        for (index, pixel) in pixels.enumerated() {
            if index.isMultiple(of: 16_384) {
                try cancellationCheck()
            }
            try accumulator.add(pixel.rgb)
        }

        let plan = try makePlan(accumulator: accumulator)
        if plan.isDegenerate {
            let analysis = makeAnalysis(plan: plan, outputMapping: .limitedVariationIdentity)
            return StretchResult(
                pixels: pixels,
                analysis: analysis,
                notice: "Not enough color variation to enhance this image."
            )
        }

        var minimum = Double.infinity
        var maximum = -Double.infinity
        var transformed = [SIMD3<Double>]()
        transformed.reserveCapacity(pixels.count)

        for (index, pixel) in pixels.enumerated() {
            if index.isMultiple(of: 16_384) {
                try cancellationCheck()
            }
            let value = plan.transformed(pixel.rgb)
            transformed.append(value)
            minimum = min(minimum, value.x, value.y, value.z)
            maximum = max(maximum, value.x, value.y, value.z)
        }

        let range = maximum - minimum
        let outputScale = range > absoluteVarianceFloor ? 1 / range : 1
        let outputPixels = try zip(pixels, transformed).enumerated().map { index, pair in
            if index.isMultiple(of: 16_384) {
                try cancellationCheck()
            }
            let (original, value) = pair
            guard range > absoluteVarianceFloor else { return original }
            return RGBAPixel(
                red: ((value.x - minimum) * outputScale).clampedToUnit,
                green: ((value.y - minimum) * outputScale).clampedToUnit,
                blue: ((value.z - minimum) * outputScale).clampedToUnit,
                alpha: original.alpha
            )
        }

        return StretchResult(
            pixels: outputPixels,
            analysis: makeAnalysis(
                plan: plan,
                outputMapping: .rgbGlobalRange(
                    minimum: minimum,
                    maximum: maximum,
                    scale: outputScale
                )
            ),
            notice: nil
        )
    }

    static func makePlan(accumulator: RunningCovariance3) throws -> StretchPlan {
        try makeCovariancePlan(accumulator: accumulator)
    }

    static func makePlan(
        accumulator: RunningCovariance3,
        matrixMode: AnalysisMatrixMode
    ) throws -> StretchPlan {
        switch matrixMode {
        case .covariance:
            try makeCovariancePlan(accumulator: accumulator)
        case .correlation:
            try makeCorrelationPlan(accumulator: accumulator)
        }
    }

    private static func makeCovariancePlan(accumulator: RunningCovariance3) throws -> StretchPlan {
        guard accumulator.count >= 2 else {
            return StretchPlan(
                mean: accumulator.mean,
                covariance: Matrix3x3(),
                analysisMatrix: Matrix3x3(),
                eigenvalues: .zero,
                eigenvectors: .identity,
                transform: .identity,
                stableVariableCount: 0,
                stableComponentCount: 0,
                isDegenerate: true
            )
        }

        let covariance = try accumulator.covariance()
        guard covariance.isFinite else { throw DecorrelationStretchError.nonFiniteInput }
        let decomposition = covariance.symmetricEigenDecomposition()
        let largest = decomposition.values.x

        let largestVariableVariance = max(covariance[0, 0], covariance[1, 1], covariance[2, 2])
        let variableFloor = max(
            absoluteVarianceFloor,
            largestVariableVariance / (maximumStableGain * maximumStableGain)
        )
        let stableVariableCount = (0..<3).count { covariance[$0, $0] >= variableFloor }

        guard largest > absoluteVarianceFloor else {
            return StretchPlan(
                mean: accumulator.mean,
                covariance: covariance,
                analysisMatrix: covariance,
                eigenvalues: decomposition.values,
                eigenvectors: decomposition.vectors,
                transform: .identity,
                stableVariableCount: 0,
                stableComponentCount: 0,
                isDegenerate: true
            )
        }

        let stabilityFloor = max(absoluteVarianceFloor, largest / (maximumStableGain * maximumStableGain))
        let targetDeviation = sqrt(largest)
        var gains = SIMD3<Double>(repeating: 1)
        var stableComponentCount = 0

        for index in 0..<3 {
            let variance = decomposition.values[index]
            guard variance >= stabilityFloor else { continue }
            gains[index] = targetDeviation / sqrt(variance)
            stableComponentCount += 1
        }

        let transform = decomposition.vectors
            * Matrix3x3.diagonal(gains)
            * decomposition.vectors.transposed

        return StretchPlan(
            mean: accumulator.mean,
            covariance: covariance,
            analysisMatrix: covariance,
            eigenvalues: decomposition.values,
            eigenvectors: decomposition.vectors,
            transform: transform,
            stableVariableCount: stableVariableCount,
            stableComponentCount: stableComponentCount,
            isDegenerate: false
        )
    }

    private static func makeCorrelationPlan(accumulator: RunningCovariance3) throws -> StretchPlan {
        guard accumulator.count >= 2 else {
            return StretchPlan(
                mean: accumulator.mean,
                covariance: Matrix3x3(),
                analysisMatrix: Matrix3x3(),
                eigenvalues: .zero,
                eigenvectors: .identity,
                transform: .identity,
                stableVariableCount: 0,
                stableComponentCount: 0,
                isDegenerate: true
            )
        }

        let covariance = try accumulator.covariance()
        guard covariance.isFinite else { throw DecorrelationStretchError.nonFiniteInput }
        let largestVariance = max(covariance[0, 0], covariance[1, 1], covariance[2, 2])
        guard largestVariance > absoluteVarianceFloor else {
            return StretchPlan(
                mean: accumulator.mean,
                covariance: covariance,
                analysisMatrix: Matrix3x3(),
                eigenvalues: .zero,
                eigenvectors: .identity,
                transform: .identity,
                stableVariableCount: 0,
                stableComponentCount: 0,
                isDegenerate: true
            )
        }

        let variableFloor = max(
            absoluteVarianceFloor,
            largestVariance / (maximumStableGain * maximumStableGain)
        )
        var stable = [Bool](repeating: false, count: 3)
        var standardDeviations = SIMD3<Double>(repeating: 1)
        var stableVariableCount = 0
        for index in 0..<3 where covariance[index, index] >= variableFloor {
            stable[index] = true
            standardDeviations[index] = sqrt(covariance[index, index])
            stableVariableCount += 1
        }

        guard stableVariableCount > 0 else {
            return StretchPlan(
                mean: accumulator.mean,
                covariance: covariance,
                analysisMatrix: Matrix3x3(),
                eigenvalues: .zero,
                eigenvectors: .identity,
                transform: .identity,
                stableVariableCount: 0,
                stableComponentCount: 0,
                isDegenerate: true
            )
        }

        var correlation = Matrix3x3()
        for row in 0..<3 where stable[row] {
            correlation[row, row] = 1
            for column in 0..<3 where stable[column] && row != column {
                correlation[row, column] = covariance[row, column]
                    / (standardDeviations[row] * standardDeviations[column])
            }
        }
        guard correlation.isFinite else { throw DecorrelationStretchError.nonFiniteInput }

        let decomposition = correlation.symmetricEigenDecomposition()
        let largest = decomposition.values.x
        let componentFloor = max(
            absoluteVarianceFloor,
            largest / (maximumStableGain * maximumStableGain)
        )
        let targetDeviation = sqrt(largest)
        var gains = SIMD3<Double>(repeating: 1)
        var stableComponentCount = 0
        for index in 0..<3 {
            let variance = decomposition.values[index]
            guard variance >= componentFloor else { continue }
            gains[index] = targetDeviation / sqrt(variance)
            stableComponentCount += 1
        }

        let standardizedTransform = decomposition.vectors
            * Matrix3x3.diagonal(gains)
            * decomposition.vectors.transposed
        var transform = Matrix3x3.identity
        for row in 0..<3 where stable[row] {
            for column in 0..<3 {
                transform[row, column] = stable[column]
                    ? standardDeviations[row] * standardizedTransform[row, column] / standardDeviations[column]
                    : 0
            }
        }
        guard transform.isFinite else { throw DecorrelationStretchError.nonFiniteInput }

        return StretchPlan(
            mean: accumulator.mean,
            covariance: covariance,
            analysisMatrix: correlation,
            eigenvalues: decomposition.values,
            eigenvectors: decomposition.vectors,
            transform: transform,
            stableVariableCount: stableVariableCount,
            stableComponentCount: stableComponentCount,
            isDegenerate: false
        )
    }

    private static func makeAnalysis(
        plan: StretchPlan,
        outputMapping: StretchOutputMapping
    ) -> StretchAnalysis {
        let outputScale: Double
        switch outputMapping {
        case let .rgbGlobalRange(_, _, scale): outputScale = scale
        case .labD65ToSRGB, .limitedVariationIdentity: outputScale = 1
        }
        return StretchAnalysis(
            mean: plan.mean,
            covariance: plan.covariance,
            analysisMatrix: plan.analysisMatrix,
            eigenvalues: plan.eigenvalues,
            eigenvectors: plan.eigenvectors,
            transform: plan.transform,
            stableVariableCount: plan.stableVariableCount,
            stableComponentCount: plan.stableComponentCount,
            outputScale: outputScale,
            outputMapping: outputMapping,
            isDegenerate: plan.isDegenerate
        )
    }
}

extension Double {
    var clampedToUnit: Double {
        min(1, max(0, self))
    }
}
