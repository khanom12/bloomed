import Foundation

enum WeeklyCalendar {
    static func calendar(timezoneID: String) throws -> Calendar {
        guard let timezone = TimeZone(identifier: timezoneID) else { throw DomainError.invalid("Choose a valid plan timezone.") }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func dateKey(for date: Date, timezoneID: String) -> String {
        guard let calendar = try? calendar(timezoneID: timezoneID) else { return "" }
        let values = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", values.year ?? 0, values.month ?? 0, values.day ?? 0)
    }

    static func date(for key: String, timezoneID: String) throws -> Date {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard key.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), (1...9999).contains(year) else {
            throw DomainError.invalid("A plan date is malformed. Expected YYYY-MM-DD.")
        }
        let calendar = try calendar(timezoneID: timezoneID)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)), dateKey(for: date, timezoneID: timezoneID) == key else {
            throw DomainError.invalid("A plan date does not exist in its timezone.")
        }
        return date
    }

    static func addingDays(_ days: Int, to key: String, timezoneID: String) throws -> String {
        let calendar = try calendar(timezoneID: timezoneID)
        guard let value = calendar.date(byAdding: .day, value: days, to: try date(for: key, timezoneID: timezoneID)) else { throw DomainError.invalid("Unable to calculate the plan dates.") }
        return dateKey(for: value, timezoneID: timezoneID)
    }

    static func dateKeys(startDateKey: String, timezoneID: String) throws -> [String] {
        try (0..<7).map { try addingDays($0, to: startDateKey, timezoneID: timezoneID) }
    }

    static func interval(for plan: WeeklyPlan) throws -> DateInterval {
        let start = try date(for: plan.startDateKey, timezoneID: plan.timezoneID)
        let endKey = try addingDays(7, to: plan.startDateKey, timezoneID: plan.timezoneID)
        return DateInterval(start: start, end: try date(for: endKey, timezoneID: plan.timezoneID))
    }

    static func intervalsOverlap(_ first: WeeklyPlan, _ second: WeeklyPlan) throws -> Bool {
        let a = try interval(for: first)
        let b = try interval(for: second)
        return a.start < b.end && b.start < a.end
    }

    static func closedDayCount(for plan: WeeklyPlan, now: Date) throws -> Int {
        let today = dateKey(for: now, timezoneID: plan.timezoneID)
        return plan.dateKeys.filter { $0 < today }.count
    }

    static func status(for plan: WeeklyPlan, now: Date, latestAssessment: AssessmentRevision?) throws -> PlanStatus {
        if plan.voidedAt != nil { return .voidedBeforeStart }
        guard plan.confirmedAt != nil else { return .draft }
        let interval = try interval(for: plan)
        if now < interval.start { return .scheduled }
        if now < interval.end { return .active }
        return latestAssessment?.reviewedAt != nil ? .reviewed : .awaitingReview
    }

    static func validateConfirmation(_ candidate: WeeklyPlan, among plans: [WeeklyPlan], now: Date) throws {
        let proposed = try interval(for: candidate)
        let today = dateKey(for: now, timezoneID: candidate.timezoneID)
        guard candidate.startDateKey >= today else { throw DomainError.invalid("A new financial commitment cannot start in the past.") }
        guard candidate.dateKeys == (try dateKeys(startDateKey: candidate.startDateKey, timezoneID: candidate.timezoneID)) else { throw DomainError.invalid("The plan must contain seven consecutive calendar dates.") }
        let existing = plans.filter { $0.id != candidate.id && $0.confirmedAt != nil && $0.voidedAt == nil }
        for plan in existing {
            if try intervalsOverlap(candidate, plan) { throw DomainError.invalid("These dates overlap an existing commitment. Choose a nonoverlapping start date.") }
        }
        let future = try existing.filter { try interval(for: $0).start > now }
        guard !(proposed.start > now && !future.isEmpty) else { throw DomainError.invalid("You already have an upcoming confirmed week. Prepare a draft or wait until that week starts.") }
    }

    static func nextAvailableStart(after plan: WeeklyPlan?, among plans: [WeeklyPlan], now: Date, timezoneID: String) throws -> String {
        let tomorrow = try addingDays(1, to: dateKey(for: now, timezoneID: timezoneID), timezoneID: timezoneID)
        let afterPrevious = try plan.map { try addingDays(7, to: $0.startDateKey, timezoneID: $0.timezoneID) } ?? tomorrow
        var candidate = max(tomorrow, afterPrevious)
        for _ in 0...plans.count {
            let keys = try dateKeys(startDateKey: candidate, timezoneID: timezoneID)
            let start = try date(for: candidate, timezoneID: timezoneID)
            let end = try date(for: addingDays(7, to: candidate, timezoneID: timezoneID), timezoneID: timezoneID)
            let conflicts = try plans.filter { plan in
                guard plan.confirmedAt != nil, plan.voidedAt == nil else { return false }
                let interval = try interval(for: plan)
                return start < interval.end && interval.start < end
            }
            guard !conflicts.isEmpty else { return keys[0] }
            let lastEnd = try conflicts.map { try interval(for: $0).end }.max()!
            candidate = dateKey(for: lastEnd, timezoneID: timezoneID)
            if try date(for: candidate, timezoneID: timezoneID) < lastEnd {
                candidate = try addingDays(1, to: candidate, timezoneID: timezoneID)
            }
        }
        throw DomainError.invalid("Unable to find an available week. Review your scheduled plans.")
    }
}

