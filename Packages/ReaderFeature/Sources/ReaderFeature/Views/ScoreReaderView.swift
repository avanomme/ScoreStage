import SwiftUI
import CoreDomain
import DesignSystem

public struct ScoreReaderView: View {
    @State var viewModel: ReaderViewModel
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss

    public init(score: Score, fileURL: URL) {
        self._viewModel = State(initialValue: ReaderViewModel(score: score))
        self.fileURL = fileURL
    }

    public var body: some View {
        ZStack {
            viewModel.paperBackgroundColor
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading score...")
            } else {
                readerContent
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            viewModel.markAsOpened()
        }
        .toolbar {
            if !viewModel.isPerformanceMode {
                readerToolbar
            }
        }
        #if os(iOS)
        .navigationBarHidden(viewModel.isPerformanceMode)
        .statusBarHidden(viewModel.isPerformanceMode)
        #endif
    }

    @ViewBuilder
    private var readerContent: some View {
        switch viewModel.displayMode {
        case .singlePage:
            singlePageView
        case .horizontalPaged:
            horizontalPagedView
        case .verticalScroll:
            verticalScrollView
        case .twoPageSpread:
            twoPageSpreadView
        }
    }

    // MARK: - Single Page

    private var singlePageView: some View {
        GeometryReader { geo in
            let size = viewModel.pageSize(at: viewModel.currentPageIndex)
            PDFPageView(
                image: viewModel.renderedPages[viewModel.currentPageIndex],
                pageSize: size
            )
            .scaleEffect(viewModel.zoomScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(pageTurnTapGesture(in: geo.size))
        }
        .overlay(alignment: .bottom) { pageIndicator }
    }

    // MARK: - Horizontal Paged

    private var horizontalPagedView: some View {
        TabView(selection: $viewModel.currentPageIndex) {
            ForEach(0..<viewModel.pageCount, id: \.self) { index in
                PDFPageView(
                    image: viewModel.renderedPages[index],
                    pageSize: viewModel.pageSize(at: index)
                )
                .tag(index)
                .task {
                    if viewModel.renderedPages[index] == nil {
                        if let img = await viewModel.renderService.renderPage(at: index) {
                            viewModel.renderedPages[index] = img
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
        .overlay(alignment: .bottom) { pageIndicator }
    }

    // MARK: - Vertical Scroll

    private var verticalScrollView: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 2) {
                ForEach(0..<viewModel.pageCount, id: \.self) { index in
                    PDFPageView(
                        image: viewModel.renderedPages[index],
                        pageSize: viewModel.pageSize(at: index)
                    )
                    .task {
                        if viewModel.renderedPages[index] == nil {
                            if let img = await viewModel.renderService.renderPage(at: index) {
                                viewModel.renderedPages[index] = img
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Two Page Spread

    private var twoPageSpreadView: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                let leftIndex = viewModel.currentPageIndex
                let rightIndex = leftIndex + 1

                PDFPageView(
                    image: viewModel.renderedPages[leftIndex],
                    pageSize: viewModel.pageSize(at: leftIndex)
                )
                .frame(maxWidth: geo.size.width / 2)

                if rightIndex < viewModel.pageCount {
                    PDFPageView(
                        image: viewModel.renderedPages[rightIndex],
                        pageSize: viewModel.pageSize(at: rightIndex)
                    )
                    .frame(maxWidth: geo.size.width / 2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .gesture(pageTurnTapGesture(in: geo.size))
        }
        .overlay(alignment: .bottom) { pageIndicator }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)")
            .font(ASTypography.caption)
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.xs)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, ASSpacing.sm)
    }

    // MARK: - Gestures

    private func pageTurnTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                Task {
                    if value.location.x > size.width * 0.5 {
                        await viewModel.nextPage()
                    } else {
                        await viewModel.previousPage()
                    }
                }
            }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var readerToolbar: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Display", selection: $viewModel.displayMode) {
                    Label("Single Page", systemImage: "doc").tag(DisplayMode.singlePage)
                    Label("Horizontal", systemImage: "book").tag(DisplayMode.horizontalPaged)
                    Label("Vertical Scroll", systemImage: "scroll").tag(DisplayMode.verticalScroll)
                    Label("Two Page", systemImage: "book.pages").tag(DisplayMode.twoPageSpread)
                }
                Divider()
                Picker("Theme", selection: $viewModel.paperTheme) {
                    Text("Light").tag(PaperTheme.light)
                    Text("Dark").tag(PaperTheme.dark)
                    Text("Sepia").tag(PaperTheme.sepia)
                    Text("High Contrast").tag(PaperTheme.highContrast)
                }
                Divider()
                Button {
                    viewModel.isPerformanceMode.toggle()
                } label: {
                    Label("Performance Mode", systemImage: "theatermasks")
                }
            } label: {
                Label("View Options", systemImage: "ellipsis.circle")
            }
        }
    }
}
