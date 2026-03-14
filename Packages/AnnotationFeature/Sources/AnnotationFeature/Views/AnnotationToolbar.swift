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

/// Lightweight layer info for UI display without SwiftData coupling.
public struct LayerInfo: Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public var type: AnnotationLayerType
    public var isVisible: Bool
    public var sortOrder: Int

    public init(
        id: UUID = UUID(),
        name: String,
        type: AnnotationLayerType = .default,
        isVisible: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isVisible = isVisible
        self.sortOrder = sortOrder
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
    /// Whether strokes have changed since last save.
    public var isDirty = false

    // MARK: - Stroke Storage (centralized across pages)

    public var allStrokes: [CanvasStroke] = []
    private var undoneStrokes: [CanvasStroke] = []

    /// Callback fired when annotations should be saved (on Done / exit).
    public var onSave: (() -> Void)?
    /// Callback fired when clear page is tapped — caller provides current page index.
    public var onClearPage: (() -> Void)?

    // MARK: - Layer Management

    public var layers: [LayerInfo] = [
        LayerInfo(name: "Default", type: .default, sortOrder: 0)
    ]
    public var activeLayerID: UUID?
    public var showingLayerManager = false

    // MARK: - Stamp Selection

    public var selectedStamp: StampSymbol?
    public var showingStampPicker = false

    // MARK: - Snapshot Management

    public var snapshots: [SnapshotInfo] = []
    public var showingSnapshotManager = false
    /// Callback for restoring a snapshot — set by the hosting view controller.
    public var onRestoreSnapshot: ((UUID) -> Void)?

    /// The name of the active layer, for display.
    public var activeLayerName: String {
        layers.first(where: { $0.id == activeLayerID })?.name ?? "Default"
    }

    /// IDs of currently visible layers.
    public var visibleLayerIDs: Set<UUID> {
        Set(layers.filter(\.isVisible).map(\.id))
    }

    public init() {
        // Set active layer to the default layer
        activeLayerID = layers.first?.id
    }

    // MARK: - Stroke Operations

    public func addStroke(_ stroke: CanvasStroke) {
        allStrokes.append(stroke)
        undoneStrokes.removeAll()
        isDirty = true
        canUndo = true
        canRedo = false
    }

    public func undo() {
        guard let last = allStrokes.popLast() else { return }
        undoneStrokes.append(last)
        isDirty = true
        canUndo = !allStrokes.isEmpty
        canRedo = true
    }

    public func redo() {
        guard let last = undoneStrokes.popLast() else { return }
        allStrokes.append(last)
        isDirty = true
        canUndo = true
        canRedo = !undoneStrokes.isEmpty
    }

    /// Remove all strokes on the given page.
    public func clearPage(_ pageIndex: Int) {
        allStrokes.removeAll { $0.pageIndex == pageIndex }
        isDirty = true
        canUndo = !allStrokes.isEmpty
    }

    /// Remove all strokes on all pages.
    public func clearAll() {
        allStrokes.removeAll()
        undoneStrokes.removeAll()
        isDirty = true
        canUndo = false
        canRedo = false
    }

    /// Save and exit annotation mode.
    public func saveAndExit() {
        if isDirty {
            onSave?()
            isDirty = false
        }
        isAnnotating = false
    }

    // MARK: - Tool Selection

    public func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
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

    // MARK: - Layer Operations

    public func addLayer(name: String, type: AnnotationLayerType) {
        let nextOrder = (layers.map(\.sortOrder).max() ?? 0) + 1
        let layer = LayerInfo(name: name, type: type, sortOrder: nextOrder)
        layers.append(layer)
        activeLayerID = layer.id
    }

    public func removeLayer(_ id: UUID) {
        // Cannot remove the default layer
        guard let layer = layers.first(where: { $0.id == id }), layer.type != .default else { return }
        layers.removeAll(where: { $0.id == id })
        // If we removed the active layer, fall back to default
        if activeLayerID == id {
            activeLayerID = layers.first(where: { $0.type == .default })?.id ?? layers.first?.id
        }
    }

    public func setActiveLayer(_ id: UUID) {
        guard layers.contains(where: { $0.id == id }) else { return }
        activeLayerID = id
    }

    public func toggleLayerVisibility(_ id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].isVisible.toggle()
    }

    public func renameLayer(_ id: UUID, to name: String) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        layers[index].name = name
    }

    // MARK: - Snapshot Operations

    public func createSnapshot(name: String) {
        let snapshot = SnapshotInfo(name: name)
        snapshots.insert(snapshot, at: 0) // newest first
    }

    public func removeSnapshot(_ id: UUID) {
        snapshots.removeAll(where: { $0.id == id })
    }
}

