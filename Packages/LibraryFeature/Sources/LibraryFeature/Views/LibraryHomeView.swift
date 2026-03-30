import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

// MARK: - Filter

public enum LibraryFilter: Equatable {
    case all
    case favorites
    case recentlyPlayed
}

public enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case title = "Title"
    case composer = "Composer"
    case genre = "Genre"
    case difficulty = "Difficulty"

    public var id: String { rawValue }
}

// MARK: - View Model

public enum LibraryViewMode: String, CaseIterable {
    case grid = "Icons"
    case list = "List"

    public var icon: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .list: "list.bullet"
        }
    }
}

@MainActor
@Observable
public final class LibraryViewModel {
    public var searchText = ""
    public var sortOrder: LibrarySortOrder = .recent
    public var viewMode: LibraryViewMode = .grid
    public var showingImporter = false
    public var showingScanner = false
    public var importError: String?
    public var inspectedScore: Score?
    /// Set when user wants to open a score (double-tap / context menu).
    public var scoreToOpen: Score?
    /// Multi-select mode
    public var isSelecting = false
    public var selectedScoreIDs: Set<UUID> = []

    public init() {}

    public func sortedScores(_ scores: [Score], filter: LibraryFilter) -> [Score] {
        var filtered = scores.filter { !$0.isArchived }

        switch filter {
        case .all: break
        case .favorites:
            filtered = filtered.filter { $0.isFavorite }
        case .recentlyPlayed:
            filtered = filtered.filter { $0.lastOpenedAt != nil }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter {
                $0.title.lowercased().contains(query) ||
                $0.composer.lowercased().contains(query) ||
                $0.customTags.contains { $0.lowercased().contains(query) }
            }
        }

        switch sortOrder {
        case .recent:
            return filtered.sorted { ($0.lastOpenedAt ?? $0.createdAt) > ($1.lastOpenedAt ?? $1.createdAt) }
        case .title:
            return filtered.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .composer:
            return filtered.sorted { $0.composer.localizedCaseInsensitiveCompare($1.composer) == .orderedAscending }
        case .genre:
            return filtered.sorted { $0.genre.localizedCaseInsensitiveCompare($1.genre) == .orderedAscending }
        case .difficulty:
            return filtered.sorted { $0.difficulty < $1.difficulty }
        }
    }
}

// MARK: - Library Home

public struct LibraryHomeView: View {
    @Query private var scores: [Score]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    private let importService = ScoreImportService()
    private let filter: LibraryFilter
    private let onOpen: ((Score) -> Void)?

    public init(filter: LibraryFilter = .all, onOpen: ((Score) -> Void)? = nil) {
        self.filter = filter
        self.onOpen = onOpen
    }

    private var navigationTitle: String {
        switch filter {
        case .all: "Library"
        case .favorites: "Favorites"
        case .recentlyPlayed: "Recently Played"
        }
    }

