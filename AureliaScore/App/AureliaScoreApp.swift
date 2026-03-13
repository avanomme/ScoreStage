import SwiftUI
import SwiftData
import CoreDomain

@main
struct AureliaScoreApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
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
