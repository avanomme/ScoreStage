import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

@main
struct ScoreStageApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .background(ASColors.chromeBackground)
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
