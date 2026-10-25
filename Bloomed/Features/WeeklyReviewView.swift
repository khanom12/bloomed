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
    @State private var charityText = ""
    @State private var savingCharity = false

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
            .scrollDismissesKeyboard(.interactively)
            .planKeyboardDismiss()
            .navigationTitle("Weekly review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $selectedDay) { selection in StepEntryView(planID: selection.planID, dateKey: selection.dateKey) }
            .sheet(isPresented: $share) { ShareSnapshotView(planID: planID, initialKind: .reviewed) }
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
        BScreenHeader(eyebrow: isReviewed ? "REVIEWED RESULTS" : prior == nil ? "AWAITING REVIEW" : "CORRECTION AWAITING REVIEW", title: isReviewed ? "Your week, reviewed." : "Review your week.", subtitle: PlanDisplay.week(plan))
        BCard {
            PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
            if let stretch = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(stretch.formatted()) steps") }
            Text("Time zone: \(PlanDisplay.timezoneName(plan.timezoneID))").font(.subheadline).foregroundStyle(BTheme.secondary)
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
                .accessibilityLabel("\(PlanDisplay.fullDay(key, timezoneID: plan.timezoneID)), \(entries[index].map { "\($0) steps" } ?? "not recorded"), own money earned back \(Money.format(assessment.dailyReturnCents[index])). Edit total.")
                if index < 6 { Divider() }
            }
        }
        if plan.terms.consistencyEnabled {
            BCard {
                Label("Consistency", systemImage: "calendar.badge.checkmark").font(.headline)
                PlanValueRow(title: "Days at your everyday goal", value: "\(assessment.qualifyingDays) of 5 needed")
                BMoneyRow(title: "Consistency amount · included below", cents: assessment.consistencyReturnCents)
                Text("Reach your everyday goal on any five days to earn back this part of your own weekly amount. The days do not need to be consecutive.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        BCard {
            Text(isReviewed ? "Reviewed amounts · CAD" : "Estimated amounts · CAD · not yet reviewed").font(.headline)
            BMoneyRow(title: "Your weekly amount", cents: plan.terms.commitmentCents)
            Divider()
            BMoneyRow(title: "Your money earned back", cents: assessment.personalReturnCents, emphasized: true)
            BMoneyRow(title: "Amount for charity", cents: assessment.charityAllocationCents)
            Text(store.charityDestination(for: plan).isEmpty ? (assessment.charityAllocationCents > 0 ? "Choose a charity or cause below" : "No charity choice needed for this result") : store.charityDestination(for: plan))
                .font(.subheadline).foregroundStyle(BTheme.secondary)
            if let support = store.support(for: plan), support.applies {
                Divider()
                BMoneyRow(title: "Supporter match", cents: assessment.supporterRewardCents)
                BMoneyRow(title: "Unused part of the match limit", cents: assessment.unusedSupporterAllowanceCents)
                Text("The unused part stays with \(support.alias). Only the amount not earned back from your own money is for charity.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        if status == .awaitingReview, assessment.charityAllocationCents > 0, store.charityDestination(for: plan).isEmpty {
            BCard {
                Text("Choose your charity or cause").font(.headline)
                Text("Your result has \(Money.format(assessment.charityAllocationCents)) for charity. Choose a destination before confirming the review. You arrange the donation outside Bloomed.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                TextField("Charity or cause", text: $charityText, axis: .vertical)
                    .lineLimit(1...3).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("review.charity")
                Button("Save charity choice") { saveCharity() }
                    .frame(minHeight: 44)
                    .disabled(savingCharity || charityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("review.saveCharity")
                Text("This saves the destination in your history; it does not make a donation.").font(.subheadline).foregroundStyle(BTheme.secondary)
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
                .disabled(confirming || (!missingKeys.isEmpty && !missingAcknowledged) || (assessment.charityAllocationCents > 0 && store.charityDestination(for: plan).isEmpty)).accessibilityIdentifier("review.confirm")
        } else if isReviewed {
            BStatusBadge(title: "Weekly review saved")
            NavigationLink { MoneyDetailView(planID: plan.id) } label: {
                Label("Record money received, kept, or donated", systemImage: "checklist").frame(maxWidth: .infinity, minHeight: 52)
            }.buttonStyle(.borderedProminent).tint(BTheme.accent).foregroundStyle(BTheme.onAccent)
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
        if steps >= terms.highestGoalSteps { return terms.stretchGoalSteps == nil ? "Goal reached" : "Higher goal reached" }
        if steps >= terms.baseGoalSteps { return "Everyday goal reached" }
        return steps == 0 ? "Recorded zero" : "Below everyday goal"
    }

    private func saveCharity() {
        guard !savingCharity else { return }
        savingCharity = true
        defer { savingCharity = false }
        do {
            try store.recordCharityDestination(planID: planID, destination: charityText)
            error = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } catch { self.error = PlanDisplay.text(error) }
    }

    private func confirm() {
        guard !confirming else { return }
        confirming = true
        defer { confirming = false }
        do { try store.review(planID: planID, acknowledgeMissing: missingAcknowledged); error = nil }
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
