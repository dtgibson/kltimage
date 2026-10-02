import XCTest

@MainActor final class NativeZoomQA: XCTestCase {
    func testNativeButtonsPinchAndFit() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Open image"].waitForExistence(timeout: 10))
        app.buttons["Open image"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Photos"].waitForExistence(timeout: 5))
        app.buttons["Photos"].tap()
        let picker = app.collectionViews.firstMatch
        XCTAssertTrue(picker.waitForExistence(timeout: 10), app.debugDescription)
        let cell = picker.cells.firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), app.debugDescription)
        cell.tap()
        XCTAssertTrue(app.buttons["Zoom in"].waitForExistence(timeout: 15), app.debugDescription)
        for _ in 0..<13 { app.buttons["Zoom in"].tap() }
        XCTAssertTrue(app.staticTexts["Zoom 1000 percent"].exists, app.debugDescription)
        attach("iPhone-buttons-1000")
        app.buttons["Zoom out"].tap()
        XCTAssertTrue(app.staticTexts["Zoom 800 percent"].exists)
        app.buttons["Fit"].tap()
        XCTAssertTrue(app.staticTexts["Zoom 100 percent"].exists)
        for _ in 0..<4 { app.pinch(withScale: 3, velocity: 2) }
        XCTAssertTrue(app.staticTexts["Zoom 1000 percent"].exists, app.debugDescription)
        app.pinch(withScale: 2, velocity: 2)
        XCTAssertTrue(app.staticTexts["Zoom 1000 percent"].exists)
        attach("iPhone-pinch-1000-overshoot")
        app.buttons["Processed"].tap()
        attach("iPhone-processed-1000")
        app.buttons["Original"].tap()
        attach("iPhone-original-1000")
        app.buttons["Fit"].tap()
        XCTAssertTrue(app.staticTexts["Zoom 100 percent"].exists)
        attach("iPhone-fit-restored")
    }
    private func attach(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name; a.lifetime = .keepAlways; add(a)
    }
}
