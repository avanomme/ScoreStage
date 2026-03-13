import Foundation
import SwiftData

@Model
public final class Bookmark {
    public var id: UUID
    public var name: String
    public var pageIndex: Int
    public var sortOrder: Int
    public var colorHex: String
    public var createdAt: Date

    public var score: Score?

    public init(name: String, pageIndex: Int, sortOrder: Int = 0, colorHex: String = "#007AFF") {
        self.id = UUID()
        self.name = name
        self.pageIndex = pageIndex
        self.sortOrder = sortOrder
        self.colorHex = colorHex
        self.createdAt = Date()
    }
}
