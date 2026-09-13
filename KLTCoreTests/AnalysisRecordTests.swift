import CoreGraphics
import Foundation
import ImageIO
import KLTCore
import UniformTypeIdentifiers
import XCTest

final class AnalysisRecordTests: XCTestCase {
    func testDecodedSourceFingerprintIsStableAndPixelSensitive() throws {
        let first = try ImagePipeline.decode(fixtureData(width: 4, height: 3))
        let repeated = try ImagePipeline.decode(fixtureData(width: 4, height: 3))
        let changed = try ImagePipeline.decode(
            fixtureData(width: 4, height: 3) { x, y in
                if x == 2, y == 1 { return (251, 17, 89, 255) }
                return self.defaultPixel(x: x, y: y, width: 4)
            }
        )

        XCTAssertEqual(first.analysisSourceFingerprint.algorithm, "sha256")
        XCTAssertEqual(first.analysisSourceFingerprint.value.count, 64)
        XCTAssertEqual(first.analysisSourceFingerprint, repeated.analysisSourceFingerprint)
        XCTAssertNotEqual(first.analysisSourceFingerprint, changed.analysisSourceFingerprint)
        XCTAssertTrue(first.analysisSourceFingerprint.value.allSatisfy { $0.isHexDigit && !$0.isUppercase })
    }

