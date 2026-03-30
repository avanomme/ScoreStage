import SwiftUI
import CoreDomain
import DesignSystem
import SyncFeature
import LibraryFeature
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultDisplayMode") private var defaultDisplayMode = "singlePage"
    @AppStorage("defaultPaperTheme") private var defaultPaperTheme = "light"
    @AppStorage("tapZoneWidth") private var tapZoneWidth = 0.5
    @AppStorage("isHalfPageTurnEnabled") private var isHalfPageTurnEnabled = false
    @AppStorage("isSyncEnabled") private var isSyncEnabled = false
    @State private var syncService = CloudKitSyncService()
    @State private var backupService: BackupRestoreService?
    @State private var backupMessage: String?
    @State private var showingBackupImporter = false
    @State private var restoreStrategy: BackupRestoreService.RestoreStrategy = .merge

    var body: some View {
        Form {
            Section("Display") {
                Picker("Default View Mode", selection: $defaultDisplayMode) {
                    Text("Single Page").tag("singlePage")
                    Text("Horizontal").tag("horizontalPaged")
                    Text("Vertical Scroll").tag("verticalScroll")
                    Text("Two Page Spread").tag("twoPageSpread")
                }

                Picker("Paper Style", selection: $defaultPaperTheme) {
                    Text("White").tag("light")
                    Text("Cream").tag("sepia")
                    Text("Warm").tag("warm")
                    Text("High Contrast").tag("highContrast")
                }
            }

            Section("Page Turning") {
                HStack {
                    Text("Forward Tap Zone")
                        .font(ASTypography.body)
                    Slider(value: $tapZoneWidth, in: 0.3...0.8)
                    Text("\(Int(tapZoneWidth * 100))%")
                        .font(ASTypography.monoSmall)
                        .foregroundStyle(.secondary)
                        .frame(width: 40)
                }
                Toggle("Half-Page Turn", isOn: $isHalfPageTurnEnabled)
            }

            Section("Sync") {
                Toggle("iCloud Sync", isOn: $isSyncEnabled)
                Text(syncService.statusDescription)
                    .font(ASTypography.caption)
                    .foregroundStyle(.secondary)

                Button("Sync Now") {
                    Task {
                        syncService.isEnabled = isSyncEnabled
                        await syncService.syncNow(modelContext: modelContext)
                    }
                }
                .disabled(!isSyncEnabled)

                if !syncService.pendingConflicts.isEmpty {
                    Text("\(syncService.pendingConflicts.count) sync conflict(s) need review from the latest imported mirror.")
                        .font(ASTypography.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Backup & Restore") {
                Picker("Restore Strategy", selection: $restoreStrategy) {
                    ForEach(BackupRestoreService.RestoreStrategy.allCases) { strategy in
                        Text(strategy.label).tag(strategy)
                    }
                }

                Button("Export Full Backup") {
                    Task { await exportBackup() }
                }

                Button("Create Restore Point") {
                    Task { await createRestorePoint() }
                }

                Button("Import Backup Package") {
                    showingBackupImporter = true
                }

                if let backupService {
                    Text(backupStatusText(for: backupService.state))
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Storage") {
                StorageInfoRow()
            }

            Section("About") {
                HStack {
                    Text("Version")
                        .font(ASTypography.body)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                        .font(ASTypography.body)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeBackground)
        .navigationTitle("Settings")
        .task {
            if backupService == nil {
                backupService = BackupRestoreService(modelContext: modelContext)
            }
            syncService.isEnabled = isSyncEnabled
        }
        .onChange(of: isSyncEnabled) { _, newValue in
            syncService.isEnabled = newValue
        }
        .fileImporter(
            isPresented: $showingBackupImporter,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await importBackup(from: url) }
        }
        .alert("Backup Status", isPresented: Binding(
            get: { backupMessage != nil },
            set: { if !$0 { backupMessage = nil } }
        )) {
            Button("OK") { backupMessage = nil }
        } message: {
            if let backupMessage {
                Text(backupMessage)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func exportBackup() async {
        guard let backupService else { return }
        do {
            let destination = defaultBackupDirectory()
            let url = try await backupService.exportBackup(to: destination)
            backupMessage = "Backup exported to \(url.path)"
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func createRestorePoint() async {
        guard let backupService else { return }
        do {
            let url = try await backupService.createRestorePoint()
            backupMessage = "Restore point created at \(url.path)"
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func importBackup(from url: URL) async {
        guard let backupService else { return }
        do {
            try await backupService.importBackup(from: url, strategy: restoreStrategy)
            backupMessage = "Backup import completed."
        } catch {
            backupMessage = error.localizedDescription
        }
    }

    private func defaultBackupDirectory() -> URL {
        #if os(macOS)
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        #endif
    }

    private func backupStatusText(for state: BackupRestoreService.BackupState) -> String {
        switch state {
        case .idle:
            return "No backup task running."
        case .exporting(let progress):
            return "Exporting \(Int(progress * 100))%"
        case .importing(let progress):
            return "Importing \(Int(progress * 100))%"
        case .completed(let url):
            return url?.lastPathComponent ?? "Completed"
        case .error(let message):
            return message
        }
    }
}

struct StorageInfoRow: View {
    @State private var storageSize = "Calculating..."

    var body: some View {
        HStack {
            Text("Library Size")
                .font(ASTypography.body)
            Spacer()
            Text(storageSize)
                .font(ASTypography.bodySmall)
                .foregroundStyle(.secondary)
        }
        .task {
            storageSize = await calculateStorageSize()
        }
    }

    private nonisolated func calculateStorageSize() async -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let dir = appSupport?.appendingPathComponent("ImportedScores") else { return "N/A" }
        guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return "0 B" }
        var total: Int64 = 0
        for fileURL in contents {
            let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }
}
