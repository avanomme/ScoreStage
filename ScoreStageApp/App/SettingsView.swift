import SwiftUI
import CoreDomain
import DesignSystem
import SyncFeature
import LibraryFeature
import UniformTypeIdentifiers
import InputTrackingFeature

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
    @State private var externalControlProfile = ExternalControlProfile.stageDefault

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

            Section("External Controls") {
                Toggle("Bluetooth Pedal Support", isOn: binding(
                    get: \.pedalControlEnabled,
                    set: { externalControlProfile.pedalControlEnabled = $0 }
                ))
                Toggle("MIDI Control Input", isOn: binding(
                    get: \.midiControlEnabled,
                    set: { externalControlProfile.midiControlEnabled = $0 }
                ))
                Toggle("Propagate Linked Commands", isOn: binding(
                    get: \.linkedCommandPropagationEnabled,
                    set: { externalControlProfile.linkedCommandPropagationEnabled = $0 }
                ))

                externalControlPickerRow(title: "Left Pedal", selection: pedalBinding(.left))
                externalControlPickerRow(title: "Right Pedal", selection: pedalBinding(.right))
                externalControlPickerRow(title: "Center Pedal", selection: pedalBinding(.center))
                externalControlPickerRow(title: "Aux Pedal", selection: pedalBinding(.auxiliary))

                externalControlPickerRow(title: "Space Key", selection: keyboardBinding(.space))
                externalControlPickerRow(title: "Tab Key", selection: keyboardBinding(.tab))
                externalControlPickerRow(title: "Return Key", selection: keyboardBinding(.returnKey))

                ForEach(externalControlProfile.midiMappings.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: ASSpacing.xs) {
                        HStack {
                            Text("MIDI Mapping \(index + 1)")
                                .font(ASTypography.body)
                            Spacer()
                            Picker("Type", selection: midiTypeBinding(index)) {
                                ForEach(MIDIBindingType.allCases) { type in
                                    Text(type.label).tag(type)
                                }
                            }
                            .pickerStyle(.menu)
                            Stepper(value: midiValueBinding(index), in: 0...127) {
                                Text("\(externalControlProfile.midiMappings[index].value)")
                                    .font(ASTypography.monoSmall)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 120)
                        }

                        externalControlPickerRow(title: "Action", selection: midiActionBinding(index))
                    }
                    .padding(.vertical, 4)
                }

                Button("Reset External Control Defaults") {
                    externalControlProfile = .stageDefault
                    saveExternalControlProfile()
                }
                .foregroundStyle(ASColors.accentFallback)
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
            loadExternalControlProfile()
        }
        .onChange(of: isSyncEnabled) { _, newValue in
            syncService.isEnabled = newValue
        }
        .onChange(of: externalControlProfile) { _, _ in
            saveExternalControlProfile()
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

    private func loadExternalControlProfile() {
        guard let raw = UserDefaults.standard.string(forKey: ExternalControlProfileStorage.defaultsKey),
              let data = raw.data(using: .utf8),
              let profile = try? JSONDecoder().decode(ExternalControlProfile.self, from: data) else {
            externalControlProfile = .stageDefault
            return
        }
        externalControlProfile = profile
    }

    private func saveExternalControlProfile() {
        guard let data = try? JSONEncoder().encode(externalControlProfile),
              let string = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(string, forKey: ExternalControlProfileStorage.defaultsKey)
    }

    private func pedalBinding(_ role: PedalInputRole) -> Binding<ExternalControlAction> {
        Binding {
            externalControlProfile.action(for: role)
        } set: { action in
            externalControlProfile.setPedalAction(action, for: role)
        }
    }

    private func keyboardBinding(_ key: KeyboardControlKey) -> Binding<ExternalControlAction> {
        Binding {
            externalControlProfile.action(for: key)
        } set: { action in
            externalControlProfile.setKeyboardAction(action, for: key)
        }
    }

    private func midiTypeBinding(_ index: Int) -> Binding<MIDIBindingType> {
        Binding {
            externalControlProfile.midiMappings[index].type
        } set: { newValue in
            externalControlProfile.midiMappings[index].type = newValue
        }
    }

    private func midiValueBinding(_ index: Int) -> Binding<Int> {
        Binding {
            externalControlProfile.midiMappings[index].value
        } set: { newValue in
            externalControlProfile.midiMappings[index].value = max(0, min(newValue, 127))
        }
    }

    private func midiActionBinding(_ index: Int) -> Binding<ExternalControlAction> {
        Binding {
            externalControlProfile.midiMappings[index].action
        } set: { newValue in
            externalControlProfile.midiMappings[index].action = newValue
        }
    }

    private func externalControlPickerRow(title: String, selection: Binding<ExternalControlAction>) -> some View {
        Picker(title, selection: selection) {
            ForEach(ExternalControlAction.allCases) { action in
                Label(action.label, systemImage: action.systemImage).tag(action)
            }
        }
    }

    private func binding<Value>(get keyPath: KeyPath<ExternalControlProfile, Value>, set update: @escaping (Value) -> Void) -> Binding<Value> {
        Binding {
            externalControlProfile[keyPath: keyPath]
        } set: { newValue in
            update(newValue)
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
