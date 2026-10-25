import SwiftUI
import UIKit

struct WalkingProgressView: View {
    @Environment(AppStore.self) private var store
    @State private var createPlan = false
    @State private var viewMode = WalkingHistoryMode.week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if store.plans.isEmpty {
                    BEmptyState(title: "See your walking take shape", message: "Record your daily steps, see which goals you reach, and look back at each week. A month view helps you spot your routine over time.", illustration: .progress, actionTitle: store.draft == nil ? "Create your walking plan" : "Continue your walking plan", action: { createPlan = true })
                } else {
                    Picker("Walking history view", selection: $viewMode) {
                        Text("Week").tag(WalkingHistoryMode.week)
                        Text("Month").tag(WalkingHistoryMode.month)
                    }.pickerStyle(.segmented)
                    if viewMode == .week {
                        if let plan = store.currentPlan { ActivityWeekCard(plan: plan) }
                    } else {
                        WalkingMonthView()
                    }
                    BSectionTitle(title: "Your weeks")
                    ForEach(store.plans) { plan in
                        NavigationLink { WalkingWeekDetailView(planID: plan.id) } label: {
                            WeekHistoryCard(plan: plan)
                        }.buttonStyle(.plain).accessibilityIdentifier("walking.history-week")
                    }
                }
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea())
            .navigationTitle("Progress").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $createPlan) { PlanEditorView() }
    }
}

private enum WalkingHistoryMode { case week, month }

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
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(BTheme.secondary).accessibilityHidden(true)
            }
            BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.lifecycle(for: plan) == .awaitingReview)
            if store.lifecycle(for: plan) != .scheduled && store.lifecycle(for: plan) != .voidedBeforeStart {
                Text("\(recorded.reduce(0, +).formatted()) steps · \(recorded.count) of 7 days recorded")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            Text("Everyday goal: \(plan.terms.baseGoalSteps.formatted()) steps\(plan.terms.stretchGoalSteps.map { " · Higher goal: \($0.formatted())" } ?? "")")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
        }
    }
}

struct WalkingWeekDetailView: View {
    @Environment(AppStore.self) private var store
    let planID: UUID
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let plan = store.plan(id: planID) {
                    ActivityWeekCard(plan: plan)
                    NavigationLink("View this week's plan") { PlanDetailView(planID: plan.id) }.frame(minHeight: 44)
                    NavigationLink("View this week's money") { MoneyDetailView(planID: plan.id) }.frame(minHeight: 44)
                } else {
                    BEmptyState(title: "Week unavailable", message: "This week is no longer in your saved records.", symbol: "calendar.badge.exclamationmark")
                }
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea())
            .navigationTitle("Weekly walking").navigationBarTitleDisplayMode(.inline)
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
        let status = store.lifecycle(for: plan)
        BCard {
            Text(Format.week(plan)).font(.headline).foregroundStyle(BTheme.ink)
            BStatusBadge(title: status.title, warning: status == .awaitingReview)
            if status == .scheduled {
                Text("Your first walking day is \(PlanDisplay.shortDay(plan.startDateKey, timezoneID: plan.timezoneID)). Record your steps once the day arrives.")
                    .foregroundStyle(BTheme.secondary)
            } else if status == .voidedBeforeStart {
                Text("This plan was cancelled before it started. Its dates and goals remain in your history.")
                    .foregroundStyle(BTheme.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text(recorded.reduce(0, +).formatted()).font(.largeTitle.weight(.bold)).monospacedDigit()
                    Text("steps recorded").foregroundStyle(BTheme.secondary)
                }.foregroundStyle(BTheme.ink)
                ActivityBars(plan: plan, steps: steps).accessibilityHidden(true)
                Text("\(recorded.count) of 7 days recorded · Everyday goal reached on \(assessment.qualifyingDays) days")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                if !recorded.isEmpty {
                    Text("Average: \((recorded.reduce(0, +) / recorded.count).formatted()) steps per recorded day")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
            }
            PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let higher = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(higher.formatted()) steps") }
            Divider()
            ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                let day = WalkingCalendarDay(plan: plan, key: key, steps: steps[index], now: store.now)
                let canEdit = day.state != .upcoming && status != .voidedBeforeStart
                Button { selected = SelectedActivityDate(key: key) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: day.state.symbol).foregroundStyle(day.state.color).frame(width: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(PlanDisplay.shortDay(key, timezoneID: plan.timezoneID)).fontWeight(.medium)
                            Text(day.description).font(.subheadline).foregroundStyle(BTheme.secondary)
                        }
                        Spacer(minLength: 0)
                        if canEdit { Image(systemName: "chevron.right").font(.caption2).accessibilityHidden(true) }
                    }.foregroundStyle(BTheme.ink).frame(minHeight: 44, alignment: .leading)
                }.disabled(!canEdit)
                    .accessibilityLabel("\(PlanDisplay.fullDay(key, timezoneID: plan.timezoneID)), \(day.description)")
                    .accessibilityHint(canEdit ? "Opens your step record for this date" : "")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                    VStack(spacing: 8) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 5).fill(BTheme.background)
                            RoundedRectangle(cornerRadius: 5)
                                .fill((steps[index] ?? 0) >= plan.terms.baseGoalSteps ? BTheme.accent : BTheme.accentSoft)
                                .frame(height: steps[index] == nil ? 0 : max(3, CGFloat(steps[index] ?? 0) / CGFloat(maximum) * 100))
                            VStack {
                                Spacer(minLength: 0)
                                Rectangle().fill(BTheme.secondary.opacity(0.5)).frame(height: 1)
                                    .offset(y: -CGFloat(plan.terms.baseGoalSteps) / CGFloat(maximum) * 100)
                            }
                        }.frame(height: 100)
                        Text(Format.weekday(key, timezoneID: plan.timezoneID)).font(.caption2).foregroundStyle(BTheme.secondary)
                    }.frame(maxWidth: .infinity)
                }
            }
            Text("Line: everyday goal of \(plan.terms.baseGoalSteps.formatted()) steps")
                .font(.caption).foregroundStyle(BTheme.secondary)
        }
    }
}

