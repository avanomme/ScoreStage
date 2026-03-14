import SwiftUI
import CoreDomain
import DesignSystem

/// Musical stamp/symbol definition for the annotation stamp picker.
public struct StampSymbol: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let category: StampCategory
    public let icon: String // SF Symbol name or custom glyph
    public let stampType: StampType

    public init(id: String, name: String, category: StampCategory, icon: String, stampType: StampType) {
        self.id = id
        self.name = name
        self.category = category
        self.icon = icon
        self.stampType = stampType
    }
}

public enum StampCategory: String, CaseIterable, Identifiable, Sendable {
    case breathing = "Breathing"
    case bowing = "Bowing"
    case dynamics = "Dynamics"
    case rehearsal = "Rehearsal"
    case symbols = "Symbols"

    public var id: String { rawValue }
}

/// Predefined musical stamps library.
public enum StampLibrary {
    public static let allStamps: [StampSymbol] = [
        // Breathing
        StampSymbol(id: "breath", name: "Breath Mark", category: .breathing, icon: "wind", stampType: .breathMark),
        StampSymbol(id: "cutoff", name: "Cutoff", category: .breathing, icon: "xmark.circle", stampType: .cutoff),

        // Bowing
        StampSymbol(id: "bowUp", name: "Up Bow", category: .bowing, icon: "chevron.up", stampType: .bowingUp),
        StampSymbol(id: "bowDown", name: "Down Bow", category: .bowing, icon: "chevron.down", stampType: .bowingDown),

        // Dynamics
        StampSymbol(id: "fermata", name: "Fermata", category: .dynamics, icon: "pause.circle", stampType: .fermata),

        // Rehearsal
        StampSymbol(id: "cue", name: "Cue Marker", category: .rehearsal, icon: "flag.fill", stampType: .cueMarker),

        // Symbols
        StampSymbol(id: "fingering", name: "Fingering", category: .symbols, icon: "hand.raised", stampType: .fingering),
    ]

    public static func stamps(for category: StampCategory) -> [StampSymbol] {
        allStamps.filter { $0.category == category }
    }
}

/// Floating stamp picker palette for musical symbols.
public struct StampPickerView: View {
    @Bindable var state: AnnotationState
    @State private var selectedCategory: StampCategory = .breathing

    public init(state: AnnotationState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Category tabs
            categoryTabs

            Divider()

            // Stamp grid
            stampGrid
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ASSpacing.xs) {
                ForEach(StampCategory.allCases) { category in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 11, weight: selectedCategory == category ? .semibold : .regular))
                            .padding(.horizontal, ASSpacing.sm)
                            .padding(.vertical, ASSpacing.xs)
                            .background(
                                selectedCategory == category
                                    ? ASColors.accentFallback.opacity(0.12)
                                    : Color.clear
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
        }
    }

    // MARK: - Stamp Grid

    private var stampGrid: some View {
        let stamps = StampLibrary.stamps(for: selectedCategory)
        return LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 52), spacing: ASSpacing.sm)
        ], spacing: ASSpacing.sm) {
            ForEach(stamps) { stamp in
                stampButton(stamp)
            }
        }
        .padding(ASSpacing.md)
    }

    // MARK: - Stamp Button

    private func stampButton(_ stamp: StampSymbol) -> some View {
        Button {
            state.selectedStamp = stamp
            state.selectedTool = .shape // Switch to placement mode
        } label: {
            VStack(spacing: 3) {
                Image(systemName: stamp.icon)
                    .font(.system(size: 20, weight: .light))
                    .frame(width: 36, height: 36)
                    .background(
                        state.selectedStamp?.id == stamp.id
                            ? ASColors.accentFallback.opacity(0.15)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))

                Text(stamp.name)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(state.selectedStamp?.id == stamp.id ? ASColors.accentFallback : .primary)
        }
        .buttonStyle(.plain)
    }
}
