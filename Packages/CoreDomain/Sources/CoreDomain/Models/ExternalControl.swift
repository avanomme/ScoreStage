import Foundation

public enum ExternalControlAction: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case nextPage
    case previousPage
    case playPausePlayback
    case stopPlayback
    case togglePlaybackPanel
    case openQuickJump
    case toggleAnnotationMode
    case toggleLinkedSession
    case toggleSetlistPanel
    case nextSetlistItem
    case previousSetlistItem
    case togglePerformanceLock

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .none: "Unassigned"
        case .nextPage: "Next Page"
        case .previousPage: "Previous Page"
        case .playPausePlayback: "Play / Pause"
        case .stopPlayback: "Stop Playback"
        case .togglePlaybackPanel: "Playback Panel"
        case .openQuickJump: "Quick Jump"
        case .toggleAnnotationMode: "Annotation Mode"
        case .toggleLinkedSession: "Linked Session"
        case .toggleSetlistPanel: "Setlist Panel"
        case .nextSetlistItem: "Next Set Item"
        case .previousSetlistItem: "Previous Set Item"
        case .togglePerformanceLock: "Performance Lock"
        }
    }

    public var systemImage: String {
        switch self {
        case .none: "minus.circle"
        case .nextPage: "arrow.right.circle"
        case .previousPage: "arrow.left.circle"
        case .playPausePlayback: "playpause.circle"
        case .stopPlayback: "stop.circle"
        case .togglePlaybackPanel: "waveform"
        case .openQuickJump: "list.bullet.rectangle.portrait"
        case .toggleAnnotationMode: "pencil.tip.crop.circle"
        case .toggleLinkedSession: "dot.radiowaves.left.and.right"
        case .toggleSetlistPanel: "music.note.list"
        case .nextSetlistItem: "forward.end.circle"
        case .previousSetlistItem: "backward.end.circle"
        case .togglePerformanceLock: "lock.shield"
        }
    }

    public var propagatesToLinkedSession: Bool {
        switch self {
        case .playPausePlayback, .stopPlayback, .nextSetlistItem, .previousSetlistItem, .togglePerformanceLock:
            return true
        default:
            return false
        }
    }
}

public enum PedalInputRole: String, Codable, CaseIterable, Identifiable, Sendable {
    case left
    case right
    case center
    case auxiliary

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .left: "Left Pedal"
        case .right: "Right Pedal"
        case .center: "Center Pedal"
        case .auxiliary: "Aux Pedal"
        }
    }
}

public enum KeyboardControlKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case rightArrow
    case leftArrow
    case upArrow
    case downArrow
    case space
    case tab
    case returnKey

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .rightArrow: "Right Arrow"
        case .leftArrow: "Left Arrow"
        case .upArrow: "Up Arrow"
        case .downArrow: "Down Arrow"
        case .space: "Space"
        case .tab: "Tab"
        case .returnKey: "Return"
        }
    }

    public static func fromLegacyKeyEquivalent(_ keyEquivalent: String) -> KeyboardControlKey? {
        switch keyEquivalent {
        case " ", UIKeyEquivalent.space.rawValue:
            return .space
        case UIKeyEquivalent.rightArrow.rawValue:
            return .rightArrow
        case UIKeyEquivalent.leftArrow.rawValue:
            return .leftArrow
        case UIKeyEquivalent.upArrow.rawValue:
            return .upArrow
        case UIKeyEquivalent.downArrow.rawValue:
            return .downArrow
        case UIKeyEquivalent.tab.rawValue:
            return .tab
        case UIKeyEquivalent.returnKey.rawValue:
            return .returnKey
        default:
            return nil
        }
    }
}

public enum MIDIBindingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case noteOn
    case controlChange

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .noteOn: "Note On"
        case .controlChange: "Control Change"
        }
    }
}

public struct PedalControlMapping: Codable, Sendable, Equatable, Identifiable {
    public var role: PedalInputRole
    public var action: ExternalControlAction

    public var id: String { role.rawValue }

    public init(role: PedalInputRole, action: ExternalControlAction) {
        self.role = role
        self.action = action
    }
}

public struct KeyboardControlMapping: Codable, Sendable, Equatable, Identifiable {
    public var key: KeyboardControlKey
    public var action: ExternalControlAction

    public var id: String { key.rawValue }

    public init(key: KeyboardControlKey, action: ExternalControlAction) {
        self.key = key
        self.action = action
    }
}

public struct MIDIControlMapping: Codable, Sendable, Equatable, Identifiable {
    public var type: MIDIBindingType
    public var value: Int
    public var channel: Int?
    public var action: ExternalControlAction

