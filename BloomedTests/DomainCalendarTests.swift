import XCTest
@testable import Bloomed

final class DomainCalendarTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private func plan(start: String, zone: String = "America/Toronto") throws -> WeeklyPlan {
        let terms = PlanTerms(baseGoalSteps: 5000, commitmentCents: 3500, charity: "Chosen charity")
        let schedule = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: nil, count: 7))
        let confirmed = try WeeklyCalendar.date(for: "2026-01-01", timezoneID: zone)
        return WeeklyPlan(participantID: owner, startDateKey: start, timezoneID: zone,
                          dateKeys: try WeeklyCalendar.dateKeys(startDateKey: start, timezoneID: zone), terms: terms,
                          createdAt: confirmed, confirmedAt: confirmed, dailyMaximumCents: schedule.dailyMaximumCents,
                          consistencyReserveCents: schedule.consistencyReserveCents)
    }

    func testSpringDSTHasSevenDatesAnd167Hours() throws {
        let value = try plan(start: "2026-03-02")
        XCTAssertEqual(value.dateKeys, ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06", "2026-03-07", "2026-03-08"])
        let interval = try WeeklyCalendar.interval(for: value)
        XCTAssertEqual(interval.duration / 3600, 167)
        XCTAssertEqual(WeeklyCalendar.dateKey(for: interval.end, timezoneID: value.timezoneID), "2026-03-09")
    }

    func testAutumnDSTHasSevenDatesAnd169Hours() throws {
        let value = try plan(start: "2026-10-26")
        let interval = try WeeklyCalendar.interval(for: value)
        XCTAssertEqual(value.dateKeys.count, 7)
        XCTAssertEqual(value.dateKeys.last, "2026-11-01")
        XCTAssertEqual(interval.duration / 3600, 169)
        XCTAssertEqual(WeeklyCalendar.dateKey(for: interval.end, timezoneID: value.timezoneID), "2026-11-02")
    }

    func testCrossTimezoneOverlapUsesAbsoluteBoundaries() throws {
        let toronto = try plan(start: "2026-10-26")
        let tokyo = try plan(start: "2026-11-02", zone: "Asia/Tokyo")
        XCTAssertTrue(try WeeklyCalendar.intervalsOverlap(toronto, tokyo))
        let adjacent = try plan(start: "2026-11-02")
        XCTAssertFalse(try WeeklyCalendar.intervalsOverlap(toronto, adjacent))
        let now = try WeeklyCalendar.date(for: "2026-10-27", timezoneID: "America/Toronto")
        XCTAssertThrowsError(try WeeklyCalendar.validateConfirmation(tokyo, among: [toronto], now: now))
        XCTAssertNoThrow(try WeeklyCalendar.validateConfirmation(adjacent, among: [toronto], now: now))
    }

    func testInvalidDatesDoNotNormalizeSilently() throws {
        for key in ["2026-02-30", "2026-13-01", "2026-1-01", "2026-01-1", "26-01-01", "2026-00-01", "2026-01-00", "not a date"] {
            XCTAssertThrowsError(try WeeklyCalendar.date(for: key, timezoneID: "America/Toronto"), key)
        }
        XCTAssertThrowsError(try WeeklyCalendar.date(for: "2026-10-26", timezoneID: "invalid/timezone"))
    }

    func testLifecycleChangesAtPinnedBoundariesWithoutBackgroundMutation() throws {
        var value = try plan(start: "2026-10-26")
        let interval = try WeeklyCalendar.interval(for: value)
        XCTAssertEqual(try WeeklyCalendar.status(for: value, now: interval.start.addingTimeInterval(-1), latestAssessment: nil), .scheduled)
        XCTAssertEqual(try WeeklyCalendar.status(for: value, now: interval.start, latestAssessment: nil), .active)
        XCTAssertEqual(try WeeklyCalendar.status(for: value, now: interval.end.addingTimeInterval(-1), latestAssessment: nil), .active)
        XCTAssertEqual(try WeeklyCalendar.status(for: value, now: interval.end, latestAssessment: nil), .awaitingReview)
        XCTAssertEqual(try WeeklyCalendar.closedDayCount(for: value, now: interval.start), 0)
        XCTAssertEqual(try WeeklyCalendar.closedDayCount(for: value, now: interval.end), 7)
        value.voidedAt = interval.start.addingTimeInterval(-1)
        XCTAssertEqual(try WeeklyCalendar.status(for: value, now: interval.end, latestAssessment: nil), .voidedBeforeStart)
    }

    func testRepeatFindsFutureNonoverlappingDatesAndDoesNotBackfill() throws {
        let old = try plan(start: "2026-03-02")
        let now = try WeeklyCalendar.date(for: "2026-10-24", timezoneID: "America/Toronto")
        XCTAssertEqual(try WeeklyCalendar.nextAvailableStart(after: old, among: [old], now: now, timezoneID: "America/Toronto"), "2026-10-25")
        let scheduled = try plan(start: "2026-10-25")
        XCTAssertEqual(try WeeklyCalendar.nextAvailableStart(after: old, among: [old, scheduled], now: now, timezoneID: "America/Toronto"), "2026-11-01")
        let extra = try plan(start: "2026-11-01")
        XCTAssertThrowsError(try WeeklyCalendar.validateConfirmation(extra, among: [scheduled], now: now))
    }

    func testStandingAgreementNeedsWholeWeekAndPreservedFundingTerms() throws {
        let value = try plan(start: "2026-10-26")
        let recorded = try WeeklyCalendar.date(for: "2026-10-24", timezoneID: value.timezoneID)
        var agreement = StandingAgreement(participantID: owner, personID: UUID(), relationshipID: UUID(), capCents: 1000,
                                          effectiveStartDateKey: "2026-10-24", timezoneID: value.timezoneID, preservedTerms: value.terms,
                                          externallyAgreedDateKey: "2026-10-24", recordedAt: recorded, recorderID: owner)
        XCTAssertTrue(agreement.applies(to: value))
        var changed = value
        changed.terms.baseGoalSteps = 6000
        XCTAssertFalse(agreement.applies(to: changed))
        agreement.inclusiveEndDateKey = "2026-10-31"
        XCTAssertFalse(agreement.applies(to: value))
        agreement.inclusiveEndDateKey = "2026-11-01"
        XCTAssertTrue(agreement.applies(to: value))
        agreement.pausedAt = recorded
        XCTAssertFalse(agreement.applies(to: value))
    }
}
