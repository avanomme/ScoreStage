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

    public init(layers: [LayerPayload]) {
        self.layers = layers
    }

    public struct LayerPayload: Codable, Sendable {
        public var id: UUID
        public var name: String
        public var type: String
        public var isVisible: Bool
        public var sortOrder: Int
        public var strokes: [StrokePayload]
        public var objects: [ObjectPayload]

        public init(
            id: UUID,
            name: String,
            type: String,
            isVisible: Bool,
            sortOrder: Int,
            strokes: [StrokePayload],
            objects: [ObjectPayload]
        ) {
            self.id = id
            self.name = name
            self.type = type
            self.isVisible = isVisible
            self.sortOrder = sortOrder
            self.strokes = strokes
            self.objects = objects
        }
    }

    public struct StrokePayload: Codable, Sendable {
        public var id: UUID
        public var tool: String
        public var colorHex: String
        public var lineWidth: Double
        public var opacity: Double
        public var pageIndex: Int
        public var pointsData: Data

        public init(
            id: UUID,
            tool: String,
            colorHex: String,
            lineWidth: Double,
            opacity: Double,
            pageIndex: Int,
            pointsData: Data
        ) {
            self.id = id
            self.tool = tool
            self.colorHex = colorHex
            self.lineWidth = lineWidth
            self.opacity = opacity
            self.pageIndex = pageIndex
            self.pointsData = pointsData
        }
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

        public init(
            id: UUID,
            type: String,
            pageIndex: Int,
            x: Double,
            y: Double,
            width: Double,
            height: Double,
            rotation: Double,
            colorHex: String,
            text: String? = nil,
            fontSize: Double? = nil,
            shapeType: String? = nil,
            stampType: String? = nil
        ) {
            self.id = id
            self.type = type
            self.pageIndex = pageIndex
            self.x = x
            self.y = y
            self.width = width
            self.height = height
            self.rotation = rotation
            self.colorHex = colorHex
            self.text = text
            self.fontSize = fontSize
            self.shapeType = shapeType
            self.stampType = stampType
        }
    }
}
