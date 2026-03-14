// RehearsalMarksPanel — navigable list of rehearsal marks extracted from notation.

import SwiftUI
import DesignSystem
import NotationFeature

// MARK: - Rehearsal Mark Info

public struct RehearsalMarkInfo: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let measureNumber: Int
    public let startTime: TimeInterval

    public init(label: String, measureNumber: Int, startTime: TimeInterval = 0) {
        self.id = "\(measureNumber)-\(label)"
        self.label = label
        self.measureNumber = measureNumber
        self.startTime = startTime
    }

    /// Extract rehearsal marks from a MeasureMap.
    public static func from(measureMap: MeasureMap) -> [RehearsalMarkInfo] {
        measureMap.rehearsalEntries.compactMap { entry in
            guard let label = entry.rehearsalMark else { return nil }
            return RehearsalMarkInfo(
                label: label,
                measureNumber: entry.measureNumber,
                startTime: entry.startTime
            )
        }
    }
}

// MARK: - Rehearsal Marks Panel

/// Floating panel listing all rehearsal marks with tap-to-navigate.
public struct RehearsalMarksPanel: View {
    let marks: [RehearsalMarkInfo]
    let currentMeasure: Int
    let onNavigate: (Int) -> Void

    public init(marks: [RehearsalMarkInfo], currentMeasure: Int, onNavigate: @escaping (Int) -> Void) {
        self.marks = marks
        self.currentMeasure = currentMeasure
        self.onNavigate = onNavigate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("REHEARSAL MARKS")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                Text("\(marks.count)")
                    .font(ASTypography.monoMicro)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.md)

            Divider()

            if marks.isEmpty {
                VStack(spacing: ASSpacing.sm) {
                    Image(systemName: "signpost.right")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text("No rehearsal marks found")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(ASSpacing.xl)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(marks) { mark in
                            rehearsalRow(mark)
                        }
                    }
                }
            }
        }
        .background(ASColors.chromeSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .strokeBorder(ASColors.chromeBorder, lineWidth: 0.5)
        )
    }

    private func rehearsalRow(_ mark: RehearsalMarkInfo) -> some View {
        let isActive = currentMeasure >= mark.measureNumber &&
            (marks.first(where: { $0.measureNumber > mark.measureNumber })
                .map { currentMeasure < $0.measureNumber } ?? true)

        return Button {
            onNavigate(mark.measureNumber)
        } label: {
            HStack(spacing: ASSpacing.md) {
                // Rehearsal badge
                Text(mark.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isActive ? .white : ASColors.accentFallback)
                    .frame(width: 32, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: ASRadius.sm)
                            .fill(isActive ? ASColors.accentFallback : ASColors.accentFallback.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Measure \(mark.measureNumber)")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.primary)

                    Text(formatTime(mark.startTime))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "play.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.sm)
            .background(isActive ? ASColors.chromeSurfaceSelected : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
