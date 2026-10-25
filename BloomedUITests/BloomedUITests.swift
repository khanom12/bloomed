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
            XCTAssertTrue(app.tabBars.buttons[title].exists)
        }
        app.tabBars.buttons["My plan"].tap()
        XCTAssertTrue(app.staticTexts["Make your first walking plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Create your walking plan"].exists)
        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["See your walking take shape"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Create your walking plan"].exists)
        app.tabBars.buttons["Money"].tap()
        XCTAssertTrue(app.buttons["Create your walking plan"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("money.current-week").exists)
        app.tabBars.buttons["Today"].tap()
        attachScreenshot("First-use product explanation")
    }

    func testSingleGoalPlanCanStartTodayRecordTotalAndShowMoney() {
        reachReview()
        tap("plan.startToday")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Today is Day 1")).firstMatch.exists)
        confirmPlan()
        tap("update-today-steps")
        enter("5000", into: "entry.total")
        tap("entry.save")
        XCTAssertTrue(app.staticTexts["5,000 steps recorded"].waitForExistence(timeout: 5))
        attachScreenshot("Active Today with recorded steps")
        app.tabBars.buttons["Money"].tap()
        XCTAssertTrue(element("money.current-week").waitForExistence(timeout: 3))
        let earned = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@ AND label CONTAINS %@", "earned back", "5.00")).firstMatch
        XCTAssertTrue(earned.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Record donation made"].exists)
        attachScreenshot("Active Money estimates")
        app.tabBars.buttons["Today"].tap()
        tap("update-today-steps")
        replace("5000", with: "6000", in: "entry.total")
        tap("entry.save")
        XCTAssertTrue(app.staticTexts["6,000 steps recorded"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["11,000 steps recorded"].exists)
    }

    func testHigherGoalValidationAndConsistencyExplainExactAmounts() {
        beginPlan(base: "5000")
        enter("35.00", into: "plan.commitment")
        XCTAssertTrue(app.buttons["plan.continue"].isEnabled, "Charity may be chosen later")
        tap("plan.continue")
        let higher = app.switches["plan.stretchEnabled"]
        XCTAssertTrue(higher.waitForExistence(timeout: 3))
        XCTAssertEqual(higher.value as? String, "0")
        higher.tap()
        XCTAssertFalse(app.buttons["plan.continue"].isEnabled)
        enter("5000", into: "plan.stretch")
        XCTAssertFalse(app.buttons["plan.continue"].isEnabled)
        replace("5000", with: "8000", in: "plan.stretch")
        XCTAssertTrue(app.buttons["plan.continue"].isEnabled)
        attachScreenshot("Higher goal financial tradeoff")
        tap("plan.continue")
        let consistency = app.switches["plan.consistencyEnabled"]
        XCTAssertTrue(consistency.waitForExistence(timeout: 3))
        consistency.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", "7.00", "35.00")).firstMatch.waitForExistence(timeout: 3))
        attachScreenshot("Consistency from the same amount")
        tap("plan.continue")
        XCTAssertTrue(app.buttons["plan.confirm"].waitForExistence(timeout: 3))
    }

    func testSavedDraftResumesFromEitherTabWithoutLosingAmount() {
        beginPlan(base: "5000")
        enter("35.00", into: "plan.commitment")
        tap("plan.continue")
        XCTAssertTrue(app.switches["plan.stretchEnabled"].waitForExistence(timeout: 3))
        app.buttons["Save & close"].tap()
        app.tabBars.buttons["My plan"].tap()
        tap("Continue your walking plan")
        XCTAssertTrue(app.switches["plan.stretchEnabled"].waitForExistence(timeout: 3))
        tap("Back")
        let amount = element("plan.commitment")
        XCTAssertTrue(amount.waitForExistence(timeout: 3))
        XCTAssertEqual(amount.value as? String, "35.00")
        app.buttons["Save & close"].tap()
        app.tabBars.buttons["Today"].tap()
        tap("Continue your walking plan")
        XCTAssertTrue(element("plan.commitment").waitForExistence(timeout: 3))
    }

    func testInvitationStartsInInvitationModeWithoutRecordingSupport() {
        reachReview()
        tap("plan.confirm")
        XCTAssertTrue(app.staticTexts["Your week is ready."].waitForExistence(timeout: 5))
        tap("Invite a supporter · optional")
        tap("support.invite")
        let invitation = app.segmentedControls.buttons["Invitation"]
        XCTAssertTrue(invitation.waitForExistence(timeout: 3))
        XCTAssertTrue(invitation.isSelected)
        XCTAssertFalse(element("support.alias").exists)
        attachScreenshot("Recipient-oriented invitation preview")
        app.navigationBars["Preview before sharing"].buttons["Done"].tap()
        XCTAssertTrue(app.buttons["support.record-agreement"].waitForExistence(timeout: 3), "Sharing preparation must not record a supporter")
    }

    func testProgressMonthAndHistoryOpenWalkingInsteadOfAgreement() {
        reachReview()
        tap("plan.startToday")
        confirmPlan()
        tap("update-today-steps")
        enter("5000", into: "entry.total")
        tap("entry.save")
        app.tabBars.buttons["Progress"].tap()
        let month = app.segmentedControls.buttons["Month"]
        XCTAssertTrue(month.waitForExistence(timeout: 3))
        month.tap()
        XCTAssertTrue(app.staticTexts["Your walking calendar"].waitForExistence(timeout: 3))
        attachScreenshot("Monthly walking calendar")
        app.segmentedControls.buttons["Week"].tap()
        let week = app.buttons.matching(identifier: "walking.history-week").firstMatch
        XCTAssertTrue(week.waitForExistence(timeout: 3))
        reveal(week)
        week.tap()
        XCTAssertTrue(app.navigationBars["Weekly walking"].waitForExistence(timeout: 3))
        attachScreenshot("Historical walking detail")
    }

    func testRapidContinueDoesNotSkipTheHigherGoalChoice() {
        beginPlan(base: "5000")
        enter("35.00", into: "plan.commitment")
        let done = app.buttons["keyboard.done"]
        if done.exists && done.isHittable { done.tap() }
        app.buttons["plan.continue"].doubleTap()
        XCTAssertTrue(app.switches["plan.stretchEnabled"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.switches["plan.consistencyEnabled"].exists)
    }

    func testLargestTextInDarkModeCanCreatePlanAndRecordSteps() {
        app.terminate()
        app.launchArguments += ["--ui-testing-large-text", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        reachReview()
        tap("plan.startToday")
        attachScreenshot("Largest text dark review")
        confirmPlan()
        tap("update-today-steps")
        enter("5000", into: "entry.total")
        tap("entry.save")
        XCTAssertTrue(app.staticTexts["5,000 steps recorded"].waitForExistence(timeout: 5))
        attachScreenshot("Largest text dark recorded steps")
    }

    func testMyPlanCanOpenAnAlreadyAgreedMatchDirectly() {
        reachReview()
        tap("plan.confirm")
        XCTAssertTrue(app.staticTexts["Your week is ready."].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()
        app.tabBars.buttons["My plan"].tap()
        let planCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "View plan details")).firstMatch
        XCTAssertTrue(planCard.waitForExistence(timeout: 3))
        reveal(planCard)
        planCard.tap()
        tap("Record an agreement already made")
        XCTAssertTrue(element("support.alias").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["support.record-agreement"].exists)
        attachScreenshot("Direct supporter agreement form")
    }

    private func beginPlan(base: String) {
        tap("Create your walking plan")
        enter(base, into: "plan.base")
        tap("plan.continue")
        XCTAssertTrue(element("plan.commitment").waitForExistence(timeout: 3), "Money must be explained before optional financial choices")
    }

    private func reachReview() {
        beginPlan(base: "5000")
        enter("35.00", into: "plan.commitment")
        tap("plan.continue")
        XCTAssertTrue(app.switches["plan.stretchEnabled"].waitForExistence(timeout: 3))
        tap("plan.continue")
        XCTAssertTrue(app.switches["plan.consistencyEnabled"].waitForExistence(timeout: 3))
        tap("plan.continue")
        XCTAssertTrue(app.buttons["plan.confirm"].waitForExistence(timeout: 3))
    }

    private func confirmPlan() {
        tap("plan.confirm")
        XCTAssertTrue(app.staticTexts["Your week is ready."].waitForExistence(timeout: 5))
        app.buttons["Done"].firstMatch.tap()
        XCTAssertTrue(app.buttons["update-today-steps"].waitForExistence(timeout: 5))
    }

    private func replace(_ old: String, with value: String, in identifier: String) {
        let field = element(identifier)
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count) + value)
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
