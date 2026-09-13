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
        let colorSpacePicker = accessibleElement(in: app, identifier: "color-space-picker")
        let matrixModePicker = accessibleElement(in: app, identifier: "matrix-mode-picker")
        XCTAssertTrue(colorSpacePicker.exists)
        XCTAssertTrue(matrixModePicker.exists)
        XCTAssertTrue(colorSpacePicker.radioButtons["RGB"].exists)
        XCTAssertTrue(colorSpacePicker.radioButtons["Lab"].exists)
        XCTAssertTrue(matrixModePicker.radioButtons["Covariance"].exists)
        XCTAssertTrue(matrixModePicker.radioButtons["Correlation"].exists)
        XCTAssertTrue(app.buttons["whole-image-sample-button"].exists)
        XCTAssertTrue(app.buttons["selected-region-sample-button"].exists)
        let guidance = accessibleElement(in: app, identifier: "exploratory-guidance")
        XCTAssertTrue(guidance.exists)
        XCTAssertEqual(guidance.label, "Exploratory enhancement")
        let guidanceDetail = guidance.descendants(matching: .any)
            .matching(identifier: "exploratory-guidance-detail")
            .firstMatch
        XCTAssertTrue(guidanceDetail.exists)
        XCTAssertEqual(guidanceDetail.elementType, .staticText)
        XCTAssertEqual(
            guidanceDetail.value as? String,
            "Color differences are amplified for inspection. The result is not, by itself, a scientific measurement."
        )

        let analysisRecordButton = app.buttons["analysis-record-button"]
        XCTAssertTrue(analysisRecordButton.waitForExistence(timeout: 3))
        XCTAssertTrue(analysisRecordButton.isEnabled)
        analysisRecordButton.click()
        let closeAnalysisRecordButton = app.buttons["close-analysis-record-button"]
        XCTAssertTrue(closeAnalysisRecordButton.waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["analysis-record-tab-0"].exists)
        XCTAssertTrue(app.buttons["analysis-record-tab-1"].exists)
        XCTAssertTrue(app.buttons["analysis-record-tab-2"].exists)
        XCTAssertTrue(app.buttons["export-analysis-record-button"].exists)
        XCTAssertTrue(app.staticTexts["analysis-record-exploratory-notice"].exists)
        let colorSpaceExplanation = accessibleElement(
            in: app,
            identifier: "analysis-record-color-space-explanation"
        )
        XCTAssertTrue(colorSpaceExplanation.exists)
        XCTAssertTrue(colorSpaceExplanation.label.contains("RGB analyzes encoded display channels"))
        let matrixModeExplanation = accessibleElement(
            in: app,
            identifier: "analysis-record-matrix-mode-explanation"
        )
        XCTAssertTrue(matrixModeExplanation.exists)
        XCTAssertTrue(matrixModeExplanation.label.contains("Covariance keeps each channel's scale of variation"))
        app.buttons["analysis-record-tab-1"].click()
        app.buttons["analysis-record-tab-2"].click()
        closeAnalysisRecordButton.click()
        XCTAssertTrue(closeAnalysisRecordButton.waitForNonExistence(timeout: 2))

        verifyMethodDetailsFocusRoundTrip(in: app)

        app.buttons["selected-region-sample-button"].click()
        XCTAssertTrue(app.staticTexts["analysis-status-banner"].waitForExistence(timeout: 2))
        XCTAssertFalse(exportButton.isEnabled)
        XCTAssertTrue(analysisRecordButton.waitForNonExistence(timeout: 2))
        let xField = app.textFields["region-x-field"]
        let yField = app.textFields["region-y-field"]
        let widthField = app.textFields["region-width-field"]
        let heightField = app.textFields["region-height-field"]
        XCTAssertTrue(xField.exists)
        XCTAssertTrue(yField.exists)
        XCTAssertTrue(widthField.exists)
        XCTAssertTrue(heightField.exists)

        xField.click()
        xField.typeText("0")
        yField.click()
        yField.typeText("0")
        widthField.click()
        widthField.typeText("48")
        heightField.click()
        heightField.typeText("32")
        XCTAssertEqual(xField.value as? String, "0")
        XCTAssertEqual(yField.value as? String, "0")
        XCTAssertEqual(widthField.value as? String, "48")
        XCTAssertEqual(heightField.value as? String, "32")
        app.buttons["apply-region-button"].click()
        waitForReadyResult(in: app, method: "RGB · covariance · selected region")
        XCTAssertEqual(
            app.staticTexts["region-feedback"].value as? String,
            "Region is valid. Its pixels establish the transform; the full image receives it."
        )
        assertActiveMethodSummary(
            in: app,
            equals: "Active method: RGB · covariance · selected region. 3 stable components · local processing"
        )
        XCTAssertTrue(analysisRecordButton.waitForExistence(timeout: 2))

        widthField.click()
        app.typeKey("a", modifierFlags: .command)
        widthField.typeText("0")
        app.buttons["apply-region-button"].click()
        XCTAssertTrue(app.staticTexts["analysis-status-banner"].waitForExistence(timeout: 2))
        XCTAssertEqual(
            app.staticTexts["region-feedback"].value as? String,
            "Width and height must both be positive. Values are kept for correction."
        )
        assertActiveMethodSummary(
            in: app,
            equals: "Active method: RGB · covariance · selected region. Region needs correction · no fallback"
        )
        XCTAssertFalse(exportButton.isEnabled)
        XCTAssertTrue(analysisRecordButton.waitForNonExistence(timeout: 2))

        widthField.click()
        app.typeKey("a", modifierFlags: .command)
        widthField.typeText("24")
        matrixModePicker.radioButtons["Correlation"].click()
        XCTAssertTrue(app.staticTexts["analysis-status-banner"].exists)
        XCTAssertFalse(exportButton.isEnabled)

        app.buttons["apply-region-button"].click()
        waitForReadyResult(in: app, method: "RGB · correlation · selected region")
        XCTAssertEqual(
            app.staticTexts["region-feedback"].value as? String,
            "Region is valid. Its pixels establish the transform; the full image receives it."
        )
        assertActiveMethodSummary(
            in: app,
            equals: "Active method: RGB · correlation · selected region. 3 stable components · local processing"
        )
        XCTAssertTrue(analysisRecordButton.waitForExistence(timeout: 2))
    }

    private func accessibleElement(in app: XCUIApplication, identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForReadyResult(in app: XCUIApplication, method: String) {
        let expectedStatus = "Status: Result ready. Requested method: \(method)."
        let readyStatus = accessibleElement(in: app, identifier: "analysis-status")
        XCTAssertTrue(readyStatus.waitForExistence(timeout: 8))
        expectation(for: NSPredicate(format: "value == %@", expectedStatus), evaluatedWith: readyStatus)
        waitForExpectations(timeout: 8)
        XCTAssertEqual(readyStatus.value as? String, expectedStatus)
        XCTAssertFalse(app.staticTexts["analysis-status-banner"].exists)

        let currentExportButton = app.buttons.matching(identifier: "export-result-button").firstMatch
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: currentExportButton)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(currentExportButton.isEnabled)
    }

    private func assertActiveMethodSummary(in app: XCUIApplication, equals expectedValue: String) {
        let summary = accessibleElement(in: app, identifier: "active-method-summary")
        XCTAssertTrue(summary.exists)
        XCTAssertEqual(summary.value as? String, expectedValue)
    }

    private func verifyMethodDetailsFocusRoundTrip(in app: XCUIApplication) {
        let trigger = app.buttons["method-details-button"]
        let close = app.buttons["close-method-details-button"]

        trigger.click()
        XCTAssertTrue(close.waitForExistence(timeout: 2))

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(close.waitForNonExistence(timeout: 2), "Space should activate the focused popover close button")

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(close.waitForExistence(timeout: 2), "Focus should return to the method-details button after dismissal")

        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(close.waitForNonExistence(timeout: 2))

        app.typeKey(.space, modifierFlags: [])
        XCTAssertTrue(close.waitForExistence(timeout: 2), "Escape dismissal should restore focus to the invoking button")
        close.click()
        XCTAssertTrue(close.waitForNonExistence(timeout: 2))
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
