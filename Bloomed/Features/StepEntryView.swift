import SwiftUI

struct StepEntryView: View {
    let planID: UUID
    @State private var dateKey: String
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var reason = ""
    @State private var error: String?
    @State private var loaded = false
    @State private var clearing = false
    @State private var saving = false
    @State private var openedTodayKey = ""
    @State private var showDateChoice = false
    @State private var showClearConfirmation = false

    init(planID: UUID, dateKey: String) {
        self.planID = planID
        _dateKey = State(initialValue: dateKey)
    }

    private var plan: WeeklyPlan? { store.plans.first { $0.id == planID } }
    private var candidate: Int? {
        guard !text.isEmpty, text.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(text), (0...100_000).contains(value) else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let plan { content(plan) }
                    else { BEmptyState(title: "Plan unavailable", message: "This entry's plan could not be found.") }
                }.bloomedScreen()
            }
            .background(BTheme.background)
            .navigationTitle("Daily step total")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task { load() }
            .planKeyboardDismiss()
            .scrollDismissesKeyboard(.interactively)
            .alert("Clear this recorded total?", isPresented: $showClearConfirmation) {
                Button("Keep total", role: .cancel) { }
                Button("Clear total", role: .destructive) { save(dateConfirmed: false) }
            } message: { Text("The day will show Not recorded. The original entry stays in its revision history.") }
            .alert("The date has changed", isPresented: $showDateChoice) {
                Button("Save to selected date") { save(dateConfirmed: true) }
                Button("Open today's entry") { openToday() }
                Button("Cancel", role: .cancel) { }
            } message: { Text("This sheet was opened before the date changed. Keep the selected date, or open today's entry. Your total will never be moved silently.") }
        }
    }

    @ViewBuilder private func content(_ plan: WeeklyPlan) -> some View {
        let existing = store.effectiveSteps(planID: planID, dateKey: dateKey)
        let reviewedBefore = store.latestReviewedAssessment(for: plan) != nil
        BScreenHeader(eyebrow: "MANUALLY RECORDED", title: PlanDisplay.fullDay(dateKey, timezoneID: plan.timezoneID), subtitle: "\(PlanDisplay.timezoneName(plan.timezoneID)) · Saving replaces the previous total.")
        BCard {
            if clearing {
                Label("This date will become Not recorded", systemImage: "eraser").font(.headline)
                Text("No zero-step activity will be invented. You can enter a total again later.").font(.subheadline).foregroundStyle(BTheme.secondary)
                Button("Keep or change the recorded total") { clearing = false }.frame(minHeight: 44)
            } else {
                PlanInput(title: "Total steps for this date", prompt: "Enter a whole number", text: $text, keyboard: .numberPad, suffix: "steps", identifier: "entry.total")
                Text("Enter 0–100,000 steps. This is the whole day's total, not steps to add.").font(.subheadline).foregroundStyle(BTheme.secondary)
                if let existing { Text("Saved total: \(existing.formatted()) steps").font(.subheadline).foregroundStyle(BTheme.secondary) }
                else { Text("No total recorded yet.").font(.subheadline).foregroundStyle(BTheme.secondary) }
                Button("Record zero steps") { text = "0" }.frame(minHeight: 44)
            }
            Divider()
            PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(stretch.formatted()) steps") }
            if let proposed = proposedAssessment(plan), let index = plan.dateKeys.firstIndex(of: dateKey) {
                BMoneyRow(title: "Earned back for this day · estimate", cents: proposed.dailyReturnCents[index])
                Text("From your own weekly amount. Review confirms the calculation; Bloomed does not verify walking or move money.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        if reviewedBefore, clearing || candidate != existing {
            BCard {
                Text("Correct a reviewed week").font(.headline)
                TextField("Reason for this correction", text: $reason, axis: .vertical)
                    .lineLimit(2...4).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("entry.reason")
                if let after = proposedAssessment(plan) {
                    PlanAssessmentComparison(before: store.assessment(for: plan), after: after)
                }
            }
        }
        if let error { PlanNotice(text: error, warning: true).accessibilityIdentifier("entry.error") }
        BPrimaryButton(title: clearing ? "Confirm clearing total" : "Save total") {
            if clearing { showClearConfirmation = true }
            else { save(dateConfirmed: false) }
        }
        .disabled(saving || (!clearing && candidate == nil) || (reviewedBefore && (clearing || candidate != existing) && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
        .accessibilityIdentifier("entry.save")
        if existing != nil, !clearing {
            Button("Clear recorded total", role: .destructive) { clearing = true }.frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func proposedAssessment(_ plan: WeeklyPlan) -> WeeklyAssessment? {
        guard clearing || candidate != nil, let index = plan.dateKeys.firstIndex(of: dateKey) else { return nil }
        var entries = store.effectiveSteps(for: plan)
        entries[index] = clearing ? nil : candidate
        let support = store.support(for: plan)
        return try? RewardEngine.evaluate(terms: plan.terms, dailySteps: entries, supporterCapCents: support?.applies == true ? support?.capCents : nil)
    }

    private func load() {
        guard !loaded, let plan else { return }
        if let existing = store.effectiveSteps(planID: planID, dateKey: dateKey) { text = String(existing) }
        openedTodayKey = WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID)
        loaded = true
    }

    private func save(dateConfirmed: Bool) {
        guard let plan, !saving else { return }
        store.refresh()
        let today = WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID)
        if today != openedTodayKey, !dateConfirmed { showDateChoice = true; return }
        saving = true
        defer { saving = false }
        do {
            try store.recordSteps(planID: planID, dateKey: dateKey, total: clearing ? nil : candidate, reason: reason, expectedTodayKey: today)
            dismiss()
        } catch { self.error = PlanDisplay.text(error) }
    }

    private func openToday() {
        guard let plan else { return }
        let today = WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID)
        guard plan.dateKeys.contains(today) else { error = "Today is outside this weekly plan. Reopen the selected date to finish its correction."; return }
        dateKey = today
        text = store.effectiveSteps(planID: planID, dateKey: today).map(String.init) ?? ""
        reason = ""
        clearing = false
        openedTodayKey = today
    }
}
