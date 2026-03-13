import SwiftUI

public enum ASTypography {
    // MARK: - Display
    public static let displayLarge = Font.system(size: 34, weight: .bold, design: .serif)
    public static let displayMedium = Font.system(size: 28, weight: .bold, design: .serif)

    // MARK: - Headings
    public static let heading1 = Font.system(size: 24, weight: .semibold, design: .default)
    public static let heading2 = Font.system(size: 20, weight: .semibold, design: .default)
    public static let heading3 = Font.system(size: 17, weight: .semibold, design: .default)

    // MARK: - Body
    public static let bodyLarge = Font.system(size: 17, weight: .regular, design: .default)
    public static let body = Font.system(size: 15, weight: .regular, design: .default)
    public static let bodySmall = Font.system(size: 13, weight: .regular, design: .default)

    // MARK: - Labels
    public static let label = Font.system(size: 13, weight: .medium, design: .default)
    public static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)

    // MARK: - Captions
    public static let caption = Font.system(size: 12, weight: .regular, design: .default)
    public static let captionSmall = Font.system(size: 10, weight: .regular, design: .default)

    // MARK: - Monospace (for musical/technical data)
    public static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    public static let monoSmall = Font.system(size: 12, weight: .regular, design: .monospaced)
}
