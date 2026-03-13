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

    public var body: some View {
        VStack(spacing: ASSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(ASColors.tertiaryText)

            VStack(spacing: ASSpacing.sm) {
                Text(title)
                    .font(ASTypography.heading2)
                    .foregroundStyle(ASColors.primaryText)

                Text(message)
                    .font(ASTypography.body)
                    .foregroundStyle(ASColors.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                PremiumButton(actionTitle, icon: "plus", action: action)
                    .padding(.top, ASSpacing.sm)
            }
        }
        .padding(ASSpacing.xxl)
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
