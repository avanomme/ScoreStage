// MIDIInputService — Detects MIDI keyboard input and compares against the score.

import Foundation
import CoreMIDI
import Combine
import NotationFeature

/// Listens for MIDI input from connected keyboards and provides real-time
/// note comparison against the current score position.
@MainActor
@Observable
public final class MIDIInputService {
    public enum ControlEvent: Sendable, Equatable {
        case noteOn(note: Int, velocity: Int, channel: Int)
        case noteOff(note: Int, channel: Int)
        case controlChange(controller: Int, value: Int, channel: Int)
    }

    // MARK: - Public State

    public enum ConnectionState: Sendable {
        case disconnected
        case searching
        case connected(String)
    }

    /// Current MIDI connection state.
    public private(set) var connectionState: ConnectionState = .disconnected

    /// Last played MIDI note number (0-127).
    public private(set) var lastPlayedNote: Int?

    /// Last played velocity (0-127).
    public private(set) var lastPlayedVelocity: Int?

    /// Last received MIDI control event.
    public private(set) var lastControlEvent: ControlEvent?

    /// Currently held notes (for chord detection).
    public private(set) var activeNotes: Set<Int> = []

    /// Notes expected at the current score position.
    public private(set) var expectedNotes: Set<Int> = []

    /// Whether the last played note(s) matched the expected note(s).
    public private(set) var lastMatchResult: MatchResult = .none

    /// Running count of correct/incorrect notes.
    public private(set) var correctCount: Int = 0
    public private(set) var incorrectCount: Int = 0

    /// Accuracy percentage.
    public var accuracy: Double {
        let total = correctCount + incorrectCount
        guard total > 0 else { return 0 }
        return Double(correctCount) / Double(total) * 100
    }

    // MARK: - Match Result

    public enum MatchResult: Sendable {
        case none
        case correct
        case incorrect
        case partial    // Some notes correct in a chord
    }

    // MARK: - Private

    private var midiClient = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var noteOnCallback: ((Int, Int) -> Void)?
    private var noteOffCallback: ((Int) -> Void)?
    public var onControlEvent: ((ControlEvent) -> Void)?

    public init() {}

    // MARK: - Connection

    /// Start listening for MIDI input from all available sources.
    public func start() {
        if midiClient != 0 || inputPort != 0 {
            stop()
        }
        connectionState = .searching

        let status = MIDIClientCreateWithBlock("ScoreStage" as CFString, &midiClient) { [weak self] notification in
            Task { @MainActor in
                self?.handleMIDINotification(notification)
            }
        }

        guard status == noErr else {
            connectionState = .disconnected
            return
        }

        // Create input port
        let portStatus = MIDIInputPortCreateWithProtocol(
            midiClient,
            "Input" as CFString,
            ._1_0,
            &inputPort
        ) { [weak self] eventList, _ in
            self?.processMIDIEventList(eventList)
        }

        guard portStatus == noErr else {
            connectionState = .disconnected
            return
        }

        connectToAllSources()
    }

    /// Stop listening for MIDI input.
    public func stop() {
        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
        connectionState = .disconnected
        activeNotes.removeAll()
    }

    /// Reset practice counters.
    public func resetCounters() {
        correctCount = 0
        incorrectCount = 0
        lastMatchResult = .none
    }

    // MARK: - Score Comparison

    /// Set the expected notes at the current score position.
    /// Called by the playback engine or manually when advancing through the score.
    public func setExpectedNotes(_ notes: Set<Int>) {
        expectedNotes = notes
    }

    /// Set expected notes from a NoteEvent array (current measure's notes).
    public func setExpectedNotes(from noteEvents: [NoteEvent], transposeSemitones: Int = 0) {
        expectedNotes = Set(
            noteEvents
                .compactMap(\.midiNote)
                .map { $0 + transposeSemitones }
                .filter { $0 >= 0 && $0 <= 127 }
        )
    }

    // MARK: - MIDI Processing

    private func connectToAllSources() {
        let sourceCount = MIDIGetNumberOfSources()
        guard sourceCount > 0 else {
            connectionState = .disconnected
            return
        }

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            MIDIPortConnectSource(inputPort, source, nil)
        }

        // Get first source name
        let firstSource = MIDIGetSource(0)
        var nameRef: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(firstSource, kMIDIPropertyDisplayName, &nameRef)
        let name = (nameRef?.takeRetainedValue() as String?) ?? "MIDI Device"
        connectionState = .connected(name)
    }

    nonisolated private func processMIDIEventList(_ eventListPtr: UnsafePointer<MIDIEventList>) {
        let eventList = eventListPtr.pointee
        var packet = eventList.packet

        for _ in 0..<eventList.numPackets {
            let words = Mirror(reflecting: packet.words).children.map { $0.value as! UInt32 }
            if let firstWord = words.first, firstWord != 0 {
                let status = UInt8((firstWord >> 16) & 0xFF)
                let data1 = UInt8((firstWord >> 8) & 0xFF)
                let data2 = UInt8(firstWord & 0xFF)

                let messageType = status & 0xF0
                let channel = Int(status & 0x0F)

                Task { @MainActor in
                    switch messageType {
                    case 0x90: // Note On
                        if data2 > 0 {
                            self.handleNoteOn(Int(data1), velocity: Int(data2))
                            self.recordControlEvent(.noteOn(note: Int(data1), velocity: Int(data2), channel: channel))
                        } else {
                            self.handleNoteOff(Int(data1))
                            self.recordControlEvent(.noteOff(note: Int(data1), channel: channel))
                        }
                    case 0x80: // Note Off
                        self.handleNoteOff(Int(data1))
                        self.recordControlEvent(.noteOff(note: Int(data1), channel: channel))
                    case 0xB0: // Control Change
                        self.recordControlEvent(.controlChange(controller: Int(data1), value: Int(data2), channel: channel))
                    default:
                        break
                    }
                }
            }

            packet = MIDIEventPacketNext(&packet).pointee
        }
    }

    private func handleNoteOn(_ note: Int, velocity: Int) {
        lastPlayedNote = note
        lastPlayedVelocity = velocity
        activeNotes.insert(note)

        evaluateMatch()
    }

    private func handleNoteOff(_ note: Int) {
        activeNotes.remove(note)
    }

    private func recordControlEvent(_ event: ControlEvent) {
        lastControlEvent = event
        onControlEvent?(event)
    }

    private func evaluateMatch() {
        guard !expectedNotes.isEmpty else {
            lastMatchResult = .none
            return
        }

        let intersection = activeNotes.intersection(expectedNotes)

        if intersection == expectedNotes {
            lastMatchResult = .correct
            correctCount += 1
        } else if !intersection.isEmpty {
            lastMatchResult = .partial
        } else if !activeNotes.isEmpty {
            lastMatchResult = .incorrect
            incorrectCount += 1
        }
    }

    // MARK: - MIDI Notifications

    nonisolated private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let messageID = notification.pointee.messageID
        Task { @MainActor in
            switch messageID {
            case .msgObjectAdded:
                self.connectToAllSources()
            case .msgObjectRemoved:
                let sourceCount = MIDIGetNumberOfSources()
                if sourceCount == 0 {
                    self.connectionState = .disconnected
                }
            default:
                break
            }
        }
    }

    // MARK: - Note Name Helper

    /// Convert MIDI note number to a human-readable note name.
    public static func noteName(for midiNote: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = (midiNote / 12) - 1
        let note = midiNote % 12
        return "\(names[note])\(octave)"
    }
}
