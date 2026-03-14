// MotionTrackingManager — Unified manager for head and eye tracking with safety controls.

import Foundation
@preconcurrency import AVFoundation
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Coordinates head and eye tracking services with safety controls:
/// - Camera permission management
/// - Availability detection (camera present, Vision supported)
/// - Battery-aware frame rate throttling
/// - Accessibility fallback (disables tracking if Switch Control / VoiceOver active)
/// - Unified enable/disable for both services
@MainActor
public final class MotionTrackingManager: ObservableObject {

    // MARK: - Public State

    public enum Availability: Sendable {
        case available
        case noCameraAvailable
        case permissionDenied
        case permissionNotDetermined
        case accessibilityOverride
    }

    @Published public private(set) var availability: Availability = .permissionNotDetermined
    @Published public private(set) var isRunning: Bool = false
    @Published public private(set) var isBatteryConstrained: Bool = false

    /// Master toggle for head tracking.
    @Published public var headTrackingEnabled: Bool = false {
        didSet { headTracking.isEnabled = headTrackingEnabled }
    }

    /// Master toggle for eye gaze tracking.
    @Published public var eyeGazeEnabled: Bool = false {
        didSet { eyeGaze.isEnabled = eyeGazeEnabled }
    }

    /// If true, tracking is suppressed when VoiceOver or Switch Control is active.
    @Published public var respectAccessibility: Bool = true

    // MARK: - Services

    public let headTracking: HeadTrackingService
    public let eyeGaze: EyeGazeService

    // MARK: - Private

    private var pageTurnService: PageTurnService?
    private var cancellables = Set<AnyCancellable>()

    #if os(iOS)
    private var batteryObserver: NSObjectProtocol?
    #endif

    public init() {
        self.headTracking = HeadTrackingService()
        self.eyeGaze = EyeGazeService()
        checkAvailability()
        setupBatteryMonitoring()
    }

    // MARK: - Public API

    /// Connect to a PageTurnService so detected gestures trigger page turns.
    public func connect(to pageTurnService: PageTurnService) {
        self.pageTurnService = pageTurnService

        headTracking.setPageTurnHandler { [weak pageTurnService] direction in
            pageTurnService?.triggerTurn(direction, from: .headMovement)
        }

        eyeGaze.setPageTurnHandler { [weak pageTurnService] direction in
            pageTurnService?.triggerTurn(direction, from: .eyeGaze)
        }
    }

    /// Start all enabled tracking services.
    public func startTracking() async {
        guard availability == .available else { return }
        guard !isAccessibilityActive else {
            availability = .accessibilityOverride
            return
        }

        isRunning = true

        if headTrackingEnabled {
            await headTracking.start()
        }
        if eyeGazeEnabled {
            await eyeGaze.start()
        }
    }

    /// Stop all tracking services and release camera.
    public func stopTracking() {
        headTracking.stop()
        eyeGaze.stop()
        isRunning = false
    }

    /// Re-check camera and permission availability.
    public func checkAvailability() {
        // Check if front camera exists
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil else {
            availability = .noCameraAvailable
            return
        }

        // Check permission
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            availability = isAccessibilityActive && respectAccessibility ? .accessibilityOverride : .available
        case .denied, .restricted:
            availability = .permissionDenied
        case .notDetermined:
            availability = .permissionNotDetermined
        @unknown default:
            availability = .permissionNotDetermined
        }
    }

    /// Request camera permission. Returns true if granted.
    public func requestPermission() async -> Bool {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        checkAvailability()
        return granted
    }

    // MARK: - Accessibility Check

    private var isAccessibilityActive: Bool {
        #if os(iOS)
        return UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        #elseif os(macOS)
        return NSWorkspace.shared.isVoiceOverEnabled
        #else
        return false
        #endif
    }

    // MARK: - Battery Monitoring

    private func setupBatteryMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true

        batteryObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateBatteryConstraint()
            }
        }
        updateBatteryConstraint()
        #endif
    }

    #if os(iOS)
    private func updateBatteryConstraint() {
        let state = UIDevice.current.batteryState
        let level = UIDevice.current.batteryLevel
        // Constrain when unplugged and below 20%
        isBatteryConstrained = (state == .unplugged || state == .unknown) && level < 0.2 && level >= 0
    }
    #endif

    // MARK: - Configuration Presets

    /// Apply conservative settings for maximum safety (wider threshold, longer debounce).
    public func applyConservativePreset() {
        headTracking.yawThreshold = 0.5       // ~29°
        headTracking.debounceInterval = 1.5
        headTracking.confidenceThreshold = 0.7

        eyeGaze.dwellDuration = 2.5
        eyeGaze.cooldownInterval = 3.0
        eyeGaze.confidenceThreshold = 0.7
        eyeGaze.holdToConfirm = true
    }

    /// Apply balanced default settings.
    public func applyDefaultPreset() {
        headTracking.yawThreshold = 0.35      // ~20°
        headTracking.debounceInterval = 1.0
        headTracking.confidenceThreshold = 0.6

        eyeGaze.dwellDuration = 1.5
        eyeGaze.cooldownInterval = 2.0
        eyeGaze.confidenceThreshold = 0.5
        eyeGaze.holdToConfirm = false
    }

    /// Apply responsive settings for experienced users (lower threshold, faster response).
    public func applyResponsivePreset() {
        headTracking.yawThreshold = 0.25      // ~14°
        headTracking.debounceInterval = 0.5
        headTracking.confidenceThreshold = 0.5

        eyeGaze.dwellDuration = 0.8
        eyeGaze.cooldownInterval = 1.0
        eyeGaze.confidenceThreshold = 0.4
        eyeGaze.holdToConfirm = false
    }
}
