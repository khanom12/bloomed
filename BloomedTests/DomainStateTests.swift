import XCTest
@testable import Bloomed

final class DomainStateTests: XCTestCase {
    private func reviewedState(steps: Int = 8000, charity: String = "Chosen charity") throws -> BloomedState {
        var state = BloomedState()
        let owner = state.profile.id
        let zone = "America/Toronto"
        let confirmation = try WeeklyCalendar.date(for: "2026-10-24", timezoneID: zone)
        let review = try WeeklyCalendar.date(for: "2026-11-02", timezoneID: zone)
        let terms = PlanTerms(baseGoalSteps: 5000, stretchGoalSteps: 8000, consistencyEnabled: true,
                              commitmentCents: 3500, charity: charity)
        let initial = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: nil, count: 7))
        let week = WeeklyPlan(participantID: owner, startDateKey: "2026-10-26", timezoneID: zone,
                              dateKeys: try WeeklyCalendar.dateKeys(startDateKey: "2026-10-26", timezoneID: zone),
                              terms: terms, createdAt: confirmation, confirmedAt: confirmation,
                              dailyMaximumCents: initial.dailyMaximumCents, consistencyReserveCents: initial.consistencyReserveCents)
        state.plans = [week]
        for key in week.dateKeys {
            state.stepRevisions.append(DailyStepRevision(participantID: owner, planID: week.id, dateKey: key,
                                                        steps: steps, actorID: owner, recordedAt: review, transactionKey: UUID()))
        }
        let result = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: steps, count: 7))
        let assessment = AssessmentRevision(participantID: owner, planID: week.id, inputFingerprint: "preserved-inputs",
                                            stepRevisionIDs: state.stepRevisions.map(\.id), result: result,
                                            createdAt: review, reviewedAt: review, reviewerID: owner, transactionKey: UUID())
        state.assessments = [assessment]
        for bucket in FinancialBucket.allCases {
            state.financialEvents.append(FinancialAssessmentEvent(participantID: owner, planID: week.id, assessmentID: assessment.id,
                                                                  bucket: bucket, deltaCents: result.amount(for: bucket),
                                                                  createdAt: review, actorID: owner, transactionKey: "opening-\(bucket.rawValue)"))
        }
        return state
    }

    func testCompleteBackupDomainRoundTripPreservesIDsAndRecords() throws {
        let state = try reviewedState()
        try StateValidator.validate(state)
        let envelope = BackupEnvelope(exportedAt: state.assessments[0].createdAt, state: state)
        let encoded = try JSONEncoder().encode(envelope)
        let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: encoded)
        XCTAssertEqual(decoded, envelope)
        XCTAssertEqual(decoded.state.plans[0].id, state.plans[0].id)
        try StateValidator.validate(decoded.state)
    }

    func testBackupRejectsDuplicateIDsBrokenReferencesAndUnknownSchema() throws {
        let valid = try reviewedState()
        var duplicate = valid
        duplicate.plans.append(duplicate.plans[0])
        XCTAssertThrowsError(try StateValidator.validate(duplicate))
        var broken = valid
        broken.stepRevisions[0].planID = UUID()
        XCTAssertThrowsError(try StateValidator.validate(broken))
        var unsupported = valid
        unsupported.schemaVersion = 999
        XCTAssertThrowsError(try StateValidator.validate(unsupported))
        var malformed = valid
        malformed.plans[0].startDateKey = "2026-02-30"
        XCTAssertThrowsError(try StateValidator.validate(malformed))
    }

    func testBackupRejectsAlteredAssessmentAndLedger() throws {
        let valid = try reviewedState()
        var altered = valid
        altered.assessments[0].result.personalReturnCents -= 1
        XCTAssertThrowsError(try StateValidator.validate(altered))
        var ledger = valid
        ledger.financialEvents[0].deltaCents -= 1
        XCTAssertThrowsError(try StateValidator.validate(ledger))
        var duplicateEvent = valid
        var event = duplicateEvent.financialEvents[0]
        event.id = UUID()
        duplicateEvent.financialEvents.append(event)
        XCTAssertThrowsError(try StateValidator.validate(duplicateEvent))
    }

    func testCorrectionAwaitingReviewPreservesPreviouslyPostedValues() throws {
        var state = try reviewedState()
        let week = state.plans[0]
        let oldEntry = state.stepRevisions[0]
        let timestamp = state.assessments[0].createdAt.addingTimeInterval(60)
        let correction = DailyStepRevision(participantID: state.profile.id, planID: week.id, dateKey: oldEntry.dateKey,
                                           steps: 5000, actorID: state.profile.id, recordedAt: timestamp,
                                           supersedesID: oldEntry.id, reason: "Corrected manual total", transactionKey: UUID())
        state.stepRevisions.append(correction)
        let changed = try RewardEngine.evaluate(terms: week.terms, dailySteps: state.dailySteps(for: week))
        let pending = AssessmentRevision(participantID: state.profile.id, planID: week.id, inputFingerprint: "corrected-inputs",
                                         stepRevisionIDs: state.effectiveStepRevisions(for: week.id).map(\.id), result: changed,
                                         createdAt: timestamp, supersedesID: state.assessments[0].id, transactionKey: UUID())
        state.assessments.append(pending)
        try StateValidator.validate(state)
        XCTAssertNil(state.latestAssessment(for: week.id)?.reviewedAt)
        XCTAssertEqual(state.latestReviewedAssessment(for: week.id)?.result.personalReturnCents, 3500)
        XCTAssertEqual(state.reconciliation(planID: week.id, bucket: .personalReturn).targetCents, 3500)
        XCTAssertEqual(try WeeklyCalendar.status(for: week, now: timestamp, latestAssessment: state.latestAssessment(for: week.id)), .awaitingReview)
        XCTAssertEqual(state.financialEvents.count, 3)
        XCTAssertEqual(state.stepRevisions.count, 8)
    }

    func testBackupRejectsForkedWalkingHistoryAndStaleCurrentAssessment() throws {
        let valid = try reviewedState()
        var fork = valid
        let old = fork.stepRevisions[0]
        for total in [5000, 6000] {
            fork.stepRevisions.append(DailyStepRevision(participantID: fork.profile.id, planID: old.planID, dateKey: old.dateKey,
                                                       steps: total, actorID: fork.profile.id, recordedAt: old.recordedAt,
                                                       supersedesID: old.id, reason: "Correction", transactionKey: UUID()))
        }
        XCTAssertThrowsError(try StateValidator.validate(fork))
        var stale = valid
        stale.stepRevisions.append(DailyStepRevision(participantID: stale.profile.id, planID: old.planID, dateKey: old.dateKey,
                                                    steps: 5000, actorID: stale.profile.id, recordedAt: old.recordedAt,
                                                    supersedesID: old.id, reason: "Correction", transactionKey: UUID()))
        XCTAssertThrowsError(try StateValidator.validate(stale))
    }

    func testExplicitZeroAndClearedEntryStayDistinctAcrossSerialization() throws {
        var state = try reviewedState()
        let old = state.stepRevisions[0]
        let zero = DailyStepRevision(participantID: state.profile.id, planID: old.planID, dateKey: old.dateKey,
                                     steps: 0, actorID: state.profile.id, recordedAt: old.recordedAt,
                                     supersedesID: old.id, reason: "Corrected total", transactionKey: UUID())
        state.stepRevisions.append(zero)
        XCTAssertEqual(state.dailySteps(for: state.plans[0])[0], 0)
        let clear = DailyStepRevision(participantID: state.profile.id, planID: old.planID, dateKey: old.dateKey,
                                      steps: nil, actorID: state.profile.id, recordedAt: old.recordedAt,
                                      supersedesID: zero.id, reason: "Clear mistaken entry", transactionKey: UUID())
        state.stepRevisions.append(clear)
        let decoded = try JSONDecoder().decode(BloomedState.self, from: JSONEncoder().encode(state))
        XCTAssertNil(decoded.dailySteps(for: decoded.plans[0])[0])
        XCTAssertEqual(decoded.stepRevisions.first { $0.id == zero.id }?.steps, 0)
        XCTAssertTrue(decoded.stepRevisions.contains { $0.id == clear.id && $0.steps == nil })
    }

    func testDeferredDestinationDoesNotChangeWalkingOrMoneyCalculations() throws {
        let named = PlanTerms(baseGoalSteps: 5000, stretchGoalSteps: 8000, consistencyEnabled: true, commitmentCents: 3500, charity: "Chosen cause")
        var deferred = named
        deferred.charity = ""
        let totals: [Int?] = [8000, 5000, 8000, 5000, 8000, 0, nil]
        XCTAssertEqual(try RewardEngine.evaluate(terms: named, dailySteps: totals),
                       try RewardEngine.evaluate(terms: deferred, dailySteps: totals))
    }

    func testReviewWithCharityAmountRequiresDestinationChosenBeforeReview() throws {
        var state = try reviewedState(steps: 0, charity: "")
        XCTAssertThrowsError(try StateValidator.validate(state))
        let plan = state.plans[0]
        let reviewDate = state.assessments[0].reviewedAt!
        let destination = CharityDestinationRecord(participantID: state.profile.id, planID: plan.id,
            destination: "Selected later", recordedAt: reviewDate, actorID: state.profile.id, transactionKey: UUID())
        state.charityDestinations = [destination]
        try StateValidator.validate(state)
        XCTAssertEqual(state.plans[0].terms.charity, "", "Original plan terms stay unchanged")
        state.charityDestinations![0].recordedAt = reviewDate.addingTimeInterval(1)
        XCTAssertThrowsError(try StateValidator.validate(state), "A later choice cannot make an earlier incomplete review valid")
    }

    func testDestinationRecordRejectsDuplicateReplacementAndUnknownOwner() throws {
        var state = try reviewedState(charity: "")
        let plan = state.plans[0]
        let destination = CharityDestinationRecord(participantID: state.profile.id, planID: plan.id,
            destination: "Selected cause", recordedAt: plan.confirmedAt!, actorID: state.profile.id, transactionKey: UUID())
        state.charityDestinations = [destination]
        try StateValidator.validate(state)
        var duplicate = destination
        duplicate.id = UUID()
        duplicate.transactionKey = UUID()
        state.charityDestinations!.append(duplicate)
        XCTAssertThrowsError(try StateValidator.validate(state))
        state.charityDestinations = [destination]
        state.charityDestinations![0].actorID = UUID()
        XCTAssertThrowsError(try StateValidator.validate(state))
        state.charityDestinations = [destination]
        state.plans[0].terms.charity = "Originally selected cause"
        XCTAssertThrowsError(try StateValidator.validate(state), "A deferred choice must not overwrite an original destination")
    }

    func testOlderBackupWithoutAdditiveDestinationFieldsStillDecodes() throws {
        let state = try reviewedState()
        let envelope = BackupEnvelope(exportedAt: state.assessments[0].createdAt, state: state)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(envelope)) as? [String: Any])
        var oldState = try XCTUnwrap(json["state"] as? [String: Any])
        oldState.removeValue(forKey: "charityDestinations")
        json["state"] = oldState
        let decoded = try JSONDecoder().decode(BackupEnvelope.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(decoded.state.charityDestinations)
        XCTAssertEqual(decoded.state.plans, state.plans)
        try StateValidator.validate(decoded.state)
    }

}
