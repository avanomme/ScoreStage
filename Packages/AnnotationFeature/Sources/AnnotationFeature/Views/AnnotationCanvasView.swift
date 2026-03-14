import SwiftUI
import CoreDomain

/// Stored stroke with its layer association and visual properties.
public struct CanvasStroke: Identifiable {
    public let id = UUID()
    public var points: [CGPoint]
    public var layerID: UUID
    public var color: Color
    public var lineWidth: CGFloat
    public var opacity: Double
}

/// A canvas overlay for drawing annotations on top of a PDF page.
/// Layer-aware: only renders strokes for visible layers, writes to active layer.
public struct AnnotationCanvasView: View {
    let pageIndex: Int
    let pageSize: CGSize
    @Bindable var state: AnnotationState
    @State private var currentPath: [CGPoint] = []
    @State private var completedStrokes: [CanvasStroke] = []
    @State private var undoneStrokes: [CanvasStroke] = []

    public init(pageIndex: Int, pageSize: CGSize, state: AnnotationState) {
        self.pageIndex = pageIndex
        self.pageSize = pageSize
        self.state = state
    }

    public var body: some View {
        Canvas { context, _ in
            let visibleIDs = state.visibleLayerIDs
            // Draw completed strokes for visible layers
            for stroke in completedStrokes where visibleIDs.contains(stroke.layerID) {
                drawStroke(stroke, in: &context)
            }
            // Draw current stroke (always visible while drawing)
            if !currentPath.isEmpty {
                let activeStroke = CanvasStroke(
                    points: currentPath,
                    layerID: state.activeLayerID ?? UUID(),
                    color: state.selectedColor,
                    lineWidth: state.lineWidth,
                    opacity: state.opacity
                )
                drawStroke(activeStroke, in: &context)
            }
        }
        .gesture(drawingGesture)
        .allowsHitTesting(state.isAnnotating && state.selectedTool != .text)
        .onChange(of: completedStrokes.count) {
            state.canUndo = !completedStrokes.isEmpty
            state.canRedo = !undoneStrokes.isEmpty
        }
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                currentPath.append(value.location)
            }
            .onEnded { _ in
                if !currentPath.isEmpty, let activeID = state.activeLayerID {
                    let stroke = CanvasStroke(
                        points: currentPath,
                        layerID: activeID,
                        color: state.selectedColor,
                        lineWidth: state.lineWidth,
                        opacity: state.opacity
                    )
                    completedStrokes.append(stroke)
                    undoneStrokes.removeAll()
                    currentPath = []
                }
            }
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

    public func undo() {
        guard let last = completedStrokes.popLast() else { return }
        undoneStrokes.append(last)
    }

    public func redo() {
        guard let last = undoneStrokes.popLast() else { return }
        completedStrokes.append(last)
    }
}
