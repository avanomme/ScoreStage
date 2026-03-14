import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem
import AnnotationFeature
import PlaybackFeature
import NotationFeature

/// Reader Environment — sacred full-screen score display.
/// No persistent toolbars. Controls appear as floating translucent overlay on interaction.
public struct ScoreReaderView: View {
    @State var viewModel: ReaderViewModel
    let fileURL: URL
    let musicXMLURL: URL?
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingControls = false
    @State private var controlsTimer: Task<Void, Never>?
    @State private var annotationState = AnnotationState()

    // Playback
    @State private var playbackEngine = PlaybackEngine()
    @State private var normalizedScore: NormalizedScore?
    @State private var measureMap: MeasureMap?
    @State private var showingPlayback = false
    @State private var showingMixer = false
    @State private var showingRehearsalMarks = false
    @State private var playbackProgress: Double = 0

    // Setlist navigation
    let setlistItems: [SetListItem]?
    let currentSetlistIndex: Int?
    let onNavigateSetlist: ((Int) -> Void)?
    @State private var showingSetlistNav = false

    public init(
        score: Score,
        fileURL: URL,
        musicXMLURL: URL? = nil,
        onClose: (() -> Void)? = nil,
        setlistItems: [SetListItem]? = nil,
        currentSetlistIndex: Int? = nil,
        onNavigateSetlist: ((Int) -> Void)? = nil
    ) {
        self._viewModel = State(initialValue: ReaderViewModel(score: score))
        self.fileURL = fileURL
        self.musicXMLURL = musicXMLURL
        self.onClose = onClose
        self.setlistItems = setlistItems
        self.currentSetlistIndex = currentSetlistIndex
        self.onNavigateSetlist = onNavigateSetlist
    }

    private var hasPlaybackData: Bool { normalizedScore != nil }

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