    public var body: some View {
        let sorted = viewModel.sortedScores(scores, filter: filter)

        VStack(spacing: 0) {
            Group {
                if scores.isEmpty && filter == .all {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "No Scores Yet",
                        message: "Import your sheet music to get started.",
                        actionTitle: "Import Score"
                    ) {
                        viewModel.showingImporter = true
                    }
                } else if sorted.isEmpty {
                    EmptyStateView(
                        icon: emptyIcon,
                        title: emptyTitle,
                        message: emptyMessage
                    )
                } else {
                    scoreCollection(sorted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Selection action bar
            if viewModel.isSelecting && !viewModel.selectedScoreIDs.isEmpty {
                selectionActionBar(sorted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(libraryBackdrop)
        .navigationTitle(navigationTitle)
        .searchable(text: $viewModel.searchText, prompt: "Search scores, composers, tags...")
        .toolbar { libraryToolbar }
        .scoreFileImporter(isPresented: $viewModel.showingImporter) { urls in
            Task {
                do {
                    let _ = try await importService.importFiles(from: urls, into: modelContext)
                } catch {
                    viewModel.importError = error.localizedDescription
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $viewModel.showingScanner) {
            ScoreScannerView { scannedPDFURL in
                Task {
                    do {
                        let _ = try await importService.importSingleFile(from: scannedPDFURL, into: modelContext)
                    } catch {
                        viewModel.importError = error.localizedDescription
                    }
                }
            }
        }
        #endif
        .alert("Import Error", isPresented: Binding(
            get: { viewModel.importError != nil },
            set: { if !$0 { viewModel.importError = nil } }
        )) {
            Button("OK") { viewModel.importError = nil }
        } message: {
            if let error = viewModel.importError {
                Text(error)
            }
        }
        .onChange(of: viewModel.scoreToOpen?.id) { _, newValue in
            if let score = viewModel.scoreToOpen {
                viewModel.scoreToOpen = nil
                onOpen?(score)
            }
        }
        .inspector(isPresented: Binding(
            get: { viewModel.inspectedScore != nil },
            set: { if !$0 { viewModel.inspectedScore = nil } }
        )) {
            if let score = viewModel.inspectedScore {
                ScoreInspectorPanel(score: score)
            }
        }
    }

    // MARK: - Score Grid / List

    @ViewBuilder
    private func scoreCollection(_ sorted: [Score]) -> some View {
        switch viewModel.viewMode {
        case .grid:
            scoreGridView(sorted)
        case .list:
            scoreListView(sorted)
        }
    }

    @ViewBuilder
    private func scoreGrid(_ sorted: [Score]) -> some View {
        switch viewModel.viewMode {
        case .grid:
            scoreGridView(sorted)
        case .list:
            scoreListView(sorted)
        }
    }

    private func scoreGridView(_ sorted: [Score]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.xxl) {
                if filter == .all {
                    libraryHero(sorted)
                    spotlightGenreStrip(sorted)
                }

                librarySectionHeader(
                    title: viewModel.searchText.isEmpty ? "Your Scores" : "Search Results",
                    subtitle: sectionSummary(for: sorted)
                )

                LazyVGrid(columns: gridColumns, spacing: ASSpacing.cardGap) {
                    ForEach(sorted) { score in
                        ZStack(alignment: .topLeading) {
                            ScoreCoverCard(
                                score: score,
                                isSelected: viewModel.isSelecting
                                    ? viewModel.selectedScoreIDs.contains(score.id)
                                    : viewModel.inspectedScore?.id == score.id
                            )

                            if viewModel.isSelecting {
                                Image(systemName: viewModel.selectedScoreIDs.contains(score.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(viewModel.selectedScoreIDs.contains(score.id)
                                                     ? ASColors.accentFallback : .white.opacity(0.7))
                                    .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                                    .padding(8)
                            }
                        }
                        .onTapGesture(count: 2) {
                            if !viewModel.isSelecting {
                                viewModel.scoreToOpen = score
                            }
                        }
                        .onTapGesture {
                            if viewModel.isSelecting {
                                toggleScoreSelection(score.id)
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.inspectedScore = score
                                }
                            }
                        }
                        .contextMenu { scoreContextMenu(for: score) }
                    }
                }
            }
            .padding(ASSpacing.screenPadding)
            .animation(.easeInOut(duration: 0.25), value: viewModel.sortOrder)
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchText)
        }
    }

    private func scoreListView(_ sorted: [Score]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.xl) {
                if filter == .all {
                    libraryHero(sorted)
                }

                librarySectionHeader(
                    title: viewModel.searchText.isEmpty ? "Library List" : "Matched Scores",
                    subtitle: sectionSummary(for: sorted)
                )

                LazyVStack(spacing: ASSpacing.sm) {
                    ForEach(sorted) { score in
                        HStack(spacing: ASSpacing.md) {
                            if viewModel.isSelecting {
                                Image(systemName: viewModel.selectedScoreIDs.contains(score.id)
                                      ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(viewModel.selectedScoreIDs.contains(score.id)
                                                     ? ASColors.accentFallback : Color.gray.opacity(0.4))
                            }

                            ScoreListRow(score: score, isSelected: !viewModel.isSelecting && viewModel.inspectedScore?.id == score.id)
                        }
                        .padding(.horizontal, ASSpacing.md)
                        .padding(.vertical, ASSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                                .fill(
                                    viewModel.isSelecting
                                        ? (viewModel.selectedScoreIDs.contains(score.id) ? ASColors.accentFallback.opacity(0.08) : ASColors.chromeSurface.opacity(0.84))
                                        : (viewModel.inspectedScore?.id == score.id ? ASColors.chromeSurfaceSelected : ASColors.chromeSurface.opacity(0.84))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                                        .stroke(
                                            viewModel.inspectedScore?.id == score.id
                                                ? ASColors.accentFallback.opacity(0.35)
                                                : ASColors.chromeBorder.opacity(0.8),
                                            lineWidth: 1
                                        )
                                )
                        )
                        .onTapGesture(count: 2) {
                            if !viewModel.isSelecting {
                                viewModel.scoreToOpen = score
                            }
                        }
                        .onTapGesture {
                            if viewModel.isSelecting {
                                toggleScoreSelection(score.id)
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.inspectedScore = score
                                }
                            }
                        }
                        .contextMenu { scoreContextMenu(for: score) }
                    }
                }
            }
            .padding(ASSpacing.screenPadding)
        }
    }

    private func toggleScoreSelection(_ id: UUID) {
        if viewModel.selectedScoreIDs.contains(id) {
            viewModel.selectedScoreIDs.remove(id)
        } else {
            viewModel.selectedScoreIDs.insert(id)
        }
    }

    // MARK: - Selection Action Bar

    private func selectionActionBar(_ sorted: [Score]) -> some View {
        HStack(spacing: ASSpacing.lg) {
            // Select All / Deselect All
            Button {
                if viewModel.selectedScoreIDs.count == sorted.count {
                    viewModel.selectedScoreIDs.removeAll()
                } else {
                    viewModel.selectedScoreIDs = Set(sorted.map(\.id))
                }
            } label: {
                Text(viewModel.selectedScoreIDs.count == sorted.count ? "Deselect All" : "Select All")
                    .font(ASTypography.labelSmall)
            }
            .buttonStyle(.plain)
            .foregroundStyle(ASColors.accentFallback)

            Spacer()

            Text("\(viewModel.selectedScoreIDs.count) selected")
                .font(ASTypography.label)
                .foregroundStyle(.secondary)

            Spacer()

            // Favorite selected
            Button {
                for score in sorted where viewModel.selectedScoreIDs.contains(score.id) {
                    score.isFavorite = true
                }
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            // Delete selected
            Button(role: .destructive) {
                for score in sorted where viewModel.selectedScoreIDs.contains(score.id) {
                    modelContext.delete(score)
                }
                viewModel.selectedScoreIDs.removeAll()
                viewModel.isSelecting = false
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                    Text("Delete")
                        .font(ASTypography.labelSmall)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(.horizontal, ASSpacing.lg)
        .padding(.vertical, ASSpacing.md)
        .background(.regularMaterial)
    }

    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 190, maximum: 230), spacing: ASSpacing.cardGap)]
        #else
        [GridItem(.adaptive(minimum: 156, maximum: 196), spacing: ASSpacing.lg)]
        #endif
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    viewModel.showingImporter = true
                } label: {
                    Label("Import Files", systemImage: "doc.badge.plus")
                }
                #if os(iOS)
                Button {
                    viewModel.showingScanner = true
                } label: {
                    Label("Scan Score", systemImage: "camera")
                }
                #endif
            } label: {
                Label("Add", systemImage: "plus")
            }
        }
        ToolbarItem {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isSelecting.toggle()
                    if !viewModel.isSelecting {
                        viewModel.selectedScoreIDs.removeAll()
                    }
                }
            } label: {
                Text(viewModel.isSelecting ? "Done" : "Select")
                    .font(ASTypography.labelSmall)
            }
        }
        ToolbarItem {
            Picker("View", selection: $viewModel.viewMode) {
                ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                    Image(systemName: mode.icon).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 80)
        }
        ToolbarItem {
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func scoreContextMenu(for score: Score) -> some View {
        Button {
            viewModel.scoreToOpen = score
        } label: {
            Label("Open", systemImage: "book.pages")
        }
        Divider()
        Button {
            score.isFavorite.toggle()
        } label: {
            Label(
                score.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: score.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button {
            viewModel.inspectedScore = score
        } label: {
            Label("Get Info", systemImage: "info.circle")
        }
        Divider()
        Button(role: .destructive) {
            modelContext.delete(score)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Empty States

    private var emptyIcon: String {
        switch filter {
        case .all: "music.note.list"
        case .favorites: "heart"
        case .recentlyPlayed: "clock"
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .all: "No Scores"
        case .favorites: "No Favorites"
        case .recentlyPlayed: "No Recent Scores"
        }
    }

    private var emptyMessage: String {
        switch filter {
        case .all: "Import sheet music to build your library."
        case .favorites: "Tap the heart icon on a score to add it to your favorites."
        case .recentlyPlayed: "Scores you've recently opened will appear here."
        }
    }

    private var libraryBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ASColors.chromeBackground,
                    ASColors.chromeSurface.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    ASColors.accentFallback.opacity(0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }

    private func libraryHero(_ sorted: [Score]) -> some View {
        let recentCount = sorted.filter {
            guard let opened = $0.lastOpenedAt else { return false }
            return Calendar.current.isDate(opened, equalTo: Date(), toGranularity: .weekOfYear)
        }.count
        let favoritesCount = scores.filter(\.isFavorite).count
        let scannedCount = scores.filter { $0.title.localizedCaseInsensitiveContains("scanned") }.count

        return VStack(alignment: .leading, spacing: ASSpacing.xl) {
            HStack(alignment: .top, spacing: ASSpacing.xl) {
                VStack(alignment: .leading, spacing: ASSpacing.md) {
                    Text("Stage library")
                        .font(ASTypography.displayMedium)
                        .foregroundStyle(ASColors.textPrimaryDark)

                    Text("Organize charts, rehearsal copies, and performance editions in a workspace that feels closer to a pro music tool than a file browser.")
                        .font(ASTypography.body)
                        .foregroundStyle(ASColors.textSecondaryDark)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: ASSpacing.sm) {
                        heroActionButton(title: "Import Score", systemImage: "square.and.arrow.down") {
                            viewModel.showingImporter = true
                        }
                        #if os(iOS)
                        heroActionButton(title: "Scan Sheet", systemImage: "camera.viewfinder") {
                            viewModel.showingScanner = true
                        }
                        #endif
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: ASSpacing.md) {
                heroStatCard(value: "\(scores.count)", title: "Total Scores", detail: "\(favoritesCount) favorites")
                heroStatCard(value: "\(recentCount)", title: "Used This Week", detail: "Keep active repertoire ready")
                heroStatCard(value: "\(scannedCount)", title: "Scanned Imports", detail: "Clean for print-style reading")
            }
        }
        .padding(ASSpacing.screenPadding)
        .background(
            RoundedRectangle(cornerRadius: ASRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            ASColors.chromeSurfaceElevated.opacity(0.95)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ASRadius.xl, style: .continuous)
                        .stroke(ASColors.accentFallback.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private func heroActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(ASTypography.label)
                .padding(.horizontal, ASSpacing.lg)
                .padding(.vertical, ASSpacing.sm)
                .background(
                    Capsule()
                        .fill(ASColors.accentFallback.opacity(0.14))
                        .overlay(
                            Capsule()
                                .stroke(ASColors.accentFallback.opacity(0.35), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(ASColors.textPrimaryDark)
    }

    private func heroStatCard(value: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.xs) {
            Text(value)
                .font(ASTypography.displaySmall)
                .foregroundStyle(ASColors.textPrimaryDark)

            Text(title.uppercased())
                .font(ASTypography.labelMicro)
                .tracking(1.0)
                .foregroundStyle(ASColors.accentFallback)

            Text(detail)
                .font(ASTypography.caption)
                .foregroundStyle(ASColors.textSecondaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ASSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                        .stroke(ASColors.chromeBorder, lineWidth: 1)
                )
        )
    }

    private func spotlightGenreStrip(_ sorted: [Score]) -> some View {
        let topGenres = Dictionary(grouping: sorted.filter { !$0.genre.isEmpty }, by: \.genre)
            .map { ($0.key, $0.value.count) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
                return lhs.1 > rhs.1
            }
            .prefix(4)

        guard !topGenres.isEmpty else {
            return AnyView(EmptyView())
        }

        return AnyView(
            VStack(alignment: .leading, spacing: ASSpacing.md) {
                librarySectionHeader(
                    title: "Spotlight Collections",
                    subtitle: "Quick pivots into the parts of your repertoire that matter now."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ASSpacing.md) {
                        ForEach(Array(topGenres), id: \.0) { genre, count in
                            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                                Text(genre)
                                    .font(ASTypography.heading3)
                                    .foregroundStyle(ASColors.textPrimaryDark)
                                Text("\(count) scores")
                                    .font(ASTypography.caption)
                                    .foregroundStyle(ASColors.textSecondaryDark)
                                Image(systemName: "waveform.and.magnifyingglass")
                                    .font(.system(size: 20, weight: .light))
                                    .foregroundStyle(ASColors.accentFallback)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(ASSpacing.cardPadding)
                            .background(
                                RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                ASColors.chromeSurfaceElevated,
                                                ASColors.chromeSurface
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                                            .stroke(ASColors.chromeBorder, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        )
    }

    private func librarySectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.xs) {
            Text(title)
                .font(ASTypography.heading1)
                .foregroundStyle(ASColors.textPrimaryDark)
            Text(subtitle)
                .font(ASTypography.bodySmall)
                .foregroundStyle(ASColors.textSecondaryDark)
        }
    }

    private func sectionSummary(for sorted: [Score]) -> String {
        if !viewModel.searchText.isEmpty {
            return "\(sorted.count) results for “\(viewModel.searchText)”"
        }

        switch filter {
        case .all:
            return "Recent imports, polished editions, and performance copies in one workspace."
        case .favorites:
            return "Pinned repertoire you want within one tap."
        case .recentlyPlayed:
            return "Your last-opened scores, ready for the next rehearsal."
        }
    }
}

// MARK: - Score Cover Card (Album Art Style — spec Section E.2)

struct ScoreCoverCard: View {
    let score: Score
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                    .fill(scoreCardGradient)
                    .aspectRatio(0.77, contentMode: .fit)
                    .overlay(alignment: .topLeading) {
                        Rectangle()
                            .fill(ASColors.accentFallback.opacity(0.88))
                            .frame(height: 8)
                    }
                    .overlay {
                        VStack(alignment: .leading, spacing: ASSpacing.md) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(score.genre.isEmpty ? "Performance Copy" : score.genre.uppercased())
                                        .font(ASTypography.monoMicro)
                                        .tracking(0.8)
                                        .foregroundStyle(ASColors.accentFallback.opacity(0.95))

                                    if score.pageCount > 0 {
                                        Text("\(score.pageCount) pages")
                                            .font(ASTypography.captionSmall)
                                            .foregroundStyle(ASColors.textTertiaryDark)
                                    }
                                }

                                Spacer()

                                Image(systemName: "music.quarternote.3")
                                    .font(.system(size: 16, weight: .light))
                                    .foregroundStyle(ASColors.textTertiaryDark)
                            }

                            Spacer()

                            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                                Text(score.title)
                                    .font(ASTypography.displaySmall)
                                    .foregroundStyle(ASColors.textPrimaryDark)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)

                                if !score.composer.isEmpty {
                                    Text(score.composer)
                                        .font(ASTypography.bodySmall)
                                        .foregroundStyle(ASColors.textSecondaryDark)
                                        .lineLimit(2)
                                }
                            }

                            HStack(spacing: ASSpacing.xs) {
                                scoreCardBadge(score.instrumentation.isEmpty ? "Solo" : score.instrumentation)
                                if score.duration > 0 {
                                    scoreCardBadge(formatDuration(score.duration))
                                }
                            }
                        }
                        .padding(ASSpacing.cardPadding)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                            .strokeBorder(isSelected ? ASColors.accentFallback : ASColors.chromeBorder.opacity(0.8), lineWidth: isSelected ? 2.5 : 1)
                    )
                    .shadow(
                        color: .black.opacity(isHovering ? 0.24 : 0.14),
                        radius: isHovering ? 18 : 10,
                        y: isHovering ? 10 : 5
                    )

                if score.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(ASColors.accentFallback.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(score.title)
                    .font(ASTypography.heading3)
                    .foregroundStyle(ASColors.textPrimaryDark)
                    .lineLimit(1)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.caption)
                        .foregroundStyle(ASColors.textSecondaryDark)
                        .lineLimit(1)
                }
            }
        }
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return secs > 0 ? "\(mins):\(String(format: "%02d", secs))" : "\(mins) min"
    }

    private var scoreCardGradient: LinearGradient {
        LinearGradient(
            colors: [
                ASColors.chromeSurfaceElevated,
                ASColors.chromeSurface,
                ASColors.chromeBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func scoreCardBadge(_ title: String) -> some View {
        Text(title)
            .font(ASTypography.monoMicro)
            .foregroundStyle(ASColors.textSecondaryDark)
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
            )
            .lineLimit(1)
    }
}

// MARK: - Score List Row

struct ScoreListRow: View {
    let score: Score
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        HStack(spacing: ASSpacing.md) {
            // Compact thumbnail
            RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                .fill(ASColors.chromeSurface)
                .frame(width: 40, height: 52)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 14, weight: .ultraLight))
                        .foregroundStyle(ASColors.tertiaryText)
                }

            // Title + composer
            VStack(alignment: .leading, spacing: 2) {
                Text(score.title)
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Genre tag
            if !score.genre.isEmpty {
                Text(score.genre)
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            // Page count
            if score.pageCount > 0 {
                Text("\(score.pageCount) pg")
                    .font(ASTypography.monoMicro)
                    .foregroundStyle(.tertiary)
                    .frame(width: 40, alignment: .trailing)
            }

            // Favorite indicator
            if score.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(ASColors.accentFallback)
            }
        }
        .padding(.vertical, ASSpacing.xs)
        .contentShape(Rectangle())
        .opacity(isHovering ? 0.85 : 1.0)
        .onHover { isHovering = $0 }
    }
}

// MARK: - Inspector Panel (spec Section E.3)

struct ScoreInspectorPanel: View {
    let score: Score

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.sectionSpacing) {
                // Header
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text(score.title)
                        .font(ASTypography.heading1)

                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(ASTypography.body)
                            .foregroundStyle(.secondary)
                    }

                    if !score.arranger.isEmpty {
                        Text("arr. \(score.arranger)")
                            .font(ASTypography.bodySmall)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Metadata rows
                VStack(alignment: .leading, spacing: ASSpacing.inspectorRowGap) {
                    inspectorRow("Instrumentation", value: score.instrumentation)
                    inspectorRow("Genre", value: score.genre)
                    inspectorRow("Key", value: score.key)

                    if score.pageCount > 0 {
                        inspectorRow("Pages", value: "\(score.pageCount)")
                    }
                    if score.difficulty > 0 {
                        inspectorRow("Difficulty", value: "\(score.difficulty) / 10")
                    }
                    if score.duration > 0 {
                        let mins = Int(score.duration) / 60
                        let secs = Int(score.duration) % 60
                        inspectorRow("Duration", value: secs > 0 ? "\(mins)m \(secs)s" : "\(mins) min")
                    }
                }

                // Tags
                if !score.customTags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: ASSpacing.sm) {
                        Text("TAGS")
                            .font(ASTypography.labelMicro)
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        FlowLayout(spacing: ASSpacing.xs) {
                            ForEach(score.customTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(ASColors.accentFallback.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // Notes
                if !score.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: ASSpacing.sm) {
                        Text("NOTES")
                            .font(ASTypography.labelMicro)
                            .foregroundStyle(.secondary)
                            .tracking(0.5)

                        Text(score.notes)
                            .font(ASTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(ASSpacing.screenPadding)
        }
        .inspectorColumnWidth(min: 240, ideal: 300, max: 380)
    }

    @ViewBuilder
    private func inspectorRow(_ label: String, value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: ASSpacing.inspectorLabelGap) {
                Text(label.uppercased())
                    .font(ASTypography.labelSmall)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(ASTypography.bodySmall)
            }
        }
    }
}
