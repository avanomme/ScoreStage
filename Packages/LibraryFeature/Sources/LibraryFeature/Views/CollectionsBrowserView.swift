import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public enum BrowseMode: String, CaseIterable {
    case composers = "Composers"
    case genres = "Genres"
    case tags = "Tags"
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
            }
        }
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

    private func filteredScoresList(title: String, predicate: @escaping (Score) -> Bool) -> some View {
        let filtered = scores.filter(predicate)
        return List(filtered) { score in
            HStack {
                VStack(alignment: .leading) {
                    Text(score.title)
                        .font(.system(size: 14, weight: .medium))
                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(title)
    }
}
