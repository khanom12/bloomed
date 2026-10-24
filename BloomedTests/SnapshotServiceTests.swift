import XCTest
@testable import Bloomed

@MainActor
final class SnapshotServiceTests: XCTestCase {
    private final class Repository: StateRepository {
        var data: Data?
        func load() throws -> Data? { data }
        func save(_ data: Data) throws { self.data = data }
    }

    private final class Clock {
        var now = ISO8601DateFormatter().date(from: "2026-10-24T16:00:00Z")!
    }

    private let privateReason = "PRIVATE_MOTIVATION_9A"
    private let handler = "HANDLER_DETAILS_4D"
    private let supportNote = "SUPPORT_NOTE_8C"
    private let settlementNote = "SETTLEMENT_NOTE_2E"
    private let exceptionNote = "EXCEPTION_NOTE_1F"
    private let charity = "CHARITY_DESTINATION_6B"
    private let alias = "SUPPORT_ALIAS_7G"

    private func fixture(support: Bool = true, reviewed: Bool = true) throws -> (AppStore, WeeklyPlan, Clock) {
        let clock = Clock()
        let store = AppStore(repository: Repository(), clock: { clock.now })
        var draft = try store.beginDraft()
        draft.baseGoalText = "5000"
        draft.stretchEnabled = true
        draft.stretchGoalText = "8000"
        draft.consistencyEnabled = true
        draft.commitmentText = "35.00"
        draft.charity = charity
        draft.handling = .anotherPersonHolds
        draft.handlerDescription = handler
        draft.privateMotivation = privateReason
        draft.startDateKey = "2026-10-24"
        draft.timezoneID = "America/Toronto"
        try store.saveDraft(draft)
        let plan = try store.confirmDraft()
        try store.updateProfile(displayName: "Chosen public name", progressionPromptsEnabled: true)
        if support {
            try store.recordSupport(planID: plan.id, alias: alias, capCents: 700,
                agreementDate: clock.now, wholeWeekAcknowledged: true, note: supportNote)
        }
        try store.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 5000)
        if reviewed {
            clock.now = ISO8601DateFormatter().date(from: "2026-10-31T16:00:00Z")!
            try store.review(planID: plan.id, acknowledgeMissing: true)
            try store.recordSettlement(planID: plan.id, bucket: .personalReturn, amountCents: 100,
                effectiveDateKey: "2026-10-31", note: settlementNote)
            try store.noteException(planID: plan.id, note: exceptionNote)
        }
        return (store, plan, clock)
    }

    func testProgressWithoutMoneyOmitsAmountsCharityAndSupporterIdentity() throws {
        let (store, plan, clock) = try fixture()
        let content = SnapshotService.content(plan: plan, store: store, kind: .progress, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.moneyLines.isEmpty)
        XCTAssertFalse(content.text.contains(charity))
        XCTAssertFalse(content.text.contains(alias))
        XCTAssertFalse(content.text.contains(Format.money(plan.terms.commitmentCents)))
        for financialLabel in ["Personal commitment:", "Personal return calculated:", "Charity allocation:",
                               "Supporter reward calculated:", "Unused supporter allowance:", "1:1 match up to"] {
            XCTAssertFalse(content.text.contains(financialLabel), "Unexpected disclosure: \(financialLabel)")
        }
        XCTAssertEqual(content.activityLines.count, 7)
        XCTAssertTrue(content.targetLines.contains { $0.contains("Daily base:") })
        XCTAssertTrue(content.text.contains("Not independently verified"))
        XCTAssertEqual(content.timezoneID, plan.timezoneID)
    }

    func testPrivateMotivationHandlingAndAllNotesAreExcludedFromEveryExport() throws {
        let (store, plan, clock) = try fixture()
        // Ensure every canary actually exists in durable source data first.
        XCTAssertEqual(store.profile.privateMotivation, privateReason)
        XCTAssertEqual(plan.terms.handlerDescription, handler)
        XCTAssertTrue(store.state.auditEvents.contains { $0.reason == supportNote })
        XCTAssertTrue(store.state.settlements.contains { $0.note == settlementNote })
        XCTAssertTrue(store.state.exceptions.contains { $0.note == exceptionNote })
        for kind in SnapshotKind.allCases {
            for includeMoney in [false, true] {
                let content = SnapshotService.content(plan: plan, store: store, kind: kind,
                    includeMoney: includeMoney, at: clock.now)
                for secret in [privateReason, handler, supportNote, settlementNote, exceptionNote] {
                    XCTAssertFalse(content.text.contains(secret), "\(kind.rawValue) exposed a private field")
                }
                XCTAssertEqual(content.displayName, "Chosen public name")
            }
        }
    }

    func testReviewedSummaryIncludesReviewedAssessmentEvenWhenIncludeMoneyIsFalse() throws {
        let (store, plan, clock) = try fixture()
        let assessment = store.latestReviewedAssessment(for: plan)!.result
        let content = SnapshotService.content(plan: plan, store: store, kind: .reviewed, includeMoney: false, at: clock.now)
        XCTAssertEqual(content.status, "Reviewed calculation · payment is separate")
        XCTAssertTrue(content.moneyLines.contains("Personal commitment: \(Format.money(plan.terms.commitmentCents)) CAD"))
        XCTAssertTrue(content.moneyLines.contains("Personal return calculated: \(Format.money(assessment.personalReturnCents))"))
        XCTAssertTrue(content.moneyLines.contains("Charity allocation: \(Format.money(assessment.charityAllocationCents)) to \(charity)"))
        XCTAssertTrue(content.moneyLines.contains("Supporter reward calculated: \(Format.money(assessment.supporterRewardCents))"))
        XCTAssertTrue(content.moneyLines.contains("Unused supporter allowance: \(Format.money(assessment.unusedSupporterAllowanceCents)) stays with supporter"))
        XCTAssertTrue(content.text.contains("An earned amount is not proof of payment or donation."))
        // The external record remains a separate fact; the summary doesn't claim it verified.
        XCTAssertFalse(content.text.contains("verified payment"))
    }

    func testInvitationGenerationDoesNotActivateSupportOrMutateRecords() throws {
        let (store, plan, clock) = try fixture(support: false, reviewed: false)
        let original = store.state
        let content = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.moneyLines.contains("Invitation — no supporter agreement recorded"))
        XCTAssertTrue(content.moneyLines.contains("Would you match what I earn back, up to an amount you choose?"))
        XCTAssertFalse(content.moneyLines.isEmpty, "An invitation must preview its proposed financial context")
        XCTAssertTrue(content.activityLines.isEmpty, "An invitation does not need private dated activity")
        XCTAssertNil(store.support(for: plan))
        XCTAssertTrue(store.state.supportPeople.isEmpty)
        XCTAssertTrue(store.state.supportSnapshots.isEmpty)
        XCTAssertEqual(store.state, original)
    }

    func testSnapshotIncludesOnlySelectedWeekAndGenerationIsReadOnly() throws {
        let (store, first, clock) = try fixture()
        var draft = try store.beginDraft(repeating: first)
        draft.startDateKey = "2026-10-31"
        draft.baseGoalText = "6789"
        try store.saveDraft(draft)
        let other = try store.confirmDraft()
        let original = store.state
        let content = SnapshotService.content(plan: first, store: store, kind: .progress, includeMoney: true, at: clock.now)
        XCTAssertEqual(content.dateRange, Format.week(first))
        XCTAssertFalse(content.targetLines.contains { $0.contains(other.terms.baseGoalSteps.formatted()) })
        XCTAssertEqual(content.activityLines.count, first.dateKeys.count)
        XCTAssertEqual(store.state, original)
    }

    func testCorrectedProgressIsLabelledProvisionalRatherThanFinal() throws {
        let (store, plan, clock) = try fixture()
        try store.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000,
                              reason: "Corrected activity total")
        let content = SnapshotService.content(plan: plan, store: store, kind: .progress, includeMoney: true, at: clock.now)
        XCTAssertEqual(content.status, "Correction awaiting review · provisional")
        XCTAssertFalse(content.moneyLines.contains { $0.hasPrefix("Charity allocation:") })
        XCTAssertTrue(content.moneyLines.contains("Personal return calculated: \(Format.money(400))"))
        XCTAssertEqual(store.latestReviewedAssessment(for: plan)?.result.personalReturnCents, 100)
    }
}
