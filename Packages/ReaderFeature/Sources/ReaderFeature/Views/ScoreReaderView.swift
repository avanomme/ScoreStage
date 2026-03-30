import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem
import AnnotationFeature
import PlaybackFeature
import NotationFeature
import DeviceLinkFeature

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
            await restoreReaderSession()
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
        .onChange(of: linkService.currentPageIndex) { _, newValue in
            syncToLinkedPage(newValue)
        }
        .onChange(of: linkService.connectedPeers.count) { _, newValue in
            if newValue > 0 {
                linkService.sendOpenedScore(viewModel.score.id, pageIndex: normalizedSpreadBase(viewModel.currentPageIndex))
            }
        }
        .sheet(isPresented: $showingDeviceLinkSheet) {
            DevicePairingView(linkService: linkService)
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

    private func linkedTwoScreenSpreadView(in size: CGSize) -> some View {
        TwoDeviceSpreadView(linkService: linkService, pageCount: viewModel.pageCount) { index in
            PDFPageView(
                image: viewModel.renderedPages[index],
                pageSize: viewModel.pageSize(at: index)
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
                    topUtilityButton(icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showingBookmarksPanel.toggle()
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

                controlButton(icon: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark", label: "Bookmark", isActive: isCurrentPageBookmarked) {
                    toggleCurrentPageBookmark()
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
                        objects: []
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
        annotationState.canUndo = !annotationState.allStrokes.isEmpty
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

    private var pageProgressLabel: String {
        "\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)"
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
        viewModel.updateViewingPreferences()
        try? modelContext.save()
    }

    private func saveReaderSession() {
        let session = ReaderSessionState(
            pageIndex: viewModel.currentPageIndex,
            displayMode: viewModel.displayMode,
            paperTheme: viewModel.paperTheme,
            zoomScale: viewModel.zoomScale,
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
    let savedAt: Date
}
