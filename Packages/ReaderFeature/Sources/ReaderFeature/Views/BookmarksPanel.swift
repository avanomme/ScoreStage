import SwiftUI
import SwiftData
import CoreDomain
import DesignSystem

public struct BookmarksPanel: View {
    let score: Score
    @Environment(\.modelContext) private var modelContext
    @State private var newBookmarkName = ""
    let currentPageIndex: Int
    let onNavigate: (Int) -> Void

    public init(score: Score, currentPageIndex: Int, onNavigate: @escaping (Int) -> Void) {
        self.score = score
        self.currentPageIndex = currentPageIndex
        self.onNavigate = onNavigate
    }

    private var sortedBookmarks: [Bookmark] {
        score.bookmarks.sorted { $0.pageIndex < $1.pageIndex }
    }

    public var body: some View {
        List {
            Section("Add Bookmark") {
                HStack {
                    TextField("Name", text: $newBookmarkName)
                    Button("Add") {
                        addBookmark()
                    }
                    .disabled(newBookmarkName.isEmpty)
                }
            }

            Section("Bookmarks") {
                if sortedBookmarks.isEmpty {
                    Text("No bookmarks")
                        .foregroundStyle(.secondary)
                        .font(ASTypography.body)
                } else {
                    ForEach(sortedBookmarks) { bookmark in
                        Button {
                            onNavigate(bookmark.pageIndex)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(Color(hex: bookmark.colorHex) ?? .blue)
                                    .frame(width: 8, height: 8)

                                Text(bookmark.name)
                                    .font(ASTypography.body)
                                    .foregroundStyle(ASColors.primaryText)

                                Spacer()

                                Text("p. \(bookmark.pageIndex + 1)")
                                    .font(ASTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { indexSet in
                        let bookmarks = sortedBookmarks
                        for index in indexSet {
                            modelContext.delete(bookmarks[index])
                        }
                    }
                }
            }

            Section("Jump to Page") {
                PageJumpView(pageCount: score.pageCount, onNavigate: onNavigate)
            }
        }
        .navigationTitle("Bookmarks")
    }

    private func addBookmark() {
        let bookmark = Bookmark(
            name: newBookmarkName,
            pageIndex: currentPageIndex,
            sortOrder: sortedBookmarks.count
        )
        bookmark.score = score
        modelContext.insert(bookmark)
        newBookmarkName = ""
    }
}

struct PageJumpView: View {
    let pageCount: Int
    let onNavigate: (Int) -> Void
    @State private var pageNumber = ""

    var body: some View {
        HStack {
            TextField("Page #", text: $pageNumber)
                #if os(iOS)
                .keyboardType(.numberPad)
                #endif
            Button("Go") {
                if let page = Int(pageNumber), page >= 1, page <= pageCount {
                    onNavigate(page - 1)
                }
            }
            .disabled(Int(pageNumber) == nil)
        }
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        guard hexSanitized.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}
