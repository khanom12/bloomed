import SwiftUI

struct SettlementEntryView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    let bucket: FinancialBucket
    @State private var amount = ""
    @State private var effectiveDate = Date()
    @State private var note = ""
    @State private var error: String?
    @State private var confirming = false
    @State private var transactionKey = UUID()

    var body: some View {
        NavigationStack {
            Form {
                if let plan = store.plan(id: planID) {
                    Section {
                        Text(Format.week(plan)).foregroundStyle(BTheme.secondary)
                        BMoneyRow(title: "Outstanding", cents: store.reconciliation(for: plan, bucket: bucket).outstandingCents)
                    }
                    Section("What happened outside Bloomed") {
                        TextField("Amount in CAD", text: $amount).keyboardType(.decimalPad)
                            .accessibilityIdentifier("settlement-amount")
                        DatePicker("Date", selection: $effectiveDate, in: ...store.now, displayedComponents: .date)
                            .environment(\.timeZone, TimeZone(identifier: plan.timezoneID) ?? .current)
                        TextField("Note (optional)", text: $note, axis: .vertical)
                    }
                    Section {
                        BNotice(message: "This records what happened outside Bloomed. Bloomed does not transfer or verify money.")
                        if let error { BErrorText(message: error) }
                        BPrimaryButton(title: settlementTitle(bucket, handling: plan.terms.handling), action: { confirming = true })
                    }
                }
            }.scrollContentBackground(.hidden).background(BTheme.background)
                .navigationTitle("External settlement").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .confirmationDialog("Record this outside settlement?", isPresented: $confirming, titleVisibility: .visible) {
                    Button("Record settlement", action: save)
                } message: { Text("Confirm that this amount was actually retained, received, or donated outside Bloomed.") }
                .onAppear(perform: prepare)
        }
    }

    private func prepare() {
        guard amount.isEmpty, let plan = store.plan(id: planID) else { return }
        let value = store.reconciliation(for: plan, bucket: bucket).outstandingCents
        amount = String(format: "%d.%02d", value / 100, value % 100)
        effectiveDate = store.now
    }
    private func save() {
        guard let plan = store.plan(id: planID) else { return }
        do {
            try store.recordSettlement(planID: planID, bucket: bucket, amountCents: Money.parseCents(amount),
                                       effectiveDateKey: WeeklyCalendar.dateKey(for: effectiveDate, timezoneID: plan.timezoneID),
                                       note: note, transactionKey: transactionKey)
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}

struct VoidSettlementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let recordID: UUID
    @State private var reason = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("Use this only to correct a mistaken record. It does not reverse an actual payment or donation. The original amount and this correction remain in history.") }
                Section("Reason for correction") { TextField("Explain what was recorded incorrectly", text: $reason, axis: .vertical) }
                Section {
                    if let error { BErrorText(message: error) }
                    Button("Void mistaken record", role: .destructive, action: save).disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.navigationTitle("Correct external record").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func save() {
        do { try store.voidSettlement(id: recordID, reason: reason); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct ExceptionHistory: View {
    @Environment(AppStore.self) private var store
    let plan: WeeklyPlan
    let addNote: () -> Void
    let resolve: (UUID) -> Void
    var body: some View {
        let entries = store.state.exceptions.filter { $0.planID == plan.id }
        let resolved = Set(entries.compactMap(\.resolvesID))
        BCard {
            BSectionTitle(title: "Outside arrangements")
            Text("Record an exceptional agreement or its resolution without changing the walking calculation.").font(.subheadline).foregroundStyle(BTheme.secondary)
            ForEach(entries) { record in
                Text(record.note).font(.subheadline)
                if record.resolvesID == nil && !resolved.contains(record.id) {
                    Button("Record resolution") { resolve(record.id) }.frame(minHeight: 44)
                }
            }
            Button("Add outside-arrangement note", action: addNote).frame(minHeight: 44)
        }
    }
}

struct ExceptionNoteView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    let resolvesID: UUID?
    @State private var note = ""
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section { Text("This preserves your outside agreement. Calculations and actual settlement records remain unchanged.") }
                Section("Note") { TextField("Describe the agreement", text: $note, axis: .vertical) }
                Section {
                    if let error { BErrorText(message: error) }
                    BPrimaryButton(title: "Save note", action: save).disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }.navigationTitle(resolvesID == nil ? "Outside arrangement" : "Record resolution").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
    }
    private func save() {
        do { try store.noteException(planID: planID, note: note, resolvesID: resolvesID); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}
