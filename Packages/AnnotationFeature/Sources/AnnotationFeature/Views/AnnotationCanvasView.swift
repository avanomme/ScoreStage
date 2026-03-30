import SwiftUI
import CoreDomain

/// Stored stroke with its layer association and visual properties.
public struct CanvasStroke: Identifiable, Sendable {
    public let id: UUID
    public var points: [CGPoint]
    public var layerID: UUID
    public var color: Color
    public var lineWidth: CGFloat
    public var opacity: Double
    public var pageIndex: Int

    public init(
        id: UUID = UUID(),
        points: [CGPoint],
        layerID: UUID,
        color: Color,
        lineWidth: CGFloat,
        opacity: Double,
        pageIndex: Int = 0
    ) {
        self.id = id
        self.points = points
        self.layerID = layerID
        self.color = color
        self.lineWidth = lineWidth
        self.opacity = opacity
        self.pageIndex = pageIndex
    }
}

/// A canvas overlay for drawing annotations on top of a PDF page.
/// Renders strokes and objects even outside edit mode; hit testing is enabled only while annotating.
public struct AnnotationCanvasView: View {
    let pageIndex: Int
    let pageSize: CGSize
    let visibleLayerIDsOverride: Set<UUID>?
    @Bindable var state: AnnotationState
    @State private var currentPath: [CGPoint] = []
    @State private var objectEditOrigin: CanvasAnnotationObject?
    @State private var objectDragOffset: CGSize = .zero
    @State private var objectResizeDelta: CGSize = .zero

    public init(pageIndex: Int, pageSize: CGSize, visibleLayerIDsOverride: Set<UUID>? = nil, state: AnnotationState) {
        self.pageIndex = pageIndex
        self.pageSize = pageSize
        self.visibleLayerIDsOverride = visibleLayerIDsOverride
        self.state = state
    }

    private var pageStrokes: [CanvasStroke] {
        state.allStrokes.filter { $0.pageIndex == pageIndex }
    }

    private var pageObjects: [CanvasAnnotationObject] {
        state.allObjects.filter { $0.pageIndex == pageIndex }
    }

    public var body: some View {
        ZStack {
            Canvas { context, _ in
                let visibleIDs = visibleLayerIDsOverride ?? state.visibleLayerIDs
                for stroke in pageStrokes where visibleIDs.contains(stroke.layerID) {
                    drawStroke(stroke, in: &context)
                }
                if !currentPath.isEmpty {
                    let activeStroke = CanvasStroke(
                        points: currentPath,
                        layerID: state.activeLayerID ?? UUID(),
                        color: state.selectedColor,
                        lineWidth: state.lineWidth,
                        opacity: state.opacity,
                        pageIndex: pageIndex
                    )
                    drawStroke(activeStroke, in: &context)
                }
            }

            ForEach(pageObjects) { object in
                if (visibleLayerIDsOverride ?? state.visibleLayerIDs).contains(object.layerID) {
                    annotationObjectView(object)
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(toolGesture)
        .allowsHitTesting(state.isAnnotating)
    }

    private var toolGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                guard state.isAnnotating, let activeLayerID = state.activeLayerID else { return }
                switch state.selectedTool {
                case .text:
                    state.addObject(
                        CanvasAnnotationObject(
                            layerID: activeLayerID,
                            type: .textBox,
                            pageIndex: pageIndex,
                            position: value.location,
                            size: CGSize(width: 160, height: 44),
                            color: state.selectedColor,
                            text: state.defaultTextValue,
                            fontSize: 24
                        )
                    )
                case .shape:
                    let stampType = state.selectedStamp?.stampType
                    let objectType: AnnotationObjectType = stampType == nil ? .shape : .stamp
                    state.addObject(
                        CanvasAnnotationObject(
                            layerID: activeLayerID,
                            type: objectType,
                            pageIndex: pageIndex,
                            position: value.location,
                            size: CGSize(width: 120, height: 48),
                            color: state.selectedColor,
                            text: stampText(for: stampType),
                            fontSize: objectType == .stamp ? 22 : nil,
                            shapeType: objectType == .shape ? state.selectedShapeType : nil,
                            stampType: stampType
                        )
                    )
                    if stampType != nil {
                        state.selectedStamp = nil
                    }
                default:
                    break
                }
            }
            .exclusively(before: drawingGesture)
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard state.isAnnotating else { return }
                switch state.selectedTool {
                case .pen, .pencil, .highlighter, .eraser:
                    currentPath.append(value.location)
                default:
                    break
                }
            }
            .onEnded { _ in
                guard state.isAnnotating else { return }
                if !currentPath.isEmpty, let activeID = state.activeLayerID {
                    let stroke = CanvasStroke(
                        points: currentPath,
                        layerID: activeID,
                        color: state.selectedColor,
                        lineWidth: state.lineWidth,
                        opacity: state.opacity,
                        pageIndex: pageIndex
                    )
                    state.addStroke(stroke)
                    currentPath = []
                }
            }
    }

