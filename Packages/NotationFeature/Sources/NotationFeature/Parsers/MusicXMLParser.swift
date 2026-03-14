// MusicXMLParser — parses MusicXML (.xml / .musicxml) and compressed MXL into NormalizedScore.

import Foundation

// MARK: - Parser Errors

public enum MusicXMLParserError: Error, Sendable {
    case fileNotFound
    case invalidXML(String)
    case unsupportedFormat
    case decompressionFailed
}

// MARK: - MusicXML Parser

/// Parses MusicXML files into a NormalizedScore representation.
public actor MusicXMLParser {

    public init() {}

    /// Parse a MusicXML file at the given URL.
    public func parse(url: URL) throws -> NormalizedScore {
        let data: Data
        if url.pathExtension.lowercased() == "mxl" {
            data = try decompressMXL(at: url)
        } else {
            data = try Data(contentsOf: url)
        }
        return try parse(data: data)
    }

    /// Parse MusicXML from raw data.
    public func parse(data: Data) throws -> NormalizedScore {
        let delegate = MusicXMLParserDelegate()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = delegate
        guard xmlParser.parse() else {
            throw MusicXMLParserError.invalidXML(
                xmlParser.parserError?.localizedDescription ?? "Unknown XML error"
            )
        }
        return delegate.buildScore()
    }

    /// Decompress .mxl (zip) to extract the root MusicXML file.
    private func decompressMXL(at url: URL) throws -> Data {
        // MXL is a ZIP archive. The rootfile is specified in META-INF/container.xml.
        // For simplicity, find the first .xml file in the archive.
        guard let archive = try? Data(contentsOf: url) else {
            throw MusicXMLParserError.fileNotFound
        }
        // Basic ZIP extraction — look for the .xml entry
        // In production, use a proper ZIP library. For now, try treating as plain XML first.
        if archive.count > 4 {
            // Check ZIP magic bytes: PK\x03\x04
            let header = [UInt8](archive.prefix(4))
            if header[0] == 0x50, header[1] == 0x4B, header[2] == 0x03, header[3] == 0x04 {
                // It's a real ZIP — extract using FileManager
                let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tempDir) }

                let zipPath = tempDir.appendingPathComponent("archive.mxl")
                try archive.write(to: zipPath)

                // Use Process on macOS / fallback
                #if os(macOS)
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
                process.arguments = ["-o", zipPath.path, "-d", tempDir.path]
                process.standardOutput = nil
                process.standardError = nil
                try process.run()
                process.waitUntilExit()
                #endif

                // Find .xml files
                if let contents = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
                    for file in contents where file.pathExtension == "xml" && file.lastPathComponent != "container.xml" {
                        return try Data(contentsOf: file)
                    }
                    // Check subdirectories
                    for dir in contents where dir.hasDirectoryPath {
                        if let subFiles = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
                            for file in subFiles where file.pathExtension == "xml" {
                                return try Data(contentsOf: file)
                            }
                        }
                    }
                }
                throw MusicXMLParserError.decompressionFailed
            }
        }
        // Not a ZIP, treat as plain XML
        return archive
    }
}

// MARK: - XMLParser Delegate

private final class MusicXMLParserDelegate: NSObject, XMLParserDelegate {
    // Build state
    private var score = NormalizedScore()
    private var currentPartList: [(id: String, name: String, abbreviation: String, midiProgram: Int, midiChannel: Int)] = []
    private var currentPartID: String?
    private var currentMeasure: Measure?
    private var currentNote: NoteEvent?
    private var currentPitch: Pitch?
    private var currentDirection: Direction?

    // Parsing state
    private var elementStack: [String] = []
    private var currentText = ""
    private var divisions: Int = 4
    private var currentDuration: Int = 0
    private var currentTimeBeats: Int?
    private var currentTimeBeatType: Int?
    private var currentKeyFifths: Int?
    private var currentKeyMode: String?
    private var currentTempo: Double?
    private var currentMidiProgram: Int = 0
    private var currentMidiChannel: Int = 0
    private var currentPartName = ""
    private var currentPartAbbrev = ""
    private var currentPartIDAttr: String?
    private var inForward = false
    private var isChord = false
    private var partMeasures: [String: [Measure]] = [:]
    private var currentBarlineLocation: String?

