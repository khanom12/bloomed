import Foundation

/// Validation is read-only. Call before atomically replacing storage on backup restoration.
enum StateValidator {
    static func validate(_ state: BloomedState) throws {
        guard state.schemaVersion == BloomedRule.schemaVersion else { throw DomainError.invalid("This backup uses an unsupported data version.") }
        var identifiers = Set<UUID>()
        func unique(_ ids: [UUID]) throws {
            for id in ids where !identifiers.insert(id).inserted { throw DomainError.invalid("The backup contains duplicate record identifiers.") }
        }
        try unique([state.profile.id])
        try unique(state.draft.map { [$0.id] } ?? [])
        try unique(state.plans.map(\.id))
        try unique(state.stepRevisions.map(\.id))
        try unique(state.supportPeople.map(\.id))
        try unique(state.relationships.map(\.id))
        try unique(state.standingAgreements.map(\.id))
        try unique(state.supportSnapshots.map(\.id))
        try unique(state.assessments.map(\.id))
        try unique(state.financialEvents.map(\.id))
        try unique(state.settlements.map(\.id))
        try unique(state.auditEvents.map(\.id))
        try unique(state.exceptions.map(\.id))
        let owner = state.profile.id
        let plans = Dictionary(uniqueKeysWithValues: state.plans.map { ($0.id, $0) })
        let people = Dictionary(uniqueKeysWithValues: state.supportPeople.map { ($0.id, $0) })
        let relationships = Dictionary(uniqueKeysWithValues: state.relationships.map { ($0.id, $0) })
        let standing = Dictionary(uniqueKeysWithValues: state.standingAgreements.map { ($0.id, $0) })
        let steps = Dictionary(uniqueKeysWithValues: state.stepRevisions.map { ($0.id, $0) })
        let support = Dictionary(uniqueKeysWithValues: state.supportSnapshots.map { ($0.id, $0) })
        let assessments = Dictionary(uniqueKeysWithValues: state.assessments.map { ($0.id, $0) })
        let settlements = Dictionary(uniqueKeysWithValues: state.settlements.map { ($0.id, $0) })
        let exceptions = Dictionary(uniqueKeysWithValues: state.exceptions.map { ($0.id, $0) })

        func owned(_ participant: UUID) throws {
            guard participant == owner else { throw DomainError.invalid("The backup contains a record belonging to an unknown participant.") }
        }
        func plan(_ id: UUID) throws -> WeeklyPlan {
            guard let value = plans[id] else { throw DomainError.invalid("The backup refers to a missing weekly plan.") }
            return value
        }
        func validCap(_ cents: Int) throws {
            guard (1...100_000).contains(cents) else { throw DomainError.invalid("The backup contains an invalid matching cap.") }
        }
        if let draft = state.draft { _ = try WeeklyCalendar.date(for: draft.startDateKey, timezoneID: draft.timezoneID) }

        for value in state.plans {
            try owned(value.participantID)
            try RewardEngine.validate(terms: value.terms)
            guard value.dateKeys == (try WeeklyCalendar.dateKeys(startDateKey: value.startDateKey, timezoneID: value.timezoneID)) else { throw DomainError.invalid("The backup contains a week with inconsistent dates.") }
            let schedule = try RewardEngine.evaluate(terms: value.terms, dailySteps: Array(repeating: nil, count: 7))
            guard value.dailyMaximumCents == schedule.dailyMaximumCents, value.consistencyReserveCents == schedule.consistencyReserveCents else { throw DomainError.invalid("The preserved return schedule does not match the plan's rule version.") }
            if let voided = value.voidedAt {
                guard let confirmed = value.confirmedAt, voided >= confirmed, voided < (try WeeklyCalendar.interval(for: value)).start else { throw DomainError.invalid("A voided plan was not cancelled before its start.") }
            }
        }
        let confirmed = state.plans.filter { $0.confirmedAt != nil && $0.voidedAt == nil }
        for index in confirmed.indices {
            for other in confirmed.indices where other > index {
                if try WeeklyCalendar.intervalsOverlap(confirmed[index], confirmed[other]) { throw DomainError.invalid("The backup contains overlapping confirmed plans.") }
            }
        }

        var stepSuccessors = Set<UUID>()
        for entry in state.stepRevisions {
            try owned(entry.participantID)
            try owned(entry.actorID)
            let week = try plan(entry.planID)
            guard week.confirmedAt != nil, week.voidedAt == nil, week.dateKeys.contains(entry.dateKey), entry.source == "manual",
                  entry.steps == nil || (0...100_000).contains(entry.steps!),
                  entry.dateKey <= WeeklyCalendar.dateKey(for: entry.recordedAt, timezoneID: week.timezoneID) else { throw DomainError.invalid("The backup contains an invalid walking entry.") }
            if let predecessorID = entry.supersedesID {
                guard let old = steps[predecessorID], old.planID == entry.planID, old.dateKey == entry.dateKey,
                      old.recordedAt <= entry.recordedAt, predecessorID != entry.id, stepSuccessors.insert(predecessorID).inserted else { throw DomainError.invalid("The walking revision history is broken or ambiguous.") }
                try validateAcyclic(start: entry.id) { steps[$0]?.supersedesID }
            }
        }
        for week in state.plans {
            let effective = state.effectiveStepRevisions(for: week.id)
            guard Set(effective.map(\.dateKey)).count == effective.count else { throw DomainError.invalid("More than one effective step total exists for a date.") }
        }

        for person in state.supportPeople {
            try owned(person.participantID)
            guard !person.alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalid("A supporter alias is missing.") }
        }
        for relationship in state.relationships {
            try owned(relationship.participantID)
            guard people[relationship.personID] != nil else { throw DomainError.invalid("A support relationship refers to a missing person.") }
        }
        for agreement in state.standingAgreements {
            try owned(agreement.participantID)
            try owned(agreement.recorderID)
            try validCap(agreement.capCents)
            try RewardEngine.validate(terms: agreement.preservedTerms)
            guard agreement.currency == BloomedRule.currency,
                  let relationship = relationships[agreement.relationshipID], relationship.personID == agreement.personID,
                  people[agreement.personID] != nil else { throw DomainError.invalid("A standing agreement has invalid references or currency.") }
            _ = try WeeklyCalendar.date(for: agreement.effectiveStartDateKey, timezoneID: agreement.timezoneID)
            _ = try WeeklyCalendar.date(for: agreement.externallyAgreedDateKey, timezoneID: agreement.timezoneID)
            if let end = agreement.inclusiveEndDateKey {
                _ = try WeeklyCalendar.date(for: end, timezoneID: agreement.timezoneID)
                guard end >= agreement.effectiveStartDateKey else { throw DomainError.invalid("A standing agreement ends before it starts.") }
            }
        }
        var supportSuccessors = Set<UUID>()
        for snapshot in state.supportSnapshots {
            try owned(snapshot.participantID)
            try owned(snapshot.recorderID)
            try validCap(snapshot.capCents)
            let week = try plan(snapshot.planID)
            _ = try WeeklyCalendar.date(for: snapshot.externallyAgreedDateKey, timezoneID: week.timezoneID)
            guard snapshot.currency == week.terms.currency, snapshot.wholeWeekAcknowledged,
                  !snapshot.alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  people[snapshot.personID] != nil,
                  relationships[snapshot.relationshipID]?.personID == snapshot.personID else { throw DomainError.invalid("A weekly support record is inconsistent.") }
            if let agreementID = snapshot.standingAgreementID {
                guard standing[agreementID] != nil else { throw DomainError.invalid("The weekly support record refers to a missing standing agreement.") }
            }
            if let previousID = snapshot.supersedesID {
                guard let previous = support[previousID], previous.planID == snapshot.planID, previous.recordedAt <= snapshot.recordedAt,
                      previousID != snapshot.id, supportSuccessors.insert(previousID).inserted else { throw DomainError.invalid("The support revision history is broken or ambiguous.") }
                try validateAcyclic(start: snapshot.id) { support[$0]?.supersedesID }
            }
        }
        for week in state.plans {
            let revisions = state.supportSnapshots.filter { $0.planID == week.id }
            let superseded = Set(revisions.compactMap(\.supersedesID))
            guard revisions.filter({ !superseded.contains($0.id) }).count <= 1 else { throw DomainError.invalid("More than one effective matching agreement exists for a week.") }
        }