enum WalkingDayState: String, CaseIterable {
    case noPlan, upcoming, missing, below, everyday, higher
    var title: String {
        switch self {
        case .noPlan: "No plan"
        case .upcoming: "Upcoming"
        case .missing: "Not recorded"
        case .below: "Below everyday goal"
        case .everyday: "Everyday goal reached"
        case .higher: "Higher goal reached"
        }
    }
    var symbol: String {
        switch self {
        case .noPlan: "minus"
        case .upcoming: "clock"
        case .missing: "circle.dashed"
        case .below: "circle"
        case .everyday: "checkmark.circle"
        case .higher: "checkmark.seal.fill"
        }
    }
    var color: Color { self == .everyday || self == .higher ? BTheme.accent : BTheme.secondary }
}

struct WalkingCalendarDay: Equatable {
    let key: String
    let planID: UUID
    let timezoneID: String
    let steps: Int?
    let state: WalkingDayState
    init(plan: WeeklyPlan, key: String, steps: Int?, now: Date) {
        self.key = key
        self.planID = plan.id
        self.timezoneID = plan.timezoneID
        self.steps = steps
        if plan.voidedAt != nil { state = .noPlan }
        else if key > WeeklyCalendar.dateKey(for: now, timezoneID: plan.timezoneID) { state = .upcoming }
        else if let steps {
            if let higher = plan.terms.stretchGoalSteps, steps >= higher { state = .higher }
            else if steps >= plan.terms.baseGoalSteps { state = .everyday }
            else { state = .below }
        } else { state = .missing }
    }
    var description: String { steps.map { "\($0.formatted()) steps · \(state.title)" } ?? state.title }
}

private struct WalkingMonthView: View {
    @Environment(AppStore.self) private var store
    @State private var selectedKey: String?

