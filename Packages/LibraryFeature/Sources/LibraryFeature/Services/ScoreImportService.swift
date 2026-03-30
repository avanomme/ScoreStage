import Foundation
import SwiftData
import CoreDomain
import PDFKit
import CryptoKit

public final class ScoreImportService: Sendable {
    private let scoresDirectoryName = "ImportedScores"

    public init() {}

    public enum DuplicateMatchKind: String, Sendable {
        case exactFile
        case metadataMatch
    }

    public enum ImportActionKind: String, CaseIterable, Identifiable, Sendable {
        case importNew
        case mergeIntoExisting
        case replaceExisting
        case skip

        public var id: String { rawValue }

        public var label: String {
            switch self {
            case .importNew: "Import"
            case .mergeIntoExisting: "Merge"
            case .replaceExisting: "Replace"
            case .skip: "Skip"
            }
        }
    }

    public struct DuplicateMatch: Identifiable, Sendable {
        public let scoreID: UUID
        public let title: String
        public let composer: String
        public let pageCount: Int
        public let kind: DuplicateMatchKind

        public var id: UUID { scoreID }
    }

    public struct ImportDecision: Sendable, Equatable {
        public var action: ImportActionKind
        public var targetScoreID: UUID?

        public init(action: ImportActionKind, targetScoreID: UUID? = nil) {
            self.action = action
            self.targetScoreID = targetScoreID
        }
    }

    public struct ImportReviewItem: Identifiable, Sendable {
        public let id: UUID
        public let sourceURL: URL
        public let fileName: String
        public let title: String
        public let composer: String
        public let pageCount: Int
        public let assetType: ScoreAssetType
        public let fileSize: Int64
        public let hashString: String
        public let duplicateMatches: [DuplicateMatch]
        public var decision: ImportDecision

        public init(
            id: UUID = UUID(),
            sourceURL: URL,
            fileName: String,
            title: String,
            composer: String,
            pageCount: Int,
            assetType: ScoreAssetType,
            fileSize: Int64,
            hashString: String,
            duplicateMatches: [DuplicateMatch],
            decision: ImportDecision
        ) {
            self.id = id
            self.sourceURL = sourceURL
            self.fileName = fileName
            self.title = title
            self.composer = composer
            self.pageCount = pageCount
            self.assetType = assetType
            self.fileSize = fileSize
            self.hashString = hashString
            self.duplicateMatches = duplicateMatches
            self.decision = decision
        }
    }

    public struct ImportBatchResult {
        public var imported: [Score]
        public var mergedCount: Int
        public var replacedCount: Int
        public var skippedCount: Int
        public var failedFiles: [String]

        public init(
            imported: [Score] = [],
            mergedCount: Int = 0,
            replacedCount: Int = 0,
            skippedCount: Int = 0,
            failedFiles: [String] = []
        ) {
            self.imported = imported
            self.mergedCount = mergedCount
            self.replacedCount = replacedCount
            self.skippedCount = skippedCount
            self.failedFiles = failedFiles
        }
    }

    // MARK: - Public API

    @MainActor
    public func previewImport(from urls: [URL], into modelContext: ModelContext) async throws -> [ImportReviewItem] {
        let candidates = try collectSupportedFiles(from: urls)
        let existingScores = try modelContext.fetch(FetchDescriptor<Score>())
        var previews: [ImportReviewItem] = []

        for url in candidates {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }

            let fileData = try Data(contentsOf: url)
            let hashString = hashString(for: fileData)
            let metadata = extractMetadata(from: url, data: fileData)
            let assetType = assetType(for: url)
            let matches = duplicateMatches(
                for: metadata,
                hashString: hashString,
                in: existingScores
            )

            previews.append(
                ImportReviewItem(
                    sourceURL: url,
                    fileName: url.lastPathComponent,
                    title: metadata.title,
                    composer: metadata.composer,
                    pageCount: metadata.pageCount,
                    assetType: assetType,
                    fileSize: Int64(fileData.count),
                    hashString: hashString,
                    duplicateMatches: matches,
                    decision: defaultDecision(for: matches)
                )
            )
        }