        var assessmentSuccessors = Set<UUID>()
        for assessment in state.assessments {
            try owned(assessment.participantID)
            let week = try plan(assessment.planID)
            guard assessment.ruleVersion == week.terms.ruleVersion, !assessment.inputFingerprint.isEmpty,
                  Set(assessment.stepRevisionIDs).count == assessment.stepRevisionIDs.count else { throw DomainError.invalid("An assessment has invalid source information.") }
            let inputEntries = try assessment.stepRevisionIDs.map { id -> DailyStepRevision in
                guard let entry = steps[id], entry.planID == week.id else { throw DomainError.invalid("An assessment refers to a missing or unrelated walking revision.") }
                return entry
            }
            guard Set(inputEntries.map(\.dateKey)).count == inputEntries.count else { throw DomainError.invalid("An assessment contains multiple totals for the same date.") }
            let totals = Dictionary(uniqueKeysWithValues: inputEntries.map { ($0.dateKey, $0.steps) })
            var cap: Int?
            if let id = assessment.supportRevisionID {
                guard let snapshot = support[id], snapshot.planID == week.id else { throw DomainError.invalid("An assessment refers to a missing or unrelated support record.") }
                cap = snapshot.applies ? snapshot.capCents : nil
            }
            let expected = try RewardEngine.evaluate(terms: week.terms, dailySteps: week.dateKeys.map { totals[$0] ?? nil }, supporterCapCents: cap)
            guard expected == assessment.result else { throw DomainError.invalid("An assessment does not match its preserved source records.") }
            if let reviewed = assessment.reviewedAt {
                let end = try WeeklyCalendar.interval(for: week).end
                let missing = Set(week.dateKeys.filter { totals[$0] == nil || totals[$0]! == nil })
                guard week.confirmedAt != nil, week.voidedAt == nil, reviewed >= end, assessment.reviewerID == owner,
                      missing.isSubset(of: Set(assessment.acknowledgedMissingDateKeys)),
                      Set(assessment.acknowledgedMissingDateKeys).isSubset(of: Set(week.dateKeys)) else { throw DomainError.invalid("A reviewed assessment has invalid timing, reviewer, or missing-date acknowledgement.") }
            } else if assessment.reviewerID != nil { throw DomainError.invalid("An unreviewed assessment names a reviewer.") }
            if let previousID = assessment.supersedesID {
                guard let previous = assessments[previousID], previous.planID == week.id, previous.createdAt <= assessment.createdAt,
                      previousID != assessment.id, assessmentSuccessors.insert(previousID).inserted else { throw DomainError.invalid("The assessment revision history is broken or ambiguous.") }
                try validateAcyclic(start: assessment.id) { assessments[$0]?.supersedesID }
            }
        }
        for week in state.plans {
            let revisions = state.assessments.filter { $0.planID == week.id }
            let superseded = Set(revisions.compactMap(\.supersedesID))
            let effective = revisions.filter { !superseded.contains($0.id) }
            guard week.confirmedAt == nil || !revisions.isEmpty else { throw DomainError.invalid("A confirmed plan is missing its assessment history.") }
            guard effective.count <= 1, effective.last?.id == revisions.last?.id else { throw DomainError.invalid("The assessment history has multiple effective revisions or is out of order.") }
            if let current = revisions.last {
                guard Set(current.stepRevisionIDs) == Set(state.effectiveStepRevisions(for: week.id).map(\.id)),
                      current.supportRevisionID == state.effectiveSupport(for: week.id)?.id else { throw DomainError.invalid("The current assessment does not use the current walking and support records.") }
            }
        }

