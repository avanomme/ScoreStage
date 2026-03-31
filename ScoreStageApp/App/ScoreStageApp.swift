import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

@main
struct ScoreStageApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(AccountSessionStorage.usernameKey) private var activeAccountUsername = ""
    @State private var showOnboarding = false
    @State private var showLogin = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(ASColors.chromeBackground)
                #if os(iOS)
                .fullScreenCover(isPresented: $showLogin) {
                    AccountLoginView {
                        showLogin = false
                        if !hasCompletedOnboarding {
                            showOnboarding = true
                        }
                    }
                    .preferredColorScheme(.dark)
                }
                #else
                .sheet(isPresented: $showLogin) {
                    AccountLoginView {
                        showLogin = false
                        if !hasCompletedOnboarding {
                            showOnboarding = true
                        }
                    }
                    .preferredColorScheme(.dark)
                    .frame(minWidth: 480, minHeight: 520)
                }
                #endif
                #if os(iOS)
                .fullScreenCover(isPresented: $showOnboarding) {
                    OnboardingView { showOnboarding = false }
                        .preferredColorScheme(.dark)
                }
                #else
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView { showOnboarding = false }
                        .preferredColorScheme(.dark)
                        .frame(minWidth: 500, minHeight: 600)
                }
                #endif
                .onAppear {
                    if activeAccountUsername.isEmpty {
                        showLogin = true
                    } else if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .onChange(of: activeAccountUsername) { _, newValue in
                    if newValue.isEmpty {
                        showOnboarding = false
                        showLogin = true
                    } else {
                        showLogin = false
                    }
                }
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1200, height: 800)
        #endif
        .modelContainer(for: [
            AdminAccount.self,
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
