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

private struct LibraryImportReviewSheet: View {
    @Binding var items: [ScoreImportService.ImportReviewItem]
    @Environment(\.dismiss) private var dismiss
    let onImport: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Review import decisions before anything touches the library. Duplicate matches can be merged or replaced instead of blindly copied.")
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(.secondary)
                }

                ForEach($items) { $item in
                    ImportReviewRow(item: $item)
                }
            }
            .navigationTitle("Import Review")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onImport()
                        dismiss()
                    }
                    .disabled(items.isEmpty)
                }
            }
        }
    }
}

private struct ImportReviewRow: View {
    @Binding var item: ScoreImportService.ImportReviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            HStack(alignment: .top, spacing: ASSpacing.md) {
                VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                    Text(item.title)
                        .font(ASTypography.label)
                    if !item.composer.isEmpty {
                        Text(item.composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.fileName)
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Picker("Decision", selection: $item.decision.action) {
                Text("Import").tag(ScoreImportService.ImportActionKind.importNew)
                if !item.duplicateMatches.isEmpty {
                    Text("Merge").tag(ScoreImportService.ImportActionKind.mergeIntoExisting)
                    Text("Replace").tag(ScoreImportService.ImportActionKind.replaceExisting)
                }
                Text("Skip").tag(ScoreImportService.ImportActionKind.skip)
            }
            .pickerStyle(.segmented)

            if !item.duplicateMatches.isEmpty {
                Picker("Target", selection: targetBinding) {
                    ForEach(item.duplicateMatches) { match in
                        Text("\(match.title)\(match.composer.isEmpty ? "" : " • \(match.composer)")")
                            .tag(Optional(match.scoreID))
                    }
                }
                .pickerStyle(.menu)

                VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                    ForEach(item.duplicateMatches) { match in
                        Label(
                            match.kind == .exactFile ? "Exact file already exists" : "Potential library match",
                            systemImage: match.kind == .exactFile ? "doc.on.doc.fill" : "rectangle.3.group"
                        )
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(match.kind == .exactFile ? ASColors.warning : .secondary)
                    }
                }
            }
        }
        .padding(.vertical, ASSpacing.xs)
        .onChange(of: item.decision.action) { _, newAction in
            if item.decision.targetScoreID == nil {
                item.decision.targetScoreID = item.duplicateMatches.first?.scoreID
            }
            if newAction == .importNew || newAction == .skip {
                item.decision.targetScoreID = item.duplicateMatches.first?.scoreID
            }
        }
    }

    private var targetBinding: Binding<UUID?> {
        Binding(
            get: { item.decision.targetScoreID ?? item.duplicateMatches.first?.scoreID },
            set: { item.decision.targetScoreID = $0 }
        )
    }
}

private struct BulkMetadataEditorSheet: View {
    let scores: [Score]
    @Environment(\.dismiss) private var dismiss

    @State private var composer = ""
    @State private var genre = ""
    @State private var instrumentation = ""
    @State private var difficulty = 0
    @State private var tags = ""
    @State private var favoriteSelection = false
    @State private var archiveSelection = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(scores.count) selected")
                        .font(ASTypography.body)
                }

                Section("Apply Metadata") {
                    TextField("Composer", text: $composer)
                    TextField("Genre", text: $genre)
                    TextField("Instrumentation", text: $instrumentation)
                    Picker("Difficulty", selection: $difficulty) {
                        Text("Keep Existing").tag(0)
                        ForEach(1...10, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                    TextField("Tags (comma separated)", text: $tags)
                }

                Section("Flags") {
                    Toggle("Mark as favorite", isOn: $favoriteSelection)
                    Toggle("Archive selection", isOn: $archiveSelection)
                }
            }
            .navigationTitle("Bulk Metadata")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        applyChanges()
                        dismiss()
                    }
                    .disabled(scores.isEmpty)
                }
            }
        }
    }

    private func applyChanges() {
        let newTags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for score in scores {
            if !composer.isEmpty { score.composer = composer }
            if !genre.isEmpty { score.genre = genre }
            if !instrumentation.isEmpty { score.instrumentation = instrumentation }
            if difficulty > 0 { score.difficulty = difficulty }
            if !newTags.isEmpty {
                score.customTags = Array(Set(score.customTags + newTags)).sorted()
            }
            if favoriteSelection { score.isFavorite = true }
            if archiveSelection { score.isArchived = true }
            score.modifiedAt = Date()
        }
    }
}

public enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case title = "Title"
    case composer = "Composer"
    case genre = "Genre"
    case difficulty = "Difficulty"

    public var id: String { rawValue }
}

public enum LibrarySmartCollection: String, CaseIterable, Identifiable {
    case importInbox = "Import Inbox"
    case needsMetadata = "Needs Metadata"
    case rehearsalActive = "Rehearsal Active"
    case performanceReady = "Performance Ready"
    case scannedLibrary = "Scanned Scores"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .importInbox: "tray.full"
        case .needsMetadata: "square.and.pencil"
        case .rehearsalActive: "music.note.house"
        case .performanceReady: "music.note.tv"
        case .scannedLibrary: "doc.viewfinder"
        }
    }
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
    public var importSummary: String?
    public var inspectedScore: Score?
    /// Set when user wants to open a score (double-tap / context menu).
    public var scoreToOpen: Score?
    /// Multi-select mode
    public var isSelecting = false
    public var selectedScoreIDs: Set<UUID> = []
    public var activeSmartCollection: LibrarySmartCollection?
    public var importReviewItems: [ScoreImportService.ImportReviewItem] = []
    public var showingImportReview = false
    public var showingBulkEditor = false

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
                $0.genre.lowercased().contains(query) ||
                $0.instrumentation.lowercased().contains(query) ||
                $0.customTags.contains { $0.lowercased().contains(query) }
            }
        }

        if let activeSmartCollection {
            filtered = filtered.filter { score in
                switch activeSmartCollection {
                case .importInbox:
                    let opened = score.lastOpenedAt ?? score.createdAt
                    return Calendar.current.dateComponents([.day], from: opened, to: Date()).day ?? 0 <= 7
                case .needsMetadata:
                    return score.composer.isEmpty || score.genre.isEmpty || score.instrumentation.isEmpty || score.customTags.isEmpty
                case .rehearsalActive:
                    guard let opened = score.lastOpenedAt else { return false }
                    return Calendar.current.dateComponents([.day], from: opened, to: Date()).day ?? 99 <= 14
                case .performanceReady:
                    return score.isFavorite || !score.bookmarks.isEmpty || !score.setListItems.isEmpty
                case .scannedLibrary:
                    return score.assets.contains(where: { $0.type == .image }) ||
                        score.title.localizedCaseInsensitiveContains("scan")
                }
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
                    viewModel.importReviewItems = try await importService.previewImport(from: urls, into: modelContext)
                    viewModel.showingImportReview = !viewModel.importReviewItems.isEmpty
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
        .alert("Import Summary", isPresented: Binding(
            get: { viewModel.importSummary != nil },
            set: { if !$0 { viewModel.importSummary = nil } }
        )) {
            Button("OK") { viewModel.importSummary = nil }
        } message: {
            if let summary = viewModel.importSummary {
                Text(summary)
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
        .sheet(isPresented: $viewModel.showingImportReview) {
            LibraryImportReviewSheet(items: $viewModel.importReviewItems) {
                Task {
                    do {
                        let result = try await importService.importReviewedFiles(viewModel.importReviewItems, into: modelContext)
                        viewModel.importSummary = importSummary(from: result)
                        viewModel.showingImportReview = false
                        viewModel.importReviewItems = []
                    } catch {
                        viewModel.importError = error.localizedDescription
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingBulkEditor) {
            BulkMetadataEditorSheet(scores: selectedScores(from: sorted))
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
                    quickCommandDeck(sorted)
                    smartCollectionsStrip
                    continueShelf(sorted)
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
                    quickCommandDeck(sorted)
                    smartCollectionsStrip
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

    private func selectedScores(from sorted: [Score]) -> [Score] {
        sorted.filter { viewModel.selectedScoreIDs.contains($0.id) }
    }

    private func importSummary(from result: ScoreImportService.ImportBatchResult) -> String {
        var parts: [String] = []
        if !result.imported.isEmpty {
            parts.append("\(result.imported.count) imported")
        }
        if result.mergedCount > 0 {
            parts.append("\(result.mergedCount) merged")
        }
        if result.replacedCount > 0 {
            parts.append("\(result.replacedCount) replaced")
        }
        if result.skippedCount > 0 {
            parts.append("\(result.skippedCount) skipped")
        }
        if !result.failedFiles.isEmpty {
            parts.append("\(result.failedFiles.count) failed")
        }
        return parts.joined(separator: ", ")
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

            Button {
                viewModel.showingBulkEditor = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14))
                    Text("Bulk Edit")
                        .font(ASTypography.labelSmall)
                }
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
                Divider()
                Picker("Smart Collection", selection: Binding(
                    get: { viewModel.activeSmartCollection },
                    set: { viewModel.activeSmartCollection = $0 }
                )) {
                    Text("All Scores").tag(LibrarySmartCollection?.none)
                    ForEach(LibrarySmartCollection.allCases) { collection in
                        Text(collection.rawValue).tag(Optional(collection))
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
        let linkedCount = scores.filter { !$0.setListItems.isEmpty }.count
        let nextUp = sorted.first(where: { $0.lastOpenedAt != nil }) ?? sorted.first

        return VStack(alignment: .leading, spacing: ASSpacing.xl) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: ASSpacing.xl) {
                    heroIntro
                    heroNowPanel(nextUp: nextUp, linkedCount: linkedCount)
                }

                VStack(alignment: .leading, spacing: ASSpacing.lg) {
                    heroIntro
                    heroNowPanel(nextUp: nextUp, linkedCount: linkedCount)
                }
            }

            HStack(spacing: ASSpacing.md) {
                heroStatCard(value: "\(scores.count)", title: "Library", detail: "\(favoritesCount) favorites")
                heroStatCard(value: "\(recentCount)", title: "This Week", detail: "Active rehearsal material")
                heroStatCard(value: "\(scannedCount)", title: "Scanned", detail: "Cleaned for score reading")
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

    private var heroIntro: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            Text("Stage library")
                .font(ASTypography.displayMedium)
                .foregroundStyle(ASColors.textPrimaryDark)

            Text("A cleaner command center for repertoire, rehearsal copies, and performance-ready scans.")
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func heroNowPanel(nextUp: Score?, linkedCount: Int) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            Text("Now")
                .font(ASTypography.labelMicro)
                .tracking(1.0)
                .foregroundStyle(ASColors.accentFallback)

            if let nextUp {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text(nextUp.title)
                        .font(ASTypography.heading2)
                        .foregroundStyle(ASColors.textPrimaryDark)
                        .lineLimit(2)
                    Text(nextUp.composer.isEmpty ? "Ready to open" : nextUp.composer)
                        .font(ASTypography.bodySmall)
                        .foregroundStyle(ASColors.textSecondaryDark)
                        .lineLimit(1)
                }
            }

            HStack(spacing: ASSpacing.sm) {
                miniInsight(title: "Linked", value: "\(linkedCount)")
                miniInsight(title: "View", value: viewModel.viewMode.rawValue)
                miniInsight(title: "Sort", value: viewModel.sortOrder.rawValue)
            }
        }
        .frame(maxWidth: 340, alignment: .leading)
        .padding(ASSpacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                        .stroke(ASColors.chromeBorder, lineWidth: 1)
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

    private var smartCollectionsStrip: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            librarySectionHeader(
                title: "Smart Collections",
                subtitle: "Saved library slices for cleanup, rehearsal prep, and stage-ready material."
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ASSpacing.md) {
                    smartCollectionChip(title: "All Scores", icon: "square.grid.2x2", isActive: viewModel.activeSmartCollection == nil) {
                        viewModel.activeSmartCollection = nil
                    }

                    ForEach(LibrarySmartCollection.allCases) { collection in
                        smartCollectionChip(
                            title: collection.rawValue,
                            icon: collection.icon,
                            isActive: viewModel.activeSmartCollection == collection
                        ) {
                            viewModel.activeSmartCollection = collection
                        }
                    }
                }
            }
        }
    }

    private func smartCollectionChip(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(ASTypography.labelSmall)
                .padding(.horizontal, ASSpacing.md)
                .padding(.vertical, ASSpacing.sm)
                .background(
                    Capsule()
                        .fill(isActive ? ASColors.accentFallback.opacity(0.14) : ASColors.chromeSurface.opacity(0.84))
                        .overlay(
                            Capsule()
                                .stroke(isActive ? ASColors.accentFallback.opacity(0.4) : ASColors.chromeBorder, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? ASColors.accentFallback : .secondary)
    }

    private func quickCommandDeck(_ sorted: [Score]) -> some View {
        let recent = sorted.first(where: { $0.lastOpenedAt != nil })
        let favorite = scores.first(where: \.isFavorite)

        return VStack(alignment: .leading, spacing: ASSpacing.md) {
            librarySectionHeader(
                title: "Quick Actions",
                subtitle: "Categorized actions reduce friction and match what premium pro apps are doing now."
            )

            ViewThatFits(in: .horizontal) {
                HStack(spacing: ASSpacing.md) {
                    commandCard(
                        title: "Continue Reading",
                        subtitle: recent?.title ?? "Open your most recent score",
                        icon: "play.rectangle",
                        accent: ASColors.info
                    ) {
                        if let recent { viewModel.scoreToOpen = recent }
                    }

                    commandCard(
                        title: "Import & Organize",
                        subtitle: "Bring in PDFs and keep metadata tidy",
                        icon: "square.and.arrow.down.on.square",
                        accent: ASColors.accentFallback
                    ) {
                        viewModel.showingImporter = true
                    }

                    commandCard(
                        title: "Open Favorite",
                        subtitle: favorite?.title ?? "Jump to pinned repertoire",
                        icon: "heart.text.square",
                        accent: ASColors.warning
                    ) {
                        if let favorite { viewModel.scoreToOpen = favorite }
                    }
                }

                VStack(spacing: ASSpacing.md) {
                    commandCard(
                        title: "Continue Reading",
                        subtitle: recent?.title ?? "Open your most recent score",
                        icon: "play.rectangle",
                        accent: ASColors.info
                    ) {
                        if let recent { viewModel.scoreToOpen = recent }
                    }

                    commandCard(
                        title: "Import & Organize",
                        subtitle: "Bring in PDFs and keep metadata tidy",
                        icon: "square.and.arrow.down.on.square",
                        accent: ASColors.accentFallback
                    ) {
                        viewModel.showingImporter = true
                    }

                    commandCard(
                        title: "Open Favorite",
                        subtitle: favorite?.title ?? "Jump to pinned repertoire",
                        icon: "heart.text.square",
                        accent: ASColors.warning
                    ) {
                        if let favorite { viewModel.scoreToOpen = favorite }
                    }
                }
            }
        }
    }

    private func continueShelf(_ sorted: [Score]) -> some View {
        let recentScores = sorted.filter { $0.lastOpenedAt != nil }.prefix(4)
        guard !recentScores.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: ASSpacing.md) {
                librarySectionHeader(
                    title: "Continue",
                    subtitle: "Glanceable shelves help users resume work quickly."
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ASSpacing.md) {
                        ForEach(Array(recentScores), id: \.id) { score in
                            Button {
                                viewModel.scoreToOpen = score
                            } label: {
                                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                                    Text(score.title)
                                        .font(ASTypography.heading3)
                                        .foregroundStyle(ASColors.textPrimaryDark)
                                        .lineLimit(2)

                                    Text(score.composer.isEmpty ? "Score ready" : score.composer)
                                        .font(ASTypography.caption)
                                        .foregroundStyle(ASColors.textSecondaryDark)
                                        .lineLimit(1)

                                    HStack(spacing: ASSpacing.xs) {
                                        Image(systemName: "clock.arrow.circlepath")
                                        Text(relativeTimestamp(for: score.lastOpenedAt ?? score.createdAt))
                                    }
                                    .font(ASTypography.monoMicro)
                                    .foregroundStyle(ASColors.accentFallback)
                                }
                                .frame(width: 220, alignment: .leading)
                                .padding(ASSpacing.cardPadding)
                                .background(
                                    RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.05),
                                                    ASColors.chromeSurfaceElevated
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
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
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

    private func commandCard(title: String, subtitle: String, icon: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ASSpacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                        .fill(accent.opacity(0.14))
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text(title)
                        .font(ASTypography.heading3)
                        .foregroundStyle(ASColors.textPrimaryDark)
                    Text(subtitle)
                        .font(ASTypography.caption)
                        .foregroundStyle(ASColors.textSecondaryDark)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .padding(ASSpacing.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.055),
                                ASColors.chromeSurfaceElevated
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
        .buttonStyle(.plain)
    }

    private func miniInsight(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(ASTypography.labelMicro)
                .tracking(0.9)
                .foregroundStyle(ASColors.textTertiaryDark)
            Text(value)
                .font(ASTypography.bodySmall)
                .foregroundStyle(ASColors.textPrimaryDark)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func relativeTimestamp(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ScoreFamily.name) private var families: [ScoreFamily]
    let score: Score

    private var familyService: ScoreFamilyService {
        ScoreFamilyService(modelContext: modelContext)
    }

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

                Divider()
                familySection
            }
            .padding(ASSpacing.screenPadding)
        }
        .inspectorColumnWidth(min: 240, ideal: 300, max: 380)
    }

    @ViewBuilder
    private var familySection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("SCORE FAMILY")
                .font(ASTypography.labelMicro)
                .foregroundStyle(.secondary)
                .tracking(0.5)

            if let family = score.family {
                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text(family.name)
                        .font(ASTypography.label)

                    if !family.composer.isEmpty {
                        Text(family.composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Role", selection: roleBinding(for: family)) {
                        ForEach(ScoreRole.allCases, id: \.self) { role in
                            Text(roleLabel(role)).tag(role)
                        }
                    }
                    .pickerStyle(.menu)

                    if family.scores.count > 1 {
                        VStack(alignment: .leading, spacing: ASSpacing.xs) {
                            Text("RELATED SCORES")
                                .font(ASTypography.labelSmall)
                                .foregroundStyle(.secondary)

                            ForEach(family.scores.filter { $0.id != score.id }.sorted { $0.title < $1.title }, id: \.id) { sibling in
                                HStack {
                                    Text(sibling.title)
                                        .font(ASTypography.bodySmall)
                                    Spacer()
                                    Text(roleLabel(family.role(for: sibling)))
                                        .font(ASTypography.captionSmall)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    Button("Remove From Family", role: .destructive) {
                        familyService.removeScore(score, from: family)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Button("Create Family From Score") {
                        let family = familyService.createFamily(
                            name: score.title,
                            composer: score.composer,
                            scores: [score]
                        )
                        familyService.setRole(.fullScore, for: score, in: family)
                    }
                    .buttonStyle(.borderedProminent)

                    if !families.isEmpty {
                        Menu("Join Existing Family") {
                            ForEach(families, id: \.id) { family in
                                Menu(family.name) {
                                    ForEach(ScoreRole.allCases, id: \.self) { role in
                                        Button(roleLabel(role)) {
                                            familyService.addScore(score, to: family, role: role)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
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

    private func roleBinding(for family: ScoreFamily) -> Binding<ScoreRole> {
        Binding(
            get: { family.role(for: score) },
            set: { newRole in
                familyService.setRole(newRole, for: score, in: family)
            }
        )
    }

    private func roleLabel(_ role: ScoreRole) -> String {
        switch role {
        case .fullScore:
            return "Full Score"
        case .part:
            return "Part"
        case .pianoReduction:
            return "Piano Reduction"
        case .alternateEdition:
            return "Alternate Edition"
        case .arrangement:
            return "Arrangement"
        }
    }
}
