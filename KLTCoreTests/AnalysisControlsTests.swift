import CoreGraphics
import Foundation
import ImageIO
import KLTCore
import UniformTypeIdentifiers
import XCTest

final class AnalysisControlsTests: XCTestCase {
    func testRequestGateRequiresNewestJobAndCurrentScientificKey() {
        XCTAssertTrue(
            RequestAcceptanceGate.accepts(
                completedJobID: 4,
                completedKey: "lab-correlation-region",
                activeJobID: 4,
                currentKey: "lab-correlation-region"
            )
        )
        XCTAssertFalse(
            RequestAcceptanceGate.accepts(
                completedJobID: 3,
                completedKey: "lab-correlation-region",
                activeJobID: 4,
                currentKey: "lab-correlation-region"
            )
        )
        XCTAssertFalse(
            RequestAcceptanceGate.accepts(
                completedJobID: 4,
                completedKey: "rgb-covariance-whole",
                activeJobID: 4,
                currentKey: "lab-correlation-region"
            )
        )
    }

    func testPublishedSRGBLabReferenceColorsAndRoundTrip() throws {
        let black = try CIELabD65.fromSRGB(.zero)
        assertEqual(black, .zero, accuracy: 1e-10)

        let white = try CIELabD65.fromSRGB(SIMD3(repeating: 1))
        XCTAssertEqual(white.x, 100, accuracy: 2e-5)
        XCTAssertEqual(white.y, 0, accuracy: 2e-5)
        XCTAssertEqual(white.z, 0, accuracy: 2e-5)

        let red = try CIELabD65.fromSRGB(SIMD3(1, 0, 0))
        XCTAssertEqual(red.x, 53.2408, accuracy: 1e-3)
        XCTAssertEqual(red.y, 80.0925, accuracy: 1e-3)
        XCTAssertEqual(red.z, 67.2032, accuracy: 1e-3)

        let fixture = SIMD3<Double>(0.12, 0.56, 0.91)
        let roundTrip = try CIELabD65.toClippedSRGB(CIELabD65.fromSRGB(fixture))
        assertEqual(roundTrip, fixture, accuracy: 5e-7)
    }

    func testLabInverseClipsFiniteOutOfGamutAndRejectsNonFinite() throws {
        let clipped = try CIELabD65.toClippedSRGB(SIMD3(115, 180, -180))
        for value in [clipped.x, clipped.y, clipped.z] {
            XCTAssertTrue(value.isFinite)
            XCTAssertTrue((0...1).contains(value))
        }
        XCTAssertThrowsError(try CIELabD65.fromSRGB(SIMD3(.nan, 0, 0))) { error in
            XCTAssertEqual(error as? ColorConversionError, .nonFiniteColor)
        }
        XCTAssertThrowsError(try CIELabD65.toClippedSRGB(SIMD3(.infinity, 0, 0))) { error in
            XCTAssertEqual(error as? ColorConversionError, .nonFiniteColor)
        }
    }

    func testRegionValidatorRetainsExactBoundsAndRejectsEveryGeometryClass() throws {
        XCTAssertThrowsError(
            try SourcePixelRegionValidator.validate(nil, sourceWidth: 20, sourceHeight: 10)
        ) { XCTAssertEqual($0 as? RegionValidationIssue, .missing) }

        XCTAssertThrowsError(
            try SourcePixelRegionValidator.validate(
                SourcePixelRegion(x: 0, y: 0, width: 0, height: 4),
                sourceWidth: 20,
                sourceHeight: 10
            )
        ) { XCTAssertEqual($0 as? RegionValidationIssue, .nonPositiveSize) }

        XCTAssertThrowsError(
            try SourcePixelRegionValidator.validate(
                SourcePixelRegion(x: 19, y: 0, width: 2, height: 2),
                sourceWidth: 20,
                sourceHeight: 10
            )
        ) { XCTAssertEqual($0 as? RegionValidationIssue, .outsideSource(sourceWidth: 20, sourceHeight: 10)) }

        XCTAssertThrowsError(
            try SourcePixelRegionValidator.validate(
                SourcePixelRegion(x: 0, y: 0, width: Int.max, height: 2),
                sourceWidth: 20,
                sourceHeight: 10
            )
        ) { XCTAssertEqual($0 as? RegionValidationIssue, .outsideSource(sourceWidth: 20, sourceHeight: 10)) }

        XCTAssertThrowsError(
            try SourcePixelRegionValidator.validate(
                SourcePixelRegion(x: 0, y: 0, width: 1, height: 3),
                sourceWidth: 20,
                sourceHeight: 10
            )
        ) { XCTAssertEqual($0 as? RegionValidationIssue, .fewerThanFourPixels) }

        let region = SourcePixelRegion(x: 16, y: 8, width: 4, height: 2)
        let validated = try SourcePixelRegionValidator.validate(
            region,
            sourceWidth: 20,
            sourceHeight: 10
        )
        XCTAssertEqual(validated.bounds, region)
        XCTAssertEqual(validated.pixelCount, 8)
    }

