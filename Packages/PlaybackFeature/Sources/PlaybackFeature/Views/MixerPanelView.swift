// MixerPanelView — DAW-style channel strip mixer for muting/soloing parts.

import SwiftUI
import DesignSystem
import NotationFeature

// MARK: - Part Info (lightweight UI model)

public struct PartInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let index: Int

    public init(id: String, name: String, abbreviation: String = "", index: Int) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.index = index
    }

    public init(from part: Part, index: Int) {
        self.id = part.id
        self.name = part.name
        self.abbreviation = part.abbreviation
        self.index = index
    }
}

// MARK: - Mixer Panel

/// Floating mixer with per-part volume, mute, and solo controls.
public struct MixerPanelView: View {
    @Bindable var engine: PlaybackEngine
    let parts: [PartInfo]

    public init(engine: PlaybackEngine, parts: [PartInfo]) {
        self.engine = engine
        self.parts = parts
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            // Header
            HStack {
                Text("MIXER")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                Button("Reset") {
                    engine.mutedParts.removeAll()
                    engine.soloPart = nil
                    for i in engine.partVolumes.indices {
                        engine.partVolumes[i] = 1.0
                    }
                }
                .font(ASTypography.captionSmall)
                .foregroundStyle(ASColors.accentFallback)
                .buttonStyle(.plain)
            }

            Divider()

            // Channel strips
            ForEach(parts) { part in
                channelStrip(for: part)
            }
        }
        .padding(ASSpacing.lg)
        .background(ASColors.chromeSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .strokeBorder(ASColors.chromeBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Channel Strip

    private func channelStrip(for part: PartInfo) -> some View {
        let isMuted = engine.mutedParts.contains(part.index)
        let isSoloed = engine.soloPart == part.index
        let volume = engine.partVolumes.indices.contains(part.index)
            ? engine.partVolumes[part.index] : 1.0

        return HStack(spacing: ASSpacing.md) {
            // Part name
            Text(part.abbreviation.isEmpty ? part.name : part.abbreviation)
                .font(ASTypography.labelSmall)
                .foregroundStyle(isMuted ? .tertiary : .primary)
                .frame(width: 60, alignment: .leading)
                .lineLimit(1)

            // Volume slider
            Slider(
                value: Binding(
                    get: { Double(volume) },
                    set: {
                        if engine.partVolumes.indices.contains(part.index) {
                            engine.partVolumes[part.index] = Float($0)
                        }
                    }
                ),
                in: 0...1
            )
            .tint(isMuted ? .secondary : ASColors.accentFallback)

            // Volume label
            Text("\(Int(volume * 100))%")
                .font(ASTypography.monoMicro)
                .foregroundStyle(.secondary)
                .frame(width: 35, alignment: .trailing)

            // Mute button
            Button {
                if isMuted {
                    engine.mutedParts.remove(part.index)
                } else {
                    engine.mutedParts.insert(part.index)
                }
            } label: {
                Text("M")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isMuted ? .white : .secondary)
                    .frame(width: 24, height: 24)
                    .background(isMuted ? ASColors.warning : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isMuted ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Solo button
            Button {
                if isSoloed {
                    engine.soloPart = nil
                } else {
                    engine.soloPart = part.index
                }
            } label: {
                Text("S")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSoloed ? .white : .secondary)
                    .frame(width: 24, height: 24)
                    .background(isSoloed ? ASColors.accentFallback : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(isSoloed ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, ASSpacing.xs)
    }
}
