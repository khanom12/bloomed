import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var sheet: TodaySheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BBrandLockup().foregroundStyle(BTheme.accent)
                if let plan = store.currentPlan {
                    TodayPlanContent(plan: plan, openEntry: { sheet = .steps(plan.id, $0) }, openReview: { sheet = .review(plan.id) })
                } else {
                    BEmptyState(title: "Build a walking routine.",
                                message: "Choose a daily step goal and an amount of your own money for seven days. Record your steps to earn it back. After your weekly review, the rest is for charity.",
                                illustration: .walking,
                                actionTitle: store.draft == nil ? "Create your walking plan" : "Continue your walking plan",
                                action: { sheet = .create })
                    if let draft = store.draft {
                        Label("Your draft is saved. You haven’t committed to a week yet.", systemImage: "square.and.pencil")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                        Text("Continue at step \(draft.step + 1) of 5").font(.caption).foregroundStyle(BTheme.secondary)
                    }
                    Text("Bloomed records your manually entered steps and calculates the amounts. You arrange all money and donations outside the app.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }.bloomedScreen()
        }
        .background(BTheme.background.ignoresSafeArea())
        .navigationTitle("Today").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { item in
            switch item {
            case .create: PlanEditorView()
            case .steps(let id, let key): StepEntryView(planID: id, dateKey: key)
            case .review(let id): WeeklyReviewView(planID: id)
            }
        }
    }
}

private enum TodaySheet: Identifiable {
    case create, steps(UUID, String), review(UUID)
    var id: String {
        switch self {
        case .create: "create"
        case .steps(let id, let key): "steps-\(id)-\(key)"
        case .review(let id): "review-\(id)"
        }
    }
}

