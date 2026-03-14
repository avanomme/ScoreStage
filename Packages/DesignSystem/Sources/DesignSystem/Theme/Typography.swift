import SwiftUI

// MARK: - Typography System (from ui-design-spec.md Section C)
//
// Serif = ONLY for score titles in library grid, display headings, app title.
// Uppercase tracking (0.3–0.5pt) ONLY for inspector section labels, tab labels, badges.

public enum ASTypography {

    // MARK: - Display (Library headers, hero text — serif)

    /// 38pt bold serif, -0.5pt tracking
    public static let displayLarge = Font.system(size: 38, weight: .bold, design: .serif)
    /// 30pt bold serif, -0.3pt tracking
    public static let displayMedium = Font.system(size: 30, weight: .bold, design: .serif)
    /// 24pt semibold serif, -0.2pt tracking
    public static let displaySmall = Font.system(size: 24, weight: .semibold, design: .serif)

    // MARK: - Headings (Section headers, panel titles)

    /// 22pt semibold
    public static let heading1 = Font.system(size: 22, weight: .semibold)
    /// 18pt semibold
    public static let heading2 = Font.system(size: 18, weight: .semibold)
    /// 15pt semibold
    public static let heading3 = Font.system(size: 15, weight: .semibold)

    // MARK: - Body (Content text, descriptions)

    /// 17pt regular
    public static let bodyLarge = Font.system(size: 17, weight: .regular)
    /// 15pt regular
    public static let body = Font.system(size: 15, weight: .regular)
    /// 13pt regular
    public static let bodySmall = Font.system(size: 13, weight: .regular)

    // MARK: - Labels (UI controls, metadata keys)

    /// 13pt medium, tracking +0.3pt
    public static let label = Font.system(size: 13, weight: .medium)
    /// 11pt medium, tracking +0.4pt
    public static let labelSmall = Font.system(size: 11, weight: .medium)
    /// 10pt semibold, tracking +0.5pt — for section headers in inspector
    public static let labelMicro = Font.system(size: 10, weight: .semibold)

    // MARK: - Captions (Timestamps, tertiary info)

    /// 12pt regular
    public static let caption = Font.system(size: 12, weight: .regular)
    /// 10pt regular
    public static let captionSmall = Font.system(size: 10, weight: .regular)

    // MARK: - Monospaced (Page numbers, time codes, measure numbers)

    /// 14pt regular mono
    public static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    /// 12pt medium mono
    public static let monoSmall = Font.system(size: 12, weight: .medium, design: .monospaced)
    /// 10pt medium mono, tracking +0.3pt
    public static let monoMicro = Font.system(size: 10, weight: .medium, design: .monospaced)

    // MARK: - Score Card Typography

    /// 11pt medium serif — for score titles on cover cards
    public static let cardTitle = Font.system(size: 11, weight: .medium, design: .serif)
    /// 9pt regular — for composer on cover cards
    public static let cardSubtitle = Font.system(size: 9, weight: .regular)
    /// 13pt medium — for title below card
    public static let cardMetaTitle = Font.system(size: 13, weight: .medium)
    /// 11pt regular — for composer below card
    public static let cardMetaSubtitle = Font.system(size: 11, weight: .regular)
}
