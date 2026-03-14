import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Color Tokens (from ui-design-spec.md)

public enum ASColors {

    // MARK: - Brand Accent (#D55D7A rose copper)

    public static let accent = Color("AccentColor", bundle: .main)
    /// Rose copper — RGB(213, 93, 122)
    public static let accentFallback = Color(red: 213/255, green: 93/255, blue: 122/255)
    /// Lighter rose for hover — RGB(224, 110, 138)
    public static let accentHover = Color(red: 224/255, green: 110/255, blue: 138/255)
    /// Deeper rose for pressed — RGB(184, 77, 104)
    public static let accentPressed = Color(red: 184/255, green: 77/255, blue: 104/255)
    /// Accent at 12% for subtle backgrounds
    public static let accentSubtle = Color(red: 213/255, green: 93/255, blue: 122/255).opacity(0.12)
    /// Accent at 6% for hover surfaces
    public static let accentMuted = Color(red: 213/255, green: 93/255, blue: 122/255).opacity(0.06)

    // MARK: - Dark Chrome (DAW-style, Library/Settings/App Shell)

    /// #1A1A1E — deepest surface (window bg)
    public static let chromeBgDark = Color(red: 0x1A/255, green: 0x1A/255, blue: 0x1E/255)
    /// #232328 — primary panels, sidebar bg
    public static let chromeSurfaceDark = Color(red: 0x23/255, green: 0x23/255, blue: 0x28/255)
    /// #2C2C32 — cards, elevated content
    public static let chromeSurfaceElevatedDark = Color(red: 0x2C/255, green: 0x2C/255, blue: 0x32/255)
    /// #35353C — hover state on surfaces
    public static let chromeSurfaceHoverDark = Color(red: 0x35/255, green: 0x35/255, blue: 0x3C/255)
    /// #3E3E46 — selected sidebar item bg
    public static let chromeSurfaceSelectedDark = Color(red: 0x3E/255, green: 0x3E/255, blue: 0x46/255)
    /// #3A3A42 — subtle dividers, 1px borders
    public static let chromeBorderDark = Color(red: 0x3A/255, green: 0x3A/255, blue: 0x42/255)
    /// #4A4A54 — stronger separators
    public static let chromeBorderStrongDark = Color(red: 0x4A/255, green: 0x4A/255, blue: 0x54/255)

    // MARK: - Light Chrome

    /// #F2F2F7 — light mode window bg
    public static let chromeBgLight = Color(red: 0xF2/255, green: 0xF2/255, blue: 0xF7/255)
    /// #FFFFFF — light mode panels
    public static let chromeSurfaceLight = Color.white
    /// #E8E8ED — light mode hover
    public static let chromeSurfaceHoverLight = Color(red: 0xE8/255, green: 0xE8/255, blue: 0xED/255)
    /// #D1D1D6 — light mode borders
    public static let chromeBorderLight = Color(red: 0xD1/255, green: 0xD1/255, blue: 0xD6/255)

    // MARK: - Adaptive Chrome (resolves to dark/light based on colorScheme)
    // Uses direct color values since we force dark mode for the DAW aesthetic.
    // For views that need to adapt, use @Environment(\.colorScheme).

    /// Window/app background — dark: #1A1A1E, light: #F2F2F7
    public static let chromeBackground = chromeBgDark
    /// Panel/sidebar background — dark: #232328, light: #FFFFFF
    public static let chromeSurface = chromeSurfaceDark
    /// Elevated cards/popovers — dark: #2C2C32
    public static let chromeSurfaceElevated = chromeSurfaceElevatedDark
    /// Hover state — dark: #35353C
    public static let chromeSurfaceHover = chromeSurfaceHoverDark
    /// Selected item — dark: #3E3E46
    public static let chromeSurfaceSelected = chromeSurfaceSelectedDark
    /// Border — dark: #3A3A42
    public static let chromeBorder = chromeBorderDark
    /// Strong border — dark: #4A4A54
    public static let chromeBorderStrong = chromeBorderStrongDark

    // MARK: - Text Colors (Dark Chrome Context)

    /// #F0F0F2 — headings, primary content
    public static let textPrimaryDark = Color(red: 0xF0/255, green: 0xF0/255, blue: 0xF2/255)
    /// #A0A0A8 — metadata, labels
    public static let textSecondaryDark = Color(red: 0xA0/255, green: 0xA0/255, blue: 0xA8/255)
    /// #6E6E78 — timestamps, hints
    public static let textTertiaryDark = Color(red: 0x6E/255, green: 0x6E/255, blue: 0x78/255)
    /// #4A4A52 — disabled
    public static let textDisabledDark = Color(red: 0x4A/255, green: 0x4A/255, blue: 0x52/255)

