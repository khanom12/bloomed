import SwiftUI

struct MoneyView: View {
    @Environment(AppStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                BScreenHeader(eyebrow: "Your commitments", title: "Every amount, clear.", subtitle: "Your money back. Their support. All kept distinct.")
                if let plan = store.currentPlan {
                    NavigationLink { MoneyDetailView(planID: plan.id) } label: { CurrentMoneyCard(plan: plan) }.buttonStyle(.plain)
                }
                if store.plans.isEmpty {
                    BEmptyState(title: "A clear record from the start.", message: "Once you've made a walking plan, see your commitment, calculated returns, and any external settlements here.", symbol: "banknote")
                } else {
                    ReviewedTotalsCard()
                    BSectionTitle(title: "Weekly money records")
                    ForEach(store.plans) { plan in
                        NavigationLink { MoneyDetailView(planID: plan.id) } label: {
                            BCard {
                                HStack {
                                    Text(Format.week(plan)).font(.headline).foregroundStyle(BTheme.ink)
                                    Spacer(); Image(systemName: "chevron.right").font(.caption).foregroundStyle(BTheme.secondary)
                                }
                                BMoneyRow(title: "Personal commitment", cents: plan.terms.commitmentCents)
                                BStatusBadge(title: store.lifecycle(for: plan).title, warning: store.reconciliationRequired(for: plan))
                            }
                        }.buttonStyle(.plain)
                    }
                }
                BNotice(message: "Bloomed does not hold or transfer money. These are calculations and your records of arrangements outside the app.")
            }.bloomedScreen()
        }.background(BTheme.background.ignoresSafeArea())
            .navigationTitle("Money").navigationBarTitleDisplayMode(.inline)
    }
}

