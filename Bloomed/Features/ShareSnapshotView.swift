import SwiftUI
import UIKit

struct ShareSnapshotView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State private var kind: SnapshotKind = .progress
    @State private var includeMoney = false
    @State private var asOf = Date()
    @State private var activity: ShareActivity?
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let plan = store.plan(id: planID) {
                        Picker("Summary type", selection: $kind) {
                            Text("Invitation").tag(SnapshotKind.invitation)
                            Text("Progress").tag(SnapshotKind.progress)
                            if store.lifecycle(for: plan) == .reviewed { Text("Reviewed").tag(SnapshotKind.reviewed) }
                        }.pickerStyle(.segmented)
                        if kind == .progress { Toggle("Include financial details", isOn: $includeMoney).tint(BTheme.accent) }
                        BNotice(message: "Only this week is included. Your private reason and notes stay private. Recipients can keep or forward shared files; Bloomed cannot revoke them.")
                        let content = SnapshotService.content(plan: plan, store: store, kind: kind, includeMoney: includeMoney, at: asOf)
                        SnapshotCard(content: content).environment(\.colorScheme, .light)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        if let error { BErrorText(message: error) }
                        BPrimaryButton(title: "Share snapshot", action: share)
                            .accessibilityIdentifier("share-snapshot")
                        DisclosureGroup("Readable text version") { Text(content.text).font(.subheadline).textSelection(.enabled) }
                    }
                }.bloomedScreen()
            }.background(BTheme.background.ignoresSafeArea()).navigationTitle("Preview before sharing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $activity) { data in SystemShareSheet(items: data.items) }
                .onAppear { store.refresh(); asOf = store.now }
        }
    }

    private func share() {
        guard let plan = store.plan(id: planID), plan.voidedAt == nil else { return }
        if kind == .reviewed && store.lifecycle(for: plan) != .reviewed {
            error = "Review the latest correction before sharing a reviewed summary."
            return
        }
        let content = SnapshotService.content(plan: plan, store: store, kind: kind, includeMoney: includeMoney, at: asOf)
        let renderer = ImageRenderer(content: SnapshotCard(content: content).frame(width: 390).environment(\.colorScheme, .light))
        renderer.scale = 3
        guard let image = renderer.uiImage else { error = "The image couldn't be prepared. Please try again."; return }
        activity = ShareActivity(items: [content.text, image])
    }
}

private struct SnapshotCard: View {
    let content: SnapshotContent
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Bloomed", systemImage: "leaf").font(.title2.weight(.bold))
                Spacer()
                Text(content.kind.rawValue).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
            }.foregroundStyle(Color(red: 0.14, green: 0.39, blue: 0.29))
            if !content.displayName.isEmpty { Text(content.displayName).font(.title2.weight(.semibold)) }
            Text(content.dateRange).font(.headline)
            Text(content.status).font(.subheadline.weight(.semibold))
            ForEach(content.targetLines, id: \.self) { Text($0).font(.subheadline) }
            if !content.activityLines.isEmpty {
                Divider()
                ForEach(content.activityLines, id: \.self) { Text($0).font(.subheadline).monospacedDigit() }
            }
            if !content.moneyLines.isEmpty {
                Divider()
                ForEach(content.moneyLines, id: \.self) { Text($0).font(.subheadline) }
            }
            Text(content.explanation).font(.caption)
            Text("As of \(content.timestamp) · \(content.timezoneID)").font(.caption)
            Text("Static summary · manual records · not independently verified. Money is arranged outside Bloomed.")
                .font(.caption)
        }
        .foregroundStyle(Color(red: 0.09, green: 0.17, blue: 0.14))
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.97, green: 0.98, blue: 0.96))
    }
}

struct ShareActivity: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
