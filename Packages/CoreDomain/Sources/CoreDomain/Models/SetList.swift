import Foundation
import SwiftData

@Model
public final class SetList {
    public var id: UUID
    public var name: String
    public var eventDescription: String
    public var eventDate: Date?
    public var createdAt: Date
    public var modifiedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \SetListItem.setList)
    public var items: [SetListItem]

    public init(name: String, eventDescription: String = "") {
        self.id = UUID()
        self.name = name
        self.eventDescription = eventDescription
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
    public var pauseDuration: TimeInterval
    public var createdAt: Date

    public var setList: SetList?
    public var score: Score?

    public init(sortOrder: Int, performanceNotes: String = "", pauseDuration: TimeInterval = 0) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.performanceNotes = performanceNotes
        self.pauseDuration = pauseDuration
        self.createdAt = Date()
    }
}
