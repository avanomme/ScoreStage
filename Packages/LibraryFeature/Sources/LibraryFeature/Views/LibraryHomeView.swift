import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public enum LibrarySortOrder: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case title = "Title"
    case composer = "Composer"
    case genre = "Genre"
    case difficulty = "Difficulty"

    public var id: String { rawValue }
}

public enum LibraryViewMode: String, CaseIterable {
    case grid
    case list
}

@MainActor
@Observable
public final class LibraryViewModel {
    public var searchText = ""
    public var sortOrder: LibrarySortOrder = .recent
    public var viewMode: LibraryViewMode = .grid
    public var showingImporter = false
    public var showingMetadataEditor = false
    public var selectedScore: Score?
    public var filterFavoritesOnly = false

    public init() {}

    public func sortedScores(_ scores: [Score]) -> [Score] {
        var filtered = scores.filter { !$0.isArchived }

        if filterFavoritesOnly {
            filtered = filtered.filter { $0.isFavorite }
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

public struct LibraryHomeView: View {
    @Query private var scores: [Score]
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    private let importService = ScoreImportService()

    public init() {}

    public var body: some View {
        Group {
            if scores.isEmpty {
                EmptyStateView(
                    icon: "music.note.list",
                    title: "No Scores Yet",
                    message: "Import your sheet music to get started.",
                    actionTitle: "Import Score"
                ) {
                    viewModel.showingImporter = true
                }
            } else {
                scoreListContent
            }
        }
        .navigationTitle("Library")
        .searchable(text: $viewModel.searchText, prompt: "Search scores")
        .toolbar { libraryToolbar }
        .animation(.easeInOut(duration: 0.3), value: viewModel.viewMode)
        .scoreFileImporter(isPresented: $viewModel.showingImporter) { urls in
            Task { try? await importService.importFiles(from: urls, into: modelContext) }
        }
        .sheet(item: $viewModel.selectedScore) { score in
            ScoreMetadataEditor(score: score)
        }
    }

    @ViewBuilder
    private var scoreListContent: some View {
        let sorted = viewModel.sortedScores(scores)
        if viewModel.viewMode == .grid {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: ASSpacing.lg) {
                    ForEach(sorted) { score in
                        ScoreGridItem(score: score)
                            .contextMenu { scoreContextMenu(for: score) }
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .padding(ASSpacing.screenPadding)
                .animation(.easeInOut(duration: 0.3), value: viewModel.sortOrder)
                .animation(.easeInOut(duration: 0.3), value: viewModel.filterFavoritesOnly)
                .animation(.easeInOut(duration: 0.3), value: viewModel.searchText)
            }
        } else {
            List(sorted) { score in
                ScoreListItem(score: score)
                    .contextMenu { scoreContextMenu(for: score) }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.sortOrder)
        }
    }

    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: ASSpacing.lg)]
        #else
        [GridItem(.adaptive(minimum: 140, maximum: 200), spacing: ASSpacing.lg)]
        #endif
    }

    @ToolbarContentBuilder
    private var libraryToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label("Import", systemImage: "plus")
            }
        }
        ToolbarItem {
            Picker("View", selection: $viewModel.viewMode) {
                Image(systemName: "square.grid.2x2").tag(LibraryViewMode.grid)
                Image(systemName: "list.bullet").tag(LibraryViewMode.list)
            }
            .pickerStyle(.segmented)
        }
        ToolbarItem {
            Menu {
                Picker("Sort", selection: $viewModel.sortOrder) {
                    ForEach(LibrarySortOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                Divider()
                Toggle("Favorites Only", isOn: $viewModel.filterFavoritesOnly)
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
        }
    }

    @ViewBuilder
    private func scoreContextMenu(for score: Score) -> some View {
        Button {
            score.isFavorite.toggle()
        } label: {
            Label(
                score.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: score.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button {
            viewModel.selectedScore = score
        } label: {
            Label("Edit Metadata", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            modelContext.delete(score)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Grid and List Items

struct ScoreGridItem: View {
    let score: Score
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ASRadius.sm)
                    .fill(Color.gray.opacity(0.08))
                    .aspectRatio(0.75, contentMode: .fit)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }

                if score.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(ASSpacing.sm)
                }
            }

            VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                Text(score.title)
                    .font(ASTypography.label)
                    .lineLimit(2)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .shadow(color: .black.opacity(isHovering ? 0.08 : 0), radius: 8, y: 4)
        .animation(.easeInOut(duration: 0.2), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ScoreListItem: View {
    let score: Score

    var body: some View {
        HStack(spacing: ASSpacing.md) {
            RoundedRectangle(cornerRadius: ASRadius.sm)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 44, height: 56)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.tertiary)
                }

            VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                Text(score.title)
                    .font(ASTypography.body)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if score.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}
