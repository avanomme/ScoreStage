import Foundation
import SwiftData

public enum JumpType: String, Codable, Sendable {
    case coda
    case dalSegno
    case daCapo
    case repeatStart
    case repeatEnd
    case custom
}

@Model
public final class JumpLink {
    public var id: UUID
    public var type: JumpType
    public var label: String
    public var sourcePageIndex: Int
    public var sourceX: Double
    public var sourceY: Double
    public var destinationPageIndex: Int
    public var destinationScoreID: UUID?
    public var createdAt: Date

    public var score: Score?

    public init(
        type: JumpType,
        label: String = "",
        sourcePageIndex: Int,
        sourceX: Double = 0,
        sourceY: Double = 0,
        destinationPageIndex: Int
    ) {
        self.id = UUID()
        self.type = type
        self.label = label
        self.sourcePageIndex = sourcePageIndex
        self.sourceX = sourceX
        self.sourceY = sourceY
        self.destinationPageIndex = destinationPageIndex
        self.createdAt = Date()
    }
}
