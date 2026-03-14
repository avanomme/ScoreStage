import SwiftUI
import SwiftData
import DesignSystem
import LibraryFeature
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
        case library = "Library"
        case browse = "Browse"
        case performance = "Performance"
        case app = "App"
    }
}

struct ContentView: View {
    @State private var selectedItem: LibrarySidebarItem? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
            List(selection: $selectedItem) {
                ForEach(LibrarySidebarItem.SidebarSection.allCases, id: \.self) { section in
                    let items = LibrarySidebarItem.allCases.filter { $0.section == section }
                    Section(section.rawValue) {
                        ForEach(items) { item in
                            Label(item.title, systemImage: item.icon)
                                .tag(item)
                        }
                    }
                }
            }
            .navigationTitle("ScoreStage")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            NavigationStack {
                detailContent(for: selectedItem ?? .library)
            }
        }
    }

    // MARK: - Compact Layout (iPhone)

    #if os(iOS)
    private var compactLayout: some View {
        TabView {
            NavigationStack {
                LibraryHomeView(filter: .all)
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
    }
    #endif

    // MARK: - Detail Content

    @ViewBuilder
    private func detailContent(for item: LibrarySidebarItem) -> some View {
        switch item {
        case .library:
            LibraryHomeView(filter: .all)
        case .recentlyPlayed:
            LibraryHomeView(filter: .recentlyPlayed)
        case .favorites:
            LibraryHomeView(filter: .favorites)
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
}

#Preview {
    ContentView()
}
