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
}
