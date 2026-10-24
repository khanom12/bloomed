import Foundation
import Observation

/// A single transaction boundary for the offline participant experience.
/// Mutations operate on a value copy, validate and save it, then publish it.
@MainActor @Observable
final class AppStore {
    private(set) var state = BloomedState()
    private(set) var now: Date
    private(set) var isLoaded = false
    var errorMessage: String?
    @ObservationIgnored private let repository: any StateRepository
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let makeID: () -> UUID

    init(repository: any StateRepository = AtomicJSONRepository(),
         clock: @escaping () -> Date = { Date() }, makeID: @escaping () -> UUID = { UUID() }) {
        self.repository = repository
        self.clock = clock
        self.makeID = makeID
        self.now = clock()
        do { try retryLoad() } catch { errorMessage = error.localizedDescription }
    }

    var canEdit: Bool { isLoaded }
    var profile: ParticipantProfile { state.profile }
    var draft: PlanDraft? { state.draft }
    var plans: [WeeklyPlan] { state.plans.sorted { $0.startDateKey > $1.startDateKey } }
    var currentPlan: WeeklyPlan? {
        let eligible = plans.filter { $0.voidedAt == nil }
        return eligible.first { lifecycle(for: $0) == .active }
            ?? eligible.filter { lifecycle(for: $0) == .scheduled }.min { $0.startDateKey < $1.startDateKey }
            ?? eligible.first
    }

    func refresh() { now = clock() }

    func retryLoad() throws {
        do {
            let loaded: BloomedState
            if let data = try repository.load() {
                loaded = try Self.decode(data)
            } else {
                var fresh = BloomedState()
                fresh.profile.id = makeID()
                fresh.profile.createdAt = clock()
                loaded = fresh
            }
            state = loaded
            now = clock()
            isLoaded = true
            errorMessage = nil
        } catch {
            isLoaded = false
            errorMessage = "Your saved records could not be opened. They have not been replaced. \(error.localizedDescription)"
            throw error
        }
    }

    func plan(id: UUID) -> WeeklyPlan? { state.plans.first { $0.id == id } }
    func effectiveSteps(for plan: WeeklyPlan) -> [Int?] { state.dailySteps(for: plan) }
    func effectiveSteps(planID: UUID, dateKey: String) -> Int? {
        state.effectiveStepRevisions(for: planID).first { $0.dateKey == dateKey }?.steps
    }
    func support(for plan: WeeklyPlan) -> WeeklySupportSnapshot? {
        guard let support = state.effectiveSupport(for: plan.id), support.applies else { return nil }
        return support
    }
    func latestAssessment(for plan: WeeklyPlan) -> AssessmentRevision? { state.latestAssessment(for: plan.id) }
    func latestReviewedAssessment(for plan: WeeklyPlan) -> AssessmentRevision? { state.latestReviewedAssessment(for: plan.id) }
    func lifecycle(for plan: WeeklyPlan) -> PlanStatus {
        (try? WeeklyCalendar.status(for: plan, now: now, latestAssessment: latestAssessment(for: plan))) ?? .draft
    }
    func assessment(for plan: WeeklyPlan) -> WeeklyAssessment {
        // Confirmed plans and every loaded snapshot have passed StateValidator.
        // An assessment is persisted atomically alongside every source change.
        if let revision = latestAssessment(for: plan) { return revision.result }
        return try! RewardEngine.evaluate(terms: plan.terms, dailySteps: effectiveSteps(for: plan),
                                          supporterCapCents: support(for: plan)?.capCents)
    }
    func previewAssessment(planID: UUID, dateKey: String, steps: Int?) throws -> WeeklyAssessment {
        guard let plan = plan(id: planID), let index = plan.dateKeys.firstIndex(of: dateKey) else { throw StoreError.missingPlan }
        var values = effectiveSteps(for: plan)
        values[index] = steps
        return try RewardEngine.evaluate(terms: plan.terms, dailySteps: values, supporterCapCents: support(for: plan)?.capCents)
    }
    func reconciliation(for plan: WeeklyPlan, bucket: FinancialBucket) -> SettlementSummary {
        let result = state.reconciliation(planID: plan.id, bucket: bucket)
        return SettlementSummary(targetCents: result.targetCents, recordedCents: result.recordedCents)
    }
    func reconciliationRequired(for plan: WeeklyPlan) -> Bool {
        state.reconciliationRequired(for: plan.id) || FinancialBucket.allCases.contains {
            reconciliation(for: plan, bucket: $0).excessCents > 0
        }
    }
    func settlements(for plan: WeeklyPlan) -> [ExternalSettlementRecord] {
        state.settlements.filter { $0.planID == plan.id }.reversed()
    }

