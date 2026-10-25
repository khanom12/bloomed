import SwiftUI

struct MyPlanView: View {
    @Environment(AppStore.self) private var store
    @State private var createPlan = false

    private var displayedPlans: [WeeklyPlan] {
        let relevant = store.plans.filter { $0.voidedAt == nil }.sorted { $0.startDateKey > $1.startDateKey }
        let currentIDs = relevant.filter { [.active, .scheduled, .awaitingReview].contains(store.lifecycle(for: $0)) }.map(\.id)
        if currentIDs.isEmpty { return Array(relevant.prefix(1)) }
        return relevant.filter { currentIDs.contains($0.id) }.sorted {
            let firstStatus = store.lifecycle(for: $0)
            let secondStatus = store.lifecycle(for: $1)
            let firstPriority = firstStatus == .active ? 0 : firstStatus == .scheduled ? 1 : 2
            let secondPriority = secondStatus == .active ? 0 : secondStatus == .scheduled ? 1 : 2
            return firstPriority == secondPriority ? $0.startDateKey > $1.startDateKey : firstPriority < secondPriority
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Your goals, dates, and weekly amount.").foregroundStyle(BTheme.secondary)
                if displayedPlans.isEmpty {
                    BEmptyState(title: "Make your first walking plan", message: "Choose a daily step goal and an amount of your own money for seven days. Earn it back by walking; any part you don’t earn goes to charity.", symbol: "figure.walk", actionTitle: store.draft == nil ? "Create your walking plan" : "Continue your walking plan", action: { createPlan = true })
                } else {
                    ForEach(displayedPlans) { plan in
                        NavigationLink {
                            PlanDetailView(planID: plan.id)
                        } label: {
                            BCard {
                                HStack {
                                    BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.lifecycle(for: plan) == .awaitingReview)
                                    Spacer()
                                    Image(systemName: "chevron.right").accessibilityHidden(true).foregroundStyle(BTheme.secondary)
                                }
                                Text(PlanDisplay.week(plan)).font(.title2.weight(.semibold)).foregroundStyle(BTheme.ink)
                                PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
                                if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(stretch.formatted()) steps") }
                                BMoneyRow(title: "Your weekly amount", cents: plan.terms.commitmentCents)
                                if let support = store.support(for: plan), support.applies {
                                    Label("\(support.alias) · match up to \(Money.format(min(support.capCents, plan.terms.commitmentCents)))", systemImage: "person.2")
                                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                                }
                                Text("View plan details").font(.subheadline.weight(.semibold)).foregroundStyle(BTheme.accent)
                            }
                        }.buttonStyle(.plain)
                    }
                    Button { createPlan = true } label: {
                        Label(store.draft == nil ? "Prepare another week" : "Continue your walking plan", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.bordered).tint(BTheme.accent)
                    if store.draft != nil { Text("Your saved draft takes effect only after you confirm the week.").font(.subheadline).foregroundStyle(BTheme.secondary) }
                }
                PlanNotice(text: "You record your steps and handle all money and donations outside Bloomed. The app does not collect or transfer money.")
            }.bloomedScreen()
        }
        .background(BTheme.background)
        .navigationTitle("My plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createPlan) { PlanEditorView() }
    }
}

private enum PlanDetailSheet: String, Identifiable {
    case editor, support, review, share, invitation
    var id: String { rawValue }
}

struct PlanDetailView: View {
    let planID: UUID
    @Environment(AppStore.self) private var store
    @State private var sheet: PlanDetailSheet?
    @State private var error: String?
    @State private var showVoid = false
    @State private var voidReason = ""

