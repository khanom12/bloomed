import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var displayName = ""
    @State private var progressionPrompts = true
    @State private var backup: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var restorePreview: RestorePreview?
    @State private var confirmingDelete = false
    @State private var error: String?
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            Form {
                if store.isLoaded {
                    Section("Your preferences") {
                        TextField("Display name (optional)", text: $displayName).textContentType(.nickname)
                        Toggle("Offer progression prompts", isOn: $progressionPrompts)
                        Text("Your name is optional in shared summaries. Your private reason and notes aren't shared.")
                            .font(.caption).foregroundStyle(BTheme.secondary)
                    }
                }
                Section("Keep your records") {
                    Button("Export backup", systemImage: "square.and.arrow.up", action: exportBackup).disabled(!store.isLoaded)
                    Button("Restore backup", systemImage: "square.and.arrow.down") { importing = true }
                    Text("Backups include all activity and financial records. The exported file is not encrypted by Bloomed. Keep it somewhere private. Restoring replaces local records.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
                if !store.isLoaded {
                    Section("Saved records unavailable") {
                        Text("Your existing data has not been replaced. Retry opening it or restore a backup.")
                        Button("Retry opening records", action: retryLoad)
                    }
                }
                Section("About Bloomed") {
                    BBrandLockup()
                        .foregroundStyle(BTheme.accent)
                        .padding(.vertical, 4)
                        .accessibilityHidden(true)
                    Text("A walking commitment, one week at a time.")
                    Text("Manual activity records. External money and verification. Bloomed does not upload your records. Device backups may include app data according to your iOS settings.")
                        .font(.subheadline).foregroundStyle(BTheme.secondary)
                    LabeledContent("Version", value: versionLabel)
                }
                Section {
                    Button("Delete local data", role: .destructive) { confirmingDelete = true }
                    Text("Deleting app data does not cancel outside obligations or delete files you've already exported.")
                        .font(.caption).foregroundStyle(BTheme.secondary)
                }
                if let notice { Section { Text(notice).foregroundStyle(BTheme.accent) } }
                if let error { Section { BErrorText(message: error) } }
            }
            .tint(BTheme.accent).scrollContentBackground(.hidden).background(BTheme.background)
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                if store.isLoaded {
                    ToolbarItem(placement: .confirmationAction) { Button("Save", action: savePreferences) }
                }
            }
            .onAppear { displayName = store.profile.displayName; progressionPrompts = store.profile.progressionPromptsEnabled }
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Bloomed-backup") { result in
                if case .failure(let failure) = result { error = failure.localizedDescription }
                else { notice = "Backup exported. Store it securely." }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json], allowsMultipleSelection: false, onCompletion: prepareRestore)
            .sheet(item: $restorePreview) { preview in
                RestoreConfirmationView(preview: preview, completed: {
                    restorePreview = nil
                    displayName = store.profile.displayName
                    progressionPrompts = store.profile.progressionPromptsEnabled
                    notice = "Backup restored. Your saved history is available."
                })
            }
            .confirmationDialog("Delete all local Bloomed records?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Export a backup first", action: exportBackup)
                Button("Delete local data", role: .destructive, action: deleteData)
            } message: { Text("This removes plans, walking entries, and financial records from this app. Existing exports and outside obligations are unaffected.") }
        }
    }

    private var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(version) (\(build)) · First draft"
    }

    private func savePreferences() {
        do { try store.updateProfile(displayName: displayName, progressionPromptsEnabled: progressionPrompts); dismiss() }
        catch { self.error = error.localizedDescription }
    }
    private func retryLoad() {
        do { try store.retryLoad(); notice = "Records opened." }
        catch { self.error = error.localizedDescription }
    }
    private func exportBackup() {
        do { backup = BackupDocument(data: try store.exportBackup()); exporting = true }
        catch { self.error = error.localizedDescription }
    }
    private func prepareRestore(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            guard (values.fileSize ?? 0) <= 50 * 1024 * 1024 else { throw StoreError.invalid("Choose a backup smaller than 50 MB.") }
            let data = try Data(contentsOf: url)
            let envelope = try JSONDecoder().decode(BackupEnvelope.self, from: data)
            guard envelope.application == "Bloomed", envelope.schemaVersion == BloomedRule.schemaVersion else { throw StoreError.invalid("Choose a supported Bloomed backup.") }
            try StateValidator.validate(envelope.state)
            restorePreview = RestorePreview(data: data, planCount: envelope.state.plans.count,
                                            exportedAt: envelope.exportedAt, entryCount: envelope.state.stepRevisions.count)
        } catch { self.error = "Backup not opened. Existing records are unchanged. \(error.localizedDescription)" }
    }
    private func deleteData() {
        do { try store.deleteLocalData(); dismiss() }
        catch { self.error = error.localizedDescription }
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw StoreError.invalid("The backup is not a readable file.") }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct RestorePreview: Identifiable {
    let id = UUID()
    let data: Data
    let planCount: Int
    let exportedAt: Date
    let entryCount: Int
}

private struct RestoreConfirmationView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let preview: RestorePreview
    let completed: () -> Void
    @State private var replacing = false
    @State private var backup: BackupDocument?
    @State private var exporting = false
    @State private var error: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("Backup preview") {
                    LabeledContent("Weeks", value: "\(preview.planCount)")
                    LabeledContent("Entry revisions", value: "\(preview.entryCount)")
                    LabeledContent("Exported", value: preview.exportedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Section {
                    Text("Restoring replaces all current local records. This does not merge histories or move any money.")
                    if store.isLoaded { Button("Export current records first", action: exportCurrent) }
                    Button("Replace local records with this backup", role: .destructive) { replacing = true }
                    if let error { BErrorText(message: error) }
                }
            }.navigationTitle("Restore backup").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
                .confirmationDialog("Replace current local records?", isPresented: $replacing, titleVisibility: .visible) {
                    Button("Restore and replace", role: .destructive, action: restore)
                }
                .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Bloomed-before-restore") { result in
                    if case .failure(let failure) = result { error = failure.localizedDescription }
                }
        }
    }
    private func exportCurrent() {
        do { backup = BackupDocument(data: try store.exportBackup()); exporting = true }
        catch { self.error = error.localizedDescription }
    }
    private func restore() {
        do { try store.restoreBackup(preview.data); completed() }
        catch { self.error = error.localizedDescription }
    }
}
