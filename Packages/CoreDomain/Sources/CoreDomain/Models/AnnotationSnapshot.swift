import Foundation
import SwiftData

/// A point-in-time snapshot of annotation state for a score.
/// Stores serialized layer/stroke/object data for restore.
@Model
public final class AnnotationSnapshot {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var snapshotData: Data // JSON-encoded annotation state

    public var score: Score?

    public init(
        name: String,
        snapshotData: Data = Data()
    ) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.snapshotData = snapshotData
    }
}

/// Codable representation of annotation state for snapshot serialization.
public struct AnnotationSnapshotPayload: Codable, Sendable {
    public var layers: [LayerPayload]

    public struct LayerPayload: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var type: String
        public var isVisible: Bool
        public var sortOrder: Int
        public var strokes: [StrokePayload]
        public var objects: [ObjectPayload]
    }

    public struct StrokePayload: Codable, Sendable {
        public var id: UUID
        public var tool: String
        public var colorHex: String
        public var lineWidth: Double
        public var opacity: Double
        public var pageIndex: Int
        public var pointsData: Data
    }

    public struct ObjectPayload: Codable, Sendable {
        public var id: UUID
        public var type: String
        public var pageIndex: Int
        public var x: Double
        public var y: Double
        public var width: Double
        public var height: Double
        public var rotation: Double
        public var colorHex: String
        public var text: String?
        public var fontSize: Double?
        public var shapeType: String?
        public var stampType: String?
    }
}