    func testViewportTransformRoundTripsCanonicalBoundsAcrossZoomAndPan() {
        let region = SourcePixelRegion(x: 313, y: 129, width: 177, height: 96)
        for paneSize in [CGSize(width: 920, height: 640), CGSize(width: 459.5, height: 640)] {
            let transform = ImageViewportTransform(
                sourceSize: CGSize(width: 1200, height: 800),
                paneSize: paneSize,
                zoom: 1.75,
                pan: CGSize(width: -43, height: 27)
            )
            let viewRect = transform.sourceToView(region)
            let reconstructed = transform.constrainedRegion(
                from: CGPoint(x: viewRect.minX, y: viewRect.minY),
                to: CGPoint(x: viewRect.maxX, y: viewRect.maxY)
            )
            XCTAssertEqual(reconstructed, region)
        }
    }

    func testBaselineMatchesImmutableVersion100Build2GoldenFixtures() throws {
        // These exact fixtures were captured by compiling and running commit
        // 8990c95, the shipped 1.0.0 (2) source, independently of this branch.
        let ordinarySource = try ImagePipeline.decode(Build2Golden.ordinaryInput)
        let ordinary = try ImagePipeline.enhance(ordinarySource, input: .baseline)
        XCTAssertEqual(rgbaData(in: ordinary.image), Build2Golden.ordinaryOutput)
        XCTAssertNil(ordinary.notice)
        XCTAssertEqual(ordinary.descriptor.input, .baseline)

        let degenerateSource = try ImagePipeline.decode(Build2Golden.degenerateInput)
        let degenerate = try ImagePipeline.enhance(degenerateSource, input: .baseline)
        XCTAssertEqual(rgbaData(in: degenerate.image), Build2Golden.degenerateOutput)
        XCTAssertEqual(degenerate.notice, "Not enough color variation to enhance this image.")
        XCTAssertTrue(degenerate.analysis.isDegenerate)
    }

    func testAllEightAnalysisCombinationsAreDeterministicAndPreserveAlpha() throws {
        let source = try decodedFixture(width: 18, height: 14, includesAlpha: true)
        let sourceAlpha = alphaBytes(in: source.originalImage)
        let region = SourcePixelRegion(x: 3, y: 2, width: 8, height: 6)

        for colorSpace in AnalysisColorSpace.allCases {
            for matrixMode in AnalysisMatrixMode.allCases {
                for sampleSource in AnalysisSampleSource.allCases {
                    let input = AnalysisInput(
                        method: AnalysisMethod(colorSpace: colorSpace, matrixMode: matrixMode),
                        sampleSource: sampleSource,
                        region: sampleSource == .selectedRegion ? region : nil
                    )
                    let first = try ImagePipeline.enhance(source, input: input)
                    let second = try ImagePipeline.enhance(source, input: input)
                    XCTAssertEqual(first.descriptor.input, input)
                    XCTAssertEqual(
                        first.descriptor.samplePixelCount,
                        sampleSource == .wholeImage ? source.pixelCount : 48
                    )
                    XCTAssertEqual(first.image.width, source.width)
                    XCTAssertEqual(first.image.height, source.height)
                    XCTAssertEqual(rgbaData(in: first.image), rgbaData(in: second.image))
                    XCTAssertEqual(alphaBytes(in: first.image), sourceAlpha)
                }
            }
        }
    }

