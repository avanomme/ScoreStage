// ScoreFollowingService — Pitch detection and score alignment for auto-page-turn.

import Foundation
import AVFoundation
import Accelerate
import NotationFeature

/// Experimental score-following service that detects pitch from microphone input
/// and aligns the live performance with the score position.
///
/// Approach: Real-time pitch detection via autocorrelation, then matching
/// detected pitches against the expected note sequence from the score.
@MainActor
@Observable
public final class ScoreFollowingService {

    // MARK: - Public State

    public enum FollowingState: Sendable {
        case idle
        case listening
        case following
        case lost          // Can't match position
        case micUnavailable
        case permissionDenied
    }

    /// Current state of score following.
    public private(set) var state: FollowingState = .idle

    /// Detected fundamental frequency in Hz.
    public private(set) var detectedFrequency: Double = 0

    /// Detected MIDI note number (closest match).
    public private(set) var detectedMIDINote: Int?

    /// Confidence of the pitch detection (0.0–1.0).
    public private(set) var pitchConfidence: Double = 0

    /// Current estimated measure position in the score.
    public private(set) var estimatedMeasure: Int = 1

    /// Current position within the measure (0.0–1.0).
    public private(set) var measureProgress: Double = 0

    /// Whether score following is actively tracking.
    public var isEnabled: Bool = false

    /// Minimum confidence to accept a pitch detection.
    public var confidenceThreshold: Double = 0.7

    // MARK: - Callbacks

    /// Called when the estimated score position changes.
    public var onPositionChanged: ((Int, Double) -> Void)?

    /// Called when a page turn should happen (based on score position).
    public var onPageTurnNeeded: ((Int) -> Void)?

    // MARK: - Private

    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private let bufferSize: AVAudioFrameCount = 4096
    private var sampleRate: Double = 44100

    // Score alignment state
    private var scoreNotes: [(measureNumber: Int, midiNote: Int, position: Double)] = []
    private var alignmentIndex: Int = 0
    private var lastMatchedMeasure: Int = 1
    private var consecutiveMatches: Int = 0
    private let matchThreshold: Int = 3   // consecutive matches needed to update position

    public init() {}

    // MARK: - Public API

    /// Load the score's note sequence for alignment.
    public func loadScore(_ score: NormalizedScore, measureMap: MeasureMap) {
        scoreNotes.removeAll()

        guard let part = score.parts.first else { return }

        for measure in part.measures {
            guard let timing = measureMap.entry(forMeasure: measure.number) else { continue }
            var positionInMeasure: Double = 0
            let totalDivisions = measure.timeSignature?.quarterNotesPerMeasure ?? 4.0

            for note in measure.notes where !note.isRest {
                guard let midiNote = note.midiNote else { continue }
                let normalizedPosition = positionInMeasure / (totalDivisions * 4.0)

                scoreNotes.append((
                    measureNumber: measure.number,
                    midiNote: midiNote,
                    position: normalizedPosition
                ))

                if !note.isChord {
                    positionInMeasure += Double(note.durationDivisions)
                }
            }
        }

        alignmentIndex = 0
        lastMatchedMeasure = 1
    }

    /// Start listening to microphone and following the score.
    public func start() async {
        guard isEnabled else { return }

        let authorized = await requestMicPermission()
        guard authorized else {
            state = .permissionDenied
            return
        }

        setupAudioEngine()
        state = .listening
    }

    /// Stop listening and release microphone.
    public func stop() {
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        state = .idle
    }

    /// Reset alignment to the beginning of the score.
    public func resetAlignment() {
        alignmentIndex = 0
        lastMatchedMeasure = 1
        estimatedMeasure = 1
        measureProgress = 0
        consecutiveMatches = 0
    }

    // MARK: - Microphone Setup

