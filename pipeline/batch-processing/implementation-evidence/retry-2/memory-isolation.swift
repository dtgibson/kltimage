import Foundation
import Accelerate
import CoreGraphics
import ImageIO
import KLTCore
import Darwin

func sample(_ label: String) {
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { p in
        p.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count) }
    }
    print("ISOLATION \(label) status=\(status) footprint=\(info.phys_footprint)")
    fflush(stdout)
}
let mode = CommandLine.arguments[1]
let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("klt-memory-isolation-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: base, withIntermediateDirectories: false)
defer { try? FileManager.default.removeItem(at: base) }
let input = base.appendingPathComponent("fixture.png")
try autoreleasepool {
    var data = Data(count: 6_000 * 4_000 * 4)
    data.withUnsafeMutableBytes { raw in
        let p = raw.bindMemory(to: UInt8.self)
        for i in 0..<(6_000 * 4_000) { p[4*i]=UInt8((i*37+17)%256); p[4*i+1]=UInt8((i*59+41)%256); p[4*i+2]=UInt8((i*83+73)%256); p[4*i+3]=255 }
    }
    let image = CGImage(width: 6_000,height: 4_000,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:24_000,space:CGColorSpace(name: CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)),provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
    try ImagePipeline.encodedData(for: image, format: .png).write(to: input)
}
sample("baseline mode=\(mode) pid=\(getpid())")
for item in 1...6 {
    let work = { try autoreleasepool {
        let file = base.appendingPathComponent("\(item).png")
        try FileManager.default.copyItem(at: input, to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        if ["core", "enhance", "encode"].contains(mode) {
            let decoded = try ImagePipeline.decode(at: file)
            precondition(decoded.width == 6_000 && decoded.height == 4_000)
            if mode != "core" {
                let enhanced = try ImagePipeline.enhance(decoded)
                if mode == "encode" { _ = try ImagePipeline.encode(enhanced.image,format:.png,maximumBytes:1_073_741_824) { _ in } }
            }
        } else {
            let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache:false] as CFDictionary)!
            var options:[CFString:Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:6_000,kCGImageSourceShouldAllowFloat:false,kCGImageSourceShouldCacheImmediately:mode != "uncached"]
            if mode == "uncached" { options[kCGImageSourceShouldCache] = false }
            if mode == "unlimited" { options.removeValue(forKey: kCGImageSourceThumbnailMaxPixelSize) }
            let oriented = mode.hasPrefix("image") ? CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary)! : CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary)!
            let image:CGImage
            if mode == "detached" {
                let data = oriented.dataProvider!.data!
                image = CGImage(width:oriented.width,height:oriented.height,bitsPerComponent:oriented.bitsPerComponent,bitsPerPixel:oriented.bitsPerPixel,bytesPerRow:oriented.bytesPerRow,space:oriented.colorSpace!,bitmapInfo:oriented.bitmapInfo,provider:CGDataProvider(data:data)!,decode:oriented.decode,shouldInterpolate:oriented.shouldInterpolate,intent:oriented.renderingIntent)!
            } else { image = oriented }
            var data = Data(count:6_000*4_000*4)
            data.withUnsafeMutableBytes { raw in
                if mode == "vimage" || mode == "imagevimage" {
                    var buffer = vImage_Buffer(data:raw.baseAddress!,height:4_000,width:6_000,rowBytes:24_000)
                    var format = vImage_CGImageFormat(bitsPerComponent:8,bitsPerPixel:32,colorSpace:Unmanaged.passUnretained(CGColorSpace(name:CGColorSpace.sRGB)!),bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)),version:0,decode:nil,renderingIntent:.defaultIntent)
                    precondition(vImageBuffer_InitWithCGImage(&buffer,&format,nil,image,vImage_Flags(kvImageNoAllocate)) == kvImageNoError)
                    return
                }
                let context = CGContext(data:raw.baseAddress!,width:6_000,height:4_000,bitsPerComponent:8,bytesPerRow:24_000,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)).rawValue)!
                context.setBlendMode(.copy); context.interpolationQuality = mode == "none" ? .none : .high
                context.draw(image,in:CGRect(x:0,y:0,width:6_000,height:4_000))
                if mode == "flush" { context.flush() }
            }
            if mode == "remove" { CGImageSourceRemoveCacheAtIndex(source,0) }
        }
    }
    }
    if mode == "thread" {
        let thread = Thread { try! work() }
        thread.start()
        while !thread.isFinished { usleep(1_000) }
    } else { try work() }
    if mode == "relief" { print("released=\(malloc_zone_pressure_relief(malloc_default_purgeable_zone(), 0))") }
    sample("item=\(item)")
}
if let seconds = ProcessInfo.processInfo.environment["QA_HOLD_SECONDS"].flatMap(Double.init) { Thread.sleep(forTimeInterval:seconds) }
