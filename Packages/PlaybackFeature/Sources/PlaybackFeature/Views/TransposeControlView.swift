// TransposeControlView — UI for transposing playback up/down by semitones.

import SwiftUI
import DesignSystem

/// Compact transposition control showing current semitone offset.
public struct TransposeControlView: View {
    @Binding var semitones: Int
    let onChanged: ((Int) -> Void)?

    public init(semitones: Binding<Int>, onChanged: ((Int) -> Void)? = nil) {
        self._semitones = semitones
        self.onChanged = onChanged
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("TRANSPOSITION")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                if semitones != 0 {
                    Button("Reset") {
                        semitones = 0
                        onChanged?(0)
                    }
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(ASColors.accentFallback)
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: ASSpacing.lg) {
                // Down button
                Button {
                    if semitones > -12 {
                        semitones -= 1
                        onChanged?(semitones)
                    }
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(semitones > -12 ? .primary : .tertiary)
                }
                .buttonStyle(.plain)

                // Display
                VStack(spacing: 2) {
                    Text(transpositionLabel)
                        .font(ASTypography.mono)
                        .foregroundStyle(semitones == 0 ? .secondary : ASColors.accentFallback)

                    Text(intervalName)
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
                .frame(minWidth: 80)

                // Up button
                Button {
                    if semitones < 12 {
                        semitones += 1
                        onChanged?(semitones)
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(semitones < 12 ? .primary : .tertiary)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(ASSpacing.lg)
    }

    private var transpositionLabel: String {
        if semitones == 0 { return "Concert" }
        let sign = semitones > 0 ? "+" : ""
        return "\(sign)\(semitones) st"
    }

    private var intervalName: String {
        let names = [
            "Unison", "Minor 2nd", "Major 2nd", "Minor 3rd", "Major 3rd",
            "Perfect 4th", "Tritone", "Perfect 5th", "Minor 6th",
            "Major 6th", "Minor 7th", "Major 7th", "Octave"
        ]
        let index = abs(semitones)
        guard index < names.count else { return "" }
        let direction = semitones > 0 ? "up" : "down"
        return semitones == 0 ? "No transposition" : "\(names[index]) \(direction)"
    }
}
