import Foundation

enum DomainError: Error, LocalizedError, Equatable, Sendable {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let explanation): explanation }
    }
}

enum Money {
    /// Exact ASCII decimal parsing. Grouping separators and fractional cents are deliberately rejected.
    static func parseCents(_ input: String) throws -> Int {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = text.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(components.count), !components[0].isEmpty,
              components.allSatisfy({ $0.allSatisfy { $0 >= "0" && $0 <= "9" } }),
              components.count == 1 || (1...2).contains(components[1].count),
              let whole = Int(components[0]) else {
            throw DomainError.invalid("Enter a dollar amount using at most two decimal places, such as 20.00. Do not include commas or currency symbols.")
        }
        let fraction = components.count == 2 ? String(components[1]).padding(toLength: 2, withPad: "0", startingAt: 0) : "00"
        guard let fractionalCents = Int(fraction) else { throw DomainError.invalid("Enter a valid dollar amount.") }
        let multiplied = whole.multipliedReportingOverflow(by: 100)
        let added = multiplied.partialValue.addingReportingOverflow(fractionalCents)
        guard !multiplied.overflow, !added.overflow else { throw DomainError.invalid("That amount is too large.") }
        return added.partialValue
    }

    static func format(_ cents: Int, currency: String = BloomedRule.currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let amount = NSDecimalNumber(decimal: Decimal(cents) / 100)
        return formatter.string(from: amount) ?? "\(currency) \(amount.stringValue)"
    }
}

struct WalkingForecast: Equatable, Sendable {
    var earnedSoFarCents: Int
    var maximumAttainableCents: Int
    var remainingWalkingOpportunityCents: Int
    var openDayCount: Int
    var attainableConsistencyCents: Int
}

enum RewardEngine {
    static func validate(terms: PlanTerms) throws {
        guard terms.ruleVersion == BloomedRule.version else { throw DomainError.invalid("This walking rule version is not supported.") }
        guard terms.currency == BloomedRule.currency else { throw DomainError.invalid("This version supports CAD only.") }
        guard (1...100_000).contains(terms.baseGoalSteps) else { throw DomainError.invalid("Choose a whole-number base goal between 1 and 100,000 steps.") }
        if let stretch = terms.stretchGoalSteps {
            guard stretch > terms.baseGoalSteps, stretch <= 100_000 else { throw DomainError.invalid("The stretch goal must exceed the base goal and be at most 100,000 steps.") }
        }
        guard (100...100_000).contains(terms.commitmentCents) else { throw DomainError.invalid("Choose a weekly commitment from CAD 1.00 to CAD 1,000.00.") }
        guard !terms.charity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalid("Enter the charity destination agreed for any unearned personal commitment.") }
        guard terms.handling == .participantRetains || !terms.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DomainError.invalid("Describe who handles the money outside Bloomed.") }
    }

    static func evaluate(terms: PlanTerms, dailySteps: [Int?], supporterCapCents: Int? = nil) throws -> WeeklyAssessment {
        try validate(terms: terms)
        guard dailySteps.count == 7 else { throw DomainError.invalid("A weekly assessment requires exactly seven ordered dates.") }
        guard dailySteps.allSatisfy({ $0 == nil || (0...100_000).contains($0!) }) else { throw DomainError.invalid("Step totals must be whole numbers from 0 to 100,000.") }
        if let cap = supporterCapCents, !(1...100_000).contains(cap) { throw DomainError.invalid("Choose a supporter cap from CAD 0.01 to CAD 1,000.00.") }
        // All inputs are bounded before arithmetic. Largest possible aggregate is 200,000 cents.
        let reserve = terms.consistencyEnabled ? terms.commitmentCents / 5 : 0
        let dailyPool = terms.commitmentCents - reserve
        let quotient = dailyPool / 7
        let remainder = dailyPool % 7
        let maxima = (0..<7).map { quotient + ($0 < remainder ? 1 : 0) }
        let baseOnly = maxima.map { terms.stretchGoalSteps == nil ? $0 : $0 / 4 }
        let returns = dailySteps.enumerated().map { index, total -> Int in
            guard let total, total >= terms.baseGoalSteps else { return 0 }
            return total >= terms.highestGoalSteps ? maxima[index] : baseOnly[index]
        }
        let qualifying = dailySteps.compactMap { $0 }.filter { $0 >= terms.baseGoalSteps }.count
        let highest = dailySteps.compactMap { $0 }.filter { $0 >= terms.highestGoalSteps }.count
        let consistency = terms.consistencyEnabled && qualifying >= 5 ? reserve : 0
        let personal = returns.reduce(0, +) + consistency
        let match = supporterCapCents.map { min(personal, $0) } ?? 0
        return WeeklyAssessment(dailyMaximumCents: maxima, dailyBaseOnlyCents: baseOnly,
                                dailyReturnCents: returns, qualifyingDays: qualifying, highestGoalDays: highest,
                                consistencyReserveCents: reserve, consistencyReturnCents: consistency,
                                personalReturnCents: personal, charityAllocationCents: terms.commitmentCents - personal,
                                supporterRewardCents: match, unusedSupporterAllowanceCents: (supporterCapCents ?? 0) - match)
    }

    /// Closed entries stay unchanged; current and future dates may still reach their highest goal.
    static func forecast(terms: PlanTerms, dailySteps: [Int?], closedDayCount: Int, supporterCapCents: Int? = nil) throws -> WalkingForecast {
        guard (0...7).contains(closedDayCount) else { throw DomainError.invalid("The closed-date count must be between zero and seven.") }
        let assessment = try evaluate(terms: terms, dailySteps: dailySteps, supporterCapCents: supporterCapCents)
        let closedReturn = assessment.dailyReturnCents.prefix(closedDayCount).reduce(0, +)
        let closedQualifying = dailySteps.prefix(closedDayCount).compactMap { $0 }.filter { $0 >= terms.baseGoalSteps }.count
        let openCount = 7 - closedDayCount
        let attainableReserve = closedQualifying + openCount >= 5 ? assessment.consistencyReserveCents : 0
        let maximum = closedReturn + assessment.dailyMaximumCents.dropFirst(closedDayCount).reduce(0, +) + attainableReserve
        return WalkingForecast(earnedSoFarCents: assessment.personalReturnCents,
                               maximumAttainableCents: maximum,
                               remainingWalkingOpportunityCents: max(maximum - assessment.personalReturnCents, 0),
                               openDayCount: openCount, attainableConsistencyCents: attainableReserve)
    }
}

struct Reconciliation: Equatable, Sendable {
    var targetCents: Int
    var recordedCents: Int
    var outstandingCents: Int { max(targetCents - recordedCents, 0) }
    var excessRecordedCents: Int { max(recordedCents - targetCents, 0) }
}

extension WeeklyAssessment {
    func amount(for bucket: FinancialBucket) -> Int {
        switch bucket {
        case .personalReturn: personalReturnCents
        case .charityAllocation: charityAllocationCents
        case .supporterReward: supporterRewardCents
        }
    }
}
