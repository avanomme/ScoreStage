// MEIParser — parses MEI (Music Encoding Initiative) XML into NormalizedScore.
// MEI uses a different schema than MusicXML but maps to the same normalized model.

import Foundation

// MARK: - Parser Errors

public enum MEIParserError: Error, Sendable {
    case fileNotFound
    case invalidXML(String)
    case unsupportedVersion
}

// MARK: - MEI Parser

/// Parses MEI files into a NormalizedScore representation.
public actor MEIParser {

    public init() {}

    /// Parse an MEI file at the given URL.
    public func parse(url: URL) throws -> NormalizedScore {
        let data = try Data(contentsOf: url)
        return try parse(data: data)
    }

    /// Parse MEI from raw data.
    public func parse(data: Data) throws -> NormalizedScore {
        let delegate = MEIParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            throw MEIParserError.invalidXML(
                xmlParser.parserError?.localizedDescription ?? "Unknown XML error"
            )
        }
        return delegate.buildScore()
    }
}

// MARK: - MEI XMLParser Delegate

private final class MEIParserDelegate: NSObject, XMLParserDelegate {
    private var score = NormalizedScore()
    private var elementStack: [String] = []
    private var currentText = ""

    // Part building
    private var staffDefs: [(id: String, name: String, midiProgram: Int, midiChannel: Int)] = []
    private var currentStaffN: String?
    private var currentMeasureNumber: Int = 0
    private var measuresByStaff: [String: [Measure]] = [:]
    private var currentNotes: [NoteEvent] = []
    private var currentDirections: [Direction] = []
    private var currentTimeBeats: Int?
    private var currentTimeBeatType: Int?
    private var currentKeyFifths: Int?
    private var currentKeyMode: String?

