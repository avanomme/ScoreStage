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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ASColors.chromeBackground)
        .navigationTitle(navigationTitle)
        .searchable(text: $viewModel.searchText, prompt: "Search scores, composers, tags...")
        .toolbar { libraryToolbar }
        .scoreFileImporter(isPresented: $viewModel.showingImporter) { urls in
            Task { let _ = try? await importService.importFiles(from: urls, into: modelContext) }
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
            LazyVGrid(columns: gridColumns, spacing: ASSpacing.cardGap) {
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
        [GridItem(.adaptive(minimum: 170, maximum: 210), spacing: ASSpacing.cardGap)]
        #else
        [GridItem(.adaptive(minimum: 140, maximum: 170), spacing: ASSpacing.lg)]
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

// MARK: - Score Cover Card (Album Art Style — spec Section E.2)

struct ScoreCoverCard: View {
    let score: Score
    let isSelected: Bool
    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            // Cover thumbnail — resembles album art / score cover
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: colorScheme == .dark
                                ? [ASColors.cardGradientTopDark, ASColors.cardGradientBottomDark]
                                : [ASColors.cardGradientTopLight, ASColors.cardGradientBottomLight],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .aspectRatio(0.77, contentMode: .fit)
                    .overlay {
                        VStack(spacing: ASSpacing.sm) {
                            Image(systemName: "music.note")
                                .font(.system(size: 28, weight: .ultraLight))
                                .foregroundStyle(ASColors.tertiaryText)

                            Text(score.title)
                                .font(ASTypography.cardTitle)
                                .foregroundStyle(ASColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, ASSpacing.sm)

                            if !score.composer.isEmpty {
                                Text(score.composer)
                                    .font(ASTypography.cardSubtitle)
                                    .foregroundStyle(ASColors.tertiaryText)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: ASRadius.card, style: .continuous)
                            .strokeBorder(
                                isSelected ? ASColors.accentFallback : Color.clear,
                                lineWidth: 2.5
                            )
                    )
                    .shadow(
                        color: .black.opacity(isHovering ? 0.18 : 0.10),
                        radius: isHovering ? 14 : 6,
                        y: isHovering ? 6 : 3
                    )

                // Favorite badge — 24pt circle, accent at 90%
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

            // Metadata below cover
            VStack(alignment: .leading, spacing: 2) {
                Text(score.title)
                    .font(ASTypography.cardMetaTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.cardMetaSubtitle)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if score.duration > 0 {
                    Text(formatDuration(score.duration))
                        .font(ASTypography.captionSmall)
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