private struct CurrentMoneyCard: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    var body: some View {
        let result = store.assessment(for: plan)
        let status = store.lifecycle(for: plan)
        BCard {
            HStack { Text("This week's commitment").font(.headline); Spacer(); Image(systemName: "arrow.up.right") }
                .foregroundStyle(BTheme.accent)
            Text(Format.money(plan.terms.commitmentCents)).font(.largeTitle.weight(.bold)).monospacedDigit().foregroundStyle(BTheme.ink)
            BMoneyRow(title: "Your money earned back", cents: result.personalReturnCents)
            if result.consistencyReturnCents > 0 {
                BMoneyRow(title: "Consistency · included above", cents: result.consistencyReturnCents)
            }
            if status == .active || status == .scheduled {
                if let closed = try? WeeklyCalendar.closedDayCount(for: plan, now: store.now),
                   let forecast = try? RewardEngine.forecast(terms: plan.terms, dailySteps: store.effectiveSteps(for: plan), closedDayCount: closed) {
                    BMoneyRow(title: "Remaining walking opportunity", cents: forecast.remainingWalkingOpportunityCents)
                    BMoneyRow(title: "Unearned under completed-day records", cents: plan.terms.commitmentCents - forecast.maximumAttainableCents)
                    Text("Based on completed days as currently recorded; corrections may change this.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
            }
            if store.support(for: plan) != nil { BMoneyRow(title: "Additional supporter reward", cents: result.supporterRewardCents) }
            if status == .reviewed { BMoneyRow(title: "Charity allocation", cents: result.charityAllocationCents) }
            Text(status == .reviewed ? "Reviewed calculation · tap for external records" : "Provisional calculation · charity allocation awaits review")
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
            BSectionTitle(title: "Reviewed history")
            Text("\(reviews.count) reviewed weeks · CAD").font(.subheadline).foregroundStyle(BTheme.secondary)
            BMoneyRow(title: "Personal returns", cents: reviews.reduce(0) { $0 + $1.personalReturnCents })
            BMoneyRow(title: "Supporter rewards", cents: reviews.reduce(0) { $0 + $1.supporterRewardCents })
            BMoneyRow(title: "Charity allocations", cents: reviews.reduce(0) { $0 + $1.charityAllocationCents })
            Text("Unreviewed estimates aren't included. A pending correction retains its last reviewed amounts here.")
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
                    BScreenHeader(eyebrow: "Weekly money record", title: "The whole picture.", subtitle: Format.week(plan))
                    BStatusBadge(title: status.title, warning: status == .awaitingReview)
                    if status == .voidedBeforeStart {
                        BNotice(message: "This week was voided before it started. No return, matching reward, or charity allocation was assessed.")
                    } else {
                        ForEach(FinancialBucket.allCases.filter { $0 != .supporterReward || store.support(for: plan) != nil || store.reconciliation(for: plan, bucket: .supporterReward).recordedCents > 0 }) { bucket in
                            FinancialCategoryCard(plan: plan, bucket: bucket, record: { sheet = .settlement(bucket) })
                        }
                        if let support = store.support(for: plan) {
                            BCard {
                                BSectionTitle(title: "Supporter's allowance")
                                BMoneyRow(title: "Agreed weekly cap", cents: support.capCents)
                                BMoneyRow(title: "Unused allowance", cents: store.assessment(for: plan).unusedSupporterAllowanceCents)
                                Text("The unused amount stays with, or returns to, \(support.alias). It is never allocated to charity.")
                                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                            }
                        }
                        if status == .awaitingReview {
                            BPrimaryButton(title: "Review this week's calculation", action: { sheet = .review })
                        }
                        if store.reconciliationRequired(for: plan) {
                            BNotice(message: "Review external settlement. Recorded outside payments or arrangements differ from the calculation. Nothing is automatically reversed or recovered.", warning: true)
                        }
                        BSectionTitle(title: "External records")
                        if store.settlements(for: plan).isEmpty {
                            Text("No outside settlements recorded yet.").foregroundStyle(BTheme.secondary)
                        }
                        ForEach(store.settlements(for: plan)) { record in
                            Button { sheet = .voidRecord(record.id) } label: {
                                BCard {
                                    BMoneyRow(title: record.bucket.title, cents: record.amountCents)
                                    Text("\(Format.day(record.effectiveDateKey, timezoneID: plan.timezoneID)) · \(record.voidedAt == nil ? "Recorded by you" : "Voided — original retained")")
                                        .font(.caption).foregroundStyle(BTheme.secondary)
                                    if !record.note.isEmpty { Text(record.note).font(.subheadline).foregroundStyle(BTheme.secondary) }
                                    if !record.voidReason.isEmpty { Text(record.voidReason).font(.caption).foregroundStyle(BTheme.secondary) }
                                }
                            }.buttonStyle(.plain).disabled(record.voidedAt != nil)
                        }
                        ExceptionHistory(plan: plan, addNote: { sheet = .exception(nil) }, resolve: { sheet = .exception($0) })
                        NavigationLink("View assessment and audit history") { AuditHistoryView(planID: plan.id) }
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
            BSectionTitle(title: bucket.title)
            if status == .reviewed {
                BMoneyRow(title: "Reviewed calculation", cents: summary.targetCents, emphasized: true)
                BMoneyRow(title: "Recorded externally", cents: summary.recordedCents)
                BMoneyRow(title: "Outstanding", cents: summary.outstandingCents)
                if summary.excessCents > 0 {
                    BNotice(message: "\(Format.money(summary.excessCents)) more was recorded than the revised calculation. Resolve this outside Bloomed.", warning: true)
                }
                if summary.outstandingCents > 0 { BPrimaryButton(title: settlementTitle(bucket, handling: plan.terms.handling), action: record) }
            } else if (status == .active || status == .scheduled) && bucket == .charityAllocation {
                Text("The allocation is determined after your weekly review. Keep working toward the walking opportunity still available this week.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
            } else {
                BMoneyRow(title: status == .awaitingReview ? "Awaiting review · estimate" : "Provisional calculation", cents: result.amount(for: bucket))
                if bucket == .personalReturn && (status == .active || status == .scheduled),
                   let closed = try? WeeklyCalendar.closedDayCount(for: plan, now: store.now),
                   let forecast = try? RewardEngine.forecast(terms: plan.terms, dailySteps: store.effectiveSteps(for: plan), closedDayCount: closed) {
                    BMoneyRow(title: "Remaining walking opportunity", cents: forecast.remainingWalkingOpportunityCents)
                    BMoneyRow(title: "Unearned under completed-day records", cents: plan.terms.commitmentCents - forecast.maximumAttainableCents)
                    Text("Based on completed days as currently recorded; corrections may change this.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
                if summary.recordedCents > 0 { BMoneyRow(title: "Previously recorded externally", cents: summary.recordedCents) }
                Text("Confirm the latest weekly review before recording settlements.").font(.caption).foregroundStyle(BTheme.secondary)
            }
            if bucket == .charityAllocation {
                Text("Destination: \(plan.terms.charity). Only your personal commitment contributes to this allocation.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
    }
}

func settlementTitle(_ bucket: FinancialBucket, handling: MoneyHandling) -> String {
    switch bucket {
    case .personalReturn: handling == .participantRetains ? "Record return retained" : "Record return received"
    case .supporterReward: "Record supporter payment received"
    case .charityAllocation: "Record donation made"
    }
}
