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

public struct CanvasAnnotationObject: Identifiable, Sendable {
    public let id: UUID
    public var layerID: UUID
    public var type: AnnotationObjectType
    public var pageIndex: Int
    public var position: CGPoint
    public var size: CGSize
    public var rotation: Double
    public var color: Color
    public var text: String?
    public var fontSize: Double?
    public var shapeType: ShapeType?
    public var stampType: StampType?

    public init(
        id: UUID = UUID(),
        layerID: UUID,
        type: AnnotationObjectType,
        pageIndex: Int,
        position: CGPoint,
        size: CGSize = CGSize(width: 120, height: 40),
        rotation: Double = 0,
        color: Color,
        text: String? = nil,
        fontSize: Double? = nil,
        shapeType: ShapeType? = nil,
        stampType: StampType? = nil
    ) {
        self.id = id
        self.layerID = layerID
        self.type = type
        self.pageIndex = pageIndex
        self.position = position
        self.size = size
        self.rotation = rotation
        self.color = color
        self.text = text
        self.fontSize = fontSize
        self.shapeType = shapeType
        self.stampType = stampType
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
    public var allObjects: [CanvasAnnotationObject] = []
    private var undoStack: [HistoryState] = []
    private var redoStack: [HistoryState] = []
    public var selectedObjectID: UUID?
    public var selectedShapeType: ShapeType = .rectangle
    public var defaultTextValue = "Text"

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
    /// Callback fired when the host should persist a new snapshot.
    public var onCreateSnapshot: ((String) -> Void)?
    /// Callback for restoring a snapshot — set by the hosting view controller.
    public var onRestoreSnapshot: ((UUID) -> Void)?
    public var onRequestExport: (() -> Void)?
    /// Optional layer visibility override supplied by the host.
    public var visibleLayerIDsOverride: Set<UUID>?

    /// The name of the active layer, for display.
    public var activeLayerName: String {
        layers.first(where: { $0.id == activeLayerID })?.name ?? "Default"
    }

    /// IDs of currently visible layers.
    public var visibleLayerIDs: Set<UUID> {
        visibleLayerIDsOverride ?? Set(layers.filter(\.isVisible).map(\.id))
    }

    public init() {
        // Set active layer to the default layer
        activeLayerID = layers.first?.id
    }

    // MARK: - Stroke Operations

    public func addStroke(_ stroke: CanvasStroke) {
        recordHistory()
        allStrokes.append(stroke)
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(makeHistoryState())
        restore(from: previous)
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(makeHistoryState())
        restore(from: next)
        isDirty = true
        updateUndoRedoAvailability()
    }

    /// Remove all strokes on the given page.
    public func clearPage(_ pageIndex: Int) {
        recordHistory()
        allStrokes.removeAll { $0.pageIndex == pageIndex }
        allObjects.removeAll { $0.pageIndex == pageIndex }
        isDirty = true
        selectedObjectID = nil
        updateUndoRedoAvailability()
    }

    /// Remove all strokes on all pages.
    public func clearAll() {
        recordHistory()
        allStrokes.removeAll()
        allObjects.removeAll()
        selectedObjectID = nil
        isDirty = true
        updateUndoRedoAvailability()
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
        recordHistory()
        let nextOrder = (layers.map(\.sortOrder).max() ?? 0) + 1
        let layer = LayerInfo(name: name, type: type, sortOrder: nextOrder)
        layers.append(layer)
        activeLayerID = layer.id
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func removeLayer(_ id: UUID) {
        // Cannot remove the default layer
        guard let layer = layers.first(where: { $0.id == id }), layer.type != .default else { return }
        recordHistory()
        layers.removeAll(where: { $0.id == id })
        allStrokes.removeAll(where: { $0.layerID == id })
        allObjects.removeAll(where: { $0.layerID == id })
        // If we removed the active layer, fall back to default
        if activeLayerID == id {
            activeLayerID = layers.first(where: { $0.type == .default })?.id ?? layers.first?.id
        }
        selectedObjectID = nil
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func setActiveLayer(_ id: UUID) {
        guard layers.contains(where: { $0.id == id }) else { return }
        activeLayerID = id
    }

    public func toggleLayerVisibility(_ id: UUID) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        recordHistory()
        layers[index].isVisible.toggle()
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func renameLayer(_ id: UUID, to name: String) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        recordHistory()
        layers[index].name = name
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func moveLayer(_ id: UUID, direction: MoveDirection) {
        guard let index = layers.firstIndex(where: { $0.id == id }) else { return }
        let targetIndex: Int
        switch direction {
        case .up:
            targetIndex = max(0, index - 1)
        case .down:
            targetIndex = min(layers.count - 1, index + 1)
        }
        guard targetIndex != index else { return }
        recordHistory()
        let layer = layers.remove(at: index)
        layers.insert(layer, at: targetIndex)
        for position in layers.indices {
            layers[position].sortOrder = position
        }
        isDirty = true
        updateUndoRedoAvailability()
    }

    // MARK: - Object Operations

    public func addObject(_ object: CanvasAnnotationObject) {
        recordHistory()
        allObjects.append(object)
        selectedObjectID = object.id
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func updateObject(_ object: CanvasAnnotationObject) {
        guard let index = allObjects.firstIndex(where: { $0.id == object.id }) else { return }
        allObjects[index] = object
        selectedObjectID = object.id
        isDirty = true
    }

    public func beginObjectEdit() {
        recordHistory()
    }

    public func deleteSelectedObject() {
        guard let selectedObjectID else { return }
        recordHistory()
        allObjects.removeAll { $0.id == selectedObjectID }
        self.selectedObjectID = nil
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func duplicateSelectedObject() {
        guard let object = selectedObject else { return }
        recordHistory()
        var duplicate = object
        duplicate = CanvasAnnotationObject(
            layerID: object.layerID,
            type: object.type,
            pageIndex: object.pageIndex,
            position: CGPoint(x: object.position.x + 18, y: object.position.y + 18),
            size: object.size,
            rotation: object.rotation,
            color: object.color,
            text: object.text,
            fontSize: object.fontSize,
            shapeType: object.shapeType,
            stampType: object.stampType
        )
        allObjects.append(duplicate)
        selectedObjectID = duplicate.id
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func setSelectedObject(_ id: UUID?) {
        selectedObjectID = id
    }

    public var selectedObject: CanvasAnnotationObject? {
        allObjects.first(where: { $0.id == selectedObjectID })
    }

    public func commitObjectEdit() {
        isDirty = true
        updateUndoRedoAvailability()
    }

    public func updateSelectedObjectText(_ text: String) {
        guard var object = selectedObject else { return }
        object.text = text
        updateObject(object)
    }

    public func updateSelectedObjectShape(_ shapeType: ShapeType) {
        guard var object = selectedObject else { return }
        object.shapeType = shapeType
        updateObject(object)
    }

    public func updateSelectedObjectColor(_ color: Color) {
        guard var object = selectedObject else { return }
        object.color = color
        updateObject(object)
    }

    // MARK: - Snapshot Operations

    public func createSnapshot(name: String) {
        let snapshot = SnapshotInfo(name: name)
        snapshots.insert(snapshot, at: 0) // newest first
        onCreateSnapshot?(name)
    }

    public func removeSnapshot(_ id: UUID) {
        snapshots.removeAll(where: { $0.id == id })
    }

    // MARK: - History

    public enum MoveDirection {
        case up
        case down
    }

    private struct HistoryState {
        let strokes: [CanvasStroke]
        let objects: [CanvasAnnotationObject]
        let layers: [LayerInfo]
        let activeLayerID: UUID?
        let selectedObjectID: UUID?
    }

    private func makeHistoryState() -> HistoryState {
        HistoryState(
            strokes: allStrokes,
            objects: allObjects,
            layers: layers,
            activeLayerID: activeLayerID,
            selectedObjectID: selectedObjectID
        )
    }

    private func restore(from history: HistoryState) {
        allStrokes = history.strokes
        allObjects = history.objects
        layers = history.layers
        activeLayerID = history.activeLayerID
        selectedObjectID = history.selectedObjectID
    }

    private func recordHistory() {
        undoStack.append(makeHistoryState())
        if undoStack.count > 100 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        updateUndoRedoAvailability()
    }

    private func updateUndoRedoAvailability() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
}

/// Floating Procreate-style annotation palette.
/// This is a separate environment layer — never embedded in Reader chrome.
public struct AnnotationToolbarView: View {
    @Bindable var state: AnnotationState
    @State private var showingColorPicker = false
    @State private var showingWidthSlider = false
    @State private var selectedObjectText = ""

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
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

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.showingSnapshotManager.toggle()
                        state.showingLayerManager = false
                        state.showingStampPicker = false
                        showingColorPicker = false
                        showingWidthSlider = false
                    }
                } label: {
                    Image(systemName: "camera.macro")
                        .font(.system(size: 14, weight: state.showingSnapshotManager ? .semibold : .medium))
                        .foregroundStyle(state.showingSnapshotManager ? ASColors.accentFallback : .primary)
                }
                .buttonStyle(.plain)
                .help("Snapshots")

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

                Button {
                    state.onRequestExport?()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .help("Export Annotations")

                if state.selectedObject != nil {
                    divider

                    Button {
                        state.duplicateSelectedObject()
                    } label: {
                        Image(systemName: "plus.square.on.square")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .help("Duplicate Selection")

                    Button {
                        state.deleteSelectedObject()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Delete Selection")
                }

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
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Done")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ASColors.accentFallback)
                    .padding(.horizontal, ASSpacing.sm)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(ASColors.accentFallback.opacity(0.12))
                    )
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

            if let selectedObject = state.selectedObject {
                objectInspector(selectedObject)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.08),
                    ASColors.chromeSurfaceElevated.opacity(0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
        )
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
                        : AnyShapeStyle(Color.white.opacity(0.03))
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

    private func objectInspector(_ object: CanvasAnnotationObject) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("Selection")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            if object.type == .textBox || object.type == .stamp {
                TextField("Text", text: Binding(
                    get: { object.text ?? selectedObjectText },
                    set: { newValue in
                        selectedObjectText = newValue
                        state.updateSelectedObjectText(newValue)
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
            }

            if object.type == .shape {
                Picker("Shape", selection: Binding(
                    get: { object.shapeType ?? .rectangle },
                    set: { state.updateSelectedObjectShape($0) }
                )) {
                    Text("Rect").tag(ShapeType.rectangle)
                    Text("Circle").tag(ShapeType.circle)
                    Text("Line").tag(ShapeType.underline)
                    Text("Arrow").tag(ShapeType.arrow)
                }
                .pickerStyle(.segmented)
                .font(.system(size: 11))
            }
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 24)
    }
}
