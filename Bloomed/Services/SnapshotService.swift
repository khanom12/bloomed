import Foundation

enum SnapshotKind: String, CaseIterable, Identifiable {
    case invitation = "Invitation"
    case progress = "Progress snapshot"
    case reviewed = "Reviewed summary"
    var id: String { rawValue }
}

struct SnapshotContent {
    let kind: SnapshotKind
    let displayName: String
    let headline: String
    let introduction: String
    let dateRange: String
    let timezoneID: String
    let timestamp: String
    let status: String
    let targetLines: [String]
    let activitySummary: String
    let activityLines: [String]
    let moneyLines: [String]
    let explanation: String

    var moneyHeading: String { kind == .invitation ? "The commitment and match" : "Money record · CAD" }
    var recordDisclosure: String {
        "Static summary from participant-recorded activity. Not independently verified. Money and donations are arranged outside Bloomed."
    }
    var timezoneName: String { PlanDisplay.timezoneName(timezoneID) }

    var text: String {
        var sections = [
            ["Bloomed — \(kind.rawValue)", displayName, headline].filter { !$0.isEmpty }.joined(separator: "\n"),
            introduction,
            ["Walking week", dateRange, "Week follows \(timezoneName)", status].joined(separator: "\n"),
            (["Walking goals"] + targetLines).joined(separator: "\n")
        ]
        if !activityLines.isEmpty {
            sections.append((["Recorded walking", activitySummary] + activityLines).joined(separator: "\n"))
        }
        if !moneyLines.isEmpty { sections.append(([moneyHeading] + moneyLines).joined(separator: "\n\n")) }
        sections += [explanation, "Created \(timestamp) · \(timezoneName)", recordDisclosure]
        return sections.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }
}

@MainActor
enum SnapshotService {
    static func matchLimitExplanation(commitmentCents: Int, capCents: Int, firstPerson: Bool = false) -> String {
        let owner = firstPerson ? "my" : "your"
        let maximum = min(commitmentCents, capCents)
        let summary = "The match is $1 for every $1 of \(owner) own money earned back, including consistency, up to \(Format.money(capCents)) per week. The largest possible match for this plan is \(Format.money(maximum))."
        if capCents > commitmentCents {
            return summary + " A limit above \(owner) \(Format.money(commitmentCents)) commitment does not multiply the match."
        }
        return summary
    }

