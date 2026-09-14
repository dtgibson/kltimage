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
    public let analysisSourceFingerprint: AnalysisSourceFingerprint

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
    public let descriptor: AnalysisDescriptor
    public let notice: String?
    public let appliedMethod: AppliedMethodSnapshot?
    public let replayDiagnostics: ReplayDiagnostics?

    let rgba8Premultiplied: Data

    init(
        image: CGImage,
        analysis: StretchAnalysis,
        descriptor: AnalysisDescriptor,
        notice: String?,
        appliedMethod: AppliedMethodSnapshot? = nil,
        replayDiagnostics: ReplayDiagnostics? = nil,
        rgba8Premultiplied: Data
    ) {
        self.image = image
        self.analysis = analysis
        self.descriptor = descriptor
        self.notice = notice
        self.appliedMethod = appliedMethod
        self.replayDiagnostics = replayDiagnostics
        self.rgba8Premultiplied = rgba8Premultiplied
    }
}

/// The supported boundary for the app's full-frame, in-memory image pipeline.
public enum ImageProcessingLimits {
    /// A 64 MP frame occupies 256 MB as 8-bit RGBA. The ceiling leaves room for
    /// the source, enhanced result, decoder storage, and export working buffers
    /// on the lowest-memory supported Mac class.
    public static let maximumPixelCount = 64_000_000

    private static let rgbaBytesPerPixel = 4

    /// Validates declared or decoded dimensions and returns the required RGBA bytes.
    public static func checkedRGBAByteCount(width: Int, height: Int) throws -> Int {
        guard width > 0, height > 0 else {
            throw ImagePipelineError.invalidDimensions
        }

        let (pixelCount, pixelOverflow) = width.multipliedReportingOverflow(by: height)
        guard !pixelOverflow, pixelCount <= maximumPixelCount else {
            throw ImagePipelineError.imageTooLarge
        }

        let (byteCount, byteOverflow) = pixelCount.multipliedReportingOverflow(
            by: rgbaBytesPerPixel
        )
        guard !byteOverflow else {
            throw ImagePipelineError.imageTooLarge
        }
        return byteCount
    }
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
            "This image exceeds KLT Image's 64-megapixel processing limit. Try a smaller file."
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

        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
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

        // Reject from metadata before ImageIO is asked for a full-resolution decode.
        _ = try ImageProcessingLimits.checkedRGBAByteCount(
            width: rawWidth,
            height: rawHeight
        )

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
        // Revalidate the decoder's actual output before allocating the app-owned buffer.
        let byteCount = try ImageProcessingLimits.checkedRGBAByteCount(
            width: width,
            height: height
        )

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
        let fingerprint = try AnalysisSourceFingerprint.sha256(
            width: width,
            height: height,
            rgba8Premultiplied: rgba
        )

