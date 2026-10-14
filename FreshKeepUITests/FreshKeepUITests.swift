import XCTest

/// End-to-end UI tests. Each test launches with an in-memory store and the mock
/// classifier so results are repeatable on any simulator. Screenshots are kept as
/// test attachments; CI exports them for the documentation.
final class FreshKeepUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extra: [String] = [], skipOnboarding: Bool = true, seed: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-mock-classifier"] + extra
        if skipOnboarding { app.launchArguments.append("-skip-onboarding") }
        if seed { app.launchArguments.append("-seed-sample-data") }
        app.launch()
        return app
    }

    private func snapshot(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testOnboardingFlow() {
        let app = launch(skipOnboarding: false, seed: false)
        XCTAssertTrue(app.staticTexts["Waste less, save more"].waitForExistence(timeout: 5))
        snapshot("01-onboarding", app)
        app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.staticTexts["Snap to add"].waitForExistence(timeout: 3))
        app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.staticTexts["Get nudged in time"].waitForExistence(timeout: 3))
        app.buttons["onboarding.next"].tap()
        // "Get started" asks for notification permission; the alert belongs to SpringBoard.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.element(boundBy: 1)
        if allow.waitForExistence(timeout: 5) { allow.tap() }
        XCTAssertTrue(app.navigationBars["My Pantry"].waitForExistence(timeout: 10))
        snapshot("02-empty-pantry", app)
    }

    func testPantryShowsSampleItemsAndDetail() {
        let app = launch()
        XCTAssertTrue(app.navigationBars["My Pantry"].waitForExistence(timeout: 15))
        snapshot("03-pantry", app)
        let carrot = app.scrollTo("pantry.row.Carrot")
        XCTAssertTrue(carrot.exists)
        carrot.tap()
        XCTAssertTrue(app.navigationBars["Carrot"].waitForExistence(timeout: 5))
        snapshot("04-item-detail", app)
        app.swipeUp()
        XCTAssertTrue(app.buttons["detail.eaten"].waitForExistence(timeout: 5))
    }

    func testAddItemManually() {
        let app = launch(seed: false)
        app.buttons["pantry.add"].firstMatch.tap()
        let name = app.textFields["item.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText("Papaya")
        snapshot("05-add-item", app)
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.element("pantry.row.Papaya").waitForExistence(timeout: 5))
    }

    func testSaveWithoutNameIsBlocked() {
        let app = launch(seed: false)
        app.buttons["pantry.add"].firstMatch.tap()
        XCTAssertTrue(app.buttons["item.save"].waitForExistence(timeout: 5))
        app.buttons["item.save"].tap()
        // Still on the form: the empty name is rejected.
        XCTAssertTrue(app.textFields["item.name"].exists)
    }

    func testScanFoodFlowAddsItem() {
        let app = launch(seed: false)
        app.tabBars.buttons["Scan"].tap()
        let sample = app.buttons["scan.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 15))
        sample.tap()
        let banana = app.element("scan.match.banana")
        XCTAssertTrue(banana.waitForExistence(timeout: 8))
        snapshot("06-scan-results", app)
        banana.tap()
        XCTAssertTrue(app.buttons["item.save"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["item.name"].value as? String, "Banana")
        app.buttons["item.save"].tap()
        XCTAssertTrue(app.element("pantry.row.Banana").waitForExistence(timeout: 5))
    }

    func testScanLabelReadsDate() {
        let app = launch(seed: false)
        app.tabBars.buttons["Scan"].tap()
        app.buttons["Date label"].firstMatch.tap()
        app.buttons["scan.sample"].tap()
        XCTAssertTrue(app.buttons["scan.useDate"].waitForExistence(timeout: 8))
        snapshot("07-label-scan", app)
    }

    func testMarkEatenFromDetail() {
        let app = launch()
        // Banana is the only "Use today" sample item, so its row is always near the top.
        // (List rows are lazy: items further down don't exist until scrolled to.)
        let banana = app.scrollTo("pantry.row.Banana")
        XCTAssertTrue(banana.exists)
        banana.tap()
        XCTAssertTrue(app.navigationBars["Banana"].waitForExistence(timeout: 10))
        app.swipeUp()
        let eaten = app.buttons["detail.eaten"]
        XCTAssertTrue(eaten.waitForExistence(timeout: 5))
        eaten.tap()
        // Once eaten, the item is no longer active so the action buttons disappear.
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: eaten)
        waitForExpectations(timeout: 5)
    }

    func testInsightsAndSettings() {
        let app = launch()
        app.tabBars.buttons["Insights"].tap()
        XCTAssertTrue(app.staticTexts["Rescue rate"].waitForExistence(timeout: 5))
        snapshot("08-insights", app)
        app.swipeUp()
        snapshot("09-insights-recipes", app)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        snapshot("10-settings", app)
    }

    func testDarkModeAndLargeTextScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-mock-classifier", "-skip-onboarding", "-seed-sample-data",
                               "-appearance", "dark",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]
        app.launch()
        XCTAssertTrue(app.navigationBars["My Pantry"].waitForExistence(timeout: 15))
        snapshot("11-dark-large-text", app)
    }

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments = ["-ui-testing", "-skip-onboarding"]
            app.launch()
        }
    }
}

private extension XCUIApplication {
    /// Finds an element by accessibility identifier regardless of its element type
    /// (a List row can surface as a button or a cell depending on the OS version).
    func element(_ identifier: String) -> XCUIElement {
        descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Lists are lazy, so rows below the fold don't exist until scrolled into view.
    /// Waits for the screen, then swipes up until the element appears (max 6 swipes).
    func scrollTo(_ identifier: String) -> XCUIElement {
        let target = element(identifier)
        if target.waitForExistence(timeout: 10) { return target }
        for _ in 0..<6 {
            swipeUp()
            if target.waitForExistence(timeout: 2) { break }
        }
        return target
    }
}
