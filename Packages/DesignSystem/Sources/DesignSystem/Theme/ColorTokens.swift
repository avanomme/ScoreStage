import SwiftUI

public enum ASColors {
    // MARK: - Brand
    public static let accent = Color("AccentColor", bundle: .main)
    public static let accentFallback = Color(red: 0.835, green: 0.365, blue: 0.478)

    // MARK: - Semantic
    public static let primaryText = Color.primary
    public static let secondaryText = Color.secondary
    public static let tertiaryText = Color(white: 0.55)

    // MARK: - Surfaces
    #if canImport(UIKit)
    public static let background = Color(uiColor: .systemBackground)
    public static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    public static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    public static let cardBackground = Color(uiColor: .systemBackground)
    #else
    public static let background = Color(nsColor: .windowBackgroundColor)
    public static let secondaryBackground = Color(nsColor: .controlBackgroundColor)
    public static let tertiaryBackground = Color(nsColor: .underPageBackgroundColor)
    public static let cardBackground = Color(nsColor: .windowBackgroundColor)
    #endif

    // MARK: - Paper Themes (always light — musicians expect printed-notation contrast)
    public static let paperWhite = Color.white
    public static let paperCream = Color(red: 0.98, green: 0.96, blue: 0.90)
    public static let paperWarm = Color(red: 0.96, green: 0.93, blue: 0.87)
    public static let paperHighContrast = Color(white: 0.94)

    // MARK: - Status
    public static let success = Color.green
    public static let warning = Color.orange
    public static let error = Color.red
    public static let info = Color.blue

    // MARK: - Annotation Palette
    public static let annotationRed = Color(red: 0.90, green: 0.22, blue: 0.21)
    public static let annotationBlue = Color(red: 0.20, green: 0.47, blue: 0.96)
    public static let annotationGreen = Color(red: 0.20, green: 0.78, blue: 0.35)
    public static let annotationYellow = Color(red: 1.0, green: 0.80, blue: 0.0)
    public static let annotationPurple = Color(red: 0.58, green: 0.32, blue: 0.87)
    public static let annotationBlack = Color.black

    public static let annotationPalette: [Color] = [
        annotationBlack, annotationRed, annotationBlue,
        annotationGreen, annotationYellow, annotationPurple
    ]
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
