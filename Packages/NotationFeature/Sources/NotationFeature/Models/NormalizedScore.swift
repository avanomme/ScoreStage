// NormalizedScore — in-memory representation of parsed notation data.
// This is NOT a SwiftData model — it's a transient parse result used by
// the playback engine, measure map, and rehearsal marks panel.

import Foundation

// MARK: - Top-Level Score

/// A fully parsed musical score with parts, measures, and metadata.
public struct NormalizedScore: Sendable {
    public var title: String
    public var composer: String
    public var arranger: String
    public var parts: [Part]
    public var metadata: ScoreMetadata

    public init(
        title: String = "",
        composer: String = "",
        arranger: String = "",
        parts: [Part] = [],
        metadata: ScoreMetadata = ScoreMetadata()
    ) {
        self.title = title
        self.composer = composer
        self.arranger = arranger
        self.parts = parts
        self.metadata = metadata
    }

    /// Total number of measures (from the first part, or 0).
    public var measureCount: Int {
        parts.first?.measures.count ?? 0
    }
}

// MARK: - Score Metadata

public struct ScoreMetadata: Sendable {
    public var workTitle: String
    public var movementTitle: String
    public var movementNumber: Int?
    public var creator: String
    public var rights: String
    public var encodingDate: String
    public var software: String

    public init(
        workTitle: String = "",
        movementTitle: String = "",
        movementNumber: Int? = nil,
        creator: String = "",
        rights: String = "",
        encodingDate: String = "",
        software: String = ""
    ) {
        self.workTitle = workTitle
        self.movementTitle = movementTitle
        self.movementNumber = movementNumber
        self.creator = creator
        self.rights = rights
        self.encodingDate = encodingDate
        self.software = software
    }
}

// MARK: - Part

/// A single instrumental/vocal part in the score.
public struct Part: Sendable, Identifiable {
    public let id: String
    public var name: String
    public var abbreviation: String
    public var midiProgram: Int
    public var midiChannel: Int
    public var transposeDiatonic: Int
    public var transposeChromatic: Int
    public var measures: [Measure]

    public init(
        id: String,
        name: String = "",
        abbreviation: String = "",
        midiProgram: Int = 0,
        midiChannel: Int = 0,
        transposeDiatonic: Int = 0,
        transposeChromatic: Int = 0,
        measures: [Measure] = []
    ) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.midiProgram = midiProgram
        self.midiChannel = midiChannel
        self.transposeDiatonic = transposeDiatonic
        self.transposeChromatic = transposeChromatic
        self.measures = measures
    }
}

// MARK: - Measure

/// A single measure/bar within a part.
public struct Measure: Sendable {
    public var number: Int
    public var timeSignature: TimeSignature?
    public var keySignature: KeySignature?
    public var tempo: TempoMarking?
    public var notes: [NoteEvent]
    public var directions: [Direction]
    public var barlineLeft: BarlineType?
    public var barlineRight: BarlineType?
    public var repeatStart: Bool
    public var repeatEnd: Bool
    public var repeatTimes: Int
    public var ending: Ending?

    public init(
        number: Int,
        timeSignature: TimeSignature? = nil,
        keySignature: KeySignature? = nil,
        tempo: TempoMarking? = nil,
        notes: [NoteEvent] = [],
        directions: [Direction] = [],
        barlineLeft: BarlineType? = nil,
        barlineRight: BarlineType? = nil,
        repeatStart: Bool = false,
        repeatEnd: Bool = false,
        repeatTimes: Int = 2,
        ending: Ending? = nil
    ) {
        self.number = number
        self.timeSignature = timeSignature
        self.keySignature = keySignature
        self.tempo = tempo
        self.notes = notes
        self.directions = directions
        self.barlineLeft = barlineLeft
        self.barlineRight = barlineRight
        self.repeatStart = repeatStart
        self.repeatEnd = repeatEnd
        self.repeatTimes = repeatTimes
        self.ending = ending
    }
}

// MARK: - Note Event

/// A single note or rest within a measure.
public struct NoteEvent: Sendable {
    public var pitch: Pitch?       // nil = rest
    public var duration: NoteDuration
    public var voice: Int
    public var staff: Int
    public var isChord: Bool
    public var isDotted: Bool
    public var isDoubleDotted: Bool
    public var isTied: Bool
    public var tieType: TieType?
    public var dynamics: DynamicLevel?
    public var articulations: [Articulation]

    public init(
        pitch: Pitch? = nil,
        duration: NoteDuration = .quarter,
        voice: Int = 1,
        staff: Int = 1,
        isChord: Bool = false,
        isDotted: Bool = false,
        isDoubleDotted: Bool = false,
        isTied: Bool = false,
        tieType: TieType? = nil,
        dynamics: DynamicLevel? = nil,
        articulations: [Articulation] = []
    ) {
        self.pitch = pitch
        self.duration = duration
        self.voice = voice
        self.staff = staff
        self.isChord = isChord
        self.isDotted = isDotted
        self.isDoubleDotted = isDoubleDotted
        self.isTied = isTied
        self.tieType = tieType
        self.dynamics = dynamics
        self.articulations = articulations
    }

    /// Is this a rest (no pitch)?
    public var isRest: Bool { pitch == nil }

