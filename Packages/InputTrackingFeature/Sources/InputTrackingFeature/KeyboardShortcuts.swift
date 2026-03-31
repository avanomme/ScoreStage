import SwiftUI
import CoreDomain

/// View modifier that handles keyboard shortcuts for page turning and common reader actions.
public struct ReaderKeyboardShortcuts: ViewModifier {
    let onKeyboardAction: (KeyboardControlKey) -> Void

    public init(onKeyboardAction: @escaping (KeyboardControlKey) -> Void) {
        self.onKeyboardAction = onKeyboardAction
    }

    public func body(content: Content) -> some View {
        content
            .keyboardShortcut(.rightArrow, modifiers: [])
            .onKeyPress(.rightArrow) { onKeyboardAction(.rightArrow); return .handled }
            .onKeyPress(.leftArrow) { onKeyboardAction(.leftArrow); return .handled }
            .onKeyPress(.space) { onKeyboardAction(.space); return .handled }
            .onKeyPress(.downArrow) { onKeyboardAction(.downArrow); return .handled }
            .onKeyPress(.upArrow) { onKeyboardAction(.upArrow); return .handled }
            .onKeyPress(.tab) { onKeyboardAction(.tab); return .handled }
            .onKeyPress(.return) { onKeyboardAction(.returnKey); return .handled }
    }
}

extension View {
    public func readerKeyboardShortcuts(onKeyboardAction: @escaping (KeyboardControlKey) -> Void) -> some View {
        modifier(ReaderKeyboardShortcuts(onKeyboardAction: onKeyboardAction))
    }
}
