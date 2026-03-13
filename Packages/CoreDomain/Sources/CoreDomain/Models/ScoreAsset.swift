import Foundation
import SwiftData

public enum ScoreAssetType: String, Codable, Sendable {
    case pdf
    case musicXML
    case mei
    case midi
    case audio
    case image
}

@Model
public final class ScoreAsset {
    public var id: UUID
    public var type: ScoreAssetType
    public var fileName: String
    public var relativePath: String
    public var fileSize: Int64
    public var isPrimary: Bool
    public var createdAt: Date

    public var score: Score?

    public init(
        type: ScoreAssetType,
        fileName: String,
        relativePath: String,
        fileSize: Int64 = 0,
        isPrimary: Bool = false
    ) {
        self.id = UUID()
        self.type = type
        self.fileName = fileName
        self.relativePath = relativePath
        self.fileSize = fileSize
        self.isPrimary = isPrimary
        self.createdAt = Date()
    }
}
