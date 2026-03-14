// EyeGazeService — Eye gaze detection with dwell-time page turning.

import Foundation
@preconcurrency import AVFoundation
import Vision
import Combine

/// Detects eye gaze direction via Vision framework face landmarks.
/// When gaze dwells on a left/right region beyond the threshold, triggers a page turn.
/// All processing is on-device.
@MainActor
public final class EyeGazeService: ObservableObject {

    // MARK: - Public State

    public enum GazeRegion: Sendable {
        case left
        case center
        case right
        case unknown
    }

    public enum GazeState: Sendable {
        case idle
        case starting
        case tracking
        case noFaceDetected
        case cameraUnavailable
        case permissionDenied
    }

    @Published public private(set) var state: GazeState = .idle
    @Published public private(set) var currentRegion: GazeRegion = .unknown
    @Published public private(set) var dwellProgress: Double = 0    // 0.0–1.0, fills as gaze holds
    @Published public private(set) var faceDetected: Bool = false
    @Published public private(set) var confidence: Float = 0

    // MARK: - Configuration

    /// How long (seconds) gaze must dwell on a region to trigger a turn.
    @Published public var dwellDuration: TimeInterval = 1.5

    /// Minimum confidence to process a gaze detection.
    @Published public var confidenceThreshold: Float = 0.5

    /// Cooldown between gaze-triggered turns.
    @Published public var cooldownInterval: TimeInterval = 2.0

    /// Whether eye gaze tracking is enabled.
    @Published public var isEnabled: Bool = false

    /// If true, gazing left triggers forward page turn.
    @Published public var leftGazeForward: Bool = true

    /// Whether to require explicit hold-to-confirm (true) or auto-fire on dwell (false).
    @Published public var holdToConfirm: Bool = false

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let processingQueue = DispatchQueue(label: "com.scorestage.eyegaze", qos: .userInteractive)
    private var frameProcessor: GazeFrameProcessor?

    private var dwellStartTime: Date?
    private var dwellRegion: GazeRegion = .unknown
    private var lastTurnTime: Date = .distantPast

    private var onPageTurn: ((PageTurnService.TurnDirection) -> Void)?

    public init() {}

    // MARK: - Public API

    public func setPageTurnHandler(_ handler: @escaping (PageTurnService.TurnDirection) -> Void) {
        self.onPageTurn = handler
    }

    /// Start camera capture and gaze tracking.
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

    /// Stop tracking and release camera.
    public func stop() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        frameProcessor = nil
        state = .idle
        faceDetected = false
        dwellProgress = 0
        dwellStartTime = nil
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

        let processor = GazeFrameProcessor(service: self)
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

    // MARK: - Gaze Analysis (called from FrameProcessor via MainActor dispatch)

    func handleGazeResult(leftPupilCenter: CGPoint?, rightPupilCenter: CGPoint?, confidence: Float) {
        self.confidence = confidence
        self.faceDetected = true

        if state == .noFaceDetected {
            state = .tracking
        }

        guard confidence >= confidenceThreshold else {
            resetDwell()
            currentRegion = .unknown
            return
        }

        // Determine gaze region from average pupil position.
        // Pupil positions are in normalized face-bounding-box coordinates (0–1).
        // Lower x = looking right (mirrored camera), higher x = looking left.
        let region = classifyGazeRegion(leftPupil: leftPupilCenter, rightPupil: rightPupilCenter)
        currentRegion = region

        updateDwell(for: region)
    }

    func handleNoFace() {
        faceDetected = false
        confidence = 0
        resetDwell()
        currentRegion = .unknown
        if state == .tracking {
            state = .noFaceDetected
        }
    }

    // MARK: - Gaze Classification

    private func classifyGazeRegion(leftPupil: CGPoint?, rightPupil: CGPoint?) -> GazeRegion {
        // Use average of both pupils if available, otherwise use whichever is present.
        var avgX: CGFloat?
        if let lp = leftPupil, let rp = rightPupil {
            avgX = (lp.x + rp.x) / 2.0
        } else if let lp = leftPupil {
            avgX = lp.x
        } else if let rp = rightPupil {
            avgX = rp.x
        }

        guard let x = avgX else { return .unknown }

        // Pupil x in normalized face coordinates:
        // ~0.3–0.7 is center. <0.3 = looking right, >0.7 = looking left (front camera mirrored).
        if x < 0.35 {
            return .right
        } else if x > 0.65 {
            return .left
        } else {
            return .center
        }
    }

    // MARK: - Dwell Logic

    private func updateDwell(for region: GazeRegion) {
        guard region == .left || region == .right else {
            resetDwell()
            return
        }

        let now = Date()

        // Check cooldown
        guard now.timeIntervalSince(lastTurnTime) >= cooldownInterval else {
            resetDwell()
            return
        }

        if region == dwellRegion, let start = dwellStartTime {
            let elapsed = now.timeIntervalSince(start)
            dwellProgress = min(elapsed / dwellDuration, 1.0)

            if elapsed >= dwellDuration {
                triggerGazeTurn(region)
                resetDwell()
            }
        } else {
            // New dwell region
            dwellRegion = region
            dwellStartTime = now
            dwellProgress = 0
        }
    }

    private func triggerGazeTurn(_ region: GazeRegion) {
        lastTurnTime = Date()
        let direction: PageTurnService.TurnDirection
        switch region {
        case .left:
            direction = leftGazeForward ? .forward : .backward
        case .right:
            direction = leftGazeForward ? .backward : .forward
        default:
            return
        }
        onPageTurn?(direction)
    }

    private func resetDwell() {
        dwellStartTime = nil
        dwellRegion = .unknown
        dwellProgress = 0
    }
}

// MARK: - Gaze Frame Processor

private final class GazeFrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let service: EyeGazeService
    private var sequenceHandler = VNSequenceRequestHandler()

    init(service: EyeGazeService) {
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

        guard let results = request.results, let face = results.first,
              let landmarks = face.landmarks else {
            Task { @MainActor in
                self.service.handleNoFace()
            }
            return
        }

        // Extract pupil centers from eye landmarks
        let leftPupilCenter = landmarks.leftPupil?.normalizedPoints.first
        let rightPupilCenter = landmarks.rightPupil?.normalizedPoints.first
        let conf = face.confidence

        Task { @MainActor in
            self.service.handleGazeResult(
                leftPupilCenter: leftPupilCenter,
                rightPupilCenter: rightPupilCenter,
                confidence: conf
            )
        }
    }
}
