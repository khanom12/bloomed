import SwiftUI

struct MoneyView: View {
    @Environment(AppStore.self) private var store
    @State private var createPlan = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !store.plans.isEmpty { Text("Your money, supporter matches, and donations.").foregroundStyle(BTheme.secondary) }
                if let plan = store.currentPlan {
                    NavigationLink { MoneyDetailView(planID: plan.id) } label: { CurrentMoneyCard(plan: plan) }.buttonStyle(.plain).accessibilityIdentifier("money.current-week")
                }
                if store.plans.isEmpty {
                    BEmptyState(title: "Know where your money stands", message: "See what you earn back from your weekly amount, any extra supporter match, and the donations you record outside Bloomed.", symbol: "banknote", actionTitle: store.draft == nil ? "Create your walking plan" : "Continue your walking plan", action: { createPlan = true })
                } else {
                    if store.plans.contains(where: { $0.voidedAt == nil && store.latestReviewedAssessment(for: $0) != nil }) { ReviewedTotalsCard() }
                    BSectionTitle(title: "Weekly money records")
                    ForEach(store.plans) { plan in
                        NavigationLink { MoneyDetailView(planID: plan.id) } label: {
                            BCard {
                                HStack {
                                    Text(Format.week(plan)).font(.headline).foregroundStyle(BTheme.ink)
                                    Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(BTheme.secondary)
                                }
                                BMoneyRow(title: "Your weekly amount", cents: plan.terms.commitmentCents)
                                BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.reconciliationRequired(for: plan))
                            }
                        }.buttonStyle(.plain)
                    }
                }
                BNotice(message: "You handle all money outside Bloomed. Amounts earned back are calculations; payments and donations appear only when you record them.")
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea())
            .navigationTitle("Money").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $createPlan) { PlanEditorView() }
    }
}

private struct CurrentMoneyCard: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    var body: some View {
        let result = store.assessment(for: plan)
        let status = store.lifecycle(for: plan)
        BCard {
            HStack(alignment: .top) {
                Text(status == .scheduled ? "Ready for your walking week" : "This week's money").font(.headline)
                Spacer()
                Image(systemName: "chevron.right").font(.caption).accessibilityHidden(true)
            }.foregroundStyle(BTheme.accent)
            Text(Format.week(plan)).font(.subheadline).foregroundStyle(BTheme.secondary)
            BStatusBadge(title: status.title, warning: status == .awaitingReview)
            BMoneyRow(title: "Your weekly amount", cents: plan.terms.commitmentCents, emphasized: true)
            if status == .scheduled {
                Text("Earn up to \(Format.money(plan.terms.commitmentCents)) of your own money back by reaching your walking goals. Your week starts \(PlanDisplay.shortDay(plan.startDateKey, timezoneID: plan.timezoneID)).")
                    .foregroundStyle(BTheme.secondary)
                if let support = store.support(for: plan) {
                    Text("\(support.alias) can add up to \(Format.money(min(support.capCents, plan.terms.commitmentCents))) this week, matching what you earn back dollar for dollar.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                Text("View the plan and money details").font(.subheadline.weight(.semibold)).foregroundStyle(BTheme.accent)
            } else {
                BMoneyRow(title: status == .reviewed ? "Earned back · reviewed" : "Earned back so far · estimate", cents: result.personalReturnCents)
                if result.consistencyReturnCents > 0 {
                    BMoneyRow(title: "Includes consistency amount", cents: result.consistencyReturnCents)
                }
                if status == .active { WalkingOpportunityRows(plan: plan) }
                if store.support(for: plan) != nil {
                    BMoneyRow(title: status == .reviewed ? "Supporter match · reviewed" : "Supporter match · estimate", cents: result.supporterRewardCents)
                }
                if status == .reviewed { BMoneyRow(title: "For charity · reviewed", cents: result.charityAllocationCents) }
                Text(status == .reviewed ? "These are reviewed calculations. Open this week to record money kept, received, or donated." : "Based on your recorded steps. Review the week before recording payments or donations.")
                    .font(.caption).foregroundStyle(BTheme.secondary)
            }
        }
    }
}

private struct WalkingOpportunityRows: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    var body: some View {
        if let closed = try? WeeklyCalendar.closedDayCount(for: plan, now: store.now),
           let forecast = try? RewardEngine.forecast(terms: plan.terms, dailySteps: store.effectiveSteps(for: plan), closedDayCount: closed) {
            BMoneyRow(title: "Still available · estimate", cents: forecast.remainingWalkingOpportunityCents)
            let notEarned = plan.terms.commitmentCents - forecast.maximumAttainableCents
            if notEarned > 0 { BMoneyRow(title: "Not earned on ended days", cents: notEarned) }
            Text("Based on days that have ended. Missing entries and corrections can change these amounts.")
                .font(.caption).foregroundStyle(BTheme.secondary)
        }
    }
}

