import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct SetlistDetailView: View {
    @Bindable var setlist: SetList
    @Environment(\.modelContext) private var modelContext
    @Query private var allScores: [Score]
    @State private var showingAddScores = false
    @State private var editingItem: SetListItem?

    private let onOpenScore: ((Score, [SetListItem], Int) -> Void)?

    public init(setlist: SetList, onOpenScore: ((Score, [SetListItem], Int) -> Void)? = nil) {
        self.setlist = setlist
        self.onOpenScore = onOpenScore
    }

    private var sortedItems: [SetListItem] {
        setlist.items.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var estimatedScoreDuration: TimeInterval {
        sortedItems.reduce(0) { $0 + ($1.score?.duration ?? 0) }
    }

    private var totalPauseDuration: TimeInterval {
        sortedItems.reduce(0) { $0 + $1.pauseDuration + $1.autoAdvanceDelay }
    }

    private var medleyCount: Int {
        Set(sortedItems.map(\.medleyTitle).filter { !$0.isEmpty }).count
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.xl) {
                heroCard
                showNotesCard
                runningOrderCard
            }
            .padding(ASSpacing.screenPadding)
        }
        .background(ASColors.chromeBackground.ignoresSafeArea())
        .navigationTitle(setlist.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddScores = true
                } label: {
                    Label("Add Scores", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddScores) {
            AddScoresToSetlistView(setlist: setlist, allScores: allScores)
        }
        .sheet(item: $editingItem) { item in
            SetlistItemEditorView(item: item)
        }
    }

    private var heroCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ASSpacing.lg) {
                HStack(alignment: .top, spacing: ASSpacing.lg) {
                    VStack(alignment: .leading, spacing: ASSpacing.sm) {
                        TextField("Setlist Name", text: $setlist.name)
                            .font(ASTypography.displaySmall)
                            .textFieldStyle(.plain)

                        TextField("Event Description", text: $setlist.eventDescription, axis: .vertical)
                            .font(ASTypography.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(2...4)

                        HStack(spacing: ASSpacing.sm) {
                            Label(eventDateLabel, systemImage: "calendar")
                                .font(ASTypography.caption)
                                .foregroundStyle(.secondary)

                            if medleyCount > 0 {
                                Label("\(medleyCount) medleys", systemImage: "link")
                                    .font(ASTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: ASSpacing.sm) {
                        Button {
                            openSet(at: 0)
                        } label: {
                            Label("Start Set", systemImage: "play.fill")
                                .font(ASTypography.label)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(sortedItems.isEmpty)

                        Menu {
                            Button("Sort by Title") {
                                sortSetlistItems { ($0.score?.title ?? "").localizedCaseInsensitiveCompare($1.score?.title ?? "") == .orderedAscending }
                            }
                            Button("Sort by Composer") {
                                sortSetlistItems { ($0.score?.composer ?? "").localizedCaseInsensitiveCompare($1.score?.composer ?? "") == .orderedAscending }
                            }
                            Button("Sort by Duration") {
                                sortSetlistItems { ($0.score?.duration ?? 0) < ($1.score?.duration ?? 0) }
                            }
                            Button("Reverse Order") {
                                reverseSetlistItems()
                            }
                            Button("Shuffle") {
                                shuffleSetlistItems()
                            }
                        } label: {
                            Label("Arrange", systemImage: "arrow.up.arrow.down.square")
                                .font(ASTypography.labelSmall)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                HStack(spacing: ASSpacing.md) {
                    SetlistMetricCard(title: "Songs", value: "\(sortedItems.count)", detail: "ready")
                    SetlistMetricCard(title: "Music", value: durationLabel(estimatedScoreDuration), detail: "score time")
                    SetlistMetricCard(title: "Transitions", value: durationLabel(totalPauseDuration), detail: "pauses + auto")
                }

                HStack(spacing: ASSpacing.md) {
                    DatePicker(
                        "Event Date",
                        selection: Binding(
                            get: { setlist.eventDate ?? Date() },
                            set: {
                                setlist.eventDate = $0
                                touchSetlist()
                            }
                        ),
                        displayedComponents: .date
                    )
                    .labelsHidden()

                    Button("Use Today") {
                        setlist.eventDate = Date()
                        touchSetlist()
                    }
                    .buttonStyle(.bordered)

                    if setlist.eventDate != nil {
                        Button("Clear Date", role: .destructive) {
                            setlist.eventDate = nil
                            touchSetlist()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var showNotesCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ASSpacing.lg) {
                Text("Show Notes")
                    .font(ASTypography.heading2)

                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text("Performance Notes")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(.secondary)
                    TextField("Shared notes for the whole set", text: $setlist.performanceNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }

                VStack(alignment: .leading, spacing: ASSpacing.sm) {
                    Text("Stage / Crew Notes")
                        .font(ASTypography.labelSmall)
                        .foregroundStyle(.secondary)
                    TextField("Lighting, patching, entrances, reminders", text: $setlist.stageNotes, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                }
            }
        }
    }

    private var runningOrderCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ASSpacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: ASSpacing.xs) {
                        Text("Running Order")
                            .font(ASTypography.heading2)
                        Text("Each item carries its own cues, transition behavior, and reader preset.")
                            .font(ASTypography.bodySmall)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        showingAddScores = true
                    } label: {
                        Label("Add Scores", systemImage: "plus.circle.fill")
                            .font(ASTypography.label)
                    }
                    .buttonStyle(.plain)
                }

                if sortedItems.isEmpty {
                    EmptyStateView(
                        icon: "music.note.list",
                        title: "No Songs Yet",
                        message: "Add scores, then shape transitions and cues for the live run.",
                        actionTitle: "Add Scores"
                    ) {
                        showingAddScores = true
                    }
                } else {
                    VStack(spacing: ASSpacing.md) {
                        ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                            SetlistPerformanceRow(
                                item: item,
                                index: index,
                                canMoveUp: index > 0,
                                canMoveDown: index < sortedItems.count - 1,
                                onOpen: {
                                    openSet(at: index)
                                },
                                onEdit: {
                                    editingItem = item
                                },
                                onMoveUp: {
                                    moveItem(item, direction: .up)
                                },
                                onMoveDown: {
                                    moveItem(item, direction: .down)
                                },
                                onDelete: {
                                    deleteItem(item)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    private var eventDateLabel: String {
        guard let eventDate = setlist.eventDate else { return "Unscheduled" }
        return eventDate.formatted(date: .abbreviated, time: .omitted)
    }

    private func openSet(at index: Int) {
        guard index >= 0, index < sortedItems.count, let score = sortedItems[index].score else { return }
        touchSetlist()
        onOpenScore?(score, sortedItems, index)
    }

    private func deleteItem(_ item: SetListItem) {
        modelContext.delete(item)
        normalizeSortOrder()
    }

    private func moveItem(_ item: SetListItem, direction: SetlistMoveDirection) {
        guard let index = sortedItems.firstIndex(where: { $0.id == item.id }) else { return }
        let destination: Int
        switch direction {
        case .up:
            destination = max(0, index - 1)
        case .down:
            destination = min(sortedItems.count - 1, index + 1)
        }
        guard destination != index else { return }

        var items = sortedItems
        let moved = items.remove(at: index)
        items.insert(moved, at: destination)
        for (position, existing) in items.enumerated() {
            existing.sortOrder = position
        }
        touchSetlist()
    }

    private func sortSetlistItems(by comparator: (SetListItem, SetListItem) -> Bool) {
        let sorted = setlist.items.sorted(by: comparator)
        for (index, item) in sorted.enumerated() {
            item.sortOrder = index
        }
        touchSetlist()
    }

    private func reverseSetlistItems() {
        for (index, item) in sortedItems.reversed().enumerated() {
            item.sortOrder = index
        }
        touchSetlist()
    }

    private func shuffleSetlistItems() {
        for (index, item) in sortedItems.shuffled().enumerated() {
            item.sortOrder = index
        }
        touchSetlist()
    }

    private func normalizeSortOrder() {
        for (index, item) in sortedItems.enumerated() {
            item.sortOrder = index
        }
        touchSetlist()
    }

    private func touchSetlist() {
        setlist.modifiedAt = Date()
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

private enum SetlistMoveDirection {
    case up
    case down
}

private struct SetlistMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.xs) {
            Text(title.uppercased())
                .font(ASTypography.labelMicro)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(ASTypography.heading1)
            Text(detail)
                .font(ASTypography.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
    }
}

private struct SetlistPerformanceRow: View {
    let item: SetListItem
    let index: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.md) {
            HStack(alignment: .top, spacing: ASSpacing.md) {
                Text("\(index + 1)")
                    .font(ASTypography.mono)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .leading)

                VStack(alignment: .leading, spacing: ASSpacing.xs) {
                    Text(item.score?.title ?? "Unknown Score")
                        .font(ASTypography.heading3)

                    if let composer = item.score?.composer, !composer.isEmpty {
                        Text(composer)
                            .font(ASTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack(spacing: ASSpacing.sm) {
                    Button(action: onMoveUp) {
                        Image(systemName: "arrow.up")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveUp)

                    Button(action: onMoveDown) {
                        Image(systemName: "arrow.down")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canMoveDown)

                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(.plain)

                    Button(action: onOpen) {
                        Image(systemName: "play.fill")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            }

            if !item.performanceNotes.isEmpty {
                Text(item.performanceNotes)
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(.primary)
            }

            if !item.cueTitle.isEmpty || !item.cueNotes.isEmpty {
                VStack(alignment: .leading, spacing: ASSpacing.xxs) {
                    if !item.cueTitle.isEmpty {
                        Label(item.cueTitle, systemImage: "music.quarternote.3")
                            .font(ASTypography.caption)
                    }
                    if !item.cueNotes.isEmpty {
                        Text(item.cueNotes)
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack(spacing: ASSpacing.sm) {
                transitionChip(style: item.transitionStyle, seconds: item.transitionStyle == .autoAdvance ? item.autoAdvanceDelay : item.pauseDuration)

                if !item.medleyTitle.isEmpty {
                    rowChip("Medley: \(item.medleyTitle)", systemImage: "link")
                }

                if let preset = item.performancePreset {
                    rowChip("Page \(preset.startPageIndex + 1)", systemImage: "bookmark")
                    if let displayMode = preset.preferredDisplayMode {
                        rowChip(displayMode.label, systemImage: "rectangle.split.2x1")
                    }
                }
            }

            if item.transitionStyle == .timedPause && !item.pauseNotes.isEmpty {
                Text(item.pauseNotes)
                    .font(ASTypography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .overlay(ASColors.chromeBorder)

            HStack {
                Button("Open in Reader", action: onOpen)
                    .font(ASTypography.label)
                    .buttonStyle(.borderedProminent)

                Spacer()

                Button("Delete", role: .destructive, action: onDelete)
                    .font(ASTypography.caption)
                    .buttonStyle(.plain)
            }
        }
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.lg, style: .continuous))
    }

    private func transitionChip(style: SetlistTransitionStyle, seconds: TimeInterval) -> some View {
        switch style {
        case .manual:
            return rowChip("Manual", systemImage: "hand.tap")
        case .segue:
            return rowChip("Segue", systemImage: "forward.frame.fill")
        case .timedPause:
            return rowChip("\(Int(seconds))s Pause", systemImage: "timer")
        case .autoAdvance:
            return rowChip("\(Int(seconds))s Auto", systemImage: "play.circle")
        }
    }

    private func rowChip(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(ASTypography.captionSmall)
            .padding(.horizontal, ASSpacing.sm)
            .padding(.vertical, ASSpacing.xs)
            .background(ASColors.accentFallback.opacity(0.10))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }
}

private struct SetlistItemEditorView: View {
    @Bindable var item: SetListItem
    @Environment(\.dismiss) private var dismiss

    @State private var usesPreset = false

    private var pageCount: Int {
        max(1, item.score?.pageCount ?? 1)
    }

    init(item: SetListItem) {
        self.item = item
        _usesPreset = State(initialValue: item.performancePreset != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Performance") {
                    TextField("Song notes", text: $item.performanceNotes, axis: .vertical)
                    TextField("Cue title", text: $item.cueTitle)
                    TextField("Cue details", text: $item.cueNotes, axis: .vertical)
                }

                Section("Transition") {
                    Picker("Flow", selection: $item.transitionStyle) {
                        ForEach(SetlistTransitionStyle.allCases, id: \.self) { style in
                            Text(style.label).tag(style)
                        }
                    }

                    if item.transitionStyle == .timedPause {
                        Stepper(value: $item.pauseDuration, in: 0...180, step: 5) {
                            Label("\(Int(item.pauseDuration)) second pause", systemImage: "timer")
                        }
                        TextField("Pause notes", text: $item.pauseNotes, axis: .vertical)
                    }

                    if item.transitionStyle == .autoAdvance {
                        Stepper(value: $item.autoAdvanceDelay, in: 0...180, step: 5) {
                            Label("\(Int(item.autoAdvanceDelay)) second auto-advance", systemImage: "play.circle")
                        }
                    }

                    TextField("Medley / segue group", text: $item.medleyTitle)
                }

                Section("Reader Preset") {
                    Toggle("Use item-specific preset", isOn: Binding(
                        get: { usesPreset },
                        set: { newValue in
                            usesPreset = newValue
                            item.performancePreset = newValue ? (item.performancePreset ?? SetlistPerformancePreset()) : nil
                        }
                    ))

                    if usesPreset {
                        Stepper(value: startPageBinding, in: 0...(pageCount - 1)) {
                            Text("Start on page \((item.performancePreset?.startPageIndex ?? 0) + 1)")
                        }

                        Picker("Display", selection: displayModeBinding) {
                            Text("Single").tag(DisplayMode.singlePage)
                            Text("Horizontal").tag(DisplayMode.horizontalPaged)
                            Text("Vertical").tag(DisplayMode.verticalScroll)
                            Text("Spread").tag(DisplayMode.twoPageSpread)
                        }

                        Picker("Paper", selection: paperThemeBinding) {
                            Text("White").tag(PaperTheme.light)
                            Text("Cream").tag(PaperTheme.sepia)
                            Text("Warm").tag(PaperTheme.warm)
                            Text("High Contrast").tag(PaperTheme.highContrast)
                        }

                        Picker("Page Turn", selection: pageTurnBinding) {
                            Text("Standard").tag(PageTurnBehavior.standard)
                            Text("Half Page").tag(PageTurnBehavior.halfPage)
                            Text("Safe Performance").tag(PageTurnBehavior.safePerformance)
                        }

                        Toggle("Open in performance mode", isOn: performanceModeBinding)
                        Toggle("Expect linked session", isOn: linkedModeBinding)
                    }
                }
            }
            .navigationTitle(item.score?.title ?? "Set Item")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onDisappear {
                item.setList?.modifiedAt = Date()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var startPageBinding: Binding<Int> {
        Binding(
            get: { item.performancePreset?.startPageIndex ?? 0 },
            set: {
                ensurePreset()
                item.performancePreset?.startPageIndex = max(0, min($0, pageCount - 1))
            }
        )
    }

    private var displayModeBinding: Binding<DisplayMode> {
        Binding(
            get: { item.performancePreset?.preferredDisplayMode ?? .singlePage },
            set: {
                ensurePreset()
                item.performancePreset?.preferredDisplayMode = $0
            }
        )
    }

    private var paperThemeBinding: Binding<PaperTheme> {
        Binding(
            get: { item.performancePreset?.preferredPaperTheme ?? .light },
            set: {
                ensurePreset()
                item.performancePreset?.preferredPaperTheme = $0
            }
        )
    }

    private var pageTurnBinding: Binding<PageTurnBehavior> {
        Binding(
            get: { item.performancePreset?.preferredPageTurnBehavior ?? .standard },
            set: {
                ensurePreset()
                item.performancePreset?.preferredPageTurnBehavior = $0
            }
        )
    }

    private var performanceModeBinding: Binding<Bool> {
        Binding(
            get: { item.performancePreset?.opensInPerformanceMode ?? true },
            set: {
                ensurePreset()
                item.performancePreset?.opensInPerformanceMode = $0
            }
        )
    }

    private var linkedModeBinding: Binding<Bool> {
        Binding(
            get: { item.performancePreset?.requiresLinkedMode ?? false },
            set: {
                ensurePreset()
                item.performancePreset?.requiresLinkedMode = $0
            }
        )
    }

    private func ensurePreset() {
        if item.performancePreset == nil {
            item.performancePreset = SetlistPerformancePreset()
        }
        usesPreset = true
    }
}

private extension SetlistTransitionStyle {
    var label: String {
        switch self {
        case .manual: return "Manual"
        case .segue: return "Segue"
        case .timedPause: return "Timed Pause"
        case .autoAdvance: return "Auto Advance"
        }
    }
}

private extension DisplayMode {
    var label: String {
        switch self {
        case .singlePage: return "Single"
        case .verticalScroll: return "Scroll"
        case .horizontalPaged: return "Horizontal"
        case .twoPageSpread: return "Spread"
        }
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
                HStack(spacing: ASSpacing.sm) {
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

                List {
                    ForEach(Array(filteredScores.enumerated()), id: \.element.id) { index, score in
                        scoreRow(score, index: index)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

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

    private func scoreRow(_ score: Score, index: Int) -> some View {
        let isSelected = selectedScoreIDs.contains(score.id)
        let alreadyInSetlist = existingScoreIDs.contains(score.id)

        return HStack(spacing: ASSpacing.md) {
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
            rangeSelect(to: index)
        }
        .onTapGesture(count: 1) {
            toggleSelection(score.id)
            lastTappedIndex = index
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedScoreIDs.contains(id) {
            selectedScoreIDs.remove(id)
        } else {
            selectedScoreIDs.insert(id)
        }
    }

    private func rangeSelect(to index: Int) {
        guard let from = lastTappedIndex else {
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