            // Playhead overlay when playing
            if playbackEngine.state != .stopped {
                PlayheadOverlayView(
                    progress: playbackProgress,
                    isPlaying: playbackEngine.state == .playing
                )
                .allowsHitTesting(false)
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

                if annotationState.showingLayerManager {
                    VStack {
                        Spacer()
                        HStack {
                            LayerManagerView(state: annotationState)
                                .frame(width: 220)
                            Spacer()
                        }
                        .padding(.leading, ASSpacing.lg)
                        .padding(.bottom, 100)
                    }
                }

                if annotationState.showingStampPicker {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            StampPickerView(state: annotationState)
                                .frame(width: 240)
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

            // Playback transport panel — slide up from bottom
            if showingPlayback && !annotationState.isAnnotating {
                playbackPanel
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Mixer panel — floating on the left
            if showingMixer {
                VStack {
                    Spacer()
                    HStack {
                        mixerPanel
                            .frame(width: 340)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.leading, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 100 : ASSpacing.screenPadding)
                }
            }

            // Rehearsal marks panel — floating on the right
            if showingRehearsalMarks {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        rehearsalPanel
                            .frame(width: 260)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    .padding(.trailing, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 100 : ASSpacing.screenPadding)
                }
            }

            // Page number — minimal overlay
            if !showingControls && !annotationState.isAnnotating && !showingPlayback {
                pageNumberOverlay
            }

            // Setlist song navigation — always visible when in setlist mode
            if setlistItems != nil && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        setlistNavigationBar
                        Spacer()
                    }
                    .padding(.bottom, showingPlayback ? 80 : ASSpacing.md)
                }
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            viewModel.markAsOpened()
            loadAnnotations()
            setupAnnotationCallbacks()
            await loadPlaybackData()
        }
        .onDisappear {
            // Auto-save annotations when leaving
            saveAnnotations()
            playbackEngine.stop()
            playbackEngine.shutdown()
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

    // MARK: - Load Playback Data

    private func loadPlaybackData() async {
        // Try to parse MusicXML for playback
        guard let xmlURL = musicXMLURL ?? findMusicXMLURL() else { return }

        let parser = MusicXMLParser()
        do {
            let score = try await parser.parse(url: xmlURL)
            let map = MeasureMap(score: score)
            await MainActor.run {
                self.normalizedScore = score
                self.measureMap = map
                playbackEngine.prepare(score: score, measureMap: map)

                // Wire measure change callback for auto-page-turn
                playbackEngine.onMeasureChanged = { measure in
                    autoPageTurn(forMeasure: measure)
                    updatePlaybackProgress()
                }
                playbackEngine.onPlaybackComplete = {
                    withAnimation { showingPlayback = false }
                }
            }
        } catch {
            // MusicXML parse failed — playback unavailable for this score
        }
    }

    /// If the primary file is a MusicXML, use it directly
    private func findMusicXMLURL() -> URL? {
        let ext = fileURL.pathExtension.lowercased()
        if ["xml", "mxl", "musicxml"].contains(ext) {
            return fileURL
        }
        return nil
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

    // MARK: - Auto Page Turn During Playback

    private func autoPageTurn(forMeasure measure: Int) {
        guard viewModel.pageCount > 0 else { return }
        // Simple heuristic: estimate page from measure/total measures ratio
        let totalMeasures = playbackEngine.measureCount
        guard totalMeasures > 0 else { return }
        let estimatedPage = Int(Double(measure) / Double(totalMeasures) * Double(viewModel.pageCount))
        let targetPage = min(max(0, estimatedPage), viewModel.pageCount - 1)
        if targetPage != viewModel.currentPageIndex {
            Task { await viewModel.goToPage(targetPage) }
        }
    }

    private func updatePlaybackProgress() {
        guard playbackEngine.totalDuration > 0 else { return }
        // Progress within current page
        let totalMeasures = playbackEngine.measureCount
        guard totalMeasures > 0, viewModel.pageCount > 0 else { return }
        let measuresPerPage = Double(totalMeasures) / Double(viewModel.pageCount)
        let measureInPage = Double(playbackEngine.currentMeasure) - Double(viewModel.currentPageIndex) * measuresPerPage
        playbackProgress = min(1.0, max(0.0, measureInPage / measuresPerPage))
    }

    // MARK: - Floating Controls Overlay

    private var floatingControlsOverlay: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    playbackEngine.stop()
                    playbackEngine.shutdown()
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

                // Paper theme
                Menu {
                    Picker("Paper", selection: $viewModel.paperTheme) {
                        Text("White").tag(PaperTheme.light)
                        Text("Cream").tag(PaperTheme.sepia)
                    }
                } label: {
                    controlIcon(icon: "doc.plaintext", label: "Paper")
                }

                controlDivider

                // Annotate
                controlButton(icon: "pencil.tip.crop.circle", label: "Annotate") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        annotationState.isAnnotating = true
                        showingControls = false
                    }
                }

                // Playback (only if MusicXML data available)
                if hasPlaybackData {
                    controlDivider

                    controlButton(icon: "play.circle", label: "Play") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingPlayback = true
                            showingControls = false
                        }
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
            .frame(minWidth: 320, maxWidth: 560)
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

    // MARK: - Playback Panel (DAW Transport)

    private var playbackPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: ASSpacing.sm) {
                // Close / panel controls row
                HStack {
                    // Mixer toggle
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingMixer.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.vertical.3")
                                .font(.system(size: 13, weight: .medium))
                            Text("Mixer")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(showingMixer ? ASColors.accentFallback : .secondary)
                    }
                    .buttonStyle(.plain)

                    // Rehearsal marks toggle
                    if let map = measureMap, !map.rehearsalEntries.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingRehearsalMarks.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "signpost.right")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Marks")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(showingRehearsalMarks ? ASColors.accentFallback : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    // Close playback panel
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            playbackEngine.stop()
                            showingPlayback = false
                            showingMixer = false
                            showingRehearsalMarks = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ASSpacing.lg)

                // Transport controls
                PlaybackControlsView(engine: playbackEngine)
            }
            .padding(.bottom, ASSpacing.screenPadding)
        }
    }

    // MARK: - Mixer Panel

    @ViewBuilder
    private var mixerPanel: some View {
        if let score = normalizedScore {
            let parts = score.parts.enumerated().map { index, part in
                PartInfo(from: part, index: index)
            }
            MixerPanelView(engine: playbackEngine, parts: parts)
        }
    }

    // MARK: - Rehearsal Marks Panel

    @ViewBuilder
    private var rehearsalPanel: some View {
        if let map = measureMap {
            let marks = RehearsalMarkInfo.from(measureMap: map)
            RehearsalMarksPanel(
                marks: marks,
                currentMeasure: playbackEngine.currentMeasure
            ) { measure in
                playbackEngine.seek(toMeasure: measure)
            }
        }
    }

    // MARK: - Shared Controls

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

    // MARK: - Annotation Persistence

    private func setupAnnotationCallbacks() {
        annotationState.onSave = { [self] in
            saveAnnotations()
        }
        annotationState.onClearPage = { [self] in
            annotationState.clearPage(viewModel.currentPageIndex)
        }
    }

    private func loadAnnotations() {
        let score = viewModel.score
        // Find or create default annotation layer
        let defaultLayer: AnnotationLayer
        if let existing = score.annotationLayers.first(where: { $0.type == .default }) {
            defaultLayer = existing
        } else {
            let layer = AnnotationLayer(name: "Default", type: .default)
            layer.score = score
            modelContext.insert(layer)
            try? modelContext.save()
            defaultLayer = layer
        }

        // Update annotation state layers
        annotationState.layers = score.annotationLayers.map { layer in
            LayerInfo(id: layer.id, name: layer.name, type: layer.type, isVisible: layer.isVisible, sortOrder: layer.sortOrder)
        }
        annotationState.activeLayerID = defaultLayer.id

        // Load strokes from all layers
        var loaded: [CanvasStroke] = []
        for layer in score.annotationLayers {
            for stroke in layer.strokes {
                if let canvasStroke = canvasStroke(from: stroke, layerID: layer.id) {
                    loaded.append(canvasStroke)
                }
            }
        }
        annotationState.allStrokes = loaded
        annotationState.isDirty = false
    }

    private func saveAnnotations() {
        guard annotationState.isDirty else { return }
        let score = viewModel.score

        // Find default layer
        guard let defaultLayer = score.annotationLayers.first(where: { $0.type == .default }) else { return }

        // Remove existing strokes for all layers
        for layer in score.annotationLayers {
            for stroke in layer.strokes {
                modelContext.delete(stroke)
            }
        }

        // Save current strokes
        for canvasStroke in annotationState.allStrokes {
            let targetLayer = score.annotationLayers.first(where: { $0.id == canvasStroke.layerID }) ?? defaultLayer
            let stroke = annotationStroke(from: canvasStroke)
            stroke.layer = targetLayer
            modelContext.insert(stroke)
        }

        try? modelContext.save()
        annotationState.isDirty = false
    }

    // MARK: - Stroke Conversion

    private func canvasStroke(from stroke: AnnotationStroke, layerID: UUID) -> CanvasStroke? {
        guard let points = try? JSONDecoder().decode([CGPoint].self, from: stroke.pointsData) else { return nil }
        return CanvasStroke(
            id: stroke.id,
            points: points,
            layerID: layerID,
            color: Color(hex: stroke.colorHex),
            lineWidth: CGFloat(stroke.lineWidth),
            opacity: stroke.opacity,
            pageIndex: stroke.pageIndex
        )
    }

    private func annotationStroke(from canvas: CanvasStroke) -> AnnotationStroke {
        let pointsData = (try? JSONEncoder().encode(canvas.points)) ?? Data()
        return AnnotationStroke(
            tool: .pen,
            colorHex: canvas.color.hexString,
            lineWidth: canvas.lineWidth,
            opacity: canvas.opacity,
            pageIndex: canvas.pageIndex,
            pointsData: pointsData
        )
    }

    // MARK: - Setlist Navigation

    @ViewBuilder
    private var setlistNavigationBar: some View {
        if let items = setlistItems, let currentIdx = currentSetlistIndex {
            HStack(spacing: ASSpacing.md) {
                // Previous song
                Button {
                    if currentIdx > 0 { onNavigateSetlist?(currentIdx - 1) }
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 14))
                }
                .disabled(currentIdx <= 0)
                .buttonStyle(.plain)

                // Song list menu
                Menu {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button {
                            onNavigateSetlist?(index)
                        } label: {
                            HStack {
                                Text("\(index + 1). \(item.score?.title ?? "Unknown")")
                                if index == currentIdx {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.number")
                            .font(.system(size: 13))
                        Text("\(currentIdx + 1)/\(items.count)")
                            .font(ASTypography.monoSmall)
                    }
                    .foregroundStyle(.primary)
                }

                // Next song
                Button {
                    if currentIdx < items.count - 1 { onNavigateSetlist?(currentIdx + 1) }
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 14))
                }
                .disabled(currentIdx >= items.count - 1)
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
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
