import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@MainActor
final class KLTImageUITests: XCTestCase {
    func testEmptyWorkspaceExposesPrimaryControls() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["open-image-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["empty-open-image-button"].exists)
        XCTAssertTrue(app.buttons["export-result-button"].exists)
        XCTAssertFalse(app.buttons["export-result-button"].isEnabled)
        XCTAssertTrue(app.staticTexts["Your images stay on this Mac."].exists)
    }

    func testOpeningImageProducesAccessibleComparisonWorkspace() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let imageURL = try makeFixtureImage()
        app.buttons["empty-open-image-button"].click()

        XCTAssertTrue(app.dialogs.firstMatch.waitForExistence(timeout: 3))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let locationField = app.sheets.textFields.firstMatch
        XCTAssertTrue(locationField.waitForExistence(timeout: 3))
        locationField.typeText(imageURL.path)
        app.typeKey(.return, modifierFlags: [])
        app.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(app.buttons["export-result-button"].waitForExistence(timeout: 8))
        let exportButton = app.buttons["export-result-button"]
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: exportButton)
        waitForExpectations(timeout: 8)

        XCTAssertTrue(app.buttons["method-details-button"].exists)
        XCTAssertTrue(app.buttons["zoom-in-button"].isEnabled)
        XCTAssertTrue(app.buttons["zoom-out-button"].isEnabled)
        XCTAssertTrue(app.staticTexts["Exploratory enhancement"].exists)
    }

    private func makeFixtureImage() throws -> URL {
        let width = 96
        let height = 64
        var pixels = Data(count: width * height * 4)
        pixels.withUnsafeMutableBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let offset = index * 4
                bytes[offset] = UInt8((index * 31 + 19) % 256)
                bytes[offset + 1] = UInt8((index * 47 + 37) % 256)
                bytes[offset + 2] = UInt8((index * 67 + 71) % 256)
                bytes[offset + 3] = 255
            }
        }

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        )
        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: CGDataProvider(data: pixels as CFData)!,
            decode: nil,
            shouldInterpolate: false,
            intent: .relativeColorimetric
        )!

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("klt-ui-fixture-\(UUID().uuidString)")
            .appendingPathExtension("png")
        let output = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            output,
            UTType.png.identifier as CFString,
            1,
            nil
        )!
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try (output as Data).write(to: url, options: .atomic)
        return url
    }
}
