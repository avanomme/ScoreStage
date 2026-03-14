import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct SetlistDetailView: View {
    @Bindable var setlist: SetList
    @Environment(\.modelContext) private var modelContext
    @State private var showingAddScores = false
    @Query private var allScores: [Score]
    private let onOpenScore: ((Score, [SetListItem], Int) -> Void)?

    public init(setlist: SetList, onOpenScore: ((Score, [SetListItem], Int) -> Void)? = nil) {
        self.setlist = setlist
        self.onOpenScore = onOpenScore
    }

    private var sortedItems: [SetListItem] {
        setlist.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func sortSetlistItems(by comparator: (SetListItem, SetListItem) -> Bool) {
        let sorted = setlist.items.sorted(by: comparator)
        for (index, item) in sorted.enumerated() {
            item.sortOrder = index
        }
        setlist.modifiedAt = Date()
    }

    private func reverseSetlistItems() {
        let items = sortedItems.reversed()
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        setlist.modifiedAt = Date()
    }

    private func shuffleSetlistItems() {
        let items = sortedItems.shuffled()
        for (index, item) in items.enumerated() {
            item.sortOrder = index
        }
        setlist.modifiedAt = Date()
    }

    public var body: some View {
        List {
            Section {
                TextField("Description", text: $setlist.eventDescription, axis: .vertical)
                DatePicker("Event Date", selection: Binding(
                    get: { setlist.eventDate ?? Date() },
                    set: { setlist.eventDate = $0 }
                ), displayedComponents: .date)
            }

            Section("Scores") {
                if sortedItems.isEmpty {
                    Text("No scores added yet")
                        .foregroundStyle(.secondary)
                        .font(ASTypography.body)
                } else {
                    ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                        SetlistItemRow(item: item, index: index + 1)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if let score = item.score {
                                    onOpenScore?(score, sortedItems, index)
                                }
                            }
                    }
                    .onDelete { indexSet in
                        let items = sortedItems
                        for index in indexSet {
                            modelContext.delete(items[index])
                        }
                    }
                    .onMove { source, destination in
                        var items = sortedItems
                        items.move(fromOffsets: source, toOffset: destination)
                        for (index, item) in items.enumerated() {
                            item.sortOrder = index
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeBackground)
        .navigationTitle(setlist.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddScores = true
                } label: {
                    Label("Add Scores", systemImage: "plus")
                }
            }
            ToolbarItem {
                Menu {
                    Section("Sort Scores") {
                        Button {
                            sortSetlistItems { ($0.score?.title ?? "").localizedCaseInsensitiveCompare($1.score?.title ?? "") == .orderedAscending }
                        } label: {
                            Label("By Title (A–Z)", systemImage: "textformat.abc")
                        }
                        Button {
                            sortSetlistItems { ($0.score?.title ?? "").localizedCaseInsensitiveCompare($1.score?.title ?? "") == .orderedDescending }
                        } label: {
                            Label("By Title (Z–A)", systemImage: "textformat.abc")
                        }
                        Button {
                            sortSetlistItems { ($0.score?.composer ?? "").localizedCaseInsensitiveCompare($1.score?.composer ?? "") == .orderedAscending }
                        } label: {
                            Label("By Composer", systemImage: "person")
                        }
                        Button {
                            sortSetlistItems { ($0.score?.genre ?? "").localizedCaseInsensitiveCompare($1.score?.genre ?? "") == .orderedAscending }
                        } label: {
                            Label("By Genre", systemImage: "guitars")
                        }
                        Button {
                            sortSetlistItems { ($0.score?.difficulty ?? 0) < ($1.score?.difficulty ?? 0) }
                        } label: {
                            Label("By Difficulty", systemImage: "chart.bar")
                        }
                        Button {
                            sortSetlistItems { ($0.score?.duration ?? 0) < ($1.score?.duration ?? 0) }
                        } label: {
                            Label("By Duration", systemImage: "clock")
                        }
                    }
                    Section {
                        Button {
                            reverseSetlistItems()
                        } label: {
                            Label("Reverse Order", systemImage: "arrow.up.arrow.down")
                        }
                        Button {
                            shuffleSetlistItems()
                        } label: {
                            Label("Shuffle", systemImage: "shuffle")
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingAddScores) {
            AddScoresToSetlistView(setlist: setlist, allScores: allScores)
        }
    }
}

struct SetlistItemRow: View {
    let item: SetListItem
    let index: Int

    var body: some View {
        HStack(spacing: ASSpacing.md) {
            // Track number
            Text("\(index)")
                .font(ASTypography.monoSmall)
                .foregroundStyle(.tertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                Text(item.score?.title ?? "Unknown Score")
                    .font(ASTypography.body)

                HStack(spacing: ASSpacing.sm) {
                    if let composer = item.score?.composer, !composer.isEmpty {
                        Text(composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !item.performanceNotes.isEmpty {
                        Text(item.performanceNotes)
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }

                if item.pauseDuration > 0 {
                    Label("\(Int(item.pauseDuration))s pause", systemImage: "timer")
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, ASSpacing.xxs)
    }
}

enum AddScoresSortOrder: String, CaseIterable {
    case title = "Title"
    case composer = "Composer"
    case genre = "Genre"
    case recent = "Recent"
}

struct AddScoresToSetlistView: View {
    let setlist: SetList
    let allScores: [Score]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScoreIDs: Set<UUID> = []
    @State private var searchText = ""
    @State private var sortOrder: AddScoresSortOrder = .title
    @State private var lastTappedIndex: Int?

    /// Scores already in this setlist (to show indicator).
    private var existingScoreIDs: Set<UUID> {
        Set(setlist.items.compactMap { $0.score?.id })
    }

    private var filteredScores: [Score] {
        var scores = allScores.filter { !$0.isArchived }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            scores = scores.filter {
                $0.title.lowercased().contains(query) ||
                $0.composer.lowercased().contains(query) ||
                $0.genre.lowercased().contains(query) ||
                $0.customTags.contains { $0.lowercased().contains(query) }
            }
        }

        switch sortOrder {
        case .title:
            scores.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .composer:
            scores.sort { $0.composer.localizedCaseInsensitiveCompare($1.composer) == .orderedAscending }
        case .genre:
            scores.sort { $0.genre.localizedCaseInsensitiveCompare($1.genre) == .orderedAscending }
        case .recent:
            scores.sort { ($0.lastOpenedAt ?? $0.createdAt) > ($1.lastOpenedAt ?? $1.createdAt) }
        }

        return scores
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sort + batch actions bar
                HStack(spacing: ASSpacing.sm) {
                    // Sort pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ASSpacing.sm) {
                            ForEach(AddScoresSortOrder.allCases, id: \.self) { order in
                                Button {
                                    sortOrder = order
                                } label: {
                                    Text(order.rawValue)
                                        .font(ASTypography.labelSmall)
                                        .padding(.horizontal, ASSpacing.md)
                                        .padding(.vertical, ASSpacing.xs)
                                        .background(
                                            sortOrder == order
                                                ? ASColors.accentFallback.opacity(0.15)
                                                : ASColors.chromeSurfaceElevated
                                        )
                                        .foregroundStyle(sortOrder == order ? ASColors.accentFallback : .secondary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    Spacer()

                    // Select All / Deselect All
                    Button {
                        if selectedScoreIDs.count == filteredScores.count {
                            selectedScoreIDs.removeAll()
                        } else {
                            selectedScoreIDs = Set(filteredScores.map(\.id))
                        }
                    } label: {
                        Text(selectedScoreIDs.count == filteredScores.count ? "Deselect All" : "Select All")
                            .font(ASTypography.labelSmall)
                            .foregroundStyle(ASColors.accentFallback)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ASSpacing.lg)
                .padding(.vertical, ASSpacing.sm)

                Divider()

                // Score list — native List for proper scrolling + tap selection
                List {
                    ForEach(Array(filteredScores.enumerated()), id: \.element.id) { index, score in
                        scoreRow(score, index: index)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // Selection summary bar
                HStack {
                    if !selectedScoreIDs.isEmpty {
                        Button("Deselect All") {
                            selectedScoreIDs.removeAll()
                            lastTappedIndex = nil
                        }
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Text(selectedScoreIDs.isEmpty
                         ? "Tap to select, two-finger tap for range"
                         : "\(selectedScoreIDs.count) selected")
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, ASSpacing.lg)
                .padding(.vertical, ASSpacing.sm)
                .background(ASColors.chromeSurface)
            }
            .searchable(text: $searchText, prompt: "Search by title, composer, tag...")
            .navigationTitle("Add Scores")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add (\(selectedScoreIDs.count))") {
                        addSelectedScores()
                        dismiss()
                    }
                    .disabled(selectedScoreIDs.isEmpty)
                }
            }
        }
    }

    // MARK: - Score Row

    private func scoreRow(_ score: Score, index: Int) -> some View {
        let isSelected = selectedScoreIDs.contains(score.id)
        let alreadyInSetlist = existingScoreIDs.contains(score.id)

        return HStack(spacing: ASSpacing.md) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 22))
                .foregroundStyle(isSelected ? ASColors.accentFallback : Color.gray.opacity(0.4))

            VStack(alignment: .leading, spacing: 2) {
                Text(score.title)
                    .font(ASTypography.body)
                    .foregroundStyle(alreadyInSetlist ? .secondary : .primary)

                HStack(spacing: ASSpacing.sm) {
                    if !score.composer.isEmpty {
                        Text(score.composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !score.genre.isEmpty {
                        Text(score.genre)
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.tertiary)
                    }
                }

                if !score.customTags.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(score.customTags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10, weight: .medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ASColors.accentFallback.opacity(0.08))
                                .clipShape(Capsule())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            if alreadyInSetlist {
                Text("Added")
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, ASSpacing.lg)
        .padding(.vertical, ASSpacing.sm)
        .background(isSelected ? ASColors.accentFallback.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-tap: range select from last tapped to this one
            rangeSelect(to: index)
        }
        .onTapGesture(count: 1) {
            toggleSelection(score.id)
            lastTappedIndex = index
        }
    }

    // MARK: - Selection

    private func toggleSelection(_ id: UUID) {
        if selectedScoreIDs.contains(id) {
            selectedScoreIDs.remove(id)
        } else {
            selectedScoreIDs.insert(id)
        }
    }

    /// Range-select: select everything between lastTappedIndex and the given index.
    private func rangeSelect(to index: Int) {
        guard let from = lastTappedIndex else {
            // No previous tap — just select this one
            if index < filteredScores.count {
                selectedScoreIDs.insert(filteredScores[index].id)
                lastTappedIndex = index
            }
            return
        }

        let lo = min(from, index)
        let hi = max(from, index)
        for i in lo...hi where i < filteredScores.count {
            selectedScoreIDs.insert(filteredScores[i].id)
        }
        lastTappedIndex = index
    }

    // MARK: - Add

    private func addSelectedScores() {
        let currentMaxOrder = setlist.items.map(\.sortOrder).max() ?? -1
        var order = currentMaxOrder + 1

        for score in filteredScores where selectedScoreIDs.contains(score.id) {
            guard !existingScoreIDs.contains(score.id) else { continue }
            let item = SetListItem(sortOrder: order)
            item.setList = setlist
            item.score = score
            modelContext.insert(item)
            order += 1
        }
        setlist.modifiedAt = Date()
    }
}
