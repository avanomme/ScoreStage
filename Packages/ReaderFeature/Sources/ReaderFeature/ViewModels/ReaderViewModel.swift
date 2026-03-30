import SwiftUI
import SwiftData
import CoreDomain

@MainActor
@Observable
public final class ReaderViewModel {
    public let score: Score
    public let renderService: PDFRenderService

    public var currentPageIndex: Int = 0
    public var displayMode: DisplayMode = .singlePage
    public var paperTheme: PaperTheme = .light
    public var isPerformanceMode: Bool = false
    public var zoomScale: CGFloat = 1.0
    public var cropInsets: NormalizedPageInsets = .none
    public var isCropMarginsEnabled = false
    public var brightnessAdjustment: Double = 0
    public var contrastAdjustment: Double = 1.0
    public var pageTurnBehavior: PageTurnBehavior = .standard
    public var showingLowerHalf = false
    public var renderedPages: [Int: CGImage] = [:]
    public var isLoading: Bool = true

    public init(score: Score, renderService: PDFRenderService = PDFRenderService()) {
        self.score = score
        self.renderService = renderService
        if let prefs = score.viewingPreferences {
            self.displayMode = prefs.displayMode
            self.paperTheme = prefs.paperTheme
            self.zoomScale = prefs.zoomLevel
            self.isCropMarginsEnabled = prefs.isCropMarginsEnabled
            self.cropInsets = prefs.cropInsets
            self.brightnessAdjustment = prefs.brightnessAdjustment
            self.contrastAdjustment = prefs.contrastAdjustment
            self.pageTurnBehavior = prefs.pageTurnBehavior
        }
    }

    public func loadDocument(from url: URL) async {
        isLoading = true
        _ = renderService.loadDocument(from: url)
        await renderCurrentPage()
        isLoading = false
    }

    public var pageCount: Int { renderService.pageCount }

    public func goToPage(_ index: Int) async {
        guard index >= 0 && index < pageCount else { return }
        currentPageIndex = index
        showingLowerHalf = false
        await renderCurrentPage()
        renderService.prefetchPages(around: index)
    }

    public func nextPage() async {
        if displayMode == .singlePage, pageTurnBehavior == .halfPage, !showingLowerHalf {
            showingLowerHalf = true
            return
        }
        let step = displayMode == .twoPageSpread ? 2 : 1
        await goToPage(min(currentPageIndex + step, pageCount - 1))
    }

    public func previousPage() async {
        if displayMode == .singlePage, pageTurnBehavior == .halfPage, showingLowerHalf {
            showingLowerHalf = false
            return
        }
        let step = displayMode == .twoPageSpread ? 2 : 1
        await goToPage(max(currentPageIndex - step, 0))
    }

    public func renderCurrentPage() async {
        let index = currentPageIndex
        if let img = await renderService.renderPage(at: index) {
            renderedPages[index] = img
        }
        // For two-page spread, also render the adjacent page
        if displayMode == .twoPageSpread, index + 1 < pageCount {
            if let img = await renderService.renderPage(at: index + 1) {
                renderedPages[index + 1] = img
            }
        }
    }

    public func pageSize(at index: Int) -> CGSize {
        let baseSize = renderService.pageSize(at: index)
        guard isCropMarginsEnabled else { return baseSize }

        let widthScale = max(0.2, 1 - cropInsets.leading - cropInsets.trailing)
        let heightScale = max(0.2, 1 - cropInsets.top - cropInsets.bottom)
        return CGSize(width: baseSize.width * widthScale, height: baseSize.height * heightScale)
    }

    /// Score paper is always light — musicians expect printed-notation contrast.
    public var paperBackgroundColor: Color {
        switch paperTheme {
        case .light: .white
        case .sepia: Color(red: 0.98, green: 0.96, blue: 0.90)    // cream
        case .warm: Color(red: 0.96, green: 0.93, blue: 0.87)     // warm off-white
        case .highContrast: Color(white: 0.94)                     // light gray
        case .dark: .white                                          // fallback to light
        }
    }

    public func updateViewingPreferences() {
        score.viewingPreferences = ViewingPreferences(
            displayMode: displayMode,
            paperTheme: paperTheme,
            zoomLevel: zoomScale,
            isCropMarginsEnabled: isCropMarginsEnabled,
            cropInsets: cropInsets,
            brightnessAdjustment: brightnessAdjustment,
            contrastAdjustment: contrastAdjustment,
            pageTurnBehavior: pageTurnBehavior
        )
    }

    public func markAsOpened() {
        score.lastOpenedAt = Date()
    }
}
