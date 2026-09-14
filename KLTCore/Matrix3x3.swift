import Foundation

public struct Matrix3x3: Equatable, Hashable, Sendable {
    private var storage: [Double]

    public init(_ values: [Double]) {
        precondition(values.count == 9)
        storage = values
    }

    public init(checked values: [Double]) throws {
        guard values.count == 9 else {
            throw Matrix3x3Error.invalidValueCount(actual: values.count)
        }
        guard values.allSatisfy(\.isFinite) else { throw Matrix3x3Error.nonFiniteValue }
        storage = values
    }

    public init(repeating value: Double = 0) {
        storage = Array(repeating: value, count: 9)
    }

    public static let identity = Matrix3x3([
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    ])

    public subscript(row: Int, column: Int) -> Double {
        get { storage[(row * 3) + column] }
        set { storage[(row * 3) + column] = newValue }
    }

    public var rowMajorValues: [Double] { storage }

    public var transposed: Matrix3x3 {
        var result = Matrix3x3()
        for row in 0..<3 {
            for column in 0..<3 {
                result[row, column] = self[column, row]
            }
        }
        return result
    }

    public static func diagonal(_ values: SIMD3<Double>) -> Matrix3x3 {
        Matrix3x3([
            values.x, 0, 0,
            0, values.y, 0,
            0, 0, values.z
        ])
    }

    public static func * (lhs: Matrix3x3, rhs: SIMD3<Double>) -> SIMD3<Double> {
        SIMD3(
            (lhs[0, 0] * rhs.x) + (lhs[0, 1] * rhs.y) + (lhs[0, 2] * rhs.z),
            (lhs[1, 0] * rhs.x) + (lhs[1, 1] * rhs.y) + (lhs[1, 2] * rhs.z),
            (lhs[2, 0] * rhs.x) + (lhs[2, 1] * rhs.y) + (lhs[2, 2] * rhs.z)
        )
    }

    public static func * (lhs: Matrix3x3, rhs: Matrix3x3) -> Matrix3x3 {
        var result = Matrix3x3()
        for row in 0..<3 {
            for column in 0..<3 {
                var value = 0.0
                for index in 0..<3 {
                    value += lhs[row, index] * rhs[index, column]
                }
                result[row, column] = value
            }
        }
        return result
    }

    mutating func addOuterProduct(_ lhs: SIMD3<Double>, _ rhs: SIMD3<Double>) {
        for row in 0..<3 {
            for column in 0..<3 {
                self[row, column] += lhs[row] * rhs[column]
            }
        }
    }

    func divided(by divisor: Double) -> Matrix3x3 {
        var result = self
        for row in 0..<3 {
            for column in 0..<3 {
                result[row, column] /= divisor
            }
        }
        return result
    }

    public var isFinite: Bool {
        storage.allSatisfy(\.isFinite)
    }

    public var determinant: Double {
        let a = self[0, 0], b = self[0, 1], c = self[0, 2]
        let d = self[1, 0], e = self[1, 1], f = self[1, 2]
        let g = self[2, 0], h = self[2, 1], i = self[2, 2]
        return (a * ((e * i) - (f * h)))
            - (b * ((d * i) - (f * g)))
            + (c * ((d * h) - (e * g)))
    }

    public var maximumAbsoluteElement: Double {
        storage.reduce(0) { max($0, abs($1)) }
    }

    public var infinityNorm: Double {
        (0..<3).reduce(0) { result, row in
            max(result, abs(self[row, 0]) + abs(self[row, 1]) + abs(self[row, 2]))
        }
    }

    public func scaled(by divisor: Double) -> Matrix3x3 {
        Matrix3x3(storage.map { $0 / divisor })
    }

    public func inverted() throws -> Matrix3x3 {
        let det = determinant
        guard det.isFinite, det != 0 else { throw Matrix3x3Error.singular }
        let a = self[0, 0], b = self[0, 1], c = self[0, 2]
        let d = self[1, 0], e = self[1, 1], f = self[1, 2]
        let g = self[2, 0], h = self[2, 1], i = self[2, 2]
        let inverse = Matrix3x3([
            ((e * i) - (f * h)) / det,
            ((c * h) - (b * i)) / det,
            ((b * f) - (c * e)) / det,
            ((f * g) - (d * i)) / det,
            ((a * i) - (c * g)) / det,
            ((c * d) - (a * f)) / det,
            ((d * h) - (e * g)) / det,
            ((b * g) - (a * h)) / det,
            ((a * e) - (b * d)) / det
        ])
        guard inverse.isFinite else { throw Matrix3x3Error.nonFiniteValue }
        return inverse
    }

