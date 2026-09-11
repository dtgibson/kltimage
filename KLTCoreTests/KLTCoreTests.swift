import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest
import KLTCore

final class Matrix3x3Tests: XCTestCase {
    func testSymmetricEigenDecompositionReconstructsMatrix() {
        let matrix = Matrix3x3([
            4.0, 1.2, -0.4,
            1.2, 2.5, 0.7,
            -0.4, 0.7, 1.3
        ])

        let decomposition = matrix.symmetricEigenDecomposition()
        let reconstructed = decomposition.vectors
            * Matrix3x3.diagonal(decomposition.values)
            * decomposition.vectors.transposed

        assertEqual(reconstructed, matrix, accuracy: 1e-10)
        assertEqual(decomposition.vectors.transposed * decomposition.vectors, .identity, accuracy: 1e-10)
        XCTAssertGreaterThanOrEqual(decomposition.values.x, decomposition.values.y)
        XCTAssertGreaterThanOrEqual(decomposition.values.y, decomposition.values.z)
    }

    private func assertEqual(
        _ actual: Matrix3x3,
        _ expected: Matrix3x3,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertEqual(actual[row, column], expected[row, column], accuracy: accuracy, file: file, line: line)
            }
        }
    }
}

final class DecorrelationStretchTests: XCTestCase {
    func testCovarianceMatchesReferenceValues() throws {
        let pixels = [
            RGBAPixel(red: 1, green: 2, blue: 3),
            RGBAPixel(red: 2, green: 4, blue: 6),
            RGBAPixel(red: 3, green: 6, blue: 9)
        ]

        let result = try DecorrelationStretch.process(pixels)

        XCTAssertEqual(result.analysis.mean.x, 2, accuracy: 1e-12)
        XCTAssertEqual(result.analysis.mean.y, 4, accuracy: 1e-12)
        XCTAssertEqual(result.analysis.mean.z, 6, accuracy: 1e-12)
        let expected = Matrix3x3([
            1, 2, 3,
            2, 4, 6,
            3, 6, 9
        ])
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertEqual(result.analysis.covariance[row, column], expected[row, column], accuracy: 1e-12)
            }
        }
    }

    func testStableOutputComponentsHaveEqualVariance() throws {
        let pixels = [
            RGBAPixel(red: 0.05, green: 0.18, blue: 0.33),
            RGBAPixel(red: 0.24, green: 0.61, blue: 0.47),
            RGBAPixel(red: 0.72, green: 0.12, blue: 0.58),
            RGBAPixel(red: 0.81, green: 0.77, blue: 0.19),
            RGBAPixel(red: 0.31, green: 0.42, blue: 0.91),
            RGBAPixel(red: 0.66, green: 0.35, blue: 0.74),
            RGBAPixel(red: 0.13, green: 0.83, blue: 0.68),
            RGBAPixel(red: 0.93, green: 0.54, blue: 0.39)
        ]

        let result = try DecorrelationStretch.process(pixels)
        let outputCovariance = try DecorrelationStretch.process(result.pixels).analysis.covariance
        let outputEigenvalues = outputCovariance.symmetricEigenDecomposition().values

        XCTAssertEqual(result.analysis.stableComponentCount, 3)
        XCTAssertEqual(outputEigenvalues.x, outputEigenvalues.y, accuracy: 1e-10)
        XCTAssertEqual(outputEigenvalues.y, outputEigenvalues.z, accuracy: 1e-10)
    }

    func testUniformImageRemainsUnchanged() throws {
        let pixels = Array(
            repeating: RGBAPixel(red: 0.2, green: 0.4, blue: 0.6, alpha: 0.7),
            count: 16
        )

        let result = try DecorrelationStretch.process(pixels)

        XCTAssertEqual(result.pixels, pixels)
        XCTAssertTrue(result.analysis.isDegenerate)
        XCTAssertEqual(result.analysis.stableComponentCount, 0)
        XCTAssertNotNil(result.notice)
    }

    func testNearSingularColorDataStaysFiniteAndBounded() throws {
        let pixels = (0..<64).map { index in
            let red = Double(index) / 63
            let perturbation = index.isMultiple(of: 2) ? 1e-10 : -1e-10
            return RGBAPixel(
                red: red,
                green: (red * 0.9) + perturbation,
                blue: 0.42
            )
        }

        let result = try DecorrelationStretch.process(pixels)

        XCTAssertGreaterThanOrEqual(result.analysis.stableComponentCount, 1)
        XCTAssertLessThan(result.analysis.stableComponentCount, 3)
        for pixel in result.pixels {
            XCTAssertTrue(pixel.red.isFinite && (0...1).contains(pixel.red))
            XCTAssertTrue(pixel.green.isFinite && (0...1).contains(pixel.green))
            XCTAssertTrue(pixel.blue.isFinite && (0...1).contains(pixel.blue))
        }
    }

    func testAlphaDoesNotEnterColorCovariance() throws {
        let colors = [
            RGBAPixel(red: 0.1, green: 0.7, blue: 0.3, alpha: 1),
            RGBAPixel(red: 0.8, green: 0.2, blue: 0.6, alpha: 1),
            RGBAPixel(red: 0.4, green: 0.9, blue: 0.1, alpha: 1),
            RGBAPixel(red: 0.6, green: 0.3, blue: 0.95, alpha: 1)
        ]
        let variedAlpha = colors.enumerated().map { index, pixel in
            RGBAPixel(
                red: pixel.red,
                green: pixel.green,
                blue: pixel.blue,
                alpha: Double(index + 1) / Double(colors.count)
            )
        }

        let opaque = try DecorrelationStretch.process(colors).analysis
        let transparent = try DecorrelationStretch.process(variedAlpha).analysis

        XCTAssertEqual(opaque.mean, transparent.mean)
        XCTAssertEqual(opaque.covariance, transparent.covariance)
    }

    func testSinglePixelRemainsUnchanged() throws {
        let pixel = RGBAPixel(red: 0.3, green: 0.2, blue: 0.1, alpha: 0.5)
        let result = try DecorrelationStretch.process([pixel])
        XCTAssertEqual(result.pixels, [pixel])
        XCTAssertTrue(result.analysis.isDegenerate)
    }

    func testOutputIsDeterministicFiniteAndPreservesAlpha() throws {
        var pixels = [RGBAPixel]()
        for index in 0..<128 {
            let red = Double((index * 31) % 127) / 126.0
            let green = Double((index * 47) % 113) / 112.0
            let blue = Double((index * 61) % 109) / 108.0
            let alpha = Double((index % 7) + 1) / 7.0
            pixels.append(RGBAPixel(red: red, green: green, blue: blue, alpha: alpha))
        }

        let first = try DecorrelationStretch.process(pixels)
        let second = try DecorrelationStretch.process(pixels)

        XCTAssertEqual(first.pixels, second.pixels)
        for (input, output) in zip(pixels, first.pixels) {
            XCTAssertEqual(output.alpha, input.alpha)
            XCTAssertTrue(output.red.isFinite && (0...1).contains(output.red))
            XCTAssertTrue(output.green.isFinite && (0...1).contains(output.green))
            XCTAssertTrue(output.blue.isFinite && (0...1).contains(output.blue))
        }
    }
}

