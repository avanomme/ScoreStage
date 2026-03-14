import SwiftUI
import CoreDomain
import DesignSystem
import AnnotationFeature

/// Reader Environment — sacred full-screen score display.
/// No persistent toolbars. Controls appear as floating translucent overlay on interaction.
public struct ScoreReaderView: View {
    @State var viewModel: ReaderViewModel
    let fileURL: URL
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingControls = false
    @State private var controlsTimer: Task<Void, Never>?
    @State private var annotationState = AnnotationState()

    public init(score: Score, fileURL: URL, onClose: (() -> Void)? = nil) {
        self._viewModel = State(initialValue: ReaderViewModel(score: score))
        self.fileURL = fileURL
        self.onClose = onClose
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

            // Annotation canvas overlay — separate layer over reader
            if annotationState.isAnnotating {
                AnnotationCanvasView(
                    pageIndex: viewModel.currentPageIndex,
                    pageSize: viewModel.pageSize(at: viewModel.currentPageIndex),
                    state: annotationState
                )
                .ignoresSafeArea()
            }

            // Annotation toolbar — floating Procreate-style palette
            if annotationState.isAnnotating {
                VStack {
                    Spacer()
                    AnnotationToolbarView(state: annotationState)
                        .padding(.horizontal, ASSpacing.xl)
                        .padding(.bottom, ASSpacing.screenPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Layer manager panel
                if annotationState.showingLayerManager {
                    VStack {
                        Spacer()
                        HStack {
                            LayerManagerView(state: annotationState)
                                .frame(width: 220)
                                .transition(.move(edge: .leading).combined(with: .opacity))
                            Spacer()
                        }
                        .padding(.leading, ASSpacing.lg)
                        .padding(.bottom, 100)
                    }
                }

                // Stamp picker panel
                if annotationState.showingStampPicker {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            StampPickerView(state: annotationState)
                                .frame(width: 240)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                        .padding(.trailing, ASSpacing.lg)
                        .padding(.bottom, 100)
                    }
                }
            }

            // Floating controls overlay (reader mode only)
            if showingControls && !annotationState.isAnnotating {
                floatingControlsOverlay
                    .transition(.opacity)
            }

            // Page number — minimal overlay
            if !showingControls && !annotationState.isAnnotating {
                pageNumberOverlay
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            viewModel.markAsOpened()
        }
        #if os(macOS)
        .onHover { hovering in
            if hovering && !showingControls && !annotationState.isAnnotating {
                withAnimation(.easeOut(duration: 0.2)) { showingControls = true }
                scheduleControlsHide()
            }
        }
        #endif
        .toolbar(.hidden)
        #if os(iOS)
        .navigationBarHidden(true)
        .statusBarHidden(!showingControls && !annotationState.isAnnotating)
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
        .gesture(annotationState.isAnnotating ? nil : pageTurnTapGesture(in: size))
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
        .gesture(annotationState.isAnnotating ? nil : pageTurnTapGesture(in: size))
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
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                    if showingControls { scheduleControlsHide() }
                }
            }
    }

    // MARK: - Floating Controls Overlay

    private var floatingControlsOverlay: some View {
        VStack {
            // Top bar — .regularMaterial, 44pt height
            HStack {
                Button {
                    if let onClose {
                        onClose()
                    } else {
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Library")
                            .font(.system(size: 14, weight: .regular))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Text(viewModel.score.title)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)")
                    .font(ASTypography.monoSmall)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, ASSpacing.lg)
            .frame(height: 44)
            .background(.regularMaterial)

            Spacer()

            // Bottom floating control bar
            HStack(spacing: ASSpacing.cardGap) {
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

                controlDivider

                // Paper theme — only light variants
                Menu {
                    Picker("Paper", selection: $viewModel.paperTheme) {
                        Text("White").tag(PaperTheme.light)
                        Text("Cream").tag(PaperTheme.sepia)
                    }
                } label: {
                    controlIcon(icon: "doc.plaintext", label: "Paper")
                }

                controlDivider

                // Annotate — enters annotation environment
                controlButton(icon: "pencil.tip.crop.circle", label: "Annotate") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        annotationState.isAnnotating = true
                        showingControls = false
                    }
                }

                controlDivider

                // Bookmarks
                controlButton(icon: "bookmark", label: "Bookmark") {}

                // Performance lock
                controlButton(icon: "lock.shield", label: "Lock") {
                    viewModel.isPerformanceMode.toggle()
                }
            }
            .padding(.horizontal, ASSpacing.xl)
            .padding(.vertical, ASSpacing.md)
            .frame(minWidth: 320, maxWidth: 520)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
            .padding(.horizontal, ASSpacing.xl)
            .padding(.bottom, ASSpacing.screenPadding)
        }
    }

    /// Vertical divider between control groups
    private var controlDivider: some View {
        Rectangle()
            .fill(.tertiary.opacity(0.3))
            .frame(width: 0.5, height: 28)
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
                .font(.system(size: 18, weight: .regular))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(.primary)
        .frame(minWidth: 44, minHeight: 44)
    }

    // MARK: - Page Number Overlay

    private var pageNumberOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text("\(viewModel.currentPageIndex + 1)")
                    .font(ASTypography.monoMicro)
                    .foregroundStyle(.tertiary.opacity(0.6))
                    .padding(.trailing, ASSpacing.md)
                    .padding(.bottom, ASSpacing.md)
            }
        }
    }

    // MARK: - Controls Timer

    private func scheduleControlsHide() {
        controlsTimer?.cancel()
        controlsTimer = Task {
            try? await Task.sleep(for: .seconds(4))
            if !Task.isCancelled {
                withAnimation(.easeIn(duration: 0.25)) { showingControls = false }
            }
        }
    }
}
