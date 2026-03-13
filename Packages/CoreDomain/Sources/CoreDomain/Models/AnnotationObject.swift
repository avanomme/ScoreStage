import Foundation
import SwiftData

public enum AnnotationObjectType: String, Codable, Sendable {
    case textBox
    case shape
    case stamp
    case image
}

public enum ShapeType: String, Codable, Sendable {
    case circle
    case rectangle
    case underline
    case arrow
}

public enum StampType: String, Codable, Sendable {
    case breathMark
    case bowingUp
    case bowingDown
    case fingering
    case cueMarker
    case cutoff
    case fermata
    case custom
}

@Model
public final class AnnotationObject {
    public var id: UUID
    public var type: AnnotationObjectType
    public var pageIndex: Int
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rotation: Double
    public var colorHex: String
    public var text: String?
    public var fontSize: Double?
    public var shapeType: ShapeType?
    public var stampType: StampType?
    public var imageAssetPath: String?
    public var createdAt: Date

    public var layer: AnnotationLayer?

    public init(
        type: AnnotationObjectType,
        pageIndex: Int,
        x: Double,
        y: Double,
        width: Double = 0,
        height: Double = 0
    ) {
        self.id = UUID()
        self.type = type
        self.pageIndex = pageIndex
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = 0
        self.colorHex = "#000000"
        self.createdAt = Date()
    }
}
