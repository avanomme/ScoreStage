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
    @State private var isDragging = false

    /// Scores already in this setlist (to show indicator).
    private var existingScoreIDs: Set<UUID> {
        Set(setlist.items.compactMap { $0.score?.id })
    }

    private var filteredScores: [Score] {
        var scores = allScores.filter { !$0.isArchived }

        // Search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            scores = scores.filter {
                $0.title.lowercased().contains(query) ||
                $0.composer.lowercased().contains(query) ||
                $0.genre.lowercased().contains(query) ||
                $0.customTags.contains { $0.lowercased().contains(query) }
            }
        }

        // Sort
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
                // Sort bar
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
                    .padding(.horizontal, ASSpacing.lg)
                    .padding(.vertical, ASSpacing.sm)
                }

                Divider()

                // Score list with drag-to-select
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredScores) { score in
                            scoreRow(score)
                        }
                    }
                }
                .gesture(dragSelectGesture)

                // Selection summary bar
                if !selectedScoreIDs.isEmpty {
                    Divider()
                    HStack {
                        Button("Deselect All") {
                            selectedScoreIDs.removeAll()
                        }
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.secondary)
                        .buttonStyle(.plain)

                        Spacer()

                        Text("\(selectedScoreIDs.count) selected")
                            .font(ASTypography.label)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, ASSpacing.lg)
                    .padding(.vertical, ASSpacing.sm)
                    .background(ASColors.chromeSurface)
                }
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

    private func scoreRow(_ score: Score) -> some View {
        let isSelected = selectedScoreIDs.contains(score.id)
        let alreadyInSetlist = existingScoreIDs.contains(score.id)

        return HStack(spacing: ASSpacing.md) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? ASColors.accentFallback : .secondary)

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

                // Tags
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
        .onTapGesture {
            toggleSelection(score.id)
        }
    }

    // MARK: - Drag-to-Select

    private var dragSelectGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                isDragging = true
                // Find which score row the drag is over based on Y position
                let rowHeight: CGFloat = 64
                let index = Int(value.location.y / rowHeight)
                if index >= 0 && index < filteredScores.count {
                    let score = filteredScores[index]
                    selectedScoreIDs.insert(score.id)
                }
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    // MARK: - Actions

    private func toggleSelection(_ id: UUID) {
        if selectedScoreIDs.contains(id) {
            selectedScoreIDs.remove(id)
        } else {
            selectedScoreIDs.insert(id)
        }
    }

    private func addSelectedScores() {
        let currentMaxOrder = setlist.items.map(\.sortOrder).max() ?? -1
        var order = currentMaxOrder + 1

        // Add in the current sort order
        for score in filteredScores where selectedScoreIDs.contains(score.id) {
            // Skip if already in setlist
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
