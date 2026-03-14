import SwiftUI
import CoreDomain
import DesignSystem

/// Reader Environment — sacred full-screen score display.
/// No persistent toolbars. Controls appear as floating translucent overlay on interaction.
public struct ScoreReaderView: View {
    @State var viewModel: ReaderViewModel
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showingControls = false
    @State private var controlsTimer: Task<Void, Never>?

    public init(score: Score, fileURL: URL) {
        self._viewModel = State(initialValue: ReaderViewModel(score: score))
        self.fileURL = fileURL
    }

    public var body: some View {
        ZStack {
            // Paper background — always light
            viewModel.paperBackgroundColor
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
                    .tint(.secondary)
            } else {
                readerContent
            }

            // Floating controls overlay
            if showingControls {
                floatingControlsOverlay
                    .transition(.opacity)
            }

            // Page number — minimal overlay
            if !showingControls {
                pageNumberOverlay
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            viewModel.markAsOpened()
        }
        #if os(macOS)
        .onHover { hovering in
            if hovering && !showingControls {
                withAnimation(.easeInOut(duration: 0.2)) { showingControls = true }
                scheduleControlsHide()
            }
        }
        #endif
        .toolbar(.hidden)
        #if os(iOS)
        .navigationBarHidden(true)
        .statusBarHidden(!showingControls)
        #endif
        .persistentSystemOverlays(.hidden)
    }

    // MARK: - Reader Content

    @ViewBuilder
    private var readerContent: some View {
        GeometryReader { geo in
            switch viewModel.displayMode {
            case .singlePage:
                singlePageView(in: geo.size)
            case .horizontalPaged:
                horizontalPagedView
            case .verticalScroll:
                verticalScrollView
            case .twoPageSpread:
                twoPageSpreadView(in: geo.size)
            }
        }
    }

    // MARK: - Display Modes

    private func singlePageView(in size: CGSize) -> some View {
        PDFPageView(
            image: viewModel.renderedPages[viewModel.currentPageIndex],
            pageSize: viewModel.pageSize(at: viewModel.currentPageIndex)
        )
        .scaleEffect(viewModel.zoomScale)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(pageTurnTapGesture(in: size))
    }

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
    }

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

    private func twoPageSpreadView(in size: CGSize) -> some View {
        HStack(spacing: 2) {
            let leftIndex = viewModel.currentPageIndex
            let rightIndex = leftIndex + 1

            PDFPageView(
                image: viewModel.renderedPages[leftIndex],
                pageSize: viewModel.pageSize(at: leftIndex)
            )
            .frame(maxWidth: size.width / 2)

            if rightIndex < viewModel.pageCount {
                PDFPageView(
                    image: viewModel.renderedPages[rightIndex],
                    pageSize: viewModel.pageSize(at: rightIndex)
                )
                .frame(maxWidth: size.width / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(pageTurnTapGesture(in: size))
    }

    // MARK: - Page Turn Gesture

    private func pageTurnTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let x = value.location.x / size.width
                if x > 0.6 {
                    Task { await viewModel.nextPage() }
                } else if x < 0.4 {
                    Task { await viewModel.previousPage() }
                } else {
                    // Center tap toggles controls
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                    if showingControls { scheduleControlsHide() }
                }
            }
    }

    // MARK: - Floating Controls Overlay

    private var floatingControlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(viewModel.score.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)")
                    .font(.system(size: 13, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.md)
            .background(.ultraThinMaterial)

            Spacer()

            // Bottom floating control bar
            HStack(spacing: ASSpacing.xl) {
                // Display mode
                Menu {
                    Picker("Display", selection: $viewModel.displayMode) {
                        Label("Single Page", systemImage: "doc").tag(DisplayMode.singlePage)
                        Label("Horizontal", systemImage: "book").tag(DisplayMode.horizontalPaged)
                        Label("Vertical Scroll", systemImage: "scroll").tag(DisplayMode.verticalScroll)
                        Label("Two Page", systemImage: "book.pages").tag(DisplayMode.twoPageSpread)
                    }
                } label: {
                    controlIcon(icon: "rectangle.split.2x1", label: "Display")
                }

                // Paper theme — only light variants
                Menu {
                    Picker("Paper", selection: $viewModel.paperTheme) {
                        Text("White").tag(PaperTheme.light)
                        Text("Cream").tag(PaperTheme.sepia)
                    }
                } label: {
                    controlIcon(icon: "doc.plaintext", label: "Paper")
                }

                // Bookmarks
                controlButton(icon: "bookmark", label: "Bookmarks") {}

                // Performance lock
                controlButton(icon: "lock.shield", label: "Lock") {
                    viewModel.isPerformanceMode.toggle()
                }
            }
            .padding(.horizontal, ASSpacing.xl)
            .padding(.vertical, ASSpacing.md)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.1), radius: 12, y: 4)
            .padding(.horizontal, ASSpacing.xl)
            .padding(.bottom, ASSpacing.lg)
        }
    }

    private func controlButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlIcon(icon: icon, label: label)
        }
        .buttonStyle(.plain)
    }

    private func controlIcon(icon: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 44)
    }

    // MARK: - Page Number Overlay

    private var pageNumberOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(viewModel.currentPageIndex + 1)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, ASSpacing.sm)
                    .padding(.vertical, ASSpacing.xs)
            }
            .padding(ASSpacing.sm)
        }
    }

    // MARK: - Controls Timer

    private func scheduleControlsHide() {
        controlsTimer?.cancel()
        controlsTimer = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                withAnimation(.easeInOut(duration: 0.25)) { showingControls = false }
            }
        }
    }
}
