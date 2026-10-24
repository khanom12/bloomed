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
    let dateRange: String
    let timezoneID: String
    let timestamp: String
    let status: String
    let targetLines: [String]
    let activityLines: [String]
    let moneyLines: [String]
    let explanation: String

    var text: String {
        (["Bloomed — \(kind.rawValue)", displayName, dateRange, timezoneID, status]
         + targetLines + activityLines + moneyLines
         + [explanation, "As of \(timestamp)", "Static summary from participant-recorded activity. Not independently verified. Money is arranged outside Bloomed."])
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

@MainActor
enum SnapshotService {
    static func content(plan: WeeklyPlan, store: AppStore, kind: SnapshotKind, includeMoney: Bool, at date: Date) -> SnapshotContent {
        let result = store.assessment(for: plan)
        let status = store.lifecycle(for: plan)
        let steps = store.effectiveSteps(for: plan)
        var targets = ["Daily base: \(plan.terms.baseGoalSteps.formatted()) steps"]
        if let stretch = plan.terms.stretchGoalSteps { targets.append("Optional stretch: \(stretch.formatted()) steps") }
        if plan.terms.consistencyEnabled { targets.append("Consistency: base goal on any 5 of 7 days · \(result.qualifyingDays) qualifying days recorded") }
        var activity: [String] = []
        if kind != .invitation {
            activity = plan.dateKeys.enumerated().map { index, key in
                "\(Format.day(key, timezoneID: plan.timezoneID)): \(steps[index].map { "\($0.formatted()) steps" } ?? "Not recorded")"
            }
        }
        var financial: [String] = []
        if includeMoney || kind != .progress {
            financial.append("Personal commitment: \(Format.money(plan.terms.commitmentCents)) CAD")
            if kind != .invitation {
                financial.append("Personal return calculated: \(Format.money(result.personalReturnCents))")
                if status == .reviewed { financial.append("Charity allocation: \(Format.money(result.charityAllocationCents)) to \(plan.terms.charity)") }
            }
            if let support = store.support(for: plan) {
                financial.append("\(support.alias): 1:1 match up to \(Format.money(support.capCents)) this week")
                financial.append("Agreement recorded by participant")
                if kind != .invitation {
                    financial.append("Supporter reward calculated: \(Format.money(result.supporterRewardCents))")
                    financial.append("Unused supporter allowance: \(Format.money(result.unusedSupporterAllowanceCents)) stays with supporter")
                }
            } else if kind == .invitation {
                financial.append("Would you match what I earn back, up to an amount you choose?")
                financial.append("Invitation — no supporter agreement recorded")
            }
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium; formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: plan.timezoneID)
        let label: String
        if kind == .invitation { label = "Confirmed plan · invitation" }
        else if status == .reviewed { label = "Reviewed calculation · payment is separate" }
        else if store.latestReviewedAssessment(for: plan) != nil { label = "Correction awaiting review · provisional" }
        else { label = "Provisional · \(status.title)" }
        return SnapshotContent(kind: kind, displayName: store.profile.displayName,
                               dateRange: Format.week(plan), timezoneID: plan.timezoneID,
                               timestamp: formatter.string(from: date), status: label,
                               targetLines: targets, activityLines: activity, moneyLines: financial,
                               explanation: kind == .invitation ? "I chose a walking plan and made my own commitment. Support is optional and agreed outside Bloomed." : "Calculated from the participant's manual entries. An earned amount is not proof of payment or donation.")
    }
}
