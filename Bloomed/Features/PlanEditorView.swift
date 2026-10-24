import SwiftUI

struct PlanEditorView: View {
    var sourcePlan: WeeklyPlan? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var draft = PlanDraft(startDateKey: "", timezoneID: TimeZone.current.identifier)
    @State private var loaded = false
    @State private var error: String?
    @State private var submitting = false
    @State private var confirmedPlan: WeeklyPlan?
    @State private var showTimezone = false
    @State private var showSupport = false
    @State private var showDiscard = false
    @State private var resumedDraft = false

    private let stepNames = ["Everyday goal", "Stretch goal", "Consistency", "Your commitment", "Review"]

    var body: some View {
        NavigationStack {
            Group {
                if let confirmedPlan { confirmation(confirmedPlan) }
                else if loaded { editor }
                else { ProgressView("Opening your plan…").frame(maxWidth: .infinity, maxHeight: .infinity) }
            }
            .background(BTheme.background)
            .foregroundStyle(BTheme.ink)
            .navigationTitle(confirmedPlan == nil ? "Your walking plan" : "You're ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if confirmedPlan == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Save & close") { if persist() { dismiss() } } }
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("Discard draft", role: .destructive) { showDiscard = true }
                        } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44).accessibilityLabel("Draft actions") }
                    }
                }
            }
            .task { load() }
            .planKeyboardDismiss()
            .onChange(of: draft) { _, _ in if loaded { persist() } }
            .interactiveDismissDisabled(error != nil || submitting)
            .sheet(isPresented: $showTimezone) { PlanTimezonePicker(selection: $draft.timezoneID) }
            .sheet(isPresented: $showSupport) {
                if let confirmedPlan { SupportAgreementView(planID: confirmedPlan.id) }
            }
            .alert("Discard this draft?", isPresented: $showDiscard) {
                Button("Keep draft", role: .cancel) { }
                Button("Discard draft", role: .destructive) { discardDraft() }
            } message: { Text("Only the unconfirmed draft is removed. Confirmed weekly plans and their history stay in your records.") }
        }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("STEP \(draft.step + 1) OF 5 · \(stepNames[min(max(draft.step, 0), 4)].uppercased())")
                        .font(.caption.weight(.bold)).tracking(1).foregroundStyle(BTheme.secondary)
                    HStack(spacing: 6) {
                        ForEach(0..<5) { index in
                            Capsule().fill(index <= draft.step ? BTheme.accent : BTheme.divider).frame(height: 4)
                        }
                    }.accessibilityHidden(true)
                }
                if resumedDraft, draft.step == 0 {
                    PlanNotice(text: "Continuing your saved draft. No new commitment exists until you confirm this week.")
                }
                switch draft.step {
                case 0: baseStep
                case 1: stretchStep
                case 2: consistencyStep
                case 3: commitmentStep
                default: reviewStep
                }
                if let error { PlanNotice(text: error, warning: true).accessibilityIdentifier("plan.error") }
            }
            .padding(20)
            .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .id(draft.step)
            editorFooter
        }
    }

    private var editorFooter: some View {
            VStack(spacing: 12) {
                Button(action: advance) {
                    HStack {
                        Text(draft.step == 4 ? (typeSize.isAccessibilitySize ? "Confirm week" : "Confirm this week's commitment") : "Continue").fontWeight(.semibold)
                        if submitting { ProgressView().tint(BTheme.onAccent) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .background(canContinue && !submitting ? BTheme.accent : BTheme.secondary, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(BTheme.onAccent)
                .disabled(!canContinue || submitting)
                .accessibilityIdentifier(draft.step == 4 ? "plan.confirm" : "plan.continue")
                .accessibilityLabel(draft.step == 4 ? "Confirm this week's commitment" : "Continue")
                if draft.step > 0 { Button("Back") { error = nil; draft.step -= 1 }.frame(minHeight: 44) }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
            .background(BTheme.surface)
    }

    private var baseStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("A walking goal for everyday life.", "What daily step count could you realistically commit to, including on a busy day?")
            BCard {
                PlanInput(title: "Your everyday goal", prompt: "Enter steps", text: $draft.baseGoalText, keyboard: .numberPad, suffix: "steps / day", identifier: "plan.base")
                Text("Choose a positive whole number up to 100,000 steps.").font(.subheadline).foregroundStyle(BTheme.secondary)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { exampleGoals }
                } else { HStack(spacing: 8) { exampleGoals } }
                Text("Examples only. Choose a target that suits your circumstances.").font(.caption).foregroundStyle(BTheme.secondary)
            }
            PlanNotice(text: "Think about small walks that fit into your day: a break, an errand, or an evening stroll. You choose what is realistic for you.")
            BCard {
                DisclosureGroup("Your personal reason · optional") {
                    TextField("What would this routine mean to you?", text: $draft.privateMotivation, axis: .vertical)
                        .lineLimit(3...6).padding(.top, 12)
                    Text("This stays private and is left out of shared summaries.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
        }
    }

    private var stretchStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Add a higher target?", "A stretch goal gives you a larger return on days when you walk more.")
            BCard {
                Toggle("Include a stretch goal", isOn: $draft.stretchEnabled).font(.headline).tint(BTheme.accent)
                    .accessibilityIdentifier("plan.stretchEnabled")
                if draft.stretchEnabled {
                    Divider()
                    PlanInput(title: "Your stretch goal", prompt: "Enter steps", text: $draft.stretchGoalText, keyboard: .numberPad, suffix: "steps / day", identifier: "plan.stretch")
                    Text("Choose a target above your everyday goal that you could repeat regularly, rather than your biggest possible walking day.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                    PlanNotice(text: "The base goal earns a smaller return. The stretch goal earns the daily maximum. Only the highest level reached pays.")
                } else {
                    Text("One daily goal, one daily return. You can keep things simple.").foregroundStyle(BTheme.secondary)
                }
            }
            if draft.stretchEnabled, !draft.stretchGoalText.isEmpty, !validStretch {
                PlanNotice(text: "Your stretch goal must be a whole number above your base goal, up to 100,000 steps.", warning: true)
            }
        }
    }

    private var consistencyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Make room for consistency.", "Recognise showing up throughout the week.")
            BCard {
                Toggle("Include a consistency return", isOn: $draft.consistencyEnabled).font(.headline).tint(BTheme.accent)
                    .accessibilityIdentifier("plan.consistencyEnabled")
                if draft.consistencyEnabled {
                    Label("Your base goal on any 5 of 7 days", systemImage: "calendar.badge.checkmark")
                        .font(.title3.weight(.semibold)).padding(.top, 8)
                    Text("The days do not need to be consecutive. Stretch-goal days count, too.").foregroundStyle(BTheme.secondary)
                    PlanNotice(text: "20% of the same personal commitment, rounded down to cents, is reserved for consistency. The rest is available through daily returns. Four qualifying days do not unlock this reserve.")
                } else {
                    Text("Your entire commitment is available through daily walking goals.").foregroundStyle(BTheme.secondary)
                }
            }
        }
    }

    private var commitmentStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Choose your weekly commitment.", "Choose an amount you are comfortable committing, including the possibility that some will not be returned.")
            BCard {
                PlanInput(title: "Your seven-day amount", prompt: "0.00", text: $draft.commitmentText, keyboard: .decimalPad, suffix: "CAD", identifier: "plan.commitment")
                Text("CAD $1.00–$1,000.00. Bloomed does not collect this money.").font(.subheadline).foregroundStyle(BTheme.secondary)
                if let preview {
                    Divider()
                    PlanValueRow(title: "Available through daily goals", value: Money.format(preview.dailyMaximumCents.reduce(0, +)))
                    if draft.consistencyEnabled { PlanValueRow(title: "Consistency reserve", value: Money.format(preview.consistencyReserveCents)) }
                    PlanValueRow(title: "Maximum personal return", value: Money.format(commitmentCents ?? 0))
                }
            }
            BCard {
                Text("Your outside arrangement").font(.headline)
                Picker("Who holds the money?", selection: $draft.handling) {
                    ForEach(MoneyHandling.allCases) { option in Text(option.title).tag(option) }
                }.pickerStyle(.menu)
                if draft.handling != .participantRetains {
                    TextField("Describe who holds it or the arrangement", text: $draft.handlerDescription, axis: .vertical)
                        .lineLimit(2...4).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("plan.handler")
                }
                Text("No bank information or contact details are needed.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            BCard {
                Text("If part is not earned back").font(.headline)
                TextField("Charity name or destination", text: $draft.charity, axis: .vertical)
                    .lineLimit(1...3).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("plan.charity")
                Text("Any unearned personal amount is allocated here after your weekly review. You arrange the donation outside Bloomed. The app does not validate charities or issue tax receipts.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Review this week's plan.", "Make sure this is an agreement you feel comfortable keeping.")
            BCard {
                Text("Seven days, chosen by you").font(.headline)
                Text("Start date").font(.headline)
                DatePicker("Start date", selection: startDateBinding, in: earliestStartDate..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.timeZone, TimeZone(identifier: draft.timezoneID) ?? .current)
                    .accessibilityIdentifier("plan.startDate")
                Button("Start today") {
                    store.refresh()
                    draft.startDateKey = WeeklyCalendar.dateKey(for: store.now, timezoneID: draft.timezoneID)
                }
                .frame(minHeight: 44)
                .accessibilityIdentifier("plan.startToday")
                Button { showTimezone = true } label: {
                    PlanValueRow(title: "Plan timezone", value: draft.timezoneID.replacingOccurrences(of: "_", with: " "))
                }.buttonStyle(.plain).frame(minHeight: 44)
                if let keys = dateKeys, let last = keys.last {
                    Text("\(PlanDisplay.fullDay(draft.startDateKey, timezoneID: draft.timezoneID)) through \(PlanDisplay.fullDay(last, timezoneID: draft.timezoneID))")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                if draft.startDateKey == WeeklyCalendar.dateKey(for: store.now, timezoneID: draft.timezoneID) {
                    PlanNotice(text: "Today is Day 1. Your whole day's recorded steps count, including walking before you confirm.")
                }
            }
            BCard {
                Text("Your daily walking agreement · CAD").font(.headline)
                PlanValueRow(title: "Base goal", value: "\(PlanDisplay.goal(draft.baseGoalText) ?? 0) steps")
                if draft.stretchEnabled { PlanValueRow(title: "Stretch goal", value: "\(PlanDisplay.goal(draft.stretchGoalText) ?? 0) steps") }
                if let preview, let keys = dateKeys {
                    Divider()
                    ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                        VStack(alignment: .leading, spacing: 5) {
                            PlanValueRow(title: PlanDisplay.shortDay(key, timezoneID: draft.timezoneID), value: Money.format(preview.dailyMaximumCents[index]))
                            if draft.stretchEnabled {
                                Text("Base only: \(Money.format(preview.dailyBaseOnlyCents[index])) · Stretch: daily maximum")
                                    .font(.caption).foregroundStyle(BTheme.secondary)
                            }
                        }
                    }
                    if draft.consistencyEnabled {
                        Divider()
                        PlanValueRow(title: "Consistency return", value: Money.format(preview.consistencyReserveCents))
                        Text("Reach the base goal on any 5 of 7 dates. This amount is part of your commitment.").font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                }
            }
            BCard {
                PlanValueRow(title: "Personal commitment", value: Money.format(commitmentCents ?? 0))
                PlanValueRow(title: "Maximum personal return", value: Money.format(commitmentCents ?? 0))
                Text("Your full commitment is available by reaching the \(draft.stretchEnabled ? "stretch goal" : "daily goal") on all 7 days.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                Divider()
                PlanValueRow(title: "Charity destination", value: draft.charity)
                Text(draft.handling.title).font(.subheadline)
                if !draft.handlerDescription.isEmpty { Text(draft.handlerDescription).font(.subheadline).foregroundStyle(BTheme.secondary) }
            }
            if let sourcePlan {
                BCard {
                    Text("A new week, preserved history").font(.headline)
                    PlanValueRow(title: "Previous base", value: "\(sourcePlan.terms.baseGoalSteps.formatted()) steps")
                    PlanValueRow(title: "Proposed base", value: "\(PlanDisplay.goal(draft.baseGoalText) ?? 0) steps")
                    PlanValueRow(title: "Previous stretch", value: sourcePlan.terms.stretchGoalSteps.map { "\($0.formatted()) steps" } ?? "Off")
                    PlanValueRow(title: "Proposed stretch", value: draft.stretchEnabled ? "\(PlanDisplay.goal(draft.stretchGoalText) ?? 0) steps" : "Off")
                    PlanValueRow(title: "Previous consistency", value: sourcePlan.terms.consistencyEnabled ? "On" : "Off")
                    PlanValueRow(title: "Proposed consistency", value: draft.consistencyEnabled ? "On" : "Off")
                    PlanValueRow(title: "Previous commitment", value: Money.format(sourcePlan.terms.commitmentCents))
                    PlanValueRow(title: "Proposed commitment", value: Money.format(commitmentCents ?? 0))
                    Text("Earlier weeks keep their original terms. Recorded standing support only applies if its covered dates and terms still match.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            standingSupportPreview
            if let confirmationValidationMessage { PlanNotice(text: confirmationValidationMessage, warning: true) }
            PlanNotice(text: "You record walking manually. Money, proof, and donations are arranged outside Bloomed. Once the week starts, its original seven-day rules remain the calculation basis; stopping early does not automatically prorate the commitment.")
        }
    }

    private func confirmation(_ plan: WeeklyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(BTheme.accent).padding(.top, 24).accessibilityHidden(true)
                heading("Your week is ready.", PlanDisplay.week(plan))
                BCard {
                    PlanValueRow(title: "Daily goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
                    PlanValueRow(title: "Your commitment", value: Money.format(plan.terms.commitmentCents))
                    Text("Your agreement has been saved. No money has moved.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(BTheme.accent).frame(minHeight: 52)
                Button("Invite a supporter · optional") { showSupport = true }.frame(minHeight: 44)
            }.padding(24)
        }.interactiveDismissDisabled(false)
    }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.largeTitle.weight(.bold)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.body).foregroundStyle(BTheme.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var exampleGoals: some View {
        ForEach([3_000, 5_000, 7_000], id: \.self) { value in
            Button { draft.baseGoalText = String(value) } label: {
                Text(value.formatted()).font(.subheadline.weight(.semibold)).padding(.horizontal, 12).frame(minHeight: 44)
                    .background(BTheme.accentSoft, in: Capsule())
            }.buttonStyle(.plain).accessibilityLabel("Example: \(value) steps")
        }
    }

    private var commitmentCents: Int? {
        guard let cents = try? Money.parseCents(draft.commitmentText), (100...100_000).contains(cents) else { return nil }
        return cents
    }
    private var validStretch: Bool {
        guard draft.stretchEnabled else { return true }
        guard let base = PlanDisplay.goal(draft.baseGoalText), let stretch = PlanDisplay.goal(draft.stretchGoalText) else { return false }
        return stretch > base
    }
    private var validArrangement: Bool {
        !draft.charity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (draft.handling == .participantRetains || !draft.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    private var canContinue: Bool {
        switch draft.step {
        case 0: PlanDisplay.goal(draft.baseGoalText) != nil
        case 1: validStretch
        case 2: true
        case 3: commitmentCents != nil && validArrangement
        default: PlanDisplay.goal(draft.baseGoalText) != nil && validStretch && commitmentCents != nil && validArrangement && dateKeys != nil && confirmationValidationMessage == nil
        }
    }
    private var terms: PlanTerms? {
        guard let base = PlanDisplay.goal(draft.baseGoalText), let cents = commitmentCents else { return nil }
        return PlanTerms(baseGoalSteps: base, stretchGoalSteps: draft.stretchEnabled ? PlanDisplay.goal(draft.stretchGoalText) : nil, consistencyEnabled: draft.consistencyEnabled, commitmentCents: cents, charity: draft.charity, handling: draft.handling, handlerDescription: draft.handlerDescription)
    }
    private var preview: WeeklyAssessment? {
        guard var terms else { return nil }
        // An allocation preview is not a confirmed agreement. Missing outside details
        // are only placeholders for the pure evaluator, never persisted as terms.
        if terms.charity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { terms.charity = "Pending destination" }
        if terms.handling != .participantRetains, terms.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { terms.handlerDescription = "Pending outside arrangement" }
        return try? RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: nil, count: 7))
    }

    @ViewBuilder private var standingSupportPreview: some View {
        let standing = store.state.standingAgreements.filter { $0.endedAt == nil && $0.pausedAt == nil }
        if !standing.isEmpty, let candidate = proposedPlan {
            let applicable = standing.filter { $0.applies(to: candidate) }
            BCard {
                Label("Recorded recurring support", systemImage: "person.2").font(.headline)
                if applicable.count == 1, let agreement = applicable.first {
                    PlanValueRow(title: "Matching cap for this week", value: Money.format(agreement.capCents))
                    Text("The recorded dates and terms match. This week will preserve its own copy of that agreement. No money moves on confirmation.").font(.subheadline).foregroundStyle(BTheme.secondary)
                } else {
                    PlanNotice(text: "This plan differs from the recorded support agreement or is outside its covered dates. Agree the changes outside Bloomed before applying support. You can confirm this week with your personal commitment alone.", warning: true)
                }
            }
        }
    }
    private var proposedPlan: WeeklyPlan? {
        guard let terms, let preview, let keys = dateKeys else { return nil }
        return WeeklyPlan(id: draft.id, participantID: store.profile.id, startDateKey: draft.startDateKey, timezoneID: draft.timezoneID, dateKeys: keys, terms: terms, createdAt: draft.createdAt, confirmedAt: nil, dailyMaximumCents: preview.dailyMaximumCents, consistencyReserveCents: preview.consistencyReserveCents)
    }
    private var confirmationValidationMessage: String? {
        guard let proposedPlan else { return "Complete your walking targets, commitment, outside arrangement, and valid dates before confirming." }
        do { try WeeklyCalendar.validateConfirmation(proposedPlan, among: store.plans, now: store.now); return nil }
        catch { return PlanDisplay.text(error) }
    }
    private var dateKeys: [String]? { try? WeeklyCalendar.dateKeys(startDateKey: draft.startDateKey, timezoneID: draft.timezoneID) }
    private var earliestStartDate: Date {
        let key = WeeklyCalendar.dateKey(for: store.now, timezoneID: draft.timezoneID)
        return (try? WeeklyCalendar.date(for: key, timezoneID: draft.timezoneID)) ?? store.now
    }
    private var startDateBinding: Binding<Date> {
        Binding(get: { (try? WeeklyCalendar.date(for: draft.startDateKey, timezoneID: draft.timezoneID)) ?? store.now }, set: { draft.startDateKey = WeeklyCalendar.dateKey(for: $0, timezoneID: draft.timezoneID) })
    }

    private func load() {
        guard !loaded else { return }
        do {
            resumedDraft = store.draft != nil
            if sourcePlan == nil, let saved = store.draft { draft = saved }
            else { draft = try store.beginDraft(repeating: sourcePlan) }
            draft.step = min(max(draft.step, 0), 4)
            loaded = true
        } catch { self.error = PlanDisplay.text(error); loaded = true }
    }
    @discardableResult private func persist() -> Bool {
        do { try store.saveDraft(draft); error = nil; return true }
        catch { self.error = PlanDisplay.text(error); return false }
    }
    private func discardDraft() {
        do { try store.deleteDraft(); dismiss() }
        catch { self.error = PlanDisplay.text(error) }
    }
    private func advance() {
        guard canContinue, !submitting else { return }
        error = nil
        if draft.step < 4 { draft.step += 1; return }
        submitting = true
        defer { submitting = false }
        do {
            try store.saveDraft(draft)
            confirmedPlan = try store.confirmDraft()
        } catch { self.error = PlanDisplay.text(error) }
    }
}

private struct PlanTimezonePicker: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""
    private var identifiers: [String] {
        TimeZone.knownTimeZoneIdentifiers.filter { search.isEmpty || $0.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List(identifiers, id: \.self) { identifier in
                Button {
                    selection = identifier
                    dismiss()
                } label: {
                    HStack {
                        Text(identifier.replacingOccurrences(of: "_", with: " "))
                        Spacer()
                        if selection == identifier { Image(systemName: "checkmark").foregroundStyle(BTheme.accent) }
                    }.foregroundStyle(BTheme.ink).frame(minHeight: 44)
                }
            }
            .searchable(text: $search, prompt: "City or timezone")
            .navigationTitle("Plan timezone")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