    static func content(plan: WeeklyPlan, store: AppStore, kind requestedKind: SnapshotKind, includeMoney: Bool, at date: Date) -> SnapshotContent {
        let result = store.assessment(for: plan)
        let status = store.lifecycle(for: plan)
        // A caller cannot turn an unreviewed correction into a reviewed export.
        let kind: SnapshotKind = requestedKind == .reviewed && status != .reviewed ? .progress : requestedKind
        let steps = store.effectiveSteps(for: plan)
        let support = store.support(for: plan)
        var targets = ["Everyday goal: \(plan.terms.baseGoalSteps.formatted()) steps per day"]
        if let higher = plan.terms.stretchGoalSteps { targets.append("Higher goal: \(higher.formatted()) steps per day") }
        if plan.terms.consistencyEnabled {
            targets.append("Consistency: reach the everyday goal on any 5 of 7 days. Higher-goal days count too.")
        }
        let todayKey = WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID)
        let recordedSteps = steps.compactMap { $0 }
        let activitySummary = "\(recordedSteps.count) of 7 days recorded · \(recordedSteps.reduce(0, +).formatted()) steps across recorded days · everyday goal reached on \(result.qualifyingDays) \(result.qualifyingDays == 1 ? "day" : "days")"
        let activity: [String] = kind == .invitation ? [] : plan.dateKeys.enumerated().map { index, key in
            let value = steps[index].map { "\($0.formatted()) steps" } ?? (key > todayKey ? "Upcoming" : "Not recorded")
            return "\(Format.day(key, timezoneID: plan.timezoneID)): \(value)"
        }
        let destination = store.charityDestination(for: plan).trimmingCharacters(in: .whitespacesAndNewlines)
        var financial: [String] = []
        if includeMoney || kind != .progress {
            financial.append("My own weekly commitment: \(Format.money(plan.terms.commitmentCents)) CAD")
            if kind == .invitation {
                let highestGoal = plan.terms.stretchGoalSteps == nil ? "everyday goal" : "higher goal"
                financial.append("I can earn back all \(Format.money(plan.terms.commitmentCents)) by reaching my \(highestGoal) on all 7 days. Anything I do not earn back is for donation.")
                financial.append(destination.isEmpty ? "Donation destination: not chosen yet." : "Donation destination: \(destination)")
                if let support {
                    financial.append("Recorded supporter: \(support.alias)")
                    financial.append(matchLimitExplanation(commitmentCents: plan.terms.commitmentCents, capCents: support.capCents, firstPerson: true))
                    financial.append("Agreement recorded by participant; not independently confirmed by the supporter.")
                } else {
                    financial.append("Would you match $1 for every $1 I earn back, including consistency? With this plan, the most you could add is \(Format.money(plan.terms.commitmentCents)). We can agree a lower weekly limit.")
                    financial.append("Invitation — no supporter agreement recorded")
                }
            } else {
                financial.append("My money earned back\(status == .reviewed ? " (reviewed)" : " so far"): \(Format.money(result.personalReturnCents))")
                if status == .reviewed {
                    financial.append("Planned donation: \(Format.money(result.charityAllocationCents))\(destination.isEmpty ? " · destination not chosen yet" : " to " + destination)")
                }
                if let support {
                    financial.append("Supporter: \(support.alias) · weekly match limit \(Format.money(support.capCents))")
                    financial.append("Extra supporter match calculated: \(Format.money(result.supporterRewardCents))")
                    financial.append("Unused part of the match limit: \(Format.money(result.unusedSupporterAllowanceCents)) stays with the supporter.")
                    financial.append("Agreement recorded by participant")
                    if support.capCents > plan.terms.commitmentCents {
                        financial.append(matchLimitExplanation(commitmentCents: plan.terms.commitmentCents, capCents: support.capCents, firstPerson: true))
                    }
                }
            }
            if let support, let standingID = support.standingAgreementID,
               let agreement = store.state.standingAgreements.first(where: { $0.id == standingID }) {
                let ending = agreement.inclusiveEndDateKey.map {
                    "through \(PlanDisplay.shortDay($0, timezoneID: agreement.timezoneID))"
                } ?? "until stopped"
                financial.append("Recurring agreement: from \(PlanDisplay.shortDay(agreement.effectiveStartDateKey, timezoneID: agreement.timezoneID)) \(ending). The limit resets for each confirmed week with unchanged terms. Each whole week must be covered; no plans or charges are created automatically.")
                if agreement.pausedAt != nil || agreement.endedAt != nil {
                    financial.append(agreement.endedAt != nil ? "Recurring support has ended for future weeks. This week's recorded agreement stays in history." : "Recurring support is paused for future weeks. This week's recorded agreement stays in history.")
                }
            }
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: plan.timezoneID)
        let label: String
        if kind == .invitation {
            label = support == nil ? "Confirmed plan · invitation only" : "Confirmed plan · outside agreement recorded by participant"
        } else if status == .reviewed { label = "Reviewed calculation · payment is separate" }
        else if store.latestReviewedAssessment(for: plan) != nil { label = "Correction awaiting review · provisional" }
        else { label = "\(status.title) · not reviewed · amounts may change" }
        let headline: String
        let introduction: String
        let explanation: String
        switch kind {
        case .invitation:
            headline = support == nil ? "Help me build a walking routine." : "A little support for my walking week."
            introduction = support == nil
                ? "I'm making time to walk each day. I've chosen my goals and committed my own money. A matching contribution would give me someone in my corner."
                : "Here's the walking plan behind the supporter match I've recorded. The agreement and any payment are arranged directly, outside Bloomed."
            explanation = support == nil
                ? "If you'd like to help, let's agree a weekly limit and discuss the arrangement directly. There is nothing to accept or pay in Bloomed. Sharing this invitation does not record your agreement. Any unused part of a supporter limit stays with the supporter."
                : "This is the participant's record of an outside agreement. Sharing it does not confirm acceptance or payment. Any unused part of the supporter limit stays with the supporter."
        case .progress:
            headline = status == .reviewed ? "My walking week." : "My walking week, so far."
            introduction = "A snapshot of the walking I've recorded for this seven-day plan. Future days are upcoming; missing past or current days are not recorded."
            explanation = "Calculated from the participant's manual entries. An earned amount is not proof of payment or donation."
        case .reviewed:
            headline = "A week of walking, reviewed."
            introduction = "I've reviewed this week's recorded walking and the amounts calculated from my plan. Payment and donation records are separate."
            explanation = "Reviewed by the participant, based on their manual entries. An earned amount is not proof of payment or donation."
        }
        return SnapshotContent(kind: kind, displayName: store.profile.displayName,
                               headline: headline, introduction: introduction,
                               dateRange: Format.week(plan), timezoneID: plan.timezoneID,
                               timestamp: formatter.string(from: date), status: label,
                               targetLines: targets, activitySummary: activitySummary,
                               activityLines: activity, moneyLines: financial, explanation: explanation)
    }
}