/// Floating Procreate-style annotation palette.
/// This is a separate environment layer — never embedded in Reader chrome.
public struct AnnotationToolbarView: View {
    @Bindable var state: AnnotationState
    @State private var showingColorPicker = false
    @State private var showingWidthSlider = false

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main tool strip
            HStack(spacing: ASSpacing.xs) {
                ForEach(AnnotationTool.allCases) { tool in
                    toolButton(tool)
                }

                divider

                // Active color indicator + picker toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingColorPicker.toggle()
                        showingWidthSlider = false
                    }
                } label: {
                    Circle()
                        .fill(state.selectedColor)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .buttonStyle(.plain)

                // Line width indicator
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingWidthSlider.toggle()
                        showingColorPicker = false
                    }
                } label: {
                    Circle()
                        .fill(.primary)
                        .frame(width: min(state.lineWidth * 1.5, 18), height: min(state.lineWidth * 1.5, 18))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                // Stamp picker toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.showingStampPicker.toggle()
                        showingColorPicker = false
                        showingWidthSlider = false
                    }
                } label: {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: state.showingStampPicker ? .semibold : .medium))
                        .foregroundStyle(state.showingStampPicker ? ASColors.accentFallback : .primary)
                }
                .buttonStyle(.plain)
                .help("Stamps & Symbols")

                divider

                // Undo / Redo
                Button { state.undo() } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(!state.canUndo)
                .buttonStyle(.plain)

                Button { state.redo() } label: {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 14, weight: .medium))
                }
                .disabled(!state.canRedo)
                .buttonStyle(.plain)

                divider

                // Layers toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.showingLayerManager.toggle()
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "square.stack.3d.up")
                            .font(.system(size: 13, weight: .medium))
                        Text(state.activeLayerName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(state.showingLayerManager ? ASColors.accentFallback : .primary)
                }
                .buttonStyle(.plain)

                divider

                // Clear page
                Button {
                    state.onClearPage?()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear Page Annotations")

                divider

                // Done — save and exit annotation environment
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.saveAndExit()
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ASColors.accentFallback)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)

            // Expandable color palette
            if showingColorPicker {
                colorPalette
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Expandable width slider
            if showingWidthSlider {
                widthSlider
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - Tool Button

    private func toolButton(_ tool: AnnotationTool) -> some View {
        Button {
            state.selectTool(tool)
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 16, weight: state.selectedTool == tool ? .semibold : .light))
                .frame(width: 34, height: 34)
                .background(
                    state.selectedTool == tool
                        ? AnyShapeStyle(ASColors.accentFallback.opacity(0.15))
                        : AnyShapeStyle(Color.clear)
                )
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }

    // MARK: - Color Palette

    private var colorPalette: some View {
        HStack(spacing: ASSpacing.sm) {
            ForEach(ASColors.annotationPalette, id: \.self) { color in
                Button {
                    state.selectedColor = color
                } label: {
                    Circle()
                        .fill(color)
                        .frame(width: 26, height: 26)
                        .overlay {
                            if state.selectedColor == color {
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2.5)
                                    .frame(width: 20, height: 20)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Width Slider

    private var widthSlider: some View {
        HStack(spacing: ASSpacing.md) {
            Circle()
                .fill(.primary)
                .frame(width: 3, height: 3)

            Slider(value: $state.lineWidth, in: 0.5...20)
                .frame(width: 120)

            Circle()
                .fill(.primary)
                .frame(width: 14, height: 14)
        }
        .padding(.horizontal, ASSpacing.lg)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(.quaternary)
            .frame(width: 1, height: 24)
    }
}