        var eventKeys = Set<String>()
        for event in state.financialEvents {
            try owned(event.participantID)
            try owned(event.actorID)
            guard event.currency == BloomedRule.currency, (-100_000...100_000).contains(event.deltaCents),
                  let assessment = assessments[event.assessmentID], assessment.planID == event.planID, assessment.reviewedAt != nil,
                  !event.transactionKey.isEmpty, eventKeys.insert(event.transactionKey).inserted else { throw DomainError.invalid("A financial assessment event is invalid or duplicated.") }
        }
        for week in state.plans {
            var precedingReviewed: WeeklyAssessment?
            for revision in state.assessments.filter({ $0.planID == week.id && $0.reviewedAt != nil }) {
                for bucket in FinancialBucket.allCases {
                    let entries = state.financialEvents.filter { $0.assessmentID == revision.id && $0.bucket == bucket }
                    let expectedDelta = revision.result.amount(for: bucket) - (precedingReviewed?.amount(for: bucket) ?? 0)
                    guard entries.count <= 1, try checkedSum(entries.map(\.deltaCents)) == expectedDelta else {
                        throw DomainError.invalid("A reviewed financial revision does not reconcile to its previous reviewed values.")
                    }
                }
                precedingReviewed = revision.result
            }
            for bucket in FinancialBucket.allCases {
                let expected = state.latestReviewedAssessment(for: week.id)?.result.amount(for: bucket) ?? 0
                let posted = try checkedSum(state.financialEvents.filter { $0.planID == week.id && $0.bucket == bucket }.map(\.deltaCents))
                guard expected == posted else { throw DomainError.invalid("Posted financial history does not reconcile to the latest reviewed assessment.") }
            }
        }

