import Foundation
import SwiftData

public enum StrokeTool: String, Codable, Sendable {
    case pen
    case pencil
    case highlighter
    case eraser
}

@Model
public final class AnnotationStroke {
    public var id: UUID
    public var tool: StrokeTool
    public var colorHex: String
    public var lineWidth: Double
    public var opacity: Double
    public var pageIndex: Int
    public var pointsData: Data
    public var createdAt: Date

    public var layer: AnnotationLayer?

    public init(
        tool: StrokeTool,
        colorHex: String = "#000000",
        lineWidth: Double = 2.0,
        opacity: Double = 1.0,
        pageIndex: Int = 0,
        pointsData: Data = Data()
    ) {
        self.id = UUID()
        self.tool = tool
        self.colorHex = colorHex
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.pageIndex = pageIndex
        self.pointsData = pointsData
        self.createdAt = Date()
    }
}
