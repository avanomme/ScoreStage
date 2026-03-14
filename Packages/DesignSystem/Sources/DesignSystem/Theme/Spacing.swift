import SwiftUI

// MARK: - Spacing System (from ui-design-spec.md Section D)
// Base unit: 4pt. All values are multiples of 4.

public enum ASSpacing {
    public static let xxs: CGFloat = 2    // half-unit, tight icon gaps only
    public static let xs: CGFloat = 4     // base unit
    public static let sm: CGFloat = 8     // compact spacing
    public static let md: CGFloat = 12    // standard element spacing
    public static let lg: CGFloat = 16    // section element spacing
    public static let xl: CGFloat = 24    // section spacing
    public static let xxl: CGFloat = 32   // major section breaks
    public static let xxxl: CGFloat = 48  // environment-level spacing

    // Screen margins
    public static let cardPadding: CGFloat = 16
    public static let screenPadding: CGFloat = 20
    public static let sectionSpacing: CGFloat = 32

    // Component spacing
    public static let cardGap: CGFloat = 20
    public static let sectionTitleGap: CGFloat = 12
    public static let toolbarItemSpacing: CGFloat = 8
    public static let inspectorLabelGap: CGFloat = 4
    public static let inspectorRowGap: CGFloat = 14
    public static let inspectorSectionGap: CGFloat = 24
}

// MARK: - Corner Radii (from spec Section D.4)

public enum ASRadius {
    public static let xs: CGFloat = 4     // small badges, tiny elements
    public static let sm: CGFloat = 6     // tool buttons, chips
    public static let md: CGFloat = 10    // buttons, text fields
    public static let lg: CGFloat = 14    // cards, panels
    public static let xl: CGFloat = 20    // floating overlays, modals
    public static let card: CGFloat = 12  // score cover cards
    public static let sheet: CGFloat = 24 // bottom sheets, floating palettes
}
