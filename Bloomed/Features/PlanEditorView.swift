import SwiftUI

struct PlanEditorView: View {
    var sourcePlan: WeeklyPlan? = nil
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var draft = PlanDraft(startDateKey: "", timezoneID: TimeZone.current.identifier)
    @State private var loaded = false
    @State private var error: String?
    @State private var submitting = false
    @State private var lastAdvanceUptime: TimeInterval?
    @State private var confirmedPlan: WeeklyPlan?
    @State private var showTimezone = false
    @State private var showSupport = false
    @State private var showDiscard = false
    @State private var resumedDraft = false
    @State private var autosaveTask: Task<Void, Never>?
    @State private var savePending = false
    @State private var draftFinished = false

    private let stepNames = ["Everyday goal", "Your weekly amount", "Higher goal", "Consistency", "Review"]

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
            .onChange(of: draft) { _, _ in scheduleAutosave() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { persist() } }
            .onDisappear { persist() }
            .interactiveDismissDisabled(savePending || error != nil || submitting)
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
                if resumedDraft {
                    Text("Continuing your saved plan · Step \(draft.step + 1) of 5")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                switch draft.step {
                case 0: baseStep
                case 1: commitmentStep
                case 2: stretchStep
                case 3: consistencyStep
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
                        Text(draft.step == 4 ? (typeSize.isAccessibilitySize ? "Confirm week" : "Confirm this week's plan") : "Continue").fontWeight(.semibold)
                        if submitting { ProgressView().tint(BTheme.onAccent) }
                    }.frame(maxWidth: .infinity).padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .background(canContinue && !submitting ? BTheme.accent : BTheme.secondary, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(BTheme.onAccent)
                .disabled(!canContinue || submitting)
                .accessibilityIdentifier(draft.step == 4 ? "plan.confirm" : "plan.continue")
                .accessibilityLabel(draft.step == 4 ? "Confirm this week's plan" : "Continue")
                if let message = continuationMessage {
                    Text(message).font(.subheadline).foregroundStyle(BTheme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("plan.validation")
                }
                if savePending { Text("Saving draft…").font(.caption).foregroundStyle(BTheme.secondary) }
                if error != nil { Button("Retry saving draft") { persist() }.frame(minHeight: 44) }
                if draft.step > 0 { Button("Back") { move(to: draft.step - 1) }.frame(minHeight: 44).disabled(submitting) }
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
            .background(BTheme.surface)
    }

    private var baseStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Choose your everyday goal.", "How many steps could you aim for each day, including a busy day?")
            BCard {
                PlanInput(title: "Your everyday goal", prompt: "Enter steps", text: $draft.baseGoalText, keyboard: .numberPad, suffix: "steps / day", identifier: "plan.base")
                if !draft.baseGoalText.isEmpty, PlanDisplay.goal(draft.baseGoalText) == nil {
                    BErrorText(message: "Enter a whole number from 1 to 100,000.")
                }
                Text("Examples").font(.subheadline.weight(.semibold)).foregroundStyle(BTheme.secondary)
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 8) { exampleGoals }
                } else { HStack(spacing: 8) { exampleGoals } }
                Text("Choose a target that suits your circumstances.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            Text("Think of walks that fit your day, such as an errand or an evening stroll.").font(.subheadline).foregroundStyle(BTheme.secondary)
            BCard {
                DisclosureGroup("Your reason · optional") {
                    TextField("What would this routine mean to you?", text: $draft.privateMotivation, axis: .vertical)
                        .lineLimit(3...6).padding(.top, 12)
                    Text("This stays private and is left out of shared summaries.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
        }
    }

    private var stretchStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Add a higher daily goal?", "Choose a second target for days you walk more.")
            BCard {
                Toggle("Add a higher goal", isOn: $draft.stretchEnabled).font(.headline).tint(BTheme.accent)
                    .accessibilityIdentifier("plan.stretchEnabled")
                if draft.stretchEnabled {
                    Text("Adding a higher goal lowers the amount earned back at your everyday goal.")
                        .font(.body.weight(.semibold))
                    PlanInput(title: "Your higher goal", prompt: "Enter steps", text: $draft.stretchGoalText, keyboard: .numberPad, suffix: "steps / day", identifier: "plan.stretch")
                    Text("Choose a higher target you could reach regularly.").font(.subheadline).foregroundStyle(BTheme.secondary)
                    if !validStretch {
                        BErrorText(message: "Enter a whole number above your everyday goal of \(PlanDisplay.goal(draft.baseGoalText)?.formatted() ?? "—"), up to 100,000.")
                    }
                } else {
                    Text("Your everyday goal earns the full daily amount.").foregroundStyle(BTheme.secondary)
                }
            }
            if let preview {
                BCard {
                    Text("Your daily amounts · CAD").font(.headline)
                    dailyAmountSummary(preview)
                    if draft.stretchEnabled {
                        Text("These are alternative amounts. Reaching the higher goal earns the full daily amount in total; the two amounts are not added together.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                        if let terms, let everydayWeek = try? RewardEngine.evaluate(terms: terms, dailySteps: Array(repeating: terms.baseGoalSteps, count: 7)) {
                            Divider()
                            PlanValueRow(title: "Everyday goal on all 7 days", value: Money.format(everydayWeek.personalReturnCents))
                            Text("That is how much of your \(Money.format(terms.commitmentCents)) you would earn back with everyday-goal days only\(draft.consistencyEnabled ? ", including consistency" : ""). The rest would be for charity after review.")
                                .font(.subheadline).foregroundStyle(BTheme.secondary)
                        }
                    }
                    if hasUnevenDailyAmounts(preview) {
                        Text("Amounts vary by a cent across the week. Review the exact dated amounts before confirming.").font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                }
            }
        }
    }

    private var consistencyStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Include a consistency goal?", "Earn back part of the same weekly amount by meeting your everyday goal on five days.")
            BCard {
                Toggle("Include consistency", isOn: $draft.consistencyEnabled).font(.headline).tint(BTheme.accent)
                    .accessibilityIdentifier("plan.consistencyEnabled")
                if draft.consistencyEnabled {
                    Label("Reach \(PlanDisplay.goal(draft.baseGoalText)?.formatted() ?? "your goal") steps on any 5 of your 7 days", systemImage: "calendar.badge.checkmark")
                        .font(.title3.weight(.semibold))
                    Text("The days do not need to be consecutive. Higher-goal days count too.").font(.subheadline).foregroundStyle(BTheme.secondary)
                    if let preview {
                        Text("\(Money.format(preview.consistencyReserveCents)) of your \(Money.format(commitmentCents ?? 0)) is for consistency. The other \(Money.format(preview.dailyMaximumCents.reduce(0, +))) is available through daily goals.")
                            .font(.body.weight(.semibold))
                        Divider()
                        dailyAmountSummary(preview)
                        Text("The consistency amount is part of your own money, not an extra payment. It is earned back once you reach your everyday goal on five days.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                    DisclosureGroup("How this amount works") {
                        Text("20% of your weekly amount is set aside for consistency, rounded down to cents. Four days do not unlock it. Reaching your highest selected goal on all seven days earns back your full weekly amount.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary).padding(.top, 8)
                    }
                } else {
                    Text("Your whole weekly amount is available through daily walking goals.").foregroundStyle(BTheme.secondary)
                    if let preview { dailyAmountSummary(preview) }
                }
            }
        }
    }

    private var commitmentStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Choose an amount for this week.", "This is your own money. Your recorded walking determines how much you earn back. After review, the rest is for charity.")
            BCard {
                PlanInput(title: "Your weekly amount", prompt: "0.00", text: $draft.commitmentText, keyboard: .decimalPad, suffix: "CAD", identifier: "plan.commitment")
                Text("Choose an amount you are comfortable committing, including the possibility that some will go to charity.").font(.subheadline).foregroundStyle(BTheme.secondary)
                if !draft.commitmentText.isEmpty, commitmentCents == nil {
                    BErrorText(message: "Enter CAD $1.00–$1,000.00, with at most two decimal places. Leave out commas and currency symbols.")
                }
                if let cents = commitmentCents {
                    Divider()
                    PlanValueRow(title: "Total you can earn back", value: Money.format(cents))
                    Text("Optional higher and consistency goals come next. You will see their exact amounts before confirming.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            BCard {
                Text("Who keeps the money?").font(.headline)
                Picker("Who keeps the money?", selection: $draft.handling) {
                    Text("I keep it myself").tag(MoneyHandling.participantRetains)
                    Text("Someone else holds it").tag(MoneyHandling.anotherPersonHolds)
                    Text("Another arrangement").tag(MoneyHandling.otherArrangement)
                }.pickerStyle(.menu)
                if draft.handling != .participantRetains {
                    Text("Describe who holds it or the arrangement").font(.subheadline.weight(.semibold))
                    TextField("Name or a short description", text: $draft.handlerDescription, axis: .vertical)
                        .lineLimit(2...4).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("plan.handler")
                    if draft.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        BErrorText(message: "Add a short description to continue.")
                    }
                }
                Text("Bloomed does not collect or transfer this money. No bank or contact details are needed.").font(.subheadline).foregroundStyle(BTheme.secondary)
            }
            BCard {
                Text("Charity or cause · optional for now").font(.headline)
                TextField("Choose now or leave blank", text: $draft.charity, axis: .vertical)
                    .lineLimit(1...3).padding(12).background(BTheme.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Charity or cause, optional for now")
                    .accessibilityIdentifier("plan.charity")
                Text("Choose where the amount not earned back will go. You can choose later, before confirming a review with an amount for charity. You arrange the donation yourself.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                DisclosureGroup("About charity records") {
                    Text("Bloomed does not validate charities, make donations, or issue tax receipts.").font(.subheadline).foregroundStyle(BTheme.secondary).padding(.top, 8)
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            heading("Review your week.", "Check your goals, dates, and money before you confirm.")
            BCard {
                Text("Your seven days").font(.headline)
                Text("Start date").font(.headline)
                DatePicker("Start date", selection: startDateBinding, in: earliestStartDate..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.timeZone, TimeZone(identifier: draft.timezoneID) ?? .current)
                    .accessibilityIdentifier("plan.startDate")
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) { startDateChoices }
                } else {
                    HStack(spacing: 16) { startDateChoices }
                }
                if let keys = dateKeys, let last = keys.last {
                    Text("\(PlanDisplay.fullDay(draft.startDateKey, timezoneID: draft.timezoneID)) through \(PlanDisplay.fullDay(last, timezoneID: draft.timezoneID))")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                Button { showTimezone = true } label: {
                    HStack {
                        Text("Time zone: \(PlanDisplay.timezoneName(draft.timezoneID))")
                        Spacer(minLength: 8)
                        Text("Change").fontWeight(.semibold)
                    }.font(.subheadline).frame(minHeight: 44)
                }.buttonStyle(.plain)
                Text("This week follows \(PlanDisplay.timezoneName(draft.timezoneID)) time, including when you travel.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary)
                if draft.startDateKey == WeeklyCalendar.dateKey(for: store.now, timezoneID: draft.timezoneID) {
                    PlanNotice(text: "Today is Day 1. Your whole day's steps count, including before you confirm.")
                }
            }
            if let preview {
                BCard {
                    Text("Your daily amounts · CAD").font(.headline)
                    dailyAmountSummary(preview)
                    if draft.stretchEnabled {
                        Text("Reaching the higher goal earns the higher amount in total that day. The two amounts are not added together.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                    if hasUnevenDailyAmounts(preview) {
                        Text("Daily amounts vary by a cent. Check the exact amount for each date below.").font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                    DisclosureGroup("Amounts for each day") {
                        dailySchedule(preview).padding(.top, 12)
                    }
                    if draft.consistencyEnabled {
                        Divider()
                        PlanValueRow(title: "Consistency amount", value: Money.format(preview.consistencyReserveCents))
                        Text("Earn back this part of your own money by reaching \(PlanDisplay.goal(draft.baseGoalText)?.formatted() ?? "your goal") steps on any 5 of 7 days. The days do not need to be consecutive.")
                            .font(.subheadline).foregroundStyle(BTheme.secondary)
                    }
                }
            }
            BCard {
                PlanValueRow(title: "Your weekly amount · CAD", value: Money.format(commitmentCents ?? 0))
                Text("Earn back your full \(Money.format(commitmentCents ?? 0)) by reaching \(PlanDisplay.goal(draft.stretchEnabled ? draft.stretchGoalText : draft.baseGoalText)?.formatted() ?? "your goal") steps on all 7 days.")
                    .font(.body.weight(.semibold))
                Text("After your weekly review, the amount not earned back is for charity.").font(.subheadline).foregroundStyle(BTheme.secondary)
                Divider()
                PlanValueRow(title: "Charity or cause", value: draft.charity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Choose later" : draft.charity)
                if draft.charity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Choose a destination before confirming a review with an amount for charity.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                PlanValueRow(title: "Who keeps the money", value: draft.handling == .participantRetains ? "I keep it myself" : draft.handling == .anotherPersonHolds ? "Someone else holds it" : "Another arrangement")
                if draft.handling != .participantRetains { Text(draft.handlerDescription).font(.subheadline).foregroundStyle(BTheme.secondary) }
            }
            if let sourcePlan {
                BCard {
                    Text("A new week, preserved history").font(.headline)
                    PlanValueRow(title: "Previous everyday goal", value: "\(sourcePlan.terms.baseGoalSteps.formatted()) steps")
                    PlanValueRow(title: "New everyday goal", value: "\(PlanDisplay.goal(draft.baseGoalText) ?? 0) steps")
                    PlanValueRow(title: "Previous higher goal", value: sourcePlan.terms.stretchGoalSteps.map { "\($0.formatted()) steps" } ?? "Off")
                    PlanValueRow(title: "New higher goal", value: draft.stretchEnabled ? "\(PlanDisplay.goal(draft.stretchGoalText) ?? 0) steps" : "Off")
                    PlanValueRow(title: "Previous weekly amount", value: Money.format(sourcePlan.terms.commitmentCents))
                    PlanValueRow(title: "New weekly amount", value: Money.format(commitmentCents ?? 0))
                    Text("Earlier weeks keep their original terms. Recorded recurring support applies only if its dates and terms still match.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
            }
            standingSupportPreview
            if let confirmationValidationMessage { PlanNotice(text: confirmationValidationMessage, warning: true) }
            Text("You enter daily step totals yourself. Bloomed calculates the amounts; all money and donations are arranged outside the app.")
                .font(.subheadline).foregroundStyle(BTheme.secondary)
            Text("If you stop early, the original seven-day money rules still apply.")
                .font(.subheadline.weight(.semibold)).foregroundStyle(BTheme.secondary)
            DisclosureGroup("What if my plans change?") {
                Text("You can record any different outside arrangement in the week's money records without rewriting the walking calculation.")
                    .font(.subheadline).foregroundStyle(BTheme.secondary).padding(.top, 8)
            }
        }
    }

    @ViewBuilder private var startDateChoices: some View {
        Button("Start today") { setStart(offset: 0) }.frame(minHeight: 44).accessibilityIdentifier("plan.startToday")
        Button("Start tomorrow") { setStart(offset: 1) }.frame(minHeight: 44).accessibilityIdentifier("plan.startTomorrow")
    }

    private func dailyAmountSummary(_ preview: WeeklyAssessment) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            PlanValueRow(title: "\(PlanDisplay.goal(draft.baseGoalText)?.formatted() ?? "—") steps · everyday goal", value: moneyRange(draft.stretchEnabled ? preview.dailyBaseOnlyCents : preview.dailyMaximumCents))
            if draft.stretchEnabled {
                PlanValueRow(title: "\(PlanDisplay.goal(draft.stretchGoalText)?.formatted() ?? "—") steps · higher goal", value: moneyRange(preview.dailyMaximumCents))
            }
        }
    }

    private func dailySchedule(_ preview: WeeklyAssessment) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let keys = dateKeys {
                ForEach(Array(keys.enumerated()), id: \.element) { index, key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(PlanDisplay.shortDay(key, timezoneID: draft.timezoneID)).font(.subheadline.weight(.semibold))
                        PlanValueRow(title: "Everyday goal", value: Money.format(draft.stretchEnabled ? preview.dailyBaseOnlyCents[index] : preview.dailyMaximumCents[index]))
                        if draft.stretchEnabled { PlanValueRow(title: "Higher goal · total", value: Money.format(preview.dailyMaximumCents[index])) }
                    }
                }
            }
        }
    }

    private func moneyRange(_ values: [Int]) -> String {
        guard let low = values.min(), let high = values.max() else { return "—" }
        return low == high ? Money.format(low) : "\(Money.format(low))–\(Money.format(high))"
    }

    private func hasUnevenDailyAmounts(_ preview: WeeklyAssessment) -> Bool {
        Set(preview.dailyMaximumCents).count > 1 || Set(preview.dailyBaseOnlyCents).count > 1
    }

    private func confirmation(_ plan: WeeklyPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(BTheme.accent).padding(.top, 24).accessibilityHidden(true)
                heading("Your week is ready.", PlanDisplay.week(plan))
                BCard {
                    PlanValueRow(title: "Everyday goal", value: "\(plan.terms.baseGoalSteps.formatted()) steps")
                    PlanValueRow(title: "Your weekly amount", value: Money.format(plan.terms.commitmentCents))
                    if let higher = plan.terms.stretchGoalSteps { PlanValueRow(title: "Higher goal", value: "\(higher.formatted()) steps") }
                    Text("Your plan is saved. No money has moved.").font(.subheadline).foregroundStyle(BTheme.secondary)
                }
                Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(BTheme.accent).foregroundStyle(BTheme.onAccent).frame(minHeight: 52)
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
        draft.handling == .participantRetains || !draft.handlerDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var continuationMessage: String? {
        switch draft.step {
        case 0: PlanDisplay.goal(draft.baseGoalText) == nil ? "Enter your everyday step goal to continue." : nil
        case 1: commitmentCents == nil ? "Enter a weekly amount from CAD $1.00 to $1,000.00." : !validArrangement ? "Describe who holds the money or the outside arrangement." : nil
        case 2: validStretch ? nil : "Enter a higher goal above your everyday goal, or turn it off."
        case 3: nil
        default: confirmationValidationMessage
        }
    }
    private var canContinue: Bool {
        switch draft.step {
        case 0: PlanDisplay.goal(draft.baseGoalText) != nil
        case 1: commitmentCents != nil && validArrangement
        case 2: validStretch
        case 3: true
        default: PlanDisplay.goal(draft.baseGoalText) != nil && validStretch && commitmentCents != nil && validArrangement && dateKeys != nil && confirmationValidationMessage == nil
        }
    }

    private var terms: PlanTerms? {
        guard let base = PlanDisplay.goal(draft.baseGoalText), let cents = commitmentCents, validStretch else { return nil }
        return PlanTerms(baseGoalSteps: base, stretchGoalSteps: draft.stretchEnabled ? PlanDisplay.goal(draft.stretchGoalText) : nil, consistencyEnabled: draft.consistencyEnabled, commitmentCents: cents, charity: draft.charity, handling: draft.handling, handlerDescription: draft.handlerDescription)
    }
    private var preview: WeeklyAssessment? {
        guard var terms else { return nil }
        // Allocation is independent of who holds the money; incomplete handler input
        // is a preview-only placeholder and can never be confirmed.
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
        guard let proposedPlan else { return "Check your walking goals, weekly amount, money arrangement, and dates before confirming." }
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

    private func setStart(offset: Int) {
        store.refresh()
        let today = WeeklyCalendar.dateKey(for: store.now, timezoneID: draft.timezoneID)
        draft.startDateKey = (try? WeeklyCalendar.addingDays(offset, to: today, timezoneID: draft.timezoneID)) ?? today
    }

    private func load() {
        guard !loaded else { return }
        do {
            resumedDraft = store.draft != nil
            draft = try store.beginDraft(repeating: sourcePlan)
            draft.step = min(max(draft.step, 0), 4)
            loaded = true
            persist()
        } catch { self.error = PlanDisplay.text(error); loaded = true }
    }

    private func scheduleAutosave() {
        guard loaded, !draftFinished, confirmedPlan == nil else { return }
        autosaveTask?.cancel()
        savePending = draft != store.draft
        guard savePending else { return }
        autosaveTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(350)) }
            catch { return }
            guard !Task.isCancelled else { return }
            persist()
        }
    }

    @discardableResult private func persist() -> Bool {
        autosaveTask?.cancel()
        autosaveTask = nil
        guard loaded, !draftFinished, confirmedPlan == nil else { return true }
        do { try store.saveDraft(draft); savePending = false; error = nil; return true }
        catch { savePending = true; self.error = PlanDisplay.text(error); return false }
    }

    private func discardDraft() {
        autosaveTask?.cancel()
        do { try store.deleteDraft(); draftFinished = true; savePending = false; dismiss() }
        catch { self.error = PlanDisplay.text(error) }
    }

    private func move(to step: Int) {
        guard !submitting else { return }
        autosaveTask?.cancel()
        var next = draft
        next.step = step
        do {
            try store.saveDraft(next)
            draft = next
            savePending = false
            error = nil
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } catch { savePending = true; self.error = PlanDisplay.text(error) }
    }

    private func advance() {
        guard canContinue, !submitting else { return }
        // A repeated activation must not skip the newly displayed optional step.
        // Uptime is monotonic and does not affect any plan or financial dates.
        let activationTime = ProcessInfo.processInfo.systemUptime
        if let lastAdvanceUptime, activationTime - lastAdvanceUptime < 0.3 { return }
        lastAdvanceUptime = activationTime
        if draft.step < 4 { move(to: draft.step + 1); return }
        autosaveTask?.cancel()
        submitting = true
        defer { submitting = false }
        do {
            try store.saveDraft(draft)
            let plan = try store.confirmDraft()
            draftFinished = true
            savePending = false
            error = nil
            confirmedPlan = plan
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
                        Text(PlanDisplay.timezoneName(identifier))
                        Spacer()
                        if selection == identifier { Image(systemName: "checkmark").foregroundStyle(BTheme.accent) }
                    }.foregroundStyle(BTheme.ink).frame(minHeight: 44)
                }
            }
            .searchable(text: $search, prompt: "City or timezone")
            .navigationTitle("Plan time zone")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
}