    func buildScore() -> NormalizedScore {
        // Build parts from part-list + collected measures
        score.parts = currentPartList.map { entry in
            Part(
                id: entry.id,
                name: entry.name,
                abbreviation: entry.abbreviation,
                midiProgram: entry.midiProgram,
                midiChannel: entry.midiChannel,
                measures: partMeasures[entry.id] ?? []
            )
        }
        return score
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        elementStack.append(elementName)
        currentText = ""

        switch elementName {
        case "score-part":
            currentPartIDAttr = attributeDict["id"]
            currentPartName = ""
            currentPartAbbrev = ""
            currentMidiProgram = 0
            currentMidiChannel = 0

        case "part":
            currentPartID = attributeDict["id"]

        case "measure":
            let number = Int(attributeDict["number"] ?? "0") ?? 0
            currentMeasure = Measure(number: number)

        case "note":
            currentNote = NoteEvent()
            currentPitch = nil
            currentDuration = 0
            isChord = false

        case "chord":
            isChord = true

        case "rest":
            currentPitch = nil

        case "pitch":
            currentPitch = Pitch(step: .C, alter: 0, octave: 4)

        case "direction":
            currentDirection = Direction(type: .words)

        case "barline":
            currentBarlineLocation = attributeDict["location"] ?? "right"

        case "repeat":
            if let dir = attributeDict["direction"] {
                if dir == "forward" {
                    currentMeasure?.repeatStart = true
                } else if dir == "backward" {
                    currentMeasure?.repeatEnd = true
                    if let times = attributeDict["times"], let t = Int(times) {
                        currentMeasure?.repeatTimes = t
                    }
                }
            }

        case "ending":
            if let numStr = attributeDict["number"], let num = Int(numStr),
               let typeStr = attributeDict["type"], let type = EndingType(rawValue: typeStr) {
                currentMeasure?.ending = Ending(number: num, type: type)
            }

        case "sound":
            if let tempoStr = attributeDict["tempo"], let bpm = Double(tempoStr) {
                currentTempo = bpm
                if inDirection {
                    currentMeasure?.tempo = TempoMarking(bpm: bpm)
                }
            }

        case "forward":
            inForward = true

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
        // Score metadata
        case "work-title":
            score.metadata.workTitle = text
            if score.title.isEmpty { score.title = text }

        case "movement-title":
            score.metadata.movementTitle = text
            if score.title.isEmpty { score.title = text }

        case "creator":
            score.metadata.creator = text
            if score.composer.isEmpty { score.composer = text }

        case "rights":
            score.metadata.rights = text

        case "encoding-date":
            score.metadata.encodingDate = text

        case "software":
            score.metadata.software = text

        // Part list
        case "part-name":
            if inPartList { currentPartName = text }

        case "part-abbreviation":
            if inPartList { currentPartAbbrev = text }

        case "midi-channel":
            if let ch = Int(text) { currentMidiChannel = ch }

        case "midi-program":
            if let prog = Int(text) { currentMidiProgram = prog }

        case "score-part":
            if let id = currentPartIDAttr {
                currentPartList.append((
                    id: id,
                    name: currentPartName,
                    abbreviation: currentPartAbbrev,
                    midiProgram: currentMidiProgram,
                    midiChannel: currentMidiChannel
                ))
            }
            currentPartIDAttr = nil

        // Divisions
        case "divisions":
            if let d = Int(text) { divisions = d }

        // Time signature
        case "beats":
            if inTime { currentTimeBeats = Int(text) }

        case "beat-type":
            if inTime { currentTimeBeatType = Int(text) }

        case "time":
            if let beats = currentTimeBeats, let beatType = currentTimeBeatType {
                currentMeasure?.timeSignature = TimeSignature(beats: beats, beatType: beatType)
            }
            currentTimeBeats = nil
            currentTimeBeatType = nil

        // Key signature
        case "fifths":
            if inKey { currentKeyFifths = Int(text) }

        case "mode":
            if inKey { currentKeyMode = text }

        case "key":
            let fifths = currentKeyFifths ?? 0
            let mode = KeyMode(rawValue: currentKeyMode ?? "major") ?? .major
            currentMeasure?.keySignature = KeySignature(fifths: fifths, mode: mode)
            currentKeyFifths = nil
            currentKeyMode = nil

        // Pitch components
        case "step":
            if let step = PitchStep(rawValue: text) {
                currentPitch?.step = step
            }

        case "alter":
            if let a = Int(text) { currentPitch?.alter = a }

        case "octave":
            if let o = Int(text) { currentPitch?.octave = o }

        // Note duration/type
        case "duration":
            if inForward {
                // forward element — skip
            } else if inNote {
                currentDuration = Int(text) ?? 0
            }

        case "type":
            if inNote {
                currentNote?.duration = noteDuration(from: text)
            }

        case "dot":
            if inNote {
                if currentNote?.isDotted == true {
                    currentNote?.isDoubleDotted = true
                } else {
                    currentNote?.isDotted = true
                }
            }

        case "voice":
            if inNote, let v = Int(text) { currentNote?.voice = v }

        case "staff":
            if inNote, let s = Int(text) { currentNote?.staff = s }

        case "tie":
            // tie type is in attributes, handled in didStartElement next iteration
            break

        // Articulations
        case "staccato": addArticulation(.staccato)
        case "accent": addArticulation(.accent)
        case "tenuto": addArticulation(.tenuto)
        case "strong-accent": addArticulation(.marcato)
        case "fermata": addArticulation(.fermata)

        // Dynamics
        case "pp": currentNote?.dynamics = .pp
        case "p": if inDynamics { currentNote?.dynamics = .p }
        case "mp": currentNote?.dynamics = .mp
        case "mf": currentNote?.dynamics = .mf
        case "f": if inDynamics { currentNote?.dynamics = .f }
        case "ff": currentNote?.dynamics = .ff
        case "fff": currentNote?.dynamics = .fff
        case "ppp": currentNote?.dynamics = .ppp
        case "sfz": currentNote?.dynamics = .sfz
        case "fp": currentNote?.dynamics = .fp

        // Direction
        case "rehearsal":
            currentDirection?.type = .rehearsalMark
            currentDirection?.text = text

        case "segno":
            if inDirection { currentDirection?.type = .segno }

        case "coda":
            if inDirection { currentDirection?.type = .coda }

        case "words":
            if inDirection {
                let lower = text.lowercased()
                if lower.contains("d.c.") || lower.contains("da capo") {
                    currentDirection?.type = .daCapo
                } else if lower.contains("d.s.") || lower.contains("dal segno") {
                    currentDirection?.type = .dalSegno
                } else if lower.contains("fine") {
                    currentDirection?.type = .fine
                } else {
                    currentDirection?.type = .words
                }
                currentDirection?.text = text
            }

        case "direction":
            if let dir = currentDirection {
                currentMeasure?.directions.append(dir)
            }
            currentDirection = nil

        // Barline
        case "bar-style":
            let barline = barlineType(from: text)
            if currentBarlineLocation == "left" {
                currentMeasure?.barlineLeft = barline
            } else {
                currentMeasure?.barlineRight = barline
            }

        case "barline":
            currentBarlineLocation = nil

        // Note complete
        case "note":
            if var note = currentNote {
                note.pitch = currentPitch
                note.isChord = isChord
                currentMeasure?.notes.append(note)
            }
            currentNote = nil
            currentPitch = nil
            isChord = false

        // Measure complete
        case "measure":
            if let measure = currentMeasure, let partID = currentPartID {
                partMeasures[partID, default: []].append(measure)
            }
            currentMeasure = nil

        // Part complete
        case "part":
            currentPartID = nil

        case "forward":
            inForward = false

        default:
            break
        }

        if !elementStack.isEmpty { elementStack.removeLast() }
    }

    // MARK: - Helpers

    private var inPartList: Bool { elementStack.contains("part-list") }
    private var inTime: Bool { elementStack.contains("time") }
    private var inKey: Bool { elementStack.contains("key") }
    private var inNote: Bool { elementStack.contains("note") }
    private var inDirection: Bool { elementStack.contains("direction") }
    private var inDynamics: Bool { elementStack.contains("dynamics") }

    private func addArticulation(_ art: Articulation) {
        if inNote { currentNote?.articulations.append(art) }
    }

    private func noteDuration(from text: String) -> NoteDuration {
        switch text {
        case "whole": .whole
        case "half": .half
        case "quarter": .quarter
        case "eighth": .eighth
        case "16th": .sixteenth
        case "32nd": .thirtySecond
        case "64th": .sixtyFourth
        default: .quarter
        }
    }

    private func barlineType(from text: String) -> BarlineType {
        switch text {
        case "light-light": .double
        case "light-heavy": .finalDouble
        case "heavy-light": .repeatForward
        default: .regular
        }
    }
}