    // MARK: - Text Colors (Light Chrome Context)

    /// #1C1C1E — headings, titles
    public static let textPrimaryLight = Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
    /// #6E6E78 — metadata, labels
    public static let textSecondaryLight = Color(red: 0x6E/255, green: 0x6E/255, blue: 0x78/255)
    /// #AEAEB2 — hints, timestamps
    public static let textTertiaryLight = Color(red: 0xAE/255, green: 0xAE/255, blue: 0xB2/255)

    // MARK: - Semantic Text (use .primary/.secondary for adaptive)

    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let tertiaryText = Color(red: 0x6E/255, green: 0x6E/255, blue: 0x78/255)

    // MARK: - Paper Themes (ALWAYS light — musicians expect printed-notation contrast)

    /// #FFFFFF — pure white, highest contrast
    public static let paperWhite = Color.white
    /// #FAF5E6 — warm cream, reduces eye strain
    public static let paperCream = Color(red: 0xFA/255, green: 0xF5/255, blue: 0xE6/255)
    /// #F5EDE0 — warm sepia-adjacent
    public static let paperWarm = Color(red: 0xF5/255, green: 0xED/255, blue: 0xE0/255)
    /// #F2EBD9 — aged parchment feel
    public static let paperParchment = Color(red: 0xF2/255, green: 0xEB/255, blue: 0xD9/255)
    /// #F0F0F0 — very light gray, maximum sharpness
    public static let paperHighContrast = Color(red: 0xF0/255, green: 0xF0/255, blue: 0xF0/255)

    // MARK: - Score Card Gradients

    /// Dark mode card gradient top
    public static let cardGradientTopDark = Color(red: 0x2A/255, green: 0x2A/255, blue: 0x30/255)
    /// Dark mode card gradient bottom
    public static let cardGradientBottomDark = Color(red: 0x22/255, green: 0x22/255, blue: 0x28/255)
    /// Light mode card gradient top
    public static let cardGradientTopLight = Color(red: 0xF0/255, green: 0xF0/255, blue: 0xF2/255)
    /// Light mode card gradient bottom
    public static let cardGradientBottomLight = Color(red: 0xE4/255, green: 0xE4/255, blue: 0xE8/255)

    // MARK: - Status

    /// #34C759
    public static let success = Color(red: 0x34/255, green: 0xC7/255, blue: 0x59/255)
    /// #FF9500
    public static let warning = Color(red: 0xFF/255, green: 0x95/255, blue: 0x00/255)
    /// #FF3B30
    public static let error = Color(red: 0xFF/255, green: 0x3B/255, blue: 0x30/255)
    /// #5AC8FA
    public static let info = Color(red: 0x5A/255, green: 0xC8/255, blue: 0xFA/255)

    // MARK: - Annotation Palette (tuned for legibility on paper)

    /// #1C1C1E — primary markup
    public static let annotationBlack = Color(red: 0x1C/255, green: 0x1C/255, blue: 0x1E/255)
    /// #E63946 — critical markings, corrections
    public static let annotationRed = Color(red: 0xE6/255, green: 0x39/255, blue: 0x46/255)
    /// #3366E6 — fingering, technical notes
    public static let annotationBlue = Color(red: 0x33/255, green: 0x66/255, blue: 0xE6/255)
    /// #2D9E48 — phrasing, dynamics
    public static let annotationGreen = Color(red: 0x2D/255, green: 0x9E/255, blue: 0x48/255)
    /// #F0C800 — highlighting (used at 30% opacity)
    public static let annotationYellow = Color(red: 0xF0/255, green: 0xC8/255, blue: 0x00/255)
    /// #8B52CC — form analysis, structure
    public static let annotationPurple = Color(red: 0x8B/255, green: 0x52/255, blue: 0xCC/255)
    /// #E68A33 — bowings, articulation
    public static let annotationOrange = Color(red: 0xE6/255, green: 0x8A/255, blue: 0x33/255)
    /// #8B6914 — historical annotations
    public static let annotationBrown = Color(red: 0x8B/255, green: 0x69/255, blue: 0x14/255)

    public static let annotationPalette: [Color] = [
        annotationBlack, annotationRed, annotationBlue,
        annotationGreen, annotationYellow, annotationPurple,
        annotationOrange, annotationBrown
    ]

    // MARK: - Playback Cursor

    public static let cursorActive = Color(red: 213/255, green: 93/255, blue: 122/255).opacity(0.40)
    public static let cursorLine = Color(red: 213/255, green: 93/255, blue: 122/255).opacity(0.80)
    public static let cursorGlow = Color(red: 213/255, green: 93/255, blue: 122/255).opacity(0.15)
}
