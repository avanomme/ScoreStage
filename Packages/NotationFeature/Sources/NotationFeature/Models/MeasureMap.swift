// MeasureMap — maps measures to absolute time positions for playback synchronization.
// Handles tempo changes, time signature changes, repeats, and navigation markers.

import Foundation

// MARK: - Measure Timing Entry

/// Timing information for a single measure in the playback timeline.
public struct MeasureTimingEntry: Sendable {
    /// Measure number (1-based, from the score).
    public let measureNumber: Int
    /// Absolute start time in seconds from the beginning.
    public let startTime: TimeInterval
    /// Duration of this measure in seconds.
    public let duration: TimeInterval
    /// Tempo in BPM at the start of this measure.
    public let tempo: Double
    /// Time signature at this measure.
    public let timeSignature: TimeSignature
    /// Key signature at this measure.
    public let keySignature: KeySignature
    /// Rehearsal mark label if present.
    public let rehearsalMark: String?
    /// Navigation directions present in this measure.
    public let directions: [DirectionType]

    /// Absolute end time in seconds.
    public var endTime: TimeInterval { startTime + duration }
}

// MARK: - Measure Map

/// Pre-computed timeline of all measures with absolute timing.
/// Used by the playback engine to schedule events and by the UI to show the playhead.
public struct MeasureMap: Sendable {
    public let entries: [MeasureTimingEntry]
    public let totalDuration: TimeInterval

    /// Create a measure map from a NormalizedScore at a given base tempo.
    /// - Parameters:
    ///   - score: The parsed score.
    ///   - tempoOverride: Optional global tempo override (nil = use score tempos).
    public init(score: NormalizedScore, tempoOverride: Double? = nil) {
        guard let firstPart = score.parts.first, !firstPart.measures.isEmpty else {
            self.entries = []
            self.totalDuration = 0
            return
        }

        var entries: [MeasureTimingEntry] = []
        var currentTime: TimeInterval = 0
        var currentTempo: Double = tempoOverride ?? 120.0
        var currentTimeSig = TimeSignature(beats: 4, beatType: 4)
        var currentKeySig = KeySignature(fifths: 0, mode: .major)

        for measure in firstPart.measures {
            // Update state from measure markings
            if let ts = measure.timeSignature {
                currentTimeSig = ts
            }
            if let ks = measure.keySignature {
                currentKeySig = ks
            }
            if let tempo = measure.tempo, tempoOverride == nil {
                currentTempo = tempo.bpm
            }

            // Calculate measure duration
            let quarterNotesInMeasure = currentTimeSig.quarterNotesPerMeasure
            let secondsPerQuarter = 60.0 / currentTempo
            let measureDuration = quarterNotesInMeasure * secondsPerQuarter

            // Find rehearsal mark
            let rehearsalMark = measure.directions
                .first(where: { $0.type == .rehearsalMark })?.text

            // Collect direction types
            let directionTypes = measure.directions.map(\.type)

            let entry = MeasureTimingEntry(
                measureNumber: measure.number,
                startTime: currentTime,
                duration: measureDuration,
                tempo: currentTempo,
                timeSignature: currentTimeSig,
                keySignature: currentKeySig,
                rehearsalMark: rehearsalMark,
                directions: directionTypes
            )
            entries.append(entry)
            currentTime += measureDuration
        }

        self.entries = entries
        self.totalDuration = currentTime
    }

    // MARK: - Queries

