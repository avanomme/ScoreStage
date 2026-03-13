import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct ScoreDetailView: View {
    let score: Score
    @Environment(\.modelContext) private var modelContext
    @State private var showingMetadataEditor = false

    public init(score: Score) {
        self.score = score
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ASSpacing.sectionSpacing) {
                // Header
                headerSection

                // Metadata
                metadataSection

                // Tags
                if !score.customTags.isEmpty {
                    tagsSection
                }

                // Assets
                assetsSection

                // Actions
                actionsSection
            }
            .padding(ASSpacing.screenPadding)
        }
        .navigationTitle(score.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .toolbar {
            ToolbarItem {
                Button {
                    showingMetadataEditor = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem {
                Button {
                    score.isFavorite.toggle()
                } label: {
                    Label("Favorite", systemImage: score.isFavorite ? "heart.fill" : "heart")
                }
            }
        }
        .sheet(isPresented: $showingMetadataEditor) {
            ScoreMetadataEditor(score: score)
        }
    }

    private var headerSection: some View {
        HStack(spacing: ASSpacing.lg) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: ASRadius.md)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 120, height: 160)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                }

            VStack(alignment: .leading, spacing: ASSpacing.sm) {
                Text(score.title)
                    .font(ASTypography.heading1)

                if !score.composer.isEmpty {
                    Text(score.composer)
                        .font(ASTypography.heading3)
                        .foregroundStyle(.secondary)
                }

                if !score.arranger.isEmpty {
                    Text("arr. \(score.arranger)")
                        .font(ASTypography.body)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: ASSpacing.md) {
                    if score.pageCount > 0 {
                        Label("\(score.pageCount) pages", systemImage: "doc")
                    }
                    if score.difficulty > 0 {
                        Label("Difficulty: \(score.difficulty)", systemImage: "gauge.medium")
                    }
                }
                .font(ASTypography.caption)
                .foregroundStyle(.secondary)
            }
        }
    }

    private var metadataSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: ASSpacing.md) {
                metadataRow("Genre", value: score.genre)
                metadataRow("Key", value: score.key)
                metadataRow("Instrumentation", value: score.instrumentation)
                if score.duration > 0 {
                    metadataRow("Duration", value: formatDuration(score.duration))
                }
            }
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        Group {
            if !value.isEmpty {
                HStack {
                    Text(label)
                        .font(ASTypography.label)
                        .foregroundStyle(.secondary)
                        .frame(width: 120, alignment: .leading)
                    Text(value)
                        .font(ASTypography.body)
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("Tags")
                .font(ASTypography.heading3)

            FlowLayout(spacing: ASSpacing.sm) {
                ForEach(score.customTags, id: \.self) { tag in
                    Text(tag)
                        .font(ASTypography.labelSmall)
                        .padding(.horizontal, ASSpacing.md)
                        .padding(.vertical, ASSpacing.xs)
                        .background(ASColors.accentFallback.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private var assetsSection: some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            Text("Files")
                .font(ASTypography.heading3)

            ForEach(score.assets) { asset in
                HStack {
                    Image(systemName: iconForAssetType(asset.type))
                        .foregroundStyle(.secondary)
                    Text(asset.fileName)
                        .font(ASTypography.body)
                    Spacer()
                    Text(formatFileSize(asset.fileSize))
                        .font(ASTypography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var actionsSection: some View {
        VStack(spacing: ASSpacing.md) {
            PremiumButton("Open Score", icon: "book.pages", style: .primary) {
                // Navigation to reader handled by parent
            }
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return secs > 0 ? "\(mins)m \(secs)s" : "\(mins) min"
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func iconForAssetType(_ type: ScoreAssetType) -> String {
        switch type {
        case .pdf: "doc.fill"
        case .musicXML: "music.note.list"
        case .mei: "music.note.list"
        case .midi: "pianokeys"
        case .audio: "speaker.wave.2"
        case .image: "photo"
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
