import Foundation

/// The repository commits one complete, versioned snapshot. A throwing save must
/// leave the previous snapshot available; callers publish state only afterward.
protocol StateRepository {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

struct AtomicJSONRepository: StateRepository {
    let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory,
            in: .userDomainMask)[0].appendingPathComponent("Bloomed", isDirectory: true)
            .appendingPathComponent("bloomed-v1.json")
    }

    func load() throws -> Data? {
        do { return try Data(contentsOf: fileURL) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
    }

    func save(_ data: Data) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                              withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }
}

enum StoreError: LocalizedError, Equatable {
    case invalid(String)
    case unavailable
    case missingPlan
    case noDraft

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        case .unavailable: "Your saved records could not be opened. Retry or restore a backup before making changes."
        case .missingPlan: "This walking plan could not be found."
        case .noDraft: "Create a plan draft before confirming a commitment."
        }
    }
}

struct SettlementSummary: Equatable {
    var targetCents: Int
    var recordedCents: Int
    var outstandingCents: Int { max(0, targetCents - recordedCents) }
    var excessCents: Int { max(0, recordedCents - targetCents) }
}
