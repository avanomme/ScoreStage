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
    @Environment(\.modelContext) private var modelContext
    @State private var selectedItem: LibrarySidebarItem? = .library
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var openedScore: Score?
    @State private var openedFileURL: URL?
    @State private var openedMusicXMLURL: URL?
    @State private var openedSetlistItems: [SetListItem]?
    @State private var openedSetlistIndex: Int?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let importService = ScoreImportService()

    var body: some View {
        Group {
            if let score = openedScore, let url = openedFileURL {
                // Full-window reader — takes over entire window like a music book
                ScoreReaderView(
                            score: score,
                            fileURL: url,
                            musicXMLURL: openedMusicXMLURL,
                            onClose: closeScore,
                            setlistItems: openedSetlistItems,
                            currentSetlistIndex: openedSetlistIndex,
                            onNavigateSetlist: navigateSetlistItem
                        )
                    .transition(.move(edge: .trailing))
            } else {
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
        }
        .onAppear(perform: seedOwnerAdminIfNeeded)
    }

    private func seedOwnerAdminIfNeeded() {
        _ = AccountBootstrap.seedOwnerAccount(in: modelContext)
    }

    // MARK: - Sidebar Layout (iPad / macOS)

    private var sidebarLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            detailContent(for: selectedItem ?? .library)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(detailBackdrop)
        }
        .tint(ASColors.accentFallback)
    }

    private var sidebarContent: some View {
        ZStack {
            sidebarBackdrop

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    sidebarHeader

                    ForEach(LibrarySidebarItem.SidebarSection.allCases, id: \.self) { section in
                        let items = LibrarySidebarItem.allCases.filter { $0.section == section }
                        sidebarSection(section, items: items)
                    }

                    sidebarFooter
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeSurface)
    }

    @ViewBuilder
    private func sidebarSection(_ section: LibrarySidebarItem.SidebarSection, items: [LibrarySidebarItem]) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.xxs) {
            Text(section.rawValue)
                .font(ASTypography.labelMicro)
                .foregroundStyle(ASColors.textTertiaryDark)
                .tracking(1.2)
                .padding(.horizontal, ASSpacing.lg)
                .padding(.top, ASSpacing.xl)
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
                    .foregroundStyle(isSelected ? ASColors.textPrimaryDark : ASColors.textSecondaryDark)
                    .frame(width: 22)
                    .overlay(alignment: .leading) {
                        if isSelected {
                            Capsule()
                                .fill(ASColors.accentFallback)
                                .frame(width: 3, height: 20)
                                .offset(x: -12)
                        }
                    }

                Text(item.title)
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(isSelected ? ASColors.textPrimaryDark : ASColors.textSecondaryDark)

                Spacer()
            }
            .padding(.horizontal, ASSpacing.md)
            .padding(.vertical, ASSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(
                                colors: [
                                    ASColors.accentFallback.opacity(0.18),
                                    ASColors.chromeSurfaceSelected
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [
                                    Color.white.opacity(0.02),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous)
                            .stroke(isSelected ? ASColors.accentFallback.opacity(0.4) : ASColors.chromeBorder.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding(.horizontal, ASSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text("ScoreStage")
                        .font(ASTypography.displaySmall)
                        .foregroundStyle(ASColors.textPrimaryDark)

                    Text("Performance library")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(ASColors.accentFallback)
                        .textCase(.uppercase)
                        .tracking(1.1)
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(ASColors.accentFallback.opacity(0.16))
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(ASColors.accentFallback)
                }
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text("Built for rehearsal rooms, pits, and concert stages.")
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(ASColors.textSecondaryDark)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: ASSpacing.sm) {
                    sidebarBadge("Library", icon: "music.note.list")
                    sidebarBadge("Reader", icon: "book.pages")
                }
            }
        }
        .padding(ASSpacing.screenPadding)
        .background(
            RoundedRectangle(cornerRadius: ASRadius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            ASColors.chromeSurfaceElevated.opacity(0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: ASRadius.xl, style: .continuous)
                        .stroke(ASColors.accentFallback.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(.horizontal, ASSpacing.md)
        .padding(.top, ASSpacing.md)
    }

    private func sidebarBadge(_ title: String, icon: String) -> some View {
        HStack(spacing: ASSpacing.xs) {
            Image(systemName: icon)
            Text(title)
        }
        .font(ASTypography.monoMicro)
        .foregroundStyle(ASColors.textSecondaryDark)
        .padding(.horizontal, ASSpacing.sm)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
        )
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Divider()
                .overlay(ASColors.chromeBorderStrong)
                .padding(.bottom, ASSpacing.sm)

            Text("Stage-ready by design")
                .font(ASTypography.heading3)
                .foregroundStyle(ASColors.textPrimaryDark)

            Text("Setlists, annotations, playback, and linked performance views live in one workspace.")
                .font(ASTypography.caption)
                .foregroundStyle(ASColors.textSecondaryDark)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ASSpacing.screenPadding)
    }

    private var sidebarBackdrop: some View {
        ZStack {
            LinearGradient(
                colors: [
                    ASColors.chromeBackground,
                    ASColors.chromeSurface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    ASColors.accentFallback.opacity(0.18),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 20,
                endRadius: 320
            )
            .offset(x: -30, y: -50)
        }
        .ignoresSafeArea()
    }

    private var detailBackdrop: some View {
        ZStack {
            ASColors.chromeBackground

            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.18)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [
                    ASColors.accentFallback.opacity(0.08),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 400
            )
        }
        .ignoresSafeArea()
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
                        SetlistDetailView(setlist: setlist) { score, items, index in
                            openSetlistScore(score, items: items, index: index)
                        }
                    }
            }
            .tabItem { Label("Setlists", systemImage: "list.bullet.rectangle") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(ASColors.accentFallback)
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
            NavigationStack {
                SetlistListView()
                    .navigationDestination(for: SetList.self) { setlist in
                        SetlistDetailView(setlist: setlist) { score, items, index in
                            openSetlistScore(score, items: items, index: index)
                        }
                    }
            }
        case .settings:
            SettingsView()
        }
    }

    // MARK: - Open / Close Score

    private func openScore(_ score: Score) {
        // Find the primary display asset (PDF preferred, or whatever is primary)
        let displayAsset = score.assets.first(where: { $0.isPrimary }) ?? score.assets.first(where: { $0.type == .pdf }) ?? score.assets.first
        guard let asset = displayAsset else { return }

        do {
            let url = try importService.fileURL(for: asset)
            score.lastOpenedAt = Date()

            // Also look for a MusicXML asset for playback
            var xmlURL: URL? = nil
            if let xmlAsset = score.assets.first(where: { $0.type == .musicXML }) {
                xmlURL = try? importService.fileURL(for: xmlAsset)
            }
            // If the primary file itself is MusicXML, use it for both display and playback
            if asset.type == .musicXML {
                xmlURL = url
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                openedFileURL = url
                openedMusicXMLURL = xmlURL
                openedScore = score
            }
        } catch {
            // File not found
        }
    }

    private func openSetlistScore(_ score: Score, items: [SetListItem], index: Int) {
        openedSetlistItems = items
        openedSetlistIndex = index
        openScore(score)
    }

    private func navigateSetlistItem(_ index: Int) {
        guard let items = openedSetlistItems,
              index >= 0 && index < items.count,
              let score = items[index].score else { return }
        openedSetlistIndex = index
        openScore(score)
    }

    private func closeScore() {
        withAnimation(.easeInOut(duration: 0.2)) {
            openedScore = nil
            openedFileURL = nil
            openedMusicXMLURL = nil
            openedSetlistItems = nil
            openedSetlistIndex = nil
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