extension StandingAgreement {
    func applies(to plan: WeeklyPlan) -> Bool {
        guard pausedAt == nil, endedAt == nil, currency == plan.terms.currency, timezoneID == plan.timezoneID,
              plan.startDateKey >= effectiveStartDateKey, let finalDate = plan.dateKeys.last,
              inclusiveEndDateKey == nil || finalDate <= inclusiveEndDateKey!, (1...100_000).contains(capCents) else { return false }
        let old = preservedTerms
        let new = plan.terms
        return old.baseGoalSteps == new.baseGoalSteps && old.stretchGoalSteps == new.stretchGoalSteps && old.consistencyEnabled == new.consistencyEnabled && old.commitmentCents == new.commitmentCents && old.currency == new.currency && old.ruleVersion == new.ruleVersion
    }
}

extension BloomedState {
    func effectiveStepRevisions(for planID: UUID) -> [DailyStepRevision] {
        let relevant = stepRevisions.filter { $0.planID == planID }
        let superseded = Set(relevant.compactMap(\.supersedesID))
        return relevant.filter { !superseded.contains($0.id) }.sorted { $0.dateKey < $1.dateKey }
    }

    func dailySteps(for plan: WeeklyPlan) -> [Int?] {
        let entries = Dictionary(effectiveStepRevisions(for: plan.id).map { ($0.dateKey, $0.steps) }, uniquingKeysWith: { _, latest in latest })
        return plan.dateKeys.map { entries[$0] ?? nil }
    }

    func effectiveSupport(for planID: UUID) -> WeeklySupportSnapshot? {
        let relevant = supportSnapshots.filter { $0.planID == planID }
        let superseded = Set(relevant.compactMap(\.supersedesID))
        return relevant.last { !superseded.contains($0.id) }
    }

    func latestAssessment(for planID: UUID) -> AssessmentRevision? {
        assessments.last { $0.planID == planID }
    }

    func latestReviewedAssessment(for planID: UUID) -> AssessmentRevision? {
        assessments.last { $0.planID == planID && $0.reviewedAt != nil }
    }

    func reconciliation(planID: UUID, bucket: FinancialBucket) -> Reconciliation {
        let target = latestReviewedAssessment(for: planID)?.result.amount(for: bucket) ?? 0
        let recorded = settlements.filter { $0.planID == planID && $0.bucket == bucket && $0.voidedAt == nil }.reduce(0) { $0 + $1.amountCents }
        return Reconciliation(targetCents: target, recordedCents: recorded)
    }

    func reconciliationRequired(for planID: UUID) -> Bool {
        let resolved = Set(exceptions.compactMap(\.resolvesID))
        return exceptions.contains { $0.planID == planID && $0.resolvesID == nil && !resolved.contains($0.id) }
    }
}
