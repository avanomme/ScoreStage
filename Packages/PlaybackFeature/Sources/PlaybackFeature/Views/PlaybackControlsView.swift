// PlaybackControlsView — DAW-style transport controls for score playback.

import SwiftUI
import DesignSystem
import NotationFeature

// MARK: - Playback Controls

/// Floating transport bar with play/pause, tempo, count-in, metronome, and loop controls.
public struct PlaybackControlsView: View {
    @Bindable var engine: PlaybackEngine
    @State private var showingTempoSlider = false

    public init(engine: PlaybackEngine) {
        self.engine = engine
    }

    public var body: some View {
        HStack(spacing: ASSpacing.lg) {
            // Measure indicator
            Text("m. \(engine.currentMeasure)")
                .font(ASTypography.monoSmall)
                .foregroundStyle(.secondary)
                .frame(minWidth: 50)

            Divider().frame(height: 28)

            // Transport buttons
            transportControls

            Divider().frame(height: 28)

            // Tempo
            tempoControl

            Divider().frame(height: 28)

            // Toggles
            toggleControls
        }
        .padding(.horizontal, ASSpacing.xl)
        .padding(.vertical, ASSpacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }

    // MARK: - Transport

    private var transportControls: some View {
        HStack(spacing: ASSpacing.md) {
            // Stop / go to start
            Button {
                engine.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(engine.state == .stopped ? .secondary : .primary)

            // Back one measure
            Button {
                engine.seek(toMeasure: max(1, engine.currentMeasure - 1))
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button {
                if engine.state == .playing {
                    engine.pause()
                } else {
                    engine.play()
                }
            } label: {
                Image(systemName: engine.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(ASColors.accentFallback)
            }
            .buttonStyle(.plain)

            // Forward one measure
            Button {
                engine.seek(toMeasure: engine.currentMeasure + 1)
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tempo

    private var tempoControl: some View {
        VStack(spacing: 2) {
            Button {
                showingTempoSlider.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "metronome")
                        .font(.system(size: 12))
                    Text("\(Int(engine.tempo))")
                        .font(ASTypography.monoSmall)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingTempoSlider) {
                VStack(spacing: ASSpacing.md) {
                    Text("Tempo")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(.secondary)

                    HStack {
                        Text("40")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                        Slider(value: $engine.tempo, in: 40...240, step: 1)
                            .frame(width: 180)
                        Text("240")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }

                    Text("\(Int(engine.tempo)) BPM")
                        .font(ASTypography.mono)
                        .foregroundStyle(ASColors.accentFallback)
                }
                .padding()
            }
        }
    }

    // MARK: - Toggle Controls

    private var toggleControls: some View {
        HStack(spacing: ASSpacing.sm) {
            // Count-in
            toggleButton(
                icon: "arrow.counterclockwise",
                label: "Count",
                isActive: engine.isCountInEnabled
            ) {
                engine.isCountInEnabled.toggle()
            }

            // Metronome
            toggleButton(
                icon: "metronome.fill",
                label: "Click",
                isActive: engine.isMetronomeEnabled
            ) {
                engine.isMetronomeEnabled.toggle()
            }

            // Loop
            toggleButton(
                icon: "repeat",
                label: "Loop",
                isActive: engine.isLooping
            ) {
                engine.isLooping.toggle()
            }
        }
    }

    private func toggleButton(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                Text(label)
                    .font(.system(size: 8, weight: .medium))
            }
            .foregroundStyle(isActive ? ASColors.accentFallback : .secondary)
            .frame(minWidth: 36, minHeight: 36)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loop Region Controls

public struct LoopRegionView: View {
    @Bindable var engine: PlaybackEngine
    let measureCount: Int

    public init(engine: PlaybackEngine, measureCount: Int) {
        self.engine = engine
        self.measureCount = measureCount
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("LOOP REGION")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                Toggle("", isOn: $engine.isLooping)
                    .labelsHidden()
                    .tint(ASColors.accentFallback)
            }

            if engine.isLooping {
                HStack(spacing: ASSpacing.lg) {
                    VStack(alignment: .leading, spacing: ASSpacing.xs) {
                        Text("Start")
                            .font(ASTypography.labelSmall)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "m. \(engine.loopStartMeasure ?? 1)",
                            value: Binding(
                                get: { engine.loopStartMeasure ?? 1 },
                                set: { engine.loopStartMeasure = $0 }
                            ),
                            in: 1...measureCount
                        )
                        .font(ASTypography.monoSmall)
                    }

                    VStack(alignment: .leading, spacing: ASSpacing.xs) {
                        Text("End")
                            .font(ASTypography.labelSmall)
                            .foregroundStyle(.secondary)
                        Stepper(
                            "m. \(engine.loopEndMeasure ?? measureCount)",
                            value: Binding(
                                get: { engine.loopEndMeasure ?? measureCount },
                                set: { engine.loopEndMeasure = $0 }
                            ),
                            in: 1...measureCount
                        )
                        .font(ASTypography.monoSmall)
                    }
                }
            }
        }
        .padding()
    }
}
