import SwiftUI
import SwiftData
import DesignSystem
import LibraryFeature
import ReaderFeature
import SetlistFeature
import CoreDomain

// MARK: - Library Sidebar Navigation

enum LibrarySidebarItem: String, CaseIterable, Identifiable, Hashable {
    case library
    case recentlyPlayed
    case favorites
    case composers
    case genres
    case setlists
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "Library"
        case .recentlyPlayed: "Recently Played"
        case .favorites: "Favorites"
        case .composers: "Composers"
        case .genres: "Genres"
        case .setlists: "Set Lists"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .library: "music.note.list"
        case .recentlyPlayed: "clock"
        case .favorites: "heart"
        case .composers: "person.2"
        case .genres: "guitars"
        case .setlists: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }

    var section: SidebarSection {
        switch self {
        case .library, .recentlyPlayed, .favorites: .library
        case .composers, .genres: .browse
        case .setlists: .performance
        case .settings: .app
        }
    }

    enum SidebarSection: String, CaseIterable {
        case library = "LIBRARY"
        case browse = "BROWSE"
        case performance = "PERFORMANCE"
        case app = "APP"
    }
}

struct ContentView: View {
    @State private var selectedItem: LibrarySidebarItem? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var scoreToOpen: Score?
    @State private var readerFileURL: URL?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let importService = ScoreImportService()

    var body: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactLayout
        } else {
            sidebarLayout
        }
        #else
        sidebarLayout
        #endif
    }

    // MARK: - Sidebar Layout (iPad / macOS)

    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            detailContent(for: selectedItem ?? .library)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(ASColors.chromeBackground)
        }
        .tint(ASColors.accentFallback)
        #if os(iOS)
        .fullScreenCover(item: $scoreToOpen) { score in
            if let url = readerFileURL {
                ScoreReaderView(score: score, fileURL: url)
            }
        }
        #else
        .sheet(item: $scoreToOpen) { score in
            if let url = readerFileURL {
                ScoreReaderView(score: score, fileURL: url)
                    .frame(minWidth: 800, minHeight: 600)
            }
        }
        #endif
    }

    private var sidebarContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // App title
                Text("ScoreStage")
                    .font(ASTypography.heading2)
                    .foregroundStyle(ASColors.textPrimaryDark)
                    .padding(.horizontal, ASSpacing.lg)
                    .padding(.top, ASSpacing.xl)
                    .padding(.bottom, ASSpacing.lg)

                ForEach(LibrarySidebarItem.SidebarSection.allCases, id: \.self) { section in
                    let items = LibrarySidebarItem.allCases.filter { $0.section == section }
                    sidebarSection(section, items: items)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeSurface)
    }

    @ViewBuilder
    private func sidebarSection(_ section: LibrarySidebarItem.SidebarSection, items: [LibrarySidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.xxs) {
            // Section header
            Text(section.rawValue)
                .font(ASTypography.labelMicro)
                .foregroundStyle(ASColors.textTertiaryDark)
                .tracking(0.5)
                .padding(.horizontal, ASSpacing.lg)
                .padding(.top, ASSpacing.lg)
                .padding(.bottom, ASSpacing.xs)

            ForEach(items) { item in
                sidebarRow(item)
            }
        }
    }

    private func sidebarRow(_ item: LibrarySidebarItem) -> some View {
        let isSelected = selectedItem == item
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedItem = item
            }
        } label: {
            HStack(spacing: ASSpacing.md) {
                Image(systemName: item.icon)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(isSelected ? ASColors.accentFallback : ASColors.textSecondaryDark)
                    .frame(width: 22)

                Text(item.title)
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(isSelected ? ASColors.textPrimaryDark : ASColors.textSecondaryDark)

                Spacer()
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                    .fill(isSelected ? ASColors.chromeSurfaceSelected : Color.clear)
            )
            .padding(.horizontal, ASSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Compact Layout (iPhone)

    #if os(iOS)
    private var compactLayout: some View {
        TabView {
            NavigationStack {
                LibraryHomeView(filter: .all, onOpen: openScore)
            }
            .tabItem { Label("Library", systemImage: "music.note.list") }

            NavigationStack {
                SetlistListView()
                    .navigationDestination(for: SetList.self) { setlist in
                        SetlistDetailView(setlist: setlist)
                    }
            }
            .tabItem { Label("Setlists", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(ASColors.accentFallback)
        .fullScreenCover(item: $scoreToOpen) { score in
            if let url = readerFileURL {
                ScoreReaderView(score: score, fileURL: url)
            }
        }
    }
    #endif

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(for item: LibrarySidebarItem) -> some View {
        switch item {
        case .library:
            LibraryHomeView(filter: .all, onOpen: openScore)
        case .recentlyPlayed:
            LibraryHomeView(filter: .recentlyPlayed, onOpen: openScore)
        case .favorites:
            LibraryHomeView(filter: .favorites, onOpen: openScore)
        case .composers:
            CollectionsBrowserView(mode: .composers)
        case .genres:
            CollectionsBrowserView(mode: .genres)
        case .setlists:
            SetlistListView()
                .navigationDestination(for: SetList.self) { setlist in
                    SetlistDetailView(setlist: setlist)
                }
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Open Score

    private func openScore(_ score: Score) {
        guard let primaryAsset = score.assets.first(where: { $0.isPrimary }) ?? score.assets.first else { return }
        do {
            let url = try importService.fileURL(for: primaryAsset)
            score.lastOpenedAt = Date()
            readerFileURL = url
            scoreToOpen = score
        } catch {
            // File not found — could show alert
        }
    }

    @ViewBuilder
    private var readerPresentation: some View {
        if let score = scoreToOpen, let url = readerFileURL {
            ScoreReaderView(score: score, fileURL: url)
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
