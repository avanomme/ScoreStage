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

struct AddScoresToSetlistView: View {
    let setlist: SetList
    let allScores: [Score]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedScoreIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List(allScores) { score in
                HStack {
                    VStack(alignment: .leading) {
                        Text(score.title).font(ASTypography.body)
                        if !score.composer.isEmpty {
                            Text(score.composer)
                                .font(ASTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if selectedScoreIDs.contains(score.id) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(ASColors.accentFallback)
                    } else {
                        Image(systemName: "circle")
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedScoreIDs.contains(score.id) {
                        selectedScoreIDs.remove(score.id)
                    } else {
                        selectedScoreIDs.insert(score.id)
                    }
                }
            }
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

    private func addSelectedScores() {
        let currentMaxOrder = setlist.items.map(\.sortOrder).max() ?? -1
        var order = currentMaxOrder + 1

        for score in allScores where selectedScoreIDs.contains(score.id) {
            let item = SetListItem(sortOrder: order)
            item.setList = setlist
            item.score = score
            modelContext.insert(item)
            order += 1
        }
        setlist.modifiedAt = Date()
    }
}
