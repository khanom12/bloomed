import XCTest
@testable import Bloomed

@MainActor
final class StoreTests: XCTestCase {
    final class MemoryRepository: StateRepository {
        var data: Data?
        var failLoad = false
        var failSave = false
        var saveCount = 0
        func load() throws -> Data? {
            if failLoad { throw StoreError.invalid("Simulated storage read failure") }
            return data
        }
        func save(_ data: Data) throws {
            if failSave { throw StoreError.invalid("Simulated storage write failure") }
            self.data = data
            saveCount += 1
        }
    }

    final class TestClock {
        var now = ISO8601DateFormatter().date(from: "2026-10-24T16:00:00Z")!
        func advance(to iso: String) { now = ISO8601DateFormatter().date(from: iso)! }
    }

    private func store(_ repository: MemoryRepository, _ time: TestClock) -> AppStore {
        AppStore(repository: repository, clock: { time.now })
    }

    private func confirm(_ store: AppStore, start: String = "2026-10-24", tiers: Bool = true,
                         consistency: Bool = true) throws -> WeeklyPlan {
        var draft = try store.beginDraft()
        draft.baseGoalText = "5000"
        draft.stretchEnabled = tiers
        draft.stretchGoalText = "8000"
        draft.consistencyEnabled = consistency
        draft.commitmentText = "35.00"
        draft.charity = "Chosen charity"
        draft.startDateKey = start
        draft.timezoneID = "America/Toronto"
        try store.saveDraft(draft)
        return try store.confirmDraft()
    }

