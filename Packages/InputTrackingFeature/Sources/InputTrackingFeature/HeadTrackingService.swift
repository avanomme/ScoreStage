// HeadTrackingService — Vision framework head pose detection for hands-free page turning.

import Foundation
@preconcurrency import AVFoundation
import Vision
import Combine

/// Tracks head yaw (left/right rotation) via the front camera and Vision framework.
/// All processing is on-device. No camera data leaves the device.
@MainActor
public final class HeadTrackingService: ObservableObject {

    // MARK: - Public State

    public enum TrackingState: Sendable {
        case idle
        case starting
        case tracking
        case noFaceDetected
        case cameraUnavailable
        case permissionDenied
    }

    public enum HeadGesture: Sendable {
        case turnLeft
        case turnRight
        case none
    }

    @Published public private(set) var state: TrackingState = .idle
    @Published public private(set) var currentYaw: Double = 0       // radians, negative = left
    @Published public private(set) var currentPitch: Double = 0     // radians
    @Published public private(set) var currentRoll: Double = 0      // radians
    @Published public private(set) var confidence: Float = 0        // 0.0–1.0
    @Published public private(set) var lastGesture: HeadGesture = .none
    @Published public private(set) var faceDetected: Bool = false

    // MARK: - Configuration

    /// Yaw threshold in radians to trigger a page turn (default ~20°).
    @Published public var yawThreshold: Double = 0.35

    /// Minimum confidence required to act on a detection (0.0–1.0).
    @Published public var confidenceThreshold: Float = 0.6

    /// Debounce interval — minimum seconds between page turns.
    @Published public var debounceInterval: TimeInterval = 1.0

    /// Whether head tracking is enabled.
    @Published public var isEnabled: Bool = false

    /// Direction mapping: if true, head-left = page forward (default).
    @Published public var leftTurnsForward: Bool = true

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.scorestage.headtracking", qos: .userInteractive)
    private var lastTurnTime: Date = .distantPast
    private var baselineYaw: Double = 0
    private var isCalibrated: Bool = false
    private var frameProcessor: FrameProcessor?

    private var onPageTurn: ((PageTurnService.TurnDirection) -> Void)?

    public init() {}

    // MARK: - Public API

    /// Set the callback invoked when a head gesture triggers a page turn.
    public func setPageTurnHandler(_ handler: @escaping (PageTurnService.TurnDirection) -> Void) {
        self.onPageTurn = handler
    }

    /// Start camera capture and head tracking.
    public func start() async {
        guard isEnabled else { return }
        state = .starting

        let authorized = await requestCameraPermission()
        guard authorized else {
            state = .permissionDenied
            return
        }

        setupCaptureSession()
        state = .tracking
    }

    /// Stop tracking and release camera resources.
    public func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        frameProcessor = nil
        state = .idle
        isCalibrated = false
        faceDetected = false
    }

    /// Calibrate baseline head position — call when user is looking straight at screen.
    public func calibrate() {
        baselineYaw = currentYaw
        isCalibrated = true
    }

    /// Reset calibration to zero.
    public func resetCalibration() {
        baselineYaw = 0
        isCalibrated = false
    }

    // MARK: - Camera Setup

    private func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private func setupCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            state = .cameraUnavailable
            return
        }

        guard session.canAddInput(input) else {
            state = .cameraUnavailable
            return
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        let processor = FrameProcessor(service: self)
        output.setSampleBufferDelegate(processor, queue: processingQueue)
        self.frameProcessor = processor

        guard session.canAddOutput(output) else {
            state = .cameraUnavailable
            return
        }
        session.addOutput(output)

        self.captureSession = session
        self.videoOutput = output

        processingQueue.async { [session] in
            session.startRunning()
        }
    }

    // MARK: - Vision Processing (called from FrameProcessor on background queue)

    func handleFrameResults(yaw: Double, pitch: Double, roll: Double, confidence: Float) {
        self.currentYaw = yaw
        self.currentPitch = pitch
        self.currentRoll = roll
        self.confidence = confidence
        self.faceDetected = true

        if state == .noFaceDetected {
            state = .tracking
        }

        guard confidence >= confidenceThreshold else {
            lastGesture = .none
            return
        }

        let adjustedYaw = yaw - baselineYaw
        let now = Date()

        guard now.timeIntervalSince(lastTurnTime) >= debounceInterval else { return }

        if adjustedYaw < -yawThreshold {
            lastGesture = .turnLeft
            lastTurnTime = now
            let direction: PageTurnService.TurnDirection = leftTurnsForward ? .forward : .backward
            onPageTurn?(direction)
        } else if adjustedYaw > yawThreshold {
            lastGesture = .turnRight
            lastTurnTime = now
            let direction: PageTurnService.TurnDirection = leftTurnsForward ? .backward : .forward
            onPageTurn?(direction)
        } else {
            lastGesture = .none
        }
    }

    func handleNoFace() {
        faceDetected = false
        confidence = 0
        if state == .tracking {
            state = .noFaceDetected
        }
    }
}

// MARK: - Frame Processor (AVCaptureVideoDataOutputSampleBufferDelegate)

/// Processes camera frames on a background queue and dispatches results to the MainActor service.
private final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let service: HeadTrackingService
    private var sequenceHandler = VNSequenceRequestHandler()

    init(service: HeadTrackingService) {
        self.service = service
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectFaceLandmarksRequest()

        do {
            try sequenceHandler.perform([request], on: pixelBuffer, orientation: .leftMirrored)
        } catch {
            return
        }

        guard let results = request.results, let face = results.first else {
            Task { @MainActor in
                self.service.handleNoFace()
            }
            return
        }

        let yaw = face.yaw?.doubleValue ?? 0
        let pitch = face.pitch?.doubleValue ?? 0
        let roll = face.roll?.doubleValue ?? 0
        let conf = face.confidence

        Task { @MainActor in
            self.service.handleFrameResults(yaw: yaw, pitch: pitch, roll: roll, confidence: conf)
        }
    }
}
