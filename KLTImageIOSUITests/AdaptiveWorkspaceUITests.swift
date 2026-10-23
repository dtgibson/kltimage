import XCTest

/// Run only on an explicitly selected local simulator. Seed the approved
/// hummingbird image with simctl addmedia and open it in the app first.
/// This focused scheme deliberately avoids automating the remote Photos extension.
final class AdaptiveWorkspaceUITests: XCTestCase {
    @MainActor
    func testNativeResizeKeepsComparisonAndCoordinateDraft() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.activate()
        XCUIDevice.shared.orientation = .portrait
        let source = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "specimen-anna-hummingbird")).firstMatch
        XCTAssertTrue(source.waitForExistence(timeout: 5), "Load the seeded approved fixture in the app before this focused UI check")
        XCTAssertTrue(app.staticTexts["Calculated for this image"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Export result"].firstMatch.isHittable, "Portrait canvas must leave its primary action reachable")
        attach(app, name: "portrait-calculated")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(source.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Zoom in"].waitForExistence(timeout: 10))
        attach(app, name: "landscape-calculated")
        app.buttons["Fit"].tap()
        for _ in 0..<12 { app.buttons["Zoom in"].tap() }
        let zoom = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "Zoom 1[,.]?000 percent")).firstMatch
        XCTAssertTrue(zoom.waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(zoom.waitForExistence(timeout: 10), "Rotation must preserve fit-relative zoom")
        let coordinates = app.buttons["Coordinates"].firstMatch
        if !coordinates.isHittable { app.buttons["Sample actions"].tap() }
        coordinates.tap()
        let x = app.textFields["X"]
        XCTAssertTrue(x.waitForExistence(timeout: 10))
        x.tap(); x.typeText("123")
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(x.value as? String, "123", "Rotation must preserve the coordinate draft")
        attach(app, name: "landscape-coordinate-draft")
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(x.value as? String, "123")
        app.buttons["Close"].tap()
        XCTAssertTrue(source.waitForExistence(timeout: 10))
    }

    @MainActor private func attach(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
