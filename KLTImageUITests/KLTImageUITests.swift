import Foundation
import XCTest

@MainActor
final class KLTImageUITests: XCTestCase {
    func testEmptyWorkspaceExposesPrimaryControls() {
        continueAfterFailure = false
        let app = isolatedApplication()
        launchIsolatedApplication(app)
        XCTAssertTrue(app.buttons["open-image-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["empty-open-image-button"].exists)
        XCTAssertTrue(app.buttons["export-result-button"].exists)
        XCTAssertFalse(app.buttons["export-result-button"].isEnabled)
        XCTAssertTrue(app.buttons["methods-button"].exists)
        XCTAssertTrue(app.staticTexts["Your images stay on this Mac."].exists)
    }

    func testMethodLibrarySeparatesTransparentWorkingSpacesAndSavedTransforms() {
        continueAfterFailure = false
        let app = isolatedApplication()
        launchIsolatedApplication(app)
        app.buttons["methods-button"].click()
        XCTAssertTrue(app.buttons["close-method-library-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.rgb").exists)
        XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.lab-d65").exists)
        XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.luma-chroma").exists)
        XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.red-complement").exists)
        XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.lab-blue-yellow").exists)
        XCTAssertTrue(app.buttons["new-working-space-button"].exists)
        XCTAssertTrue(app.buttons["import-method-button"].exists)
        app.buttons["close-method-library-button"].click()
    }

    func testWorkingSpaceEditorFieldsHaveSemanticAccessibilityLabels() {
        continueAfterFailure = false
        let app = isolatedApplication()
        launchIsolatedApplication(app)
        app.buttons["methods-button"].click()
        XCTAssertTrue(app.buttons["new-working-space-button"].waitForExistence(timeout: 3))
        app.buttons["new-working-space-button"].click()

        for row in 1...3 {
            for column in 1...3 {
                let field = app.textFields["working-space-coefficient-\(row)-\(column)"]
                XCTAssertTrue(field.waitForExistence(timeout: 2))
                XCTAssertTrue(field.label.contains("Coefficient row \(row)"))
                XCTAssertTrue(field.label.contains("base column \(column)"))
                XCTAssertNotEqual(field.label, "0")
                XCTAssertNotEqual(field.label, "Value")
            }
            let offset = app.textFields["working-space-offset-\(row)"]
            XCTAssertTrue(offset.exists)
            XCTAssertTrue(offset.label.contains("Offset row \(row)"))
            XCTAssertNotEqual(offset.label, "0")
            XCTAssertNotEqual(offset.label, "Value")
        }

        let first = app.textFields["working-space-coefficient-1-1"]
        for _ in 0..<8 where !first.hasKeyboardFocus {
            app.typeKey(.tab, modifierFlags: [])
        }
        XCTAssertTrue(first.hasKeyboardFocus, "Tab navigation should reach the first coefficient field")
        app.typeKey(.tab, modifierFlags: [])
        let second = app.textFields["working-space-coefficient-1-2"]
        XCTAssertTrue(second.hasKeyboardFocus, "Coefficient fields should follow row-major Tab order")
        app.typeKey("a", modifierFlags: .command)
        app.typeText("3")
        XCTAssertEqual(second.value as? String, "3")

        let finalOffset = app.textFields["working-space-offset-3"]
        focusWithTabs(finalOffset, in: app)
        replaceFocusedText(with: "not-a-number", in: app)
        let validation = accessibleElement(in: app, identifier: "working-space-validation")
        XCTAssertTrue(validation.label.contains("Every coefficient and offset must be a finite decimal number."))
        XCTAssertFalse(app.buttons["save-working-space-button"].isEnabled)
        XCTAssertTrue(finalOffset.hasKeyboardFocus)
        finalOffset.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(app.textFields["working-space-library-name"].exists)
        XCTAssertTrue(validation.label.contains("Every coefficient and offset must be a finite decimal number."))
    }

    func testKeyboardCreatesAndPersistsEncodedSRGBAndLabWorkingSpaces() throws {
        continueAfterFailure = false
        let libraryToken = "klt-keyboard-library-\(UUID().uuidString).json"
        let app = isolatedApplication()
        app.launchEnvironment["KLT_UI_TEST_METHOD_LIBRARY_PATH"] = libraryToken
        launchIsolatedApplication(app)

        let enabledFullKeyboardAccess = isFullKeyboardAccessEnabled
        if !enabledFullKeyboardAccess {
            app.typeKey(.F7, modifierFlags: [.control, .function])
            addTeardownBlock {
                guard app.state == .runningForeground else { return }
                app.typeKey(.F7, modifierFlags: [.control, .function])
            }
        }

        openMethodLibraryWithKeyboard(in: app)
        try createWorkingSpaceWithKeyboard(
            in: app,
            name: "Keyboard RGB Space",
            purpose: "Encoded sRGB keyboard fixture",
            base: "Encoded sRGB",
            channels: ["warm", "green", "cool"],
            coefficients: ["1", "0.1", "0", "0", "1", "0.05", "0.02", "0", "1"],
            offsets: ["0.1", "-0.2", "0.3"]
        )
        try createWorkingSpaceWithKeyboard(
            in: app,
            name: "Keyboard Lab Space",
            purpose: "Lab keyboard fixture",
            base: "CIE Lab D65",
            channels: ["light", "red green", "blue yellow"],
            coefficients: ["1", "0.02", "0", "0", "1", "0.03", "0.01", "0", "1"],
            offsets: ["1.5", "-2", "3.25"]
        )
        XCTAssertTrue(workingSpaceRow(named: "Keyboard RGB Space", in: app).exists)
        XCTAssertTrue(workingSpaceRow(named: "Keyboard Lab Space", in: app).exists)
        activateWithKeyboard(app.buttons["close-method-library-button"], in: app)
        app.terminate()

        launchIsolatedApplication(app)
        openMethodLibraryWithKeyboard(in: app)
        XCTAssertTrue(workingSpaceRow(named: "Keyboard RGB Space", in: app).waitForExistence(timeout: 3))
        XCTAssertTrue(workingSpaceRow(named: "Keyboard Lab Space", in: app).exists)
    }

    func testFixedLightLibraryRemainsUsableWithLargerTextAndIncreasedContrastInBothSystemAppearances() {
        continueAfterFailure = false
        for darkAppearance in [false, true] {
            let app = isolatedApplication()
            app.launchEnvironment["KLT_UI_TEST_LARGER_TEXT"] = "1"
            app.launchArguments += ["-AppleIncreaseContrast", "YES"]
            if darkAppearance {
                app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
            }
            launchIsolatedApplication(app)
            app.buttons["methods-button"].click()
            XCTAssertTrue(app.buttons["new-working-space-button"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["new-working-space-button"].isHittable)
            XCTAssertTrue(accessibleElement(in: app, identifier: "working-space-row-org.kltimage.space.rgb").exists)
            app.buttons["new-working-space-button"].click()
            let name = app.textFields["working-space-library-name"]
            let validation = accessibleElement(in: app, identifier: "working-space-validation")
            XCTAssertTrue(name.waitForExistence(timeout: 2))
            XCTAssertTrue(validation.exists)
            XCTAssertFalse(name.frame.isEmpty)
            XCTAssertFalse(validation.frame.isEmpty)
            XCTAssertTrue(app.buttons["save-working-space-button"].exists)
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = darkAppearance
                ? "Dark system, fixed-light app, larger text, increased contrast"
                : "Light system, fixed-light app, larger text, increased contrast"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    func testOpeningImageProducesAccessibleComparisonWorkspace() throws {
        continueAfterFailure = false
        let app = isolatedApplication()
        launchIsolatedApplication(app)
        let imageURL = URL(
            fileURLWithPath: "/System/Library/CoreServices/StageManagerOnboarding.app/Contents/Resources/StageManager_LT.ca/assets/wallpaper.jpg"
        )
        XCTAssertTrue(FileManager.default.isReadableFile(atPath: imageURL.path))
        app.buttons["empty-open-image-button"].click()

        XCTAssertTrue(app.dialogs.firstMatch.waitForExistence(timeout: 3))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let locationField = app.sheets.textFields.firstMatch
        XCTAssertTrue(locationField.waitForExistence(timeout: 3))
        locationField.typeText(imageURL.path)
        app.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            locationField.waitForNonExistence(timeout: 3),
            "The Go to Folder sheet should finish selecting the file before it is opened"
        )
        let openButton = app.dialogs.firstMatch.buttons["Open Image"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "enabled == true"), evaluatedWith: openButton)
        waitForExpectations(timeout: 3)
        openButton.click()
        XCTAssertTrue(app.dialogs.firstMatch.waitForNonExistence(timeout: 3))

        XCTAssertTrue(app.buttons["export-result-button"].waitForExistence(timeout: 8))
        let exportButton = app.buttons["export-result-button"]
        let ready = NSPredicate(format: "enabled == true")
        expectation(for: ready, evaluatedWith: exportButton)
        waitForExpectations(timeout: 8)

        XCTAssertTrue(app.buttons["method-details-button"].exists)
        XCTAssertTrue(app.buttons["zoom-in-button"].isEnabled)
        XCTAssertTrue(app.buttons["zoom-out-button"].isEnabled)
        let imageViewPicker = accessibleElement(in: app, identifier: "image-view-picker")
        XCTAssertTrue(imageViewPicker.radioButtons["Original"].exists)
        XCTAssertTrue(imageViewPicker.radioButtons["Side-by-Side"].exists)
        XCTAssertTrue(imageViewPicker.radioButtons["Slider"].exists)
        XCTAssertTrue(imageViewPicker.radioButtons["Processed"].exists)
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
            "Color differences are amplified for inspection. Coordinate choice, color management, and target mismatch during fixed reuse can amplify noise, compression, lighting differences, clipping, low contrast, or gamut loss. The result is not, by itself, a scientific measurement."
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

    private func isolatedApplication() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ApplePersistenceIgnoreState", "YES",
            "-NSQuitAlwaysKeepsWindows", "NO"
        ]
        app.launchEnvironment["KLT_UI_TEST_STATE_ID"] = UUID().uuidString
        return app
    }

    private var isFullKeyboardAccessEnabled: Bool {
        let mode = UserDefaults.standard
            .persistentDomain(forName: UserDefaults.globalDomain)?["AppleKeyboardUIMode"] as? NSNumber
        return mode.map { $0.intValue & 2 != 0 } ?? false
    }

    private func launchIsolatedApplication(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if app.state != .notRunning {
            app.terminate()
        }
        XCTAssertTrue(
            app.wait(for: .notRunning, timeout: 5),
            "The prior application instance did not terminate",
            file: file,
            line: line
        )
        app.launch()
        app.activate()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "The application did not reach the foreground",
            file: file,
            line: line
        )
    }

    private func openMethodLibraryWithKeyboard(in app: XCUIApplication) {
        let button = app.buttons["methods-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        activateWithKeyboard(button, in: app)
        XCTAssertTrue(app.buttons["new-working-space-button"].waitForExistence(timeout: 3))
    }

    private func createWorkingSpaceWithKeyboard(
        in app: XCUIApplication,
        name: String,
        purpose: String,
        base: String,
        channels: [String],
        coefficients: [String],
        offsets: [String]
    ) throws {
        activateWithKeyboard(app.buttons["new-working-space-button"], in: app)
        let nameField = app.textFields["working-space-library-name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        focusWithTabs(nameField, in: app)
        replaceFocusedText(with: name, in: app)

        let purposeField = app.textFields["working-space-purpose"]
        focusWithTabs(purposeField, in: app)
        replaceFocusedText(with: purpose, in: app)

        let encoded = app.radioButtons["Encoded sRGB"]
        let lab = app.radioButtons["CIE Lab D65"]
        focusWithTabs(encoded, in: app)
        if base == "CIE Lab D65" {
            app.typeKey(.rightArrow, modifierFlags: [])
            XCTAssertTrue(lab.hasKeyboardFocus)
            app.typeKey(.space, modifierFlags: [])
        } else {
            app.typeKey(.space, modifierFlags: [])
        }

        for index in 0..<3 {
            let field = app.textFields["working-space-channel-\(index + 1)"]
            focusWithTabs(field, in: app)
            replaceFocusedText(with: channels[index], in: app)
        }
        for row in 0..<3 {
            for column in 0..<3 {
                let field = app.textFields["working-space-coefficient-\(row + 1)-\(column + 1)"]
                focusWithTabs(field, in: app)
                replaceFocusedText(with: coefficients[row * 3 + column], in: app)
            }
            let offset = app.textFields["working-space-offset-\(row + 1)"]
            focusWithTabs(offset, in: app)
            replaceFocusedText(with: offsets[row], in: app)
        }

        let validation = accessibleElement(in: app, identifier: "working-space-validation")
        XCTAssertTrue(validation.exists)
        XCTAssertTrue(validation.label.contains("Definition is reversible"))
        let save = app.buttons["save-working-space-button"]
        XCTAssertTrue(save.isEnabled)
        let finalOffset = app.textFields["working-space-offset-3"]
        XCTAssertTrue(finalOffset.hasKeyboardFocus)
        finalOffset.typeKey(.return, modifierFlags: [])
        XCTAssertTrue(nameField.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 3))
    }

    private func workingSpaceRow(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
    }

    private func activateWithKeyboard(_ element: XCUIElement, in app: XCUIApplication) {
        focusWithTabs(element, in: app)
        app.typeKey(.space, modifierFlags: [])
    }

    private func focusWithTabs(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let identifier = element.identifier
        let label = element.label
        let elementType = element.elementType
        let currentElement: () -> XCUIElement = {
            if !identifier.isEmpty {
                return app.descendants(matching: .any).matching(identifier: identifier).firstMatch
            }
            return app.descendants(matching: elementType)
                .matching(NSPredicate(format: "label == %@", label))
                .firstMatch
        }

        XCTAssertTrue(currentElement().waitForExistence(timeout: 2), file: file, line: line)
        for _ in 0..<40 {
            if currentElement().hasKeyboardFocus { return }
            app.typeKey(.tab, modifierFlags: [])
        }
        XCTAssertTrue(
            currentElement().hasKeyboardFocus,
            "Tab navigation did not reach \(identifier.isEmpty ? label : identifier)",
            file: file,
            line: line
        )
    }

    private func replaceFocusedText(with text: String, in app: XCUIApplication) {
        app.typeKey("a", modifierFlags: .command)
        app.typeText(text)
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

}

private extension XCUIElement {
    var hasKeyboardFocus: Bool {
        (value(forKey: "hasKeyboardFocus") as? Bool) == true
    }
}
