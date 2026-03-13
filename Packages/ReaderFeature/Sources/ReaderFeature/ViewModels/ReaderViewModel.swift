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
    public var renderedPages: [Int: CGImage] = [:]
    public var isLoading: Bool = true

    public init(score: Score, renderService: PDFRenderService = PDFRenderService()) {
        self.score = score
        self.renderService = renderService
        if let prefs = score.viewingPreferences {
            self.displayMode = prefs.displayMode
            self.paperTheme = prefs.paperTheme
            self.zoomScale = prefs.zoomLevel
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
        await renderCurrentPage()
        renderService.prefetchPages(around: index)
    }

    public func nextPage() async {
        let step = displayMode == .twoPageSpread ? 2 : 1
        await goToPage(min(currentPageIndex + step, pageCount - 1))
    }

    public func previousPage() async {
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
        renderService.pageSize(at: index)
    }

    public var paperBackgroundColor: Color {
        switch paperTheme {
        case .light: .white
        case .dark: Color(white: 0.12)
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.87)
        case .highContrast: .black
        }
    }

    public func updateViewingPreferences() {
        score.viewingPreferences = ViewingPreferences(
            displayMode: displayMode,
            paperTheme: paperTheme,
            zoomLevel: zoomScale
        )
    }

    public func markAsOpened() {
        score.lastOpenedAt = Date()
    }
}
