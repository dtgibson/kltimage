import Foundation
import Accelerate
import CoreGraphics
import ImageIO
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
    let dest = CGImageDestinationCreateWithURL(input as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    precondition(CGImageDestinationFinalize(dest))
}
sample("baseline mode=\(mode) pid=\(getpid())")
for item in 1...6 {
    let work = { try autoreleasepool {
        let file = base.appendingPathComponent("\(item).png")
        try FileManager.default.copyItem(at: input, to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            let source = CGImageSourceCreateWithURL(file as CFURL, [kCGImageSourceShouldCache:false] as CFDictionary)!
            var options:[CFString:Any] = [kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:6_000,kCGImageSourceShouldAllowFloat:false,kCGImageSourceShouldCacheImmediately:mode != "uncached"]
            if mode == "uncached" { options[kCGImageSourceShouldCache] = false }
            if mode == "unlimited" { options.removeValue(forKey: kCGImageSourceThumbnailMaxPixelSize) }
            let oriented = mode.hasPrefix("image") ? CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary)! : CGImageSourceCreateThumbnailAtIndex(source,0,options as CFDictionary)!
            if item == 1 {
                let direct = CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false] as CFDictionary)!
                for (label,i) in [("direct",direct),("thumbnail",oriented)] {
                    print("FORMAT \(label) bpc=\(i.bitsPerComponent) bpp=\(i.bitsPerPixel) row=\(i.bytesPerRow) bitmap=\(i.bitmapInfo.rawValue) alpha=\(i.alphaInfo.rawValue) color=\(String(describing:i.colorSpace!.name)) interpolate=\(i.shouldInterpolate) intent=\(i.renderingIntent.rawValue)")
                }
            }
            if mode == "nodraw" { precondition(oriented.width == 6000); return }
            if mode == "read" { let bytes = oriented.dataProvider!.data!; precondition(CFDataGetLength(bytes) > 0); return }
            let image:CGImage
            if mode == "deepcopy" || mode == "nointerpolate" || mode == "defaultintent" {
                let original = oriented.dataProvider!.data!
                let data = CFDataCreate(kCFAllocatorDefault, CFDataGetBytePtr(original), CFDataGetLength(original))!
                image = CGImage(width:oriented.width,height:oriented.height,bitsPerComponent:oriented.bitsPerComponent,bitsPerPixel:oriented.bitsPerPixel,bytesPerRow:oriented.bytesPerRow,space:oriented.colorSpace!,bitmapInfo:oriented.bitmapInfo,provider:CGDataProvider(data:data)!,decode:oriented.decode,shouldInterpolate:mode == "nointerpolate" ? false : oriented.shouldInterpolate,intent:mode == "defaultintent" ? .defaultIntent : oriented.renderingIntent)!
            } else { image = oriented }
            if mode == "rawbuffer" || mode == "nocopy" || mode == "copyout" || mode.hasPrefix("overlap") {
                let ptr = calloc(6_000*4_000,4)!
                do {
                    let c=CGContext(data:ptr,width:6000,height:4000,bitsPerComponent:8,bytesPerRow:24000,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)).rawValue)!
                    c.setBlendMode(.copy);c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:6000,height:4000))
                }
                if mode == "rawbuffer" { free(ptr) }
                else {
                    let owned:Data
                    if mode == "nocopy" || mode.hasPrefix("overlap") { owned = Data(bytesNoCopy:ptr,count:6000*4000*4,deallocator:.free) }
                    else { owned = Data(bytes:ptr,count:6000*4000*4); free(ptr) }
                    let cg = CGImage(width:6000,height:4000,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:24000,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)),provider:CGDataProvider(data:owned as CFData)!,decode:nil,shouldInterpolate:true,intent:.relativeColorimetric)!
                    print("BUFFER item=\(item) decoded=\(ptr)")
                    if mode.hasPrefix("overlap") {
                        var extra = mode == "overlapnocopy" ? Data(bytesNoCopy:calloc(6000*4000,4)!,count:6000*4000*4,deallocator:.free) : Data(count:6000*4000*4)
                        extra.withUnsafeMutableBytes { b in
                            b.baseAddress!.copyMemory(from:ptr,byteCount:6000*4000*4)
                            print("BUFFER item=\(item) enhancement=\(b.baseAddress!)")
                        }
                        if mode == "overlapdataonly" { withExtendedLifetime((extra,cg,owned)) { precondition(extra[3] == 255) }; return }
                        let enhanced = CGImage(width:6000,height:4000,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:24000,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)),provider:CGDataProvider(data:extra as CFData)!,decode:nil,shouldInterpolate:true,intent:.relativeColorimetric)!
                        withExtendedLifetime((extra,enhanced,cg,owned)) { precondition(extra[3] == 255 && enhanced.width == 6000) }
                    }
                    precondition(cg.width == 6000 && owned.count == 6000*4000*4 && owned[3] == 255)
                }
                return
            }
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
