// ScoreScannerView — Camera scanning workflow: capture pages, review, enhance, name, and save as PDF.

#if os(iOS)
import SwiftUI
import VisionKit
import DesignSystem

/// Full scanning workflow: VisionKit camera → page review/enhance → title entry → PDF save.
struct ScoreScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .camera
    @State private var scannedPages: [ScannedPage] = []
    @State private var scoreTitle = ""
    @State private var selectedPageIndex: Int = 0
    @State private var activeFilter: ScoreScannerService.EnhancementFilter = .blackAndWhite
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let scannerService = ScoreScannerService()
    let onSave: (URL) -> Void

    enum ScanPhase {
        case camera
        case review
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .camera:
                    DocumentCameraView { images in
                        scannedPages = images.enumerated().map { index, img in
                            ScannedPage(id: index, original: img, enhanced: nil)
                        }
                        // Auto-apply B&W filter to all pages
                        applyFilterToAll(.blackAndWhite)
                        phase = .review
                    } onCancel: {
                        dismiss()
                    }
                    .ignoresSafeArea()

                case .review:
                    reviewView
                }
            }
            .background(ASColors.chromeBackground)
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                if let msg = errorMessage { Text(msg) }
            }
        }
    }

    // MARK: - Review View

    private var reviewView: some View {
        VStack(spacing: 0) {
            // Page preview
            if !scannedPages.isEmpty {
                TabView(selection: $selectedPageIndex) {
                    ForEach(scannedPages) { page in
                        pagePreview(page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
                .frame(maxHeight: .infinity)
            }

            Divider()

            // Controls panel
            VStack(spacing: ASSpacing.md) {
                // Page indicator
                Text("Page \(selectedPageIndex + 1) of \(scannedPages.count)")
                    .font(ASTypography.label)
                    .foregroundStyle(.secondary)

                // Edit tools row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ASSpacing.md) {
                        // Auto-fix (deskew + enhance)
                        editToolButton(icon: "wand.and.stars", label: "Auto") {
                            autoFixCurrentPage()
                        }
                        // Deskew
                        editToolButton(icon: "skew", label: "Deskew") {
                            deskewCurrentPage()
                        }
                        // Rotate
                        editToolButton(icon: "rotate.right", label: "Rotate") {
                            rotateCurrentPage()
                        }

                        Divider().frame(height: 36)

                        // Enhancement filter picker
                        ForEach(ScoreScannerService.EnhancementFilter.allCases) { filter in
                            filterButton(filter)
                        }
                    }
                    .padding(.horizontal, ASSpacing.lg)
                }

                // Title field
                HStack(spacing: ASSpacing.sm) {
                    Image(systemName: "character.cursor.ibeam")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 14))
                    TextField("Score Title", text: $scoreTitle)
                        .font(ASTypography.body)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, ASSpacing.lg)
                .padding(.vertical, ASSpacing.sm)
                .background(ASColors.chromeSurfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
                .padding(.horizontal, ASSpacing.lg)

                // Actions
                HStack(spacing: ASSpacing.md) {
                    Button {
                        // Go back to camera to add more pages
                        phase = .camera
                    } label: {
                        Label("Add Pages", systemImage: "plus.circle")
                            .font(ASTypography.label)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ASColors.accentFallback)

                    Spacer()

                    Button {
                        saveScannedScore()
                    } label: {
                        HStack(spacing: ASSpacing.xs) {
                            if isSaving {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Save")
                                .font(ASTypography.heading3)
                        }
                        .padding(.horizontal, ASSpacing.xl)
                        .padding(.vertical, ASSpacing.sm)
                        .background(ASColors.accentFallback)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
                    }
                    .disabled(isSaving)
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ASSpacing.lg)
            }
            .padding(.vertical, ASSpacing.md)
            .background(ASColors.chromeSurface)
        }
        .navigationTitle("Scanned Score")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .destructiveAction) {
                if scannedPages.count > 1 {
                    Button(role: .destructive) {
                        deletePage(at: selectedPageIndex)
                    } label: {
                        Label("Delete Page", systemImage: "trash")
                    }
                }
            }
        }
    }

    // MARK: - Page Preview

    private func pagePreview(_ page: ScannedPage) -> some View {
        let displayImage = page.enhanced ?? page.original
        return Image(uiImage: displayImage)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            .padding(ASSpacing.lg)
    }

    // MARK: - Filter Button

    private func filterButton(_ filter: ScoreScannerService.EnhancementFilter) -> some View {
        let isActive = activeFilter == filter
        return Button {
            activeFilter = filter
            applyFilterToAll(filter)
        } label: {
            VStack(spacing: ASSpacing.xs) {
                Image(systemName: filter.icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(isActive ? ASColors.accentFallback.opacity(0.15) : ASColors.chromeSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))

                Text(filter.rawValue)
                    .font(ASTypography.captionSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(isActive ? ASColors.accentFallback : .secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit Tool Button

    private func editToolButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: ASSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 36, height: 36)
                    .background(ASColors.chromeSurfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
                Text(label)
                    .font(ASTypography.captionSmall)
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Edit Actions

    private func autoFixCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].original
        // Auto-deskew then apply current filter
        let deskewed = scannerService.autoDeskew(source)
        scannedPages[selectedPageIndex].original = deskewed
        scannedPages[selectedPageIndex].enhanced = scannerService.enhance(deskewed, filter: activeFilter)
    }

    private func deskewCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].original
        let deskewed = scannerService.autoDeskew(source)
        scannedPages[selectedPageIndex].original = deskewed
        scannedPages[selectedPageIndex].enhanced = scannerService.enhance(deskewed, filter: activeFilter)
    }

    private func rotateCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].enhanced ?? scannedPages[selectedPageIndex].original
        let rotated = rotateImage90(source)
        scannedPages[selectedPageIndex].original = rotated
        scannedPages[selectedPageIndex].enhanced = rotated
    }

    private func rotateImage90(_ image: UIImage) -> UIImage {
        let newOrientation: UIImage.Orientation
        switch image.imageOrientation {
        case .up: newOrientation = .right
        case .right: newOrientation = .down
        case .down: newOrientation = .left
        case .left: newOrientation = .up
        default: newOrientation = .right
        }
        return UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: newOrientation)
    }

    // MARK: - Actions

    private func applyFilterToAll(_ filter: ScoreScannerService.EnhancementFilter) {
        for i in scannedPages.indices {
            scannedPages[i].enhanced = scannerService.enhance(
                scannedPages[i].original,
                filter: filter
            )
        }
    }

    private func deletePage(at index: Int) {
        guard scannedPages.count > 1 else { return }
        scannedPages.remove(at: index)
        // Re-index
        for i in scannedPages.indices {
            scannedPages[i].id = i
        }
        selectedPageIndex = min(selectedPageIndex, scannedPages.count - 1)
    }

    private func saveScannedScore() {
        guard !scannedPages.isEmpty else { return }
        isSaving = true

        let pages = scannedPages.map { $0.enhanced ?? $0.original }
        let title = scoreTitle.isEmpty ? "Scanned Score \(formattedDate())" : scoreTitle

        Task {
            do {
                let pdfURL = try scannerService.compileToPDF(pages: pages, title: title)
                onSave(pdfURL)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

// MARK: - Scanned Page Model

struct ScannedPage: Identifiable {
    var id: Int
    var original: UIImage
    var enhanced: UIImage?
}

// MARK: - VisionKit Document Camera Wrapper

struct DocumentCameraView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onCancel()
        }
    }
}
#endif