        return previews.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
    }

    @MainActor
    public func importReviewedFiles(_ items: [ImportReviewItem], into modelContext: ModelContext) async throws -> ImportBatchResult {
        var result = ImportBatchResult()

        for item in items {
            do {
                switch item.decision.action {
                case .skip:
                    result.skippedCount += 1
                case .importNew:
                    if let score = try await createImportedScore(from: item.sourceURL, into: modelContext) {
                        result.imported.append(score)
                    } else {
                        result.skippedCount += 1
                    }
                case .mergeIntoExisting:
                    guard let target = try findScore(id: item.decision.targetScoreID, in: modelContext) else {
                        result.failedFiles.append(item.fileName)
                        continue
                    }
                    try await mergeImportedFile(from: item.sourceURL, into: target, replacePrimary: false, modelContext: modelContext)
                    result.mergedCount += 1
                case .replaceExisting:
                    guard let target = try findScore(id: item.decision.targetScoreID, in: modelContext) else {
                        result.failedFiles.append(item.fileName)
                        continue
                    }
                    try await mergeImportedFile(from: item.sourceURL, into: target, replacePrimary: true, modelContext: modelContext)
                    result.replacedCount += 1
                }
            } catch {
                result.failedFiles.append(item.fileName)
            }
        }

        try modelContext.save()
        return result
    }

    @MainActor
    public func importFiles(from urls: [URL], into modelContext: ModelContext) async throws -> [Score] {
        let preview = try await previewImport(from: urls, into: modelContext)
        let result = try await importReviewedFiles(preview, into: modelContext)
        return result.imported
    }

    @MainActor
    public func importSingleFile(from sourceURL: URL, into modelContext: ModelContext) async throws -> Score? {
        try await createImportedScore(from: sourceURL, into: modelContext)
    }

    // MARK: - File Support

    public func isSupportedFile(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ["pdf", "xml", "mxl", "musicxml", "mei", "mid", "midi", "png", "jpg", "jpeg", "tiff"].contains(ext)
    }

    public func assetType(for url: URL) -> ScoreAssetType {
        switch url.pathExtension.lowercased() {
        case "pdf": return .pdf
        case "xml", "mxl", "musicxml": return .musicXML
        case "mei": return .mei
        case "mid", "midi": return .midi
        case "png", "jpg", "jpeg", "tiff": return .image
        default: return .pdf
        }
    }

    // MARK: - Metadata Extraction

    struct ScoreMetadata {
        var title: String
        var composer: String
        var pageCount: Int
    }

    func extractMetadata(from url: URL, data: Data) -> ScoreMetadata {
        let fileName = url.deletingPathExtension().lastPathComponent
        var title = cleanTitle(fileName)
        var composer = ""
        var pageCount = 0

        let parts = fileName.components(separatedBy: " - ")
        if parts.count == 2 {
            let left = cleanTitle(parts[0])
            let right = cleanTitle(parts[1])
            let leftIsNumber = left.allSatisfy { $0.isNumber || $0 == "." || $0 == " " }

            if leftIsNumber {
                title = cleanTitle(fileName)
            } else {
                composer = left
                title = right
            }
        }

        if url.pathExtension.lowercased() == "pdf", let pdfDoc = PDFDocument(data: data) {
            pageCount = pdfDoc.pageCount
        }

        return ScoreMetadata(title: title, composer: composer, pageCount: pageCount)
    }

    private func cleanTitle(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - File Storage

    func scoresDirectory() throws -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let scoresDir = appSupport.appendingPathComponent(scoresDirectoryName)
        if !FileManager.default.fileExists(atPath: scoresDir.path) {
            try FileManager.default.createDirectory(at: scoresDir, withIntermediateDirectories: true)
        }
        return scoresDir
    }

    func uniqueFileName(_ name: String, in directory: URL) -> String {
        let url = directory.appendingPathComponent(name)
        if !FileManager.default.fileExists(atPath: url.path) { return name }

        let stem = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var counter = 1
        while true {
            let suffix = ext.isEmpty ? "" : ".\(ext)"
            let candidate = "\(stem)_\(counter)\(suffix)"
            let candidateURL = directory.appendingPathComponent(candidate)
            if !FileManager.default.fileExists(atPath: candidateURL.path) { return candidate }
            counter += 1
        }
    }

    public func fileURL(for asset: ScoreAsset) throws -> URL {
        let scoresDir = try scoresDirectory()
        return scoresDir.appendingPathComponent(asset.relativePath)
    }

    // MARK: - Private Import Helpers

    @MainActor
    private func createImportedScore(from sourceURL: URL, into modelContext: ModelContext) async throws -> Score? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: sourceURL)
        let hashString = hashString(for: fileData)
        let descriptor = FetchDescriptor<Score>(predicate: #Predicate { $0.fileHash == hashString })
        let existing = try modelContext.fetch(descriptor)
        if !existing.isEmpty { return nil }

        let metadata = extractMetadata(from: sourceURL, data: fileData)
        let assetType = assetType(for: sourceURL)
        let (uniqueName, relativePath) = try storeImportedFile(sourceURL: sourceURL, data: fileData)

        let score = Score(
            title: metadata.title,
            composer: metadata.composer,
            pageCount: metadata.pageCount,
            fileHash: hashString
        )
        modelContext.insert(score)

        let asset = ScoreAsset(
            type: assetType,
            fileName: uniqueName,
            relativePath: relativePath,
            fileSize: Int64(fileData.count),
            isPrimary: true
        )
        asset.score = score
        modelContext.insert(asset)
        try modelContext.save()

        return score
    }

    @MainActor
    private func mergeImportedFile(from sourceURL: URL, into score: Score, replacePrimary: Bool, modelContext: ModelContext) async throws {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: sourceURL)
        let newHash = hashString(for: fileData)
        let metadata = extractMetadata(from: sourceURL, data: fileData)
        let newAssetType = assetType(for: sourceURL)

        if score.fileHash == newHash && !replacePrimary {
            mergeMetadata(into: score, using: metadata, replaceExisting: false)
            score.modifiedAt = Date()
            return
        }

        let (storedName, relativePath) = try storeImportedFile(sourceURL: sourceURL, data: fileData)

        if replacePrimary {
            for asset in score.assets where asset.isPrimary {
                asset.isPrimary = false
            }
        }

        let shouldCreateAsset = !score.assets.contains {
            $0.fileName == storedName || ($0.type == newAssetType && score.fileHash == newHash && !replacePrimary)
        }

        if shouldCreateAsset {
            let asset = ScoreAsset(
                type: newAssetType,
                fileName: storedName,
                relativePath: relativePath,
                fileSize: Int64(fileData.count),
                isPrimary: replacePrimary || score.assets.isEmpty
            )
            asset.score = score
            modelContext.insert(asset)
        }

        mergeMetadata(into: score, using: metadata, replaceExisting: replacePrimary)
        if replacePrimary || score.fileHash.isEmpty {
            score.fileHash = newHash
            score.pageCount = metadata.pageCount
        }
        score.modifiedAt = Date()
    }

    private func mergeMetadata(into score: Score, using metadata: ScoreMetadata, replaceExisting: Bool) {
        if replaceExisting || score.title.isEmpty {
            score.title = metadata.title
        }
        if replaceExisting || score.composer.isEmpty {
            score.composer = metadata.composer
        }
        if replaceExisting || score.pageCount == 0 {
            score.pageCount = metadata.pageCount
        }
    }

    @MainActor
    private func findScore(id: UUID?, in modelContext: ModelContext) throws -> Score? {
        guard let id else { return nil }
        let allScores = try modelContext.fetch(FetchDescriptor<Score>())
        return allScores.first { $0.id == id }
    }

    private func collectSupportedFiles(from urls: [URL]) throws -> [URL] {
        var collected: [URL] = []
        for url in urls {
            if url.hasDirectoryPath {
                let children = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )
                collected.append(contentsOf: try collectSupportedFiles(from: children))
            } else if isSupportedFile(url) {
                collected.append(url)
            }
        }
        return collected
    }

    private func duplicateMatches(for metadata: ScoreMetadata, hashString: String, in scores: [Score]) -> [DuplicateMatch] {
        let normalizedTitle = normalize(metadata.title)
        let normalizedComposer = normalize(metadata.composer)

        return scores.compactMap { score in
            if score.fileHash == hashString {
                return DuplicateMatch(
                    scoreID: score.id,
                    title: score.title,
                    composer: score.composer,
                    pageCount: score.pageCount,
                    kind: .exactFile
                )
            }

            let titleMatch = normalize(score.title) == normalizedTitle
            let composerMatch = normalizedComposer.isEmpty || normalize(score.composer) == normalizedComposer
            let pageCountMatch = metadata.pageCount == 0 || score.pageCount == 0 || score.pageCount == metadata.pageCount

            if titleMatch && composerMatch && pageCountMatch {
                return DuplicateMatch(
                    scoreID: score.id,
                    title: score.title,
                    composer: score.composer,
                    pageCount: score.pageCount,
                    kind: .metadataMatch
                )
            }

            return nil
        }
    }

    private func defaultDecision(for matches: [DuplicateMatch]) -> ImportDecision {
        if let exact = matches.first(where: { $0.kind == .exactFile }) {
            return ImportDecision(action: .skip, targetScoreID: exact.scoreID)
        }
        if let likely = matches.first(where: { $0.kind == .metadataMatch }) {
            return ImportDecision(action: .mergeIntoExisting, targetScoreID: likely.scoreID)
        }
        return ImportDecision(action: .importNew)
    }

    private func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hashString(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func storeImportedFile(sourceURL: URL, data: Data) throws -> (fileName: String, relativePath: String) {
        let scoresDir = try scoresDirectory()
        let fileName = uniqueFileName(sourceURL.lastPathComponent, in: scoresDir)
        let destinationURL = scoresDir.appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: .atomic)
        return (fileName, fileName)
    }
}
