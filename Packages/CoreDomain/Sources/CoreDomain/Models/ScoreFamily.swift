import Foundation
import SwiftData

@Model
public final class ScoreFamily {
    public var id: UUID
    public var name: String
    public var createdAt: Date

    @Relationship(deleteRule: .nullify)
    public var scores: [Score]

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.scores = []
    }
}
