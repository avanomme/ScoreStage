import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

@main
struct ScoreStageApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(ASColors.chromeBackground)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView {
                        showOnboarding = false
                    }
                    .preferredColorScheme(.dark)
                }
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        #endif
        .modelContainer(for: [
            Score.self,
            ScoreAsset.self,
            AnnotationLayer.self,
            AnnotationStroke.self,
            AnnotationObject.self,
            SetList.self,
            SetListItem.self,
            Bookmark.self,
            JumpLink.self,
            PlaybackProfile.self,
            ScoreFamily.self,
            RehearsalMark.self,
            SyncRecord.self,
            UserPreference.self,
        ])
    }
}