    @discardableResult
    func beginDraft(repeating plan: WeeklyPlan? = nil) throws -> PlanDraft {
        if let existing = draft { return existing }
        refresh()
        let timezone = plan?.timezoneID ?? TimeZone.current.identifier
        var created = PlanDraft(startDateKey: try WeeklyCalendar.nextAvailableStart(after: plan, among: state.plans,
            now: now, timezoneID: timezone), timezoneID: timezone)
        created.id = makeID()
        created.createdAt = now
        if let plan {
            let terms = plan.terms
            created.baseGoalText = String(terms.baseGoalSteps)
            created.stretchEnabled = terms.stretchGoalSteps != nil
            created.stretchGoalText = terms.stretchGoalSteps.map(String.init) ?? ""
            created.consistencyEnabled = terms.consistencyEnabled
            created.commitmentText = String(format: "%d.%02d", terms.commitmentCents / 100, terms.commitmentCents % 100)
            created.charity = terms.charity
            created.handling = terms.handling
            created.handlerDescription = terms.handlerDescription
        }
        created.privateMotivation = profile.privateMotivation
        try saveDraft(created)
        return created
    }

    func saveDraft(_ draft: PlanDraft) throws {
        try transact { candidate in
            guard candidate.plans.allSatisfy({ $0.id != draft.id }) else { throw StoreError.invalid("An existing commitment cannot be edited as a draft.") }
            guard TimeZone(identifier: draft.timezoneID) != nil else { throw StoreError.invalid("Choose a valid timezone.") }
            _ = try WeeklyCalendar.date(for: draft.startDateKey, timezoneID: draft.timezoneID)
            candidate.draft = draft
        }
    }

    func deleteDraft() throws { try transact { $0.draft = nil } }

