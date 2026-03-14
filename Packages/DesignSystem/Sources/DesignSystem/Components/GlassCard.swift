import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(ASSpacing.cardPadding)
            .background(ASColors.chromeSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                    .strokeBorder(ASColors.chromeBorder, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 8, y: 3)
    }
}

#Preview {
    GlassCard {
        Text("Sample Card")
            .font(ASTypography.heading2)
    }
    .padding()
}
