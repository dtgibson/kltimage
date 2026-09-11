import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct DecodedImage: @unchecked Sendable {
    public let width: Int
    public let height: Int
    public let sourceTypeIdentifier: String?
    public let hasAlpha: Bool
    public let originalImage: CGImage

    let rgba8Premultiplied: Data

    public var pixelCount: Int { width * height }

    public var sourceFormatName: String {
        guard
            let sourceTypeIdentifier,
            let type = UTType(sourceTypeIdentifier),
            let extensionName = type.preferredFilenameExtension
        else {
            return "IMAGE"
        }
        return extensionName.uppercased()
    }
}

public struct EnhancedImage: @unchecked Sendable {
    public let image: CGImage
    public let analysis: StretchAnalysis
    public let notice: String?

    let rgba8Premultiplied: Data
}

public enum ImageExportFormat: String, CaseIterable, Sendable {
    case png
    case tiff
    case jpeg

    public var filenameExtension: String {
        switch self {
        case .png: "png"
        case .tiff: "tiff"
        case .jpeg: "jpg"
        }
    }

    public var displayName: String {
        switch self {
        case .png: "PNG"
        case .tiff: "TIFF"
        case .jpeg: "JPEG"
        }
    }

    public var uniformType: UTType {
        switch self {
        case .png: .png
        case .tiff: .tiff
        case .jpeg: .jpeg
        }
    }

    public static func inferred(from url: URL) -> ImageExportFormat {
        switch url.pathExtension.lowercased() {
        case "tif", "tiff": .tiff
        case "jpg", "jpeg": .jpeg
        default: .png
        }
    }
}

public enum ImagePipelineError: Error, LocalizedError, Equatable {
    case unreadableImage
    case invalidDimensions
    case imageTooLarge
    case cannotCreateWorkingImage
    case cannotEncodeImage

    public var errorDescription: String? {
        switch self {
        case .unreadableImage:
            "This image could not be read. Try a JPEG, PNG, TIFF, or HEIC file."
        case .invalidDimensions:
            "This image has invalid pixel dimensions. Try a different file."
        case .imageTooLarge:
            "This image is too large to process safely. Try a smaller file."
        case .cannotCreateWorkingImage:
            "The image could not be converted to the sRGB working space."
        case .cannotEncodeImage:
            "The enhanced image could not be exported in that format."
        }
    }
}

