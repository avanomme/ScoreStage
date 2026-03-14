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

@MainActor
@Observable
public final class LibraryViewModel {
    public var searchText = ""
    public var sortOrder: LibrarySortOrder = .recent
    public var showingImporter = false
    public var inspectedScore: Score?

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

    public init(filter: LibraryFilter = .all) {
        self.filter = filter
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
                scoreGrid(sorted)
            }
        }
        .navigationTitle(navigationTitle)
        .searchable(text: $viewModel.searchText, prompt: "Search scores")
        .toolbar { libraryToolbar }
        .scoreFileImporter(isPresented: $viewModel.showingImporter) { urls in
            Task { try? await importService.importFiles(from: urls, into: modelContext) }
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

    // MARK: - Score Grid (Cover Art Style)

    private func scoreGrid(_ sorted: [Score]) -> some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: ASSpacing.xl) {
                ForEach(sorted) { score in
                    ScoreCoverCard(score: score, isSelected: viewModel.inspectedScore?.id == score.id)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.inspectedScore = score
                            }
                        }
                        .contextMenu { scoreContextMenu(for: score) }
                }
            }
            .padding(ASSpacing.screenPadding)
            .animation(.easeInOut(duration: 0.25), value: viewModel.sortOrder)
            .animation(.easeInOut(duration: 0.25), value: viewModel.searchText)
        }
    }

    private var gridColumns: [GridItem] {
        #if os(macOS)
        [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: ASSpacing.xl)]
        #else
        [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: ASSpacing.lg)]
        #endif
    }

    // MARK: - Toolbar

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
}

// MARK: - Score Cover Card (Album Art Style)

struct ScoreCoverCard: View {
    let score: Score
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            // Cover thumbnail — resembles album art / score cover
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.95), Color(white: 0.88)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .aspectRatio(0.77, contentMode: .fit)
                    .overlay {
                        VStack(spacing: ASSpacing.sm) {
                            Image(systemName: "music.note")
                                .font(.system(size: 32, weight: .ultraLight))
                                .foregroundStyle(Color(white: 0.6))

                            Text(score.title)
                                .font(.system(size: 11, weight: .medium, design: .serif))
                                .foregroundStyle(Color(white: 0.4))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, ASSpacing.sm)

                            if !score.composer.isEmpty {
                                Text(score.composer)
                                    .font(.system(size: 9, weight: .regular))
                                    .foregroundStyle(Color(white: 0.55))
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous)
                            .strokeBorder(
                                isSelected ? ASColors.accentFallback : Color.clear,
                                lineWidth: 2.5
                            )
                    )
                    .shadow(
                        color: .black.opacity(isHovering ? 0.15 : 0.08),
                        radius: isHovering ? 12 : 6,
                        y: isHovering ? 6 : 3
                    )

                if score.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(ASColors.accentFallback.opacity(0.85))
                        .clipShape(Circle())
                        .padding(6)
                }
            }

            // Metadata below cover
            VStack(alignment: .leading, spacing: 2) {
                Text(score.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if score.duration > 0 {
                    Text(formatDuration(score.duration))
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
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
}

// MARK: - Inspector Panel

struct ScoreInspectorPanel: View {
    let score: Score

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.sectionSpacing) {
                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text(score.title)
                        .font(.system(size: 20, weight: .semibold))

                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }

                    if !score.arranger.isEmpty {
                        Text("arr. \(score.arranger)")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: ASSpacing.md) {
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

                if !score.customTags.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: ASSpacing.sm) {
                        Text("Tags")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        FlowLayout(spacing: ASSpacing.xs) {
                            ForEach(score.customTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, ASSpacing.sm)
                                    .padding(.vertical, 3)
                                    .background(ASColors.accentFallback.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if !score.notes.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: ASSpacing.sm) {
                        Text("Notes")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(score.notes)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
        }
        .inspectorColumnWidth(min: 220, ideal: 280, max: 350)
    }

    @ViewBuilder
    private func inspectorRow(_ label: String, value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 13))
            }
        }
    }
}
