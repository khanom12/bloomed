import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store
    @State private var sheet: TodaySheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BScreenHeader(eyebrow: "Bloomed", title: "A little each day.", subtitle: "Your pace. Your commitment.")
                if let plan = store.currentPlan {
                    TodayPlanContent(plan: plan, openEntry: { key in sheet = .steps(plan.id, key) }, openReview: { sheet = .review(plan.id) })
                } else {
                    BEmptyState(title: "Your next chapter starts with a walk.",
                                message: "Choose a goal that fits your life. Make a personal commitment, then build your week one day at a time.",
                                symbol: "figure.walk", actionTitle: "Create your walking plan", action: { sheet = .create })
                    BNotice(message: "Bloomed records your progress and calculates your returns. All money and donations are arranged outside the app.")
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
                Spacer()
                BStatusBadge(title: status.title, warning: status == .awaitingReview)
            }
            if status == .active, let dayIndex {
                BCard {
                    HStack {
                        Text("DAY \(dayIndex + 1) OF 7").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(BTheme.secondary)
                        Spacer()
                        Image(systemName: "figure.walk").foregroundStyle(BTheme.accent).accessibilityHidden(true)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let total = steps[dayIndex] {
                            Text(total.formatted()).font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                                .accessibilityLabel("\(total) steps recorded")
                        } else {
                            Text("Not recorded").font(.largeTitle.weight(.bold))
                        }
                        Text("steps recorded today").foregroundStyle(BTheme.secondary)
                    }.foregroundStyle(BTheme.ink)
                    BStepProgress(steps: steps[dayIndex] ?? 0, base: plan.terms.baseGoalSteps, stretch: plan.terms.stretchGoalSteps)
                    BPrimaryButton(title: "Update today's steps", action: { openEntry(today) })
                        .accessibilityIdentifier("update-today-steps")
                    Divider()
                    BMoneyRow(title: "Your return today", cents: assessment.dailyReturnCents[dayIndex], emphasized: true)
                    Text("Provisional · based on your recorded total").font(.caption).foregroundStyle(BTheme.secondary)
                }
            } else if status == .scheduled {
                BEmptyState(title: "A fresh week is ahead.", message: "Your plan starts \(Format.day(plan.startDateKey, timezoneID: plan.timezoneID)). Your walking targets and commitment are ready.", symbol: "calendar")
            } else {
                BCard {
                    Text(status == .reviewed ? "A week to build on." : "Make a moment for review.").font(.title2.weight(.semibold))
                    BMoneyRow(title: "Your money earned back", cents: assessment.personalReturnCents, emphasized: true)
                    Text(status == .reviewed ? "Your recorded results are saved. Prepare another week when you're ready." : "Check your seven days and confirm the result before recording outside settlements.")
                        .foregroundStyle(BTheme.secondary)
                    if status == .awaitingReview { BPrimaryButton(title: "Review this week", action: openReview) }
                    NavigationLink("View the weekly plan") { PlanDetailView(planID: plan.id) }
                        .font(.body.weight(.semibold)).frame(minHeight: 44)
                }
            }
            BCard {
                BSectionTitle(title: "Your week, one day at a time")
                BWeekStrip(plan: plan, steps: steps, todayKey: today, onSelect: openEntry)
                if plan.terms.consistencyEnabled {
                    Divider()
                    Label("\(min(assessment.qualifyingDays, 5)) of 5 qualifying days", systemImage: assessment.qualifyingDays >= 5 ? "checkmark.seal.fill" : "leaf")
                        .font(.headline).foregroundStyle(BTheme.accent)
                    Text("Any five days at your base goal unlock \(Format.money(assessment.consistencyReserveCents)) from your commitment. They don't need to be consecutive.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            if let support = store.support(for: plan), support.applies {
                BCard {
                    Label("In your corner", systemImage: "person.crop.circle.badge.checkmark").font(.headline)
                    Text("\(support.alias) · matching up to \(Format.money(support.capCents)) this week")
                        .foregroundStyle(BTheme.secondary)
                    BMoneyRow(title: "Supporter reward calculated", cents: assessment.supporterRewardCents)
                    Text("Agreement recorded by you. Payment is arranged outside Bloomed.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
            }
            if plan.timezoneID != TimeZone.current.identifier {
                BNotice(message: "This week follows \(plan.timezoneID). Its dates stay the same when you travel.")
            }
        }
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
                            Text(Format.day(key, timezoneID: plan.timezoneID))
                            Spacer()
                            Text(steps[index].map { "\($0.formatted()) steps" } ?? "Not recorded")
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
                            Image(systemName: qualifies ? "checkmark.circle.fill" : (steps[index] == nil ? "circle.dashed" : "circle"))
                                .font(.title2).foregroundStyle(qualifies ? BTheme.accent : BTheme.secondary)
                            if key == todayKey { Circle().fill(BTheme.accent).frame(width: 4, height: 4) }
                        }.frame(maxWidth: .infinity, minHeight: 70)
                    }
                    .disabled(key > todayKey)
                    .foregroundStyle(BTheme.secondary)
                    .accessibilityLabel("\(Format.day(key, timezoneID: plan.timezoneID)), \(steps[index].map { "\($0) steps" } ?? "not recorded"), \(qualifies ? "base goal reached" : "base goal not reached")")
                }
            }
        }
    }
}
