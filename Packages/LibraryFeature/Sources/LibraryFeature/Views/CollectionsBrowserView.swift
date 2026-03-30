import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public enum BrowseMode: String, CaseIterable {
    case composers = "Composers"
    case genres = "Genres"
    case tags = "Tags"
    case smart = "Smart Collections"
}

public struct CollectionsBrowserView: View {
    @Query private var scores: [Score]
    private let mode: BrowseMode

    public init(mode: BrowseMode = .composers) {
        self.mode = mode
    }

    public var body: some View {
        List {
            switch mode {
            case .tags:
                tagsSection
            case .composers:
                composersSection
            case .genres:
                genresSection
            case .smart:
                smartCollectionsSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeBackground)
        .navigationTitle(mode.rawValue)
    }

    private var tagsSection: some View {
        let allTags = Set(scores.flatMap { $0.customTags }).sorted()
        return ForEach(allTags, id: \.self) { tag in
            NavigationLink(tag) {
                filteredScoresList(title: tag) { $0.customTags.contains(tag) }
            }
            .badge(scores.filter { $0.customTags.contains(tag) }.count)
        }
    }

    private var composersSection: some View {
        let composers = Set(scores.map { $0.composer }).filter { !$0.isEmpty }.sorted()
        return ForEach(composers, id: \.self) { composer in
            NavigationLink(composer) {
                filteredScoresList(title: composer) { $0.composer == composer }
            }
            .badge(scores.filter { $0.composer == composer }.count)
        }
    }

    private var genresSection: some View {
        let genres = Set(scores.map { $0.genre }).filter { !$0.isEmpty }.sorted()
        return ForEach(genres, id: \.self) { genre in
            NavigationLink(genre) {
                filteredScoresList(title: genre) { $0.genre == genre }
            }
            .badge(scores.filter { $0.genre == genre }.count)
        }
    }

    private var smartCollectionsSection: some View {
        ForEach(LibrarySmartCollection.allCases) { collection in
            NavigationLink(collection.rawValue) {
                filteredScoresList(title: collection.rawValue) { score in
                    switch collection {
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
            .badge(smartCollectionCount(collection))
        }
    }

    private func filteredScoresList(title: String, predicate: @escaping (Score) -> Bool) -> some View {
        let filtered = scores.filter(predicate)
        return List(filtered) { score in
            HStack {
                VStack(alignment: .leading) {
                    Text(score.title)
                        .font(ASTypography.label)
                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(title)
    }

    private func smartCollectionCount(_ collection: LibrarySmartCollection) -> Int {
        scores.filter { score in
            switch collection {
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
        }.count
    }
}