        var settlementKeys = Set<UUID>()
        for settlement in state.settlements {
            try owned(settlement.participantID)
            try owned(settlement.actorID)
            let week = try plan(settlement.planID)
            let effectiveDate = try WeeklyCalendar.date(for: settlement.effectiveDateKey, timezoneID: week.timezoneID)
            guard settlement.currency == week.terms.currency, (1...100_000).contains(settlement.amountCents),
                  settlement.effectiveDateKey <= WeeklyCalendar.dateKey(for: settlement.createdAt, timezoneID: week.timezoneID),
                  effectiveDate.timeIntervalSince1970.isFinite, state.latestReviewedAssessment(for: week.id) != nil,
                  settlementKeys.insert(settlement.transactionKey).inserted else { throw DomainError.invalid("An external settlement record is invalid or duplicated.") }
            if settlement.voidedAt != nil, settlement.voidReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw DomainError.invalid("A voided settlement is missing its correction reason.") }
            if let replacementID = settlement.replacesID {
                guard let old = settlements[replacementID], old.planID == settlement.planID, old.bucket == settlement.bucket, old.voidedAt != nil else { throw DomainError.invalid("A replacement settlement has invalid correction history.") }
            }
        }
        for week in state.plans {
            for bucket in FinancialBucket.allCases {
                _ = try checkedSum(state.settlements.filter { $0.planID == week.id && $0.bucket == bucket && $0.voidedAt == nil }.map(\.amountCents))
            }
        }
        for exception in state.exceptions {
            try owned(exception.participantID)
            try owned(exception.actorID)
            _ = try plan(exception.planID)
            guard !exception.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalid("An external-resolution note is empty.") }
            if let resolvedID = exception.resolvesID {
                guard let original = exceptions[resolvedID], original.planID == exception.planID, original.resolvesID == nil else { throw DomainError.invalid("An external-resolution note refers to a missing exception.") }
            }
        }
        for audit in state.auditEvents {
            try owned(audit.participantID)
            try owned(audit.actorID)
            _ = try plan(audit.planID)
            guard identifiers.contains(audit.entityID), !audit.transactionKey.isEmpty else { throw DomainError.invalid("An audit record has an invalid entity or transaction reference.") }
            if let before = audit.beforeReference, !identifiers.contains(before) { throw DomainError.invalid("An audit record refers to missing original data.") }
            if let after = audit.afterReference, !identifiers.contains(after) { throw DomainError.invalid("An audit record refers to missing replacement data.") }
        }
    }

    private static func validateAcyclic(start: UUID, predecessor: (UUID) -> UUID?) throws {
        var seen = Set<UUID>()
        var current: UUID? = start
        while let id = current {
            guard seen.insert(id).inserted else { throw DomainError.invalid("The backup contains cyclic revision history.") }
            current = predecessor(id)
        }
    }

    private static func checkedSum(_ values: [Int]) throws -> Int {
        try values.reduce(0) { result, value in
            let sum = result.addingReportingOverflow(value)
            guard !sum.overflow else { throw DomainError.invalid("The backup contains overflowing financial totals.") }
            return sum.partialValue
        }
    }
}