    private func requestMicPermission() async -> Bool {
        #if os(iOS)
        let status = AVAudioApplication.shared.recordPermission
        switch status {
        case .granted:
            return true
        case .undetermined:
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        default:
            return false
        }
        #else
        // macOS
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
        #endif
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        sampleRate = format.sampleRate

        let capturedSampleRate = sampleRate
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, sampleRate: capturedSampleRate)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.inputNode = input
        } catch {
            state = .micUnavailable
        }
    }

    // MARK: - Pitch Detection (Autocorrelation)

    nonisolated private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Compute autocorrelation for pitch detection
        let (frequency, confidence) = detectPitch(
            samples: channelData,
            count: frameCount,
            sampleRate: sampleRate
        )

        Task { @MainActor in
            self.detectedFrequency = frequency
            self.pitchConfidence = confidence

            if confidence >= self.confidenceThreshold && frequency > 20 {
                let midiNote = Self.frequencyToMIDI(frequency)
                self.detectedMIDINote = midiNote
                self.matchAgainstScore(midiNote: midiNote)

                if self.state == .listening {
                    self.state = .following
                }
            }
        }
    }

    /// Autocorrelation-based pitch detection.
    nonisolated private func detectPitch(samples: UnsafeMutablePointer<Float>, count: Int, sampleRate: Double) -> (frequency: Double, confidence: Double) {
        // Simple normalized autocorrelation
        let minLag = Int(sampleRate / 2000) // Max frequency 2000 Hz
        let maxLag = Int(sampleRate / 50)   // Min frequency 50 Hz

        guard maxLag < count else { return (0, 0) }

        var bestLag = minLag
        var bestCorrelation: Float = 0
        var energy: Float = 0

        // Compute energy of signal
        vDSP_dotpr(samples, 1, samples, 1, &energy, vDSP_Length(count))

        guard energy > 0.001 else { return (0, 0) } // Silence threshold

        for lag in minLag..<min(maxLag, count) {
            var correlation: Float = 0
            vDSP_dotpr(samples, 1, samples.advanced(by: lag), 1, &correlation, vDSP_Length(count - lag))

            // Normalize
            var lagEnergy: Float = 0
            vDSP_dotpr(
                samples.advanced(by: lag), 1,
                samples.advanced(by: lag), 1,
                &lagEnergy,
                vDSP_Length(count - lag)
            )

            let normalizedCorrelation = correlation / sqrt(energy * lagEnergy)

            if normalizedCorrelation > bestCorrelation {
                bestCorrelation = normalizedCorrelation
                bestLag = lag
            }
        }

        let frequency = sampleRate / Double(bestLag)
        let confidence = Double(max(0, bestCorrelation))
        return (frequency, confidence)
    }

    // MARK: - Score Alignment

    private func matchAgainstScore(midiNote: Int) {
        guard !scoreNotes.isEmpty else { return }

        // Search forward from current alignment index
        let searchWindow = 10  // Look ahead up to 10 notes
        let startIdx = max(0, alignmentIndex - 2)
        let endIdx = min(scoreNotes.count, alignmentIndex + searchWindow)

        for i in startIdx..<endIdx {
            let scoreNote = scoreNotes[i]
            // Match within 1 semitone tolerance (for temperament/tuning)
            if abs(scoreNote.midiNote - midiNote) <= 1 {
                consecutiveMatches += 1

                if consecutiveMatches >= matchThreshold || i > alignmentIndex {
                    alignmentIndex = i + 1

                    if scoreNote.measureNumber != lastMatchedMeasure {
                        lastMatchedMeasure = scoreNote.measureNumber
                        estimatedMeasure = scoreNote.measureNumber
                        onPositionChanged?(estimatedMeasure, scoreNote.position)
                    }
                    measureProgress = scoreNote.position
                }
                return
            }
        }

        // No match found
        consecutiveMatches = 0
        if alignmentIndex > 0 {
            state = .lost
        }
    }

    // MARK: - Frequency/MIDI Conversion

    /// Convert frequency in Hz to the nearest MIDI note number.
    public static func frequencyToMIDI(_ frequency: Double) -> Int {
        guard frequency > 0 else { return 0 }
        return Int(round(69 + 12 * log2(frequency / 440.0)))
    }

    /// Convert MIDI note number to frequency in Hz.
    public static func midiToFrequency(_ midiNote: Int) -> Double {
        440.0 * pow(2.0, Double(midiNote - 69) / 12.0)
    }
}