    func testCorrelationMatrixUsesUnitDiagonalAndExcludesFlatVariable() throws {
        let source = try decodedFixture(width: 24, height: 18, includesAlpha: false) { x, y in
            let red = UInt8((x * 37 + y * 11) % 256)
            let green = UInt8((x * 13 + y * 43) % 256)
            return (red, green, 96, 255)
        }
        let input = AnalysisInput(
            method: AnalysisMethod(colorSpace: .rgb, matrixMode: .correlation),
            sampleSource: .wholeImage,
            region: nil
        )
        let result = try ImagePipeline.enhance(source, input: input)
        let matrix = result.analysis.analysisMatrix

        XCTAssertEqual(result.analysis.stableVariableCount, 2)
        XCTAssertEqual(matrix[0, 0], 1, accuracy: 1e-12)
        XCTAssertEqual(matrix[1, 1], 1, accuracy: 1e-12)
        XCTAssertEqual(matrix[2, 2], 0, accuracy: 1e-12)
        XCTAssertEqual(matrix[0, 2], 0, accuracy: 1e-12)
        XCTAssertEqual(matrix[2, 1], 0, accuracy: 1e-12)
        XCTAssertTrue(result.descriptor.hasLimitedVariation)
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertTrue(matrix[row, column].isFinite)
                XCTAssertEqual(matrix[row, column], matrix[column, row], accuracy: 1e-12)
            }
        }
    }

    func testCorrelationMatrixMatchesThreeVariableReference() throws {
        let pixels: [(UInt8, UInt8, UInt8, UInt8)] = [
            (0, 20, 230, 255),
            (50, 180, 40, 255),
            (120, 70, 160, 255),
            (200, 240, 90, 255),
            (255, 130, 200, 255),
            (80, 250, 10, 255)
        ]
        let source = try decodedFixture(width: 3, height: 2, includesAlpha: false) { x, y in
            pixels[(y * 3) + x]
        }
        let result = try ImagePipeline.enhance(
            source,
            input: AnalysisInput(
                method: AnalysisMethod(colorSpace: .rgb, matrixMode: .correlation),
                sampleSource: .wholeImage,
                region: nil
            )
        )
        let matrix = result.analysis.analysisMatrix

        XCTAssertEqual(result.analysis.stableVariableCount, 3)
        XCTAssertEqual(matrix[0, 0], 1, accuracy: 1e-12)
        XCTAssertEqual(matrix[1, 1], 1, accuracy: 1e-12)
        XCTAssertEqual(matrix[2, 2], 1, accuracy: 1e-12)
        XCTAssertEqual(matrix[0, 1], 0.31715869208599906, accuracy: 1e-12)
        XCTAssertEqual(matrix[0, 2], 0.1232915621576995, accuracy: 1e-12)
        XCTAssertEqual(matrix[1, 2], -0.8570396483539887, accuracy: 1e-12)
        XCTAssertEqual(matrix[1, 0], matrix[0, 1], accuracy: 1e-12)
        XCTAssertEqual(matrix[2, 0], matrix[0, 2], accuracy: 1e-12)
        XCTAssertEqual(matrix[2, 1], matrix[1, 2], accuracy: 1e-12)
    }

    func testSelectedRegionIncludesExactHalfOpenPixelPopulation() throws {
        let selected: [String: (UInt8, UInt8, UInt8, UInt8)] = [
            "1,1": (10, 30, 200, 255),
            "2,1": (80, 160, 20, 255),
            "1,2": (170, 70, 130, 255),
            "2,2": (250, 220, 90, 255)
        ]
        let source = try decodedFixture(width: 4, height: 3, includesAlpha: false) { x, y in
            selected["\(x),\(y)"] ?? (255, 1, 2, 255)
        }
        let result = try ImagePipeline.enhance(
            source,
            input: AnalysisInput(
                method: .baseline,
                sampleSource: .selectedRegion,
                region: SourcePixelRegion(x: 1, y: 1, width: 2, height: 2)
            )
        )

        XCTAssertEqual(result.descriptor.samplePixelCount, 4)
        assertEqual(
            result.analysis.mean,
            SIMD3(0.5, 0.47058823529411764, 0.43137254901960786),
            accuracy: 1e-12
        )
        let covariance = result.analysis.covariance
        let expected = Matrix3x3([
            0.16852492631039342, 0.09637318979879535, -0.04049724464949379,
            0.09637318979879535, 0.11380238369857747, -0.07535563244905805,
            -0.04049724464949379, -0.07535563244905805, 0.08714596949891068
        ])
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertEqual(covariance[row, column], expected[row, column], accuracy: 1e-12)
            }
        }
    }

    func testUniformSelectedRegionFailsWithoutWholeImageFallback() throws {
        let source = try decodedFixture(width: 8, height: 8, includesAlpha: false) { x, y in
            if x < 2 { return (80, 80, 80, 255) }
            return (
                UInt8((x * 37 + y * 13) % 256),
                UInt8((x * 19 + y * 47) % 256),
                UInt8((x * 71 + y * 5) % 256),
                255
            )
        }
        let input = AnalysisInput(
            method: .baseline,
            sampleSource: .selectedRegion,
            region: SourcePixelRegion(x: 0, y: 0, width: 2, height: 2)
        )
        XCTAssertThrowsError(try ImagePipeline.enhance(source, input: input)) { error in
            XCTAssertEqual(
                error as? RegionValidationIssue,
                .insufficientVariation(stableComponentCount: 0)
            )
        }
    }

    func testRegionStatisticsProduceAFullFrameResult() throws {
        let source = try decodedFixture(width: 12, height: 8, includesAlpha: false)
        let regionInput = AnalysisInput(
            method: .baseline,
            sampleSource: .selectedRegion,
            region: SourcePixelRegion(x: 0, y: 0, width: 5, height: 5)
        )
        let result = try ImagePipeline.enhance(source, input: regionInput)
        let sourceBytes = rgbaData(in: source.originalImage)
        let resultBytes = rgbaData(in: result.image)

        XCTAssertEqual(result.descriptor.samplePixelCount, 25)
        XCTAssertNotEqual(sourceBytes, resultBytes)
        let outsideRegionOffset = ((7 * source.width) + 11) * 4
        XCTAssertNotEqual(
            Array(sourceBytes[outsideRegionOffset..<(outsideRegionOffset + 3)]),
            Array(resultBytes[outsideRegionOffset..<(outsideRegionOffset + 3)])
        )
    }

    func testEveryCombinationExportsAtSourceDimensions() throws {
        let source = try decodedFixture(width: 10, height: 8, includesAlpha: true)
        let region = SourcePixelRegion(x: 1, y: 1, width: 6, height: 5)
        for colorSpace in AnalysisColorSpace.allCases {
            for matrixMode in AnalysisMatrixMode.allCases {
                for sampleSource in AnalysisSampleSource.allCases {
                    let input = AnalysisInput(
                        method: AnalysisMethod(colorSpace: colorSpace, matrixMode: matrixMode),
                        sampleSource: sampleSource,
                        region: sampleSource == .selectedRegion ? region : nil
                    )
                    let result = try ImagePipeline.enhance(source, input: input)
                    for format in ImageExportFormat.allCases {
                        let data = try ImagePipeline.encodedData(for: result.image, format: format)
                        let decoded = try ImagePipeline.decode(data)
                        XCTAssertEqual(decoded.width, source.width)
                        XCTAssertEqual(decoded.height, source.height)
                        XCTAssertEqual(decoded.hasAlpha, format != .jpeg)
                    }
                }
            }
        }
    }

    func testAlreadyCancelledAnalysisStopsBeforePublishingAResult() async throws {
        let source = try decodedFixture(width: 120, height: 80, includesAlpha: false)
        let task = Task.detached {
            try await Task.sleep(for: .seconds(2))
            return try ImagePipeline.enhance(
                source,
                input: AnalysisInput(
                    method: AnalysisMethod(colorSpace: .lab, matrixMode: .correlation),
                    sampleSource: .wholeImage,
                    region: nil
                )
            )
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A canceled analysis unexpectedly completed")
        } catch is CancellationError {
            // Expected.
        }
    }

    private func decodedFixture(
        width: Int,
        height: Int,
        includesAlpha: Bool,
        pixel: ((Int, Int) -> (UInt8, UInt8, UInt8, UInt8))? = nil
    ) throws -> DecodedImage {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for y in 0..<height {
                for x in 0..<width {
                    let index = (y * width) + x
                    let defaultAlpha = includesAlpha ? UInt8(80 + ((index * 23) % 176)) : 255
                    let raw = pixel?(x, y) ?? (
                        UInt8((index * 37 + 17) % 256),
                        UInt8((index * 59 + 41) % 256),
                        UInt8((index * 83 + 73) % 256),
                        defaultAlpha
                    )
                    let offset = index * 4
                    bytes[offset] = UInt8((UInt16(raw.0) * UInt16(raw.3) + 127) / 255)
                    bytes[offset + 1] = UInt8((UInt16(raw.1) * UInt16(raw.3) + 127) / 255)
                    bytes[offset + 2] = UInt8((UInt16(raw.2) * UInt16(raw.3) + 127) / 255)
                    bytes[offset + 3] = raw.3
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
        return try ImagePipeline.decode(output as Data)
    }

    private func rgbaData(in image: CGImage) -> Data {
        var data = Data(count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { rawBuffer in
            let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
                CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            )
            let context = CGContext(
                data: rawBuffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: bitmapInfo.rawValue
            )!
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }

    private func alphaBytes(in image: CGImage) -> [UInt8] {
        let data = rgbaData(in: image)
        return data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        }
    }

    private func assertEqual(
        _ actual: SIMD3<Double>,
        _ expected: SIMD3<Double>,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, file: file, line: line)
    }
}

