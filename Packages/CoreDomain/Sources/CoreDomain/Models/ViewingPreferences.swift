import Foundation

public enum DisplayMode: String, Codable, Sendable {
    case singlePage
    case verticalScroll
    case horizontalPaged
    case twoPageSpread
}

public enum PaperTheme: String, Codable, Sendable {
    case light       // white paper
    case sepia        // cream / warm paper
    case warm         // warmer off-white
    case highContrast // high-contrast light paper (slightly gray background, very dark text)

    // Legacy case kept for data compatibility
    case dark
}

public struct ViewingPreferences: Codable, Sendable {
    public var displayMode: DisplayMode
    public var paperTheme: PaperTheme
    public var zoomLevel: Double
    public var isCropMarginsEnabled: Bool

    public init(
        displayMode: DisplayMode = .singlePage,
        paperTheme: PaperTheme = .light,
        zoomLevel: Double = 1.0,
        isCropMarginsEnabled: Bool = false
    ) {
        self.displayMode = displayMode
        self.paperTheme = paperTheme
        self.zoomLevel = zoomLevel
        self.isCropMarginsEnabled = isCropMarginsEnabled
    }
}
