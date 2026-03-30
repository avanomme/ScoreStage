import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(ASSpacing.cardPadding)
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.07),
                        ASColors.chromeSurfaceElevated.opacity(0.96),
                        ASColors.chromeSurface.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.14),
                                ASColors.chromeBorder
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            )
            .shadow(color: .black.opacity(0.16), radius: 14, y: 8)
    }
}

#Preview {
    GlassCard {
        Text("Sample Card")
            .font(ASTypography.heading2)
    }
    .padding()
}