final class ImagePipelineTests: XCTestCase {
#if !DEBUG
    func testTwentyFourMegapixelImageProcessesWithinFiveSeconds() throws {
        let width = 6_000
        let height = 4_000
        let fixture = try fixtureData(width: width, height: height, type: .tiff)
        let decoded = try ImagePipeline.decode(fixture)

        let start = CFAbsoluteTimeGetCurrent()
        let result = try ImagePipeline.enhance(decoded)
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(result.image.width, width)
        XCTAssertEqual(result.image.height, height)
        XCTAssertLessThan(elapsed, 5, "24 MP processing took \(elapsed) seconds")
    }
#endif

    func testAllSupportedImportFormatsDecode() throws {
        for type in [UTType.jpeg, .png, .tiff, .heic] {
            let data = try fixtureData(width: 6, height: 4, type: type)
            let decoded = try ImagePipeline.decode(data)
            XCTAssertEqual(decoded.width, 6, "Wrong width for \(type.identifier)")
            XCTAssertEqual(decoded.height, 4, "Wrong height for \(type.identifier)")
        }
    }

    func testDecodeRespectsOrientationAndConvertsToSRGB() throws {
        let source = try fixtureData(width: 2, height: 3, type: .tiff, orientation: 6)
        let decoded = try ImagePipeline.decode(source)

        XCTAssertEqual(decoded.width, 3)
        XCTAssertEqual(decoded.height, 2)
        XCTAssertEqual(decoded.originalImage.colorSpace?.name, CGColorSpace.sRGB)
    }

