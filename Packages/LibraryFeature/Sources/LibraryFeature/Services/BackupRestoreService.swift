import Foundation
import SwiftData
import CoreDomain

@MainActor
public final class BackupRestoreService: ObservableObject {
    public enum BackupState: Sendable {
        case idle
        case exporting(progress: Double)
        case importing(progress: Double)
        case completed(URL?)
        case error(String)
    }

    public enum RestoreStrategy: String, CaseIterable, Identifiable, Sendable {
        case merge
        case replaceExisting
        case keepBoth

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .merge: "Merge"
            case .replaceExisting: "Replace Existing"
            case .keepBoth: "Keep Both"
            }
        }
    }

    @Published public private(set) var state: BackupState = .idle

    private let modelContext: ModelContext
    private let importedScoresDirectoryName = "ImportedScores"
    private let restorePointsDirectoryName = "RestorePoints"

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Export

    public func exportBackup(to directory: URL, packageName: String? = nil) async throws -> URL {
        state = .exporting(progress: 0)

        let bundleName = packageName ?? "ScoreStage-Backup-\(formatDate(Date()))"
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bundleURL = directory.appendingPathComponent("\(bundleName).scorestagebackup")

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let library = try await gatherLibrarySnapshot()
        state = .exporting(progress: 0.25)
        let manifest = BackupManifest(
            version: 2,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            scoreCount: library.scores.count,
            setlistCount: library.setlists.count,
            bookmarkCount: library.scores.reduce(0) { $0 + $1.bookmarks.count }
        )

        try JSONEncoder.prettyPrinted.encode(manifest).write(to: tempDir.appendingPathComponent("manifest.json"))
        try JSONEncoder.prettyPrinted.encode(library).write(to: tempDir.appendingPathComponent("library.json"))

        state = .exporting(progress: 0.45)
        let packageScoresDir = tempDir.appendingPathComponent(importedScoresDirectoryName)
        try FileManager.default.createDirectory(at: packageScoresDir, withIntermediateDirectories: true)

        let sourceScoresDir = try importedScoresDirectory()
        if FileManager.default.fileExists(atPath: sourceScoresDir.path) {
            let files = try FileManager.default.contentsOfDirectory(at: sourceScoresDir, includingPropertiesForKeys: nil)
            for (index, file) in files.enumerated() {
                let destination = packageScoresDir.appendingPathComponent(file.lastPathComponent)
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: file, to: destination)
                let progress = 0.45 + (0.45 * Double(index + 1) / Double(max(files.count, 1)))
                state = .exporting(progress: progress)
            }
        }

        state = .exporting(progress: 0.95)
        if FileManager.default.fileExists(atPath: bundleURL.path) {
            try FileManager.default.removeItem(at: bundleURL)
        }
        try FileManager.default.moveItem(at: tempDir, to: bundleURL)
        state = .completed(bundleURL)
        return bundleURL
    }

    // MARK: - Import

    public func importBackup(from bundleURL: URL, strategy: RestoreStrategy = .merge) async throws {
        state = .importing(progress: 0)

        let manifestURL = bundleURL.appendingPathComponent("manifest.json")
        let libraryURL = bundleURL.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path),
              FileManager.default.fileExists(atPath: libraryURL.path) else {
            state = .error("Invalid backup package")
            throw BackupError.invalidBundle
        }

        _ = try await createRestorePoint()

        let libraryData = try Data(contentsOf: libraryURL)
        let library = try JSONDecoder().decode(BackupLibrary.self, from: libraryData)

        state = .importing(progress: 0.15)
        try restoreLibraryFiles(from: bundleURL)

        state = .importing(progress: 0.45)
        let scoreMap = try restoreScores(library.scores, strategy: strategy)

        state = .importing(progress: 0.75)
        try restoreSetlists(library.setlists, scoreMap: scoreMap, strategy: strategy)

        try modelContext.save()
        state = .completed(nil)
    }

    public func createRestorePoint() async throws -> URL {
        let directory = try restorePointsDirectory()
        return try await exportBackup(
            to: directory,
            packageName: "RestorePoint-\(formatDate(Date()))"
        )
    }

    public func resetState() {
        state = .idle
    }

    // MARK: - Snapshot Gathering

    private func gatherLibrarySnapshot() async throws -> BackupLibrary {
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
                duration: score.duration,
                notes: score.notes,
                isFavorite: score.isFavorite,
                isArchived: score.isArchived,
                customTags: score.customTags,
                pageCount: score.pageCount,
                fileHash: score.fileHash,
                viewingPreferences: score.viewingPreferences,
                assets: score.assets.map {
                    BackupAsset(
                        type: $0.type,
                        fileName: $0.fileName,
                        relativePath: $0.relativePath,
                        fileSize: $0.fileSize,
                        isPrimary: $0.isPrimary
                    )
                },
                bookmarks: score.bookmarks.map {
                    BackupBookmark(
                        id: $0.id,
                        name: $0.name,
                        pageIndex: $0.pageIndex,
                        sortOrder: $0.sortOrder
                    )
                }
            )
        }

        let setlistEntries = setlists.map { setlist in
            BackupSetlist(
                id: setlist.id,
                name: setlist.name,
                eventDescription: setlist.eventDescription,
                eventDate: setlist.eventDate,
                performanceNotes: setlist.performanceNotes,
                stageNotes: setlist.stageNotes,
                items: setlist.items.sorted(by: { $0.sortOrder < $1.sortOrder }).map { item in
                    BackupSetlistItem(
                        sortOrder: item.sortOrder,
                        scoreHash: item.score?.fileHash,
                        scoreTitle: item.score?.title ?? "",
                        performanceNotes: item.performanceNotes,
                        cueTitle: item.cueTitle,
                        cueNotes: item.cueNotes,
                        pauseDuration: item.pauseDuration,
                        pauseNotes: item.pauseNotes,
                        transitionStyle: item.transitionStyle,
                        medleyTitle: item.medleyTitle,
                        autoAdvanceDelay: item.autoAdvanceDelay,
                        performancePreset: item.performancePreset
                    )
                }
            )
        }

        return BackupLibrary(scores: scoreEntries, setlists: setlistEntries)
    }

    // MARK: - Restore

    private func restoreLibraryFiles(from bundleURL: URL) throws {
        let packageScoresDir = bundleURL.appendingPathComponent(importedScoresDirectoryName)
        guard FileManager.default.fileExists(atPath: packageScoresDir.path) else { return }

        let destinationDir = try importedScoresDirectory()
        let files = try FileManager.default.contentsOfDirectory(at: packageScoresDir, includingPropertiesForKeys: nil)
        for file in files {
            let destination = destinationDir.appendingPathComponent(file.lastPathComponent)
            if !FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.copyItem(at: file, to: destination)
            }
        }
    }

    private func restoreScores(_ backupScores: [BackupScore], strategy: RestoreStrategy) throws -> [String: Score] {
        let existingScores = try modelContext.fetch(FetchDescriptor<Score>())
        var scoresByHash = Dictionary(uniqueKeysWithValues: existingScores.map { ($0.fileHash, $0) })

        for backupScore in backupScores {
            if let existing = scoresByHash[backupScore.fileHash] {
                switch strategy {
                case .merge:
                    merge(existing: existing, with: backupScore, replaceExisting: false)
                case .replaceExisting:
                    merge(existing: existing, with: backupScore, replaceExisting: true)
                case .keepBoth:
                    let copy = createScore(from: backupScore, keepBoth: true)
                    modelContext.insert(copy)
                    attachAssetsAndBookmarks(from: backupScore, to: copy)
                    scoresByHash["\(backupScore.fileHash)-\(copy.id.uuidString)"] = copy
                    continue
                }

                attachAssetsAndBookmarks(from: backupScore, to: existing)
                scoresByHash[backupScore.fileHash] = existing
            } else {
                let score = createScore(from: backupScore)
                modelContext.insert(score)
                attachAssetsAndBookmarks(from: backupScore, to: score)
                scoresByHash[backupScore.fileHash] = score
            }
        }

        return scoresByHash
    }

    private func restoreSetlists(_ backupSetlists: [BackupSetlist], scoreMap: [String: Score], strategy: RestoreStrategy) throws {
        let existingSetlists = try modelContext.fetch(FetchDescriptor<SetList>())

        for backupSetlist in backupSetlists {
            let target: SetList
            if let existing = existingSetlists.first(where: { $0.name == backupSetlist.name }) {
                switch strategy {
                case .replaceExisting:
                    existing.eventDescription = backupSetlist.eventDescription
                    existing.eventDate = backupSetlist.eventDate
                    existing.performanceNotes = backupSetlist.performanceNotes
                    existing.stageNotes = backupSetlist.stageNotes
                    for item in existing.items {
                        modelContext.delete(item)
                    }
                    target = existing
                case .merge:
                    target = existing
                case .keepBoth:
                    let copy = SetList(
                        name: "\(backupSetlist.name) (Imported)",
                        eventDescription: backupSetlist.eventDescription,
                        performanceNotes: backupSetlist.performanceNotes,
                        stageNotes: backupSetlist.stageNotes
                    )
                    copy.eventDate = backupSetlist.eventDate
                    modelContext.insert(copy)
                    target = copy
                }
            } else {
                let setlist = SetList(
                    name: backupSetlist.name,
                    eventDescription: backupSetlist.eventDescription,
                    performanceNotes: backupSetlist.performanceNotes,
                    stageNotes: backupSetlist.stageNotes
                )
                setlist.eventDate = backupSetlist.eventDate
                modelContext.insert(setlist)
                target = setlist
            }

            let existingSignature: Set<String> = Set(target.items.compactMap { item in
                guard let fileHash = item.score?.fileHash else { return nil }
                return "\(fileHash)-\(item.sortOrder)"
            })

            for backupItem in backupSetlist.items {
                guard let scoreHash = backupItem.scoreHash,
                      let linkedScore = scoreMap[scoreHash] else { continue }

                let signature = "\(scoreHash)-\(backupItem.sortOrder)"
                if strategy == .merge && existingSignature.contains(signature) {
                    continue
                }

                let item = SetListItem(
                    sortOrder: backupItem.sortOrder,
                    performanceNotes: backupItem.performanceNotes,
                    cueTitle: backupItem.cueTitle,
                    cueNotes: backupItem.cueNotes,
                    pauseDuration: backupItem.pauseDuration,
                    pauseNotes: backupItem.pauseNotes,
                    transitionStyle: backupItem.transitionStyle,
                    medleyTitle: backupItem.medleyTitle,
                    autoAdvanceDelay: backupItem.autoAdvanceDelay,
                    performancePreset: backupItem.performancePreset
                )
                item.setList = target
                item.score = linkedScore
                modelContext.insert(item)
            }
            target.modifiedAt = Date()
        }
    }

    private func merge(existing score: Score, with backup: BackupScore, replaceExisting: Bool) {
        if replaceExisting || score.title.isEmpty { score.title = backup.title }
        if replaceExisting || score.composer.isEmpty { score.composer = backup.composer }
        if replaceExisting || score.arranger.isEmpty { score.arranger = backup.arranger }
        if replaceExisting || score.genre.isEmpty { score.genre = backup.genre }
        if replaceExisting || score.key.isEmpty { score.key = backup.key }
        if replaceExisting || score.instrumentation.isEmpty { score.instrumentation = backup.instrumentation }
        if replaceExisting || score.notes.isEmpty { score.notes = backup.notes }
        if replaceExisting || score.pageCount == 0 { score.pageCount = backup.pageCount }
        if replaceExisting || score.duration == 0 { score.duration = backup.duration }
        if replaceExisting || score.difficulty == 0 { score.difficulty = backup.difficulty }
        if replaceExisting { score.isArchived = backup.isArchived }
        score.isFavorite = score.isFavorite || backup.isFavorite
        score.customTags = Array(Set(score.customTags + backup.customTags)).sorted()
        if replaceExisting || score.viewingPreferences == nil {
            score.viewingPreferences = backup.viewingPreferences
        }
        score.modifiedAt = Date()
    }

    private func createScore(from backup: BackupScore, keepBoth: Bool = false) -> Score {
        let title = keepBoth ? "\(backup.title) (Imported)" : backup.title
        let score = Score(
            title: title,
            composer: backup.composer,
            arranger: backup.arranger,
            genre: backup.genre,
            key: backup.key,
            instrumentation: backup.instrumentation,
            difficulty: backup.difficulty,
            duration: backup.duration,
            notes: backup.notes,
            pageCount: backup.pageCount,
            fileHash: backup.fileHash
        )
        score.isFavorite = backup.isFavorite
        score.isArchived = backup.isArchived
        score.customTags = backup.customTags
        score.viewingPreferences = backup.viewingPreferences
        return score
    }

    private func attachAssetsAndBookmarks(from backup: BackupScore, to score: Score) {
        let existingAssetPaths = Set(score.assets.map(\.relativePath))
        for backupAsset in backup.assets where !existingAssetPaths.contains(backupAsset.relativePath) {
            let asset = ScoreAsset(
                type: backupAsset.type,
                fileName: backupAsset.fileName,
                relativePath: backupAsset.relativePath,
                fileSize: backupAsset.fileSize,
                isPrimary: backupAsset.isPrimary
            )
            asset.score = score
            modelContext.insert(asset)
        }

        let existingBookmarks = Set(score.bookmarks.map { "\($0.pageIndex)-\($0.name)" })
        for backupBookmark in backup.bookmarks where !existingBookmarks.contains("\(backupBookmark.pageIndex)-\(backupBookmark.name)") {
            let bookmark = Bookmark(
                name: backupBookmark.name,
                pageIndex: backupBookmark.pageIndex,
                sortOrder: backupBookmark.sortOrder
            )
            bookmark.score = score
            modelContext.insert(bookmark)
        }
    }

    // MARK: - Directories

    private func appSupportDirectory() throws -> URL {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func importedScoresDirectory() throws -> URL {
        let directory = try appSupportDirectory().appendingPathComponent(importedScoresDirectoryName)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private func restorePointsDirectory() throws -> URL {
        let directory = try appSupportDirectory().appendingPathComponent(restorePointsDirectoryName)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: date)
    }

    public enum BackupError: Error, LocalizedError {
        case invalidBundle

        public var errorDescription: String? {
            switch self {
            case .invalidBundle:
                "The backup package is invalid or corrupted."
            }
        }
    }
}

