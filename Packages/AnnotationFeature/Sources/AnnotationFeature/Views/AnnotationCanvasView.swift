import SwiftUI
import CoreDomain

/// A canvas overlay for drawing annotations on top of a PDF page.
public struct AnnotationCanvasView: View {
    let pageIndex: Int
    let pageSize: CGSize
    @Bindable var state: AnnotationState
    @State private var currentPath: [CGPoint] = []
    @State private var completedStrokes: [[CGPoint]] = []
    @State private var undoneStrokes: [[CGPoint]] = []

    public init(pageIndex: Int, pageSize: CGSize, state: AnnotationState) {
        self.pageIndex = pageIndex
        self.pageSize = pageSize
        self.state = state
    }

    public var body: some View {
        Canvas { context, size in
            // Draw completed strokes
            for stroke in completedStrokes {
                drawStroke(stroke, in: &context, size: size)
            }
            // Draw current stroke
            if !currentPath.isEmpty {
                drawStroke(currentPath, in: &context, size: size)
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
                if !currentPath.isEmpty {
                    completedStrokes.append(currentPath)
                    undoneStrokes.removeAll()
                    currentPath = []
                }
            }
    }

    private func drawStroke(_ points: [CGPoint], in context: inout GraphicsContext, size: CGSize) {
        guard points.count > 1 else { return }
        var path = Path()
        path.move(to: points[0])
        for point in points.dropFirst() {
            path.addLine(to: point)
        }

        context.opacity = state.opacity
        context.stroke(
            path,
            with: .color(state.selectedColor),
            style: StrokeStyle(
                lineWidth: state.lineWidth,
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
