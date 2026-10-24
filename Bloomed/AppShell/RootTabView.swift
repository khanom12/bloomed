import SwiftUI

enum AppTab: String, CaseIterable, Identifiable {
    case today, plan, progress, money
    var id: Self { self }
    var title: String {
        switch self { case .today: "Today"; case .plan: "My plan"; case .progress: "Progress"; case .money: "Money" }
    }
    var symbol: String {
        switch self { case .today: "sun.max"; case .plan: "leaf"; case .progress: "chart.bar"; case .money: "banknote" }
    }
}

struct RootTabView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .today
    @State private var showingSettings = false

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            ForEach(AppTab.allCases) { item in
                NavigationStack {
                    Group {
                        switch item {
                        case .today: TodayView()
                        case .plan: MyPlanView()
                        case .progress: WalkingProgressView()
                        case .money: MoneyView()
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Settings", systemImage: "gearshape") { showingSettings = true }
                                .labelStyle(.iconOnly).accessibilityIdentifier("settings")
                        }
                    }
                }.tabItem { Label(item.title, systemImage: item.symbol) }.tag(item)
            }
        }
        .tint(BTheme.accent)
        .sheet(isPresented: $showingSettings) { SettingsView() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.refresh() } }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in store.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in store.refresh() }
        .task(id: scenePhase) { await refreshAtPinnedDayBoundaries() }
        .alert("Your records need attention", isPresented: Binding(get: { store.errorMessage != nil && store.isLoaded }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK") { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .overlay {
            if !store.isLoaded {
                VStack(spacing: 20) {
                    BEmptyState(title: "Your saved records need attention.", message: "They have not been replaced. Retry opening them or restore a backup from Settings.", symbol: "externaldrive.badge.exclamationmark", actionTitle: "Open recovery settings", action: { showingSettings = true })
                    if let message = store.errorMessage { BErrorText(message: message) }
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity).background(BTheme.background)
            }
        }
    }

    /// A plan keeps its own timezone while travelling, so the device's midnight
    /// notification alone cannot advance an open screen at the plan boundary.
    private func refreshAtPinnedDayBoundaries() async {
        guard scenePhase == .active else { return }
        while !Task.isCancelled {
            store.refresh()
            let zoneIDs = Set(store.plans.map(\.timezoneID) + [TimeZone.current.identifier])
            let boundaries = zoneIDs.compactMap { zoneID -> Date? in
                guard let zone = TimeZone(identifier: zoneID) else { return nil }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = zone
                return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: store.now))
            }
            let delay = max(0.1, (boundaries.min() ?? store.now.addingTimeInterval(60)).timeIntervalSinceNow)
            do { try await Task.sleep(for: .seconds(min(delay, 60))) }
            catch { return }
        }
    }
}
