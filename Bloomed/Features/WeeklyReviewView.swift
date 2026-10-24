import SwiftUI

private struct ReviewStepSelection: Identifiable {
    let planID: UUID
    let dateKey: String
    var id: String { dateKey }
}

struct WeeklyReviewView: View {
    let planID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var missingAcknowledged = false
    @State private var error: String?
    @State private var confirming = false
    @State private var selectedDay: ReviewStepSelection?
    @State private var share = false
    @State private var prepareNext = false
    @State private var progressionDismissed = false

    private var plan: WeeklyPlan? { store.plans.first { $0.id == planID } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if let plan {
                        if store.lifecycle(for: plan) == .voidedBeforeStart {
                            BEmptyState(title: "This week was voided before starting", message: "The original agreement stays in history. There is no assessed personal return, supporter reward, or charity allocation.", symbol: "calendar.badge.minus")
                        } else { review(plan) }
                    }
                    else { BEmptyState(title: "Week unavailable", message: "This week's records could not be found.") }
                }.bloomedScreen()
            }
            .background(BTheme.background)
            .navigationTitle("Weekly review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedDay) { selection in StepEntryView(planID: selection.planID, dateKey: selection.dateKey) }
            .sheet(isPresented: $share) { ShareSnapshotView(planID: planID) }
            .sheet(isPresented: $prepareNext) { PlanEditorView(sourcePlan: plan) }
        }
    }

    @ViewBuilder private func review(_ plan: WeeklyPlan) -> some View {
        let assessment = store.assessment(for: plan)
        let entries = store.effectiveSteps(for: plan)
        let status = store.lifecycle(for: plan)
        let isReviewed = status == .reviewed
        let missingKeys = plan.dateKeys.enumerated().filter { entries[$0.offset] == nil }.map(\.element)
        let prior = store.latestReviewedAssessment(for: plan)
        BScreenHeader(eyebrow: isReviewed ? "REVIEWED RESULTS" : prior == nil ? "AWAITING REVIEW" : "CORRECTION AWAITING REVIEW", title: "A week of showing up.", subtitle: PlanDisplay.week(plan))
        BCard {
            PlanValueRow(title: "Base goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Stretch goal", value: "\(stretch.formatted()) steps") }
            Text(plan.timezoneID.replacingOccurrences(of: "_", with: " ")).font(.subheadline).foregroundStyle(BTheme.secondary)
            Divider()
            ForEach(Array(plan.dateKeys.enumerated()), id: \.element) { index, key in
                Button {
                    selectedDay = ReviewStepSelection(planID: plan.id, dateKey: key)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(PlanDisplay.shortDay(key, timezoneID: plan.timezoneID)).font(.subheadline.weight(.semibold))
                            Spacer(minLength: 8)
                            Text(Money.format(assessment.dailyReturnCents[index])).font(.subheadline.monospacedDigit().weight(.semibold))
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entries[index].map { "\($0.formatted()) steps" } ?? "Not recorded")
                            Spacer(minLength: 8)
                            Text(level(entries[index], terms: plan.terms)).font(.caption)
                            Image(systemName: "pencil").font(.caption)
                        }.foregroundStyle(BTheme.secondary)
                    }.foregroundStyle(BTheme.ink).padding(.vertical, 8).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(key > WeeklyCalendar.dateKey(for: store.now, timezoneID: plan.timezoneID) || status == .voidedBeforeStart)
                .accessibilityLabel("\(PlanDisplay.fullDay(key, timezoneID: plan.timezoneID)), \(entries[index].map { "\($0) steps" } ?? "not recorded"), personal return \(Money.format(assessment.dailyReturnCents[index])). Edit total.")
                if index < 6 { Divider() }
            }
        }
        if plan.terms.consistencyEnabled {
            BCard {
                Label("Consistency", systemImage: "calendar.badge.checkmark").font(.headline)
                PlanValueRow(title: "Qualifying days", value: "\(assessment.qualifyingDays) of 5 needed")
                BMoneyRow(title: "Consistency return", cents: assessment.consistencyReturnCents)
                Text("Any five dates meeting the base goal unlock the reserve once. Earlier daily returns remain earned regardless.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        BCard {
            Text(isReviewed ? "Reviewed financial outcome · CAD" : "Calculated outcome · CAD · awaiting review").font(.headline)
            BMoneyRow(title: "Personal commitment", cents: plan.terms.commitmentCents)
            Divider()
            BMoneyRow(title: "Your money earned back", cents: assessment.personalReturnCents, emphasized: true)
            BMoneyRow(title: "Charity allocation", cents: assessment.charityAllocationCents)
            Text(plan.terms.charity).font(.subheadline).foregroundStyle(BTheme.secondary)
            if let support = store.support(for: plan), support.applies {
                Divider()
                BMoneyRow(title: "Supporter rewards earned", cents: assessment.supporterRewardCents)
                BMoneyRow(title: "Unused supporter allowance", cents: assessment.unusedSupporterAllowanceCents)
                Text("Unused allowance stays with \(support.alias). Only your own unearned commitment is allocated to charity.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        if !isReviewed, let prior {
            BCard { PlanAssessmentComparison(before: prior.result, after: assessment) }
        }
        if !isReviewed, !missingKeys.isEmpty {
            BCard {
                Label("Some dates have no recorded total", systemImage: "exclamationmark.circle").font(.headline).foregroundStyle(BTheme.warning)
                Text("You can enter those totals above, or acknowledge that these dates receive no return:").foregroundStyle(BTheme.secondary)
                ForEach(missingKeys, id: \.self) { key in Text(PlanDisplay.shortDay(key, timezoneID: plan.timezoneID)).font(.subheadline.weight(.semibold)) }
                Toggle("I acknowledge these missing dates receive no return", isOn: $missingAcknowledged).tint(BTheme.accent)
                    .accessibilityIdentifier("review.missingAcknowledged")
            }
        }
        if let error { PlanNotice(text: error, warning: true) }
        if status == .awaitingReview {
            PlanNotice(text: "Confirming records this calculation from the walking you entered. It does not verify exercise, transfer money, or execute a donation.")
            BPrimaryButton(title: prior == nil ? "Confirm weekly review" : "Confirm corrected weekly review") { confirm() }
                .disabled(confirming || (!missingKeys.isEmpty && !missingAcknowledged)).accessibilityIdentifier("review.confirm")
        } else if isReviewed {
            BStatusBadge(title: "Weekly review saved")
            NavigationLink { MoneyDetailView(planID: plan.id) } label: {
                Label("Record external settlement", systemImage: "checklist").frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).tint(BTheme.accent)
            Button { share = true } label: { Label("Share reviewed summary", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 48) }
            BCard {
                Text(shouldSuggestProgression(plan) && !progressionDismissed ? "You've been meeting these targets regularly." : "What would you like for next week?").font(.headline)
                Text(shouldSuggestProgression(plan) && !progressionDismissed ? "Keep this plan or consider an adjustment for next week. Your money commitment never increases automatically." : "Keeping a routine is progress. You can repeat this plan or adjust your next commitment without changing this week's history.").font(.subheadline).foregroundStyle(BTheme.secondary)
                Button("Keep this plan") { prepareNext = true }.frame(minHeight: 44)
                Button("Adjust next week") { prepareNext = true }.frame(minHeight: 44)
                if shouldSuggestProgression(plan), !progressionDismissed {
                    Button("Not now") { progressionDismissed = true }.frame(minHeight: 44)
                }
            }
        } else {
            PlanNotice(text: status == .voidedBeforeStart ? "A voided week has no assessed financial outcome." : "Your weekly review becomes available after the seven-day plan ends. These figures are provisional.")
        }
    }

    private func level(_ steps: Int?, terms: PlanTerms) -> String {
        guard let steps else { return "Missing" }
        if steps >= terms.highestGoalSteps { return terms.stretchGoalSteps == nil ? "Goal reached" : "Stretch reached" }
        if steps >= terms.baseGoalSteps { return "Base reached" }
        return steps == 0 ? "Recorded zero" : "Below base"
    }

    private func confirm() {
        guard !confirming else { return }
        confirming = true
        defer { confirming = false }
        do { try store.review(planID: planID, acknowledgeMissing: missingAcknowledged) }
        catch { self.error = PlanDisplay.text(error) }
    }

    private func shouldSuggestProgression(_ plan: WeeklyPlan) -> Bool {
        guard store.profile.progressionPromptsEnabled, store.lifecycle(for: plan) == .reviewed,
              store.assessment(for: plan).highestGoalDays == 7,
              let precedingStart = try? WeeklyCalendar.addingDays(-7, to: plan.startDateKey, timezoneID: plan.timezoneID),
              let previous = store.plans.first(where: { $0.startDateKey == precedingStart && $0.timezoneID == plan.timezoneID && $0.voidedAt == nil }),
              store.lifecycle(for: previous) == .reviewed else { return false }
        return store.assessment(for: previous).highestGoalDays == 7
    }
}
