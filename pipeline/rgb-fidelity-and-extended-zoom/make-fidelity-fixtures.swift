// Generate deterministic sources and full-resolution references for GUI inspection.
// Compile against the locally built KLTCore framework; see implementation-record.md.
import Foundation
import CoreGraphics
import ImageIO
import KLTCore

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let width = 2053, height = 1537
var bytes = [UInt8](repeating: 255, count: width * height * 4)
for y in 0..<height {
    for x in 0..<width {
        let offset = (y * width + x) * 4
        // One-pixel color detail, wider stripes, and smooth regions in one source.
        let detail = x < width / 2 ? 1 : 8
        let px = x / detail, py = y / detail
        bytes[offset] = UInt8(100 + (px * 7 + py * 3) % 41)
        bytes[offset + 1] = UInt8(105 + (px * 3 + py * 11) % 37)
        bytes[offset + 2] = UInt8(110 + (px * 13 + py * 5) % 43)
    }
}
let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)),
                    provider: CGDataProvider(data: Data(bytes) as CFData)!, decode: nil,
                    shouldInterpolate: true, intent: .relativeColorimetric)!
for format in [ImageExportFormat.png, .jpeg] {
    let encoded = try ImagePipeline.encodedData(for: image, format: format)
    try encoded.write(to: directory.appendingPathComponent("source.\(format.filenameExtension)"))
    let source = try ImagePipeline.decode(encoded)
    for colorSpace in AnalysisColorSpace.allCases {
        for matrixMode in AnalysisMatrixMode.allCases {
            let input = AnalysisInput(method: AnalysisMethod(colorSpace: colorSpace, matrixMode: matrixMode),
                                      sampleSource: .wholeImage, region: nil)
            let result = try ImagePipeline.enhance(source, input: input)
            let name = "\(format.rawValue)-\(colorSpace.rawValue)-\(matrixMode.rawValue).png"
            try ImagePipeline.encodedData(for: result.image, format: .png)
                .write(to: directory.appendingPathComponent(name))
            print("\(name): \(result.image.width) × \(result.image.height)")
        }
    }
}
