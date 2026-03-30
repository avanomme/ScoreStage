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

public enum PageTurnBehavior: String, Codable, Sendable {
    case standard
    case halfPage
    case safePerformance
}

public struct NormalizedPageInsets: Codable, Sendable, Equatable {
    public var top: Double
    public var leading: Double
    public var bottom: Double
    public var trailing: Double

    public init(
        top: Double = 0,
        leading: Double = 0,
        bottom: Double = 0,
        trailing: Double = 0
    ) {
        self.top = max(0, min(top, 0.3))
        self.leading = max(0, min(leading, 0.3))
        self.bottom = max(0, min(bottom, 0.3))
        self.trailing = max(0, min(trailing, 0.3))
    }

    public static let none = NormalizedPageInsets()
    public static let narrow = NormalizedPageInsets(top: 0.02, leading: 0.02, bottom: 0.02, trailing: 0.02)
    public static let medium = NormalizedPageInsets(top: 0.05, leading: 0.04, bottom: 0.05, trailing: 0.04)
    public static let aggressive = NormalizedPageInsets(top: 0.08, leading: 0.06, bottom: 0.08, trailing: 0.06)
}

public struct ViewingPreferences: Codable, Sendable {
    public var displayMode: DisplayMode
    public var paperTheme: PaperTheme
    public var zoomLevel: Double
    public var isCropMarginsEnabled: Bool
    public var cropInsets: NormalizedPageInsets
    public var brightnessAdjustment: Double
    public var contrastAdjustment: Double
    public var pageTurnBehavior: PageTurnBehavior

    public init(
        displayMode: DisplayMode = .singlePage,
        paperTheme: PaperTheme = .light,
        zoomLevel: Double = 1.0,
        isCropMarginsEnabled: Bool = false,
        cropInsets: NormalizedPageInsets = .none,
        brightnessAdjustment: Double = 0,
        contrastAdjustment: Double = 1.0,
        pageTurnBehavior: PageTurnBehavior = .standard
    ) {
        self.displayMode = displayMode
        self.paperTheme = paperTheme
        self.zoomLevel = zoomLevel
        self.isCropMarginsEnabled = isCropMarginsEnabled
        self.cropInsets = cropInsets
        self.brightnessAdjustment = brightnessAdjustment
        self.contrastAdjustment = contrastAdjustment
        self.pageTurnBehavior = pageTurnBehavior
    }

    enum CodingKeys: String, CodingKey {
        case displayMode
        case paperTheme
        case zoomLevel
        case isCropMarginsEnabled
        case cropInsets
        case brightnessAdjustment
        case contrastAdjustment
        case pageTurnBehavior
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .singlePage
        paperTheme = try container.decodeIfPresent(PaperTheme.self, forKey: .paperTheme) ?? .light
        zoomLevel = try container.decodeIfPresent(Double.self, forKey: .zoomLevel) ?? 1.0
        isCropMarginsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCropMarginsEnabled) ?? false
        cropInsets = try container.decodeIfPresent(NormalizedPageInsets.self, forKey: .cropInsets) ?? .none
        brightnessAdjustment = try container.decodeIfPresent(Double.self, forKey: .brightnessAdjustment) ?? 0
        contrastAdjustment = try container.decodeIfPresent(Double.self, forKey: .contrastAdjustment) ?? 1.0
        pageTurnBehavior = try container.decodeIfPresent(PageTurnBehavior.self, forKey: .pageTurnBehavior) ?? .standard
    }
}
