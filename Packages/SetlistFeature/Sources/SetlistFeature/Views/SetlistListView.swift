import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct SetlistListView: View {
    @Query(sort: \SetList.modifiedAt, order: .reverse) private var setlists: [SetList]
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewSetlist = false
    @State private var newSetlistName = ""

    public init() {}

    public var body: some View {
        Group {
            if setlists.isEmpty {
                EmptyStateView(
                    icon: "list.bullet.rectangle",
                    title: "No Setlists",
                    message: "Create a setlist to organize your performances.",
                    actionTitle: "New Setlist"
                ) {
                    showingNewSetlist = true
                }
            } else {
                List {
                    ForEach(setlists) { setlist in
                        NavigationLink(value: setlist) {
                            SetlistRow(setlist: setlist)
                        }
                        .contextMenu {
                            Button {
                                duplicateSetlist(setlist)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            Button(role: .destructive) {
                                modelContext.delete(setlist)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            modelContext.delete(setlists[index])
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(ASColors.chromeBackground)
        .navigationTitle("Setlists")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewSetlist = true
                } label: {
                    Label("New Setlist", systemImage: "plus")
                }
            }
        }
        .alert("New Setlist", isPresented: $showingNewSetlist) {
            TextField("Setlist Name", text: $newSetlistName)
            Button("Create") {
                guard !newSetlistName.isEmpty else { return }
                let setlist = SetList(name: newSetlistName)
                modelContext.insert(setlist)
                newSetlistName = ""
            }
            Button("Cancel", role: .cancel) { newSetlistName = "" }
        }
    }

    private func duplicateSetlist(_ original: SetList) {
        let copy = SetList(
            name: "\(original.name) (Copy)",
            eventDescription: original.eventDescription,
            performanceNotes: original.performanceNotes,
            stageNotes: original.stageNotes
        )
        modelContext.insert(copy)
        for item in original.items.sorted(by: { $0.sortOrder < $1.sortOrder }) {
            let newItem = SetListItem(
                sortOrder: item.sortOrder,
                performanceNotes: item.performanceNotes,
                cueTitle: item.cueTitle,
                cueNotes: item.cueNotes,
                pauseDuration: item.pauseDuration,
                pauseNotes: item.pauseNotes,
                transitionStyle: item.transitionStyle,
                medleyTitle: item.medleyTitle,
                autoAdvanceDelay: item.autoAdvanceDelay,
                performancePreset: item.performancePreset
            )
            newItem.setList = copy
            newItem.score = item.score
            modelContext.insert(newItem)
        }
    }
}

struct SetlistRow: View {
    let setlist: SetList

    var body: some View {
        VStack(alignment: .leading, spacing: ASSpacing.xxs) {
            Text(setlist.name)
                .font(ASTypography.body)

            HStack(spacing: ASSpacing.sm) {
                Text("\(setlist.items.count) scores")
                    .font(ASTypography.caption)
                    .foregroundStyle(.secondary)

                if !setlist.performanceNotes.isEmpty || !setlist.stageNotes.isEmpty {
                    Label("Show Notes", systemImage: "music.note.list")
                        .font(ASTypography.captionSmall)
                        .foregroundStyle(.tertiary)
                }

                if let date = setlist.eventDate {
                    Text(date, style: .date)
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, ASSpacing.xxs)
    }
}
