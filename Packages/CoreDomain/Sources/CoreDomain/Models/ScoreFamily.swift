import Foundation
import SwiftData

/// Role of a score within a family (e.g., full score vs. individual part).
public enum ScoreRole: String, Codable, Sendable, CaseIterable {
    case fullScore       // Conductor's full score
    case part            // Individual instrument part
    case pianoReduction  // Piano reduction / vocal score
    case alternateEdition // Different edition of the same work
    case arrangement     // Arrangement (different instrumentation)
}

@Model
public final class ScoreFamily {
    public var id: UUID
    public var name: String
    public var composer: String
    public var createdAt: Date
    public var modifiedAt: Date

    /// Optional catalog or opus number for the work.
    public var catalogNumber: String

    /// Roles assigned to each score by their ID.
    /// Stored as [UUID.uuidString: ScoreRole.rawValue].
    public var scoreRoles: [String: String]

    /// Page-level cross-references between scores.
    /// Stored as JSON: [{"sourceScoreID": "", "sourcePage": 0, "targetScoreID": "", "targetPage": 0}]
    public var pageReferences: [String]

    @Relationship(deleteRule: .nullify)
    public var scores: [Score]

    public init(name: String, composer: String = "") {
        self.id = UUID()
        self.name = name
        self.composer = composer
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.catalogNumber = ""
        self.scoreRoles = [:]
        self.pageReferences = []
        self.scores = []
    }

    /// Get the role for a specific score.
    public func role(for score: Score) -> ScoreRole {
        if let raw = scoreRoles[score.id.uuidString],
           let role = ScoreRole(rawValue: raw) {
            return role
        }
        return .part
    }

    /// Set the role for a specific score.
    public func setRole(_ role: ScoreRole, for score: Score) {
        scoreRoles[score.id.uuidString] = role.rawValue
        modifiedAt = Date()
    }

    /// The full/conductor score in this family, if one exists.
    public var fullScore: Score? {
        scores.first(where: { role(for: $0) == .fullScore })
    }

    /// All part scores in this family.
    public var parts: [Score] {
        scores.filter { role(for: $0) == .part }
    }

    /// All alternate editions.
    public var alternateEditions: [Score] {
        scores.filter { role(for: $0) == .alternateEdition }
    }
}
