import Foundation
import SwiftData
import CoreDomain
import PDFKit
import CryptoKit
import UniformTypeIdentifiers

public final class ScoreImportService: Sendable {
    private let scoresDirectoryName = "ImportedScores"

    public init() {}

    // MARK: - Public API

    @MainActor
    public func importFiles(from urls: [URL], into modelContext: ModelContext) async throws -> [Score] {
        var imported: [Score] = []
        for url in urls {
            if url.hasDirectoryPath {
                let children = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                let childResults = try await importFiles(from: children, into: modelContext)
                imported.append(contentsOf: childResults)
            } else if isSupportedFile(url) {
                if let score = try await importSingleFile(from: url, into: modelContext) {
                    imported.append(score)
                }
            }
        }
        return imported
    }

    @MainActor
    public func importSingleFile(from sourceURL: URL, into modelContext: ModelContext) async throws -> Score? {
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        let fileData = try Data(contentsOf: sourceURL)
        let hash = SHA256.hash(data: fileData)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()

        // Check for duplicates
        let descriptor = FetchDescriptor<Score>(predicate: #Predicate { $0.fileHash == hashString })
        let existing = try modelContext.fetch(descriptor)
        if !existing.isEmpty { return nil }

        // Copy file to app storage
        let scoresDir = try scoresDirectory()
        let fileName = sourceURL.lastPathComponent
        let uniqueName = uniqueFileName(fileName, in: scoresDir)
        let destURL = scoresDir.appendingPathComponent(uniqueName)
        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        // Extract metadata
        let metadata = extractMetadata(from: sourceURL, data: fileData)
        let assetType = assetType(for: sourceURL)

        let score = Score(
            title: metadata.title,
            composer: metadata.composer,
            pageCount: metadata.pageCount,
            fileHash: hashString
        )
        modelContext.insert(score)

        let fileSize = Int64(fileData.count)
        let asset = ScoreAsset(
            type: assetType,
            fileName: uniqueName,
            relativePath: uniqueName,
            fileSize: fileSize,
            isPrimary: true
        )
        asset.score = score

        modelContext.insert(asset)
        try modelContext.save()

        return score
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

        // Try to parse "Composer - Title" or "Title - Composer" patterns
        let parts = fileName.components(separatedBy: " - ")
        if parts.count == 2 {
            title = cleanTitle(parts[1])
            composer = cleanTitle(parts[0])
        }

        // Extract page count from PDF
        if url.pathExtension.lowercased() == "pdf" {
            if let pdfDoc = PDFDocument(data: data) {
                pageCount = pdfDoc.pageCount
            }
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
            let candidate = "\(stem)_\(counter).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidate)
            if !FileManager.default.fileExists(atPath: candidateURL.path) { return candidate }
            counter += 1
        }
    }

    /// Resolve a stored asset's relative path to a full file URL
    public func fileURL(for asset: ScoreAsset) throws -> URL {
        let scoresDir = try scoresDirectory()
        return scoresDir.appendingPathComponent(asset.relativePath)
    }
}