    private var plan: WeeklyPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let plan {
                    agreement(plan)
                } else {
                    BEmptyState(title: "Plan unavailable", message: "This plan is no longer in the local records.", symbol: "calendar.badge.exclamationmark")
                }
            }.bloomedScreen()
        }
        .background(BTheme.background)
        .navigationTitle("Weekly plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { destination in
            if let plan {
                switch destination {
                case .editor: PlanEditorView(sourcePlan: plan)
                case .support: SupportAgreementView(planID: plan.id, recordAgreement: store.state.effectiveSupport(for: plan.id) == nil)
                case .review: WeeklyReviewView(planID: plan.id)
                case .share: ShareSnapshotView(planID: plan.id)
                case .invitation: ShareSnapshotView(planID: plan.id, initialKind: .invitation)
                }
            }
        }
        .alert("Void this upcoming week?", isPresented: $showVoid) {
            TextField("Reason", text: $voidReason)
            Button("Keep plan", role: .cancel) { }
            Button("Void scheduled week", role: .destructive) { voidPlan() }
        } message: {
            Text("The original agreement will stay in history. No return, reward, or charity amount is assessed. Notify anyone involved outside Bloomed.")
        }
    }

    @ViewBuilder private func agreement(_ plan: WeeklyPlan) -> some View {
        let status = store.lifecycle(for: plan)
        Text(PlanDisplay.week(plan)).font(.title2.weight(.semibold)).foregroundStyle(BTheme.ink)
        BStatusBadge(title: status.title, warning: status == .awaitingReview)
        Text("\(PlanDisplay.timezoneName(plan.timezoneID)) · dates stay fixed for this plan")
            .font(.subheadline).foregroundStyle(BTheme.secondary)
        if status == .voidedBeforeStart {
            PlanNotice(text: "This week was voided before it started. Its original agreement is preserved, and no earnings or charity allocation apply.")
        }
        BCard {
            Label("Daily walking", systemImage: "figure.walk").font(.headline)
            PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(stretch.formatted()) steps") }
            if plan.terms.consistencyEnabled {
                Divider()
                PlanValueRow(title: "Consistency amount", value: Money.format(plan.consistencyReserveCents))
                Text("Reach \(plan.terms.baseGoalSteps.formatted()) steps on any 5 of the 7 days to earn this part of your weekly amount back. The days do not need to be consecutive.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            Text("To earn your full \(Format.money(plan.terms.commitmentCents)) back, reach \(plan.terms.highestGoalSteps.formatted()) steps on all 7 days.").font(.subheadline).foregroundStyle(BTheme.secondary)
        }
        BCard {
            Text("Your weekly amount · CAD").font(.headline)
            BMoneyRow(title: "Your own money", cents: plan.terms.commitmentCents, emphasized: true)
            PlanValueRow(title: "How you handle it", value: plan.terms.handling.title)
            if !plan.terms.handlerDescription.isEmpty { Text(plan.terms.handlerDescription).font(.subheadline).foregroundStyle(BTheme.secondary) }
            PlanValueRow(title: "Charity destination", value: store.charityDestination(for: plan).isEmpty ? "Choose later" : store.charityDestination(for: plan))
            if store.charityDestination(for: plan).isEmpty {
                Text("Choose a destination during weekly review if there is money to donate.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            Text("The part of your own money you don’t earn back goes to this charity after you review the week. You arrange the donation yourself.").font(.subheadline).foregroundStyle(BTheme.secondary)
        }
        BCard {
            DisclosureGroup("What you can earn back each day") {
                VStack(spacing: 16) {
                    ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                        VStack(alignment: .leading, spacing: 5) {
                            PlanValueRow(title: PlanDisplay.shortDay(key, timezoneID: plan.timezoneID), value: Money.format(plan.dailyMaximumCents[index]))
                            if plan.terms.stretchGoalSteps != nil {
                                let assessed = store.assessment(for: plan)
                                Text("\(plan.terms.baseGoalSteps.formatted()) steps: \(Money.format(assessed.dailyBaseOnlyCents[index])) back · \(plan.terms.highestGoalSteps.formatted()) steps: \(Money.format(plan.dailyMaximumCents[index])) back")
                                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                            }
                        }
                    }
                }.padding(.top, 16)
            }
        }
        if status != .voidedBeforeStart {
            supportCard(plan)
            VStack(spacing: 12) {
                if status == .awaitingReview {
                    BPrimaryButton(title: "Review this week") { sheet = .review }
                } else if status == .reviewed {
                    Button("View reviewed results") { sheet = .review }.buttonStyle(.bordered).frame(minHeight: 44)
                    NavigationLink("View money and outside records") { MoneyDetailView(planID: plan.id) }.frame(minHeight: 44)
                }
                Button { sheet = .share } label: { Label("Share this week", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.bordered).tint(BTheme.accent)
                BPrimaryButton(title: status == .active || status == .scheduled ? "Adjust next week" : "Repeat this plan") { sheet = .editor }
            }
            Text("Changes to goals or amounts apply to a new week. This plan keeps the terms you confirmed.").font(.subheadline).foregroundStyle(BTheme.secondary)
            if status == .scheduled {
                Menu {
                    Button("Void scheduled week", role: .destructive) { showVoid = true }
                } label: {
                    Label("Other actions", systemImage: "ellipsis.circle").frame(minHeight: 44)
                }
            }
        }
        if let error { PlanNotice(text: error, warning: true) }
    }

    private func supportCard(_ plan: WeeklyPlan) -> some View {
        BCard {
            Label("Optional support", systemImage: "person.2").font(.headline)
            if let support = store.state.effectiveSupport(for: plan.id) {
                Text(support.alias).font(.title3.weight(.semibold))
                PlanValueRow(title: support.applies ? "Agreed weekly limit" : "Previously recorded limit", value: Money.format(support.capCents))
                BStatusBadge(title: "Agreement recorded by you")
                Text(support.applies ? "For every $1 you earn back, \(support.alias) adds $1, up to the agreed weekly limit. Payment is arranged outside Bloomed." : "This earlier agreement does not apply to the week. Its details and corrections remain in history.").font(.subheadline).foregroundStyle(BTheme.secondary)
                if support.applies && support.capCents > plan.terms.commitmentCents {
                    Text("With your \(Money.format(plan.terms.commitmentCents)) commitment, the most this plan can earn in extra support is \(Money.format(min(plan.terms.commitmentCents, support.capCents))). A higher limit does not increase the 1:1 rate.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                Button("View recorded agreement") { sheet = .support }.frame(minHeight: 44)
            } else {
                Text("Someone you trust can add $1 for each $1 you earn back, up to a weekly amount you agree together.").foregroundStyle(BTheme.secondary)
                if [.active, .scheduled].contains(store.lifecycle(for: plan)) {
                    Button("Prepare an invitation") { sheet = .invitation }.frame(minHeight: 44)
                    Button("Record an agreement already made") { sheet = .support }.frame(minHeight: 44)
                } else {
                    Text("No matching agreement applied to this week.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
        }
    }

    private func voidPlan() {
        do { try store.voidScheduled(planID: planID, reason: voidReason) }
        catch { self.error = PlanDisplay.text(error) }
    }
}