    func buildScore() -> NormalizedScore {
        score.parts = staffDefs.map { def in
            Part(
                id: def.id,
                name: def.name,
                midiProgram: def.midiProgram,
                midiChannel: def.midiChannel,
                measures: measuresByStaff[def.id] ?? []
            )
        }
        return score
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attrs: [String: String] = [:]) {
        elementStack.append(elementName)
        currentText = ""

        switch elementName {
        // MEI header metadata
        case "title":
            break // text collected in didEnd

        case "persName":
            break // composer, lyricist etc.

        // Staff definitions (in scoreDef)
        case "staffDef":
            let n = attrs["n"] ?? String(staffDefs.count + 1)
            let label = attrs["label"] ?? "Staff \(n)"
            let midiProgram = Int(attrs["midi.instrnum"] ?? "0") ?? 0
            let midiChannel = Int(attrs["midi.channel"] ?? "0") ?? 0
            staffDefs.append((id: n, name: label, midiProgram: midiProgram, midiChannel: midiChannel))

            // Meter from staffDef
            if let beats = attrs["meter.count"], let beatType = attrs["meter.unit"] {
                currentTimeBeats = Int(beats)
                currentTimeBeatType = Int(beatType)
            }
            // Key from staffDef
            if let sig = attrs["key.sig"] {
                currentKeyFifths = parseKeySig(sig)
                currentKeyMode = attrs["key.mode"]
            }

        // Measures
        case "measure":
            currentMeasureNumber = Int(attrs["n"] ?? "0") ?? 0
            currentNotes = []
            currentDirections = []

        // Staff within measure
        case "staff":
            currentStaffN = attrs["n"]
            currentNotes = []

        // Notes
        case "note":
            var note = NoteEvent()
            if let pitchName = attrs["pname"], let step = PitchStep(rawValue: pitchName.uppercased()) {
                let octave = Int(attrs["oct"] ?? "4") ?? 4
                let alter = parseAccidental(attrs["accid"] ?? attrs["accid.ges"] ?? "")
                note.pitch = Pitch(step: step, alter: alter, octave: octave)
            }
            if let dur = attrs["dur"] {
                note.duration = meiDuration(dur)
            }
            if attrs["dots"] == "1" { note.isDotted = true }
            if attrs["dots"] == "2" { note.isDoubleDotted = true }
            if let staff = attrs["staff"], let s = Int(staff) { note.staff = s }
            currentNotes.append(note)

        // Rests
        case "rest", "mRest":
            var note = NoteEvent()
            note.pitch = nil // rest
            if let dur = attrs["dur"] {
                note.duration = meiDuration(dur)
            } else if elementName == "mRest" {
                note.duration = .whole // whole-measure rest
            }
            currentNotes.append(note)

        // Directions
        case "dir":
            break

        case "tempo":
            if let bpmStr = attrs["midi.bpm"], let _ = Double(bpmStr) {
                currentDirections.append(Direction(type: .words, text: attrs["label"] ?? ""))
            }

        case "reh":
            break // rehearsal mark — text collected in didEnd

        case "dynam":
            break // dynamics — text collected in didEnd

        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title":
            if inHeader && score.title.isEmpty {
                score.title = text
            }

        case "persName":
            if inHeader && score.composer.isEmpty {
                score.composer = text
            }

        case "staff":
            // Close staff — assign collected notes to measure for this staff
            if let staffN = currentStaffN {
                var measure = Measure(number: currentMeasureNumber, notes: currentNotes)
                // Apply time/key sig from staffDef for first measure
                if currentMeasureNumber <= 1 {
                    if let beats = currentTimeBeats, let beatType = currentTimeBeatType {
                        measure.timeSignature = TimeSignature(beats: beats, beatType: beatType)
                    }
                    if let fifths = currentKeyFifths {
                        let mode = KeyMode(rawValue: currentKeyMode ?? "major") ?? .major
                        measure.keySignature = KeySignature(fifths: fifths, mode: mode)
                    }
                }
                measure.directions = currentDirections
                measuresByStaff[staffN, default: []].append(measure)
            }
            currentStaffN = nil
            currentNotes = []

        case "measure":
            // If no staff elements (single-staff score), assign to first staffDef
            if currentStaffN == nil, !currentNotes.isEmpty, let firstStaff = staffDefs.first {
                var measure = Measure(number: currentMeasureNumber, notes: currentNotes)
                measure.directions = currentDirections
                measuresByStaff[firstStaff.id, default: []].append(measure)
            }
            currentNotes = []
            currentDirections = []

        case "reh":
            if !text.isEmpty {
                currentDirections.append(Direction(type: .rehearsalMark, text: text))
            }

        case "dynam":
            if let level = parseDynamic(text) {
                // Apply to last note if available
                if !currentNotes.isEmpty {
                    currentNotes[currentNotes.count - 1].dynamics = level
                }
            }

        case "dir":
            if !text.isEmpty {
                currentDirections.append(Direction(type: .words, text: text))
            }

        default:
            break
        }

        if !elementStack.isEmpty { elementStack.removeLast() }
    }

    // MARK: - Helpers

    private var inHeader: Bool { elementStack.contains("meiHead") }

    private func meiDuration(_ dur: String) -> NoteDuration {
        switch dur {
        case "1", "whole": .whole
        case "2", "half": .half
        case "4", "quarter": .quarter
        case "8", "eighth": .eighth
        case "16": .sixteenth
        case "32": .thirtySecond
        case "64": .sixtyFourth
        default: .quarter
        }
    }

    private func parseAccidental(_ accid: String) -> Int {
        switch accid {
        case "s", "sharp": 1
        case "f", "flat": -1
        case "ss", "double-sharp", "x": 2
        case "ff", "double-flat": -2
        case "n", "natural": 0
        default: 0
        }
    }

    private func parseKeySig(_ sig: String) -> Int {
        // MEI key.sig format: "3f" = 3 flats, "2s" = 2 sharps
        guard sig.count >= 2 else { return 0 }
        let numStr = String(sig.dropLast())
        let suffix = sig.last
        guard let num = Int(numStr) else { return 0 }
        return suffix == "f" ? -num : num
    }

    private func parseDynamic(_ text: String) -> DynamicLevel? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return DynamicLevel(rawValue: cleaned)
    }
}
