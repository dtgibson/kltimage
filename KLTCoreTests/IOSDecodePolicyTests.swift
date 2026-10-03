import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Foundation
import XCTest
@testable import KLTCore

final class IOSDecodePolicyTests: XCTestCase {
    func testFixedMobileBoundaryDoesNotChangeMacBoundary() throws {
        XCTAssertEqual(try ImageProcessingLimits.checkedRGBAByteCount(
            width: 6_500, height: 4_000,
            maximumPixelCount: ImageProcessingLimits.maximumIOSPixelCount
        ), 104_000_000)
        XCTAssertThrowsError(try ImageProcessingLimits.checkedRGBAByteCount(
            width: 6_500, height: 4_001,
            maximumPixelCount: ImageProcessingLimits.maximumIOSPixelCount
        )) { XCTAssertEqual($0 as? ImagePipelineError, .imageTooLarge) }
        XCTAssertEqual(try ImageProcessingLimits.checkedRGBAByteCount(width: 8_000, height: 8_000), 256_000_000)
        XCTAssertThrowsError(try ImageProcessingLimits.checkedRGBAByteCount(width: 8_000, height: 8_001))
    }

    func testFileURLDecodeMatchesDataDecode() throws {
        let png = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAGCAYAAAD+Bd/7AAAAAXNSR0IB2cksfwAAAFBlWElmTU0AKgAAAAgAAgESAAMAAAABAAEAAIdpAAQAAAABAAAAJgAAAAAAA6ABAAMAAAABAAEAAKACAAQAAAABAAAACKADAAQAAAABAAAABgAAAAA4aestAAAAn0lEQVQIHR1NyxGCMBQcZ3LYo4JMCjA/7ACiBXhTyIHOAjRGoARiEa4c3ry3b3+nc/16m7aX+slpgtSPXir/kcYT+yDFfZmgyh66ytwRJvH2O3Q5wfEv3DZCN/EQmSJDF8QUuTLDXOIg7ELXtkO1E8mOzh12pahlEg2iThE3RtkUoPwIV5H4V6aRpgBh1xmq+MKw31GkGX3UXLvBbFn+ANf2M2AGpmb4AAAAAElFTkSuQmCC")!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try png.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let fromData = try ImagePipeline.decode(png)
        let fromFile = try ImagePipeline.decode(at: url, maximumPixelCount: ImageProcessingLimits.maximumIOSPixelCount)
        XCTAssertEqual(fromFile.width, fromData.width)
        XCTAssertEqual(fromFile.height, fromData.height)
        XCTAssertEqual(fromFile.analysisSourceFingerprint, fromData.analysisSourceFingerprint)
        XCTAssertEqual(fromFile.hasAlpha, fromData.hasAlpha)
    }
    func testDecodeMatchesLegacyThumbnailPixelsAcrossFormatsOrientationAndProfiles() throws {
        let supported = CGImageDestinationCopyTypeIdentifiers() as! [String]
        for type in [UTType.png, .tiff, .jpeg, .heic] where supported.contains(type.identifier) {
            for profile in [CGColorSpace.sRGB, CGColorSpace.displayP3, CGColorSpace.adobeRGB1998] {
                for bits in [8, 16] {
                    for alpha in [false, true] {
                        let image = try parityFixture(bits: bits, alpha: alpha, profile: profile)
                        for orientation in 1...8 {
                            try autoreleasepool {
                                let data = NSMutableData()
                                let encoder = try XCTUnwrap(CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil))
                                CGImageDestinationAddImage(encoder, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
                                XCTAssertTrue(CGImageDestinationFinalize(encoder))
                                let expected = try legacyThumbnailPixels(data as Data)
                                let actual = try ImagePipeline.decode(data as Data)
                                XCTAssertEqual(actual.width, expected.width)
                                XCTAssertEqual(actual.height, expected.height)
                                if actual.rgba8Premultiplied != expected.pixels {
                                    let deltas = zip(actual.rgba8Premultiplied, expected.pixels).map { abs(Int($0) - Int($1)) }
                                    print("PARITY_DIFF \(type.identifier) \(profile) bits=\(bits) alpha=\(alpha) EXIF=\(orientation) differingBytes=\(deltas.filter { $0 != 0 }.count) maxDelta=\(deltas.max() ?? 0)")
                                }
                                XCTAssertEqual(actual.rgba8Premultiplied, expected.pixels,
                                               "\(type.identifier) \(profile) \(bits)-bit alpha=\(alpha) EXIF=\(orientation)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func parityFixture(bits: Int, alpha: Bool, profile: CFString) throws -> CGImage {
        let width = 64, height = 48
        let componentBytes = bits / 8
        var data = Data(count: width * height * 4 * componentBytes)
        data.withUnsafeMutableBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            for pixel in 0..<(width * height) {
                let maximum = bits == 8 ? 255 : 65535
                let opacity = alpha ? (maximum / 4 + (pixel * 173) % (maximum * 3 / 4)) : maximum
                let values = [(pixel * 37 + 17) % (maximum + 1), (pixel * 59 + 41) % (maximum + 1),
                              (pixel * 83 + 73) % (maximum + 1)].map { ($0 * opacity + maximum / 2) / maximum } + [opacity]
                for channel in 0..<4 {
                    let offset = (pixel * 4 + channel) * componentBytes
                    bytes[offset] = UInt8(truncatingIfNeeded: values[channel])
                    if bits == 16 { bytes[offset + 1] = UInt8(truncatingIfNeeded: values[channel] >> 8) }
                }
            }
        }
        let bitmap = (bits == 8 ? CGBitmapInfo.byteOrder32Big : .byteOrder16Little)
            .union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
        return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits * 4,
                                    bytesPerRow: width * 4 * componentBytes, space: try XCTUnwrap(CGColorSpace(name: profile)),
                                    bitmapInfo: bitmap, provider: try XCTUnwrap(CGDataProvider(data: data as CFData)),
                                    decode: nil, shouldInterpolate: false, intent: .relativeColorimetric))
    }

    /// Frozen reference for the decoder's pre-memory-fix path, including ImageIO
    /// orientation, bit-depth handling and the existing sRGB rendering operation.
    private func legacyThumbnailPixels(_ data: Data) throws -> (width: Int, height: Int, pixels: Data) {
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        let width = try XCTUnwrap(properties[kCGImagePropertyPixelWidth] as? Int)
        let height = try XCTUnwrap(properties[kCGImagePropertyPixelHeight] as? Int)
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true, kCGImageSourceShouldAllowFloat: false]
        let image = try XCTUnwrap(CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary))
        var pixels = Data(count: image.width * image.height * 4)
        try pixels.withUnsafeMutableBytes { raw in
            let bitmap = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue))
            let context = try XCTUnwrap(CGContext(data: raw.baseAddress!, width: image.width, height: image.height,
                                                  bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                                  space: try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)), bitmapInfo: bitmap.rawValue))
            context.setBlendMode(.copy); context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return (image.width, image.height, pixels)
    }

}
