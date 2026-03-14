import SwiftUI
import CoreDomain
import DesignSystem

/// Snapshot info for UI display, decoupled from SwiftData.
public struct SnapshotInfo: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

/// Floating panel to create, browse, and restore annotation snapshots.
public struct SnapshotManagerView: View {
    @Bindable var state: AnnotationState
    @State private var isCreating = false
    @State private var newSnapshotName = ""

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            snapshotList
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Snapshots")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCreating.toggle()
                }
            } label: {
                Image(systemName: "camera")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Save Snapshot")
            .popover(isPresented: $isCreating) {
                createSnapshotPopover
            }
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Snapshot List

    private var snapshotList: some View {
        ScrollView {
            if state.snapshots.isEmpty {
                VStack(spacing: ASSpacing.sm) {
                    Image(systemName: "camera.on.rectangle")
                        .font(.system(size: 24, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("No snapshots yet")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Save your current annotations as a snapshot to restore later.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(ASSpacing.lg)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(state.snapshots) { snapshot in
                        snapshotRow(snapshot)
                        if snapshot.id != state.snapshots.last?.id {
                            Divider().padding(.leading, ASSpacing.lg)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 240)
    }

    // MARK: - Snapshot Row

    private func snapshotRow(_ snapshot: SnapshotInfo) -> some View {
        HStack(spacing: ASSpacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(snapshot.createdAt, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Restore
            Button {
                state.onRestoreSnapshot?(snapshot.id)
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ASColors.accentFallback)
            }
            .buttonStyle(.plain)
            .help("Restore")

            // Delete
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    state.removeSnapshot(snapshot.id)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Create Snapshot Popover

    private var createSnapshotPopover: some View {
        VStack(spacing: ASSpacing.md) {
            Text("Save Snapshot")
                .font(.system(size: 13, weight: .semibold))

            TextField("Snapshot Name", text: $newSnapshotName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            HStack {
                Button("Cancel") {
                    isCreating = false
                    newSnapshotName = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                Button("Save") {
                    let name = newSnapshotName.isEmpty
                        ? "Snapshot \(state.snapshots.count + 1)"
                        : newSnapshotName
                    state.createSnapshot(name: name)
                    newSnapshotName = ""
                    isCreating = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ASColors.accentFallback)
            }
        }
        .padding(ASSpacing.md)
        .frame(width: 200)
    }
}
