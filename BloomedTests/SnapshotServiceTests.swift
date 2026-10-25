import XCTest
import SwiftUI
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

    private func fixture(support: Bool = true, reviewed: Bool = true, supportCapCents: Int = 700, standing: Bool = false, charityDestination: String? = nil, supporterAlias: String? = nil) throws -> (AppStore, WeeklyPlan, Clock) {
        let clock = Clock()
        let store = AppStore(repository: Repository(), clock: { clock.now })
        var draft = try store.beginDraft()
        draft.baseGoalText = "5000"
        draft.stretchEnabled = true
        draft.stretchGoalText = "8000"
        draft.consistencyEnabled = true
        draft.commitmentText = "35.00"
        draft.charity = charityDestination ?? charity
        draft.handling = .anotherPersonHolds
        draft.handlerDescription = handler
        draft.privateMotivation = privateReason
        draft.startDateKey = "2026-10-24"
        draft.timezoneID = "America/Toronto"
        try store.saveDraft(draft)
        let plan = try store.confirmDraft()
        try store.updateProfile(displayName: "Chosen public name", progressionPromptsEnabled: true)
        if support {
            try store.recordSupport(planID: plan.id, alias: supporterAlias ?? alias, capCents: supportCapCents,
                agreementDate: clock.now, standing: standing, wholeWeekAcknowledged: true, note: supportNote)
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
        for financialLabel in ["My own weekly commitment:", "My money earned back", "Planned donation:",
                               "Extra supporter match calculated:", "Unused part of the match limit:", "weekly match limit"] {
            XCTAssertFalse(content.text.contains(financialLabel), "Unexpected disclosure: \(financialLabel)")
        }
        XCTAssertEqual(content.activityLines.count, 7)
        XCTAssertTrue(content.targetLines.contains { $0.contains("Everyday goal:") })
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
        XCTAssertTrue(content.moneyLines.contains("My own weekly commitment: \(Format.money(plan.terms.commitmentCents)) CAD"))
        XCTAssertTrue(content.moneyLines.contains("My money earned back (reviewed): \(Format.money(assessment.personalReturnCents))"))
        XCTAssertTrue(content.moneyLines.contains("Planned donation: \(Format.money(assessment.charityAllocationCents)) to \(charity)"))
        XCTAssertTrue(content.moneyLines.contains("Extra supporter match calculated: \(Format.money(assessment.supporterRewardCents))"))
        XCTAssertTrue(content.moneyLines.contains("Unused part of the match limit: \(Format.money(assessment.unusedSupporterAllowanceCents)) stays with the supporter."))
        XCTAssertTrue(content.text.contains("An earned amount is not proof of payment or donation."))
        // The external record remains a separate fact; the summary doesn't claim it verified.
        XCTAssertFalse(content.text.contains("verified payment"))
    }

    func testInvitationGenerationDoesNotActivateSupportOrMutateRecords() throws {
        let (store, plan, clock) = try fixture(support: false, reviewed: false)
        let original = store.state
        let content = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.moneyLines.contains("Invitation — no supporter agreement recorded"))
        XCTAssertTrue(content.moneyLines.contains { $0.contains("Would you match $1 for every $1 I earn back") })
        XCTAssertTrue(content.text.contains("There is nothing to accept or pay in Bloomed."))
        XCTAssertTrue(content.text.contains("the most you could add is \(Format.money(plan.terms.commitmentCents))"))
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
        XCTAssertFalse(content.moneyLines.contains { $0.hasPrefix("Planned donation:") })
        XCTAssertTrue(content.moneyLines.contains("My money earned back so far: \(Format.money(400))"))
        XCTAssertEqual(store.latestReviewedAssessment(for: plan)?.result.personalReturnCents, 100)
    }

    func testLargeMatchLimitExplainsOneToOneMaximumWithoutChangingCalculatedMatch() throws {
        let (store, plan, clock) = try fixture(reviewed: false, supportCapCents: 35_000)
        let before = store.state
        let content = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.text.contains("$1 for every $1 of my own money earned back"))
        XCTAssertTrue(content.text.contains("up to \(Format.money(35_000)) per week"))
        XCTAssertTrue(content.text.contains("largest possible match for this plan is \(Format.money(3500))"))
        XCTAssertTrue(content.text.contains("does not multiply the match"))
        XCTAssertTrue(content.text.contains("not independently confirmed by the supporter"))
        XCTAssertEqual(store.assessment(for: plan).supporterRewardCents, 100)
        XCTAssertEqual(store.state, before)
    }

    func testSmallerMatchLimitIsTheMaximumShownInTheInvitation() throws {
        let (store, plan, clock) = try fixture(reviewed: false, supportCapCents: 700)
        let content = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.text.contains("largest possible match for this plan is \(Format.money(700))"))
        XCTAssertFalse(content.text.contains("does not multiply the match"))
    }

    func testRecurringSupportExplainsWeeklyResetAndRequiresWholeWeeks() throws {
        let (store, plan, clock) = try fixture(reviewed: false, standing: true)
        let before = store.state
        let content = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(content.text.contains("Recurring agreement:"))
        XCTAssertTrue(content.text.contains("limit resets for each confirmed week with unchanged terms"))
        XCTAssertTrue(content.text.contains("Each whole week must be covered"))
        XCTAssertTrue(content.text.contains("no plans or charges are created automatically"))
        XCTAssertEqual(store.state, before)
    }

    func testMissingAndLaterChosenDonationDestinationUseTheSamePreservedPlan() throws {
        let (store, plan, clock) = try fixture(reviewed: false, charityDestination: "")
        let invitation = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(invitation.text.contains("Donation destination: not chosen yet."))
        try store.recordCharityDestination(planID: plan.id, destination: charity)
        let updated = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: false, at: clock.now)
        XCTAssertTrue(updated.text.contains("Donation destination: \(charity)"))
        XCTAssertEqual(store.plan(id: plan.id)?.terms.charity, "", "Sharing must not rewrite the original weekly terms")
        let privateProgress = SnapshotService.content(plan: plan, store: store, kind: .progress, includeMoney: false, at: clock.now)
        XCTAssertFalse(privateProgress.text.contains(charity))
    }

    func testUnreviewedCorrectionCannotBeExportedAsReviewedByCallingServiceDirectly() throws {
        let (store, plan, clock) = try fixture()
        try store.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000,
                              reason: "Corrected activity total")
        let content = SnapshotService.content(plan: plan, store: store, kind: .reviewed, includeMoney: true, at: clock.now)
        XCTAssertEqual(content.kind, .progress)
        XCTAssertEqual(content.status, "Correction awaiting review · provisional")
        XCTAssertFalse(content.moneyLines.contains { $0.hasPrefix("Planned donation:") })
        XCTAssertFalse(content.text.contains("Reviewed calculation · payment is separate"))
    }

    func testMistakenSupportRecordIsNotExportedAsAnActiveMatch() throws {
        let (store, plan, clock) = try fixture(reviewed: false)
        try store.removeSupport(planID: plan.id, reason: "The match was recorded for the wrong week")
        XCTAssertFalse(try XCTUnwrap(store.state.effectiveSupport(for: plan.id)).applies)
        let before = store.state
        let invitation = SnapshotService.content(plan: plan, store: store, kind: .invitation, includeMoney: true, at: clock.now)
        XCTAssertFalse(invitation.text.contains(alias))
        XCTAssertTrue(invitation.text.contains("Invitation — no supporter agreement recorded"))
        let progress = SnapshotService.content(plan: plan, store: store, kind: .progress, includeMoney: true, at: clock.now)
        XCTAssertFalse(progress.moneyLines.contains { $0.contains("Extra supporter match calculated:") })
        XCTAssertFalse(progress.text.contains(alias))
        XCTAssertEqual(store.state, before)
    }

    func testFutureDaysAreUpcomingRatherThanMissingEntries() throws {
        let (store, first, clock) = try fixture(support: false, reviewed: false)
        let active = SnapshotService.content(plan: first, store: store, kind: .progress, includeMoney: false, at: clock.now)
        XCTAssertEqual(active.activityLines.filter { $0.contains("Upcoming") }.count, 6)
        var draft = try store.beginDraft(repeating: first)
        draft.startDateKey = "2026-10-31"
        try store.saveDraft(draft)
        let upcoming = try store.confirmDraft()
        let content = SnapshotService.content(plan: upcoming, store: store, kind: .progress, includeMoney: false, at: clock.now)
        XCTAssertEqual(content.activityLines.count, 7)
        XCTAssertTrue(content.activityLines.allSatisfy { $0.hasSuffix("Upcoming") })
        XCTAssertFalse(content.activityLines.contains { $0.hasSuffix("Not recorded") })
    }

    func testShareImagesRenderAtExportSizeWithLongPublicLabels() throws {
        let exports: [(SnapshotKind, String)] = [
            (.invitation, "Invitation export"),
            (.progress, "Progress export"),
            (.reviewed, "Reviewed export")
        ]
        for (kind, name) in exports {
            let (store, plan, clock) = try fixture(
                support: kind != .invitation, reviewed: kind == .reviewed,
                charityDestination: "Community Walking and Neighbourhood Support Foundation — a longer example destination",
                supporterAlias: "Aunt Alexandra and the family walking supporters")
            try store.updateProfile(displayName: "Alexandra Morgan — building a regular walking routine", progressionPromptsEnabled: true)
            let content = SnapshotService.content(plan: plan, store: store, kind: kind, includeMoney: true, at: clock.now)
            let renderer = ImageRenderer(content: SnapshotCard(content: content)
                .frame(width: 390).environment(\.colorScheme, .light).dynamicTypeSize(.large))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
            XCTAssertEqual(image.size.width, 390, accuracy: 0.5, "\(name) has an unexpected export width")
            XCTAssertGreaterThan(image.size.height, image.size.width, "\(name) should grow to fit its content")
            XCTAssertGreaterThan(try XCTUnwrap(image.cgImage).height, 0)
            let attachment = XCTAttachment(image: image)
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