private struct ReviewedTotalsCard: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        let eligible = store.plans.filter { $0.voidedAt == nil }
        let reviews = eligible.compactMap { store.latestReviewedAssessment(for: $0)?.result }
        BCard {
            BSectionTitle(title: "All reviewed weeks")
            Text("\(reviews.count) reviewed weeks · CAD").font(.subheadline).foregroundStyle(BTheme.secondary)
            BMoneyRow(title: "Your money earned back", cents: reviews.reduce(0) { $0 + $1.personalReturnCents })
            BMoneyRow(title: "Extra supporter matches", cents: reviews.reduce(0) { $0 + $1.supporterRewardCents })
            BMoneyRow(title: "For charity", cents: reviews.reduce(0) { $0 + $1.charityAllocationCents })
            Text("Calculated amounts, not payment records. Only reviewed weeks count; a week being corrected keeps its last reviewed amounts until you review it again.")
                .font(.caption).foregroundStyle(BTheme.secondary)
        }
    }
}

struct MoneyDetailView: View {
    @Environment(AppStore.self) private var store
    let planID: UUID
    @State private var sheet: MoneySheet?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let plan = store.plan(id: planID) {
                    let status = store.lifecycle(for: plan)
                    Text(Format.week(plan)).font(.title2.weight(.semibold)).foregroundStyle(BTheme.ink)
                    BStatusBadge(title: status.title, warning: status == .awaitingReview)
                    if status == .voidedBeforeStart {
                        BNotice(message: "This week was voided before it started. No return, matching reward, or charity allocation was assessed.")
                    } else {
                        ForEach(FinancialBucket.allCases.filter { $0 != .supporterReward || store.support(for: plan) != nil || store.reconciliation(for: plan, bucket: .supporterReward).recordedCents > 0 }) { bucket in
                            FinancialCategoryCard(plan: plan, bucket: bucket, record: { sheet = .settlement(bucket) })
                        }
                        if let support = store.support(for: plan) {
                            BCard {
                                BSectionTitle(title: "Supporter agreement")
                                BMoneyRow(title: "Agreed weekly limit", cents: support.capCents)
                                BMoneyRow(title: "Stays with the supporter", cents: store.assessment(for: plan).unusedSupporterAllowanceCents)
                                Text("This plan can earn a match of up to \(Format.money(min(support.capCents, plan.terms.commitmentCents))). Unused allowance stays with \(support.alias); it does not go to charity.")
                                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                            }
                        }
                        if status == .awaitingReview {
                            BPrimaryButton(title: "Review this week", action: { sheet = .review })
                        }
                        if store.reconciliationRequired(for: plan) {
                            BNotice(message: "Your outside records differ from the walking calculation. Check the records and arrange any changes outside Bloomed.", warning: true)
                        }
                        BSectionTitle(title: "Money recorded outside Bloomed")
                        if store.settlements(for: plan).isEmpty {
                            Text("No payments or donations recorded. This does not tell us whether money has changed hands.").foregroundStyle(BTheme.secondary)
                        }
                        ForEach(store.settlements(for: plan)) { record in
                            Button { sheet = .voidRecord(record.id) } label: {
                                BCard {
                                    BMoneyRow(title: moneyCategoryTitle(record.bucket), cents: record.amountCents)
                                    Text("\(Format.day(record.effectiveDateKey, timezoneID: plan.timezoneID)) · \(record.voidedAt == nil ? "Recorded by you" : "Record cancelled · original saved")")
                                        .font(.caption).foregroundStyle(BTheme.secondary)
                                    if !record.note.isEmpty { Text(record.note).font(.subheadline).foregroundStyle(BTheme.secondary) }
                                    if !record.voidReason.isEmpty { Text(record.voidReason).font(.caption).foregroundStyle(BTheme.secondary) }
                                }
                            }.buttonStyle(.plain).disabled(record.voidedAt != nil)
                        }
                        ExceptionHistory(plan: plan, addNote: { sheet = .exception(nil) }, resolve: { sheet = .exception($0) })
                        NavigationLink("View calculations and change history") { AuditHistoryView(planID: plan.id) }
                            .frame(minHeight: 44)
                    }
                }
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea()).navigationTitle("Weekly money").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $sheet) { item in
                switch item {
                case .settlement(let bucket): SettlementEntryView(planID: planID, bucket: bucket)
                case .review: WeeklyReviewView(planID: planID)
                case .voidRecord(let id): VoidSettlementView(recordID: id)
                case .exception(let id): ExceptionNoteView(planID: planID, resolvesID: id)
                }
            }
    }
}