    public var id: String {
        "\(type.rawValue)-\(value)-\(channel ?? -1)"
    }

    public init(type: MIDIBindingType, value: Int, channel: Int? = nil, action: ExternalControlAction) {
        self.type = type
        self.value = max(0, min(value, 127))
        self.channel = channel
        self.action = action
    }
}

public struct ExternalControlProfile: Codable, Sendable, Equatable {
    public var pedalControlEnabled: Bool
    public var midiControlEnabled: Bool
    public var linkedCommandPropagationEnabled: Bool
    public var pedalMappings: [PedalControlMapping]
    public var keyboardMappings: [KeyboardControlMapping]
    public var midiMappings: [MIDIControlMapping]

    public init(
        pedalControlEnabled: Bool = true,
        midiControlEnabled: Bool = true,
        linkedCommandPropagationEnabled: Bool = true,
        pedalMappings: [PedalControlMapping] = [],
        keyboardMappings: [KeyboardControlMapping] = [],
        midiMappings: [MIDIControlMapping] = []
    ) {
        self.pedalControlEnabled = pedalControlEnabled
        self.midiControlEnabled = midiControlEnabled
        self.linkedCommandPropagationEnabled = linkedCommandPropagationEnabled
        self.pedalMappings = pedalMappings
        self.keyboardMappings = keyboardMappings
        self.midiMappings = midiMappings
    }

    public static let stageDefault = ExternalControlProfile(
        pedalControlEnabled: true,
        midiControlEnabled: true,
        linkedCommandPropagationEnabled: true,
        pedalMappings: [
            PedalControlMapping(role: .left, action: .previousPage),
            PedalControlMapping(role: .right, action: .nextPage),
            PedalControlMapping(role: .center, action: .playPausePlayback),
            PedalControlMapping(role: .auxiliary, action: .togglePerformanceLock)
        ],
        keyboardMappings: [
            KeyboardControlMapping(key: .rightArrow, action: .nextPage),
            KeyboardControlMapping(key: .leftArrow, action: .previousPage),
            KeyboardControlMapping(key: .upArrow, action: .previousPage),
            KeyboardControlMapping(key: .downArrow, action: .nextPage),
            KeyboardControlMapping(key: .space, action: .nextPage),
            KeyboardControlMapping(key: .tab, action: .openQuickJump),
            KeyboardControlMapping(key: .returnKey, action: .playPausePlayback)
        ],
        midiMappings: [
            MIDIControlMapping(type: .controlChange, value: 64, action: .nextPage),
            MIDIControlMapping(type: .controlChange, value: 67, action: .previousPage),
            MIDIControlMapping(type: .noteOn, value: 60, action: .playPausePlayback),
            MIDIControlMapping(type: .noteOn, value: 59, action: .togglePerformanceLock)
        ]
    )

    public func action(for pedalRole: PedalInputRole) -> ExternalControlAction {
        pedalMappings.first(where: { $0.role == pedalRole })?.action ?? .none
    }

    public func action(for key: KeyboardControlKey) -> ExternalControlAction {
        keyboardMappings.first(where: { $0.key == key })?.action ?? .none
    }

    public func action(for type: MIDIBindingType, value: Int, channel: Int?) -> ExternalControlAction {
        midiMappings.first(where: {
            $0.type == type &&
            $0.value == value &&
            ($0.channel == nil || $0.channel == channel)
        })?.action ?? .none
    }

    public mutating func setPedalAction(_ action: ExternalControlAction, for role: PedalInputRole) {
        if let index = pedalMappings.firstIndex(where: { $0.role == role }) {
            pedalMappings[index].action = action
        } else {
            pedalMappings.append(PedalControlMapping(role: role, action: action))
        }
    }

    public mutating func setKeyboardAction(_ action: ExternalControlAction, for key: KeyboardControlKey) {
        if let index = keyboardMappings.firstIndex(where: { $0.key == key }) {
            keyboardMappings[index].action = action
        } else {
            keyboardMappings.append(KeyboardControlMapping(key: key, action: action))
        }
    }
}

public enum ExternalControlProfileStorage {
    public static let defaultsKey = "external-control-profile"
}

private enum UIKeyEquivalent: String {
    case rightArrow = "\u{F703}"
    case leftArrow = "\u{F702}"
    case upArrow = "\u{F700}"
    case downArrow = "\u{F701}"
    case space = " "
    case tab = "\t"
    case returnKey = "\r"
}
