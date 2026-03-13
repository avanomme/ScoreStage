import SwiftUI

public struct GlassCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(ASSpacing.cardPadding)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous))
    }
}

#Preview {
    GlassCard {
        Text("Sample Card")
            .font(ASTypography.heading2)
    }
    .padding()
}
