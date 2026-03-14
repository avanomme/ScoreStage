import SwiftUI
import CoreDomain
import DesignSystem

/// Floating layer management panel for annotation layers.
/// Supports creating, selecting, toggling visibility, reordering, and deleting layers.
public struct LayerManagerView: View {
    @Bindable var state: AnnotationState
    @State private var isAddingLayer = false
    @State private var newLayerName = ""
    @State private var newLayerType: AnnotationLayerType = .custom

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            layerList
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Layers")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAddingLayer.toggle()
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isAddingLayer) {
                addLayerPopover
            }
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
    }

    // MARK: - Layer List

    private var layerList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(state.layers) { layer in
                    layerRow(layer)
                    if layer.id != state.layers.last?.id {
                        Divider().padding(.leading, ASSpacing.xl)
                    }
                }
            }
        }
        .frame(maxHeight: 240)
    }

    // MARK: - Layer Row

    private func layerRow(_ layer: LayerInfo) -> some View {
        HStack(spacing: ASSpacing.sm) {
            // Visibility toggle
            Button {
                state.toggleLayerVisibility(layer.id)
            } label: {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(layer.isVisible ? .primary : .tertiary)
                    .frame(width: 20)
            }
            .buttonStyle(.plain)

            // Layer type icon
            Image(systemName: iconForLayerType(layer.type))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(colorForLayerType(layer.type))
                .frame(width: 16)

            // Layer name
            Text(layer.name)
                .font(.system(size: 12, weight: state.activeLayerID == layer.id ? .semibold : .regular))
                .lineLimit(1)

            Spacer()

            // Active indicator
            if state.activeLayerID == layer.id {
                Circle()
                    .fill(ASColors.accentFallback)
                    .frame(width: 6, height: 6)
            }

            // Delete (only non-default layers)
            if layer.type != .default {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.removeLayer(layer.id)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ASSpacing.md)
        .padding(.vertical, ASSpacing.sm)
        .background(
            state.activeLayerID == layer.id
                ? AnyShapeStyle(ASColors.accentFallback.opacity(0.08))
                : AnyShapeStyle(Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            state.setActiveLayer(layer.id)
        }
    }

    // MARK: - Add Layer Popover

    private var addLayerPopover: some View {
        VStack(spacing: ASSpacing.md) {
            Text("New Layer")
                .font(.system(size: 13, weight: .semibold))

            TextField("Layer Name", text: $newLayerName)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))

            Picker("Type", selection: $newLayerType) {
                Text("Teacher").tag(AnnotationLayerType.teacher)
                Text("Performer").tag(AnnotationLayerType.performer)
                Text("Rehearsal").tag(AnnotationLayerType.rehearsal)
                Text("Custom").tag(AnnotationLayerType.custom)
            }
            .pickerStyle(.segmented)
            .font(.system(size: 11))

            HStack {
                Button("Cancel") {
                    isAddingLayer = false
                    newLayerName = ""
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))

                Spacer()

                Button("Add") {
                    let name = newLayerName.isEmpty ? defaultName(for: newLayerType) : newLayerName
                    state.addLayer(name: name, type: newLayerType)
                    newLayerName = ""
                    isAddingLayer = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ASColors.accentFallback)
            }
        }
        .padding(ASSpacing.md)
        .frame(width: 200)
    }

    // MARK: - Helpers

    private func iconForLayerType(_ type: AnnotationLayerType) -> String {
        switch type {
        case .default: "square.stack"
        case .teacher: "person.fill"
        case .performer: "music.note"
        case .rehearsal: "metronome"
        case .custom: "paintbrush"
        }
    }

    private func colorForLayerType(_ type: AnnotationLayerType) -> Color {
        switch type {
        case .default: .primary
        case .teacher: ASColors.annotationBlue
        case .performer: ASColors.annotationGreen
        case .rehearsal: ASColors.annotationPurple
        case .custom: ASColors.annotationRed
        }
    }

    private func defaultName(for type: AnnotationLayerType) -> String {
        switch type {
        case .default: "Default"
        case .teacher: "Teacher"
        case .performer: "Performer"
        case .rehearsal: "Rehearsal"
        case .custom: "Custom"
        }
    }
}
