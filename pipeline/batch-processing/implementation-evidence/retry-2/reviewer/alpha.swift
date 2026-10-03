import Foundation
import CoreGraphics
import ImageIO
import Darwin
setbuf(stdout, nil)
func unwrap<T>(_ x: T?) -> T { return x! }
func parityFixture(bits: Int, alpha: Bool, profile: CFString) throws -> CGImage {
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
        return unwrap(CGImage(width: width, height: height, bitsPerComponent: bits, bitsPerPixel: bits * 4,
                                    bytesPerRow: width * 4 * componentBytes, space: unwrap(CGColorSpace(name: profile)),
                                    bitmapInfo: bitmap, provider: unwrap(CGDataProvider(data: data as CFData)),
                                    decode: nil, shouldInterpolate: false, intent: .relativeColorimetric))
    }


func describe(_ label:String, _ image:CGImage) {
    print("FORMAT \(label) bpc=\(image.bitsPerComponent) bpp=\(image.bitsPerPixel) row=\(image.bytesPerRow) bitmap=\(image.bitmapInfo.rawValue) alpha=\(image.alphaInfo.rawValue) space=\(String(describing:image.colorSpace!.name))")
}
func render(_ image:CGImage,bits:Int,alpha:CGImageAlphaInfo = .premultipliedLast) -> CGImage {
    let bitmap = (bits == 8 ? CGBitmapInfo.byteOrder32Big : .byteOrder16Little).union(.init(rawValue:alpha.rawValue))
    let ctx = CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:bits,bytesPerRow:image.width*bits/8*4,space:bits == 16 ? image.colorSpace! : CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:bitmap.rawValue)!
    ctx.setBlendMode(.copy);ctx.interpolationQuality = .high
    ctx.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
    return ctx.makeImage()!
}
func rgba(_ image:CGImage)->Data { render(image,bits:8).dataProvider!.data! as Data }
for profile in [CGColorSpace.sRGB,CGColorSpace.displayP3,CGColorSpace.adobeRGB1998] {
    let image = try parityFixture(bits:16,alpha:true,profile:profile)
    let data = NSMutableData()
    let dest = CGImageDestinationCreateWithData(data,"public.png" as CFString,1,nil)!
    CGImageDestinationAddImage(dest,image,nil);precondition(CGImageDestinationFinalize(dest))
    let source = CGImageSourceCreateWithData(data,[kCGImageSourceShouldCache:false] as CFDictionary)!
    let direct = CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false,kCGImageSourceShouldAllowFloat:false] as CFDictionary)!
    let thumb = CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:64,kCGImageSourceShouldCacheImmediately:true,kCGImageSourceShouldAllowFloat:false] as CFDictionary)!
    describe("direct",direct);describe("thumb",thumb)
    let expected=rgba(thumb)
    for (label,candidate) in [("direct",rgba(direct)),("16-intermediate",rgba(render(direct,bits:16)))] {
        let deltas=zip(expected,candidate).map{abs(Int($0)-Int($1))}
        print("DIFF \(profile) \(label) count=\(deltas.filter{$0 != 0}.count) max=\(deltas.max()!)")
    }
    let native=direct.dataProvider!.data! as Data, nativeThumb=thumb.dataProvider!.data! as Data
    try native.write(to:URL(fileURLWithPath:"/tmp/klt-decode-review/direct-\(profile).bin"))
    try nativeThumb.write(to:URL(fileURLWithPath:"/tmp/klt-decode-review/thumb-\(profile).bin"))
    try expected.write(to:URL(fileURLWithPath:"/tmp/klt-decode-review/expected-\(profile).bin"))
    try rgba(direct).write(to:URL(fileURLWithPath:"/tmp/klt-decode-review/drawn-\(profile).bin"))
}
