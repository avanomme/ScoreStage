import Foundation
import CoreDomain
import Combine

/// Unified page turn service handling keyboard, pedal, and gesture triggers.
public final class PageTurnService: ObservableObject, @unchecked Sendable {
    public enum TurnDirection: Equatable {
        case forward
        case backward
    }

    public enum TurnTrigger: Equatable {
        case tap
        case swipe
        case keyboard
        case pedal
        case midi
        case headMovement
        case eyeGaze
        case linkedDevice
    }

    @Published public var lastTurnDirection: TurnDirection?
    @Published public var lastTrigger: TurnTrigger?
    @Published public var controlProfile: ExternalControlProfile = .stageDefault
    @Published public var lastAction: ExternalControlAction = .none

    // Configuration
    @Published public var tapZoneRightWidth: Double = 0.5
    @Published public var isHalfPageTurnEnabled: Bool = false
    @Published public var isSwipeEnabled: Bool = true
    @Published public var isPedalEnabled: Bool = true

    private var onPageTurn: ((TurnDirection) -> Void)?
    private var onAction: ((ExternalControlAction, TurnTrigger) -> Void)?

    public init() {}

    public func setHandler(_ handler: @escaping (TurnDirection) -> Void) {
        self.onPageTurn = handler
    }

    public func setActionHandler(_ handler: @escaping (ExternalControlAction, TurnTrigger) -> Void) {
        self.onAction = handler
    }

    public func triggerTurn(_ direction: TurnDirection, from trigger: TurnTrigger) {
        lastTurnDirection = direction
        lastTrigger = trigger
        lastAction = direction == .forward ? .nextPage : .previousPage
        onPageTurn?(direction)
    }

    public func handleKeyboardKey(_ key: KeyboardControlKey) -> Bool {
        perform(controlProfile.action(for: key), from: .keyboard)
    }

    public func handleKeyPress(_ keyEquivalent: String) -> Bool {
        guard let key = KeyboardControlKey.fromLegacyKeyEquivalent(keyEquivalent) else { return false }
        return handleKeyboardKey(key)
    }

    public func handlePedalInput(_ role: PedalInputRole) -> Bool {
        guard controlProfile.pedalControlEnabled, isPedalEnabled else { return false }
        return perform(controlProfile.action(for: role), from: .pedal)
    }

    public func handleMIDIInput(type: MIDIBindingType, value: Int, channel: Int?) -> Bool {
        guard controlProfile.midiControlEnabled else { return false }
        return perform(controlProfile.action(for: type, value: value, channel: channel), from: .midi)
    }

    @discardableResult
    public func perform(_ action: ExternalControlAction, from trigger: TurnTrigger) -> Bool {
        guard action != .none else { return false }
        lastAction = action
        lastTrigger = trigger

        switch action {
        case .nextPage:
            triggerTurn(.forward, from: trigger)
        case .previousPage:
            triggerTurn(.backward, from: trigger)
        default:
            onAction?(action, trigger)
        }

        return true
    }
}
