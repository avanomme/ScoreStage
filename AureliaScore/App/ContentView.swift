import SwiftUI
import DesignSystem

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
            .navigationTitle("Aurelia Score")
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
            LibraryPlaceholderView()
        case .setlists:
            SetlistsPlaceholderView()
        case .settings:
            SettingsPlaceholderView()
        }
    }
}

// MARK: - Placeholder Views (to be replaced by feature modules)

struct LibraryPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            icon: "music.note.list",
            title: "No Scores Yet",
            message: "Import your sheet music to get started.",
            actionTitle: "Import Score"
        ) {}
        .navigationTitle("Library")
    }
}

struct SetlistsPlaceholderView: View {
    var body: some View {
        EmptyStateView(
            icon: "list.bullet.rectangle",
            title: "No Setlists",
            message: "Create a setlist to organize your performances."
        )
        .navigationTitle("Setlists")
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        Form {
            Section("General") {
                Text("Settings will appear here")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

#Preview {
    ContentView()
}