// MARK: - Transfer Models

public struct BackupManifest: Codable, Sendable {
    public let version: Int
    public let createdAt: Date
    public let appVersion: String
    public let scoreCount: Int
    public let setlistCount: Int
    public let bookmarkCount: Int
}

public struct BackupLibrary: Codable, Sendable {
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
    public let duration: TimeInterval
    public let notes: String
    public let isFavorite: Bool
    public let isArchived: Bool
    public let customTags: [String]
    public let pageCount: Int
    public let fileHash: String
    public let viewingPreferences: ViewingPreferences?
    public let assets: [BackupAsset]
    public let bookmarks: [BackupBookmark]
}

public struct BackupAsset: Codable, Sendable {
    public let type: ScoreAssetType
    public let fileName: String
    public let relativePath: String
    public let fileSize: Int64
    public let isPrimary: Bool
}

public struct BackupBookmark: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let pageIndex: Int
    public let sortOrder: Int
}

public struct BackupSetlist: Codable, Sendable {
    public let id: UUID
    public let name: String
    public let eventDescription: String
    public let eventDate: Date?
    public let performanceNotes: String
    public let stageNotes: String
    public let items: [BackupSetlistItem]
}

public struct BackupSetlistItem: Codable, Sendable {
    public let sortOrder: Int
    public let scoreHash: String?
    public let scoreTitle: String
    public let performanceNotes: String
    public let cueTitle: String
    public let cueNotes: String
    public let pauseDuration: TimeInterval
    public let pauseNotes: String
    public let transitionStyle: SetlistTransitionStyle
    public let medleyTitle: String
    public let autoAdvanceDelay: TimeInterval
    public let performancePreset: SetlistPerformancePreset?
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