    func testNewStoreIsEmptyAndDraftSurvivesRelaunch() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let first = store(repository, time)
        XCTAssertTrue(first.isLoaded)
        XCTAssertTrue(first.plans.isEmpty)
        XCTAssertNil(first.draft)
        var draft = try first.beginDraft()
        draft.baseGoalText = "3750"
        draft.privateMotivation = "A private reason"
        draft.step = 2
        try first.saveDraft(draft)
        let reopened = store(repository, time)
        XCTAssertEqual(reopened.draft, draft)
        XCTAssertTrue(reopened.plans.isEmpty)
        XCTAssertEqual(reopened.profile.id, first.profile.id)
    }

    func testFailedSavePublishesNoMutationAndRelaunchKeepsSavedState() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        let before = app.state
        repository.failSave = true
        XCTAssertThrowsError(try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000))
        XCTAssertEqual(app.state, before)
        XCTAssertNotNil(app.errorMessage)
        repository.failSave = false
        XCTAssertEqual(store(repository, time).state, before)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000)
        XCTAssertEqual(app.effectiveSteps(for: plan)[0], 8000)
    }

    func testUnreadableStoreIsBlockedUntilExplicitSuccessfulRetry() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        _ = try confirm(app)
        let saved = repository.data
        repository.failLoad = true
        let blocked = store(repository, time)
        XCTAssertFalse(blocked.isLoaded)
        XCTAssertFalse(blocked.canEdit)
        XCTAssertThrowsError(try blocked.beginDraft())
        XCTAssertEqual(repository.data, saved)
        repository.failLoad = false
        try blocked.retryLoad()
        XCTAssertTrue(blocked.isLoaded)
        XCTAssertEqual(blocked.state, app.state)
    }

    func testMissingZeroReplacementNoOpAndIdempotencyRemainDistinct() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        XCTAssertNil(app.effectiveSteps(for: plan)[0])
        let key = UUID()
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 0, transactionKey: key)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 0, transactionKey: key)
        XCTAssertEqual(app.state.stepRevisions.count, 1)
        XCTAssertEqual(app.effectiveSteps(for: plan)[0], 0)
        let count = app.state.assessments.count
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 0)
        XCTAssertEqual(app.state.assessments.count, count)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 6500)
        XCTAssertEqual(app.effectiveSteps(for: plan)[0], 6500)
        XCTAssertEqual(app.state.stepRevisions.count, 2)
        XCTAssertEqual(app.state.stepRevisions.last?.supersedesID, app.state.stepRevisions.first?.id)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: nil)
        XCTAssertNil(app.effectiveSteps(for: plan)[0])
        XCTAssertEqual(app.state.auditEvents.last?.action, .entryCleared)
    }

    func testFutureAndStaleDateEntryAreRejected() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        XCTAssertThrowsError(try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[1], total: 8000))
        XCTAssertThrowsError(try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000, expectedTodayKey: "2026-10-23"))
        XCTAssertTrue(app.state.stepRevisions.isEmpty)
    }

    func testReviewMissingAcknowledgementAndDuplicateReview() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        XCTAssertThrowsError(try app.review(planID: plan.id, acknowledgeMissing: true))
        time.advance(to: "2026-10-31T16:00:00Z")
        XCTAssertThrowsError(try app.review(planID: plan.id, acknowledgeMissing: false))
        try app.review(planID: plan.id, acknowledgeMissing: true)
        try app.review(planID: plan.id, acknowledgeMissing: true)
        XCTAssertEqual(app.state.financialEvents.count, 3)
        XCTAssertEqual(app.latestReviewedAssessment(for: plan)?.acknowledgedMissingDateKeys, plan.dateKeys)
        XCTAssertEqual(app.lifecycle(for: plan), .reviewed)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .charityAllocation).outstandingCents, 3500)
        XCTAssertTrue(app.state.settlements.isEmpty)
    }

    func testReviewedSettledCorrectionPreservesPaymentsAndPostsOnlyOnRereview() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        try app.recordSupport(planID: plan.id, alias: "Friend", capCents: 1000, agreementDate: time.now,
                              wholeWeekAcknowledged: true)
        time.advance(to: "2026-10-30T16:00:00Z")
        for (index, date) in plan.dateKeys.enumerated() {
            try app.recordSteps(planID: plan.id, dateKey: date, total: index < 5 ? 5000 : 0)
        }
        time.advance(to: "2026-10-31T16:00:00Z")
        try app.review(planID: plan.id, acknowledgeMissing: false)
        let old = app.latestReviewedAssessment(for: plan)!
        XCTAssertEqual(old.result.personalReturnCents, 1200)
        for bucket in FinancialBucket.allCases {
            try app.recordSettlement(planID: plan.id, bucket: bucket, amountCents: old.result.amount(for: bucket), effectiveDateKey: "2026-10-31")
        }
        let payments = app.state.settlements
        XCTAssertThrowsError(try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[4], total: 0))
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[4], total: 0, reason: "Corrected an entry error")
        XCTAssertEqual(app.lifecycle(for: plan), .awaitingReview)
        XCTAssertEqual(app.assessment(for: plan).personalReturnCents, 400)
        XCTAssertEqual(app.latestReviewedAssessment(for: plan)?.id, old.id)
        XCTAssertEqual(app.state.financialEvents.count, 3)
        XCTAssertEqual(app.state.settlements, payments)
        XCTAssertThrowsError(try app.recordSettlement(planID: plan.id, bucket: .charityAllocation,
            amountCents: 1, effectiveDateKey: "2026-10-31"))
        try app.review(planID: plan.id, acknowledgeMissing: false)
        XCTAssertEqual(app.state.financialEvents.count, 6)
        XCTAssertEqual(app.state.financialEvents.suffix(3).map(\.deltaCents), [-800, 800, -600])
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .personalReturn).excessCents, 800)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .supporterReward).excessCents, 600)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .charityAllocation).outstandingCents, 800)
        XCTAssertTrue(app.reconciliationRequired(for: plan))
        XCTAssertEqual(store(repository, time).state, app.state)
    }

    func testSameTierCorrectionStillRequiresReviewAndZeroDeltaEvents() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 5000)
        time.advance(to: "2026-10-31T16:00:00Z")
        try app.review(planID: plan.id, acknowledgeMissing: true)
        let before = app.assessment(for: plan)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 6000, reason: "Corrected total")
        XCTAssertEqual(app.assessment(for: plan), before)
        XCTAssertEqual(app.lifecycle(for: plan), .awaitingReview)
        try app.review(planID: plan.id, acknowledgeMissing: true)
        XCTAssertEqual(app.state.financialEvents.suffix(3).map(\.deltaCents), [0, 0, 0])
    }

    func testPartialSettlementDuplicateKeyAndVoidingPreserveOriginal() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        time.advance(to: "2026-10-31T16:00:00Z")
        try app.review(planID: plan.id, acknowledgeMissing: true)
        let key = UUID()
        try app.recordSettlement(planID: plan.id, bucket: .charityAllocation, amountCents: 500, effectiveDateKey: "2026-10-31", transactionKey: key)
        try app.recordSettlement(planID: plan.id, bucket: .charityAllocation, amountCents: 500, effectiveDateKey: "2026-10-31", transactionKey: key)
        XCTAssertEqual(app.state.settlements.count, 1)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .charityAllocation).outstandingCents, 3000)
        XCTAssertThrowsError(try app.recordSettlement(planID: plan.id, bucket: .charityAllocation, amountCents: 3001, effectiveDateKey: "2026-10-31"))
        let record = app.state.settlements[0]
        XCTAssertThrowsError(try app.voidSettlement(id: record.id, reason: ""))
        try app.voidSettlement(id: record.id, reason: "Recorded the wrong amount")
        XCTAssertEqual(app.state.settlements[0].amountCents, 500)
        XCTAssertNotNil(app.state.settlements[0].voidedAt)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .charityAllocation).outstandingCents, 3500)
    }

    func testStandingSupportReusesOnlyMatchingWholeWeekTermsAndPausePreservesHistory() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let first = try confirm(app)
        try app.recordSupport(planID: first.id, alias: "Partner", capCents: 1500,
            agreementDate: time.now, standing: true, wholeWeekAcknowledged: true)
        let originalSupport = app.support(for: first)!
        var draft = try app.beginDraft(repeating: first)
        draft.startDateKey = "2026-10-31"
        try app.saveDraft(draft)
        let second = try app.confirmDraft()
        XCTAssertEqual(app.support(for: second)?.capCents, 1500)
        XCTAssertNotEqual(app.support(for: second)?.id, originalSupport.id)
        let standingID = app.state.standingAgreements[0].id
        try app.pauseStandingAgreement(id: standingID)
        let pausedAt = app.state.standingAgreements[0].pausedAt
        time.advance(to: "2026-10-25T16:00:00Z")
        try app.pauseStandingAgreement(id: standingID)
        XCTAssertEqual(app.state.standingAgreements[0].pausedAt, pausedAt)
        XCTAssertEqual(app.support(for: first), originalSupport)
        XCTAssertEqual(app.support(for: second)?.capCents, 1500)
        time.advance(to: "2026-10-31T16:00:00Z")
        var next = try app.beginDraft(repeating: second)
        next.startDateKey = "2026-11-07"
        try app.saveDraft(next)
        let third = try app.confirmDraft()
        XCTAssertNil(app.support(for: third))
    }

    func testCorrectedAliasIsPreservedInFutureStandingSnapshot() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let first = try confirm(app)
        try app.recordSupport(planID: first.id, alias: "Original alias", capCents: 1500,
            agreementDate: time.now, standing: true, wholeWeekAcknowledged: true)
        let original = app.state.supportSnapshots[0]
        try app.recordSupport(planID: first.id, alias: "Corrected alias", capCents: 1500,
            agreementDate: time.now, standing: true, wholeWeekAcknowledged: true,
            correctionReason: "Corrected the alias")
        _ = try app.beginDraft(repeating: first)
        let second = try app.confirmDraft()
        XCTAssertEqual(app.support(for: second)?.alias, "Corrected alias")
        XCTAssertEqual(app.state.supportSnapshots.first, original)
        XCTAssertEqual(original.alias, "Original alias")
    }

    func testChangedWalkingTermsDoNotAutomaticallyReuseStandingMatch() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let first = try confirm(app)
        try app.recordSupport(planID: first.id, alias: "Partner", capCents: 1500,
            agreementDate: time.now, standing: true, wholeWeekAcknowledged: true)
        var draft = try app.beginDraft(repeating: first)
        draft.baseGoalText = "5500"
        try app.saveDraft(draft)
        let second = try app.confirmDraft()
        XCTAssertNil(app.support(for: second))
        XCTAssertEqual(app.support(for: first)?.capCents, 1500)
        XCTAssertEqual(first.terms.baseGoalSteps, 5000)
    }

    func testSameConfirmationTransactionNeverCreatesSecondCommitment() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        var draft = try app.beginDraft()
        draft.baseGoalText = "5000"
        draft.commitmentText = "20.00"
        draft.charity = "Chosen charity"
        try app.saveDraft(draft)
        let key = UUID()
        let first = try app.confirmDraft(transactionKey: key)
        let repeated = try app.confirmDraft(transactionKey: key)
        XCTAssertEqual(first.id, repeated.id)
        XCTAssertEqual(app.plans.count, 1)
        XCTAssertEqual(app.state.auditEvents.filter { $0.action == .planConfirmed }.count, 1)
    }

    func testRemoveMistakenSupportRetainsOriginalSnapshotAndRequiresRereview() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        try app.recordSupport(planID: plan.id, alias: "Friend", capCents: 1000,
            agreementDate: time.now, wholeWeekAcknowledged: true)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 8000)
        time.advance(to: "2026-10-31T16:00:00Z")
        try app.review(planID: plan.id, acknowledgeMissing: true)
        XCTAssertEqual(app.assessment(for: plan).supporterRewardCents, 400)
        try app.recordSettlement(planID: plan.id, bucket: .supporterReward, amountCents: 400, effectiveDateKey: "2026-10-31")
        let originalPayment = app.state.settlements[0]
        try app.removeSupport(planID: plan.id, reason: "This agreement was entered against the wrong week")
        XCTAssertNil(app.support(for: plan))
        XCTAssertEqual(app.state.supportSnapshots.count, 2)
        XCTAssertTrue(app.state.supportSnapshots[0].applies)
        XCTAssertFalse(app.state.supportSnapshots[1].applies)
        XCTAssertEqual(app.lifecycle(for: plan), .awaitingReview)
        XCTAssertEqual(app.state.financialEvents.count, 3)
        try app.review(planID: plan.id, acknowledgeMissing: true)
        XCTAssertEqual(app.state.financialEvents.last?.deltaCents, -400)
        XCTAssertEqual(app.state.settlements[0], originalPayment)
        XCTAssertEqual(app.reconciliation(for: plan, bucket: .supporterReward).excessCents, 400)
    }

    func testInvalidRestoreAndFailedRestorePreserveExistingData() throws {
        let repository = MemoryRepository()
        let time = TestClock()
        let app = store(repository, time)
        let plan = try confirm(app)
        try app.recordSteps(planID: plan.id, dateKey: plan.dateKeys[0], total: 5000)
        let previous = app.state
        let backup = try app.exportBackup()
        var corrupt = try JSONDecoder().decode(BackupEnvelope.self, from: backup)
        corrupt.state.assessments[0].result.personalReturnCents = 99
        XCTAssertThrowsError(try app.restoreBackup(JSONEncoder().encode(corrupt)))
        XCTAssertEqual(app.state, previous)
        corrupt = try JSONDecoder().decode(BackupEnvelope.self, from: backup)
        corrupt.schemaVersion = 999
        XCTAssertThrowsError(try app.restoreBackup(JSONEncoder().encode(corrupt)))
        repository.failSave = true
        XCTAssertThrowsError(try app.restoreBackup(backup))
        XCTAssertEqual(app.state, previous)
        repository.failSave = false
        try app.deleteLocalData()
        XCTAssertTrue(app.plans.isEmpty)
        try app.restoreBackup(backup)
        XCTAssertEqual(app.state, previous)
        XCTAssertEqual(store(repository, time).state, previous)
    }

    func testAtomicJSONRepositoryDurablyReplacesSnapshot() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let repository = AtomicJSONRepository(fileURL: directory.appendingPathComponent("store.json"))
        XCTAssertNil(try repository.load())
        try repository.save(Data("first".utf8))
        try repository.save(Data("second".utf8))
        XCTAssertEqual(try repository.load(), Data("second".utf8))
    }
}
