import SwiftUI

public struct EmptyStateView: View {
    private let icon: String
    private let title: String
    private let message: String
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    @State private var appeared = false

    public var body: some View {
        VStack(spacing: ASSpacing.lg) {
            // Icon — 48pt, .light, animated pulse
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ASColors.tertiaryText)
                .symbolEffect(.pulse.byLayer, options: .repeating.speed(0.5), value: appeared)
                .scaleEffect(appeared ? 1.0 : 0.85)
                .opacity(appeared ? 1.0 : 0.0)

            VStack(spacing: ASSpacing.sm) {
                Text(title)
                    .font(ASTypography.heading2)
                    .foregroundStyle(ASColors.primaryText)

                Text(message)
                    .font(ASTypography.body)
                    .foregroundStyle(ASColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 10)

            if let actionTitle, let action {
                PremiumButton(actionTitle, icon: "plus", action: action)
                    .padding(.top, ASSpacing.sm)
                    .opacity(appeared ? 1.0 : 0.0)
                    .offset(y: appeared ? 0 : 10)
            }
        }
        .frame(maxWidth: 320)
        .padding(ASSpacing.xxl)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                appeared = true
            }
        }
    }
}

#Preview {
    EmptyStateView(
        icon: "music.note.list",
        title: "No Scores Yet",
        message: "Import your sheet music to get started.",
        actionTitle: "Import Score"
    ) {}
}