private enum Build2Golden {
    static let ordinaryInput = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAYAAAD+Bd/7AAAAAXNSR0IB2cksfwAAAFBlWElmTU0AKgAAAAgAAgESAAMAAAABAAEAAIdpAAQAAAABAAAAJgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAACKADAAQAAAABAAAABgAAAAA4aestAAAAn0lEQVQIHR1NyxGCMBQcZ3LYo4JMCjA/7ACiBXhTyIHOAjRGoARiEa4c3ry3b3+nc/16m7aX+slpgtSPXir/kcYT+yDFfZmgyh66ytwRJvH2O3Q5wfEv3DZCN/EQmSJDF8QUuTLDXOIg7ELXtkO1E8mOzh12pahlEg2iThE3RtkUoPwIV5H4V6aRpgBh1xmq+MKw31GkGX3UXLvBbFn+ANf2M2AGpmb4AAAAAElFTkSuQmCC")!
    static let ordinaryOutput = Data(base64Encoded: "BhEWUBYrPmcrUXZ+QoAllXgKZqyhNbTDy20y2gbIgfEZAk5YKhwWb0U/RoZka4edh6IetMsUacsUYrniMKQf+SBULWBFCGB3YCoQjodTSqWyhpO8GwoQ0z09X+ogJjxRNEgFaFB0MX+EEG6WqjkHrQ6DQ8QtwJTbaBYA8jIbHllOOUpwb2KGh5OWMJ4aMHG1N2LEzFWhPON/5Zb6SQtcYWcpH3iOT1SPD5OUpjoSKb1eQXTUh3rP6zg9D1JVZTdp")!
    static let degenerateInput = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAAXNSR0IB2cksfwAAAERlWElmTU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAABKADAAQAAAABAAAABAAAAADFbP4CAAAAFklEQVQIHWM0Tpv5nwEJMCGxwUzCAgCPkgI5Tk8fHgAAAABJRU5ErkJggg==")!
    static let degenerateOutput = Data(base64Encoded: "M2aZ/zNmmf8zZpn/M2aZ/zNmmf8zZpn/M2aZ/zNmmf8zZpn/M2aZ/zNmmf8zZpn/M2aZ/zNmmf8zZpn/M2aZ/w==")!
}
