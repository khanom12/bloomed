import SwiftUI

struct PlanNotice: View {
    let text: String
    var warning = false

    var body: some View {
        Label {
            Text(text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: warning ? "exclamationmark.circle" : "info.circle")
        }
        .foregroundStyle(warning ? BTheme.warning : BTheme.secondary)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(warning ? BTheme.warningSoft : BTheme.accentSoft, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct PlanInput: View {
    let title: String
    let prompt: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var suffix: String? = nil
    var identifier = ""
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { input; unit }
                } else {
                    HStack(alignment: .firstTextBaseline) { input; unit }
                }
            }
            .padding(16)
            .background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(BTheme.secondary, lineWidth: 1))
        }
    }

    private var input: some View {
        TextField(prompt, text: $text)
            .keyboardType(keyboard)
            .font(.title2.monospacedDigit())
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder private var unit: some View {
        if let suffix { Text(suffix).font(.subheadline).foregroundStyle(BTheme.secondary) }
    }
}

struct PlanValueRow: View {
    let title: String
    let value: String
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title).foregroundStyle(BTheme.secondary)
                Spacer(minLength: 12)
                Text(value).fontWeight(.semibold).multilineTextAlignment(.trailing)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).foregroundStyle(BTheme.secondary)
                Text(value).fontWeight(.semibold)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum PlanDisplay {
    static func shortDay(_ key: String, timezoneID: String) -> String {
        guard let date = try? WeeklyCalendar.date(for: key, timezoneID: timezoneID) else { return key }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezoneID)
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d")
        return formatter.string(from: date)
    }

    static func fullDay(_ key: String, timezoneID: String) -> String {
        guard let date = try? WeeklyCalendar.date(for: key, timezoneID: timezoneID) else { return key }
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timezoneID)
        formatter.setLocalizedDateFormatFromTemplate("EEEE MMMM d yyyy")
        return formatter.string(from: date)
    }

    static func week(_ plan: WeeklyPlan) -> String {
        guard let last = plan.dateKeys.last else { return plan.startDateKey }
        return "\(shortDay(plan.startDateKey, timezoneID: plan.timezoneID)) – \(shortDay(last, timezoneID: plan.timezoneID))"
    }

    static func number(_ value: Int) -> String { value.formatted() }

    static func text(_ error: Error) -> String { error.localizedDescription }

    static func goal(_ value: String) -> Int? {
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }), let steps = Int(value), (1...100_000).contains(steps) else { return nil }
        return steps
    }
}

struct PlanAssessmentComparison: View {
    let before: WeeklyAssessment
    let after: WeeklyAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How this changes the week").font(.headline)
            comparison("Your money earned back", before.personalReturnCents, after.personalReturnCents)
            comparison("Charity allocation", before.charityAllocationCents, after.charityAllocationCents)
            comparison("Supporter rewards", before.supporterRewardCents, after.supporterRewardCents)
            Text("Existing external payment and donation records stay in your history. Confirm a new weekly review before recording further settlement.")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
        }
    }

    private func comparison(_ title: String, _ old: Int, _ new: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).foregroundStyle(BTheme.secondary)
            Text("\(Money.format(old)) → \(Money.format(new))")
                .font(.headline.monospacedDigit())
        }
        .accessibilityElement(children: .combine)
    }
}

private struct PlanKeyboardDismissModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .accessibilityIdentifier("keyboard.done")
            }
        }
    }
}

extension View {
    func planKeyboardDismiss() -> some View { modifier(PlanKeyboardDismissModifier()) }
}
