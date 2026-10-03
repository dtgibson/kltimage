import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgba(_ image: CGImage) -> Data {
    var data = Data(count: image.width * image.height * 4)
    data.withUnsafeMutableBytes { raw in
        let c = CGContext(data:raw.baseAddress!,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)).rawValue)!
        c.setBlendMode(.copy);c.interpolationQuality = .high;c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
    }
    return data
}
func orientedDraw(_ image: CGImage, orientation: Int) -> Data {
    let sw=CGFloat(image.width), sh=CGFloat(image.height)
    let w=orientation >= 5 ? image.height : image.width, h=orientation >= 5 ? image.width : image.height
    var data=Data(count:w*h*4)
    data.withUnsafeMutableBytes { raw in
        let c=CGContext(data:raw.baseAddress!,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)).rawValue)!
        let transform:CGAffineTransform
        switch orientation {
        case 2:transform=CGAffineTransform(a:-1,b:0,c:0,d:1,tx:sw,ty:0)
        case 3:transform=CGAffineTransform(a:-1,b:0,c:0,d:-1,tx:sw,ty:sh)
        case 4:transform=CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:sh)
        case 5:transform=CGAffineTransform(a:0,b:-1,c:-1,d:0,tx:sh,ty:sw)
        case 6:transform=CGAffineTransform(a:0,b:-1,c:1,d:0,tx:0,ty:sw)
        case 7:transform=CGAffineTransform(a:0,b:1,c:1,d:0,tx:0,ty:0)
        case 8:transform=CGAffineTransform(a:0,b:1,c:-1,d:0,tx:sh,ty:0)
        default:transform = .identity
        }
        c.setBlendMode(.copy);c.interpolationQuality = .high;c.concatenate(transform)
        c.draw(image,in:CGRect(x:0,y:0,width:sw,height:sh))
    }
    return data
}
func permute(_ bytes: Data, width: Int, height: Int, orientation: Int) -> (Int,Int,Data) {
    let w = orientation >= 5 ? height : width, h = orientation >= 5 ? width : height
    var result = Data(count:bytes.count)
    bytes.withUnsafeBytes { src in result.withUnsafeMutableBytes { dst in
        let s=src.bindMemory(to:UInt32.self), d=dst.bindMemory(to:UInt32.self)
        for y in 0..<h { for x in 0..<w {
            let sx:Int, sy:Int
            switch orientation {
            case 2:sx=width-1-x;sy=y
            case 3:sx=width-1-x;sy=height-1-y
            case 4:sx=x;sy=height-1-y
            case 5:sx=y;sy=x
            case 6:sx=y;sy=height-1-x
            case 7:sx=width-1-y;sy=height-1-x
            case 8:sx=width-1-y;sy=x
            default:sx=x;sy=y
            }
            d[y*w+x]=s[sy*width+sx]
        }}
    }}
    return (w,h,result)
}
for orientation in 1...8 {
    autoreleasepool {
        var pixels = Data(count:64*48*4)
        pixels.withUnsafeMutableBytes { p in
            let b=p.bindMemory(to:UInt8.self)
            for i in 0..<(64*48) { b[4*i]=UInt8((i*37+17)%256);b[4*i+1]=UInt8((i*59+41)%256);b[4*i+2]=UInt8((i*83+73)%256);b[4*i+3]=255 }
        }
        let image = CGImage(width:64,height:48,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:256,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.union(.init(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue)),provider:CGDataProvider(data:pixels as CFData)!,decode:nil,shouldInterpolate:false,intent:.relativeColorimetric)!
        let encoded = NSMutableData()
        let dest = CGImageDestinationCreateWithData(encoded,UTType.heic.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(dest,image,[kCGImagePropertyOrientation:orientation] as CFDictionary)
        precondition(CGImageDestinationFinalize(dest))
        let source=CGImageSourceCreateWithData(encoded,[kCGImageSourceShouldCache:false] as CFDictionary)!
        let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil)! as NSDictionary
        let direct=CGImageSourceCreateImageAtIndex(source,0,[kCGImageSourceShouldCache:false,kCGImageSourceShouldAllowFloat:false] as CFDictionary)!
        let legacy=CGImageSourceCreateThumbnailAtIndex(source,0,[kCGImageSourceCreateThumbnailFromImageAlways:true,kCGImageSourceCreateThumbnailWithTransform:true,kCGImageSourceThumbnailMaxPixelSize:64,kCGImageSourceShouldCacheImmediately:true,kCGImageSourceShouldAllowFloat:false] as CFDictionary)!
        let directBytes=rgba(direct), expected=rgba(legacy)
        var comparisons:[String]=[]
        for candidate in 1...8 {
            let (w,h,data)=permute(directBytes,width:direct.width,height:direct.height,orientation:candidate)
            guard w==legacy.width && h==legacy.height else { continue }
            let delta=zip(data,expected).map{abs(Int($0)-Int($1))}
            comparisons.append("perm=\(candidate):different=\(delta.filter{$0 != 0}.count):max=\(delta.max()!)")
        }
        let ctm=orientedDraw(direct,orientation:orientation)
        let ctmDelta=zip(ctm,expected).map{abs(Int($0)-Int($1))}
        print("CTM EXIF=\(orientation) differingBytes=\(ctmDelta.filter{$0 != 0}.count) maxDelta=\(ctmDelta.max()!)")
        print("HEIC exifRequested=\(orientation) metadata=\(props[kCGImagePropertyOrientation]!) metadataSize=\(props[kCGImagePropertyPixelWidth]!)x\(props[kCGImagePropertyPixelHeight]!) direct=\(direct.width)x\(direct.height) legacy=\(legacy.width)x\(legacy.height) \(comparisons.joined(separator:" "))")
    }
}
