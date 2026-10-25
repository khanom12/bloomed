import XCTest
@testable import Bloomed

final class WalkingHistoryTests: XCTestCase {
    private let zone = "America/Toronto"
    private func plan(higher: Int? = 8000) throws -> WeeklyPlan {
        let terms = PlanTerms(baseGoalSteps: 5000, stretchGoalSteps: higher, commitmentCents: 3500, charity: "")
        let assessment = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: nil, count: 7))
        let date = try WeeklyCalendar.date(for: "2026-10-25", timezoneID: zone)
        return WeeklyPlan(participantID: UUID(), startDateKey: "2026-10-25", timezoneID: zone,
            dateKeys: try WeeklyCalendar.dateKeys(startDateKey: "2026-10-25", timezoneID: zone),
            terms: terms, createdAt: date, confirmedAt: date,
            dailyMaximumCents: assessment.dailyMaximumCents, consistencyReserveCents: assessment.consistencyReserveCents)
    }

    func testCalendarDistinguishesUpcomingMissingZeroAndBothGoals() throws {
        let plan = try plan()
        let now = try WeeklyCalendar.date(for: "2026-10-26", timezoneID: zone)
        XCTAssertEqual(WalkingCalendarDay(plan: plan, key: "2026-10-27", steps: nil, now: now).state, .upcoming)
        XCTAssertEqual(WalkingCalendarDay(plan: plan, key: "2026-10-25", steps: nil, now: now).state, .missing)
        let zero = WalkingCalendarDay(plan: plan, key: "2026-10-25", steps: 0, now: now)
        XCTAssertEqual(zero.state, .below)
        XCTAssertTrue(zero.description.contains("0 steps"))
        XCTAssertEqual(WalkingCalendarDay(plan: plan, key: "2026-10-25", steps: 5000, now: now).state, .everyday)
        XCTAssertEqual(WalkingCalendarDay(plan: plan, key: "2026-10-25", steps: 8000, now: now).state, .higher)
        var cancelled = plan
        cancelled.voidedAt = plan.confirmedAt
        XCTAssertEqual(WalkingCalendarDay(plan: cancelled, key: "2026-10-25", steps: nil, now: now).state, .noPlan)
    }

    func testSingleGoalSuccessAndHistoricalTargetsRemainIndependent() throws {
        let original = try plan(higher: nil)
        let now = try WeeklyCalendar.date(for: "2026-10-26", timezoneID: zone)
        XCTAssertEqual(WalkingCalendarDay(plan: original, key: original.startDateKey, steps: 5000, now: now).state, .everyday)
        var later = original
        later.terms.baseGoalSteps = 7000
        XCTAssertEqual(WalkingCalendarDay(plan: later, key: later.startDateKey, steps: 5000, now: now).state, .below)
        XCTAssertEqual(WalkingCalendarDay(plan: original, key: original.startDateKey, steps: 5000, now: now).state, .everyday)
    }
}
