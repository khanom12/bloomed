import SwiftUI
import UIKit

struct ShareSnapshotView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let planID: UUID
    @State private var kind: SnapshotKind
    @State private var includeMoney = false
    @State private var asOf = Date()
    @State private var activity: ShareActivity?
    @State private var error: String?

    init(planID: UUID, initialKind: SnapshotKind = .progress) {
        self.planID = planID
        _kind = State(initialValue: initialKind)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let plan = store.plan(id: planID), plan.voidedAt == nil {
                        Picker("What would you like to share?", selection: $kind) {
                            Text("Invitation").tag(SnapshotKind.invitation)
                            Text("Progress").tag(SnapshotKind.progress)
                            if store.lifecycle(for: plan) == .reviewed { Text("Reviewed").tag(SnapshotKind.reviewed) }
                        }.pickerStyle(.segmented)
                        if kind == .progress {
                            Toggle("Include financial details", isOn: $includeMoney).tint(BTheme.accent)
                        } else if kind == .invitation {
                            Text("Your invitation includes this week's goals and financial terms. You choose where to share it. Sharing does not record an agreement.")
                                .font(.subheadline).foregroundStyle(BTheme.secondary)
                        }
                        let content = SnapshotService.content(plan: plan, store: store, kind: kind, includeMoney: includeMoney, at: asOf)
                        SnapshotCard(content: content).environment(\.colorScheme, .light).dynamicTypeSize(.large)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        DisclosureGroup("Read or copy the text version") {
                            Text(content.text).font(.body).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
                        }
                        BNotice(message: "Only this week is included. Your private reason and notes stay private. Recipients can keep or forward a shared file; Bloomed cannot recall it.")
                        if let error { BErrorText(message: error) }
                        BPrimaryButton(title: shareTitle, action: share).accessibilityIdentifier("share-snapshot")
                    } else {
                        BEmptyState(title: "This week can't be shared", message: "Choose a confirmed walking plan that has not been cancelled.")
                    }
                }.bloomedScreen()
            }.background(BTheme.background.ignoresSafeArea())
                .navigationTitle("Preview before sharing").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $activity) { data in SystemShareSheet(items: data.items) }
                .onAppear {
                    store.refresh()
                    asOf = store.now
                    if let plan = store.plan(id: planID), kind == .reviewed, store.lifecycle(for: plan) != .reviewed { kind = .progress }
                }
                .onChange(of: kind) { _, _ in error = nil }
        }
    }

    private var shareTitle: String {
        switch kind {
        case .invitation: return "Share invitation"
        case .progress: return "Share progress"
        case .reviewed: return "Share reviewed summary"
        }
    }

    private func share() {
        store.refresh()
        guard let plan = store.plan(id: planID), plan.voidedAt == nil else { return }
        if kind == .reviewed && store.lifecycle(for: plan) != .reviewed {
            error = "Review the latest correction before sharing a reviewed summary."
            return
        }
        asOf = store.now
        let content = SnapshotService.content(plan: plan, store: store, kind: kind, includeMoney: includeMoney, at: asOf)
        let renderer = ImageRenderer(content: SnapshotCard(content: content).frame(width: 390).environment(\.colorScheme, .light).dynamicTypeSize(.large))
        renderer.scale = 3
        guard let image = renderer.uiImage else { error = "The image couldn't be prepared. Please try again."; return }
        activity = ShareActivity(items: [image, content.text])
    }
}

struct SnapshotCard: View {
    let content: SnapshotContent
    private let accent = Color(red: 35.0 / 255, green: 99.0 / 255, blue: 75.0 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 12) {
                BBrandLockup()
                Spacer(minLength: 8)
                Text(content.kind.rawValue).font(.caption.weight(.semibold)).multilineTextAlignment(.trailing)
            }.foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 12) {
                if content.kind == .invitation {
                    Image(systemName: "figure.walk").font(.system(size: 36, weight: .regular))
                        .foregroundStyle(accent).accessibilityHidden(true)
                }
                if !content.displayName.isEmpty { Text(content.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(accent) }
                Text(content.headline).font(.title2.weight(.bold))
                Text(content.introduction).font(.body)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(content.dateRange).font(.headline)
                Text("Week follows \(content.timezoneName)").font(.subheadline)
                Text(content.status).font(.subheadline.weight(.medium)).foregroundStyle(accent)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            section("Walking goals", lines: content.targetLines)
            if !content.activityLines.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recorded walking").font(.headline).foregroundStyle(accent)
                    Text(content.activitySummary).font(.subheadline.weight(.medium))
                    ForEach(content.activityLines, id: \.self) { Text($0).font(.subheadline).monospacedDigit() }
                }
            }
            if !content.moneyLines.isEmpty { section(content.moneyHeading, lines: content.moneyLines) }
            Divider()
            Text(content.explanation).font(.subheadline)
            VStack(alignment: .leading, spacing: 8) {
                Text("Created \(content.timestamp) · \(content.timezoneName)")
                Text(content.recordDisclosure)
            }.font(.caption)
        }
        .fixedSize(horizontal: false, vertical: true)
        .foregroundStyle(Color(red: 0.09, green: 0.17, blue: 0.14))
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.97, green: 0.98, blue: 0.96))
    }

    private func section(_ title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).foregroundStyle(accent)
            ForEach(lines, id: \.self) { Text($0).font(.subheadline) }
        }
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
