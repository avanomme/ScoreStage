// ScoreFamilyService — manages score family relationships (full score + parts, editions).

import Foundation
import SwiftData
import CoreDomain

/// Service for creating and managing score families — grouping related scores
/// (full score, parts, alternate editions) into a single work.
@MainActor
public final class ScoreFamilyService: ObservableObject {

    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Create & Manage Families

    /// Create a new score family with a name and optional initial scores.
    @discardableResult
    public func createFamily(name: String, composer: String = "", scores: [Score] = []) -> ScoreFamily {
        let family = ScoreFamily(name: name, composer: composer)
        modelContext.insert(family)
        for score in scores {
            score.family = family
            family.scores.append(score)
        }
        try? modelContext.save()
        return family
    }

    /// Add a score to a family with a specified role.
    public func addScore(_ score: Score, to family: ScoreFamily, role: ScoreRole = .part) {
        score.family = family
        if !family.scores.contains(where: { $0.id == score.id }) {
            family.scores.append(score)
        }
        family.setRole(role, for: score)
        try? modelContext.save()
    }

    /// Remove a score from its family.
    public func removeScore(_ score: Score, from family: ScoreFamily) {
        score.family = nil
        family.scores.removeAll(where: { $0.id == score.id })
        family.scoreRoles.removeValue(forKey: score.id.uuidString)
        family.modifiedAt = Date()
        try? modelContext.save()
    }

    /// Delete a family (scores are kept, just unlinked).
    public func deleteFamily(_ family: ScoreFamily) {
        for score in family.scores {
            score.family = nil
        }
        modelContext.delete(family)
        try? modelContext.save()
    }

    /// Change the role of a score within its family.
    public func setRole(_ role: ScoreRole, for score: Score, in family: ScoreFamily) {
        family.setRole(role, for: score)
        try? modelContext.save()
    }

    // MARK: - Queries

    /// Fetch all score families.
    public func allFamilies() -> [ScoreFamily] {
        let descriptor = FetchDescriptor<ScoreFamily>(
            sortBy: [SortDescriptor(\.name)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Find the family for a given score.
    public func family(for score: Score) -> ScoreFamily? {
        score.family
    }

    /// Find related scores (siblings in the same family).
    public func relatedScores(for score: Score) -> [Score] {
        guard let family = score.family else { return [] }
        return family.scores.filter { $0.id != score.id }
    }

    // MARK: - Cross-Reference

    /// Add a page-level cross-reference between two scores in the same family.
    public func addPageReference(
        from sourceScore: Score, page sourcePage: Int,
        to targetScore: Score, page targetPage: Int,
        in family: ScoreFamily
    ) {
        let ref = PageReference(
            sourceScoreID: sourceScore.id,
            sourcePage: sourcePage,
            targetScoreID: targetScore.id,
            targetPage: targetPage
        )
        if let json = try? JSONEncoder().encode(ref),
           let str = String(data: json, encoding: .utf8) {
            family.pageReferences.append(str)
            family.modifiedAt = Date()
            try? modelContext.save()
        }
    }

    /// Get all page references for a score within its family.
    public func pageReferences(for score: Score, in family: ScoreFamily) -> [PageReference] {
        family.pageReferences.compactMap { str in
            guard let data = str.data(using: .utf8),
                  let ref = try? JSONDecoder().decode(PageReference.self, from: data) else { return nil }
            guard ref.sourceScoreID == score.id || ref.targetScoreID == score.id else { return nil }
            return ref
        }
    }
}

// MARK: - Page Reference

/// A cross-reference linking a page in one score to a page in another.
public struct PageReference: Codable, Sendable {
    public let sourceScoreID: UUID
    public let sourcePage: Int
    public let targetScoreID: UUID
    public let targetPage: Int
}