    func terms(for draft: PlanDraft) throws -> PlanTerms {
        guard let base = Self.wholeNumber(draft.baseGoalText), (1...100_000).contains(base) else {
            throw StoreError.invalid("Enter a whole-number walking goal between 1 and 100,000 steps.")
        }
        var stretch: Int?
        if draft.stretchEnabled {
            guard let value = Self.wholeNumber(draft.stretchGoalText) else { throw StoreError.invalid("Enter a whole-number stretch goal.") }
            stretch = value
        }
        let terms = PlanTerms(baseGoalSteps: base, stretchGoalSteps: stretch,
            consistencyEnabled: draft.consistencyEnabled, commitmentCents: try Money.parseCents(draft.commitmentText),
            charity: draft.charity.trimmingCharacters(in: .whitespacesAndNewlines), handling: draft.handling,
            handlerDescription: draft.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines))
        try RewardEngine.validate(terms: terms)
        return terms
    }

    @discardableResult
    func confirmDraft(transactionKey: UUID = UUID()) throws -> WeeklyPlan {
        if let prior = state.auditEvents.first(where: { $0.transactionKey == "\(transactionKey.uuidString):\(AuditAction.planConfirmed.rawValue)" && $0.action == .planConfirmed }),
           let existing = plan(id: prior.planID) { return existing }
        guard let draft else { throw StoreError.noDraft }
        refresh()
        let terms = try terms(for: draft)
        let emptyResult = try RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: nil, count: 7))
        let plan = WeeklyPlan(id: draft.id, participantID: profile.id, startDateKey: draft.startDateKey,
            timezoneID: draft.timezoneID, dateKeys: try WeeklyCalendar.dateKeys(startDateKey: draft.startDateKey, timezoneID: draft.timezoneID),
            terms: terms, createdAt: draft.createdAt, confirmedAt: now,
            dailyMaximumCents: emptyResult.dailyMaximumCents, consistencyReserveCents: emptyResult.consistencyReserveCents)
        try transact { candidate in
            try WeeklyCalendar.validateConfirmation(plan, among: candidate.plans, now: now)
            candidate.plans.append(plan)
            candidate.profile.privateMotivation = draft.privateMotivation
            candidate.draft = nil
            let applicable = candidate.standingAgreements.filter { $0.applies(to: plan) }
            if applicable.count == 1, let standing = applicable.first,
               let person = candidate.supportPeople.first(where: { $0.id == standing.personID }) {
                let snapshot = WeeklySupportSnapshot(id: makeID(), participantID: profile.id, planID: plan.id,
                    personID: person.id, relationshipID: standing.relationshipID, alias: person.alias,
                    capCents: standing.capCents, wholeWeekAcknowledged: true,
                    externallyAgreedDateKey: standing.externallyAgreedDateKey, recordedAt: now, recorderID: profile.id,
                    standingAgreementID: standing.id, transactionKey: transactionKey)
                candidate.supportSnapshots.append(snapshot)
                audit(.supportRecorded, planID: plan.id, entityID: snapshot.id, transactionKey: transactionKey, in: &candidate)
            }
            try appendAssessment(plan: plan, transactionKey: transactionKey, in: &candidate)
            audit(.planConfirmed, planID: plan.id, entityID: plan.id, transactionKey: transactionKey, in: &candidate)
        }
        return plan
    }

    func voidScheduled(planID: UUID, reason: String) throws {
        try transact { candidate in
            let index = try indexOfPlan(planID, in: candidate)
            let plan = candidate.plans[index]
            guard now < (try WeeklyCalendar.interval(for: plan)).start, plan.voidedAt == nil else {
                throw StoreError.invalid("Only a confirmed week that has not started can be voided.")
            }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalid("Enter a reason for voiding this week.") }
            candidate.plans[index].voidedAt = now
            audit(.planVoided, planID: planID, entityID: planID, reason: reason, transactionKey: makeID(), in: &candidate)
        }
    }

    func recordSteps(planID: UUID, dateKey: String, total: Int?, reason: String? = nil,
                     expectedTodayKey: String? = nil, transactionKey: UUID = UUID()) throws {
        if state.stepRevisions.contains(where: { $0.transactionKey == transactionKey }) { return }
        try transact { candidate in
            let plan = candidate.plans[try indexOfPlan(planID, in: candidate)]
            guard plan.voidedAt == nil, plan.dateKeys.contains(dateKey) else { throw StoreError.invalid("Choose a date in a nonvoided walking plan.") }
            let today = WeeklyCalendar.dateKey(for: now, timezoneID: plan.timezoneID)
            guard dateKey <= today else { throw StoreError.invalid("Steps cannot be recorded for a future date.") }
            if let expectedTodayKey, expectedTodayKey != today {
                throw StoreError.invalid("The plan date changed while this screen was open. Review the selected date and reopen entry before saving.")
            }
            if let total, !(0...100_000).contains(total) { throw StoreError.invalid("Enter a whole-number total from 0 to 100,000 steps.") }
            let previous = candidate.effectiveStepRevisions(for: planID).first { $0.dateKey == dateKey }
            if previous?.steps == total { return }
            let reviewed = candidate.latestReviewedAssessment(for: planID) != nil
            if reviewed, (reason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw StoreError.invalid("Explain the correction to this reviewed week.")
            }
            let revision = DailyStepRevision(id: makeID(), participantID: profile.id, planID: planID,
                dateKey: dateKey, steps: total, actorID: profile.id, recordedAt: now,
                supersedesID: previous?.id, reason: reason ?? "", transactionKey: transactionKey)
            candidate.stepRevisions.append(revision)
            try appendAssessment(plan: plan, transactionKey: transactionKey, in: &candidate)
            let action: AuditAction = total == nil ? .entryCleared : previous == nil ? .entryRecorded : .entryCorrected
            audit(action, planID: planID, entityID: revision.id, reason: reason ?? "", before: previous?.id,
                  after: revision.id, transactionKey: transactionKey, in: &candidate)
        }
    }

    func review(planID: UUID, acknowledgeMissing: Bool, transactionKey: UUID = UUID()) throws {
        try transact { candidate in
            let plan = candidate.plans[try indexOfPlan(planID, in: candidate)]
            guard plan.voidedAt == nil, now >= (try WeeklyCalendar.interval(for: plan)).end else {
                throw StoreError.invalid("The seven-day plan must end before its weekly review can be confirmed.")
            }
            guard let index = candidate.assessments.lastIndex(where: { $0.planID == planID }) else { throw StoreError.invalid("The weekly assessment is missing.") }
            if candidate.assessments[index].reviewedAt != nil { return }
            let missing = zip(plan.dateKeys, candidate.dailySteps(for: plan)).compactMap { $1 == nil ? $0 : nil }
            guard missing.isEmpty || acknowledgeMissing else {
                throw StoreError.invalid("Record the missing dates or acknowledge that those dates receive no return.")
            }
            let previous = candidate.latestReviewedAssessment(for: planID)
            candidate.assessments[index].reviewedAt = now
            candidate.assessments[index].reviewerID = profile.id
            candidate.assessments[index].acknowledgedMissingDateKeys = missing
            let reviewed = candidate.assessments[index]
            for bucket in FinancialBucket.allCases {
                let key = "review:\(reviewed.id.uuidString):\(bucket.rawValue)"
                guard !candidate.financialEvents.contains(where: { $0.transactionKey == key }) else { continue }
                candidate.financialEvents.append(FinancialAssessmentEvent(id: makeID(), participantID: profile.id,
                    planID: planID, assessmentID: reviewed.id, bucket: bucket,
                    deltaCents: reviewed.result.amount(for: bucket) - (previous?.result.amount(for: bucket) ?? 0),
                    createdAt: now, actorID: profile.id, transactionKey: key))
            }
            audit(previous == nil ? .assessmentReviewed : .assessmentAdjusted, planID: planID,
                entityID: reviewed.id, before: previous?.id, after: reviewed.id,
                transactionKey: transactionKey, in: &candidate)
        }
    }

    func recordSupport(planID: UUID, alias: String, capCents: Int, agreementDate: Date,
                       standing: Bool = false, coverageStartKey: String? = nil, coverageEndKey: String? = nil,
                       wholeWeekAcknowledged: Bool = false, note: String = "", correctionReason: String = "",
                       transactionKey: UUID = UUID()) throws {
        if state.supportSnapshots.contains(where: { $0.transactionKey == transactionKey }) { return }
        try transact { candidate in
            let plan = candidate.plans[try indexOfPlan(planID, in: candidate)]
            guard plan.voidedAt == nil else { throw StoreError.invalid("A voided week cannot receive support.") }
            let trimmedAlias = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAlias.isEmpty, (1...100_000).contains(capCents) else {
                throw StoreError.invalid("Enter a supporter alias and a cap from CAD 0.01 to CAD 1,000.00.")
            }
            let interval = try WeeklyCalendar.interval(for: plan)
            let prior = candidate.effectiveSupport(for: planID)
            if prior != nil, correctionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw StoreError.invalid("Explain the correction to the recorded agreement.")
            }
            if now >= interval.end, prior == nil { throw StoreError.invalid("New matching cannot be added retroactively to an ended week.") }
            if now >= interval.start, now < interval.end, !wholeWeekAcknowledged {
                throw StoreError.invalid("Confirm that the outside agreement covers this entire week, including already-recorded activity.")
            }
            let agreedKey = WeeklyCalendar.dateKey(for: agreementDate, timezoneID: plan.timezoneID)
            let today = WeeklyCalendar.dateKey(for: now, timezoneID: plan.timezoneID)
            guard agreedKey <= today else { throw StoreError.invalid("An outside agreement cannot be dated in the future.") }
            let coverageStart = coverageStartKey ?? plan.startDateKey
            _ = try WeeklyCalendar.date(for: coverageStart, timezoneID: plan.timezoneID)
            if let coverageEndKey { _ = try WeeklyCalendar.date(for: coverageEndKey, timezoneID: plan.timezoneID) }
            guard coverageStart <= plan.startDateKey, coverageEndKey == nil || coverageEndKey! >= plan.dateKeys[6] else {
                throw StoreError.invalid("The agreement must cover all seven dates of this week.")
            }
            let personID = prior?.personID ?? makeID()
            let relationshipID = prior?.relationshipID ?? makeID()
            if prior == nil {
                candidate.supportPeople.append(SupportPerson(id: personID, participantID: profile.id, alias: trimmedAlias, createdAt: now))
                candidate.relationships.append(SupportRelationship(id: relationshipID, participantID: profile.id, personID: personID, createdAt: now))
            } else if let personIndex = candidate.supportPeople.firstIndex(where: { $0.id == personID }) {
                // Historical snapshots retain their original display aliases.
                candidate.supportPeople[personIndex].alias = trimmedAlias
            }
            var standingID: UUID?
            if !standing, let previousStandingID = prior?.standingAgreementID,
               let index = candidate.standingAgreements.firstIndex(where: { $0.id == previousStandingID }) {
                candidate.standingAgreements[index].endedAt = now
            }
            if standing {
                for index in candidate.standingAgreements.indices where candidate.standingAgreements[index].endedAt == nil {
                    candidate.standingAgreements[index].endedAt = now
                }
                let agreement = StandingAgreement(id: makeID(), participantID: profile.id, personID: personID,
                    relationshipID: relationshipID, capCents: capCents, effectiveStartDateKey: coverageStart,
                    inclusiveEndDateKey: coverageEndKey, timezoneID: plan.timezoneID, preservedTerms: plan.terms,
                    externallyAgreedDateKey: agreedKey, recordedAt: now, recorderID: profile.id)
                candidate.standingAgreements.append(agreement)
                standingID = agreement.id
            }
            let snapshot = WeeklySupportSnapshot(id: makeID(), participantID: profile.id, planID: planID,
                personID: personID, relationshipID: relationshipID, alias: trimmedAlias, capCents: capCents,
                wholeWeekAcknowledged: true,
                externallyAgreedDateKey: agreedKey, recordedAt: now, recorderID: profile.id,
                standingAgreementID: standingID, supersedesID: prior?.id, reason: correctionReason,
                transactionKey: transactionKey)
            candidate.supportSnapshots.append(snapshot)
            try appendAssessment(plan: plan, transactionKey: transactionKey, in: &candidate)
            audit(prior == nil ? .supportRecorded : .supportCorrected, planID: planID, entityID: snapshot.id,
                  reason: correctionReason.isEmpty ? note : correctionReason, before: prior?.id, after: snapshot.id,
                  transactionKey: transactionKey, in: &candidate)
        }
    }

    func pauseStandingAgreement(id: UUID) throws {
        try changeStandingAgreement(id: id, end: false)
    }
    func endStandingAgreement(id: UUID) throws {
        try changeStandingAgreement(id: id, end: true)
    }

    /// Correct a mistakenly recorded applicability without deleting the original agreement.
    func removeSupport(planID: UUID, reason: String, transactionKey: UUID = UUID()) throws {
        if state.supportSnapshots.contains(where: { $0.transactionKey == transactionKey }) { return }
        try transact { candidate in
            let plan = candidate.plans[try indexOfPlan(planID, in: candidate)]
            guard plan.voidedAt == nil else { throw StoreError.invalid("A voided week's historical agreement cannot be changed.") }
            guard let previous = candidate.effectiveSupport(for: planID), previous.applies else { return }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StoreError.invalid("Explain why the recorded matching agreement does not apply.")
            }
            var corrected = previous
            corrected.id = makeID()
            corrected.applies = false
            corrected.recordedAt = now
            corrected.supersedesID = previous.id
            corrected.reason = reason
            corrected.transactionKey = transactionKey
            candidate.supportSnapshots.append(corrected)
            try appendAssessment(plan: plan, transactionKey: transactionKey, in: &candidate)
            audit(.supportCorrected, planID: planID, entityID: corrected.id, reason: reason,
                  before: previous.id, after: corrected.id, transactionKey: transactionKey, in: &candidate)
        }
    }
    private func changeStandingAgreement(id: UUID, end: Bool) throws {
        try transact { candidate in
            guard let index = candidate.standingAgreements.firstIndex(where: { $0.id == id }) else { throw StoreError.invalid("The standing agreement was not found.") }
            if end {
                guard candidate.standingAgreements[index].endedAt == nil else { return }
                candidate.standingAgreements[index].endedAt = now
            } else {
                guard candidate.standingAgreements[index].pausedAt == nil,
                      candidate.standingAgreements[index].endedAt == nil else { return }
                candidate.standingAgreements[index].pausedAt = now
            }
            if let snapshot = candidate.supportSnapshots.last(where: { $0.standingAgreementID == id }) {
                audit(.supportCorrected, planID: snapshot.planID, entityID: id,
                      reason: end ? "Standing agreement ended for future weeks." : "Standing agreement paused for future weeks.",
                      transactionKey: makeID(), in: &candidate)
            }
        }
    }

    func recordSettlement(planID: UUID, bucket: FinancialBucket, amountCents: Int,
                          effectiveDateKey: String, note: String = "", transactionKey: UUID = UUID()) throws {
        if state.settlements.contains(where: { $0.transactionKey == transactionKey }) { return }
        try transact { candidate in
            let plan = candidate.plans[try indexOfPlan(planID, in: candidate)]
            guard candidate.latestAssessment(for: planID)?.reviewedAt != nil, plan.voidedAt == nil else {
                throw StoreError.invalid("Confirm the latest weekly review before recording external settlement.")
            }
            _ = try WeeklyCalendar.date(for: effectiveDateKey, timezoneID: plan.timezoneID)
            guard effectiveDateKey <= WeeklyCalendar.dateKey(for: now, timezoneID: plan.timezoneID) else {
                throw StoreError.invalid("External settlement cannot be dated in the future.")
            }
            let outstanding = candidate.reconciliation(planID: planID, bucket: bucket).outstandingCents
            guard amountCents > 0, amountCents <= outstanding else {
                throw StoreError.invalid("Enter a positive amount no greater than the outstanding amount for this category.")
            }
            let record = ExternalSettlementRecord(id: makeID(), participantID: profile.id, planID: planID,
                bucket: bucket, amountCents: amountCents, effectiveDateKey: effectiveDateKey,
                createdAt: now, actorID: profile.id, note: note, transactionKey: transactionKey)
            candidate.settlements.append(record)
            audit(.settlementRecorded, planID: planID, entityID: record.id, reason: note,
                  transactionKey: transactionKey, in: &candidate)
        }
    }

    func voidSettlement(id: UUID, reason: String, transactionKey: UUID = UUID()) throws {
        try transact { candidate in
            guard let index = candidate.settlements.firstIndex(where: { $0.id == id }) else { throw StoreError.invalid("The external record was not found.") }
            if candidate.settlements[index].voidedAt != nil { return }
            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalid("Explain why this external record is being voided.") }
            candidate.settlements[index].voidedAt = now
            candidate.settlements[index].voidReason = reason
            audit(.settlementVoided, planID: candidate.settlements[index].planID, entityID: id,
                  reason: reason, transactionKey: transactionKey, in: &candidate)
        }
    }

    func noteException(planID: UUID, note: String, resolvesID: UUID? = nil,
                       transactionKey: UUID = UUID()) throws {
        if state.exceptions.contains(where: { $0.transactionKey == transactionKey }) { return }
        try transact { candidate in
            _ = try indexOfPlan(planID, in: candidate)
            guard !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw StoreError.invalid("Enter a note describing the outside arrangement.") }
            if let resolvesID {
                guard candidate.exceptions.contains(where: { $0.id == resolvesID && $0.planID == planID && $0.resolvesID == nil }) else {
                    throw StoreError.invalid("The exception being resolved was not found.")
                }
            }
            let record = ExceptionRecord(id: makeID(), participantID: profile.id, planID: planID,
                note: note, createdAt: now, actorID: profile.id, resolvesID: resolvesID, transactionKey: transactionKey)
            candidate.exceptions.append(record)
            audit(resolvesID == nil ? .exceptionNoted : .resolutionNoted, planID: planID,
                  entityID: record.id, reason: note, before: resolvesID, after: record.id,
                  transactionKey: transactionKey, in: &candidate)
        }
    }

    func updateProfile(displayName: String, progressionPromptsEnabled: Bool) throws {
        try transact { candidate in
            candidate.profile.displayName = displayName
            candidate.profile.progressionPromptsEnabled = progressionPromptsEnabled
        }
    }

    func exportBackup() throws -> Data {
        guard isLoaded else { throw StoreError.unavailable }
        return try Self.encode(state, exportedAt: clock())
    }

    func restoreBackup(_ data: Data) throws {
        do {
            let restored = try Self.decode(data)
            let encoded = try Self.encode(restored, exportedAt: clock())
            try repository.save(encoded)
            state = restored
            now = clock()
            isLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "The backup was not restored. Existing records have not changed. \(error.localizedDescription)"
            throw error
        }
    }

    func deleteLocalData() throws {
        // An explicit destructive recovery action may replace an unreadable store.
        var empty = BloomedState()
        empty.profile.id = makeID()
        empty.profile.createdAt = clock()
        do {
            try repository.save(Self.encode(empty, exportedAt: clock()))
            state = empty
            now = clock()
            isLoaded = true
            errorMessage = nil
        } catch {
            errorMessage = "Local records could not be deleted. \(error.localizedDescription)"
            throw error
        }
    }

    private func transact(_ mutation: (inout BloomedState) throws -> Void) throws {
        guard isLoaded else { throw StoreError.unavailable }
        refresh()
        var candidate = state
        do {
            try mutation(&candidate)
            guard candidate != state else { errorMessage = nil; return }
            try StateValidator.validate(candidate)
            let encoded = try Self.encode(candidate, exportedAt: now)
            try repository.save(encoded)
            state = candidate
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    private func indexOfPlan(_ id: UUID, in candidate: BloomedState) throws -> Int {
        guard let index = candidate.plans.firstIndex(where: { $0.id == id }) else { throw StoreError.missingPlan }
        return index
    }

    private func appendAssessment(plan: WeeklyPlan, transactionKey: UUID, in candidate: inout BloomedState) throws {
        let entries = candidate.effectiveStepRevisions(for: plan.id)
        let support = candidate.effectiveSupport(for: plan.id)
        let fingerprint = ([plan.id.uuidString] + plan.dateKeys.map { key in
            entries.first(where: { $0.dateKey == key })?.id.uuidString ?? "missing:\(key)"
        } + [support?.id.uuidString ?? "no-support"]).joined(separator: "|")
        if candidate.latestAssessment(for: plan.id)?.inputFingerprint == fingerprint { return }
        let result = try RewardEngine.evaluate(terms: plan.terms, dailySteps: candidate.dailySteps(for: plan),
                                               supporterCapCents: support?.applies == true ? support?.capCents : nil)
        candidate.assessments.append(AssessmentRevision(id: makeID(), participantID: profile.id, planID: plan.id,
            inputFingerprint: fingerprint, stepRevisionIDs: entries.map(\.id), supportRevisionID: support?.id,
            result: result, createdAt: now, supersedesID: candidate.latestAssessment(for: plan.id)?.id,
            transactionKey: transactionKey))
    }

    private func audit(_ action: AuditAction, planID: UUID, entityID: UUID, reason: String = "",
                       before: UUID? = nil, after: UUID? = nil, transactionKey: UUID, in candidate: inout BloomedState) {
        candidate.auditEvents.append(AuditEvent(id: makeID(), participantID: profile.id, planID: planID,
            entityID: entityID, action: action, createdAt: now, actorID: profile.id, reason: reason,
            beforeReference: before, afterReference: after, transactionKey: "\(transactionKey.uuidString):\(action.rawValue)"))
    }

    private static func wholeNumber(_ text: String) -> Int? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        return Int(value)
    }

    private static func encode(_ state: BloomedState, exportedAt: Date) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(BackupEnvelope(exportedAt: exportedAt, state: state))
    }

    private static func decode(_ data: Data) throws -> BloomedState {
        // A bounded local file avoids accidental imports of unrelated huge data.
        guard data.count <= 50 * 1_024 * 1_024 else { throw StoreError.invalid("This backup is larger than the supported 50 MB limit.") }
        let envelope = try JSONDecoder().decode(BackupEnvelope.self, from: data)
        guard envelope.application == "Bloomed", envelope.schemaVersion == BloomedRule.schemaVersion else {
            throw StoreError.invalid("This is not a supported Bloomed backup version.")
        }
        try StateValidator.validate(envelope.state)
        return envelope.state
    }
}
