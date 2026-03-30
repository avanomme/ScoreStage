// PlaybackEngine — AVAudioEngine-based MIDI playback with soundfont rendering.
// Schedules PlaybackEvents from NotationFeature and drives the playhead.

import Foundation
import AVFoundation
import NotationFeature

// MARK: - Playback State

public enum PlaybackState: Sendable {
    case stopped
    case playing
    case paused
}

// MARK: - Playback Engine

/// Core audio engine for score playback using AVAudioEngine + MIDI.
@MainActor
@Observable
public final class PlaybackEngine {
    public var state: PlaybackState = .stopped
    public var currentTime: TimeInterval = 0
    public var currentMeasure: Int = 0
    public var tempo: Double = 120.0
    public var isMetronomeEnabled: Bool = false
    public var isCountInEnabled: Bool = false
    public var transposeSemitones: Int = 0

    // Mixer state
    public var partVolumes: [Float] = []
    public var mutedParts: Set<Int> = []
    public var soloPart: Int? = nil

    // Loop state
    public var isLooping: Bool = false
    public var loopStartMeasure: Int? = nil
    public var loopEndMeasure: Int? = nil

    // Internal
    private var audioEngine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var metronomePlayer: AVAudioPlayerNode?
    private var events: [PlaybackEvent] = []
    private var measureMap: MeasureMap?
    private var score: NormalizedScore?
    private var playbackTask: Task<Void, Never>?
    private var eventIndex: Int = 0
    private var startTimestamp: Date?
    private var pauseOffset: TimeInterval = 0
    private var lastMetronomeBeat: Int = -1
    private var countInBeatsRemaining: Int = 0

    /// Callback when playback position updates (fires per measure).
    public var onMeasureChanged: ((Int) -> Void)?

    /// Callback every frame with (currentTime, totalDuration) for smooth progress.
    public var onTimeUpdate: ((TimeInterval, TimeInterval) -> Void)?

    /// Callback when playback completes.
    public var onPlaybackComplete: (() -> Void)?

    public init() {}

    // MARK: - Setup

    /// Number of parts in the loaded score.
    public var partCount: Int { score?.parts.count ?? 0 }

    /// Part names for UI display.
    public var partNames: [String] { score?.parts.map { $0.name } ?? [] }

    /// Total number of measures.
    public var measureCount: Int { measureMap?.entries.count ?? 0 }

    /// Total duration of the score.
    public var totalDuration: TimeInterval { measureMap?.totalDuration ?? 0 }

    /// Whether a score is loaded and ready for playback.
    public var isReady: Bool { !events.isEmpty && audioEngine != nil }

    /// Prepare the engine with a parsed score.
    public func prepare(score: NormalizedScore, measureMap: MeasureMap) {
        self.measureMap = measureMap
        self.score = score
        self.tempo = measureMap.entries.first?.tempo ?? 120.0

        // Initialize part volumes
        partVolumes = Array(repeating: 1.0, count: score.parts.count)

        // Schedule events
        let scheduler = PlaybackEventScheduler()
        events = scheduler.schedule(
            score: score,
            measureMap: measureMap,
            transposeSemitones: transposeSemitones
        )

        setupAudioEngine()

        // Set MIDI programs per part (different instruments)
        if let sampler {
            for (index, part) in score.parts.enumerated() {
                let channel = UInt8(min(index, 15)) // MIDI channels 0-15 (skip 9 for drums)
                let program = UInt8(part.midiProgram)
                // Send program change
                sampler.sendProgramChange(program, onChannel: channel)
            }
        }
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)

        // Metronome player
        let metronome = AVAudioPlayerNode()
        engine.attach(metronome)
        engine.connect(metronome, to: engine.mainMixerNode, format: nil)

