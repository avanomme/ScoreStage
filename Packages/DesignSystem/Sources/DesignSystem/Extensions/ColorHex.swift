import SwiftUI
import CoreGraphics

extension Color {
    /// Create a Color from a hex string like "#FF0000" or "FF0000".
    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b, a: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
            a = 1.0
        case 8:
            r = Double((int >> 24) & 0xFF) / 255.0
            g = Double((int >> 16) & 0xFF) / 255.0
            b = Double((int >> 8) & 0xFF) / 255.0
            a = Double(int & 0xFF) / 255.0
        default:
            r = 0; g = 0; b = 0; a = 1
        }
        self.init(red: r, green: g, blue: b, opacity: a)
    }

    /// Convert a Color to a hex string like "#1C1C1E".
    public var hexString: String {
        guard let cgColor = cgColor,
              let components = cgColor.components,
              components.count >= 3 else {
            return "#000000"
        }
        let r = Int(max(0, min(255, components[0] * 255)))
        let g = Int(max(0, min(255, components[1] * 255)))
        let b = Int(max(0, min(255, components[2] * 255)))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    /// Access the underlying CGColor.
    private var cgColor: CGColor? {
        #if canImport(UIKit)
        return UIColor(self).cgColor
        #elseif canImport(AppKit)
        return NSColor(self).cgColor
        #else
        return nil
        #endif
    }
}
