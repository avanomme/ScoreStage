import Foundation
import SwiftData

@Model
public final class Score {
    public var id: UUID
    public var title: String
    public var composer: String
    public var arranger: String
    public var genre: String
    public var key: String
    public var instrumentation: String
    public var difficulty: Int
    public var duration: TimeInterval
    public var notes: String
    public var isFavorite: Bool
    public var isArchived: Bool
    public var customTags: [String]
    public var createdAt: Date
    public var modifiedAt: Date
    public var lastOpenedAt: Date?
    public var lastPerformedAt: Date?
    public var pageCount: Int
    public var fileHash: String

    @Relationship(deleteRule: .cascade, inverse: \ScoreAsset.score)
    public var assets: [ScoreAsset]

    @Relationship(deleteRule: .cascade, inverse: \AnnotationLayer.score)
    public var annotationLayers: [AnnotationLayer]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.score)
    public var bookmarks: [Bookmark]

    @Relationship(deleteRule: .nullify, inverse: \SetListItem.score)
    public var setListItems: [SetListItem]

    @Relationship(deleteRule: .cascade, inverse: \JumpLink.score)
    public var jumpLinks: [JumpLink]

    @Relationship(deleteRule: .cascade, inverse: \PlaybackProfile.score)
    public var playbackProfiles: [PlaybackProfile]

    @Relationship(deleteRule: .nullify, inverse: \ScoreFamily.scores)
    public var family: ScoreFamily?

    @Relationship(deleteRule: .cascade, inverse: \RehearsalMark.score)
    public var rehearsalMarks: [RehearsalMark]

    public var viewingPreferences: ViewingPreferences?

    public init(
        title: String,
        composer: String = "",
        arranger: String = "",
        genre: String = "",
        key: String = "",
        instrumentation: String = "",
        difficulty: Int = 0,
        duration: TimeInterval = 0,
        notes: String = "",
        pageCount: Int = 0,
        fileHash: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.composer = composer
        self.arranger = arranger
        self.genre = genre
        self.key = key
        self.instrumentation = instrumentation
        self.difficulty = difficulty
        self.duration = duration
        self.notes = notes
        self.isFavorite = false
        self.isArchived = false
        self.customTags = []
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.pageCount = pageCount
        self.fileHash = fileHash
        self.assets = []
        self.annotationLayers = []
        self.bookmarks = []
        self.setListItems = []
        self.jumpLinks = []
        self.playbackProfiles = []
        self.rehearsalMarks = []
    }
}