private struct TodayPlanContent: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    let openEntry: (String) -> Void
    let openReview: () -> Void

    private var today: String { WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID) }
    private var dayIndex: Int? { plan.dateKeys.firstIndex(of: today) }
    private var status: PlanStatus { store.lifecycle(for: plan) }
    private var assessment: WeeklyAssessment { store.assessment(for: plan) }
    private var steps: [Int?] { store.effectiveSteps(for: plan) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                Text(Format.week(plan)).font(.subheadline).foregroundStyle(BTheme.secondary)
                Spacer(minLength: 8)
                BStatusBadge(title: status.title, warning: status == .awaitingReview)
            }
            if status == .active, let dayIndex {
                activeDay(dayIndex)
            } else if status == .scheduled {
                upcomingWeek
            } else {
                BCard {
                    Text(status == .reviewed ? "Your week is saved." : "Review your week.").font(.title2.weight(.semibold))
                    BMoneyRow(title: status == .reviewed ? "Your money earned back" : "Earned back · estimate", cents: assessment.personalReturnCents, emphasized: true)
                    Text(status == .reviewed ? "Plan another week when you're ready. Money received, kept, and donated is recorded separately." : "Check your seven days and confirm the calculation. This does not move money.")
                        .foregroundStyle(BTheme.secondary)
                    if status == .awaitingReview { BPrimaryButton(title: "Review this week", action: openReview) }
                    NavigationLink("View your plan") { PlanDetailView(planID: plan.id) }
                        .font(.body.weight(.semibold)).frame(minHeight: 44)
                }
            }
            if status != .scheduled {
                BCard {
                    BSectionTitle(title: "Your walking this week")
                    BWeekStrip(plan: plan, steps: steps, todayKey: today, onSelect: openEntry)
                    if plan.terms.consistencyEnabled {
                        Divider()
                        Label("\(min(assessment.qualifyingDays, 5)) of 5 days at your everyday goal", systemImage: assessment.qualifyingDays >= 5 ? "checkmark.seal.fill" : "calendar")
                            .font(.headline).foregroundStyle(BTheme.accent)
                        Text("Reach \(plan.terms.baseGoalSteps.formatted()) steps on any five days to earn back \(Format.money(assessment.consistencyReserveCents)) of your weekly amount. Higher-goal days count too.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                }
            }
            if let support = store.support(for: plan), support.applies {
                BCard {
                    Label("\(support.alias) is supporting this week", systemImage: "person.2").font(.headline)
                    Text("Matching what you earn back, up to \(Format.money(min(support.capCents, plan.terms.commitmentCents))) for this week.")
                        .foregroundStyle(BTheme.secondary)
                    if status != .scheduled {
                        BMoneyRow(title: status == .reviewed ? "This week's match" : "Match this week · estimate", cents: assessment.supporterRewardCents)
                    }
                    NavigationLink("View supporter match") { MoneyDetailView(planID: plan.id) }.frame(minHeight: 44)
                    Text("Agreement recorded by you. Any payment is arranged outside Bloomed.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
            }
            if plan.timezoneID != TimeZone.current.identifier {
                BNotice(message: "This week follows \(PlanDisplay.timezoneName(plan.timezoneID)) time, including when you travel.")
            }
        }
    }

    private func activeDay(_ index: Int) -> some View {
        BCard {
            Text("DAY \(index + 1) OF 7").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(BTheme.secondary)
            VStack(alignment: .leading, spacing: 4) {
                if let total = steps[index] {
                    Text(total.formatted()).font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                        .accessibilityLabel("\(total.formatted()) steps recorded")
                } else {
                    Text("Not recorded").font(.largeTitle.weight(.bold))
                }
                Text("steps today").foregroundStyle(BTheme.secondary)
            }.foregroundStyle(BTheme.ink)
            BStepProgress(steps: steps[index] ?? 0, base: plan.terms.baseGoalSteps, stretch: plan.terms.stretchGoalSteps)
            BPrimaryButton(title: steps[index] == nil ? "Record today's steps" : "Update today's steps", action: { openEntry(today) })
                .accessibilityIdentifier("update-today-steps")
            Divider()
            BMoneyRow(title: "Earned back today · estimate", cents: assessment.dailyReturnCents[index])
            Text("From your own weekly amount. Based on your recorded total; reviewed at the end of the week.")
                .font(.caption).foregroundStyle(BTheme.secondary)
        }
    }

    private var upcomingWeek: some View {
        BCard {
            Image(systemName: "calendar").font(.title).foregroundStyle(BTheme.accent).accessibilityHidden(true)
            Text(startsTomorrow ? "Your week starts tomorrow." : "Your next walking week.").font(.title2.weight(.semibold))
            Text("Starts \(PlanDisplay.fullDay(plan.startDateKey, timezoneID: plan.timezoneID))").foregroundStyle(BTheme.secondary)
            PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let higher = plan.terms.stretchGoalSteps {
                PlanValueRow(title: "Higher goal", value: "\(higher.formatted()) steps")
            }
            PlanValueRow(title: "Your weekly amount · CAD", value: money(plan.terms.commitmentCents))
            Text("You can earn back up to \(money(plan.terms.commitmentCents)) through your plan. Step recording opens when your week starts.")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
            NavigationLink { PlanDetailView(planID: plan.id) } label: {
                HStack { Text("View your plan"); Spacer(); Image(systemName: "chevron.right") }.frame(minHeight: 44)
            }
        }
    }

    private var startsTomorrow: Bool {
        (try? WeeklyCalendar.addingDays(1, to: today, timezoneID: plan.timezoneID)) == plan.startDateKey
    }
}

struct BWeekStrip: View {
    let plan: WeeklyPlan
    let steps: [Int?]
    let todayKey: String
    let onSelect: (String) -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(spacing: 8) {
                ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                    Button { onSelect(key) } label: {
                        HStack {
                            Text(PlanDisplay.shortDay(key, timezoneID: plan.timezoneID))
                            Spacer()
                            Text(key > todayKey ? "Upcoming" : steps[index].map { "\($0.formatted()) steps" } ?? "Not recorded")
                        }.frame(minHeight: 44)
                    }.disabled(key > todayKey).foregroundStyle(BTheme.ink)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 0) {
                ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                    let qualifies = (steps[index] ?? -1) >= plan.terms.baseGoalSteps
                    Button { onSelect(key) } label: {
                        VStack(spacing: 8) {
                            Text(Format.weekday(key, timezoneID: plan.timezoneID)).font(.caption2)
                            Image(systemName: key > todayKey ? "circle" : qualifies ? "checkmark.circle.fill" : (steps[index] == nil ? "circle.dashed" : "minus.circle"))
                                .font(.title2).foregroundStyle(qualifies ? BTheme.accent : BTheme.secondary)
                            if key == todayKey { Circle().fill(BTheme.accent).frame(width: 4, height: 4) }
                        }.frame(maxWidth: .infinity, minHeight: 70)
                    }
                    .disabled(key > todayKey)
                    .foregroundStyle(BTheme.secondary)
                    .accessibilityLabel("\(Format.day(key, timezoneID: plan.timezoneID)), \(daySummary(index, key: key))")
                }
            }
        }
    }

    private func daySummary(_ index: Int, key: String) -> String {
        if key > todayKey { return "upcoming" }
        guard let total = steps[index] else { return "not recorded" }
        let outcome = total >= plan.terms.highestGoalSteps ? "goal reached" : total >= plan.terms.baseGoalSteps ? "everyday goal reached" : "below everyday goal"
        return "\(total) steps, \(outcome)"
    }
}