    func testWholeImageRecordCapturesExactMathematicsAndRGBOutputMapping() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 8, height: 6))
        let enhancement = try ImagePipeline.enhance(source, input: .baseline)
        let record = try AnalysisRecord(
            decodedSource: source,
            displayFilename: "field-sample.tif",
            enhancement: enhancement
        )

        XCTAssertEqual(record.source.displayFilename, "field-sample.tif")
        XCTAssertEqual(record.source.width, 8)
        XCTAssertEqual(record.source.height, 6)
        XCTAssertEqual(record.source.analysisPixelFormat, "rgba8-premultiplied-srgb")
        XCTAssertEqual(record.source.fingerprint, source.analysisSourceFingerprint)
        XCTAssertEqual(record.input, .baseline)
        XCTAssertNil(record.region)
        XCTAssertEqual(record.conventions.channelOrder, ["red", "green", "blue"])
        XCTAssertEqual(record.conventions.channelUnits, Array(repeating: "encoded-srgb-[0,1]", count: 3))
        XCTAssertEqual(record.mathematics.samplePixelCount, source.pixelCount)
        XCTAssertEqual(record.mathematics.mean.values, vectorValues(enhancement.analysis.mean))
        XCTAssertEqual(record.mathematics.covariance.values, enhancement.analysis.covariance.rowMajorValues)
        XCTAssertEqual(record.mathematics.analysisMatrix.values, enhancement.analysis.analysisMatrix.rowMajorValues)
        XCTAssertEqual(record.mathematics.eigenvalues.values, vectorValues(enhancement.analysis.eigenvalues))
        XCTAssertEqual(record.mathematics.eigenvectors.values, enhancement.analysis.eigenvectors.rowMajorValues)
        XCTAssertEqual(record.mathematics.transform.values, enhancement.analysis.transform.rowMajorValues)

        guard case let .rgbGlobalRange(minimum, maximum, scale) = record.mathematics.outputMapping,
              case let .rgbGlobalRange(expectedMinimum, expectedMaximum, expectedScale) = enhancement.analysis.outputMapping
        else {
            return XCTFail("Expected the rendered RGB global-range mapping")
        }
        XCTAssertEqual(minimum, expectedMinimum)
        XCTAssertEqual(maximum, expectedMaximum)
        XCTAssertEqual(scale, expectedScale)
    }

    func testSelectedRegionRecordUsesResolvedHalfOpenBoundsAndNormalizedGeometry() throws {
        let source = try ImagePipeline.decode(fixtureData(width: 10, height: 8))
        let input = AnalysisInput(
            method: AnalysisMethod(colorSpace: .lab, matrixMode: .correlation),
            sampleSource: .selectedRegion,
            region: SourcePixelRegion(x: 2, y: 1, width: 5, height: 4)
        )
        let enhancement = try ImagePipeline.enhance(source, input: input)
        let record = try AnalysisRecord(
            decodedSource: source,
            displayFilename: "oriented-source.png",
            enhancement: enhancement
        )

        XCTAssertEqual(record.region?.sourcePixels, input.region)
        XCTAssertEqual(record.region?.normalized.x, 0.2)
        XCTAssertEqual(record.region?.normalized.y, 0.125)
        XCTAssertEqual(record.region?.normalized.width, 0.5)
        XCTAssertEqual(record.region?.normalized.height, 0.5)
        XCTAssertEqual(record.mathematics.samplePixelCount, 20)
        XCTAssertEqual(record.conventions.channelOrder, ["L*", "a*", "b*"])
        XCTAssertEqual(record.conventions.channelUnits, ["L-star", "a-star", "b-star"])
        XCTAssertEqual(
            record.mathematics.outputMapping,
            .labD65ToSRGB(clipsFiniteOutOfGamutValues: true)
        )
    }

    func testRecordValueTypesRejectNonFiniteAndWrongSizedValues() throws {
        XCTAssertThrowsError(try AnalysisVector3(values: [0, .nan, 2])) { error in
            XCTAssertEqual(error as? AnalysisRecordError, .nonFiniteValue)
        }
        XCTAssertThrowsError(try AnalysisVector3(values: [0, 1])) { error in
            XCTAssertEqual(
                error as? AnalysisRecordError,
                .invalidValueCount(expected: 3, actual: 2)
            )
        }
        XCTAssertThrowsError(try AnalysisMatrix3(values: Array(repeating: 0, count: 8))) { error in
            XCTAssertEqual(
                error as? AnalysisRecordError,
                .invalidValueCount(expected: 9, actual: 8)
            )
        }

        let vector = try AnalysisVector3(values: [0, 1, 2])
        let matrix = try AnalysisMatrix3(values: Array(repeating: 0, count: 9))
        XCTAssertThrowsError(
            try AnalysisMathematicsRecord(
                samplePixelCount: 4,
                mean: vector,
                covariance: matrix,
                analysisMatrix: matrix,
                eigenvalues: vector,
                eigenvectors: matrix,
                transform: matrix,
                stableVariableCount: 3,
                stableComponentCount: 3,
                outputMapping: .rgbGlobalRange(minimum: 0, maximum: 1, scale: .infinity)
            )
        ) { error in
            XCTAssertEqual(error as? AnalysisRecordError, .nonFiniteValue)
        }
    }

    func testCanonicalJSONHasVersionedSchemaExplicitNullAndNoVolatileValues() throws {
        let record = try canonicalFixtureRecord()
        let data = try AnalysisRecordJSONEncoder.data(for: record)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        XCTAssertEqual(object["schema"] as? String, "org.kltimage.analysis-record")
        XCTAssertEqual(object["version"] as? Int, 1)
        let request = try XCTUnwrap(object["request"] as? [String: Any])
        XCTAssertTrue(request["region"] is NSNull)
        let mathematics = try XCTUnwrap(object["mathematics"] as? [String: Any])
        XCTAssertEqual((mathematics["mean"] as? [NSNumber])?.map(\.doubleValue), [1, 2, 3])
        XCTAssertEqual((mathematics["transform"] as? [NSNumber])?.count, 9)

        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.hasSuffix("\n"))
        XCTAssertFalse(text.contains("timestamp"))
        XCTAssertFalse(text.contains("jobID"))
        XCTAssertFalse(text.contains("/Users/"))
    }

    func testCanonicalJSONBytesAreGoldenAndAtomicWritesRepeatExactly() throws {
        let record = try canonicalFixtureRecord()
        let first = try AnalysisRecordJSONEncoder.data(for: record)
        let second = try AnalysisRecordJSONEncoder.data(for: record)
        XCTAssertEqual(first, second)
        XCTAssertEqual(String(decoding: first, as: UTF8.self), canonicalGoldenJSON)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("klt-analysis-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("result.klt-analysis.json")
        try AnalysisRecordJSONEncoder.write(record, to: url)
        let writtenOnce = try Data(contentsOf: url)
        try AnalysisRecordJSONEncoder.write(record, to: url)
        let writtenTwice = try Data(contentsOf: url)
        XCTAssertEqual(writtenOnce, first)
        XCTAssertEqual(writtenTwice, first)
    }

    func testLimitedVariationRecordUsesExplicitIdentityOutputPath() throws {
        let source = try ImagePipeline.decode(
            fixtureData(width: 4, height: 4) { _, _ in (51, 102, 153, 255) }
        )
        let enhancement = try ImagePipeline.enhance(source, input: .baseline)
        let record = try AnalysisRecord(
            decodedSource: source,
            displayFilename: "constant.png",
            enhancement: enhancement
        )

        XCTAssertTrue(record.hasLimitedVariation)
        XCTAssertEqual(record.mathematics.transform.values, Matrix3x3.identity.rowMajorValues)
        XCTAssertEqual(record.mathematics.outputMapping, .limitedVariationIdentity)
        XCTAssertTrue(record.mathematics.mean.values.allSatisfy(\.isFinite))
        XCTAssertTrue(record.mathematics.covariance.values.allSatisfy(\.isFinite))
        XCTAssertNoThrow(try AnalysisRecordJSONEncoder.data(for: record))
    }

    func testRepeatedAndNearEqualEigenvaluesKeepDeterministicOrderAndSigns() {
        let matrices = [
            Matrix3x3.diagonal(SIMD3(2, 2, 1)),
            Matrix3x3([
                2.000000000001, 0.0000000002, 0,
                0.0000000002, 2, 0,
                0, 0, 1
            ])
        ]

        for matrix in matrices {
            let first = matrix.symmetricEigenDecomposition()
            let second = matrix.symmetricEigenDecomposition()
            XCTAssertEqual(first.values, second.values)
            XCTAssertEqual(first.vectors, second.vectors)
            XCTAssertGreaterThanOrEqual(first.values.x, first.values.y)
            XCTAssertGreaterThanOrEqual(first.values.y, first.values.z)

            for column in 0..<3 {
                let dominantRow = (0..<3).max {
                    abs(first.vectors[$0, column]) < abs(first.vectors[$1, column])
                }!
                XCTAssertGreaterThanOrEqual(first.vectors[dominantRow, column], 0)
            }
        }
    }

    private func canonicalFixtureRecord() throws -> AnalysisRecord {
        let fingerprint = try AnalysisSourceFingerprint(
            algorithm: "sha256",
            value: String(repeating: "a", count: 64)
        )
        let source = try AnalysisSourceDescriptor(
            displayFilename: "specimen.tif",
            width: 2,
            height: 2,
            fingerprint: fingerprint
        )
        let vector = try AnalysisVector3(values: [1, 2, 3])
        let covariance = try AnalysisMatrix3(values: [
            4, 0.5, 0.25,
            0.5, 5, 0.75,
            0.25, 0.75, 6
        ])
        let identity = try AnalysisMatrix3(values: Matrix3x3.identity.rowMajorValues)
        let mathematics = try AnalysisMathematicsRecord(
            samplePixelCount: 4,
            mean: vector,
            covariance: covariance,
            analysisMatrix: covariance,
            eigenvalues: try AnalysisVector3(values: [6, 5, 4]),
            eigenvectors: identity,
            transform: identity,
            stableVariableCount: 3,
            stableComponentCount: 3,
            outputMapping: .rgbGlobalRange(minimum: -1, maximum: 3, scale: 0.25)
        )
        return try AnalysisRecord(
            source: source,
            input: .baseline,
            region: nil,
            conventions: try AnalysisConventions(
                channelOrder: ["red", "green", "blue"],
                channelUnits: Array(repeating: "encoded-srgb-[0,1]", count: 3)
            ),
            mathematics: mathematics,
            hasLimitedVariation: false
        )
    }

    private func fixtureData(
        width: Int,
        height: Int,
        pixel: ((Int, Int) -> (UInt8, UInt8, UInt8, UInt8))? = nil
    ) throws -> Data {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let value = pixel?(x, y) ?? defaultPixel(x: x, y: y, width: width)
                    let offset = ((y * width) + x) * 4
                    bytes[offset] = value.0
                    bytes[offset + 1] = value.1
                    bytes[offset + 2] = value.2
                    bytes[offset + 3] = value.3
                }
            }
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: bitmapInfo,
            provider: CGDataProvider(data: pixels as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .relativeColorimetric
        )!
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output,
            UTType.tiff.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func defaultPixel(
        x: Int,
        y: Int,
        width: Int
    ) -> (UInt8, UInt8, UInt8, UInt8) {
        let index = (y * width) + x
        return (
            UInt8((index * 37 + 17) % 256),
            UInt8((index * 59 + 41) % 256),
            UInt8((index * 83 + 73) % 256),
            255
        )
    }

    private func vectorValues(_ value: SIMD3<Double>) -> [Double] {
        [value.x, value.y, value.z]
    }

    private var canonicalGoldenJSON: String {
        "{\"conventions\":{\"channelOrder\":[\"red\",\"green\",\"blue\"],\"channelUnits\":[\"encoded-srgb-[0,1]\",\"encoded-srgb-[0,1]\",\"encoded-srgb-[0,1]\"],\"matrixStorage\":\"row-major\",\"regionBounds\":\"half-open\",\"regionOrigin\":\"top-left\"},\"interpretation\":{\"exploratoryUseNotice\":\"This record documents an exploratory enhancement. It does not establish a biological or scientific conclusion.\",\"limitedVariation\":false},\"mathematics\":{\"analysisMatrix\":[4,0.5,0.25,0.5,5,0.75,0.25,0.75,6],\"covariance\":[4,0.5,0.25,0.5,5,0.75,0.25,0.75,6],\"eigenvalues\":[6,5,4],\"eigenvectors\":[1,0,0,0,1,0,0,0,1],\"mean\":[1,2,3],\"outputMapping\":{\"clipsToUnitRange\":true,\"maximum\":3,\"minimum\":-1,\"scale\":0.25,\"type\":\"rgbGlobalRange\"},\"samplePixelCount\":4,\"stableComponentCount\":3,\"stableVariableCount\":3,\"transform\":[1,0,0,0,1,0,0,0,1]},\"request\":{\"colorSpace\":\"rgb\",\"matrixMode\":\"covariance\",\"region\":null,\"samplingMode\":\"wholeImage\"},\"schema\":\"org.kltimage.analysis-record\",\"source\":{\"analysisPixelFormat\":\"rgba8-premultiplied-srgb\",\"filename\":\"specimen.tif\",\"fingerprint\":{\"algorithm\":\"sha256\",\"value\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"},\"height\":2,\"width\":2},\"version\":1}\n"
    }
}
