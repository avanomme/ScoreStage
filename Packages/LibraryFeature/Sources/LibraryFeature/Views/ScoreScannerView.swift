// ScoreScannerView — Camera scanning workflow: capture pages, review, enhance, name, and save as PDF.

#if os(iOS)
import SwiftUI
import VisionKit
import DesignSystem

/// Full scanning workflow: VisionKit camera → page review/enhance → title entry → PDF save.
struct ScoreScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var phase: ScanPhase = .camera
    @State private var scannerMode: ScannerMode = .append
    @State private var scannedPages: [ScannedPage] = []
    @State private var scoreTitle = ""
    @State private var selectedPageIndex: Int = 0
    @State private var activeFilter: ScoreScannerService.EnhancementFilter = .blackAndWhite
    @State private var isSaving = false
    @State private var isImportingSamples = false
    @State private var shareItems: [URL] = []
    @State private var errorMessage: String?

    private let scannerService = ScoreScannerService()
    let onSave: (URL) -> Void

    enum ScanPhase {
        case camera
        case review
    }

    enum ScannerMode {
        case append
        case replace(index: Int)
        case insertBefore(index: Int)
        case insertAfter(index: Int)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .camera:
                    DocumentCameraView { images in
                        handleScannedImages(images)
                        phase = .review
                    } onCancel: {
                        if scannedPages.isEmpty {
                            dismiss()
                        } else {
                            phase = .review
                        }
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
        .scoreFileImporter(isPresented: $isImportingSamples, allowMultiple: true) { urls in
            importSamplePages(from: urls)
        }
        .sheet(isPresented: Binding(
            get: { !shareItems.isEmpty },
            set: { if !$0 { shareItems = [] } }
        )) {
            ActivityShareSheet(activityItems: shareItems)
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

                if scannedPages.indices.contains(selectedPageIndex) {
                    qualitySummaryCard(for: scannedPages[selectedPageIndex])
                        .padding(.horizontal, ASSpacing.lg)
                }

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
                        editToolButton(icon: "viewfinder", label: "Rescan") {
                            rescanCurrentPage()
                        }
                        editToolButton(icon: "sidebar.left", label: "Insert Before") {
                            insertPageBeforeCurrent()
                        }
                        editToolButton(icon: "sidebar.right", label: "Insert After") {
                            insertPageAfterCurrent()
                        }
                        editToolButton(icon: "square.and.arrow.up", label: "Export Sample") {
                            exportCurrentPageSample()
                        }
                        editToolButton(icon: "square.and.arrow.down", label: "Import Samples") {
                            isImportingSamples = true
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
                        scannerMode = .append
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
            ToolbarItem(placement: .primaryAction) {
                if !scannedPages.isEmpty {
                    Button {
                        exportSessionSamples()
                    } label: {
                        Label("Export Session", systemImage: "square.and.arrow.up.on.square")
                    }
                }
            }
        }
    }

    // MARK: - Page Preview

    private func pagePreview(_ page: ScannedPage) -> some View {
        let displayImage = page.enhanced ?? page.original
        return VStack(spacing: ASSpacing.sm) {
            if page.qualityReport.requiresRescan || !page.qualityReport.issues.isEmpty {
                HStack(spacing: ASSpacing.xs) {
                    qualityBadge(for: page.qualityReport)
                    Spacer()
                }
                .padding(.horizontal, ASSpacing.lg)
            }

            Image(uiImage: displayImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: ASRadius.sm, style: .continuous))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal, ASSpacing.lg)
                .padding(.bottom, ASSpacing.lg)
        }
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

    private func handleScannedImages(_ images: [UIImage]) {
        let newPages = images.enumerated().map { index, image in
            makeScannedPage(from: image, id: index)
        }
        guard !newPages.isEmpty else { return }

        switch scannerMode {
        case .append:
            if scannedPages.isEmpty {
                scannedPages = newPages
                selectedPageIndex = 0
            } else {
                scannedPages.append(contentsOf: newPages)
                reindexPages()
                selectedPageIndex = max(0, scannedPages.count - newPages.count)
            }
        case .replace(let index):
            guard scannedPages.indices.contains(index) else {
                scannedPages.append(contentsOf: newPages)
                reindexPages()
                selectedPageIndex = max(0, scannedPages.count - newPages.count)
                break
            }
            scannedPages[index] = newPages[0]
            if newPages.count > 1 {
                scannedPages.insert(contentsOf: Array(newPages.dropFirst()), at: index + 1)
            }
            reindexPages()
            selectedPageIndex = index
        case .insertBefore(let index):
            let insertionIndex = min(max(index, 0), scannedPages.count)
            scannedPages.insert(contentsOf: newPages, at: insertionIndex)
            reindexPages()
            selectedPageIndex = insertionIndex
        case .insertAfter(let index):
            let insertionIndex = min(max(index + 1, 0), scannedPages.count)
            scannedPages.insert(contentsOf: newPages, at: insertionIndex)
            reindexPages()
            selectedPageIndex = insertionIndex
        }

        scannerMode = .append
    }

    private func makeScannedPage(from image: UIImage, id: Int) -> ScannedPage {
        let enhanced = scannerService.enhance(image, filter: activeFilter)
        return ScannedPage(
            id: id,
            original: image,
            enhanced: enhanced,
            qualityReport: scannerService.qualityReport(for: image)
        )
    }

    private func autoFixCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].original
        let deskewed = scannerService.autoDeskew(source)
        scannedPages[selectedPageIndex].original = deskewed
        scannedPages[selectedPageIndex].enhanced = scannerService.enhance(deskewed, filter: activeFilter)
        scannedPages[selectedPageIndex].qualityReport = scannerService.qualityReport(for: deskewed)
    }

    private func deskewCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].original
        let deskewed = scannerService.autoDeskew(source)
        scannedPages[selectedPageIndex].original = deskewed
        scannedPages[selectedPageIndex].enhanced = scannerService.enhance(deskewed, filter: activeFilter)
        scannedPages[selectedPageIndex].qualityReport = scannerService.qualityReport(for: deskewed)
    }

    private func rotateCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let source = scannedPages[selectedPageIndex].enhanced ?? scannedPages[selectedPageIndex].original
        let rotated = rotateImage90(source)
        scannedPages[selectedPageIndex].original = rotated
        scannedPages[selectedPageIndex].enhanced = rotated
        scannedPages[selectedPageIndex].qualityReport = scannerService.qualityReport(for: rotated)
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
            scannedPages[i].qualityReport = scannerService.qualityReport(for: scannedPages[i].original)
        }
    }

    private func rescanCurrentPage() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        scannerMode = .replace(index: selectedPageIndex)
        phase = .camera
    }

    private func insertPageBeforeCurrent() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        scannerMode = .insertBefore(index: selectedPageIndex)
        phase = .camera
    }

    private func insertPageAfterCurrent() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        scannerMode = .insertAfter(index: selectedPageIndex)
        phase = .camera
    }

    private func deletePage(at index: Int) {
        guard scannedPages.count > 1 else { return }
        scannedPages.remove(at: index)
        reindexPages()
        selectedPageIndex = min(selectedPageIndex, scannedPages.count - 1)
    }

    private func reindexPages() {
        for i in scannedPages.indices {
            scannedPages[i].id = i
        }
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

    private func importSamplePages(from urls: [URL]) {
        var importedImages: [UIImage] = []
        for url in urls {
            let granted = url.startAccessingSecurityScopedResource()
            defer {
                if granted {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                continue
            }
            importedImages.append(image)
        }

        guard !importedImages.isEmpty else {
            errorMessage = "No readable sample images were imported."
            return
        }

        scannerMode = .append
        handleScannedImages(importedImages)
        phase = .review
    }

    private func exportCurrentPageSample() {
        guard scannedPages.indices.contains(selectedPageIndex) else { return }
        let page = scannedPages[selectedPageIndex]
        do {
            let title = (scoreTitle.isEmpty ? "ScoreStage Sample Page \(selectedPageIndex + 1)" : "\(scoreTitle) Page \(selectedPageIndex + 1)")
            let bundleURL = try scannerService.exportSampleBundle(
                title: title,
                pages: [(page.original, page.enhanced, page.qualityReport)]
            )
            shareItems = [
                bundleURL.appendingPathComponent("manifest.json"),
                bundleURL.appendingPathComponent("page-1-original.png")
            ] + (page.enhanced != nil ? [bundleURL.appendingPathComponent("page-1-enhanced.png")] : [])
        } catch {
            errorMessage = "Sample export failed: \(error.localizedDescription)"
        }
    }

    private func exportSessionSamples() {
        guard !scannedPages.isEmpty else { return }
        do {
            let title = scoreTitle.isEmpty ? "ScoreStage Scan Session \(formattedDate())" : scoreTitle
            let bundleURL = try scannerService.exportSampleBundle(
                title: title,
                pages: scannedPages.map { ($0.original, $0.enhanced, $0.qualityReport) }
            )
            shareItems = [bundleURL]
        } catch {
            errorMessage = "Session export failed: \(error.localizedDescription)"
        }
    }

    private func qualitySummaryCard(for page: ScannedPage) -> some View {
        VStack(alignment: .leading, spacing: ASSpacing.sm) {
            HStack {
                qualityBadge(for: page.qualityReport)
                Spacer()
                Text("Quality \(page.qualityReport.score)")
                    .font(ASTypography.label)
                    .foregroundStyle(page.qualityReport.score >= 85 ? ASColors.success : page.qualityReport.score >= 70 ? ASColors.warning : ASColors.error)
            }

            HStack(spacing: ASSpacing.md) {
                qualityMetric(title: "Edges", value: "\(Int(page.qualityReport.edgeConfidence * 100))%")
                qualityMetric(title: "Contrast", value: "\(Int(page.qualityReport.contrast * 100))%")
                qualityMetric(title: "Warp", value: "\(Int(page.qualityReport.warp * 100))%")
            }

            if page.qualityReport.issues.isEmpty {
                Text("Page looks performance-ready.")
                    .font(ASTypography.bodySmall)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(page.qualityReport.issues) { issue in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.title)
                            .font(ASTypography.labelSmall)
                            .foregroundStyle(issue.severity == .critical ? ASColors.error : ASColors.warning)
                        Text(issue.message)
                            .font(ASTypography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(ASSpacing.md)
        .background(ASColors.chromeSurfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: ASRadius.md, style: .continuous))
    }

    private func qualityBadge(for report: ScoreScannerService.PageQualityReport) -> some View {
        let text: String
        let color: Color
        if report.requiresRescan {
            text = "Rescan Recommended"
            color = ASColors.error
        } else if report.issues.isEmpty {
            text = "Stage Ready"
            color = ASColors.success
        } else {
            text = "Review Page"
            color = ASColors.warning
        }

        return Text(text)
            .font(ASTypography.captionSmall)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func qualityMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(ASTypography.labelMicro)
                .foregroundStyle(.secondary)
            Text(value)
                .font(ASTypography.bodySmall)
        }
    }
}

// MARK: - Scanned Page Model

struct ScannedPage: Identifiable {
    var id: Int
    var original: UIImage
    var enhanced: UIImage?
    var qualityReport: ScoreScannerService.PageQualityReport
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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
