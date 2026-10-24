import SwiftUI

struct WalkingProgressView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BScreenHeader(eyebrow: "Your journey", title: "See your growth.", subtitle: "Every week keeps its own story.")
                if let plan = store.currentPlan {
                    ActivityWeekCard(plan: plan)
                }
                if store.plans.isEmpty {
                    BEmptyState(title: "Room for your story.", message: "Your recorded steps and weekly goals will appear here after you create a plan.", symbol: "chart.bar.xaxis")
                } else {
                    BSectionTitle(title: "Your weeks")
                    ForEach(store.plans) { plan in
                        NavigationLink { PlanDetailView(planID: plan.id) } label: {
                            WeekHistoryCard(plan: plan)
                        }.buttonStyle(.plain)
                    }
                }
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea())
            .navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
    }
}

struct WeekHistoryCard: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    var body: some View {
        let steps = store.effectiveSteps(for: plan)
        let recorded = steps.compactMap { $0 }
        BCard {
            HStack(alignment: .top) {
                Text(Format.week(plan)).font(.headline).foregroundStyle(BTheme.ink)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(BTheme.secondary)
            }
            HStack {
                Label("\(recorded.reduce(0, +).formatted()) steps", systemImage: "figure.walk")
                Spacer()
                Text("\(recorded.count)/7 recorded")
            }.font(.subheadline).foregroundStyle(BTheme.secondary)
            Text("Base \(plan.terms.baseGoalSteps.formatted())\(plan.terms.stretchGoalSteps.map { " · Stretch \($0.formatted())" } ?? "")")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
            BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.lifecycle(for: plan) == .awaitingReview)
        }
    }
}

private struct ActivityWeekCard: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    @State private var selected: SelectedActivityDate?

    var body: some View {
        let steps = store.effectiveSteps(for: plan)
        let recorded = steps.compactMap { $0 }
        let assessment = store.assessment(for: plan)
        BCard {
            BSectionTitle(title: "This week's walking")
            Text(Format.week(plan)).font(.subheadline).foregroundStyle(BTheme.secondary)
            HStack(alignment: .firstTextBaseline) {
                Text(recorded.reduce(0, +).formatted()).font(.largeTitle.weight(.bold)).monospacedDigit()
                Text("steps recorded").foregroundStyle(BTheme.secondary)
            }.foregroundStyle(BTheme.ink)
            ActivityBars(plan: plan, steps: steps).accessibilityHidden(true)
            Text("\(recorded.count) of 7 days recorded · \(assessment.qualifyingDays) base goals reached")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
            if !recorded.isEmpty {
                Text("Average \((recorded.reduce(0, +) / recorded.count).formatted()) steps across \(recorded.count) recorded days")
                    .font(.caption).foregroundStyle(BTheme.secondary)
            }
            Divider()
            ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                let canEdit = key <= WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID) && store.lifecycle(for: plan) != .voidedBeforeStart
                Button { selected = SelectedActivityDate(key: key) } label: {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Format.day(key, timezoneID: plan.timezoneID))
                        Spacer()
                        Text(steps[index].map { "\($0.formatted())" } ?? "Not recorded").monospacedDigit()
                        Image(systemName: "chevron.right").font(.caption2)
                    }.font(.subheadline).foregroundStyle(BTheme.ink).frame(minHeight: 44)
                }.disabled(!canEdit)
                    .accessibilityLabel("\(Format.day(key, timezoneID: plan.timezoneID)), \(steps[index].map { "\($0) steps" } ?? "not recorded"), goal \(plan.terms.baseGoalSteps)")
            }
        }
        .sheet(item: $selected) { selection in StepEntryView(planID: plan.id, dateKey: selection.key) }
    }
}

private struct SelectedActivityDate: Identifiable {
    let key: String
    var id: String { key }
}

private struct ActivityBars: View {
    let plan: WeeklyPlan
    let steps: [Int?]
    var body: some View {
        let maximum = max(steps.compactMap { $0 }.max() ?? 0, plan.terms.highestGoalSteps)
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6)
                        .fill((steps[index] ?? 0) >= plan.terms.baseGoalSteps ? BTheme.accent : BTheme.accentSoft)
                        .frame(height: steps[index] == nil ? 3 : max(4, CGFloat(steps[index] ?? 0) / CGFloat(maximum) * 100))
                    Text(Format.weekday(key, timezoneID: plan.timezoneID)).font(.caption2).foregroundStyle(BTheme.secondary)
                }.frame(maxWidth: .infinity)
            }
        }.frame(height: 130)
    }
}
