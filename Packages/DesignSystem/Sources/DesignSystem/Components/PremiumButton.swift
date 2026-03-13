import SwiftUI

public enum PremiumButtonStyle {
    case primary
    case secondary
    case ghost
}

public struct PremiumButton: View {
    private let title: String
    private let icon: String?
    private let style: PremiumButtonStyle
    private let action: () -> Void

    public init(
        _ title: String,
        icon: String? = nil,
        style: PremiumButtonStyle = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: ASSpacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                }
                Text(title)
                    .font(ASTypography.label)
            }
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.md)
            .frame(maxWidth: style == .primary ? .infinity : nil)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: ASColors.accentFallback
        case .ghost: ASColors.primaryText
        }
    }

    private var backgroundColor: some ShapeStyle {
        switch style {
        case .primary: AnyShapeStyle(ASColors.accentFallback)
        case .secondary: AnyShapeStyle(ASColors.accentFallback.opacity(0.12))
        case .ghost: AnyShapeStyle(Color.clear)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        PremiumButton("Import Score", icon: "plus", style: .primary) {}
        PremiumButton("Cancel", style: .secondary) {}
        PremiumButton("Skip", style: .ghost) {}
    }
    .padding()
}
