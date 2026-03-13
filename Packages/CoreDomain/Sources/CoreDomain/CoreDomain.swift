// CoreDomain — shared data models and protocols for Aurelia Score
// This package contains SwiftData models and domain types used across all features.

import Foundation
import SwiftData

/// All SwiftData model types used in the app's ModelContainer.
public let allModelTypes: [any PersistentModel.Type] = [
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
]