    public func maximumAbsoluteDifference(from other: Matrix3x3) -> Double {
        zip(storage, other.storage).reduce(0) { max($0, abs($1.0 - $1.1)) }
    }
}

public enum Matrix3x3Error: Error, Equatable, LocalizedError, Sendable {
    case invalidValueCount(actual: Int)
    case nonFiniteValue
    case singular

    public var errorDescription: String? {
        switch self {
        case let .invalidValueCount(actual): "A 3 by 3 matrix requires exactly 9 values; received \(actual)."
        case .nonFiniteValue: "Every matrix value must be finite."
        case .singular: "The matrix is singular."
        }
    }
}

public struct EigenDecomposition3x3: Sendable {
    public let values: SIMD3<Double>
    public let vectors: Matrix3x3
}

extension Matrix3x3 {
    public func symmetricEigenDecomposition() -> EigenDecomposition3x3 {
        var matrix = self
        var vectors = Matrix3x3.identity
        let diagonalScale = max(
            abs(matrix[0, 0]),
            abs(matrix[1, 1]),
            abs(matrix[2, 2]),
            1
        )
        let tolerance = diagonalScale * 1e-14

        for _ in 0..<64 {
            var p = 0
            var q = 1
            var largest = abs(matrix[0, 1])

            for candidate in [(0, 2), (1, 2)] {
                let magnitude = abs(matrix[candidate.0, candidate.1])
                if magnitude > largest {
                    largest = magnitude
                    p = candidate.0
                    q = candidate.1
                }
            }

            if largest <= tolerance {
                break
            }

            let app = matrix[p, p]
            let aqq = matrix[q, q]
            let apq = matrix[p, q]
            let angle = 0.5 * atan2(2 * apq, aqq - app)
            let cosine = cos(angle)
            let sine = sin(angle)

            for index in 0..<3 where index != p && index != q {
                let aip = matrix[index, p]
                let aiq = matrix[index, q]
                let rotatedP = (cosine * aip) - (sine * aiq)
                let rotatedQ = (sine * aip) + (cosine * aiq)
                matrix[index, p] = rotatedP
                matrix[p, index] = rotatedP
                matrix[index, q] = rotatedQ
                matrix[q, index] = rotatedQ
            }

            matrix[p, p] = (cosine * cosine * app) - (2 * sine * cosine * apq) + (sine * sine * aqq)
            matrix[q, q] = (sine * sine * app) + (2 * sine * cosine * apq) + (cosine * cosine * aqq)
            matrix[p, q] = 0
            matrix[q, p] = 0

            for row in 0..<3 {
                let vip = vectors[row, p]
                let viq = vectors[row, q]
                vectors[row, p] = (cosine * vip) - (sine * viq)
                vectors[row, q] = (sine * vip) + (cosine * viq)
            }
        }

        let rawValues = [matrix[0, 0], matrix[1, 1], matrix[2, 2]]
        let order = [0, 1, 2].sorted {
            if rawValues[$0] == rawValues[$1] { return $0 < $1 }
            return rawValues[$0] > rawValues[$1]
        }

        var sortedVectors = Matrix3x3()
        var sortedValues = SIMD3<Double>(repeating: 0)

        for newColumn in 0..<3 {
            let oldColumn = order[newColumn]
            sortedValues[newColumn] = max(0, rawValues[oldColumn])

            var dominantRow = 0
            for row in 1..<3 where abs(vectors[row, oldColumn]) > abs(vectors[dominantRow, oldColumn]) {
                dominantRow = row
            }
            let sign = vectors[dominantRow, oldColumn] < 0 ? -1.0 : 1.0
            for row in 0..<3 {
                sortedVectors[row, newColumn] = vectors[row, oldColumn] * sign
            }
        }

        return EigenDecomposition3x3(values: sortedValues, vectors: sortedVectors)
    }
}
