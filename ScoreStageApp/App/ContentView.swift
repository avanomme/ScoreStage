import SwiftUI
import DesignSystem
import LibraryFeature
import SetlistFeature
import CoreDomain

enum AppTab: String, CaseIterable, Identifiable {
    case library
    case setlists
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .library: "Library"
        case .setlists: "Setlists"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .library: "music.note.list"
        case .setlists: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        #if os(macOS)
        sidebarLayout
        #else
        adaptiveLayout
        #endif
    }

    // MARK: - iPad/iPhone tab bar
    private var adaptiveLayout: some View {
        TabView(selection: $selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack {
                    tabContent(for: tab)
                }
                .tabItem {
                    Label(tab.title, systemImage: tab.icon)
                }
                .tag(tab)
            }
        }
    }

    // MARK: - macOS sidebar
    #if os(macOS)
    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(AppTab.allCases, selection: $selectedTab) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("ScoreStage")
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            NavigationStack {
                tabContent(for: selectedTab)
            }
        }
    }
    #endif

    @ViewBuilder
    private func tabContent(for tab: AppTab) -> some View {
        switch tab {
        case .library:
            LibraryHomeView()
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