        // Load soundfont: try bundled .sf2 first, then fall back to system DLS
        var loaded = false
        for name in ["GeneralUser", "FluidR3_GM", "soundfont"] {
            for ext in ["sf2", "dls"] {
                if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                    do {
                        try sampler.loadSoundBankInstrument(
                            at: url,
                            program: 0,
                            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                            bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                        )
                        loaded = true
                    } catch {}
                }
                if loaded { break }
            }
            if loaded { break }
        }

        // Fall back to system DLS (built into macOS/iOS)
        if !loaded {
            #if os(macOS)
            let dlsPath = "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls"
            let dlsURL = URL(fileURLWithPath: dlsPath)
            if FileManager.default.fileExists(atPath: dlsPath) {
                try? sampler.loadSoundBankInstrument(
                    at: dlsURL,
                    program: 0,
                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                    bankLSB: UInt8(kAUSampler_DefaultBankLSB)
                )
            }
            #endif
            // AVAudioUnitSampler produces a default piano sound even without explicit loading
        }

        self.audioEngine = engine
        self.sampler = sampler
        self.metronomePlayer = metronome
    }

    // MARK: - Transport Controls

    public func play() {
        guard state != .playing else { return }

        do {
            if audioEngine?.isRunning != true {
                try audioEngine?.start()
            }
        } catch {
            return
        }

        if state == .paused {
            // Resume from pause position
            startTimestamp = Date().addingTimeInterval(-pauseOffset)
            state = .playing
            startPlaybackLoop()
        } else {
            // Start from beginning or current position
            lastMetronomeBeat = -1

            if isCountInEnabled {
                // Count-in: play time-signature beats worth of clicks before starting
                let beatsPerBar = measureMap?.entries.first?.timeSignature.beats ?? 4
                countInBeatsRemaining = beatsPerBar
                state = .playing
                startCountIn(beats: beatsPerBar)
            } else {
                startTimestamp = Date().addingTimeInterval(-currentTime)
                eventIndex = findEventIndex(at: currentTime)
                state = .playing
                startPlaybackLoop()
            }
        }
    }

    /// Play count-in clicks, then start the main playback loop.
    private func startCountIn(beats: Int) {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            guard let self else { return }
            let beatDuration = 60.0 / self.tempo

            for beat in 0..<beats {
                guard !Task.isCancelled && self.state == .playing else { return }
                self.countInBeatsRemaining = beats - beat
                self.playMetronomeClick(isDownbeat: beat == 0)
                try? await Task.sleep(for: .milliseconds(Int(beatDuration * 1000)))
            }
            self.countInBeatsRemaining = 0

            guard !Task.isCancelled && self.state == .playing else { return }
            self.startTimestamp = Date().addingTimeInterval(-self.currentTime)
            self.eventIndex = self.findEventIndex(at: self.currentTime)
            self.startPlaybackLoop()
        }
    }

    public func pause() {
        guard state == .playing else { return }
        state = .paused
        pauseOffset = currentTime
        playbackTask?.cancel()
        playbackTask = nil
        allNotesOff()
    }

    public func stop() {
        state = .stopped
        playbackTask?.cancel()
        playbackTask = nil
        allNotesOff()
        currentTime = 0
        currentMeasure = 0
        pauseOffset = 0
        eventIndex = 0
    }

    public func seek(toMeasure measure: Int) {
        guard let map = measureMap,
              let entry = map.entry(forMeasure: measure) else { return }
        allNotesOff()
        currentTime = entry.startTime
        currentMeasure = measure
        pauseOffset = currentTime
        eventIndex = findEventIndex(at: currentTime)

        if state == .playing {
            startTimestamp = Date().addingTimeInterval(-currentTime)
        }
    }

    public func seek(to time: TimeInterval) {
        allNotesOff()
        currentTime = max(0, time)
        pauseOffset = currentTime
        eventIndex = findEventIndex(at: currentTime)

        if let entry = measureMap?.entry(at: currentTime) {
            currentMeasure = entry.measureNumber
        }

        if state == .playing {
            startTimestamp = Date().addingTimeInterval(-currentTime)
        }
    }

    /// Set tempo (recalculates event schedule).
    public func setTempo(_ newTempo: Double) {
        guard newTempo > 0 else { return }
        let wasPlaying = state == .playing
        if wasPlaying { pause() }

        self.tempo = newTempo
        if let map = measureMap {
            let newMap = map.withTempo(newTempo)
            self.measureMap = newMap
            // Re-schedule events with new map
            // For now, adjust timing proportionally
            let ratio = (measureMap?.entries.first?.tempo ?? 120.0) / newTempo
            events = events.map { event in
                PlaybackEvent(
                    time: event.time * ratio,
                    type: event.type,
                    partIndex: event.partIndex,
                    midiNote: event.midiNote,
                    velocity: event.velocity,
                    duration: event.duration * ratio,
                    measureNumber: event.measureNumber
                )
            }
        }

        if wasPlaying { play() }
    }

    // MARK: - Playback Loop

    private func startPlaybackLoop() {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled && self.state == .playing {
                guard let start = self.startTimestamp else { break }
                let elapsed = Date().timeIntervalSince(start)
                self.currentTime = elapsed

                // Process events up to current time
                self.processEvents(upTo: elapsed)

                // Check for end of score
                if let map = self.measureMap, elapsed >= map.totalDuration {
                    if self.isLooping, let loopStart = self.loopStartMeasure {
                        let loopMeasure = loopStart
                        self.seek(toMeasure: loopMeasure)
                        continue
                    } else {
                        self.stop()
                        self.onPlaybackComplete?()
                        break
                    }
                }

                // Update measure and fire metronome
                if let entry = self.measureMap?.entry(at: elapsed) {
                    if entry.measureNumber != self.currentMeasure {
                        self.currentMeasure = entry.measureNumber
                        self.onMeasureChanged?(entry.measureNumber)
                    }

                    // Metronome: calculate current beat within measure
                    if self.isMetronomeEnabled {
                        let beatsPerBar = entry.timeSignature.beats
                        let beatDuration = 60.0 / entry.tempo
                        let timeInMeasure = elapsed - entry.startTime
                        let currentBeat = Int(timeInMeasure / beatDuration)
                        let globalBeat = entry.measureNumber * 1000 + currentBeat
                        if globalBeat != self.lastMetronomeBeat && currentBeat < beatsPerBar {
                            self.lastMetronomeBeat = globalBeat
                            self.playMetronomeClick(isDownbeat: currentBeat == 0)
                        }
                    }
                }

                // Fire continuous time update for smooth UI
                self.onTimeUpdate?(elapsed, self.measureMap?.totalDuration ?? 0)

                try? await Task.sleep(for: .milliseconds(8)) // ~120Hz update rate
            }
        }
    }

    private func processEvents(upTo time: TimeInterval) {
        guard let sampler else { return }

        while eventIndex < events.count {
            let event = events[eventIndex]
            guard event.time <= time else { break }

            // Check if part is muted
            let isMuted = mutedParts.contains(event.partIndex)
            let isSoloActive = soloPart != nil
            let shouldPlay = !isMuted && (!isSoloActive || soloPart == event.partIndex)

            let channel = UInt8(min(event.partIndex, 15))

            if shouldPlay {
                switch event.type {
                case .noteOn:
                    let volume = partVolumes.indices.contains(event.partIndex)
                        ? partVolumes[event.partIndex] : 1.0
                    let adjustedVelocity = UInt8(min(127, Float(event.velocity) * volume))
                    sampler.startNote(UInt8(event.midiNote), withVelocity: adjustedVelocity, onChannel: channel)

                case .noteOff:
                    sampler.stopNote(UInt8(event.midiNote), onChannel: channel)

                case .tempoChange, .measureStart:
                    break
                }
            } else if event.type == .noteOff {
                // Always process note-off even if muted to avoid stuck notes
                sampler.stopNote(UInt8(event.midiNote), onChannel: channel)
            }

            eventIndex += 1
        }
    }

    // MARK: - Metronome

    public func playMetronomeClick(isDownbeat: Bool) {
        guard isMetronomeEnabled, let sampler else { return }
        // Use MIDI percussion channel (10) for metronome
        let note: UInt8 = isDownbeat ? 76 : 77 // High wood block / Low wood block
        sampler.startNote(note, withVelocity: isDownbeat ? 100 : 70, onChannel: 9)
        Task {
            try? await Task.sleep(for: .milliseconds(50))
            sampler.stopNote(note, onChannel: 9)
        }
    }

    // MARK: - Helpers

    private func allNotesOff() {
        guard let sampler else { return }
        let channelCount = UInt8(min(score?.parts.count ?? 1, 16))
        for ch: UInt8 in 0..<channelCount {
            for note: UInt8 in 0...127 {
                sampler.stopNote(note, onChannel: ch)
            }
        }
    }

    private func findEventIndex(at time: TimeInterval) -> Int {
        // Binary search for the first event at or after the given time
        var low = 0
        var high = events.count
        while low < high {
            let mid = (low + high) / 2
            if events[mid].time < time {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }

    /// Call this before the engine is deallocated to clean up audio resources.
    public func shutdown() {
        audioEngine?.stop()
    }
}