private enum MoneySheet: Identifiable {
    case settlement(FinancialBucket), review, voidRecord(UUID), exception(UUID?)
    var id: String {
        switch self {
        case .settlement(let value): value.rawValue
        case .review: "review"
        case .voidRecord(let id): "void-\(id)"
        case .exception(let id): "exception-\(id?.uuidString ?? "new")"
        }
    }
}

private struct FinancialCategoryCard: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    let bucket: FinancialBucket
    let record: () -> Void
    var body: some View {
        let status = store.lifecycle(for: plan)
        let summary = store.reconciliation(for: plan, bucket: bucket)
        let result = store.assessment(for: plan)
        BCard {
            BSectionTitle(title: moneyCategoryTitle(bucket))
            if status == .scheduled {
                if bucket == .personalReturn {
                    BMoneyRow(title: "Available to earn back", cents: plan.terms.commitmentCents, emphasized: true)
                    Text("Reach \(plan.terms.highestGoalSteps.formatted()) steps on all 7 days to earn your full weekly amount back.").foregroundStyle(BTheme.secondary)
                } else if bucket == .supporterReward, let support = store.support(for: plan) {
                    Text("\(support.alias) adds $1 for each $1 you earn back, up to \(Format.money(support.capCents)) for the week.").foregroundStyle(BTheme.secondary)
                } else {
                    Text("Any part of your own money you don’t earn back is for charity. The amount is set after you review the week.").foregroundStyle(BTheme.secondary)
                }
            } else if status == .reviewed {
                BMoneyRow(title: "Reviewed amount", cents: summary.targetCents, emphasized: true)
                BMoneyRow(title: "Recorded by you", cents: summary.recordedCents)
                if summary.outstandingCents > 0 {
                    BMoneyRow(title: "No outside record for", cents: summary.outstandingCents)
                    BPrimaryButton(title: settlementTitle(bucket, handling: plan.terms.handling), action: record)
                }
                if summary.excessCents > 0 {
                    BNotice(message: "Your outside records exceed the revised amount by \(Format.money(summary.excessCents)). Check what happened and arrange any changes outside Bloomed.", warning: true)
                }
            } else if status == .active && bucket == .charityAllocation {
                Text("Review your week to confirm how much of your own money goes to charity. You still have time to earn more back.").foregroundStyle(BTheme.secondary)
            } else {
                BMoneyRow(title: "Estimate · not yet reviewed", cents: result.amount(for: bucket), emphasized: true)
                if bucket == .personalReturn && status == .active { WalkingOpportunityRows(plan: plan) }
                if summary.recordedCents > 0 { BMoneyRow(title: "Previously recorded by you", cents: summary.recordedCents) }
                Text("Review the week before recording money kept, received, or donated.").font(.caption).foregroundStyle(BTheme.secondary)
            }
            if bucket == .charityAllocation {
                let destination = store.charityDestination(for: plan)
                Text(destination.isEmpty ? "Charity not chosen yet. Choose one during weekly review if there is money to donate." : "Charity: \(destination). You arrange the donation outside Bloomed.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
    }
}

private func moneyCategoryTitle(_ bucket: FinancialBucket) -> String {
    switch bucket {
    case .personalReturn: "Your money earned back"
    case .supporterReward: "Extra supporter match"
    case .charityAllocation: "For charity"
    }
}

func settlementTitle(_ bucket: FinancialBucket, handling: MoneyHandling) -> String {
    switch bucket {
    case .personalReturn: handling == .participantRetains ? "Record money kept" : "Record money returned"
    case .supporterReward: "Record supporter money received"
    case .charityAllocation: "Record a donation"
    }
}
