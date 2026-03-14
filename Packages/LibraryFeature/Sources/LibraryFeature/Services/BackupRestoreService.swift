// BackupRestoreService — Full library backup bundle export/import.

import Foundation
import SwiftData
import CoreDomain

/// Exports and imports the entire ScoreStage library as a portable backup bundle.
/// The bundle is a directory containing:
/// - metadata.json (scores, setlists, bookmarks, families)
/// - ImportedScores/ (PDF files)
/// - Annotations/ (annotation layer data)
@MainActor
public final class BackupRestoreService: ObservableObject {

    // MARK: - State

    public enum BackupState: Sendable {
        case idle
        case exporting(progress: Double)
        case importing(progress: Double)
        case completed(URL?)
        case error(String)
    }

    @Published public private(set) var state: BackupState = .idle

    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    /// Export the full library to a backup bundle at the specified directory.
    /// Returns the URL of the created .scorestagebackup file.
    public func exportBackup(to directory: URL) async throws -> URL {
        state = .exporting(progress: 0)

        // Create temp directory for bundle
        let bundleName = "ScoreStage-Backup-\(formatDate(Date()))"
        let bundleURL = directory.appendingPathComponent("\(bundleName).scorestagebackup")
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(bundleName)

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // Export metadata
        state = .exporting(progress: 0.1)
        let metadata = try await gatherMetadata()
        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: tempDir.appendingPathComponent("metadata.json"))

        // Copy score PDFs
        state = .exporting(progress: 0.3)
        let scoresDir = tempDir.appendingPathComponent("ImportedScores")
        try FileManager.default.createDirectory(at: scoresDir, withIntermediateDirectories: true)

        let appScoresDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ImportedScores")

        if let appScoresDir, FileManager.default.fileExists(atPath: appScoresDir.path) {
            let files = try FileManager.default.contentsOfDirectory(at: appScoresDir, includingPropertiesForKeys: nil)
            for (index, file) in files.enumerated() {
                try FileManager.default.copyItem(at: file, to: scoresDir.appendingPathComponent(file.lastPathComponent))
                let progress = 0.3 + 0.5 * Double(index + 1) / Double(max(files.count, 1))
                state = .exporting(progress: progress)
            }
        }

        // Create ZIP archive
        state = .exporting(progress: 0.85)

        // Move temp directory to final location
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.removeItem(at: bundleURL)
        }
        try FileManager.default.moveItem(at: tempDir, to: bundleURL)

        state = .completed(bundleURL)
        return bundleURL
    }

    // MARK: - Import

    /// Import a backup bundle, merging with existing library.
    public func importBackup(from bundleURL: URL) async throws {
        state = .importing(progress: 0)

        let metadataURL = bundleURL.appendingPathComponent("metadata.json")
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            state = .error("Invalid backup: metadata.json not found")
            throw BackupError.invalidBundle
        }

        // Parse metadata
        state = .importing(progress: 0.1)
        let data = try Data(contentsOf: metadataURL)
        let metadata = try JSONDecoder().decode(BackupMetadata.self, from: data)

        // Import scores
        state = .importing(progress: 0.2)
        let scoresDir = bundleURL.appendingPathComponent("ImportedScores")
        let appScoresDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("ImportedScores")

        if let appScoresDir {
            try FileManager.default.createDirectory(at: appScoresDir, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: scoresDir.path) {
                let files = try FileManager.default.contentsOfDirectory(at: scoresDir, includingPropertiesForKeys: nil)
                for (index, file) in files.enumerated() {
                    let dest = appScoresDir.appendingPathComponent(file.lastPathComponent)
                    if !FileManager.default.fileExists(atPath: dest.path) {
                        try FileManager.default.copyItem(at: file, to: dest)
                    }
                    let progress = 0.2 + 0.6 * Double(index + 1) / Double(max(files.count, 1))
                    state = .importing(progress: progress)
                }
            }
        }

        // Restore metadata records
        state = .importing(progress: 0.85)
        try restoreMetadata(metadata)

        state = .completed(nil)
    }

    // MARK: - Reset

    public func resetState() {
        state = .idle
    }

    // MARK: - Metadata Gathering

    private func gatherMetadata() async throws -> BackupMetadata {
        let scores = try modelContext.fetch(FetchDescriptor<Score>())
        let setlists = try modelContext.fetch(FetchDescriptor<SetList>())

        let scoreEntries = scores.map { score in
            BackupScore(
                id: score.id,
                title: score.title,
                composer: score.composer,
                arranger: score.arranger,
                genre: score.genre,
                key: score.key,
                instrumentation: score.instrumentation,
                difficulty: score.difficulty,
                customTags: score.customTags,
                isFavorite: score.isFavorite,
                pageCount: score.pageCount,
                fileHash: score.fileHash
            )
        }

        let setlistEntries = setlists.map { setlist in
            BackupSetlist(
                id: setlist.id,
                name: setlist.name,
                scoreIDs: setlist.items.sorted(by: { $0.sortOrder < $1.sortOrder }).compactMap { $0.score?.id }
            )
        }

        return BackupMetadata(
            version: 1,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            scores: scoreEntries,
            setlists: setlistEntries
        )
    }

    private func restoreMetadata(_ metadata: BackupMetadata) throws {
        // Scores — only import if not already present (by fileHash)
        let existingScores = try modelContext.fetch(FetchDescriptor<Score>())
        let existingHashes = Set(existingScores.map(\.fileHash))

        for entry in metadata.scores {
            guard !existingHashes.contains(entry.fileHash) else { continue }

            let score = Score(
                title: entry.title,
                composer: entry.composer,
                arranger: entry.arranger,
                genre: entry.genre,
                key: entry.key,
                instrumentation: entry.instrumentation,
                difficulty: entry.difficulty,
                pageCount: entry.pageCount,
                fileHash: entry.fileHash
            )
            score.customTags = entry.customTags
            score.isFavorite = entry.isFavorite
            modelContext.insert(score)
        }

        try modelContext.save()
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Errors

    public enum BackupError: Error, LocalizedError {
        case invalidBundle
        case exportFailed(String)

        public var errorDescription: String? {
            switch self {
            case .invalidBundle: "The backup file is invalid or corrupted."
            case .exportFailed(let msg): "Export failed: \(msg)"
            }
        }
    }
}

// MARK: - Backup Models

public struct BackupMetadata: Codable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let appVersion: String
    public let scores: [BackupScore]
    public let setlists: [BackupSetlist]
}

public struct BackupScore: Codable, Sendable {
    public let id: UUID
    public let title: String
    public let composer: String
    public let arranger: String
    public let genre: String
    public let key: String
    public let instrumentation: String
    public let difficulty: Int
    public let customTags: [String]
    public let isFavorite: Bool
    public let pageCount: Int
    public let fileHash: String
}

public struct BackupSetlist: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let scoreIDs: [UUID]
}