public enum ImagePipeline {
    private static let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
        CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    )
    private static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let cancellationStride = 16_384

    /// Decodes the first frame, applies its orientation, and converts it to 8-bit sRGB RGBA.
    public static func decode(_ data: Data) throws -> DecodedImage {
        try Task.checkCancellation()

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImagePipelineError.unreadableImage
        }
        guard CGImageSourceGetCount(source) > 0 else {
            throw ImagePipelineError.unreadableImage
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawWidth = (properties?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let rawHeight = (properties?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        guard rawWidth > 0, rawHeight > 0 else {
            throw ImagePipelineError.invalidDimensions
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(rawWidth, rawHeight),
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceShouldAllowFloat: false
        ]

        guard let orientedImage = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            thumbnailOptions as CFDictionary
        ) else {
            throw ImagePipelineError.unreadableImage
        }

        let width = orientedImage.width
        let height = orientedImage.height
        guard width > 0, height > 0 else {
            throw ImagePipelineError.invalidDimensions
        }

        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        let (byteCount, byteOverflow) = pixelCount.multipliedReportingOverflow(by: 4)
        guard !pixelOverflow, !byteOverflow, byteCount <= 2_000_000_000 else {
            throw ImagePipelineError.imageTooLarge
        }

        var rgba = Data(count: byteCount)
        let drewImage = rgba.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return false
            }

            context.setBlendMode(.copy)
            context.interpolationQuality = .high
            context.draw(orientedImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drewImage else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }

        try Task.checkCancellation()
        guard let originalImage = makeImage(width: width, height: height, rgba: rgba) else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }

        let hasAlpha = rgba.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            var index = 3
            while index < bytes.count {
                if bytes[index] != 255 { return true }
                index += 4
            }
            return false
        }

        return DecodedImage(
            width: width,
            height: height,
            sourceTypeIdentifier: CGImageSourceGetType(source) as String?,
            hasAlpha: hasAlpha,
            originalImage: originalImage,
            rgba8Premultiplied: rgba
        )
    }

    /// Applies the covariance-based RGB decorrelation stretch without changing source pixels.
    public static func enhance(_ source: DecodedImage) throws -> EnhancedImage {
        try Task.checkCancellation()

        var accumulator = RunningCovariance3()
        try source.rgba8Premultiplied.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for pixelIndex in 0..<source.pixelCount {
                if pixelIndex.isMultiple(of: cancellationStride) {
                    try Task.checkCancellation()
                }
                let offset = pixelIndex * 4
                try accumulator.add(unpremultipliedRGB(bytes: bytes, offset: offset))
            }
        }

        let plan = try DecorrelationStretch.makePlan(accumulator: accumulator)
        if plan.isDegenerate {
            return EnhancedImage(
                image: source.originalImage,
                analysis: analysis(for: plan, outputScale: 1),
                notice: "Not enough color variation to enhance this image.",
                rgba8Premultiplied: source.rgba8Premultiplied
            )
        }

        var minimum = Double.infinity
        var maximum = -Double.infinity
        try source.rgba8Premultiplied.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for pixelIndex in 0..<source.pixelCount {
                if pixelIndex.isMultiple(of: cancellationStride) {
                    try Task.checkCancellation()
                }
                let offset = pixelIndex * 4
                let transformed = plan.transformed(unpremultipliedRGB(bytes: bytes, offset: offset))
                minimum = min(minimum, transformed.x, transformed.y, transformed.z)
                maximum = max(maximum, transformed.x, transformed.y, transformed.z)
            }
        }

        let range = maximum - minimum
        guard range.isFinite else {
            throw DecorrelationStretchError.nonFiniteInput
        }
        let outputScale = range > DecorrelationStretch.absoluteVarianceFloor ? 1 / range : 1
        var output = Data(count: source.pixelCount * 4)

        if range <= DecorrelationStretch.absoluteVarianceFloor {
            output = source.rgba8Premultiplied
        } else {
            try source.rgba8Premultiplied.withUnsafeBytes { sourceBuffer in
                try output.withUnsafeMutableBytes { outputBuffer in
                    let sourceBytes = sourceBuffer.bindMemory(to: UInt8.self)
                    let outputBytes = outputBuffer.bindMemory(to: UInt8.self)
                    for pixelIndex in 0..<source.pixelCount {
                        if pixelIndex.isMultiple(of: cancellationStride) {
                            try Task.checkCancellation()
                        }
                        let offset = pixelIndex * 4
                        let value = plan.transformed(unpremultipliedRGB(bytes: sourceBytes, offset: offset))
                        let alpha = sourceBytes[offset + 3]
                        outputBytes[offset] = premultipliedByte(
                            normalized: (value.x - minimum) * outputScale,
                            alpha: alpha
                        )
                        outputBytes[offset + 1] = premultipliedByte(
                            normalized: (value.y - minimum) * outputScale,
                            alpha: alpha
                        )
                        outputBytes[offset + 2] = premultipliedByte(
                            normalized: (value.z - minimum) * outputScale,
                            alpha: alpha
                        )
                        outputBytes[offset + 3] = alpha
                    }
                }
            }
        }

        try Task.checkCancellation()
        guard let image = makeImage(width: source.width, height: source.height, rgba: output) else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }

        return EnhancedImage(
            image: image,
            analysis: analysis(for: plan, outputScale: outputScale),
            notice: nil,
            rgba8Premultiplied: output
        )
    }

    public static func encodedData(
        for image: CGImage,
        format: ImageExportFormat,
        jpegQuality: Double = 0.94
    ) throws -> Data {
        try Task.checkCancellation()
        let imageToEncode: CGImage
        if format == .jpeg {
            guard let flattened = opaqueImage(from: image) else {
                throw ImagePipelineError.cannotEncodeImage
            }
            imageToEncode = flattened
        } else {
            imageToEncode = image
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            format.uniformType.identifier as CFString,
            1,
            nil
        ) else {
            throw ImagePipelineError.cannotEncodeImage
        }

        var properties: [CFString: Any] = [kCGImagePropertyOrientation: 1]
        if format == .jpeg {
            properties[kCGImageDestinationLossyCompressionQuality] = min(1, max(0, jpegQuality))
        }
        CGImageDestinationAddImage(destination, imageToEncode, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImagePipelineError.cannotEncodeImage
        }
        try Task.checkCancellation()
        return output as Data
    }

    private static func analysis(for plan: StretchPlan, outputScale: Double) -> StretchAnalysis {
        StretchAnalysis(
            mean: plan.mean,
            covariance: plan.covariance,
            eigenvalues: plan.eigenvalues,
            eigenvectors: plan.eigenvectors,
            stableComponentCount: plan.stableComponentCount,
            outputScale: outputScale,
            isDegenerate: plan.isDegenerate
        )
    }

    @inline(__always)
    private static func unpremultipliedRGB(
        bytes: UnsafeBufferPointer<UInt8>,
        offset: Int
    ) -> SIMD3<Double> {
        let alpha = bytes[offset + 3]
        guard alpha > 0 else { return .zero }
        let alphaScale = 1 / Double(alpha)
        return SIMD3(
            min(1, Double(bytes[offset]) * alphaScale),
            min(1, Double(bytes[offset + 1]) * alphaScale),
            min(1, Double(bytes[offset + 2]) * alphaScale)
        )
    }

    @inline(__always)
    private static func premultipliedByte(normalized: Double, alpha: UInt8) -> UInt8 {
        let clamped = normalized.clampedToUnit
        return UInt8((clamped * Double(alpha)).rounded())
    }

    private static func makeImage(width: Int, height: Int, rgba: Data) -> CGImage? {
        guard let provider = CGDataProvider(data: rgba as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .relativeColorimetric
        )
    }

    private static func opaqueImage(from image: CGImage) -> CGImage? {
        var rgba = Data(count: image.width * image.height * 4)
        let rendered = rgba.withUnsafeMutableBytes { rawBuffer -> Bool in
            guard let baseAddress = rawBuffer.baseAddress else { return false }
            guard let context = CGContext(
                data: baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo.rawValue
            ) else {
                return false
            }
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard rendered else { return nil }
        return makeImage(width: image.width, height: image.height, rgba: rgba)
    }
}
