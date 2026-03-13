import Foundation
import SwiftData

@Model
public final class RehearsalMark {
    public var id: UUID
    public var label: String
    public var measureNumber: Int
    public var pageIndex: Int
    public var sortOrder: Int
    public var createdAt: Date

    public var score: Score?

    public init(label: String, measureNumber: Int, pageIndex: Int = 0, sortOrder: Int = 0) {
        self.id = UUID()
        self.label = label
        self.measureNumber = measureNumber
        self.pageIndex = pageIndex
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
