import SwiftUI
import CoreDomain
import DesignSystem
import InputTrackingFeature

struct AdminFeatureAudit: Identifiable {
    let feature: ProFeature
    let isAccessible: Bool

    var id: String { feature.rawValue }
}

struct ReleaseValidationItem: Identifiable {
    let area: String
    let status: String
    let note: String

    var id: String { area }
}

struct AdminConsoleView: View {
    let activeUsername: String
    let activeRole: AccountRole
    let ownerAccount: AdminAccount?
    let subscriptionStatus: String
    let syncEnabled: Bool
    let syncStatusDescription: String
    let syncConflictCount: Int
    let backupStatusDescription: String
    let externalControlProfile: ExternalControlProfile
    let featureAudit: [AdminFeatureAudit]
    let onRefreshAuthorization: () -> Void
    let onReseedOwner: () -> Void
    let onRunSync: () -> Void
    let onCreateRestorePoint: () -> Void
    let onSignOut: () -> Void

    private let releaseValidationItems: [ReleaseValidationItem] = [
        .init(area: "Reader QA", status: "Verify", note: "Needs long-session real-device validation."),
        .init(area: "Linked Devices", status: "Verify", note: "Needs reconnect, drift, and role-switch soak testing."),
        .init(area: "Cloud / Backup Failure Paths", status: "Verify", note: "Needs destructive restore and conflict-path validation."),
        .init(area: "Head Tracking", status: "Verify", note: "Services exist but need permissions and device validation."),
        .init(area: "Eye Gaze", status: "Verify", note: "Needs accessibility and device compatibility validation."),
        .init(area: "Microphone Score Following", status: "Verify", note: "Needs product-level workflow validation."),
        .init(area: "MIDI Practice Workflow", status: "Finish", note: "Needs final practice UX shaping."),
        .init(area: "Handoff", status: "Finish", note: "Needs user-facing restore and QA."),
        .init(area: "Score Families", status: "Finish", note: "Needs explicit part-management workflow review.")
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    consoleRow("Active Account", value: activeUsername)
                    consoleRow("Role", value: activeRole.displayName)
                    consoleRow("Access Policy", value: subscriptionStatus)
                    consoleRow("Owner Account", value: ownerAccount?.username ?? AccountBootstrap.ownerUsername)
                    consoleRow("Last Auth", value: lastAuthenticatedLabel)
                }

                Section("Feature Gates") {
                    ForEach(featureAudit) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.feature.displayName)
                                    .font(ASTypography.body)
                                Text(item.feature.rawValue)
                                    .font(ASTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(item.isAccessible ? "Allowed" : "Blocked")
                                .font(ASTypography.caption)
                                .foregroundStyle(item.isAccessible ? .green : .orange)
                        }
                    }
                }

                Section("Operations") {
                    consoleRow("Sync Enabled", value: syncEnabled ? "Yes" : "No")
                    consoleRow("Sync Status", value: syncStatusDescription)
                    consoleRow("Sync Conflicts", value: "\(syncConflictCount)")
                    consoleRow("Backup Status", value: backupStatusDescription)
                    consoleRow("Pedal Control", value: externalControlProfile.pedalControlEnabled ? "Enabled" : "Disabled")
                    consoleRow("MIDI Control", value: externalControlProfile.midiControlEnabled ? "Enabled" : "Disabled")
                    consoleRow("Linked Commands", value: externalControlProfile.linkedCommandPropagationEnabled ? "Enabled" : "Disabled")
                }

                Section("Release Validation") {
                    ForEach(releaseValidationItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(item.area)
                                    .font(ASTypography.body)
                                Spacer()
                                Text(item.status)
                                    .font(ASTypography.caption)
                                    .foregroundStyle(item.status == "Finish" ? .orange : ASColors.accentFallback)
                            }
                            Text(item.note)
                                .font(ASTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Actions") {
                    Button("Refresh Authorization") {
                        onRefreshAuthorization()
                    }
                    Button("Reseed Owner Account") {
                        onReseedOwner()
                    }
                    Button("Run Sync Now") {
                        onRunSync()
                    }
                    Button("Create Restore Point") {
                        onCreateRestorePoint()
                    }
                    Button("Sign Out") {
                        onSignOut()
                    }
                    .foregroundStyle(.red)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ASColors.chromeBackground)
            .navigationTitle("Admin Console")
        }
    }

    private var lastAuthenticatedLabel: String {
        guard let ownerAccount else { return "Unknown" }
        guard let lastAuthenticatedAt = ownerAccount.lastAuthenticatedAt else {
            return "Not signed in yet"
        }

        if lastAuthenticatedAt == .distantPast {
            return "Not signed in yet"
        }

        return lastAuthenticatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func consoleRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(ASTypography.body)
            Spacer()
            Text(value)
                .font(ASTypography.bodySmall)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}
