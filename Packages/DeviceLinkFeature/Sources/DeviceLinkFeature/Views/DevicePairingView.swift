import SwiftUI
import DesignSystem

/// Device pairing UI — discover nearby devices, connect, and assign roles.
public struct DevicePairingView: View {
    @Bindable var linkService: DeviceLinkService
    @Environment(\.dismiss) private var dismiss

    public init(linkService: DeviceLinkService) {
        self.linkService = linkService
    }

    public var body: some View {
        VStack(spacing: ASSpacing.lg) {
            // Header
            HStack {
                Text("Link Devices")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            // Status
            statusSection

            // Connected devices
            if !linkService.connectedPeers.isEmpty {
                connectedSection
            }

            // Discovered devices
            if !linkService.discoveredPeers.isEmpty {
                discoveredSection
            }

            // Scanning indicator
            if linkService.isBrowsing && linkService.discoveredPeers.isEmpty {
                VStack(spacing: ASSpacing.sm) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning for nearby devices...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(ASSpacing.lg)
            }

            Spacer()

            // Action buttons
            actionButtons
        }
        .padding(ASSpacing.lg)
        .frame(minWidth: 280, minHeight: 360)
    }

    // MARK: - Sections

    private var statusSection: some View {
        HStack(spacing: ASSpacing.sm) {
            Circle()
                .fill(linkService.connectedPeers.isEmpty ? Color.orange : ASColors.success)
                .frame(width: 8, height: 8)
            Text(linkService.connectedPeers.isEmpty ? "No devices connected" : "\(linkService.connectedPeers.count) device(s) connected")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var connectedSection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("Connected")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(linkService.connectedPeers) { peer in
                HStack {
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 14))
                        .foregroundStyle(ASColors.success)
                    Text(peer.displayName)
                        .font(.system(size: 13))
                    Spacer()
                    Text(peer.role.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, ASSpacing.sm)
                        .padding(.vertical, ASSpacing.xxs)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                .padding(ASSpacing.sm)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
            }
        }
    }

    private var discoveredSection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("Nearby Devices")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(linkService.discoveredPeers) { peer in
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text(peer.displayName)
                        .font(.system(size: 13))
                    Spacer()
                    Button("Connect") {
                        linkService.invitePeer(peer)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundStyle(ASColors.accentFallback)
                }
                .padding(ASSpacing.sm)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
            }
        }
    }

    // MARK: - Actions

    private var actionButtons: some View {
        HStack(spacing: ASSpacing.md) {
            if linkService.isBrowsing || linkService.isAdvertising {
                Button {
                    linkService.stopBrowsing()
                    linkService.stopAdvertising()
                } label: {
                    Text("Stop Scanning")
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ASSpacing.sm)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    linkService.startAdvertising()
                    linkService.startBrowsing()
                } label: {
                    Text("Start Scanning")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ASSpacing.sm)
                        .background(ASColors.accentFallback)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if !linkService.connectedPeers.isEmpty {
                Button {
                    linkService.disconnect()
                } label: {
                    Text("Disconnect")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
