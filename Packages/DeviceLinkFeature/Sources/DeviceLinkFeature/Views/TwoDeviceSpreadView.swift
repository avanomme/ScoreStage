import SwiftUI
import DesignSystem

/// Manages the two-device page spread — this device shows either the left or right page.
/// Navigation is synced via the DeviceLinkService.
public struct TwoDeviceSpreadView<PageContent: View>: View {
    @Bindable var linkService: DeviceLinkService
    let pageCount: Int
    let pageContent: (Int) -> PageContent

    public init(
        linkService: DeviceLinkService,
        pageCount: Int,
        @ViewBuilder pageContent: @escaping (Int) -> PageContent
    ) {
        self.linkService = linkService
        self.pageCount = pageCount
        self.pageContent = pageContent
    }

    /// Which page index this device should display.
    private var displayPageIndex: Int {
        let base = linkService.currentPageIndex
        switch linkService.localRole {
        case .primary:
            // Primary shows the left page (even index)
            return base
        case .secondary:
            // Secondary shows the right page (odd index)
            return min(base + 1, pageCount - 1)
        default:
            return base
        }
    }

    public var body: some View {
        ZStack {
            if displayPageIndex < pageCount {
                pageContent(displayPageIndex)
            } else {
                // Beyond last page
                VStack(spacing: ASSpacing.md) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Text("End of score")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            // Role indicator overlay
            VStack {
                Spacer()
                HStack {
                    roleIndicator
                    Spacer()
                }
                .padding(ASSpacing.md)
            }
        }
    }

    private var roleIndicator: some View {
        HStack(spacing: ASSpacing.xs) {
            Image(systemName: linkService.localRole == .primary ? "rectangle.lefthalf.filled" : "rectangle.righthalf.filled")
                .font(.system(size: 10))
            Text(linkService.localRole == .primary ? "Left Page" : "Right Page")
                .font(.system(size: 10, weight: .medium))
            Text("p. \(displayPageIndex + 1)")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, ASSpacing.sm)
        .padding(.vertical, ASSpacing.xs)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - Spread Session Controller

/// Coordinates two-device spread: handles page turn sync, role negotiation.
extension DeviceLinkService {
    /// Navigate to next spread (advance by 2 pages for spread mode).
    public func nextSpread() {
        let newPage = min(currentPageIndex + 2, Int.max)
        sendPageChange(to: newPage)
    }

    /// Navigate to previous spread.
    public func previousSpread() {
        let newPage = max(currentPageIndex - 2, 0)
        sendPageChange(to: newPage)
    }

    /// Assign roles for two-device spread.
    public func configureSpreadRoles() {
        localRole = .primary
        displayMode = .twoPageSpread
        // Send role assignment to connected peer
        sendMessage(.roleAssignment(role: DeviceRole.secondary.rawValue))
        sendMessage(.displayModeChanged(mode: LinkedDisplayMode.twoPageSpread.rawValue))
    }
}
