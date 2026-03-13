import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct ScoreMetadataEditor: View {
    @Bindable var score: Score
    @Environment(\.dismiss) private var dismiss

    public init(score: Score) {
        self.score = score
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Title", text: $score.title)
                    TextField("Composer", text: $score.composer)
                    TextField("Arranger", text: $score.arranger)
                }

                Section("Classification") {
                    TextField("Genre", text: $score.genre)
                    TextField("Key", text: $score.key)
                    TextField("Instrumentation", text: $score.instrumentation)
                    Picker("Difficulty", selection: $score.difficulty) {
                        Text("Unrated").tag(0)
                        ForEach(1...10, id: \.self) { level in
                            Text("\(level)").tag(level)
                        }
                    }
                }

                Section("Details") {
                    HStack {
                        Text("Duration")
                        Spacer()
                        TextField("Minutes", value: Binding(
                            get: { score.duration / 60.0 },
                            set: { score.duration = $0 * 60.0 }
                        ), format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        Text("min")
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $score.notes)
                        .frame(minHeight: 80)
                }

                Section("Tags") {
                    TagsEditor(tags: $score.customTags)
                }
            }
            .navigationTitle("Edit Metadata")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        score.modifiedAt = Date()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TagsEditor: View {
    @Binding var tags: [String]
    @State private var newTag = ""

    var body: some View {
        ForEach(tags, id: \.self) { tag in
            HStack {
                Text(tag)
                Spacer()
                Button {
                    tags.removeAll { $0 == tag }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        HStack {
            TextField("Add tag", text: $newTag)
                .onSubmit { addTag() }
            Button("Add") { addTag() }
                .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func addTag() {
        let trimmed = newTag.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { return }
        tags.append(trimmed)
        newTag = ""
    }
}
