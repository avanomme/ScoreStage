import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem
import AnnotationFeature
import PlaybackFeature
import NotationFeature
import DeviceLinkFeature

private struct SetlistAdvanceCountdown: Equatable {
    let title: String
    let message: String
    var remainingSeconds: Int
    let destinationIndex: Int
}

private extension DisplayMode {
    var setlistLabel: String {
        switch self {
        case .singlePage: return "Single"
        case .verticalScroll: return "Scroll"
        case .horizontalPaged: return "Horizontal"
        case .twoPageSpread: return "Spread"
        }
    }
}

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
    @State private var showingBarJump = false
    @State private var barJumpText = ""
    @State private var playbackProgress: Double = 0
    @State private var linkService = DeviceLinkService()
    @State private var showingDeviceLinkSheet = false
    @State private var suppressLinkedBroadcast = false
    @State private var showingBookmarksPanel = false
    @State private var showingLinkSessionPanel = false
    @State private var showingQuickJumpPanel = false
    @State private var showingPageSetupPanel = false
    @State private var showingExportSheet = false

    // Setlist navigation
    let setlistItems: [SetListItem]?
    let currentSetlistIndex: Int?
    let onNavigateSetlist: ((Int) -> Void)?
    @State private var showingSetlistNav = false
    @State private var setlistAdvanceTask: Task<Void, Never>?
    @State private var activeSetlistCountdown: SetlistAdvanceCountdown?

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
    private var isLinkedSessionActive: Bool { linkService.isLinked }
    private var isLinkedTwoScreenSpread: Bool {
        isLinkedSessionActive && linkService.displayMode == .twoPageSpread
    }
    private var canBroadcastPageChanges: Bool {
        isLinkedSessionActive && linkService.localRole != .secondary && !suppressLinkedBroadcast
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

            // Playhead overlay when playing
            if playbackEngine.state != .stopped {
                PlayheadOverlayView(
                    progress: playbackProgress,
                    isPlaying: playbackEngine.state == .playing
                )
                .allowsHitTesting(false)
            }

            // Annotation overlay is always visible; editing is enabled only in annotation mode.
            if annotationState.isAnnotating || !annotationState.allStrokes.isEmpty || !annotationState.allObjects.isEmpty {
                AnnotationCanvasView(
                    pageIndex: viewModel.currentPageIndex,
                    pageSize: viewModel.pageSize(at: viewModel.currentPageIndex),
                    visibleLayerIDsOverride: effectiveVisibleLayerIDs,
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

                if annotationState.showingSnapshotManager {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            SnapshotManagerView(state: annotationState)
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

            if showingBookmarksPanel && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        bookmarksPanel
                            .frame(width: 320)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    .padding(.trailing, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 110 : ASSpacing.screenPadding)
                }
            }

            if showingLinkSessionPanel && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        linkSessionPanel
                            .frame(width: 320)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.leading, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 110 : ASSpacing.screenPadding)
                }
            }

            if showingQuickJumpPanel && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        quickJumpPanel
                            .frame(width: 340)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.leading, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 110 : ASSpacing.screenPadding)
                }
            }

            if showingPageSetupPanel && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        pageSetupPanel
                            .frame(width: 340)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                    .padding(.trailing, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 110 : ASSpacing.screenPadding)
                }
            }

            if showingSetlistNav && !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    HStack {
                        setlistSessionPanel
                            .frame(width: 360)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                        Spacer()
                    }
                    .padding(.leading, ASSpacing.lg)
                    .padding(.bottom, showingPlayback ? 110 : ASSpacing.screenPadding)
                }
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

            if let countdown = activeSetlistCountdown, !annotationState.isAnnotating {
                VStack {
                    Spacer()
                    VStack(spacing: ASSpacing.sm) {
                        Text(countdown.title)
                            .font(ASTypography.heading2)
                        Text(countdown.message)
                            .font(ASTypography.bodySmall)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Text("\(countdown.remainingSeconds)")
                            .font(ASTypography.displayMedium)
                            .monospacedDigit()
                        Button("Skip Wait") {
                            completeSetlistAdvance(to: countdown.destinationIndex)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(ASSpacing.xl)
                    .background(readerHUDPanel)
                    .padding(.bottom, showingPlayback ? 160 : 120)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            await restoreReaderSession()
            await applyCurrentSetlistPreset()
            viewModel.markAsOpened()
            loadAnnotations()
            setupAnnotationCallbacks()
            configureDeviceLink()
            await loadPlaybackData()
        }
        .onDisappear {
            // Auto-save annotations when leaving
            saveAnnotations()
            persistReaderPreferences()
            saveReaderSession()
            playbackEngine.stop()
            playbackEngine.shutdown()
            setlistAdvanceTask?.cancel()
            linkService.disconnect()
        }
        .onChange(of: viewModel.currentPageIndex) { _, newValue in
            saveReaderSession()
            guard canBroadcastPageChanges else { return }
            let pageToSend = linkService.displayMode == .twoPageSpread
                ? max(0, newValue - (newValue % 2))
                : newValue
            linkService.sendPageChange(to: pageToSend)
        }
        .onChange(of: viewModel.displayMode) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.paperTheme) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.pageTurnBehavior) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.isCropMarginsEnabled) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.cropInsets) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.brightnessAdjustment) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: viewModel.contrastAdjustment) { _, _ in
            persistReaderPreferences()
            saveReaderSession()
        }
        .onChange(of: linkService.currentPageIndex) { _, newValue in
            syncToLinkedPage(newValue)
        }
        .onChange(of: linkService.connectedPeers.count) { _, newValue in
            if newValue > 0 {
                linkService.sendOpenedScore(viewModel.score.id, pageIndex: normalizedSpreadBase(viewModel.currentPageIndex))
            }
        }
        .onChange(of: currentSetlistIndex) { _, _ in
            setlistAdvanceTask?.cancel()
            activeSetlistCountdown = nil
            Task {
                await applyCurrentSetlistPreset()
            }
        }
        .onChange(of: playbackEngine.state) { oldValue, newValue in
            guard oldValue == .playing, newValue == .stopped else { return }
            scheduleAutoAdvanceIfNeeded()
        }
        .sheet(isPresented: $showingDeviceLinkSheet) {
            DevicePairingView(linkService: linkService)
        }
        .sheet(isPresented: $showingExportSheet) {
            ExportAnnotationsView { mode in
                await exportAnnotations(mode: mode)
            }
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
                }
                // Continuous time update for smooth playhead
                playbackEngine.onTimeUpdate = { time, total in
                    updatePlaybackProgress(currentTime: time, totalDuration: total)
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
            if isLinkedTwoScreenSpread {
                linkedTwoScreenSpreadView(in: geo.size)
            } else {
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
    }

    // MARK: - Display Modes

    private func singlePageView(in size: CGSize) -> some View {
        PDFPageView(
            image: viewModel.renderedPages[viewModel.currentPageIndex],
            pageSize: viewModel.pageSize(at: viewModel.currentPageIndex),
            cropInsets: activeCropInsets,
            brightness: viewModel.brightnessAdjustment,
            contrast: viewModel.contrastAdjustment,
            slice: currentPageSlice
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
                    pageSize: viewModel.pageSize(at: index),
                    cropInsets: activeCropInsets,
                    brightness: viewModel.brightnessAdjustment,
                    contrast: viewModel.contrastAdjustment
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
                        pageSize: viewModel.pageSize(at: index),
                        cropInsets: activeCropInsets,
                        brightness: viewModel.brightnessAdjustment,
                        contrast: viewModel.contrastAdjustment
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
                pageSize: viewModel.pageSize(at: leftIndex),
                cropInsets: activeCropInsets,
                brightness: viewModel.brightnessAdjustment,
                contrast: viewModel.contrastAdjustment
            )
            .frame(maxWidth: size.width / 2)

            if rightIndex < viewModel.pageCount {
                PDFPageView(
                    image: viewModel.renderedPages[rightIndex],
                    pageSize: viewModel.pageSize(at: rightIndex),
                    cropInsets: activeCropInsets,
                    brightness: viewModel.brightnessAdjustment,
                    contrast: viewModel.contrastAdjustment
                )
                .frame(maxWidth: size.width / 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(annotationState.isAnnotating ? nil : pageTurnTapGesture(in: size))
    }

    private func linkedTwoScreenSpreadView(in size: CGSize) -> some View {
        TwoDeviceSpreadView(linkService: linkService, pageCount: viewModel.pageCount) { index in
            PDFPageView(
                image: viewModel.renderedPages[index],
                pageSize: viewModel.pageSize(at: index),
                cropInsets: activeCropInsets,
                brightness: viewModel.brightnessAdjustment,
                contrast: viewModel.contrastAdjustment
            )
            .scaleEffect(viewModel.zoomScale)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                if viewModel.renderedPages[index] == nil {
                    if let img = await viewModel.renderService.renderPage(at: index) {
                        viewModel.renderedPages[index] = img
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(annotationState.isAnnotating || linkService.localRole == .secondary ? nil : linkedSpreadTapGesture(in: size))
    }

    // MARK: - Page Turn Gesture

    private func pageTurnTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let x = value.location.x / size.width
                let y = value.location.y / size.height
                let isSafeMode = viewModel.isPerformanceMode || viewModel.pageTurnBehavior == .safePerformance

                if y < 0.08 {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                    if showingControls { scheduleControlsHide() }
                    return
                }

                if x > 0.6 {
                    Task { await viewModel.nextPage() }
                } else if x < 0.4 {
                    Task { await viewModel.previousPage() }
                } else if !isSafeMode {
                    // Center tap toggles controls
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                    if showingControls { scheduleControlsHide() }
                }
            }
    }

    private func linkedSpreadTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let x = value.location.x / size.width
                if x > 0.6 {
                    let nextPage = min(linkService.currentPageIndex + 2, max(viewModel.pageCount - 1, 0))
                    linkService.sendPageChange(to: normalizedSpreadBase(nextPage))
                } else if x < 0.4 {
                    let previousPage = max(linkService.currentPageIndex - 2, 0)
                    linkService.sendPageChange(to: normalizedSpreadBase(previousPage))
                } else {
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

    private func updatePlaybackProgress(currentTime: TimeInterval, totalDuration: TimeInterval) {
        guard totalDuration > 0, viewModel.pageCount > 0 else { return }
        // Calculate progress within the current page
        // Each page covers an equal fraction of total duration
        let durationPerPage = totalDuration / Double(viewModel.pageCount)
        let pageStartTime = Double(viewModel.currentPageIndex) * durationPerPage
        let timeInPage = currentTime - pageStartTime
        playbackProgress = min(1.0, max(0.0, timeInPage / durationPerPage))
    }

    // MARK: - Floating Controls Overlay

    private var floatingControlsOverlay: some View {
        VStack {
            HStack(alignment: .center, spacing: ASSpacing.md) {
                closeReaderButton

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.score.title)
                        .font(ASTypography.heading3)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: ASSpacing.xs) {
                        readerMetaBadge(icon: "doc.text", text: pageProgressLabel)

                        if isLinkedSessionActive {
                            readerMetaBadge(icon: "dot.radiowaves.left.and.right", text: linkedModeLabel, accent: ASColors.success)
                        }

                        if playbackEngine.state == .playing {
                            readerMetaBadge(icon: "waveform", text: "Playback", accent: ASColors.accentFallback)
                        }
                    }
                }

                Spacer()

                HStack(spacing: ASSpacing.sm) {
                    if setlistItems != nil {
                        topUtilityButton(icon: "music.note.list") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showingSetlistNav.toggle()
                            }
                        }
                    }
                    topUtilityButton(icon: "list.bullet.rectangle.portrait") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingQuickJumpPanel.toggle()
                        }
                    }
                    topUtilityButton(icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingBookmarksPanel.toggle()
                        }
                    }
                    topUtilityButton(icon: "slider.horizontal.3") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingPageSetupPanel.toggle()
                        }
                    }
                    topUtilityButton(icon: isLinkedSessionActive ? "dot.radiowaves.left.and.right" : "ipad.and.iphone") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingLinkSessionPanel.toggle()
                        }
                    }
                }
            }
            .padding(.horizontal, ASSpacing.lg)
            .padding(.vertical, ASSpacing.md)
            .background(readerHUDPanel)
            .padding(.horizontal, ASSpacing.lg)
            .padding(.top, ASSpacing.md)

            Spacer()

            HStack(spacing: ASSpacing.cardGap) {
                Menu {
                    Picker("Display", selection: $viewModel.displayMode) {
                        Label("Single Page", systemImage: "doc").tag(DisplayMode.singlePage)
                        Label("Horizontal", systemImage: "book").tag(DisplayMode.horizontalPaged)
                        Label("Vertical Scroll", systemImage: "scroll").tag(DisplayMode.verticalScroll)
                        Label("Two Page", systemImage: "book.pages").tag(DisplayMode.twoPageSpread)
                    }
                } label: {
                    controlIcon(icon: "rectangle.split.2x1", label: displayModeLabel, isActive: false)
                }

                if setlistItems != nil {
                    controlDivider

                    controlButton(icon: "music.note.list", label: "Set", isActive: showingSetlistNav) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSetlistNav.toggle()
                        }
                    }
                }

                controlDivider

                Menu {
                    Picker("Paper", selection: $viewModel.paperTheme) {
                        Text("White").tag(PaperTheme.light)
                        Text("Cream").tag(PaperTheme.sepia)
                    }
                } label: {
                    controlIcon(icon: "doc.plaintext", label: paperThemeLabel, isActive: false)
                }

                controlDivider

                controlButton(icon: "pencil.tip.crop.circle", label: "Annotate", isActive: annotationState.isAnnotating) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        annotationState.isAnnotating = true
                        showingControls = false
                    }
                }

                if hasPlaybackData {
                    controlDivider

                    controlButton(icon: "play.circle", label: "Play", isActive: showingPlayback) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingPlayback = true
                            showingControls = false
                        }
                    }
                }

                controlDivider

                controlButton(icon: "list.bullet.rectangle.portrait", label: "Jump", isActive: showingQuickJumpPanel) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingQuickJumpPanel.toggle()
                    }
                }

                controlDivider

                controlButton(icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark", label: "Bookmark", isActive: isCurrentPageBookmarked) {
                    toggleCurrentPageBookmark()
                }

                controlDivider

                controlButton(icon: "slider.horizontal.3", label: "Page", isActive: showingPageSetupPanel) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPageSetupPanel.toggle()
                    }
                }

                controlDivider

                controlButton(icon: isLinkedSessionActive ? "dot.radiowaves.left.and.right" : "ipad.and.iphone", label: "Link", isActive: isLinkedSessionActive) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingLinkSessionPanel.toggle()
                    }
                }

                controlButton(icon: "lock.shield", label: "Lock", isActive: viewModel.isPerformanceMode) {
                    viewModel.isPerformanceMode.toggle()
                }
            }
            .padding(.horizontal, ASSpacing.xl)
            .padding(.vertical, ASSpacing.md)
            .frame(minWidth: 320, maxWidth: 560)
            .background(readerHUDPanel)
            .padding(.horizontal, ASSpacing.xl)
            .padding(.bottom, ASSpacing.screenPadding)
        }
    }

    // MARK: - Playback Panel (DAW Transport)

    private var playbackPanel: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: ASSpacing.sm) {
                HStack(spacing: ASSpacing.sm) {
                    if let score = normalizedScore {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(Array(score.parts.enumerated()), id: \.offset) { index, part in
                                    partChip(name: part.abbreviation.isEmpty ? part.name : part.abbreviation, index: index)
                                }
                            }
                        }
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showingMixer.toggle() }
                    } label: {
                        Image(systemName: "slider.vertical.3")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(showingMixer ? ASColors.accentFallback : .secondary)
                    }
                    .buttonStyle(.plain)

                    if let map = measureMap, !map.rehearsalEntries.isEmpty {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showingRehearsalMarks.toggle() }
                        } label: {
                            Image(systemName: "signpost.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(showingRehearsalMarks ? ASColors.accentFallback : .secondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            playbackEngine.stop()
                            showingPlayback = false
                            showingMixer = false
                            showingRehearsalMarks = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ASSpacing.lg)

                HStack(spacing: ASSpacing.md) {
                    Text("Playback Studio")
                        .font(ASTypography.heading3)
                        .foregroundStyle(.primary)

                    Spacer()

                    readerMetaBadge(icon: "metronome", text: "\(Int(playbackEngine.tempo)) BPM", accent: ASColors.accentFallback)
                    readerMetaBadge(icon: "music.note", text: "m. \(playbackEngine.currentMeasure)", accent: ASColors.info)
                }
                .padding(.horizontal, ASSpacing.lg)

                HStack(spacing: ASSpacing.sm) {
                    Button {
                        barJumpText = "\(playbackEngine.currentMeasure)"
                        showingBarJump = true
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "number")
                                .font(.system(size: 10, weight: .medium))
                            Text("Bar \(playbackEngine.currentMeasure)/\(playbackEngine.measureCount)")
                                .font(ASTypography.monoSmall)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ASColors.chromeSurfaceElevated)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingBarJump) {
                        barJumpPopover
                    }

                    Text(formatTime(playbackEngine.currentTime))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.secondary)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ASColors.accentFallback)
                                .frame(width: geo.size.width * (playbackEngine.totalDuration > 0 ? playbackEngine.currentTime / playbackEngine.totalDuration : 0), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text(formatTime(playbackEngine.totalDuration))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, ASSpacing.lg)

                PlaybackControlsView(engine: playbackEngine)
            }
            .padding(.vertical, ASSpacing.md)
            .background(readerHUDPanel)
            .padding(.horizontal, ASSpacing.lg)
            .padding(.bottom, ASSpacing.screenPadding)
        }
    }

    // MARK: - Part Chip (inline mute/solo)

    private func partChip(name: String, index: Int) -> some View {
        let isMuted = playbackEngine.mutedParts.contains(index)
        let isSoloed = playbackEngine.soloPart == index

        let bgColor: Color = isSoloed ? ASColors.accentFallback.opacity(0.2) :
            isMuted ? Color.gray.opacity(0.15) : ASColors.chromeSurfaceElevated
        let fgColor: Color = isSoloed ? ASColors.accentFallback :
            isMuted ? Color.gray.opacity(0.4) : Color(white: 0.9)
        let borderColor: Color = isSoloed ? ASColors.accentFallback.opacity(0.5) :
            isMuted ? Color.clear : Color.gray.opacity(0.2)

        return Menu {
            Button {
                if isMuted {
                    playbackEngine.mutedParts.remove(index)
                } else {
                    playbackEngine.mutedParts.insert(index)
                }
            } label: {
                Label(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "speaker.wave.2" : "speaker.slash")
            }
            Button {
                if isSoloed {
                    playbackEngine.soloPart = nil
                } else {
                    playbackEngine.soloPart = index
                }
            } label: {
                Label(isSoloed ? "Unsolo" : "Solo", systemImage: "headphones")
            }
        } label: {
            Text(name)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(bgColor)
                .foregroundStyle(fgColor)
                .overlay(
                    RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bar Jump Popover

    private var barJumpPopover: some View {
        VStack(spacing: ASSpacing.md) {
            Text("Jump to Bar")
                .font(ASTypography.labelSmall)
                .foregroundStyle(.secondary)

            HStack {
                TextField("Bar", text: $barJumpText)
                    .font(ASTypography.mono)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif

                Text("/ \(playbackEngine.measureCount)")
                    .font(ASTypography.monoSmall)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: ASSpacing.md) {
                Button("Cancel") {
                    showingBarJump = false
                }
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)

                Button("Go") {
                    if let bar = Int(barJumpText), bar >= 1, bar <= playbackEngine.measureCount {
                        playbackEngine.seek(toMeasure: bar)
                        autoPageTurn(forMeasure: bar)
                    }
                    showingBarJump = false
                }
                .foregroundStyle(ASColors.accentFallback)
                .buttonStyle(.plain)
                .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding()
        .frame(minWidth: 200)
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

    private func controlButton(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            controlIcon(icon: icon, label: label, isActive: isActive)
        }
        .buttonStyle(.plain)
    }

    private func controlIcon(icon: String, label: String, isActive: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(isActive ? ASColors.accentFallback : .primary)
        .frame(minWidth: 54, minHeight: 48)
        .background(
            RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                .fill(isActive ? ASColors.accentFallback.opacity(0.12) : Color.clear)
        )
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
        annotationState.onCreateSnapshot = { [self] name in
            createAnnotationSnapshot(named: name)
        }
        annotationState.onRestoreSnapshot = { [self] id in
            restoreAnnotationSnapshot(id: id)
        }
        annotationState.onRequestExport = { [self] in
            showingExportSheet = true
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
        annotationState.layers = score.annotationLayers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { layer in
            LayerInfo(id: layer.id, name: layer.name, type: layer.type, isVisible: layer.isVisible, sortOrder: layer.sortOrder)
        }
        annotationState.activeLayerID = defaultLayer.id
        refreshAnnotationSnapshots()

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
        annotationState.allObjects = score.annotationLayers.flatMap { layer in
            layer.objects.compactMap { canvasObject(from: $0, layerID: layer.id) }
        }
        annotationState.isDirty = false
    }

    private func saveAnnotations() {
        guard annotationState.isDirty else { return }
        let score = viewModel.score

        syncPersistentLayers(for: score)

        // Find default layer
        guard let defaultLayer = score.annotationLayers.first(where: { $0.type == .default }) else { return }

        // Remove existing strokes for all layers
        for layer in score.annotationLayers {
            for stroke in layer.strokes {
                modelContext.delete(stroke)
            }
            for object in layer.objects {
                modelContext.delete(object)
            }
        }

        // Save current strokes
        for canvasStroke in annotationState.allStrokes {
            let targetLayer = score.annotationLayers.first(where: { $0.id == canvasStroke.layerID }) ?? defaultLayer
            let stroke = annotationStroke(from: canvasStroke)
            stroke.layer = targetLayer
            modelContext.insert(stroke)
        }

        for canvasObject in annotationState.allObjects {
            let targetLayer = score.annotationLayers.first(where: { $0.id == canvasObject.layerID }) ?? defaultLayer
            let object = annotationObject(from: canvasObject)
            object.layer = targetLayer
            modelContext.insert(object)
        }

        try? modelContext.save()
        annotationState.isDirty = false
    }

    private func syncPersistentLayers(for score: Score) {
        let stateLayers = annotationState.layers.sorted { $0.sortOrder < $1.sortOrder }
        let stateIDs = Set(stateLayers.map(\.id))

        for info in stateLayers {
            if let existing = score.annotationLayers.first(where: { $0.id == info.id }) {
                existing.name = info.name
                existing.type = info.type
                existing.isVisible = info.isVisible
                existing.sortOrder = info.sortOrder
                existing.modifiedAt = Date()
            } else {
                let layer = AnnotationLayer(name: info.name, type: info.type, sortOrder: info.sortOrder)
                layer.id = info.id
                layer.isVisible = info.isVisible
                layer.score = score
                modelContext.insert(layer)
            }
        }

        for layer in score.annotationLayers where !stateIDs.contains(layer.id) && layer.type != .default {
            modelContext.delete(layer)
        }

        if !annotationState.layers.contains(where: { $0.type == .default }) {
            let defaultLayer = AnnotationLayer(name: "Default", type: .default, sortOrder: 0)
            defaultLayer.score = score
            modelContext.insert(defaultLayer)
            annotationState.layers.insert(
                LayerInfo(id: defaultLayer.id, name: defaultLayer.name, type: defaultLayer.type, isVisible: defaultLayer.isVisible, sortOrder: defaultLayer.sortOrder),
                at: 0
            )
            annotationState.activeLayerID = defaultLayer.id
        }
    }

    private func refreshAnnotationSnapshots() {
        annotationState.snapshots = viewModel.score.annotationSnapshots
            .sorted { $0.createdAt > $1.createdAt }
            .map { SnapshotInfo(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
    }

    private func createAnnotationSnapshot(named name: String) {
        let payload = AnnotationSnapshotPayload(
            layers: annotationState.layers
                .sorted { $0.sortOrder < $1.sortOrder }
                .map { layer in
                    AnnotationSnapshotPayload.LayerPayload(
                        id: layer.id,
                        name: layer.name,
                        type: layer.type.rawValue,
                        isVisible: layer.isVisible,
                        sortOrder: layer.sortOrder,
                        strokes: annotationState.allStrokes
                            .filter { $0.layerID == layer.id }
                            .map { stroke in
                                AnnotationSnapshotPayload.StrokePayload(
                                    id: stroke.id,
                                    tool: "pen",
                                    colorHex: stroke.color.hexString,
                                    lineWidth: stroke.lineWidth,
                                    opacity: stroke.opacity,
                                    pageIndex: stroke.pageIndex,
                                    pointsData: (try? JSONEncoder().encode(stroke.points)) ?? Data()
                                )
                            },
                        objects: annotationState.allObjects
                            .filter { $0.layerID == layer.id }
                            .map { object in
                                AnnotationSnapshotPayload.ObjectPayload(
                                    id: object.id,
                                    type: object.type.rawValue,
                                    pageIndex: object.pageIndex,
                                    x: object.position.x,
                                    y: object.position.y,
                                    width: object.size.width,
                                    height: object.size.height,
                                    rotation: object.rotation,
                                    colorHex: object.color.hexString,
                                    text: object.text,
                                    fontSize: object.fontSize,
                                    shapeType: object.shapeType?.rawValue,
                                    stampType: object.stampType?.rawValue
                                )
                            }
                    )
                }
        )

        guard let data = try? JSONEncoder().encode(payload) else { return }
        let snapshot = AnnotationSnapshot(name: name, snapshotData: data)
        snapshot.score = viewModel.score
        modelContext.insert(snapshot)
        try? modelContext.save()
        refreshAnnotationSnapshots()
    }

    private func restoreAnnotationSnapshot(id: UUID) {
        guard let snapshot = viewModel.score.annotationSnapshots.first(where: { $0.id == id }),
              let payload = try? JSONDecoder().decode(AnnotationSnapshotPayload.self, from: snapshot.snapshotData) else {
            return
        }

        var restoredLayers = payload.layers
            .sorted { $0.sortOrder < $1.sortOrder }
            .map {
                LayerInfo(
                    id: $0.id,
                    name: $0.name,
                    type: AnnotationLayerType(rawValue: $0.type) ?? .custom,
                    isVisible: $0.isVisible,
                    sortOrder: $0.sortOrder
                )
            }

        if !restoredLayers.contains(where: { $0.type == .default }) {
            restoredLayers.insert(LayerInfo(name: "Default", type: .default, sortOrder: 0), at: 0)
        }

        annotationState.layers = restoredLayers
        annotationState.activeLayerID = restoredLayers.first(where: { $0.type == .default })?.id ?? restoredLayers.first?.id
        annotationState.allStrokes = payload.layers.flatMap { layer in
            layer.strokes.compactMap { strokePayload in
                guard let points = try? JSONDecoder().decode([CGPoint].self, from: strokePayload.pointsData) else { return nil }
                return CanvasStroke(
                    id: strokePayload.id,
                    points: points,
                    layerID: layer.id,
                    color: Color(hex: strokePayload.colorHex),
                    lineWidth: strokePayload.lineWidth,
                    opacity: strokePayload.opacity,
                    pageIndex: strokePayload.pageIndex
                )
            }
        }
        annotationState.allObjects = payload.layers.flatMap { layer in
            layer.objects.map { objectPayload in
                CanvasAnnotationObject(
                    id: objectPayload.id,
                    layerID: layer.id,
                    type: AnnotationObjectType(rawValue: objectPayload.type) ?? .shape,
                    pageIndex: objectPayload.pageIndex,
                    position: CGPoint(x: objectPayload.x, y: objectPayload.y),
                    size: CGSize(width: objectPayload.width, height: objectPayload.height),
                    rotation: objectPayload.rotation,
                    color: Color(hex: objectPayload.colorHex),
                    text: objectPayload.text,
                    fontSize: objectPayload.fontSize,
                    shapeType: objectPayload.shapeType.flatMap(ShapeType.init(rawValue:)),
                    stampType: objectPayload.stampType.flatMap(StampType.init(rawValue:))
                )
            }
        }
        annotationState.canUndo = !annotationState.allStrokes.isEmpty || !annotationState.allObjects.isEmpty
        annotationState.canRedo = false
        annotationState.isDirty = true
        saveAnnotations()
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

    private func canvasObject(from object: AnnotationObject, layerID: UUID) -> CanvasAnnotationObject? {
        CanvasAnnotationObject(
            id: object.id,
            layerID: layerID,
            type: object.type,
            pageIndex: object.pageIndex,
            position: CGPoint(x: object.x, y: object.y),
            size: CGSize(width: object.width, height: object.height),
            rotation: object.rotation,
            color: Color(hex: object.colorHex),
            text: object.text,
            fontSize: object.fontSize,
            shapeType: object.shapeType,
            stampType: object.stampType
        )
    }

    private func annotationObject(from canvas: CanvasAnnotationObject) -> AnnotationObject {
        let object = AnnotationObject(
            type: canvas.type,
            pageIndex: canvas.pageIndex,
            x: canvas.position.x,
            y: canvas.position.y,
            width: canvas.size.width,
            height: canvas.size.height
        )
        object.id = canvas.id
        object.rotation = canvas.rotation
        object.colorHex = canvas.color.hexString
        object.text = canvas.text
        object.fontSize = canvas.fontSize
        object.shapeType = canvas.shapeType
        object.stampType = canvas.stampType
        return object
    }

    // MARK: - Setlist Navigation

    private var currentSetlistItem: SetListItem? {
        guard let items = setlistItems, let currentSetlistIndex, items.indices.contains(currentSetlistIndex) else {
            return nil
        }
        return items[currentSetlistIndex]
    }

    private var hasActiveSetlistPreset: Bool {
        currentSetlistItem?.performancePreset != nil
    }

    @ViewBuilder
    private var setlistNavigationBar: some View {
        if let items = setlistItems, let currentIdx = currentSetlistIndex {
            HStack(spacing: ASSpacing.md) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingSetlistNav.toggle()
                    }
                } label: {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)

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

                if currentSetlistItem != nil {
                    Button {
                        triggerCurrentSetlistTransition()
                    } label: {
                        Image(systemName: transitionButtonIcon)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIdx >= items.count - 1)
                }
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
        }
    }

    @ViewBuilder
    private var setlistSessionPanel: some View {
        if let item = currentSetlistItem, let currentIdx = currentSetlistIndex {
            VStack(alignment: .leading, spacing: ASSpacing.lg) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: ASSpacing.xs) {
                        Text("Live Set")
                            .font(ASTypography.heading2)
                        Text("\(currentIdx + 1) of \(setlistItems?.count ?? 0)")
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingSetlistNav = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text(item.score?.title ?? viewModel.score.title)
                        .font(ASTypography.heading3)
                    if !item.medleyTitle.isEmpty {
                        Label("Medley: \(item.medleyTitle)", systemImage: "link")
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let preset = item.performancePreset {
                        HStack(spacing: ASSpacing.sm) {
                            readerMetaBadge(icon: "bookmark", text: "Page \(preset.startPageIndex + 1)")
                            if let displayMode = preset.preferredDisplayMode {
                                readerMetaBadge(icon: "rectangle.split.2x1", text: displayMode.setlistLabel)
                            }
                            if preset.requiresLinkedMode {
                                readerMetaBadge(icon: "ipad.and.iphone", text: "Linked", accent: ASColors.success)
                            }
                        }
                    }
                }

                if !item.cueTitle.isEmpty || !item.cueNotes.isEmpty {
                    sessionInfoBlock(title: item.cueTitle.isEmpty ? "Cue" : item.cueTitle, body: item.cueNotes)
                }

                if !item.performanceNotes.isEmpty {
                    sessionInfoBlock(title: "Performance Notes", body: item.performanceNotes)
                }

                if let setNotes = currentSetlistItem?.setList?.performanceNotes, !setNotes.isEmpty {
                    sessionInfoBlock(title: "Set Notes", body: setNotes)
                }

                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text("Transition")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(.secondary)
                    HStack(spacing: ASSpacing.sm) {
                        readerMetaBadge(icon: transitionButtonIcon, text: currentTransitionLabel)
                        if item.transitionStyle == .timedPause, !item.pauseNotes.isEmpty {
                            readerMetaBadge(icon: "text.bubble", text: item.pauseNotes)
                        }
                    }
                }

                HStack(spacing: ASSpacing.sm) {
                    Button("Previous") {
                        if currentIdx > 0 {
                            onNavigateSetlist?(currentIdx - 1)
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(currentIdx == 0)

                    Button(currentIdx >= (setlistItems?.count ?? 1) - 1 ? "Last Song" : "Advance") {
                        triggerCurrentSetlistTransition()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(currentIdx >= (setlistItems?.count ?? 1) - 1)
                }
            }
            .padding(ASSpacing.cardPadding)
            .background(readerHUDPanel)
        }
    }

    private func sessionInfoBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.xs) {
            Text(title)
                .font(ASTypography.labelSmall)
                .foregroundStyle(.secondary)
            Text(body)
                .font(ASTypography.bodySmall)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
    }

    private var transitionButtonIcon: String {
        guard let item = currentSetlistItem else { return "forward.end.fill" }
        switch item.transitionStyle {
        case .manual:
            return "forward.end.fill"
        case .segue:
            return "forward.frame.fill"
        case .timedPause:
            return "timer"
        case .autoAdvance:
            return "play.circle.fill"
        }
    }

    private var currentTransitionLabel: String {
        guard let item = currentSetlistItem else { return "Manual" }
        switch item.transitionStyle {
        case .manual:
            return "Manual advance"
        case .segue:
            return item.medleyTitle.isEmpty ? "Segue to next song" : "Segue in \(item.medleyTitle)"
        case .timedPause:
            return "\(Int(item.pauseDuration)) second pause"
        case .autoAdvance:
            return "\(Int(item.autoAdvanceDelay)) second auto-advance"
        }
    }

    private func applyCurrentSetlistPreset() async {
        guard let item = currentSetlistItem, let preset = item.performancePreset else { return }

        if let displayMode = preset.preferredDisplayMode {
            viewModel.displayMode = displayMode
        }
        if let paperTheme = preset.preferredPaperTheme {
            viewModel.paperTheme = paperTheme
        }
        if let pageTurnBehavior = preset.preferredPageTurnBehavior {
            viewModel.pageTurnBehavior = pageTurnBehavior
        }
        viewModel.isPerformanceMode = preset.opensInPerformanceMode

        guard viewModel.pageCount > 0 else { return }
        await viewModel.goToPage(min(preset.startPageIndex, viewModel.pageCount - 1))
    }

    private func triggerCurrentSetlistTransition() {
        guard let items = setlistItems,
              let currentIdx = currentSetlistIndex,
              currentIdx < items.count - 1 else { return }

        let nextIndex = currentIdx + 1
        let item = items[currentIdx]
        switch item.transitionStyle {
        case .manual, .segue:
            completeSetlistAdvance(to: nextIndex)
        case .timedPause:
            startSetlistCountdown(
                title: item.medleyTitle.isEmpty ? "Pause" : item.medleyTitle,
                message: item.pauseNotes.isEmpty ? "Advancing to the next chart after the programmed pause." : item.pauseNotes,
                seconds: max(1, Int(item.pauseDuration)),
                destinationIndex: nextIndex
            )
        case .autoAdvance:
            startSetlistCountdown(
                title: "Auto Advance",
                message: "The next chart will open automatically.",
                seconds: max(1, Int(item.autoAdvanceDelay)),
                destinationIndex: nextIndex
            )
        }
    }

    private func scheduleAutoAdvanceIfNeeded() {
        guard let item = currentSetlistItem, item.transitionStyle == .autoAdvance else { return }
        guard let currentIdx = currentSetlistIndex,
              let items = setlistItems,
              currentIdx < items.count - 1 else { return }
        startSetlistCountdown(
            title: "Auto Advance",
            message: "Playback ended. Opening the next chart automatically.",
            seconds: max(1, Int(item.autoAdvanceDelay)),
            destinationIndex: currentIdx + 1
        )
    }

    private func startSetlistCountdown(title: String, message: String, seconds: Int, destinationIndex: Int) {
        setlistAdvanceTask?.cancel()
        activeSetlistCountdown = SetlistAdvanceCountdown(
            title: title,
            message: message,
            remainingSeconds: seconds,
            destinationIndex: destinationIndex
        )

        setlistAdvanceTask = Task {
            var remaining = seconds
            while remaining > 0 && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
                if Task.isCancelled { return }
                await MainActor.run {
                    activeSetlistCountdown?.remainingSeconds = remaining
                }
            }
            if !Task.isCancelled {
                await MainActor.run {
                    completeSetlistAdvance(to: destinationIndex)
                }
            }
        }
    }

    private func completeSetlistAdvance(to destinationIndex: Int) {
        setlistAdvanceTask?.cancel()
        activeSetlistCountdown = nil
        onNavigateSetlist?(destinationIndex)
    }

    private var linkedModeLabel: String {
        switch linkService.displayMode {
        case .twoPageSpread:
            return linkService.localRole == .secondary ? "Linked Right Page" : "Linked Left Page"
        case .mirroredSync:
            return "Mirrored"
        case .conductorPerformer:
            return linkService.localRole == .conductor ? "Conductor" : "Performer"
        }
    }

    private var sortedBookmarks: [Bookmark] {
        viewModel.score.bookmarks.sorted { lhs, rhs in
            if lhs.pageIndex == rhs.pageIndex {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.pageIndex < rhs.pageIndex
        }
    }

    private var currentPageBookmark: Bookmark? {
        sortedBookmarks.first(where: { $0.pageIndex == viewModel.currentPageIndex })
    }

    private var isCurrentPageBookmarked: Bool {
        currentPageBookmark != nil
    }

    private var effectiveVisibleLayerIDs: Set<UUID>? {
        if annotationState.isAnnotating {
            return nil
        }

        switch linkService.displayMode {
        case .conductorPerformer:
            let visibleLayers = annotationState.layers.filter { layer in
                switch linkService.localRole {
                case .conductor:
                    return layer.type != .performer
                case .performer:
                    return layer.type != .teacher && layer.type != .rehearsal
                default:
                    return layer.isVisible
                }
            }
            return Set(visibleLayers.filter(\.isVisible).map(\.id))
        default:
            return nil
        }
    }

    private var activeCropInsets: NormalizedPageInsets {
        viewModel.isCropMarginsEnabled ? viewModel.cropInsets : .none
    }

    private var currentPageSlice: ReaderPageSlice {
        guard viewModel.displayMode == .singlePage, viewModel.pageTurnBehavior == .halfPage else {
            return .full
        }
        return viewModel.showingLowerHalf ? .bottomHalf : .topHalf
    }

    private var rehearsalMarks: [RehearsalMarkInfo] {
        guard let map = measureMap else { return [] }
        return RehearsalMarkInfo.from(measureMap: map)
    }

    private var navigationHotspots: [JumpNavigationEngine.NavigationHotspot] {
        guard let normalizedScore else { return [] }
        return JumpNavigationEngine().extractHotspots(from: normalizedScore)
            .filter { $0.destinationMeasure != nil }
    }

    private var currentPageStructuralJumps: [JumpNavigationEngine.NavigationHotspot] {
        navigationHotspots.filter { hotspot in
            estimatedPageIndex(forMeasure: hotspot.measureNumber) == viewModel.currentPageIndex
        }
    }

    private var pageProgressLabel: String {
        let suffix: String
        if viewModel.displayMode == .singlePage, viewModel.pageTurnBehavior == .halfPage {
            suffix = viewModel.showingLowerHalf ? "B" : "A"
        } else {
            suffix = ""
        }
        return "\(viewModel.currentPageIndex + 1)\(suffix) / \(viewModel.pageCount)"
    }

    private var displayModeLabel: String {
        switch viewModel.displayMode {
        case .singlePage: "Single"
        case .horizontalPaged: "Paged"
        case .verticalScroll: "Scroll"
        case .twoPageSpread: "Spread"
        }
    }

    private var paperThemeLabel: String {
        switch viewModel.paperTheme {
        case .light: "White"
        case .sepia: "Cream"
        case .warm: "Warm"
        case .highContrast: "Sharp"
        case .dark: "White"
        }
    }

    private var pageTurnBehaviorLabel: String {
        switch viewModel.pageTurnBehavior {
        case .standard: "Standard"
        case .halfPage: "Half Page"
        case .safePerformance: "Safe"
        }
    }

    private var readerHUDPanel: some View {
        RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.48),
                        ASColors.chromeSurface.opacity(0.92)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: ASRadius.sheet, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.22), radius: 18, y: 10)
    }

    private var closeReaderButton: some View {
        Button {
            playbackEngine.stop()
            playbackEngine.shutdown()
            if let onClose {
                onClose()
            } else {
                dismiss()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                Text("Library")
                    .font(ASTypography.label)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private func topUtilityButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }

    private func readerMetaBadge(icon: String, text: String, accent: Color? = nil) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ASTypography.monoMicro)
        .foregroundStyle(accent ?? ASColors.textSecondaryDark)
        .padding(.horizontal, ASSpacing.sm)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }

    private var bookmarksPanel: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("Bookmarks")
                    .font(ASTypography.heading3)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingBookmarksPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: ASSpacing.sm) {
                Button(isCurrentPageBookmarked ? "Remove Current" : "Save Current") {
                    toggleCurrentPageBookmark()
                }
                .buttonStyle(.plain)
                .foregroundStyle(isCurrentPageBookmarked ? ASColors.error : ASColors.accentFallback)

                Spacer()

                Text("Page \(viewModel.currentPageIndex + 1)")
                    .font(ASTypography.monoMicro)
                    .foregroundStyle(.secondary)
            }

            if sortedBookmarks.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("No bookmarks yet")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)
                    Text("Save important turns, repeats, and rehearsal entry points for fast recall.")
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, ASSpacing.sm)
            } else {
                ScrollView {
                    VStack(spacing: ASSpacing.xs) {
                        ForEach(sortedBookmarks) { bookmark in
                            HStack(spacing: ASSpacing.sm) {
                                Circle()
                                    .fill(Color(hex: bookmark.colorHex) ?? ASColors.accentFallback)
                                    .frame(width: 8, height: 8)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.name)
                                        .font(ASTypography.label)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("Page \(bookmark.pageIndex + 1)")
                                        .font(ASTypography.monoMicro)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if bookmark.pageIndex == viewModel.currentPageIndex {
                                    Text("Live")
                                        .font(ASTypography.monoMicro)
                                        .foregroundStyle(ASColors.accentFallback)
                                }

                                Button("Go") {
                                    Task { await viewModel.goToPage(bookmark.pageIndex) }
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showingBookmarksPanel = false
                                    }
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(ASColors.accentFallback)

                                Button {
                                    removeBookmark(bookmark)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, ASSpacing.sm)
                            .padding(.vertical, ASSpacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .padding(ASSpacing.lg)
        .background(readerHUDPanel)
    }

    private var linkSessionPanel: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("Linked Session")
                    .font(ASTypography.heading3)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingLinkSessionPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: ASSpacing.xs) {
                readerMetaBadge(icon: "dot.radiowaves.left.and.right", text: linkService.connectionSummary, accent: isLinkedSessionActive ? ASColors.success : ASColors.warning)
                Text("Switch roles and layouts without leaving the reader.")
                    .font(ASTypography.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Two-Device Spread")
                    .font(ASTypography.label)
                    .foregroundStyle(.primary)

                HStack(spacing: ASSpacing.sm) {
                    linkModeButton(
                        title: "Lead",
                        subtitle: "Left page",
                        isActive: linkService.displayMode == .twoPageSpread && linkService.localRole == .primary
                    ) {
                        linkService.configureLinkedSession(displayMode: .twoPageSpread, localRole: .primary, remoteRole: .secondary)
                    }

                    linkModeButton(
                        title: "Follow",
                        subtitle: "Right page",
                        isActive: linkService.displayMode == .twoPageSpread && linkService.localRole == .secondary
                    ) {
                        linkService.configureLinkedSession(displayMode: .twoPageSpread, localRole: .secondary, remoteRole: .primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Mirrored")
                    .font(ASTypography.label)
                    .foregroundStyle(.primary)

                HStack(spacing: ASSpacing.sm) {
                    linkModeButton(
                        title: "Leader",
                        subtitle: "Turns pages",
                        isActive: linkService.displayMode == .mirroredSync && linkService.localRole == .primary
                    ) {
                        linkService.configureLinkedSession(displayMode: .mirroredSync, localRole: .primary, remoteRole: .secondary)
                    }

                    linkModeButton(
                        title: "Follower",
                        subtitle: "Stays synced",
                        isActive: linkService.displayMode == .mirroredSync && linkService.localRole == .secondary
                    ) {
                        linkService.configureLinkedSession(displayMode: .mirroredSync, localRole: .secondary, remoteRole: .primary)
                    }
                }
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Conductor Session")
                    .font(ASTypography.label)
                    .foregroundStyle(.primary)

                HStack(spacing: ASSpacing.sm) {
                    linkModeButton(
                        title: "Conductor",
                        subtitle: "Leads ensemble",
                        isActive: linkService.displayMode == .conductorPerformer && linkService.localRole == .conductor
                    ) {
                        linkService.configureLinkedSession(displayMode: .conductorPerformer, localRole: .conductor, remoteRole: .performer)
                    }

                    linkModeButton(
                        title: "Performer",
                        subtitle: "Follows cueing",
                        isActive: linkService.displayMode == .conductorPerformer && linkService.localRole == .performer
                    ) {
                        linkService.configureLinkedSession(displayMode: .conductorPerformer, localRole: .performer, remoteRole: .conductor)
                    }
                }
            }

            HStack(spacing: ASSpacing.sm) {
                Button("Pair Devices") {
                    showingDeviceLinkSheet = true
                }
                .buttonStyle(.plain)
                .foregroundStyle(ASColors.accentFallback)

                Spacer()

                if isLinkedSessionActive {
                    Button("End Session") {
                        linkService.disconnect()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ASColors.error)
                }
            }
        }
        .padding(ASSpacing.lg)
        .background(readerHUDPanel)
    }

    private var quickJumpPanel: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("Quick Jump")
                    .font(ASTypography.heading3)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingQuickJumpPanel = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if !currentPageStructuralJumps.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("On This Page")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)

                    ForEach(currentPageStructuralJumps) { hotspot in
                        quickJumpRow(
                            title: hotspot.label,
                            subtitle: structuralJumpSubtitle(hotspot),
                            accent: ASColors.warning
                        ) {
                            navigate(toHotspot: hotspot)
                        }
                    }
                }
            }

            if !sortedBookmarks.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("Bookmarks")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)

                    ScrollView {
                        VStack(spacing: ASSpacing.xs) {
                            ForEach(sortedBookmarks) { bookmark in
                                quickJumpRow(
                                    title: bookmark.name,
                                    subtitle: "Page \(bookmark.pageIndex + 1)",
                                    accent: Color(hex: bookmark.colorHex) ?? ASColors.accentFallback
                                ) {
                                    Task { await navigateToPage(bookmark.pageIndex) }
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                }
            }

            if !rehearsalMarks.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("Rehearsal")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)

                    ScrollView {
                        VStack(spacing: ASSpacing.xs) {
                            ForEach(rehearsalMarks) { mark in
                                quickJumpRow(
                                    title: mark.label,
                                    subtitle: "Measure \(mark.measureNumber)",
                                    accent: ASColors.info
                                ) {
                                    navigateToMeasure(mark.measureNumber)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
            }

            if !viewModel.score.jumpLinks.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("Manual Links")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)

                    ForEach(viewModel.score.jumpLinks.sorted { $0.sourcePageIndex < $1.sourcePageIndex }) { link in
                        quickJumpRow(
                            title: link.label.isEmpty ? jumpTypeLabel(link.type) : link.label,
                            subtitle: "Page \(link.sourcePageIndex + 1) to \(link.destinationPageIndex + 1)",
                            accent: ASColors.success
                        ) {
                            Task { await navigateToPage(link.destinationPageIndex) }
                        }
                    }
                }
            }
        }
        .padding(ASSpacing.lg)
        .background(readerHUDPanel)
    }

    private var pageSetupPanel: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack {
                Text("Page Setup")
                    .font(ASTypography.heading3)
                    .foregroundStyle(.primary)

                Spacer()

                Button("Reset") {
                    resetPageSetup()
                }
                .buttonStyle(.plain)
                .foregroundStyle(ASColors.accentFallback)
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Turn Behavior")
                    .font(ASTypography.label)
                    .foregroundStyle(.primary)

                HStack(spacing: ASSpacing.sm) {
                    pageSetupOption(title: "Standard", subtitle: "Center tap allowed", isActive: viewModel.pageTurnBehavior == .standard) {
                        viewModel.pageTurnBehavior = .standard
                    }
                    pageSetupOption(title: "Half Page", subtitle: "A/B reading flow", isActive: viewModel.pageTurnBehavior == .halfPage) {
                        viewModel.pageTurnBehavior = .halfPage
                    }
                    pageSetupOption(title: "Safe", subtitle: "Top strip unlock", isActive: viewModel.pageTurnBehavior == .safePerformance) {
                        viewModel.pageTurnBehavior = .safePerformance
                    }
                }
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                HStack {
                    Text("Margin Crop")
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)
                    Spacer()
                    Toggle("", isOn: $viewModel.isCropMarginsEnabled)
                        .labelsHidden()
                }

                HStack(spacing: ASSpacing.sm) {
                    pageSetupOption(title: "None", subtitle: "Full page", isActive: activeCropInsets == .none) {
                        applyCropPreset(.none)
                    }
                    pageSetupOption(title: "Tight", subtitle: "Light trim", isActive: activeCropInsets == .narrow) {
                        applyCropPreset(.narrow)
                    }
                    pageSetupOption(title: "Stage", subtitle: "Bigger notes", isActive: activeCropInsets == .medium) {
                        applyCropPreset(.medium)
                    }
                }

                HStack(spacing: ASSpacing.sm) {
                    pageSetupOption(title: "Top", subtitle: "\(Int(viewModel.cropInsets.top * 100))%", isActive: false) {}
                    Slider(value: binding(for: \.top), in: 0...0.12, step: 0.01)
                }
                HStack(spacing: ASSpacing.sm) {
                    pageSetupOption(title: "Side", subtitle: "\(Int(viewModel.cropInsets.leading * 100))%", isActive: false) {}
                    Slider(value: binding(for: \.leading), in: 0...0.10, step: 0.01)
                }
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Paper Tuning")
                    .font(ASTypography.label)
                    .foregroundStyle(.primary)

                HStack(spacing: ASSpacing.sm) {
                    pageSetupOption(title: paperThemeLabel, subtitle: "Theme", isActive: false) {}
                    Spacer()
                    Text(pageTurnBehaviorLabel)
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: ASSpacing.sm) {
                    Text("Brightness")
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Slider(value: $viewModel.brightnessAdjustment, in: -0.2...0.25, step: 0.01)
                    Text(String(format: "%.2f", viewModel.brightnessAdjustment))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }

                HStack(spacing: ASSpacing.sm) {
                    Text("Contrast")
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 72, alignment: .leading)
                    Slider(value: $viewModel.contrastAdjustment, in: 0.8...1.8, step: 0.05)
                    Text(String(format: "%.2f", viewModel.contrastAdjustment))
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .padding(ASSpacing.lg)
        .background(readerHUDPanel)
    }

    private func quickJumpRow(title: String, subtitle: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ASSpacing.sm) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ASTypography.label)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(ASTypography.monoMicro)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, ASSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func pageSetupOption(title: String, subtitle: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ASTypography.label)
                    .foregroundStyle(isActive ? ASColors.accentFallback : .primary)
                Text(subtitle)
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, ASSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                    .fill(isActive ? ASColors.accentFallback.opacity(0.14) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func linkModeButton(title: String, subtitle: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ASTypography.label)
                    .foregroundStyle(isActive ? ASColors.accentFallback : .primary)
                Text(subtitle)
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, ASSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                    .fill(isActive ? ASColors.accentFallback.opacity(0.14) : Color.white.opacity(0.04))
            )
        }
        .buttonStyle(.plain)
    }

    private func configureDeviceLink() {
        linkService.startSession()
        linkService.onMessageReceived = { message in
            switch message {
            case .scoreOpened(let scoreID):
                if scoreID != viewModel.score.id {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showingControls = true
                    }
                }
            case .pageChanged(let pageIndex):
                syncToLinkedPage(pageIndex)
            default:
                break
            }
        }

        if linkService.isLinked {
            linkService.sendOpenedScore(viewModel.score.id, pageIndex: normalizedSpreadBase(viewModel.currentPageIndex))
        }
    }

    private func syncToLinkedPage(_ pageIndex: Int) {
        guard isLinkedSessionActive else { return }
        let target = linkService.displayMode == .twoPageSpread ? normalizedSpreadBase(pageIndex) : pageIndex
        guard target != viewModel.currentPageIndex else { return }

        suppressLinkedBroadcast = true
        Task {
            await viewModel.goToPage(target)
            await MainActor.run {
                suppressLinkedBroadcast = false
            }
        }
    }

    private func normalizedSpreadBase(_ pageIndex: Int) -> Int {
        max(0, pageIndex - (pageIndex % 2))
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func binding(for keyPath: WritableKeyPath<NormalizedPageInsets, Double>) -> Binding<Double> {
        Binding {
            viewModel.cropInsets[keyPath: keyPath]
        } set: { newValue in
            viewModel.cropInsets[keyPath: keyPath] = newValue
            viewModel.isCropMarginsEnabled = viewModel.cropInsets != .none
        }
    }

    private func applyCropPreset(_ preset: NormalizedPageInsets) {
        viewModel.cropInsets = preset
        viewModel.isCropMarginsEnabled = preset != .none
    }

    private func resetPageSetup() {
        viewModel.isCropMarginsEnabled = false
        viewModel.cropInsets = .none
        viewModel.brightnessAdjustment = 0
        viewModel.contrastAdjustment = 1.0
        viewModel.pageTurnBehavior = .standard
    }

    private func navigate(toHotspot hotspot: JumpNavigationEngine.NavigationHotspot) {
        guard let destination = hotspot.destinationMeasure else { return }
        navigateToMeasure(destination)
    }

    private func navigateToMeasure(_ measureNumber: Int) {
        let pageIndex = estimatedPageIndex(forMeasure: measureNumber)
        Task { await navigateToPage(pageIndex) }
    }

    private func navigateToPage(_ pageIndex: Int) async {
        await viewModel.goToPage(pageIndex)
        withAnimation(.easeInOut(duration: 0.2)) {
            showingQuickJumpPanel = false
            showingBookmarksPanel = false
        }
        if canBroadcastPageChanges {
            linkService.sendPageChange(to: pageIndex)
        }
    }

    private func estimatedPageIndex(forMeasure measureNumber: Int) -> Int {
        guard let normalizedScore,
              let firstPart = normalizedScore.parts.first,
              let lastMeasure = firstPart.measures.last?.number,
              lastMeasure > 0,
              viewModel.pageCount > 0 else {
            return min(max(0, measureNumber - 1), max(viewModel.pageCount - 1, 0))
        }

        let progress = Double(max(1, measureNumber) - 1) / Double(max(lastMeasure - 1, 1))
        return min(max(Int(progress * Double(max(viewModel.pageCount - 1, 0))), 0), max(viewModel.pageCount - 1, 0))
    }

    private func structuralJumpSubtitle(_ hotspot: JumpNavigationEngine.NavigationHotspot) -> String {
        guard let destinationMeasure = hotspot.destinationMeasure else {
            return "Measure \(hotspot.measureNumber)"
        }
        let destinationPage = estimatedPageIndex(forMeasure: destinationMeasure) + 1
        return "Measure \(hotspot.measureNumber) to page \(destinationPage)"
    }

    private func jumpTypeLabel(_ type: JumpType) -> String {
        switch type {
        case .coda: "Coda"
        case .dalSegno: "Dal Segno"
        case .daCapo: "Da Capo"
        case .repeatStart: "Repeat Start"
        case .repeatEnd: "Repeat End"
        case .custom: "Jump Link"
        }
    }

    private func exportAnnotations(mode: PDFExportMode) async -> Result<URL, Error> {
        saveAnnotations()
        let exporter = AnnotatedPDFExporter()
        let tempDirectory = FileManager.default.temporaryDirectory
        let safeTitle = viewModel.score.title.replacingOccurrences(of: " ", with: "-")

        do {
            switch mode {
            case .flattened:
                let outputURL = tempDirectory.appendingPathComponent("\(safeTitle)-annotated.pdf")
                let url = try await exporter.exportFlattened(
                    sourceURL: fileURL,
                    strokes: annotationState.allStrokes,
                    objects: annotationState.allObjects,
                    outputURL: outputURL
                )
                return .success(url)
            case .editable:
                let outputURL = tempDirectory.appendingPathComponent("\(safeTitle)-annotations-editable.json")
                let url = try await exporter.exportRawData(
                    strokes: annotationState.allStrokes,
                    objects: annotationState.allObjects,
                    layers: annotationState.layers,
                    outputURL: outputURL
                )
                return .success(url)
            case .rawData:
                let outputURL = tempDirectory.appendingPathComponent("\(safeTitle)-annotations-raw.json")
                let url = try await exporter.exportRawData(
                    strokes: annotationState.allStrokes,
                    objects: annotationState.allObjects,
                    layers: annotationState.layers,
                    outputURL: outputURL
                )
                return .success(url)
            }
        } catch {
            return .failure(error)
        }
    }

    private func toggleCurrentPageBookmark() {
        if let bookmark = currentPageBookmark {
            removeBookmark(bookmark)
            return
        }

        let bookmark = Bookmark(
            name: "Page \(viewModel.currentPageIndex + 1)",
            pageIndex: viewModel.currentPageIndex,
            sortOrder: sortedBookmarks.count
        )
        bookmark.score = viewModel.score
        modelContext.insert(bookmark)
        try? modelContext.save()
    }

    private func removeBookmark(_ bookmark: Bookmark) {
        modelContext.delete(bookmark)
        try? modelContext.save()
    }

    private func persistReaderPreferences() {
        guard !hasActiveSetlistPreset else { return }
        viewModel.updateViewingPreferences()
        try? modelContext.save()
    }

    private func saveReaderSession() {
        let session = ReaderSessionState(
            pageIndex: viewModel.currentPageIndex,
            displayMode: viewModel.displayMode,
            paperTheme: viewModel.paperTheme,
            zoomScale: viewModel.zoomScale,
            cropInsets: viewModel.cropInsets,
            isCropMarginsEnabled: viewModel.isCropMarginsEnabled,
            brightnessAdjustment: viewModel.brightnessAdjustment,
            contrastAdjustment: viewModel.contrastAdjustment,
            pageTurnBehavior: viewModel.pageTurnBehavior,
            savedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: readerSessionStorageKey)
    }

    private func restoreReaderSession() async {
        guard let data = UserDefaults.standard.data(forKey: readerSessionStorageKey),
              let session = try? JSONDecoder().decode(ReaderSessionState.self, from: data) else {
            return
        }

        viewModel.displayMode = session.displayMode
        viewModel.paperTheme = session.paperTheme
        viewModel.zoomScale = session.zoomScale
        viewModel.cropInsets = session.cropInsets
        viewModel.isCropMarginsEnabled = session.isCropMarginsEnabled
        viewModel.brightnessAdjustment = session.brightnessAdjustment
        viewModel.contrastAdjustment = session.contrastAdjustment
        viewModel.pageTurnBehavior = session.pageTurnBehavior

        guard viewModel.pageCount > 0 else { return }
        await viewModel.goToPage(min(session.pageIndex, viewModel.pageCount - 1))
    }

    private var readerSessionStorageKey: String {
        "reader-session-\(viewModel.score.id.uuidString)"
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

private struct ReaderSessionState: Codable {
    let pageIndex: Int
    let displayMode: DisplayMode
    let paperTheme: PaperTheme
    let zoomScale: Double
    let cropInsets: NormalizedPageInsets
    let isCropMarginsEnabled: Bool
    let brightnessAdjustment: Double
    let contrastAdjustment: Double
    let pageTurnBehavior: PageTurnBehavior
    let savedAt: Date

    init(
        pageIndex: Int,
        displayMode: DisplayMode,
        paperTheme: PaperTheme,
        zoomScale: Double,
        cropInsets: NormalizedPageInsets,
        isCropMarginsEnabled: Bool,
        brightnessAdjustment: Double,
        contrastAdjustment: Double,
        pageTurnBehavior: PageTurnBehavior,
        savedAt: Date
    ) {
        self.pageIndex = pageIndex
        self.displayMode = displayMode
        self.paperTheme = paperTheme
        self.zoomScale = zoomScale
        self.cropInsets = cropInsets
        self.isCropMarginsEnabled = isCropMarginsEnabled
        self.brightnessAdjustment = brightnessAdjustment
        self.contrastAdjustment = contrastAdjustment
        self.pageTurnBehavior = pageTurnBehavior
        self.savedAt = savedAt
    }

    enum CodingKeys: String, CodingKey {
        case pageIndex
        case displayMode
        case paperTheme
        case zoomScale
        case cropInsets
        case isCropMarginsEnabled
        case brightnessAdjustment
        case contrastAdjustment
        case pageTurnBehavior
        case savedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageIndex = try container.decodeIfPresent(Int.self, forKey: .pageIndex) ?? 0
        displayMode = try container.decodeIfPresent(DisplayMode.self, forKey: .displayMode) ?? .singlePage
        paperTheme = try container.decodeIfPresent(PaperTheme.self, forKey: .paperTheme) ?? .light
        zoomScale = try container.decodeIfPresent(Double.self, forKey: .zoomScale) ?? 1.0
        cropInsets = try container.decodeIfPresent(NormalizedPageInsets.self, forKey: .cropInsets) ?? .none
        isCropMarginsEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCropMarginsEnabled) ?? false
        brightnessAdjustment = try container.decodeIfPresent(Double.self, forKey: .brightnessAdjustment) ?? 0
        contrastAdjustment = try container.decodeIfPresent(Double.self, forKey: .contrastAdjustment) ?? 1.0
        pageTurnBehavior = try container.decodeIfPresent(PageTurnBehavior.self, forKey: .pageTurnBehavior) ?? .standard
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .now
    }
}