        return DecodedImage(
            width: width,
            height: height,
            sourceTypeIdentifier: CGImageSourceGetType(source) as String?,
            hasAlpha: hasAlpha,
            originalImage: originalImage,
            analysisSourceFingerprint: fingerprint,
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
                analysis: analysis(for: plan, outputMapping: .limitedVariationIdentity),
                descriptor: descriptor(
                    input: .baseline,
                    samplePixelCount: source.pixelCount,
                    plan: plan
                ),
                notice: "Not enough color variation to enhance this image.",
                appliedMethod: .calculated(
                    workingSpace: WorkingSpaceCatalog.standardRGB.revision,
                    workingSpaceName: WorkingSpaceCatalog.standardRGB.libraryName
                ),
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
            analysis: analysis(
                for: plan,
                outputMapping: .rgbGlobalRange(
                    minimum: minimum,
                    maximum: maximum,
                    scale: outputScale
                )
            ),
            descriptor: descriptor(
                input: .baseline,
                samplePixelCount: source.pixelCount,
                plan: plan
            ),
            notice: nil,
            appliedMethod: .calculated(
                workingSpace: WorkingSpaceCatalog.standardRGB.revision,
                workingSpaceName: WorkingSpaceCatalog.standardRGB.libraryName
            ),
            rgba8Premultiplied: output
        )
    }

    /// Applies one explicit analysis request to the immutable decoded source.
    /// The baseline overload above remains its original arithmetic path so its
    /// output bytes cannot drift as new methods are added.
    public static func enhance(_ source: DecodedImage, input: AnalysisInput) throws -> EnhancedImage {
        if input == .baseline {
            return try enhance(source)
        }

        try Task.checkCancellation()
        let validatedRegion: ValidatedSourcePixelRegion?
        switch input.sampleSource {
        case .wholeImage:
            validatedRegion = nil
        case .selectedRegion:
            validatedRegion = try SourcePixelRegionValidator.validate(
                input.region,
                sourceWidth: source.width,
                sourceHeight: source.height
            )
        }

        var accumulator = RunningCovariance3()
        try source.rgba8Premultiplied.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let minimumX = validatedRegion?.bounds.x ?? 0
            let maximumX = minimumX + (validatedRegion?.bounds.width ?? source.width)
            let minimumY = validatedRegion?.bounds.y ?? 0
            let maximumY = minimumY + (validatedRegion?.bounds.height ?? source.height)
            var sampled = 0
            for y in minimumY..<maximumY {
                for x in minimumX..<maximumX {
                    if sampled.isMultiple(of: cancellationStride) {
                        try Task.checkCancellation()
                    }
                    let offset = ((y * source.width) + x) * 4
                    switch input.method.colorSpace {
                    case .rgb:
                        try accumulator.add(unpremultipliedRGB(bytes: bytes, offset: offset))
                    case .lab:
                        try accumulator.add(
                            CIELabD65.fromPremultipliedSRGB(bytes: bytes, offset: offset)
                        )
                    }
                    sampled += 1
                }
            }
        }

        let plan = try DecorrelationStretch.makePlan(
            accumulator: accumulator,
            matrixMode: input.method.matrixMode
        )
        if plan.isDegenerate {
            if input.sampleSource == .selectedRegion {
                throw RegionValidationIssue.insufficientVariation(
                    stableComponentCount: plan.stableComponentCount
                )
            }
            return EnhancedImage(
                image: source.originalImage,
                analysis: analysis(for: plan, outputMapping: .limitedVariationIdentity),
                descriptor: descriptor(
                    input: input,
                    samplePixelCount: source.pixelCount,
                    plan: plan
                ),
                notice: "Not enough color variation to enhance this image.",
                appliedMethod: .calculated(
                    workingSpace: input.method.colorSpace == .rgb
                        ? WorkingSpaceCatalog.standardRGB.revision
                        : WorkingSpaceCatalog.standardLabD65.revision,
                    workingSpaceName: input.method.colorSpace.displayName
                ),
                rgba8Premultiplied: source.rgba8Premultiplied
            )
        }

        let output: Data
        let outputMapping: StretchOutputMapping
        switch input.method.colorSpace {
        case .rgb:
            let rendered = try renderRGB(source: source, plan: plan)
            output = rendered.data
            outputMapping = .rgbGlobalRange(
                minimum: rendered.minimum,
                maximum: rendered.maximum,
                scale: rendered.scale
            )
        case .lab:
            output = try renderLab(source: source, plan: plan)
            outputMapping = .labD65ToSRGB
        }

        try Task.checkCancellation()
        guard let image = makeImage(width: source.width, height: source.height, rgba: output) else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }

        let resultDescriptor = descriptor(
            input: input,
            samplePixelCount: validatedRegion?.pixelCount ?? source.pixelCount,
            plan: plan
        )
        let notice = resultDescriptor.hasLimitedVariation
            ? "Limited variation: \(plan.stableComponentCount) of 3 components are stable."
            : nil
        return EnhancedImage(
            image: image,
            analysis: analysis(for: plan, outputMapping: outputMapping),
            descriptor: resultDescriptor,
            notice: notice,
            appliedMethod: .calculated(
                workingSpace: input.method.colorSpace == .rgb
                    ? WorkingSpaceCatalog.standardRGB.revision
                    : WorkingSpaceCatalog.standardLabD65.revision,
                workingSpaceName: input.method.colorSpace.displayName
            ),
            rgba8Premultiplied: output
        )
    }

    /// Applies a tagged calculation request. Standard RGB and Lab requests are
    /// routed through their shipped arithmetic paths; affine spaces use the
    /// validated generic coordinate path.
    public static func enhance(
        _ source: DecodedImage,
        request: CalculatedAnalysisRequest,
        workingSpaceName: String? = nil
    ) throws -> EnhancedImage {
        if let input = request.compatibilityInput {
            return try enhance(source, input: input)
        }

        guard case let .affine(revision) = request.workingSpace else {
            throw WorkingSpaceValidationIssue.invalidIdentity
        }
        _ = try WorkingSpaceValidator.validate(revision)
        try Task.checkCancellation()

        let validatedRegion = try validatedRegion(
            source: source,
            sampleSource: request.sampleSource,
            region: request.region
        )
        var accumulator = RunningCovariance3()
        try source.rgba8Premultiplied.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            let minimumX = validatedRegion?.bounds.x ?? 0
            let maximumX = minimumX + (validatedRegion?.bounds.width ?? source.width)
            let minimumY = validatedRegion?.bounds.y ?? 0
            let maximumY = minimumY + (validatedRegion?.bounds.height ?? source.height)
            var sampled = 0
            for y in minimumY..<maximumY {
                for x in minimumX..<maximumX {
                    if sampled.isMultiple(of: cancellationStride) { try Task.checkCancellation() }
                    let offset = ((y * source.width) + x) * 4
                    let base = try baseValue(revision.base, bytes: bytes, offset: offset)
                    let working = revision.forwardMap(base)
                    guard working.x.isFinite, working.y.isFinite, working.z.isFinite else {
                        throw DecorrelationStretchError.nonFiniteInput
                    }
                    try accumulator.add(working)
                    sampled += 1
                }
            }
        }

        let plan = try DecorrelationStretch.makePlan(
            accumulator: accumulator,
            matrixMode: request.matrixMode
        )
        let compatibilityInput = AnalysisInput(
            method: AnalysisMethod(
                colorSpace: revision.base == .encodedSRGB ? .rgb : .lab,
                matrixMode: request.matrixMode
            ),
            sampleSource: request.sampleSource,
            region: request.region
        )
        if plan.isDegenerate {
            if request.sampleSource == .selectedRegion {
                throw RegionValidationIssue.insufficientVariation(
                    stableComponentCount: plan.stableComponentCount
                )
            }
            return EnhancedImage(
                image: source.originalImage,
                analysis: analysis(for: plan, outputMapping: .limitedVariationIdentity),
                descriptor: descriptor(
                    input: compatibilityInput,
                    samplePixelCount: source.pixelCount,
                    plan: plan
                ),
                notice: "Not enough color variation to enhance this image.",
                appliedMethod: .calculated(
                    workingSpace: revision,
                    workingSpaceName: workingSpaceName ?? revision.identity.identifier
                ),
                rgba8Premultiplied: source.rgba8Premultiplied
            )
        }

        let frozen: FrozenOutputMapping
        let output: Data
        switch revision.outputBehavior {
        case .encodedSRGBGlobalRangeV1:
            let extrema = try affineExtrema(source: source, revision: revision, plan: plan)
            let range = extrema.maximum - extrema.minimum
            guard range.isFinite, range > DecorrelationStretch.absoluteVarianceFloor else {
                throw DecorrelationStretchError.nonFiniteInput
            }
            let scale = 1 / range
            frozen = .encodedSRGBGlobalRangeV1(
                minimum: extrema.minimum,
                maximum: extrema.maximum,
                scale: scale,
                clipsToUnitRange: true
            )
            output = try renderFrozen(
                source: source,
                revision: revision,
                center: plan.mean,
                transform: plan.transform,
                outputMapping: frozen
            ).data
        case .cieLabD65ToClippedSRGBV1:
            frozen = .cieLabD65ToClippedSRGBV1(
                referenceWhite: TransformRecipeValidator.d65ReferenceWhite,
                clipsFiniteOutOfGamutValues: true
            )
            output = try renderFrozen(
                source: source,
                revision: revision,
                center: plan.mean,
                transform: plan.transform,
                outputMapping: frozen
            ).data
        }
        guard let image = makeImage(width: source.width, height: source.height, rgba: output) else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }
        let resultDescriptor = descriptor(
            input: compatibilityInput,
            samplePixelCount: validatedRegion?.pixelCount ?? source.pixelCount,
            plan: plan
        )
        let outputMapping: StretchOutputMapping
        switch frozen {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, _):
            outputMapping = .rgbGlobalRange(minimum: minimum, maximum: maximum, scale: scale)
        case .cieLabD65ToClippedSRGBV1:
            outputMapping = .labD65ToSRGB
        }
        return EnhancedImage(
            image: image,
            analysis: analysis(for: plan, outputMapping: outputMapping),
            descriptor: resultDescriptor,
            notice: resultDescriptor.hasLimitedVariation
                ? "Limited variation: \(plan.stableComponentCount) of 3 components are stable."
                : nil,
            appliedMethod: .calculated(
                workingSpace: revision,
                workingSpaceName: workingSpaceName ?? revision.identity.identifier
            ),
            rgba8Premultiplied: output
        )
    }

    /// Applies only the recipe's frozen values. No target covariance,
    /// eigensystem, center, extrema, range, or gamut fit is calculated.
    public static func replay(
        _ source: DecodedImage,
        recipe: TransformRecipeSnapshot,
        recipeName: String = "Saved Transform"
    ) throws -> EnhancedImage {
        try TransformRecipeValidator.validate(recipe)
        try Task.checkCancellation()
        let rendered = try renderFrozen(
            source: source,
            revision: recipe.workingSpace,
            center: recipe.workingCenter,
            transform: recipe.transform,
            outputMapping: recipe.outputMapping
        )
        guard let image = makeImage(width: source.width, height: source.height, rgba: rendered.data) else {
            throw ImagePipelineError.cannotCreateWorkingImage
        }
        let sameAsOrigin = source.width == recipe.originSource.width
            && source.height == recipe.originSource.height
            && source.analysisSourceFingerprint == recipe.originSource.fingerprint
        let diagnostics = ReplayDiagnostics(
            sameAsOrigin: sameAsOrigin,
            evaluatedPixelCount: rendered.evaluatedPixelCount,
            clippedColorPixelCount: rendered.clippedColorPixelCount,
            clippedFraction: rendered.evaluatedPixelCount == 0
                ? 0
                : Double(rendered.clippedColorPixelCount) / Double(rendered.evaluatedPixelCount),
            minimumMappedComponent: rendered.minimumMappedComponent,
            maximumMappedComponent: rendered.maximumMappedComponent,
            mappedRange: rendered.minimumMappedComponent.flatMap { minimum in
                rendered.maximumMappedComponent.map { $0 - minimum }
            }
        )
        let input = AnalysisInput(
            method: AnalysisMethod(
                colorSpace: recipe.workingSpace.base == .encodedSRGB ? .rgb : .lab,
                matrixMode: recipe.originatingAnalysis.matrixMode
            ),
            sampleSource: recipe.originatingAnalysis.samplingMode,
            region: recipe.originatingAnalysis.region?.sourcePixels
        )
        let mapping: StretchOutputMapping
        switch recipe.outputMapping {
        case let .encodedSRGBGlobalRangeV1(minimum, maximum, scale, _):
            mapping = .rgbGlobalRange(minimum: minimum, maximum: maximum, scale: scale)
        case .cieLabD65ToClippedSRGBV1:
            mapping = .labD65ToSRGB
        }
        let replayAnalysis = StretchAnalysis(
            mean: recipe.workingCenter,
            covariance: Matrix3x3(),
            analysisMatrix: Matrix3x3(),
            eigenvalues: .zero,
            eigenvectors: .identity,
            transform: recipe.transform,
            stableVariableCount: 0,
            stableComponentCount: 0,
            outputScale: {
                if case let .encodedSRGBGlobalRangeV1(_, _, scale, _) = recipe.outputMapping { return scale }
                return 1
            }(),
            outputMapping: mapping,
            isDegenerate: false
        )
        let descriptor = AnalysisDescriptor(
            input: input,
            samplePixelCount: recipe.originatingAnalysis.samplePixelCount,
            stableVariableCount: 0,
            stableComponentCount: 0,
            hasLimitedVariation: false
        )
        var notices = [String]()
        if diagnostics.hasSubstantialClipping {
            notices.append(String(format: "%.1f%% of target pixels clip under this frozen recipe.", diagnostics.clippedFraction * 100))
        } else if diagnostics.clippedColorPixelCount > 0 {
            notices.append("Some target colors clip under this frozen recipe.")
        }
        if diagnostics.hasLowContrast { notices.append("The frozen recipe produces low contrast on this target.") }
        return EnhancedImage(
            image: image,
            analysis: replayAnalysis,
            descriptor: descriptor,
            notice: notices.isEmpty ? nil : notices.joined(separator: " "),
            appliedMethod: .replayed(recipe: recipe, recipeName: recipeName, diagnostics: diagnostics),
            replayDiagnostics: diagnostics,
            rgba8Premultiplied: rendered.data
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

    private static func analysis(
        for plan: StretchPlan,
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

    private static func descriptor(
        input: AnalysisInput,
        samplePixelCount: Int,
        plan: StretchPlan
    ) -> AnalysisDescriptor {
        AnalysisDescriptor(
            input: input,
            samplePixelCount: samplePixelCount,
            stableVariableCount: plan.stableVariableCount,
            stableComponentCount: plan.stableComponentCount,
            hasLimitedVariation: plan.stableVariableCount < 3 || plan.stableComponentCount < 3
        )
    }

    private static func validatedRegion(
        source: DecodedImage,
        sampleSource: AnalysisSampleSource,
        region: SourcePixelRegion?
    ) throws -> ValidatedSourcePixelRegion? {
        switch sampleSource {
        case .wholeImage: return nil
        case .selectedRegion:
            return try SourcePixelRegionValidator.validate(
                region,
                sourceWidth: source.width,
                sourceHeight: source.height
            )
        }
    }

    @inline(__always)
    private static func baseValue(
        _ base: WorkingSpaceBase,
        bytes: UnsafeBufferPointer<UInt8>,
        offset: Int
    ) throws -> SIMD3<Double> {
        switch base {
        case .encodedSRGB: unpremultipliedRGB(bytes: bytes, offset: offset)
        case .cieLabD65: try CIELabD65.fromPremultipliedSRGB(bytes: bytes, offset: offset)
        }
    }

    @inline(__always)
    private static func applyFrozen(
        base: SIMD3<Double>,
        revision: WorkingSpaceRevision,
        center: SIMD3<Double>,
        transform: Matrix3x3
    ) throws -> SIMD3<Double> {
        let working = revision.forwardMap(base)
        let transformed = center + (transform * (working - center))
        let recovered = revision.inverseMap(transformed)
        guard recovered.x.isFinite, recovered.y.isFinite, recovered.z.isFinite else {
            throw DecorrelationStretchError.nonFiniteInput
        }
        return recovered
    }

    private static func affineExtrema(
        source: DecodedImage,
        revision: WorkingSpaceRevision,
        plan: StretchPlan
    ) throws -> (minimum: Double, maximum: Double) {
        var minimum = Double.infinity
        var maximum = -Double.infinity
        try source.rgba8Premultiplied.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for pixelIndex in 0..<source.pixelCount {
                if pixelIndex.isMultiple(of: cancellationStride) { try Task.checkCancellation() }
                let offset = pixelIndex * 4
                let base = try baseValue(revision.base, bytes: bytes, offset: offset)
                let recovered = try applyFrozen(
                    base: base,
                    revision: revision,
                    center: plan.mean,
                    transform: plan.transform
                )
                minimum = min(minimum, recovered.x, recovered.y, recovered.z)
                maximum = max(maximum, recovered.x, recovered.y, recovered.z)
            }
        }
        guard minimum.isFinite, maximum.isFinite else {
            throw DecorrelationStretchError.nonFiniteInput
        }
        return (minimum, maximum)
    }

    private struct FrozenRenderResult {
        let data: Data
        let evaluatedPixelCount: Int
        let clippedColorPixelCount: Int
        let minimumMappedComponent: Double?
        let maximumMappedComponent: Double?
    }

    private static func renderFrozen(
        source: DecodedImage,
        revision: WorkingSpaceRevision,
        center: SIMD3<Double>,
        transform: Matrix3x3,
        outputMapping: FrozenOutputMapping
    ) throws -> FrozenRenderResult {
        var output = Data(count: source.pixelCount * 4)
        var evaluated = 0
        var clipped = 0
        var minimum = Double.infinity
        var maximum = -Double.infinity
        try source.rgba8Premultiplied.withUnsafeBytes { sourceBuffer in
            try output.withUnsafeMutableBytes { outputBuffer in
                let sourceBytes = sourceBuffer.bindMemory(to: UInt8.self)
                let outputBytes = outputBuffer.bindMemory(to: UInt8.self)
                for pixelIndex in 0..<source.pixelCount {
                    if pixelIndex.isMultiple(of: cancellationStride) { try Task.checkCancellation() }
                    let offset = pixelIndex * 4
                    let alpha = sourceBytes[offset + 3]
                    let base = try baseValue(revision.base, bytes: sourceBytes, offset: offset)
                    let recovered = try applyFrozen(
                        base: base,
                        revision: revision,
                        center: center,
                        transform: transform
                    )
                    let mapped: SIMD3<Double>
                    switch outputMapping {
                    case let .encodedSRGBGlobalRangeV1(minimum, _, scale, _):
                        mapped = (recovered - SIMD3<Double>(repeating: minimum)) * scale
                    case .cieLabD65ToClippedSRGBV1:
                        mapped = try CIELabD65.toSRGB(recovered)
                    }
                    guard mapped.x.isFinite, mapped.y.isFinite, mapped.z.isFinite else {
                        throw DecorrelationStretchError.nonFiniteInput
                    }
                    if alpha > 0 {
                        evaluated += 1
                        minimum = min(minimum, mapped.x, mapped.y, mapped.z)
                        maximum = max(maximum, mapped.x, mapped.y, mapped.z)
                        if mapped.x < 0 || mapped.x > 1 || mapped.y < 0 || mapped.y > 1 || mapped.z < 0 || mapped.z > 1 {
                            clipped += 1
                        }
                    }
                    outputBytes[offset] = premultipliedByte(normalized: mapped.x, alpha: alpha)
                    outputBytes[offset + 1] = premultipliedByte(normalized: mapped.y, alpha: alpha)
                    outputBytes[offset + 2] = premultipliedByte(normalized: mapped.z, alpha: alpha)
                    outputBytes[offset + 3] = alpha
                }
            }
        }
        return FrozenRenderResult(
            data: output,
            evaluatedPixelCount: evaluated,
            clippedColorPixelCount: clipped,
            minimumMappedComponent: evaluated == 0 ? nil : minimum,
            maximumMappedComponent: evaluated == 0 ? nil : maximum
        )
    }

    private static func renderRGB(
        source: DecodedImage,
        plan: StretchPlan
    ) throws -> (data: Data, minimum: Double, maximum: Double, scale: Double) {
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
                guard transformed.x.isFinite, transformed.y.isFinite, transformed.z.isFinite else {
                    throw DecorrelationStretchError.nonFiniteInput
                }
                minimum = min(minimum, transformed.x, transformed.y, transformed.z)
                maximum = max(maximum, transformed.x, transformed.y, transformed.z)
            }
        }

        let range = maximum - minimum
        guard range.isFinite else { throw DecorrelationStretchError.nonFiniteInput }
        let outputScale = range > DecorrelationStretch.absoluteVarianceFloor ? 1 / range : 1
        guard range > DecorrelationStretch.absoluteVarianceFloor else {
            return (source.rgba8Premultiplied, minimum, maximum, outputScale)
        }

        var output = Data(count: source.pixelCount * 4)
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
        return (output, minimum, maximum, outputScale)
    }

    private static func renderLab(source: DecodedImage, plan: StretchPlan) throws -> Data {
        var output = Data(count: source.pixelCount * 4)
        try source.rgba8Premultiplied.withUnsafeBytes { sourceBuffer in
            try output.withUnsafeMutableBytes { outputBuffer in
                let sourceBytes = sourceBuffer.bindMemory(to: UInt8.self)
                let outputBytes = outputBuffer.bindMemory(to: UInt8.self)
                for pixelIndex in 0..<source.pixelCount {
                    if pixelIndex.isMultiple(of: cancellationStride) {
                        try Task.checkCancellation()
                    }
                    let offset = pixelIndex * 4
                    let lab = try CIELabD65.fromPremultipliedSRGB(
                        bytes: sourceBytes,
                        offset: offset
                    )
                    let transformed = plan.transformed(lab)
                    let rgb = try CIELabD65.toClippedSRGB(transformed)
                    let alpha = sourceBytes[offset + 3]
                    outputBytes[offset] = premultipliedByte(normalized: rgb.x, alpha: alpha)
                    outputBytes[offset + 1] = premultipliedByte(normalized: rgb.y, alpha: alpha)
                    outputBytes[offset + 2] = premultipliedByte(normalized: rgb.z, alpha: alpha)
                    outputBytes[offset + 3] = alpha
                }
            }
        }
        return output
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
