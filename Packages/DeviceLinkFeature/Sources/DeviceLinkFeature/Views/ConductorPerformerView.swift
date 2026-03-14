import SwiftUI
import DesignSystem

/// Conductor/performer mirrored display mode.
/// Conductor controls navigation; performer follows with optional annotation visibility settings.
public struct ConductorPerformerView<PageContent: View>: View {
    @Bindable var linkService: DeviceLinkService
    let pageCount: Int
    let scoreTitle: String
    let pageContent: (Int) -> PageContent

    public init(
        linkService: DeviceLinkService,
        pageCount: Int,
        scoreTitle: String,
        @ViewBuilder pageContent: @escaping (Int) -> PageContent
    ) {
        self.linkService = linkService
        self.pageCount = pageCount
        self.scoreTitle = scoreTitle
        self.pageContent = pageContent
    }

    private var isConductor: Bool {
        linkService.localRole == .conductor
    }

    public var body: some View {
        ZStack {
            // Page content
            if linkService.currentPageIndex < pageCount {
                pageContent(linkService.currentPageIndex)
            }

            // Mode indicator + controls overlay
            VStack {
                topBar
                Spacer()
                if isConductor {
                    conductorControls
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // Role badge
            HStack(spacing: ASSpacing.xs) {
                Image(systemName: isConductor ? "person.wave.2" : "music.note")
                    .font(.system(size: 11, weight: .medium))
                Text(isConductor ? "Conductor" : "Performer")
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, ASSpacing.xs)
            .background(isConductor ? ASColors.accentFallback.opacity(0.15) : Color.blue.opacity(0.15))
            .clipShape(Capsule())

            Spacer()

            // Connection status
            HStack(spacing: ASSpacing.xs) {
                Circle()
                    .fill(linkService.connectedPeers.isEmpty ? Color.orange : ASColors.success)
                    .frame(width: 6, height: 6)
                Text("\(linkService.connectedPeers.count) linked")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            // Page indicator
            Text("\(linkService.currentPageIndex + 1) / \(pageCount)")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, ASSpacing.sm)
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
        .background(.ultraThinMaterial)
    }

    // MARK: - Conductor Controls

    private var conductorControls: some View {
        HStack(spacing: ASSpacing.xl) {
            Button {
                let newPage = max(linkService.currentPageIndex - 1, 0)
                linkService.sendPageChange(to: newPage)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(linkService.currentPageIndex <= 0)

            Text("Page \(linkService.currentPageIndex + 1)")
                .font(.system(size: 13, weight: .medium, design: .monospaced))

            Button {
                let newPage = min(linkService.currentPageIndex + 1, pageCount - 1)
                linkService.sendPageChange(to: newPage)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(linkService.currentPageIndex >= pageCount - 1)
        }
        .padding(.horizontal, ASSpacing.xl)
        .padding(.vertical, ASSpacing.md)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
        .padding(.horizontal, ASSpacing.xl)
        .padding(.bottom, ASSpacing.lg)
    }
}

// MARK: - Conductor/Performer Session Setup

extension DeviceLinkService {
    /// Configure this device as the conductor.
    public func configureConductorMode() {
        localRole = .conductor
        displayMode = .conductorPerformer
        sendMessage(.roleAssignment(role: DeviceRole.performer.rawValue))
        sendMessage(.displayModeChanged(mode: LinkedDisplayMode.conductorPerformer.rawValue))
    }

    /// Configure this device as a performer (follower).
    public func configurePerformerMode() {
        localRole = .performer
        displayMode = .conductorPerformer
    }
}