    /// MIDI note number (concert pitch, 0-127).
    public var midiNote: Int? { pitch?.midiNote }

    /// Duration in divisions (relative to MusicXML divisions).
    public var durationDivisions: Int {
        var base = duration.baseDivisions
        if isDotted { base = base + base / 2 }
        if isDoubleDotted { base = base + base / 2 + base / 4 }
        return base
    }
}

// MARK: - Pitch

public struct Pitch: Sendable, Equatable {
    public var step: PitchStep
    public var alter: Int       // -1 flat, 0 natural, +1 sharp
    public var octave: Int

    public init(step: PitchStep, alter: Int = 0, octave: Int = 4) {
        self.step = step
        self.alter = alter
        self.octave = octave
    }

    /// MIDI note number (C4 = 60).
    public var midiNote: Int {
        let base: Int
        switch step {
        case .C: base = 0
        case .D: base = 2
        case .E: base = 4
        case .F: base = 5
        case .G: base = 7
        case .A: base = 9
        case .B: base = 11
        }
        return (octave + 1) * 12 + base + alter
    }
}

public enum PitchStep: String, Sendable, CaseIterable {
    case C, D, E, F, G, A, B
}

// MARK: - Note Duration

public enum NoteDuration: String, Sendable, CaseIterable {
    case whole
    case half
    case quarter
    case eighth
    case sixteenth
    case thirtySecond = "32nd"
    case sixtyFourth = "64th"

    /// Base divisions assuming 4 divisions per quarter note.
    public var baseDivisions: Int {
        switch self {
        case .whole: 16
        case .half: 8
        case .quarter: 4
        case .eighth: 2
        case .sixteenth: 1
        case .thirtySecond: 1 // sub-division limit
        case .sixtyFourth: 1
        }
    }
}

// MARK: - Time Signature

public struct TimeSignature: Sendable, Equatable {
    public var beats: Int
    public var beatType: Int

    public init(beats: Int = 4, beatType: Int = 4) {
        self.beats = beats
        self.beatType = beatType
    }

    /// Duration of one measure in quarter-note equivalents.
    public var quarterNotesPerMeasure: Double {
        Double(beats) * 4.0 / Double(beatType)
    }
}

// MARK: - Key Signature

public struct KeySignature: Sendable, Equatable {
    public var fifths: Int       // -7 to +7 (negative = flats)
    public var mode: KeyMode

    public init(fifths: Int = 0, mode: KeyMode = .major) {
        self.fifths = fifths
        self.mode = mode
    }

    public var keyName: String {
        let majorKeys = ["Cb","Gb","Db","Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#"]
        let minorKeys = ["Ab","Eb","Bb","F","C","G","D","A","E","B","F#","C#","G#","D#","A#"]
        let index = fifths + 7
        guard index >= 0, index < 15 else { return "C" }
        switch mode {
        case .major: return majorKeys[index]
        case .minor: return minorKeys[index] + "m"
        }
    }
}

public enum KeyMode: String, Sendable {
    case major
    case minor
}

// MARK: - Tempo

public struct TempoMarking: Sendable {
    public var bpm: Double
    public var beatUnit: NoteDuration
    public var text: String        // e.g. "Allegro"

    public init(bpm: Double = 120, beatUnit: NoteDuration = .quarter, text: String = "") {
        self.bpm = bpm
        self.beatUnit = beatUnit
        self.text = text
    }
}

// MARK: - Direction (text expressions, dynamics, rehearsal marks)

public struct Direction: Sendable {
    public var type: DirectionType
    public var text: String
    public var offset: Int         // position within measure

    public init(type: DirectionType, text: String = "", offset: Int = 0) {
        self.type = type
        self.text = text
        self.offset = offset
    }
}

public enum DirectionType: String, Sendable {
    case rehearsalMark
    case segno
    case coda
    case daCapo
    case dalSegno
    case fine
    case dynamicMark
    case words        // generic text direction
    case crescendo
    case diminuendo
}

// MARK: - Dynamics

public enum DynamicLevel: String, Sendable, CaseIterable {
    case ppp, pp, p, mp, mf, f, ff, fff, sfz, fp

    public var velocity: Int {
        switch self {
        case .ppp: 16
        case .pp: 33
        case .p: 49
        case .mp: 64
        case .mf: 80
        case .f: 96
        case .ff: 112
        case .fff: 127
        case .sfz: 120
        case .fp: 96
        }
    }
}

// MARK: - Articulation

public enum Articulation: String, Sendable {
    case staccato
    case accent
    case tenuto
    case marcato
    case fermata
    case trill
    case mordent
    case turn
    case upBow = "up-bow"
    case downBow = "down-bow"
}

// MARK: - Barline & Repeat

public enum BarlineType: String, Sendable {
    case regular
    case double = "light-light"
    case finalDouble = "light-heavy"
    case repeatForward = "heavy-light"
    case repeatBackward = "light-heavy-repeat"
}

public enum TieType: String, Sendable {
    case start, stop
}

public struct Ending: Sendable {
    public var number: Int
    public var type: EndingType

    public init(number: Int, type: EndingType) {
        self.number = number
        self.type = type
    }
}

public enum EndingType: String, Sendable {
    case start, stop, discontinue
}
