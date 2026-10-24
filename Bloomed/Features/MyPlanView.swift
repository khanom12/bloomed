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
                BScreenHeader(eyebrow: "YOUR AGREEMENT", title: "My plan", subtitle: "A clear commitment, one week at a time.")
                if displayedPlans.isEmpty {
                    BEmptyState(title: "A routine that fits your life.", message: "Choose a daily walking goal and a personal commitment. Support is always optional.", symbol: "figure.walk", actionTitle: "Create your walking plan", action: { createPlan = true })
                } else {
                    ForEach(displayedPlans) { plan in
                        NavigationLink {
                            PlanDetailView(planID: plan.id)
                        } label: {
                            BCard {
                                HStack {
                                    BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.lifecycle(for: plan) == .awaitingReview)
                                    Spacer()
                                    Image(systemName: "arrow.up.right").foregroundStyle(BTheme.secondary)
                                }
                                Text(PlanDisplay.week(plan)).font(.title2.weight(.semibold)).foregroundStyle(BTheme.ink)
                                PlanValueRow(title: plan.terms.stretchGoalSteps == nil ? "Daily goal" : "Base goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
                                if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Stretch goal", value: "\(stretch.formatted()) steps") }
                                BMoneyRow(title: "Personal commitment", cents: plan.terms.commitmentCents)
                                if let support = store.support(for: plan), support.applies {
                                    Label("\(support.alias) · match up to \(Money.format(support.capCents))", systemImage: "person.2")
                                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                                }
                                Text("View this week's agreement").font(.subheadline.weight(.semibold)).foregroundStyle(BTheme.accent)
                            }
                        }.buttonStyle(.plain)
                    }
                    Button { createPlan = true } label: {
                        Label(store.draft == nil ? "Prepare another week" : "Continue saved draft", systemImage: "square.and.pencil")
                            .frame(maxWidth: .infinity, minHeight: 52)
                    }.buttonStyle(.bordered).tint(BTheme.accent)
                    if store.draft != nil { Text("Your draft is not a financial commitment until you confirm it.").font(.subheadline).foregroundStyle(BTheme.secondary) }
                }
                PlanNotice(text: "Bloomed records your agreement and walking. Money, donations, and proof are handled outside the app.")
            }.bloomedScreen()
        }
        .background(BTheme.background)
        .navigationTitle("My plan")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $createPlan) { PlanEditorView() }
    }
}

private enum PlanDetailSheet: String, Identifiable {
    case editor, support, review, share
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
        .navigationTitle("Weekly agreement")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $sheet) { destination in
            if let plan {
                switch destination {
                case .editor: PlanEditorView(sourcePlan: plan)
                case .support: SupportAgreementView(planID: plan.id)
                case .review: WeeklyReviewView(planID: plan.id)
                case .share: ShareSnapshotView(planID: plan.id)
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
        BScreenHeader(eyebrow: status.title, title: PlanDisplay.week(plan), subtitle: plan.timezoneID.replacingOccurrences(of: "_", with: " "))
        if status == .voidedBeforeStart {
            PlanNotice(text: "This week was voided before it started. Its original agreement is preserved, and no earnings or charity allocation apply.")
        }
        BCard {
            Label("Walking targets", systemImage: "figure.walk").font(.headline)
            PlanValueRow(title: plan.terms.stretchGoalSteps == nil ? "Daily goal" : "Base goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Stretch goal", value: "\(stretch.formatted()) steps") }
            if plan.terms.consistencyEnabled {
                Divider()
                PlanValueRow(title: "Consistency return", value: Money.format(plan.consistencyReserveCents))
                Text("Reach the base goal on any 5 of the 7 dates. They do not need to be consecutive.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            Text("Full personal return requires the highest selected goal on all 7 days.").font(.subheadline).foregroundStyle(BTheme.secondary)
        }
        BCard {
            Text("Your personal commitment · CAD").font(.headline)
            BMoneyRow(title: "Seven-day amount", cents: plan.terms.commitmentCents, emphasized: true)
            PlanValueRow(title: "Outside handling", value: plan.terms.handling.title)
            if !plan.terms.handlerDescription.isEmpty { Text(plan.terms.handlerDescription).font(.subheadline).foregroundStyle(BTheme.secondary) }
            PlanValueRow(title: "Charity destination", value: plan.terms.charity)
            Text("Only unearned personal money is allocated to charity. Unused supporter allowance stays with the supporter.").font(.subheadline).foregroundStyle(BTheme.secondary)
        }
        BCard {
            DisclosureGroup("Exact daily return schedule") {
                VStack(spacing: 16) {
                    ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                        VStack(alignment: .leading, spacing: 5) {
                            PlanValueRow(title: PlanDisplay.shortDay(key, timezoneID: plan.timezoneID), value: Money.format(plan.dailyMaximumCents[index]))
                            if plan.terms.stretchGoalSteps != nil {
                                let assessed = store.assessment(for: plan)
                                Text("Base-only return: \(Money.format(assessed.dailyBaseOnlyCents[index]))")
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
                    NavigationLink("View money and external settlement") { MoneyDetailView(planID: plan.id) }.frame(minHeight: 44)
                }
                Button { sheet = .share } label: { Label("Share this week", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48) }
                    .buttonStyle(.bordered).tint(BTheme.accent)
                BPrimaryButton(title: status == .active || status == .scheduled ? "Adjust next week" : "Repeat this plan") { sheet = .editor }
            }
            PlanNotice(text: "Changes apply to a new week. This agreement keeps its original dates, goals, and return rules.")
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
                PlanValueRow(title: support.applies ? "1:1 matching cap" : "Previously recorded cap", value: Money.format(support.capCents))
                BStatusBadge(title: "Agreement recorded by you")
                Text(support.applies ? "Matches your total personal return, including consistency. This record does not verify available funds or a payment." : "This previously recorded agreement does not apply. Its details and corrections remain in history.").font(.subheadline).foregroundStyle(BTheme.secondary)
                Button("View recorded agreement") { sheet = .support }.frame(minHeight: 44)
            } else {
                Text("Someone you trust can match what you earn back, up to an agreed cap.").foregroundStyle(BTheme.secondary)
                if [.active, .scheduled].contains(store.lifecycle(for: plan)) {
                    Button("Invite or record a supporter") { sheet = .support }.frame(minHeight: 44)
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
