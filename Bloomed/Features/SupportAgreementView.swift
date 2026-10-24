import SwiftUI

struct SupportAgreementView: View {
    let planID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var alias = ""
    @State private var capText = ""
    @State private var agreementDate = Date()
    @State private var standing = false
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var useCurrentWeek = false
    @State private var acknowledged = false
    @State private var wholeWeekAcknowledged = false
    @State private var correctionReason = ""
    @State private var note = ""
    @State private var editing = false
    @State private var error: String?
    @State private var saving = false
    @State private var loaded = false
    @State private var showShare = false
    @State private var showNextPlan = false
    @State private var standingAction: SupportStandingAction?
    @State private var showRemove = false
    @State private var removeReason = ""

    private var originalPlan: WeeklyPlan? { store.plans.first { $0.id == planID } }
    private var originalSupport: WeeklySupportSnapshot? {
        guard let originalPlan else { return nil }
        return store.state.effectiveSupport(for: originalPlan.id)
    }
    private var futurePlan: WeeklyPlan? {
        guard let originalPlan else { return nil }
        return store.plans.filter { $0.id != originalPlan.id && $0.voidedAt == nil && $0.startDateKey > originalPlan.startDateKey && store.lifecycle(for: $0) == .scheduled }.sorted { $0.startDateKey < $1.startDateKey }.first
    }
    private var targetPlan: WeeklyPlan? {
        guard let originalPlan else { return nil }
        if store.lifecycle(for: originalPlan) == .scheduled || originalSupport != nil || useCurrentWeek { return originalPlan }
        return futurePlan
    }
    private var capCents: Int? {
        guard let cents = try? Money.parseCents(capText), (1...100_000).contains(cents) else { return nil }
        return cents
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BScreenHeader(eyebrow: "OPTIONAL SUPPORT", title: "Someone in your corner.", subtitle: "Record a matching agreement you made outside Bloomed.")
                    if let plan = originalPlan {
                        if let support = originalSupport, !editing { savedAgreement(support, plan: plan) }
                        else { agreementForm(plan) }
                    } else { BEmptyState(title: "Plan unavailable", message: "Choose a confirmed walking plan before recording support.") }
                    if let error { PlanNotice(text: error, warning: true) }
                }.bloomedScreen()
            }
            .background(BTheme.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Support agreement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .task { load() }
            .planKeyboardDismiss()
            .sheet(isPresented: $showShare) {
                ShareSnapshotView(planID: targetPlan?.id ?? planID)
            }
            .sheet(isPresented: $showNextPlan) {
                PlanEditorView(sourcePlan: originalPlan)
            }
            .alert(item: $standingAction) { action in
                Alert(title: Text(action.end ? "End recurring support?" : "Pause recurring support?"), message: Text("This prevents reuse on future weeks. Existing confirmed weekly agreements and earned amounts stay in history. Discuss the change outside Bloomed."), primaryButton: .destructive(Text(action.end ? "End support" : "Pause support")) { updateStanding(action) }, secondaryButton: .cancel())
            }
            .alert("Correct agreement applicability?", isPresented: $showRemove) {
                TextField("Reason this record was mistaken", text: $removeReason)
                Button("Keep agreement", role: .cancel) { }
                Button("Save applicability correction", role: .destructive) { removeMistakenAgreement() }
            } message: {
                Text("Use this only to correct a mistakenly recorded agreement. It does not cancel a real outside promise. The original stays in history, matching is recalculated, and reviewed results need a new review.")
            }
        }
    }

    private func savedAgreement(_ support: WeeklySupportSnapshot, plan: WeeklyPlan) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            BCard {
                BStatusBadge(title: "Agreement recorded by you")
                if !support.applies {
                    PlanNotice(text: "This previously recorded agreement does not apply. Its original details remain in history, and no matching is calculated from it.", warning: true)
                }
                Text(support.alias).font(.title.weight(.semibold))
                PlanValueRow(title: support.applies ? "1:1 weekly matching cap · CAD" : "Previously recorded cap · CAD", value: Money.format(support.capCents))
                Text(PlanDisplay.week(plan)).font(.subheadline).foregroundStyle(BTheme.secondary)
                Text("Matches your total personal return, including any consistency return. Unused allowance stays with the supporter.").foregroundStyle(BTheme.secondary)
                PlanValueRow(title: "Outside agreement date", value: PlanDisplay.shortDay(support.externallyAgreedDateKey, timezoneID: plan.timezoneID))
                if let standingID = support.standingAgreementID, let agreement = store.state.standingAgreements.first(where: { $0.id == standingID }) {
                    Divider()
                    Label("Recurring support recorded", systemImage: "repeat").font(.headline)
                    Text("Applies to confirmed weeks with unchanged recorded terms, from \(PlanDisplay.shortDay(agreement.effectiveStartDateKey, timezoneID: agreement.timezoneID))\(agreement.inclusiveEndDateKey.map { " through " + PlanDisplay.shortDay($0, timezoneID: agreement.timezoneID) } ?? " until stopped").")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                    if agreement.pausedAt != nil || agreement.endedAt != nil {
                        BStatusBadge(title: agreement.endedAt != nil ? "Ended for future weeks" : "Paused for future weeks", warning: true)
                    } else {
                        HStack {
                            Button("Pause future support") { standingAction = SupportStandingAction(id: standingID, end: false) }.frame(minHeight: 44)
                            Spacer()
                            Button("End", role: .destructive) { standingAction = SupportStandingAction(id: standingID, end: true) }.frame(minHeight: 44)
                        }
                    }
                }
            }
            PlanNotice(text: "This is your record of an outside agreement. The supporter has not signed in or independently confirmed it in Bloomed. No funds have been collected.")
            Button { showShare = true } label: { Label("Share this week's summary", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity, minHeight: 52) }
                .buttonStyle(.bordered).tint(BTheme.accent)
            Button("Correct recorded agreement") { editing = true }.frame(maxWidth: .infinity, minHeight: 44)
            if support.applies {
                Button("Correct agreement applicability", role: .destructive) { showRemove = true }.frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    @ViewBuilder private func agreementForm(_ plan: WeeklyPlan) -> some View {
        if originalSupport == nil {
            BCard {
                Text("A simple 1:1 match").font(.headline)
                Text("If you earn back $10 of your own commitment, your supporter provides another $10—up to the weekly cap you agree. Consistency counts toward the same match.")
                    .foregroundStyle(BTheme.secondary)
                Button { showShare = true } label: { Label("Prepare an invitation", systemImage: "square.and.arrow.up").frame(minHeight: 44) }
                Text("Sharing does not activate support. Record the agreement only after you have discussed it.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
        if originalSupport == nil, store.lifecycle(for: plan) == .active {
            BCard {
                Text("Which week does the agreement cover?").font(.headline)
                Toggle("Include this whole current week", isOn: $useCurrentWeek).tint(BTheme.accent)
                if useCurrentWeek {
                    PlanNotice(text: "The match includes all seven dates, including progress already recorded this week. There is no partial-week matching.", warning: true)
                    Toggle("We agreed to include earlier progress this week", isOn: $wholeWeekAcknowledged).tint(BTheme.accent)
                } else if let futurePlan {
                    Text("Next confirmed week: \(PlanDisplay.week(futurePlan))").foregroundStyle(BTheme.secondary)
                } else {
                    Text("Next week is the default. Confirm that week's plan first so the supporter can agree to its exact terms.").foregroundStyle(BTheme.secondary)
                    Button("Prepare next week") { showNextPlan = true }.frame(minHeight: 44)
                }
            }
        }
        if originalSupport == nil, [.awaitingReview, .reviewed, .voidedBeforeStart].contains(store.lifecycle(for: plan)) {
            PlanNotice(text: "A new supporter agreement cannot be added retroactively to an ended week. Prepare another week to record future support.", warning: true)
            Button("Prepare another week") { showNextPlan = true }.frame(minHeight: 44)
        } else if let targetPlan {
            formFields(targetPlan)
        }
    }

    private func formFields(_ plan: WeeklyPlan) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            BCard {
                Text("Your recorded agreement").font(.headline)
                Text(PlanDisplay.week(plan)).font(.subheadline).foregroundStyle(BTheme.secondary)
                TextField("Supporter's name or alias", text: $alias)
                    .textContentType(.nickname).padding(14).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("support.alias")
                PlanInput(title: "Maximum match for one week", prompt: "0.00", text: $capText, keyboard: .decimalPad, suffix: "CAD", identifier: "support.cap")
                Text("CAD $0.01–$1,000.00. This is a cap, not a payment already received.").font(.subheadline).foregroundStyle(BTheme.secondary)
                DatePicker("Agreed outside Bloomed", selection: $agreementDate, in: ...store.now, displayedComponents: .date)
                    .environment(\.timeZone, TimeZone(identifier: plan.timezoneID) ?? .current)
                TextField("Optional note", text: $note, axis: .vertical).lineLimit(2...4)
            }
            BCard {
                Toggle("Ongoing weekly agreement", isOn: $standing).font(.headline).tint(BTheme.accent)
                if standing {
                    Text("The cap resets for each new week you explicitly confirm. Goals, budget, timezone, and rules must still match this recorded agreement.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                    Toggle("Set an end date", isOn: $hasEndDate).tint(BTheme.accent)
                    if hasEndDate {
                        DatePicker("Last covered date", selection: $endDate, in: standingEarliestEnd(plan)..., displayedComponents: .date)
                            .environment(\.timeZone, TimeZone(identifier: plan.timezoneID) ?? .current)
                    }
                    Text("No automatic charge, plan creation, or supporter notification occurs.").font(.subheadline).foregroundStyle(BTheme.secondary)
                } else { Text("Covers only the seven dates shown above.").font(.subheadline).foregroundStyle(BTheme.secondary) }
            }
            if let capCents {
                BCard {
                    Text("Match preview · CAD").font(.headline)
                    BMoneyRow(title: "Current recorded personal return", cents: store.assessment(for: plan).personalReturnCents)
                    if let preview = try? RewardEngine.evaluate(terms: plan.terms, dailySteps: store.effectiveSteps(for: plan), supporterCapCents: capCents) {
                        BMoneyRow(title: "Matching reward from recorded activity", cents: preview.supporterRewardCents)
                        BMoneyRow(title: "Unused supporter allowance", cents: preview.unusedSupporterAllowanceCents)
                        if originalSupport != nil {
                            Divider()
                            PlanAssessmentComparison(before: store.assessment(for: plan), after: preview)
                        }
                    }
                    Text("Amounts remain provisional until weekly review. The supporter keeps unused allowance.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            if originalSupport != nil {
                BCard {
                    Text("Preserve a correction").font(.headline)
                    TextField("Why is the recorded agreement changing?", text: $correctionReason, axis: .vertical)
                        .lineLimit(2...4).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    Text("The previous agreement stays in history. A reviewed week will need another review; existing settlement records are retained.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            Toggle("We agreed to this outside Bloomed", isOn: $acknowledged).tint(BTheme.accent)
                .accessibilityIdentifier("support.acknowledged")
            BPrimaryButton(title: originalSupport == nil ? "Save recorded agreement" : "Save agreement correction") { save(plan) }
                .disabled(!canSave(plan) || saving).accessibilityIdentifier("support.save")
            PlanNotice(text: "This creates a participant-recorded agreement. It does not contact the supporter, collect money, or verify their acceptance.")
        }
    }

    private func standingEarliestEnd(_ plan: WeeklyPlan) -> Date {
        (try? WeeklyCalendar.date(for: plan.dateKeys.last ?? plan.startDateKey, timezoneID: plan.timezoneID)) ?? store.now
    }

    private func canSave(_ plan: WeeklyPlan) -> Bool {
        let validAlias = !alias.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let validReason = originalSupport == nil || !correctionReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let validWholeWeek = store.lifecycle(for: plan) != .active || originalSupport != nil || wholeWeekAcknowledged
        return validAlias && capCents != nil && acknowledged && validReason && validWholeWeek
    }

    private func load() {
        guard !loaded, let plan = originalPlan else { return }
        agreementDate = store.now
        endDate = standingEarliestEnd(plan)
        if let support = originalSupport {
            alias = support.alias
            capText = NSDecimalNumber(decimal: Decimal(support.capCents) / 100).stringValue
            agreementDate = (try? WeeklyCalendar.date(for: support.externallyAgreedDateKey, timezoneID: plan.timezoneID)) ?? store.now
            useCurrentWeek = true
            if let standingID = support.standingAgreementID, let agreement = store.state.standingAgreements.first(where: { $0.id == standingID }) {
                standing = true
                hasEndDate = agreement.inclusiveEndDateKey != nil
                if let key = agreement.inclusiveEndDateKey { endDate = (try? WeeklyCalendar.date(for: key, timezoneID: agreement.timezoneID)) ?? endDate }
            }
        } else { editing = true }
        loaded = true
    }

    private func save(_ plan: WeeklyPlan) {
        guard canSave(plan), let capCents, !saving else { return }
        saving = true
        defer { saving = false }
        do {
            try store.recordSupport(planID: plan.id, alias: alias, capCents: capCents, agreementDate: agreementDate, standing: standing, coverageStartKey: plan.startDateKey, coverageEndKey: standing && hasEndDate ? WeeklyCalendar.dateKey(for: endDate, timezoneID: plan.timezoneID) : nil, wholeWeekAcknowledged: store.lifecycle(for: plan) != .active || wholeWeekAcknowledged || originalSupport != nil, note: note, correctionReason: correctionReason)
            dismiss()
        } catch { self.error = PlanDisplay.text(error) }
    }

    private func updateStanding(_ action: SupportStandingAction) {
        do {
            if action.end { try store.endStandingAgreement(id: action.id) }
            else { try store.pauseStandingAgreement(id: action.id) }
        } catch { self.error = PlanDisplay.text(error) }
    }

    private func removeMistakenAgreement() {
        do { try store.removeSupport(planID: planID, reason: removeReason); editing = false }
        catch { self.error = PlanDisplay.text(error) }
    }
}

private struct SupportStandingAction: Identifiable {
    let id: UUID
    let end: Bool
}
