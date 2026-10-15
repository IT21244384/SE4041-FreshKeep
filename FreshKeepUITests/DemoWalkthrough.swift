import XCTest

/// Slow, scripted tour of the app used to record the viva demo video in CI
/// (`.github/workflows/demo.yml`). It is skipped by the normal test run.
///
/// Unlike the other UI tests it uses the real Vision classifier and OCR, so what
/// the video shows is genuine on-device recognition of the sample photos.
final class DemoWalkthrough: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        // In-memory store and onboarding shown, but no mock services.
        app.launchArguments = ["-ui-testing"]
    }

    /// Gives the viewer time to see each step.
    private func pause(_ seconds: TimeInterval = 2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 5) {
        if element.waitForExistence(timeout: timeout) { element.tap() }
    }

    private func tab(_ name: String) {
        tapIfExists(app.tabBars.buttons[name])
        pause(1.5)
    }

    func testDemoWalkthrough() {
        app.launch()
        pause(3)

        // 1. Onboarding
        for _ in 0..<3 {
            tapIfExists(app.buttons["onboarding.next"])
            pause(2.5)
        }
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons.element(boundBy: 1)
        if allow.waitForExistence(timeout: 5) { pause(1.5); allow.tap() }
        pause(2.5)

        // 2. Load the demo pantry from Settings
        tab("Settings")
        tapIfExists(app.buttons["Load sample pantry"])
        pause(1)
        tab("Pantry")
        pause(3)

        // 3. Browse the pantry and the urgent carousel
        app.swipeUp(velocity: .slow)
        pause(2)
        app.swipeDown(velocity: .slow)
        pause(2)

        // 4. Rescue the banana with a swipe (confetti)
        let banana = app.descendants(matching: .any).matching(identifier: "pantry.row.Banana").firstMatch
        if banana.waitForExistence(timeout: 5) {
            banana.swipeRight()
            pause(1)
            tapIfExists(app.buttons["Eaten"], timeout: 2)
            pause(3)
        }

        // 5. Item detail: freshness ring, storage tip, freeze
        let chicken = app.descendants(matching: .any).matching(identifier: "pantry.row.Chicken").firstMatch
        if !chicken.waitForExistence(timeout: 3) { app.swipeUp(velocity: .slow) }
        if chicken.waitForExistence(timeout: 3) {
            chicken.tap()
            pause(3.5)
            app.swipeUp(velocity: .slow)
            pause(2.5)
            tapIfExists(app.buttons["Freeze"], timeout: 3)
            pause(3)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause(2)
        }

        // 6. Scan food with the camera pipeline (real Vision classifier)
        tab("Scan")
        pause(1.5)
        tapIfExists(app.buttons["scan.sample"])
        let match = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'scan.match.'")).firstMatch
        if match.waitForExistence(timeout: 20) {
            pause(3.5)
            match.tap()
            pause(3)
            tapIfExists(app.buttons["item.save"])
            pause(3)
        } else {
            pause(3)
        }

        // 7. Read a best-before date from a label (real OCR)
        tab("Scan")
        tapIfExists(app.buttons["Date label"].firstMatch)
        pause(1.5)
        tapIfExists(app.buttons["scan.sample"])
        let useDate = app.buttons["scan.useDate"]
        if useDate.waitForExistence(timeout: 20) {
            pause(3.5)
            useDate.tap()
            pause(1.5)
            let name = app.textFields["item.name"]
            if name.waitForExistence(timeout: 5) {
                name.tap()
                name.typeText("Fresh milk")
                pause(1.5)
                tapIfExists(app.buttons["item.save"])
            }
            pause(3)
        }

        // 8. Insights and a recipe
        tab("Insights")
        pause(3)
        app.swipeUp(velocity: .slow)
        pause(2.5)
        app.swipeUp(velocity: .slow)
        pause(2)
        let recipe = app.buttons.containing(NSPredicate(format: "label CONTAINS 'min'")).firstMatch
        if recipe.waitForExistence(timeout: 3) {
            recipe.tap()
            pause(2.5)
            let step = app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'slice' OR label CONTAINS[c] 'chop' OR label CONTAINS[c] 'whisk'")).firstMatch
            tapIfExists(step, timeout: 2)
            pause(2.5)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            pause(1.5)
        }

        // 9. Dark mode
        tab("Settings")
        tapIfExists(app.buttons["Dark"])
        pause(1.5)
        tab("Pantry")
        pause(3.5)
        tab("Insights")
        pause(3)
        tab("Settings")
        tapIfExists(app.buttons["System"])
        pause(1)
        tab("Pantry")
        pause(3)
    }
}
