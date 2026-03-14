// PlayheadOverlayView — visual cursor that follows playback position on the score.

import SwiftUI
import DesignSystem

// MARK: - Playhead Overlay

/// Translucent overlay that highlights the current playback position on the score page.
public struct PlayheadOverlayView: View {
    let progress: Double        // 0.0 to 1.0 across the page width
    let isPlaying: Bool

    public init(progress: Double, isPlaying: Bool) {
        self.progress = progress
        self.isPlaying = isPlaying
    }

    public var body: some View {
        GeometryReader { geo in
            if isPlaying {
                // Cursor line
                Rectangle()
                    .fill(ASColors.cursorLine)
                    .frame(width: 2)
                    .position(x: geo.size.width * progress, y: geo.size.height / 2)
                    .animation(.linear(duration: 0.1), value: progress)

                // Glow behind cursor
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                ASColors.cursorGlow,
                                Color.clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 40)
                    .position(x: geo.size.width * progress - 20, y: geo.size.height / 2)
                    .animation(.linear(duration: 0.1), value: progress)

                // Active region highlight
                Rectangle()
                    .fill(ASColors.cursorActive)
                    .frame(width: max(0, geo.size.width * progress))
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Measure Highlight Overlay

/// Highlights the current measure region on the score page.
public struct MeasureHighlightView: View {
    let measureStart: Double    // 0.0 to 1.0 (fraction of page width)
    let measureEnd: Double
    let isActive: Bool

    public init(measureStart: Double, measureEnd: Double, isActive: Bool) {
        self.measureStart = measureStart
        self.measureEnd = measureEnd
        self.isActive = isActive
    }

    public var body: some View {
        GeometryReader { geo in
            if isActive {
                let x = geo.size.width * measureStart
                let width = geo.size.width * (measureEnd - measureStart)

                Rectangle()
                    .fill(ASColors.cursorActive)
                    .frame(width: width, height: geo.size.height)
                    .position(x: x + width / 2, y: geo.size.height / 2)
                    .animation(.easeInOut(duration: 0.2), value: measureStart)
            }
        }
        .allowsHitTesting(false)
    }
}
