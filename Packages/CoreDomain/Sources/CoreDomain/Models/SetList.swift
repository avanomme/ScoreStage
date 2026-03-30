import Foundation
import SwiftData

public enum SetlistTransitionStyle: String, Codable, CaseIterable, Sendable {
    case manual
    case segue
    case timedPause
    case autoAdvance
}

public struct SetlistPerformancePreset: Codable, Sendable, Equatable {
    public var startPageIndex: Int
    public var preferredDisplayMode: DisplayMode?
    public var preferredPaperTheme: PaperTheme?
    public var preferredPageTurnBehavior: PageTurnBehavior?
    public var opensInPerformanceMode: Bool
    public var requiresLinkedMode: Bool

    public init(
        startPageIndex: Int = 0,
        preferredDisplayMode: DisplayMode? = nil,
        preferredPaperTheme: PaperTheme? = nil,
        preferredPageTurnBehavior: PageTurnBehavior? = nil,
        opensInPerformanceMode: Bool = true,
        requiresLinkedMode: Bool = false
    ) {
        self.startPageIndex = max(0, startPageIndex)
        self.preferredDisplayMode = preferredDisplayMode
        self.preferredPaperTheme = preferredPaperTheme
        self.preferredPageTurnBehavior = preferredPageTurnBehavior
        self.opensInPerformanceMode = opensInPerformanceMode
        self.requiresLinkedMode = requiresLinkedMode
    }
}

@Model
public final class SetList {
    public var id: UUID
    public var name: String
    public var eventDescription: String
    public var eventDate: Date?
    public var performanceNotes: String
    public var stageNotes: String
    public var createdAt: Date
    public var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SetListItem.setList)
    public var items: [SetListItem]

    public init(
        name: String,
        eventDescription: String = "",
        performanceNotes: String = "",
        stageNotes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.eventDescription = eventDescription
        self.performanceNotes = performanceNotes
        self.stageNotes = stageNotes
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.items = []
    }
}

@Model
public final class SetListItem {
    public var id: UUID
    public var sortOrder: Int
    public var performanceNotes: String
    public var cueTitle: String
    public var cueNotes: String
    public var pauseDuration: TimeInterval
    public var pauseNotes: String
    public var transitionStyle: SetlistTransitionStyle
    public var medleyTitle: String
    public var autoAdvanceDelay: TimeInterval
    public var performancePreset: SetlistPerformancePreset?
    public var createdAt: Date

    public var setList: SetList?
    public var score: Score?

    public init(
        sortOrder: Int,
        performanceNotes: String = "",
        cueTitle: String = "",
        cueNotes: String = "",
        pauseDuration: TimeInterval = 0,
        pauseNotes: String = "",
        transitionStyle: SetlistTransitionStyle = .manual,
        medleyTitle: String = "",
        autoAdvanceDelay: TimeInterval = 0,
        performancePreset: SetlistPerformancePreset? = nil
    ) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.performanceNotes = performanceNotes
        self.cueTitle = cueTitle
        self.cueNotes = cueNotes
        self.pauseDuration = pauseDuration
        self.pauseNotes = pauseNotes
        self.transitionStyle = transitionStyle
        self.medleyTitle = medleyTitle
        self.autoAdvanceDelay = autoAdvanceDelay
        self.performancePreset = performancePreset
        self.createdAt = Date()
    }
}