    /// Find the measure entry at a given absolute time.
    public func entry(at time: TimeInterval) -> MeasureTimingEntry? {
        // Binary search for efficiency
        var low = 0
        var high = entries.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let entry = entries[mid]
            if time < entry.startTime {
                high = mid - 1
            } else if time >= entry.endTime {
                low = mid + 1
            } else {
                return entry
            }
        }
        return entries.last
    }

    /// Find the entry for a specific measure number.
    public func entry(forMeasure number: Int) -> MeasureTimingEntry? {
        entries.first(where: { $0.measureNumber == number })
    }

    /// All entries that have rehearsal marks.
    public var rehearsalEntries: [MeasureTimingEntry] {
        entries.filter { $0.rehearsalMark != nil }
    }

    /// Entries in a given time range (for loop regions).
    public func entries(from startTime: TimeInterval, to endTime: TimeInterval) -> [MeasureTimingEntry] {
        entries.filter { $0.startTime < endTime && $0.endTime > startTime }
    }

    /// Entries for a measure range (inclusive).
    public func entries(fromMeasure start: Int, toMeasure end: Int) -> [MeasureTimingEntry] {
        entries.filter { $0.measureNumber >= start && $0.measureNumber <= end }
    }

    /// Start time for a given measure number.
    public func startTime(forMeasure number: Int) -> TimeInterval? {
        entry(forMeasure: number)?.startTime
    }

    /// Recalculate the map with a new tempo (scales all durations proportionally).
    public func withTempo(_ newTempo: Double) -> MeasureMap {
        guard let firstEntry = entries.first else { return self }
        let ratio = firstEntry.tempo / newTempo
        var newEntries: [MeasureTimingEntry] = []
        var newTime: TimeInterval = 0

        for entry in entries {
            let newDuration = entry.duration * ratio
            newEntries.append(MeasureTimingEntry(
                measureNumber: entry.measureNumber,
                startTime: newTime,
                duration: newDuration,
                tempo: newTempo,
                timeSignature: entry.timeSignature,
                keySignature: entry.keySignature,
                rehearsalMark: entry.rehearsalMark,
                directions: entry.directions
            ))
            newTime += newDuration
        }

        return MeasureMap(entries: newEntries, totalDuration: newTime)
    }

    /// Private init for withTempo.
    private init(entries: [MeasureTimingEntry], totalDuration: TimeInterval) {
        self.entries = entries
        self.totalDuration = totalDuration
    }
}

// MARK: - Playback Event

/// A MIDI-level event scheduled for playback at an absolute time.
public struct PlaybackEvent: Sendable, Equatable, Comparable {
    public let time: TimeInterval
    public let type: PlaybackEventType
    public let partIndex: Int
    public let midiNote: Int
    public let velocity: Int
    public let duration: TimeInterval
    public let measureNumber: Int

    public init(
        time: TimeInterval,
        type: PlaybackEventType,
        partIndex: Int,
        midiNote: Int = 0,
        velocity: Int = 80,
        duration: TimeInterval = 0,
        measureNumber: Int = 0
    ) {
        self.time = time
        self.type = type
        self.partIndex = partIndex
        self.midiNote = midiNote
        self.velocity = velocity
        self.duration = duration
        self.measureNumber = measureNumber
    }

    public static func < (lhs: PlaybackEvent, rhs: PlaybackEvent) -> Bool {
        lhs.time < rhs.time
    }
}

public enum PlaybackEventType: Sendable, Equatable {
    case noteOn
    case noteOff
    case tempoChange(Double)
    case measureStart
}

// MARK: - Event Scheduler

/// Generates a flat list of playback events from a NormalizedScore and MeasureMap.
public struct PlaybackEventScheduler: Sendable {

    public init() {}

    /// Generate all playback events for the score.
    public func schedule(score: NormalizedScore, measureMap: MeasureMap, transposeSemitones: Int = 0) -> [PlaybackEvent] {
        var events: [PlaybackEvent] = []

        for (partIndex, part) in score.parts.enumerated() {
            for measure in part.measures {
                guard let timing = measureMap.entry(forMeasure: measure.number) else { continue }

                // Measure start event
                events.append(PlaybackEvent(
                    time: timing.startTime,
                    type: .measureStart,
                    partIndex: partIndex,
                    measureNumber: measure.number
                ))

                // Schedule notes
                let secondsPerDivision = timing.duration / Double(measure.timeSignature?.quarterNotesPerMeasure ?? 4.0) / 4.0
                var positionInDivisions: Int = 0

                for note in measure.notes where !note.isRest {
                    guard let midiNote = note.midiNote else { continue }
                    if note.isChord {
                        // Chord — same position as previous note
                    }

                    let noteTime = timing.startTime + Double(positionInDivisions) * secondsPerDivision
                    let noteDuration = Double(note.durationDivisions) * secondsPerDivision
                    let velocity = note.dynamics?.velocity ?? 80
                    let transposedNote = midiNote + transposeSemitones

                    guard transposedNote >= 0, transposedNote <= 127 else { continue }

                    events.append(PlaybackEvent(
                        time: noteTime,
                        type: .noteOn,
                        partIndex: partIndex,
                        midiNote: transposedNote,
                        velocity: velocity,
                        duration: noteDuration,
                        measureNumber: measure.number
                    ))

                    events.append(PlaybackEvent(
                        time: noteTime + noteDuration,
                        type: .noteOff,
                        partIndex: partIndex,
                        midiNote: transposedNote,
                        measureNumber: measure.number
                    ))

                    if !note.isChord {
                        positionInDivisions += note.durationDivisions
                    }
                }
            }
        }

        return events.sorted()
    }
}
