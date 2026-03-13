import SwiftUI

/// View modifier that handles keyboard shortcuts for page turning and common reader actions.
public struct ReaderKeyboardShortcuts: ViewModifier {
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onTogglePerformanceMode: (() -> Void)?

    public init(
        onNextPage: @escaping () -> Void,
        onPreviousPage: @escaping () -> Void,
        onTogglePerformanceMode: (() -> Void)? = nil
    ) {
        self.onNextPage = onNextPage
        self.onPreviousPage = onPreviousPage
        self.onTogglePerformanceMode = onTogglePerformanceMode
    }

    public func body(content: Content) -> some View {
        content
            .keyboardShortcut(.rightArrow, modifiers: [])
            .onKeyPress(.rightArrow) { onNextPage(); return .handled }
            .onKeyPress(.leftArrow) { onPreviousPage(); return .handled }
            .onKeyPress(.space) { onNextPage(); return .handled }
            .onKeyPress(.downArrow) { onNextPage(); return .handled }
            .onKeyPress(.upArrow) { onPreviousPage(); return .handled }
    }
}

extension View {
    public func readerKeyboardShortcuts(
        onNextPage: @escaping () -> Void,
        onPreviousPage: @escaping () -> Void,
        onTogglePerformanceMode: (() -> Void)? = nil
    ) -> some View {
        modifier(ReaderKeyboardShortcuts(
            onNextPage: onNextPage,
            onPreviousPage: onPreviousPage,
            onTogglePerformanceMode: onTogglePerformanceMode
        ))
    }
}
