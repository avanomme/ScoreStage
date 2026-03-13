import Foundation
import CoreDomain
import Combine

/// Unified page turn service handling keyboard, pedal, and gesture triggers.
public final class PageTurnService: ObservableObject, @unchecked Sendable {
    public enum TurnDirection {
        case forward
        case backward
    }

    public enum TurnTrigger {
        case tap
        case swipe
        case keyboard
        case pedal
    }

    @Published public var lastTurnDirection: TurnDirection?
    @Published public var lastTrigger: TurnTrigger?

    // Configuration
    @Published public var tapZoneRightWidth: Double = 0.5
    @Published public var isHalfPageTurnEnabled: Bool = false
    @Published public var isSwipeEnabled: Bool = true
    @Published public var isPedalEnabled: Bool = true

    private var onPageTurn: ((TurnDirection) -> Void)?

    public init() {}

    public func setHandler(_ handler: @escaping (TurnDirection) -> Void) {
        self.onPageTurn = handler
    }

    public func triggerTurn(_ direction: TurnDirection, from trigger: TurnTrigger) {
        lastTurnDirection = direction
        lastTrigger = trigger
        onPageTurn?(direction)
    }

    /// Handle a keyboard event for page turning.
    /// Returns true if the key was consumed.
    public func handleKeyPress(_ keyEquivalent: String) -> Bool {
        switch keyEquivalent {
        case " ", UIKeyEquivalents.rightArrow, UIKeyEquivalents.pageDown:
            triggerTurn(.forward, from: .keyboard)
            return true
        case UIKeyEquivalents.leftArrow, UIKeyEquivalents.pageUp:
            triggerTurn(.backward, from: .keyboard)
            return true
        default:
            return false
        }
    }
}

// Platform-agnostic key equivalents
enum UIKeyEquivalents {
    static let rightArrow = "\u{F703}"
    static let leftArrow = "\u{F702}"
    static let pageDown = "\u{F72D}"
    static let pageUp = "\u{F72C}"
}