    private func annotationObjectView(_ object: CanvasAnnotationObject) -> some View {
        let isSelected = state.selectedObjectID == object.id
        let dragGesture = DragGesture()
            .onChanged { value in
                guard state.isAnnotating else { return }
                if objectEditOrigin == nil {
                    objectEditOrigin = object
                    state.beginObjectEdit()
                }
                objectDragOffset = value.translation
                if let origin = objectEditOrigin {
                    var updated = origin
                    updated.position = CGPoint(
                        x: origin.position.x + value.translation.width,
                        y: origin.position.y + value.translation.height
                    )
                    state.updateObject(updated)
                }
            }
            .onEnded { _ in
                objectEditOrigin = nil
                objectDragOffset = .zero
                state.commitObjectEdit()
            }

        return ZStack(alignment: .bottomTrailing) {
            annotationObjectShape(object)
                .frame(width: max(28, object.size.width), height: max(24, object.size.height))
                .rotationEffect(.degrees(object.rotation))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(isSelected ? state.selectedColor.opacity(0.85) : Color.clear, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                )

            if state.isAnnotating && isSelected {
                resizeHandle(for: object)
                    .offset(x: 8, y: 8)
            }
        }
        .position(object.position)
        .gesture(dragGesture)
        .onTapGesture {
            if state.isAnnotating {
                state.setSelectedObject(object.id)
            }
        }
        .contextMenu {
            if state.isAnnotating {
                Button("Duplicate") { state.duplicateSelectedObject() }
                Button("Delete", role: .destructive) { state.deleteSelectedObject() }
            }
        }
    }

    @ViewBuilder
    private func annotationObjectShape(_ object: CanvasAnnotationObject) -> some View {
        switch object.type {
        case .textBox:
            Text(object.text ?? "")
                .font(.system(size: object.fontSize ?? 24, weight: .semibold))
                .foregroundStyle(object.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .background(Color.white.opacity(0.001))
        case .shape:
            shapeView(for: object)
        case .stamp:
            Text(object.text ?? stampText(for: object.stampType))
                .font(.system(size: object.fontSize ?? 22, weight: .semibold))
                .foregroundStyle(object.color)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .image:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(object.color.opacity(0.08))
                .overlay(
                    Image(systemName: "photo")
                        .foregroundStyle(object.color)
                )
        }
    }

    @ViewBuilder
    private func shapeView(for object: CanvasAnnotationObject) -> some View {
        switch object.shapeType ?? .rectangle {
        case .circle:
            Circle()
                .stroke(object.color, lineWidth: max(1.5, state.lineWidth))
        case .rectangle:
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(object.color, lineWidth: max(1.5, state.lineWidth))
        case .underline:
            VStack {
                Spacer()
                Rectangle()
                    .fill(object.color)
                    .frame(height: max(2, state.lineWidth))
            }
        case .arrow:
            Path { path in
                let width = object.size.width
                let height = object.size.height
                let midY = height / 2
                path.move(to: CGPoint(x: 0, y: midY))
                path.addLine(to: CGPoint(x: width - 16, y: midY))
                path.addLine(to: CGPoint(x: width - 28, y: midY - 10))
                path.move(to: CGPoint(x: width - 16, y: midY))
                path.addLine(to: CGPoint(x: width - 28, y: midY + 10))
            }
            .stroke(object.color, style: StrokeStyle(lineWidth: max(2, state.lineWidth), lineCap: .round, lineJoin: .round))
        }
    }

    private func resizeHandle(for object: CanvasAnnotationObject) -> some View {
        let resizeGesture = DragGesture()
            .onChanged { value in
                guard state.isAnnotating else { return }
                if objectEditOrigin == nil {
                    objectEditOrigin = object
                    state.beginObjectEdit()
                }
                objectResizeDelta = value.translation
                if let origin = objectEditOrigin {
                    var updated = origin
                    updated.size = CGSize(
                        width: max(40, origin.size.width + value.translation.width),
                        height: max(24, origin.size.height + value.translation.height)
                    )
                    if updated.type == .textBox {
                        updated.fontSize = max(14, min(48, (updated.fontSize ?? 24) + value.translation.height * 0.08))
                    }
                    state.updateObject(updated)
                }
            }
            .onEnded { _ in
                objectEditOrigin = nil
                objectResizeDelta = .zero
                state.commitObjectEdit()
            }

        return Circle()
            .fill(state.selectedColor)
            .frame(width: 14, height: 14)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 1))
            .gesture(resizeGesture)
    }

    private func drawStroke(_ stroke: CanvasStroke, in context: inout GraphicsContext) {
        guard stroke.points.count > 1 else { return }
        var path = Path()
        path.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            path.addLine(to: point)
        }

        context.opacity = stroke.opacity
        context.stroke(
            path,
            with: .color(stroke.color),
            style: StrokeStyle(
                lineWidth: stroke.lineWidth,
                lineCap: .round,
                lineJoin: .round
            )
        )
        context.opacity = 1.0
    }

    private func stampText(for stampType: StampType?) -> String {
        switch stampType {
        case .breathMark: "ˇ"
        case .bowingUp: "⌃"
        case .bowingDown: "⌄"
        case .fingering: "1"
        case .cueMarker: "Cue"
        case .cutoff: "Cut"
        case .fermata: "𝄐"
        case .custom, .none: "♪"
        }
    }
}
