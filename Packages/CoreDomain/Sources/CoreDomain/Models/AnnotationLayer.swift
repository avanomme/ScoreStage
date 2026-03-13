import Foundation
import SwiftData

public enum AnnotationLayerType: String, Codable, Sendable {
    case `default`
    case teacher
    case performer
    case rehearsal
    case custom
}

@Model
public final class AnnotationLayer {
    public var id: UUID
    public var name: String
    public var type: AnnotationLayerType
    public var isVisible: Bool
    public var sortOrder: Int
    public var createdAt: Date
    public var modifiedAt: Date

    public var score: Score?

    @Relationship(deleteRule: .cascade, inverse: \AnnotationStroke.layer)
    public var strokes: [AnnotationStroke]

    @Relationship(deleteRule: .cascade, inverse: \AnnotationObject.layer)
    public var objects: [AnnotationObject]

    public init(
        name: String,
        type: AnnotationLayerType = .default,
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.isVisible = true
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.strokes = []
        self.objects = []
    }
}
