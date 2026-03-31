// PaywallView — Pro upgrade screen with subscription options.

import SwiftUI
import StoreKit
import DesignSystem

/// Premium paywall screen showing Pro features and purchase options.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let storeService: StoreService
    @State private var selectedProductID: String?

    var body: some View {
        ScrollView {
            VStack(spacing: ASSpacing.xxl) {
                // Header
                VStack(spacing: ASSpacing.md) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 48, weight: .thin))
                        .foregroundStyle(ASColors.accentFallback)

                    Text("ScoreStage Pro")
                        .font(ASTypography.displaySmall)
                        .foregroundStyle(.primary)

                    Text("Unlock the full power of your music library")
                        .font(ASTypography.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: ASSpacing.sm) {
                        paywallBadge("Unlimited Library", icon: "books.vertical.fill")
                        paywallBadge("Playback Studio", icon: "waveform.circle.fill")
                        paywallBadge("Linked Devices", icon: "rectangle.on.rectangle.circle.fill")
                    }
                }
                .padding(.top, ASSpacing.xxl)

                // Feature list
                VStack(alignment: .leading, spacing: ASSpacing.md) {
                    featureRow("Unlimited score imports", icon: "doc.on.doc")
                    featureRow("Notation playback with mixer", icon: "play.circle")
                    featureRow("Head & eye tracking page turns", icon: "face.smiling")
                    featureRow("iCloud sync across devices", icon: "icloud")
                    featureRow("Device linking & mirrored display", icon: "rectangle.on.rectangle")
                    featureRow("Score following (microphone/MIDI)", icon: "waveform")
                    featureRow("Export annotated PDFs", icon: "square.and.arrow.up")
                }
                .padding(.horizontal, ASSpacing.lg)
                .accessibleCard("Pro features list", hint: "Shows the capabilities unlocked with ScoreStage Pro.")

                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text("Why musicians upgrade")
                        .font(ASTypography.heading3)
                        .foregroundStyle(.primary)

                    Text("Keep every chart in one library, rehearse with synced playback, and run shows across linked devices without rebuilding your workflow.")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ASSpacing.lg)

                // Purchase options
                VStack(spacing: ASSpacing.md) {
                    if storeService.products.isEmpty && storeService.isLoaded {
                        Text("Products unavailable — check your App Store connection")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    ForEach(storeService.products, id: \.id) { product in
                        productCard(product)
                    }
                }
                .padding(.horizontal, ASSpacing.lg)

                // Restore
                Button("Restore Purchases") {
                    Task { await storeService.restorePurchases() }
                }
                .font(ASTypography.bodySmall)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .largeTapTarget()

                Text(storeService.subscriptionStatus)
                    .font(ASTypography.caption)
                    .foregroundStyle(.secondary)

                // Error
                if let error = storeService.errorMessage {
                    Text(error)
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.red)
                }

                // Terms
                HStack(spacing: ASSpacing.lg) {
                    Link("Terms of Use", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    Link("Privacy Policy", destination: URL(string: "https://scorestage.com/privacy")!)
                }
                .font(ASTypography.captionSmall)
                .foregroundStyle(.tertiary)
                .padding(.bottom, ASSpacing.xl)
            }
        }
        .background(ASColors.chromeBackground)
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(ASSpacing.lg)
            .largeTapTarget()
        }
        .task {
            if !storeService.isLoaded {
                await storeService.loadProducts()
                await storeService.updatePurchaseStatus()
            }
            if selectedProductID == nil {
                selectedProductID = storeService.products.first?.id
            }
        }
    }

    private func featureRow(_ text: String, icon: String) -> some View {
        HStack(spacing: ASSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(ASColors.accentFallback)
                .frame(width: 24)

            Text(text)
                .font(ASTypography.body)
                .foregroundStyle(.primary)

            Spacer()
        }
    }

    private func paywallBadge(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title)
        }
        .font(ASTypography.monoMicro)
        .foregroundStyle(ASColors.accentFallback)
        .padding(.horizontal, ASSpacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(ASColors.accentFallback.opacity(0.12))
        )
    }

    private func productCard(_ product: Product) -> some View {
        Button {
            selectedProductID = product.id
            Task { await storeService.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)

                    if let subscription = product.subscription {
                        Text(subscriptionPeriodText(subscription.subscriptionPeriod))
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("One-time purchase")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(product.displayPrice)
                        .font(ASTypography.heading3)
                        .foregroundStyle(ASColors.accentFallback)

                    if product.id == bestValueProductID {
                        Text("Best value")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(ASSpacing.lg)
            .background(ASColors.chromeSurfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                    .strokeBorder(product.id == selectedProductID ? ASColors.accentFallback : ASColors.chromeBorder, lineWidth: product.id == selectedProductID ? 1.5 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeService.isPurchasing)
        .largeTapTarget()
        .accessibleCard("\(product.displayName), \(product.displayPrice)", hint: "Double tap to purchase or subscribe.")
    }

    private var bestValueProductID: String? {
        storeService.products.first(where: { $0.id == "com.scorestage.pro.yearly" })?.id
    }

    private func subscriptionPeriodText(_ period: Product.SubscriptionPeriod) -> String {
        switch period.unit {
        case .month: period.value == 1 ? "Billed monthly" : "Billed every \(period.value) months"
        case .year: period.value == 1 ? "Billed annually" : "Billed every \(period.value) years"
        case .week: "Billed weekly"
        case .day: "Billed daily"
        @unknown default: ""
        }
    }
}
