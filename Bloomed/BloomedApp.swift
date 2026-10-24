import SwiftUI

@main
struct BloomedApp: App {
    @State private var store: AppStore

    init() {
        #if DEBUG
        // UI tests are isolated in memory. Normal launches always use the durable local store.
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            _store = State(initialValue: AppStore(repository: UITestRepository()))
        } else {
            _store = State(initialValue: AppStore())
        }
        #else
        _store = State(initialValue: AppStore())
        #endif
    }

    var body: some Scene {
        WindowGroup { RootTabView().environment(store) }
    }
}

#if DEBUG
private final class UITestRepository: StateRepository {
    private var data: Data?
    func load() throws -> Data? { data }
    func save(_ data: Data) throws { self.data = data }
}
#endif