    func testCorruptInputProducesReadableError() {
        XCTAssertThrowsError(try ImagePipeline.decode(Data("not an image".utf8))) { error in
            XCTAssertEqual(error as? ImagePipelineError, .unreadableImage)
            XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
        }
    }

    func testEnhancementPreservesDimensionsAndAlphaBytes() throws {
        let sourceData = try fixtureData(width: 8, height: 8, type: .png, includesAlpha: true)
        let source = try ImagePipeline.decode(sourceData)
        let result = try ImagePipeline.enhance(source)

        XCTAssertEqual(result.image.width, 8)
        XCTAssertEqual(result.image.height, 8)
        XCTAssertTrue(source.hasAlpha)
        let sourceAlpha = alphaBytes(in: source.originalImage)
        let resultAlpha = alphaBytes(in: result.image)
        XCTAssertEqual(resultAlpha, sourceAlpha)
    }

    func testPNGAndTIFFExportRetainDimensionsAndTransparency() throws {
        let sourceData = try fixtureData(width: 7, height: 5, type: .png, includesAlpha: true)
        let enhanced = try ImagePipeline.enhance(ImagePipeline.decode(sourceData))

        for format in [ImageExportFormat.png, .tiff] {
            let encoded = try ImagePipeline.encodedData(for: enhanced.image, format: format)
            let decoded = try ImagePipeline.decode(encoded)
            XCTAssertEqual(decoded.width, 7)
            XCTAssertEqual(decoded.height, 5)
            XCTAssertTrue(decoded.hasAlpha)
        }
    }

    func testJPEGExportRetainsDimensions() throws {
        let sourceData = try fixtureData(width: 9, height: 6, type: .png, includesAlpha: true)
        let enhanced = try ImagePipeline.enhance(ImagePipeline.decode(sourceData))
        let encoded = try ImagePipeline.encodedData(for: enhanced.image, format: .jpeg)
        let decoded = try ImagePipeline.decode(encoded)

        XCTAssertEqual(decoded.width, 9)
        XCTAssertEqual(decoded.height, 6)
        XCTAssertFalse(decoded.hasAlpha)
    }

    func testRepeatedPipelineProcessingIsByteDeterministic() throws {
        let sourceData = try fixtureData(width: 12, height: 10, type: .png, includesAlpha: true)
        let source = try ImagePipeline.decode(sourceData)
        let first = try ImagePipeline.enhance(source)
        let second = try ImagePipeline.enhance(source)
        XCTAssertEqual(rgbaData(in: first.image), rgbaData(in: second.image))
    }

    private func fixtureData(
        width: Int,
        height: Int,
        type: UTType,
        orientation: Int = 1,
        includesAlpha: Bool = false
    ) throws -> Data {
        let fixture = fixtureImage(width: width, height: height, includesAlpha: includesAlpha)

        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(output, type.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(
            destination,
            fixture.image,
            [kCGImagePropertyOrientation: orientation] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return output as Data
    }

    private func fixtureImage(
        width: Int,
        height: Int,
        includesAlpha: Bool
    ) -> (pixels: Data, image: CGImage) {
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let alpha = includesAlpha ? UInt8(80 + ((index * 23) % 176)) : 255
                let red = UInt8((index * 37 + 17) % 256)
                let green = UInt8((index * 59 + 41) % 256)
                let blue = UInt8((index * 83 + 73) % 256)
                let offset = index * 4
                bytes[offset] = UInt8((UInt16(red) * UInt16(alpha) + 127) / 255)
                bytes[offset + 1] = UInt8((UInt16(green) * UInt16(alpha) + 127) / 255)
                bytes[offset + 2] = UInt8((UInt16(blue) * UInt16(alpha) + 127) / 255)
                bytes[offset + 3] = alpha
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let provider = CGDataProvider(data: pixels as CFData)!
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .relativeColorimetric
        )!
        return (pixels, image)
    }

    private func alphaBytes(in image: CGImage) -> [UInt8] {
        let data = rgbaData(in: image)
        return data.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            return stride(from: 3, to: bytes.count, by: 4).map { bytes[$0] }
        }
    }

    private func rgbaData(in image: CGImage) -> Data {
        var data = Data(count: image.width * image.height * 4)
        data.withUnsafeMutableBytes { rawBuffer in
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
            let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
                CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            )
            let context = CGContext(
                data: rawBuffer.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            )!
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return data
    }
}
