import SwiftUI
import CoreDomain
import DesignSystem

public enum AnnotationTool: String, CaseIterable, Identifiable {
    case pen
    case pencil
    case highlighter
    case eraser
    case text
    case shape

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .pen: "pencil.tip"
        case .pencil: "pencil"
        case .highlighter: "highlighter"
        case .eraser: "eraser"
        case .text: "textformat"
        case .shape: "square.on.circle"
        }
    }

    public var label: String {
        switch self {
        case .pen: "Pen"
        case .pencil: "Pencil"
        case .highlighter: "Highlighter"
        case .eraser: "Eraser"
        case .text: "Text"
        case .shape: "Shape"
        }
    }
}

@MainActor
@Observable
public final class AnnotationState {
    public var isAnnotating = false
    public var selectedTool: AnnotationTool = .pen
    public var selectedColor: Color = ASColors.annotationBlack
    public var lineWidth: CGFloat = 2.0
    public var opacity: Double = 1.0
    public var canUndo = false
    public var canRedo = false

    public init() {}

    public func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
        // Set defaults per tool
        switch tool {
        case .pen:
            lineWidth = 2.0; opacity = 1.0
        case .pencil:
            lineWidth = 1.5; opacity = 0.8
        case .highlighter:
            lineWidth = 12.0; opacity = 0.3
            selectedColor = ASColors.annotationYellow
        case .eraser:
            lineWidth = 20.0; opacity = 1.0
        case .text:
            lineWidth = 1.0; opacity = 1.0
        case .shape:
            lineWidth = 2.0; opacity = 1.0
        }
    }
}

public struct AnnotationToolbarView: View {
    @Bindable var state: AnnotationState

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: ASSpacing.xs) {
            // Tool picker
            ForEach(AnnotationTool.allCases) { tool in
                Button {
                    state.selectTool(tool)
                } label: {
                    Image(systemName: tool.icon)
                        .font(.body)
                        .frame(width: 36, height: 36)
                        .background(state.selectedTool == tool ? ASColors.accentFallback.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm))
                }
                .buttonStyle(.plain)
                .help(tool.label)
            }

            Divider().frame(height: 28)

            // Color picker
            ForEach(ASColors.annotationPalette, id: \.self) { color in
                Button {
                    state.selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if state.selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                                    .frame(width: 20, height: 20)
                            }
                        }
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 28)

            // Line width
            Slider(value: $state.lineWidth, in: 0.5...20)
                .frame(width: 80)

            Divider().frame(height: 28)

            // Undo / Redo
            Button { /* undo action */ } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!state.canUndo)
            .buttonStyle(.plain)

            Button { /* redo action */ } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!state.canRedo)
            .buttonStyle(.plain)

            Spacer()

            // Done
            Button {
                state.isAnnotating = false
            } label: {
                Text("Done")
                    .font(ASTypography.label)
                    .foregroundStyle(ASColors.accentFallback)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
        .background(.ultraThinMaterial)
    }
}
