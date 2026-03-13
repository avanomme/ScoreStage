import Foundation

public enum DisplayMode: String, Codable, Sendable {
    case singlePage
    case verticalScroll
    case horizontalPaged
    case twoPageSpread
}

public enum PaperTheme: String, Codable, Sendable {
    case light
    case dark
    case sepia
    case highContrast
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
