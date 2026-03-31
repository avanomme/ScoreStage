// OnboardingView — Premium first-launch experience with feature highlights and setup.

import SwiftUI
import DesignSystem

/// Multi-step onboarding shown on first launch. Highlights key features
/// and guides the user through importing their first score.
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @State private var showingPaywall = false
    @State private var storeService = StoreService()

    let onComplete: () -> Void

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "music.note.list",
            title: "Your Sheet Music,\nElevated",
            subtitle: "A professional-grade score reader built for performers, teachers, and conductors.",
            accent: true
        ),
        OnboardingPage(
            icon: "doc.richtext",
            title: "Import & Organize",
            subtitle: "Import PDFs from Files, iCloud, or drag and drop. Organize with collections, tags, and smart search.",
            accent: false
        ),
        OnboardingPage(
            icon: "pencil.and.outline",
            title: "Annotate with Precision",
            subtitle: "Mark up scores with pen, highlighter, stamps, and text. Multiple layers for teacher, performer, and rehearsal notes.",
            accent: false
        ),
        OnboardingPage(
            icon: "play.circle",
            title: "Playback & Practice",
            subtitle: "Play back MusicXML scores with tempo control, looping, transposition, and a per-part mixer.",
            accent: false
        ),
        OnboardingPage(
            icon: "hand.raised",
            title: "Hands-Free Turning",
            subtitle: "Turn pages with head movement, eye gaze, Bluetooth pedals, or tap zones. Calibrate for your performance setup.",
            accent: false
        ),
    ]

    var body: some View {
        ZStack {
            ASColors.chromeBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page)
                            .tag(index)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                .animation(.easeInOut(duration: 0.25), value: currentPage)

                Spacer()

                // Page indicator
                HStack(spacing: ASSpacing.sm) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? ASColors.accentFallback : ASColors.chromeBorderStrong)
                            .frame(width: index == currentPage ? 8 : 6, height: index == currentPage ? 8 : 6)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }
                .padding(.bottom, ASSpacing.xl)

                // Actions
                VStack(spacing: ASSpacing.md) {
                    if currentPage == pages.count - 1 {
                        PremiumButton("Start Free Library", icon: "arrow.right", style: .primary) {
                            completeOnboarding(trackProIntent: false)
                        }
                        .largeTapTarget()
                        .accessibilityLabel("Start free library")
                        .accessibilityHint("Finish onboarding and open your library.")

                        PremiumButton("Explore Pro", icon: "star.circle", style: .secondary) {
                            showingPaywall = true
                        }
                        .largeTapTarget()
                        .accessibilityLabel("Explore ScoreStage Pro")
                        .accessibilityHint("Review paid features and subscription options.")
                    } else {
                        PremiumButton("Continue", style: .primary) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .largeTapTarget()
                        .accessibilityHint("Move to the next onboarding page.")
                    }

                    if currentPage < pages.count - 1 {
                        Button("Skip") {
                            completeOnboarding(trackProIntent: false)
                        }
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                        .largeTapTarget()
                    }
                }
                .padding(.horizontal, ASSpacing.xl)
                .padding(.bottom, ASSpacing.xxxl)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView(storeService: storeService)
        }
    }

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: ASSpacing.xl) {
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(page.accent ? ASColors.accentFallback : .secondary)
                .frame(height: 80)

            // Title
            Text(page.title)
                .font(ASTypography.displaySmall)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            // Subtitle
            Text(page.subtitle)
                .font(ASTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .frame(maxWidth: 320)

            if currentPage == pages.count - 1 {
                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    onboardingChecklistRow(title: "Import up to 5 scores free", icon: "checkmark.circle.fill")
                    onboardingChecklistRow(title: "Upgrade later for unlimited library, sync, and playback tools", icon: "star.circle.fill")
                    onboardingChecklistRow(title: "Your annotations, setlists, and backups stay on-device by default", icon: "lock.shield.fill")
                }
                .padding(ASSpacing.lg)
                .background(ASColors.chromeSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
                .frame(maxWidth: 420)
                .accessibleCard("Onboarding checklist. Import five scores free. Upgrade later for unlimited library, sync and playback tools. Data stays on device by default.", hint: "Summary of the free and pro experience.")
            }
        }
        .padding(.horizontal, ASSpacing.xl)
    }

    private func onboardingChecklistRow(title: String, icon: String) -> some View {
        HStack(spacing: ASSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(ASColors.accentFallback)
            Text(title)
                .font(ASTypography.bodySmall)
                .foregroundStyle(.primary)
            Spacer()
        }
    }

    private func completeOnboarding(trackProIntent: Bool) {
        hasCompletedOnboarding = true
        if trackProIntent {
            UserDefaults.standard.set(true, forKey: "hasSeenPaywallFromOnboarding")
        }
        onComplete()
    }
}

// MARK: - Onboarding Page Model

private struct OnboardingPage {
    let icon: String
    let title: String
    let subtitle: String
    let accent: Bool
}
