// MotionTrackingCalibrationView — Calibration and training screen for head/eye tracking.

import SwiftUI
import DesignSystem

/// Calibration screen for head movement and eye gaze page turning.
/// Shows camera preview, detection state, sensitivity controls, and training mode.
public struct MotionTrackingCalibrationView: View {
    @ObservedObject var headTracking: HeadTrackingService
    @ObservedObject var eyeGaze: EyeGazeService

    @State private var activeTab: TrackingTab = .head
    @State private var isTrainingMode: Bool = false
    @State private var trainingTurnCount: Int = 0

    public enum TrackingTab: String, CaseIterable {
        case head = "Head"
        case eye = "Eye Gaze"
    }

    public init(headTracking: HeadTrackingService, eyeGaze: EyeGazeService) {
        self.headTracking = headTracking
        self.eyeGaze = eyeGaze
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            Divider()

            // Tab picker
            Picker("Tracking Mode", selection: $activeTab) {
                ForEach(TrackingTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.md)

            ScrollView {
                VStack(spacing: ASSpacing.xl) {
                    // Detection status
                    detectionStatusCard

                    // Head pose / gaze visualization
                    trackingVisualization

                    // Sensitivity controls
                    sensitivityControls

                    // Direction mapping
                    directionControls

                    // Training mode
                    trainingSection

                    // Privacy notice
                    privacyNotice
                }
                .padding(ASSpacing.lg)
            }

            Divider()

            // Bottom actions
            bottomActions
        }
        .background(ASColors.chromeBackground)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.xl, style: .continuous))
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOTION TRACKING")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Text("Calibration")
                    .font(ASTypography.heading2)
                    .foregroundStyle(.primary)
            }

            Spacer()

            // Status indicator
            statusBadge
        }
        .padding(.horizontal, ASSpacing.lg)
        .padding(.vertical, ASSpacing.md)
    }

    private var statusBadge: some View {
        let (text, color) = statusInfo
        return HStack(spacing: ASSpacing.xs) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(text)
                .font(ASTypography.captionSmall)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, ASSpacing.sm)
        .padding(.vertical, ASSpacing.xs)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }

    private var statusInfo: (String, Color) {
        switch activeTab {
        case .head:
            switch headTracking.state {
            case .idle: return ("Idle", .secondary)
            case .starting: return ("Starting…", .yellow)
            case .tracking: return ("Tracking", .green)
            case .noFaceDetected: return ("No Face", .orange)
            case .cameraUnavailable: return ("No Camera", .red)
            case .permissionDenied: return ("Permission Denied", .red)
            }
        case .eye:
            switch eyeGaze.state {
            case .idle: return ("Idle", .secondary)
            case .starting: return ("Starting…", .yellow)
            case .tracking: return ("Tracking", .green)
            case .noFaceDetected: return ("No Face", .orange)
            case .cameraUnavailable: return ("No Camera", .red)
            case .permissionDenied: return ("Permission Denied", .red)
            }
        }
    }

    // MARK: - Detection Status Card

    private var detectionStatusCard: some View {
        VStack(spacing: ASSpacing.md) {
            HStack(spacing: ASSpacing.lg) {
                // Face detected indicator
                VStack(spacing: ASSpacing.xs) {
                    Image(systemName: faceDetected ? "face.smiling" : "face.dashed")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(faceDetected ? Color.green : Color.gray.opacity(0.3))
                    Text(faceDetected ? "Face Detected" : "No Face")
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Confidence meter
                VStack(spacing: ASSpacing.xs) {
                    Text(String(format: "%.0f%%", currentConfidence * 100))
                        .font(ASTypography.mono)
                        .foregroundStyle(confidenceColor)
                    Text("Confidence")
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Current reading
                if activeTab == .head {
                    VStack(spacing: ASSpacing.xs) {
                        Text(String(format: "%.1f°", headTracking.currentYaw * 180 / .pi))
                            .font(ASTypography.mono)
                            .foregroundStyle(.primary)
                        Text("Yaw")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: ASSpacing.xs) {
                        Text(eyeGaze.currentRegion.displayName)
                            .font(ASTypography.mono)
                            .foregroundStyle(.primary)
                        Text("Gaze Region")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private var faceDetected: Bool {
        activeTab == .head ? headTracking.faceDetected : eyeGaze.faceDetected
    }

    private var currentConfidence: Float {
        activeTab == .head ? headTracking.confidence : eyeGaze.confidence
    }

    private var confidenceColor: Color {
        if currentConfidence >= 0.8 { return .green }
        if currentConfidence >= 0.5 { return .yellow }
        return .red
    }

    // MARK: - Tracking Visualization

    private var trackingVisualization: some View {
        VStack(spacing: ASSpacing.md) {
            Text(activeTab == .head ? "HEAD POSITION" : "GAZE DIRECTION")
                .font(ASTypography.labelMicro)
                .foregroundStyle(.secondary)
                .tracking(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            if activeTab == .head {
                headPositionVisualization
            } else {
                gazeVisualization
            }
        }
    }

    private var headPositionVisualization: some View {
        ZStack {
            // Background circle
            Circle()
                .strokeBorder(ASColors.chromeBorder, lineWidth: 1)
                .frame(width: 160, height: 160)

            // Threshold ring
            Circle()
                .strokeBorder(ASColors.accentFallback.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .frame(width: 160 * thresholdRatio, height: 160 * thresholdRatio)

            // Center crosshair
            Group {
                Rectangle().frame(width: 1, height: 12)
                Rectangle().frame(width: 12, height: 1)
            }
            .foregroundStyle(.tertiary)

            // Head position dot
            let yawOffset = headTracking.currentYaw / (Double.pi / 4) * 60
            let pitchOffset = headTracking.currentPitch / (Double.pi / 4) * 60
            Circle()
                .fill(headTracking.faceDetected ? ASColors.accentFallback : Color.gray.opacity(0.3))
                .frame(width: 14, height: 14)
                .offset(x: yawOffset, y: -pitchOffset)
                .animation(.easeOut(duration: 0.15), value: headTracking.currentYaw)
                .animation(.easeOut(duration: 0.15), value: headTracking.currentPitch)

            // Threshold labels
            HStack {
                Text("←")
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(ASColors.accentFallback.opacity(0.5))
                Spacer()
                Text("→")
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(ASColors.accentFallback.opacity(0.5))
            }
            .frame(width: 180)
        }
        .frame(height: 180)
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurface)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
    }

    private var thresholdRatio: CGFloat {
        CGFloat(headTracking.yawThreshold / (Double.pi / 4))
    }

    private var gazeVisualization: some View {
        VStack(spacing: ASSpacing.md) {
            // Three-zone display
            HStack(spacing: ASSpacing.sm) {
                gazeZone("Left", region: .left, isActive: eyeGaze.currentRegion == .left)
                gazeZone("Center", region: .center, isActive: eyeGaze.currentRegion == .center)
                gazeZone("Right", region: .right, isActive: eyeGaze.currentRegion == .right)
            }
            .frame(height: 100)

            // Dwell progress bar
            if eyeGaze.currentRegion == .left || eyeGaze.currentRegion == .right {
                VStack(spacing: ASSpacing.xs) {
                    ProgressView(value: eyeGaze.dwellProgress)
                        .tint(ASColors.accentFallback)

                    Text(String(format: "Dwell: %.1fs / %.1fs", eyeGaze.dwellProgress * eyeGaze.dwellDuration, eyeGaze.dwellDuration))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurface)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
    }

    private func gazeZone(_ label: String, region: EyeGazeService.GazeRegion, isActive: Bool) -> some View {
        VStack(spacing: ASSpacing.xs) {
            Image(systemName: regionIcon(region))
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(isActive ? ASColors.accentFallback : Color.gray.opacity(0.3))

            Text(label)
                .font(ASTypography.captionSmall)
                .foregroundStyle(isActive ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isActive ? ASColors.accentFallback.opacity(0.12) : ASColors.chromeSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
    }

    private func regionIcon(_ region: EyeGazeService.GazeRegion) -> String {
        switch region {
        case .left: return "arrow.left.circle"
        case .center: return "circle"
        case .right: return "arrow.right.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    // MARK: - Sensitivity Controls

    private var sensitivityControls: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            Text("SENSITIVITY")
                .font(ASTypography.labelMicro)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if activeTab == .head {
                // Yaw threshold
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Movement Threshold")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.0f°", headTracking.yawThreshold * 180 / .pi))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $headTracking.yawThreshold, in: 0.1...0.8)
                        .tint(ASColors.accentFallback)
                }

                // Debounce
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Debounce")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.1fs", headTracking.debounceInterval))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $headTracking.debounceInterval, in: 0.3...3.0)
                        .tint(ASColors.accentFallback)
                }

                // Confidence threshold
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Confidence Threshold")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.0f%%", headTracking.confidenceThreshold * 100))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $headTracking.confidenceThreshold, in: 0.3...0.95)
                        .tint(ASColors.accentFallback)
                }
            } else {
                // Dwell duration
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Dwell Duration")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.1fs", eyeGaze.dwellDuration))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $eyeGaze.dwellDuration, in: 0.5...4.0)
                        .tint(ASColors.accentFallback)
                }

                // Cooldown
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Cooldown")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.1fs", eyeGaze.cooldownInterval))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $eyeGaze.cooldownInterval, in: 0.5...5.0)
                        .tint(ASColors.accentFallback)
                }

                // Confidence
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    HStack {
                        Text("Confidence Threshold")
                            .font(ASTypography.bodySmall)
                        Spacer()
                        Text(String(format: "%.0f%%", eyeGaze.confidenceThreshold * 100))
                            .font(ASTypography.monoSmall)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $eyeGaze.confidenceThreshold, in: 0.3...0.95)
                        .tint(ASColors.accentFallback)
                }

                // Hold-to-confirm toggle
                Toggle(isOn: $eyeGaze.holdToConfirm) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hold to Confirm")
                            .font(ASTypography.bodySmall)
                        Text("Require sustained gaze to trigger")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(ASColors.accentFallback)
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

    // MARK: - Direction Controls

    private var directionControls: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            Text("DIRECTION MAPPING")
                .font(ASTypography.labelMicro)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if activeTab == .head {
                Toggle(isOn: $headTracking.leftTurnsForward) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Head Left → Forward")
                            .font(ASTypography.bodySmall)
                        Text(headTracking.leftTurnsForward
                             ? "Turn head left to go forward, right to go back"
                             : "Turn head right to go forward, left to go back")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(ASColors.accentFallback)
            } else {
                Toggle(isOn: $eyeGaze.leftGazeForward) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Look Left → Forward")
                            .font(ASTypography.bodySmall)
                        Text(eyeGaze.leftGazeForward
                             ? "Look left to go forward, right to go back"
                             : "Look right to go forward, left to go back")
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(ASColors.accentFallback)
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

    // MARK: - Training Section

    private var trainingSection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("TRAINING MODE")
                    .font(ASTypography.labelMicro)
                    .foregroundStyle(.secondary)
                    .tracking(0.5)

                Spacer()

                if isTrainingMode {
                    Text("\(trainingTurnCount) turns")
                        .font(ASTypography.monoSmall)
                        .foregroundStyle(ASColors.accentFallback)
                }
            }

            Text("Practice page turns without affecting your score. Turns are counted but not applied.")
                .font(ASTypography.captionSmall)
                .foregroundStyle(.tertiary)

            Toggle(isOn: $isTrainingMode) {
                Text("Enable Training Mode")
                    .font(ASTypography.bodySmall)
            }
            .tint(ASColors.accentFallback)
            .onChange(of: isTrainingMode) { _, newValue in
                if newValue {
                    trainingTurnCount = 0
                }
            }

            if isTrainingMode {
                // Visual turn indicator
                HStack(spacing: ASSpacing.xl) {
                    trainingArrow(direction: .backward, label: "Back")
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    trainingArrow(direction: .forward, label: "Forward")
                }
                .padding(.vertical, ASSpacing.md)
            }
        }
        .padding(ASSpacing.lg)
        .background(ASColors.chromeSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .strokeBorder(isTrainingMode ? ASColors.accentFallback.opacity(0.3) : ASColors.chromeBorder, lineWidth: 0.5)
        )
    }

    private func trainingArrow(direction: PageTurnService.TurnDirection, label: String) -> some View {
        VStack(spacing: ASSpacing.xs) {
            Image(systemName: direction == .forward ? "chevron.right.circle" : "chevron.left.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text(label)
                .font(ASTypography.captionSmall)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Privacy Notice

    private var privacyNotice: some View {
        HStack(spacing: ASSpacing.sm) {
            Image(systemName: "lock.shield")
                .font(.system(size: 14))
                .foregroundStyle(.green)

            Text("All tracking is processed on-device. No camera data leaves your device.")
                .font(ASTypography.captionSmall)
                .foregroundStyle(.tertiary)
        }
        .padding(ASSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: ASSpacing.md) {
            if activeTab == .head {
                Button {
                    headTracking.calibrate()
                } label: {
                    Label("Set Baseline", systemImage: "scope")
                        .font(ASTypography.bodySmall)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ASColors.accentFallback)
                .disabled(!headTracking.faceDetected)
            }

            Spacer()

            let isActive = activeTab == .head
                ? headTracking.state == .tracking || headTracking.state == .noFaceDetected
                : eyeGaze.state == .tracking || eyeGaze.state == .noFaceDetected

            Button {
                Task {
                    if isActive {
                        if activeTab == .head { headTracking.stop() } else { eyeGaze.stop() }
                    } else {
                        if activeTab == .head { await headTracking.start() } else { await eyeGaze.start() }
                    }
                }
            } label: {
                Text(isActive ? "Stop Tracking" : "Start Tracking")
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ASSpacing.lg)
                    .padding(.vertical, ASSpacing.sm)
                    .background(isActive ? Color.red.opacity(0.8) : ASColors.accentFallback)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ASSpacing.lg)
        .padding(.vertical, ASSpacing.md)
    }
}

// MARK: - GazeRegion Display Name

extension EyeGazeService.GazeRegion {
    var displayName: String {
        switch self {
        case .left: return "Left"
        case .center: return "Center"
        case .right: return "Right"
        case .unknown: return "—"
        }
    }
}
