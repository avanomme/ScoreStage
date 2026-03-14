import SwiftUI
import CoreDomain
import DesignSystem

struct SettingsView: View {
    @AppStorage("defaultDisplayMode") private var defaultDisplayMode = "singlePage"
    @AppStorage("defaultPaperTheme") private var defaultPaperTheme = "light"
    @AppStorage("tapZoneWidth") private var tapZoneWidth = 0.5
    @AppStorage("isHalfPageTurnEnabled") private var isHalfPageTurnEnabled = false
    @AppStorage("isSyncEnabled") private var isSyncEnabled = false

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
                    Slider(value: $tapZoneWidth, in: 0.3...0.8)
                    Text("\(Int(tapZoneWidth * 100))%")
                        .font(ASTypography.mono)
                        .frame(width: 40)
                }
                Toggle("Half-Page Turn", isOn: $isHalfPageTurnEnabled)
            }

            Section("Sync") {
                Toggle("iCloud Sync", isOn: $isSyncEnabled)
                Text("Sync your library, setlists, and bookmarks across devices.")
                    .font(ASTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Storage") {
                StorageInfoRow()
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

struct StorageInfoRow: View {
    @State private var storageSize = "Calculating..."

    var body: some View {
        HStack {
            Text("Library Size")
            Spacer()
            Text(storageSize)
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
