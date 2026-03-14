// AccessibilityModifiers — Reusable accessibility modifiers for ScoreStage views.

import SwiftUI

// MARK: - Large Tap Target Modifier

/// Ensures a minimum 44×44pt tap target for accessibility compliance.
public struct LargeTapTarget: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Apply minimum 44×44pt tap target for accessibility.
    public func largeTapTarget() -> some View {
        modifier(LargeTapTarget())
    }
}

// MARK: - High Contrast Support

/// Applies high-contrast styling when the accessibility setting is enabled.
public struct HighContrastBorder: ViewModifier {
    @Environment(\.colorSchemeContrast) var contrast

    let cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if contrast == .increased {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.5), lineWidth: 1)
                    }
                }
            )
    }
}

extension View {
    /// Add a visible border when high contrast mode is enabled.
    public func highContrastBorder(cornerRadius: CGFloat = ASRadius.md) -> some View {
        modifier(HighContrastBorder(cornerRadius: cornerRadius))
    }
}

// MARK: - Score Reader Accessibility

/// Accessibility actions for the score reader (performance mode).
public struct ReaderAccessibilityActions: ViewModifier {
    let onNextPage: () -> Void
    let onPreviousPage: () -> Void
    let onToggleAnnotation: (() -> Void)?
    let currentPage: Int
    let totalPages: Int

    public func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Score Reader")
            .accessibilityValue("Page \(currentPage) of \(totalPages)")
            .accessibilityAction(named: "Next Page") { onNextPage() }
            .accessibilityAction(named: "Previous Page") { onPreviousPage() }
            .accessibilityAddTraits(.allowsDirectInteraction)
    }
}

extension View {
    /// Add VoiceOver accessibility actions for the score reader.
    public func readerAccessibility(
        currentPage: Int,
        totalPages: Int,
        onNextPage: @escaping () -> Void,
        onPreviousPage: @escaping () -> Void,
        onToggleAnnotation: (() -> Void)? = nil
    ) -> some View {
        modifier(ReaderAccessibilityActions(
            onNextPage: onNextPage,
            onPreviousPage: onPreviousPage,
            onToggleAnnotation: onToggleAnnotation,
            currentPage: currentPage,
            totalPages: totalPages
        ))
    }
}

// MARK: - Accessible Card

/// Makes a card VoiceOver-friendly with a combined label.
public struct AccessibleCard: ViewModifier {
    let label: String
    let hint: String
    let isButton: Bool

    public func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityAddTraits(isButton ? .isButton : [])
    }
}

extension View {
    /// Make a card accessible with a combined label for VoiceOver.
    public func accessibleCard(_ label: String, hint: String = "", isButton: Bool = true) -> some View {
        modifier(AccessibleCard(label: label, hint: hint, isButton: isButton))
    }
}

// MARK: - Reduce Motion

/// Disables animations when Reduce Motion is enabled.
public struct ReduceMotionAware: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    public func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: UUID())
    }
}

// MARK: - Dynamic Type Support

/// Scales icon size based on Dynamic Type settings.
public struct DynamicTypeIcon: ViewModifier {
    @ScaledMetric var scaledSize: CGFloat

    init(baseSize: CGFloat) {
        _scaledSize = ScaledMetric(wrappedValue: baseSize)
    }

    public func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize))
    }
}

extension View {
    /// Scale an icon based on Dynamic Type.
    public func dynamicTypeIcon(baseSize: CGFloat = 16) -> some View {
        modifier(DynamicTypeIcon(baseSize: baseSize))
    }
}