    private var days: [String: [WalkingCalendarDay]] {
        var result: [String: [WalkingCalendarDay]] = [:]
        for plan in store.plans.reversed() where plan.voidedAt == nil {
            let steps = store.effectiveSteps(for: plan)
            for (index, key) in plan.dateKeys.enumerated() {
                result[key, default: []].append(WalkingCalendarDay(plan: plan, key: key, steps: steps[index], now: store.now))
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your walking calendar").font(.headline)
            Text("Dates follow each plan’s saved time zone.").font(.caption).foregroundStyle(BTheme.secondary)
            WalkingNativeCalendar(days: days, initialDate: store.now, selectedKey: $selectedKey)
                .frame(minHeight: 350)
            if let selectedKey {
                BCard {
                    if let records = days[selectedKey] {
                        ForEach(records, id: \.planID) { day in
                            VStack(alignment: .leading, spacing: 12) {
                                Text(PlanDisplay.fullDay(selectedKey, timezoneID: day.timezoneID)).font(.headline)
                                Text(PlanDisplay.timezoneName(day.timezoneID)).font(.caption).foregroundStyle(BTheme.secondary)
                                Label(day.description, systemImage: day.state.symbol).foregroundStyle(day.state.color)
                                if let plan = store.plan(id: day.planID) {
                                    Text("Everyday goal: \(plan.terms.baseGoalSteps.formatted()) steps\(plan.terms.stretchGoalSteps.map { " · Higher goal: \($0.formatted()) steps" } ?? "")")
                                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                                }
                                NavigationLink("View this week's walking") { WalkingWeekDetailView(planID: day.planID) }.frame(minHeight: 44)
                            }
                        }
                    } else {
                        Text(PlanDisplay.fullDay(selectedKey, timezoneID: TimeZone.current.identifier)).font(.headline)
                        Text("No walking plan for this date.").foregroundStyle(BTheme.secondary)
                    }
                }
            } else {
                Text("Choose a date to see its steps and goals.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            DisclosureGroup("Calendar key") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(WalkingDayState.allCases, id: \.self) { state in
                        if state == .noPlan { Text("No marker: no plan").foregroundStyle(BTheme.secondary) }
                        else { Label(state.title, systemImage: state.symbol).foregroundStyle(state.color) }
                    }
                    if days.values.contains(where: { $0.count > 1 }) { Label("More than one plan date", systemImage: "square.stack") }
                    Text("A recorded zero is shown as 0 steps. It is different from a day with no record.").font(.caption).foregroundStyle(BTheme.secondary)
                }.font(.subheadline).padding(.top, 12)
            }
        }
    }
}

private struct WalkingNativeCalendar: UIViewRepresentable {
    let days: [String: [WalkingCalendarDay]]
    let initialDate: Date
    @Binding var selectedKey: String?

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView()
        view.calendar = Calendar(identifier: .gregorian)
        view.locale = .current
        view.timeZone = .current
        view.fontDesign = .rounded
        view.tintColor = UIColor(BTheme.accent)
        view.delegate = context.coordinator
        view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
        view.visibleDateComponents = view.calendar.dateComponents([.year, .month, .day], from: initialDate)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }
    func updateUIView(_ uiView: UICalendarView, context: Context) {
        let previous = context.coordinator.parent.days
        context.coordinator.parent = self
        if previous != days {
            let keys = Set(previous.keys).union(days.keys)
            uiView.reloadDecorations(forDateComponents: keys.compactMap(Self.components), animated: false)
        }
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UICalendarView, context: Context) -> CGSize? {
        let width = proposal.width ?? 335
        return uiView.systemLayoutSizeFitting(CGSize(width: width, height: 0), withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
    }
    static func key(_ components: DateComponents) -> String? {
        guard let year = components.year, let month = components.month, let day = components.day else { return nil }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }
    static func components(_ key: String) -> DateComponents? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return DateComponents(year: parts[0], month: parts[1], day: parts[2])
    }
    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {
        var parent: WalkingNativeCalendar
        init(_ parent: WalkingNativeCalendar) { self.parent = parent }
        func calendarView(_ calendarView: UICalendarView, decorationFor dateComponents: DateComponents) -> UICalendarView.Decoration? {
            guard let key = WalkingNativeCalendar.key(dateComponents), let records = parent.days[key], let day = records.first else { return nil }
            return .customView {
                let image = UIImageView(image: UIImage(systemName: records.count > 1 ? "square.stack" : day.state.symbol))
                image.tintColor = UIColor(day.state.color)
                image.isAccessibilityElement = true
                image.accessibilityLabel = records.map { "\($0.description), \(PlanDisplay.timezoneName($0.timezoneID))" }.joined(separator: ". ")
                return image
            }
        }
        func dateSelection(_ selection: UICalendarSelectionSingleDate, didSelectDate dateComponents: DateComponents?) {
            parent.selectedKey = dateComponents.flatMap(WalkingNativeCalendar.key)
            if let key = parent.selectedKey {
                UIAccessibility.post(notification: .announcement, argument: parent.days[key]?.map { "\($0.description), \(PlanDisplay.timezoneName($0.timezoneID))" }.joined(separator: ". ") ?? "No walking plan for this date")
            }
        }
    }
}
