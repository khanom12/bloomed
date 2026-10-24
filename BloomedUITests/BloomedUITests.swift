import XCTest

/// Real navigation and input coverage. Financial formula coverage lives in the
/// domain fixtures; these tests verify that the participant can use those rules.
@MainActor
final class BloomedUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_CA"]
        app.launch()
    }

    func testFreshInstallationHasFourPurposefulEmptyTabs() {
        XCTAssertTrue(app.buttons["Create your walking plan"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["update-today-steps"].exists)

        for title in ["Today", "My plan", "Progress", "Money"] {
            XCTAssertTrue(app.tabBars.buttons[title].exists, "Missing tab: \(title)")
        }

        app.tabBars.buttons["My plan"].tap()
        XCTAssertTrue(app.staticTexts["A routine that fits your life."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Create your walking plan"].exists)

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Room for your story."].waitForExistence(timeout: 3))

        app.tabBars.buttons["Money"].tap()
        XCTAssertTrue(app.staticTexts["A clear record from the start."].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["This week's commitment"].exists, "A fresh install must not fabricate a commitment.")

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["Create your walking plan"].exists)
        attachScreenshot("Fresh Today")
    }

    func testSingleGoalPlanCanStartTodayRecordTotalAndShowMoney() {
        beginPlan(base: "5000")

        let stretch = app.switches["plan.stretchEnabled"]
        XCTAssertTrue(stretch.waitForExistence(timeout: 3))
        XCTAssertEqual(stretch.value as? String, "0", "Stretch must be optional and off initially.")
        tap("plan.continue")

        let consistency = app.switches["plan.consistencyEnabled"]
        XCTAssertTrue(consistency.waitForExistence(timeout: 3))
        XCTAssertEqual(consistency.value as? String, "0", "Consistency must be optional and off initially.")
        tap("plan.continue")

        enter("35.00", into: "plan.commitment")
        enter("Walking plan test charity", into: "plan.charity")
        let keyboardDone = app.buttons["keyboard.done"]
        if keyboardDone.exists && keyboardDone.isHittable { keyboardDone.tap() }
        attachScreenshot("Completed commitment arrangement")
        tap("plan.continue")

        tap("plan.startToday")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Today is Day 1")).firstMatch.exists)
        let confirm = app.buttons["plan.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(confirm.isEnabled)
        confirm.tap()

        XCTAssertTrue(app.staticTexts["Your week is ready."].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()

        let update = app.buttons["update-today-steps"]
        XCTAssertTrue(update.waitForExistence(timeout: 5), "Starting today must make daily entry available.")
        tap("update-today-steps")
        enter("5000", into: "entry.total")
        tap("entry.save")

        XCTAssertTrue(app.staticTexts["5,000 steps recorded"].waitForExistence(timeout: 5))
        attachScreenshot("Active Today after first entry")
        app.tabBars.buttons["Money"].tap()
        XCTAssertTrue(app.staticTexts["This week's commitment"].waitForExistence(timeout: 3))
        let earned = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "Your money earned back", "5.00")).firstMatch
        XCTAssertTrue(earned.waitForExistence(timeout: 3), "One successful day of a CAD 35 single-goal week must show CAD 5 earned back.")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "charity allocation awaits review")).firstMatch.exists)
        XCTAssertFalse(app.buttons["Record donation made"].exists, "An active week must not offer final settlement.")
        attachScreenshot("Active single-goal money")

        // Saving an updated daily total replaces it instead of accumulating it.
        app.tabBars.buttons["Today"].tap()
        tap("update-today-steps")
        let entry = element("entry.total")
        XCTAssertTrue(entry.waitForExistence(timeout: 3))
        entry.tap()
        entry.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "6000")
        tap("entry.save")
        XCTAssertTrue(app.staticTexts["6,000 steps recorded"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["11,000 steps recorded"].exists)
    }

    func testStretchMustExceedBaseBeforeContinuing() {
        beginPlan(base: "5000")
        let toggle = app.switches["plan.stretchEnabled"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        toggle.tap()
        XCTAssertFalse(app.buttons["plan.continue"].isEnabled)

        enter("5000", into: "plan.stretch")
        XCTAssertFalse(app.buttons["plan.continue"].isEnabled, "Equal targets cannot create two tiers.")

        let field = element("plan.stretch")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "8000")
        XCTAssertTrue(app.buttons["plan.continue"].isEnabled)
        tap("plan.continue")
        XCTAssertTrue(app.switches["plan.consistencyEnabled"].waitForExistence(timeout: 3))
    }

    private func beginPlan(base: String) {
        let create = app.buttons["Create your walking plan"]
        XCTAssertTrue(create.waitForExistence(timeout: 8))
        create.tap()
        enter(base, into: "plan.base")
        tap("plan.continue")
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func enter(_ value: String, into identifier: String) {
        let keyboardDone = app.buttons["keyboard.done"]
        if keyboardDone.exists && keyboardDone.isHittable { keyboardDone.tap() }
        let field = element(identifier)
        XCTAssertTrue(field.waitForExistence(timeout: 4), "Missing input: \(identifier)")
        reveal(field, insideScroll: true)
        field.tap()
        field.typeText(value)
    }

    private func tap(_ identifier: String) {
        let button = app.buttons[identifier]
        XCTAssertTrue(button.waitForExistence(timeout: 4), "Missing action: \(identifier)")
        reveal(button)
        XCTAssertTrue(button.isEnabled, "Disabled action: \(identifier)")
        button.tap()
    }

    private func reveal(_ element: XCUIElement, insideScroll: Bool = false) {
        let containingScroll = app.scrollViews.containing(.any, identifier: element.identifier).firstMatch
        let scroll = containingScroll.exists ? containingScroll : app.scrollViews.firstMatch
        let requireViewport = insideScroll || containingScroll.exists
        let navigationBottom = app.navigationBars.firstMatch.frame.maxY
        let visibleTop = max(scroll.frame.minY, navigationBottom) + 12
        let tabBar = app.tabBars.firstMatch
        let bottomBoundary = tabBar.exists && tabBar.isHittable ? min(scroll.frame.maxY, tabBar.frame.minY) : scroll.frame.maxY
        let visibleBottom = bottomBoundary - 12
        for _ in 0..<32 {
            let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
            if element.isHittable && (!requireViewport || (visibleTop...visibleBottom).contains(center.y)) { return }
            let keyboardDone = app.buttons["keyboard.done"]
            if keyboardDone.exists && keyboardDone.isHittable { keyboardDone.tap() }
            else {
                // A fast swipe can fling a large-text field past both edges.
                // Short, held drags move through the actual viewport predictably.
                let downward = requireViewport && center.y < visibleTop
                // Use the form gutter so native date controls don't consume the drag.
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: downward ? 0.35 : 0.65))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: downward ? 0.65 : 0.35))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.2)
            }
        }
        attachScreenshot("Unreachable \(element.identifier)")
        let center = CGPoint(x: element.frame.midX, y: element.frame.midY)
        XCTAssertTrue(element.isHittable && (!requireViewport || (visibleTop...visibleBottom).contains(center.y)), "The element \(element.identifier) must be reachable between navigation and footer. Element: \(element.frame); scroll: \(scroll.frame).")
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
