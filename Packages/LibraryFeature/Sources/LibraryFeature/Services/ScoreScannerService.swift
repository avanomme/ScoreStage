// ScoreScannerService — Camera scanning with document detection, enhancement, and PDF compilation.

#if os(iOS)
import Foundation
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import PDFKit

/// Handles image enhancement and PDF compilation for scanned sheet music pages.
@MainActor
public final class ScoreScannerService {

    public enum ScanIssueSeverity: String, Codable, Sendable {
        case info
        case warning
        case critical
    }

    public struct ScanIssue: Codable, Identifiable, Sendable {
        public var id: UUID
        public let severity: ScanIssueSeverity
        public let title: String
        public let message: String

        public init(severity: ScanIssueSeverity, title: String, message: String) {
            self.id = UUID()
            self.severity = severity
            self.title = title
            self.message = message
        }
    }

    public struct PageQualityReport: Codable, Sendable {
        public let score: Int
        public let edgeConfidence: Double
        public let contrast: Double
        public let brightness: Double
        public let warp: Double
        public let issues: [ScanIssue]

        public init(
            score: Int,
            edgeConfidence: Double,
            contrast: Double,
            brightness: Double,
            warp: Double,
            issues: [ScanIssue]
        ) {
            self.score = score
            self.edgeConfidence = edgeConfidence
            self.contrast = contrast
            self.brightness = brightness
            self.warp = warp
            self.issues = issues
        }

        public var requiresRescan: Bool {
            issues.contains { $0.severity == .critical }
        }
    }

    public struct ExportedScanSamplePage: Codable, Sendable {
        public let index: Int
        public let originalFileName: String
        public let enhancedFileName: String?
        public let qualityReport: PageQualityReport

        public init(index: Int, originalFileName: String, enhancedFileName: String?, qualityReport: PageQualityReport) {
            self.index = index
            self.originalFileName = originalFileName
            self.enhancedFileName = enhancedFileName
            self.qualityReport = qualityReport
        }
    }

    public struct ExportedScanSampleManifest: Codable, Sendable {
        public let title: String
        public let createdAt: Date
        public let pageCount: Int
        public let pages: [ExportedScanSamplePage]

        public init(title: String, createdAt: Date, pageCount: Int, pages: [ExportedScanSamplePage]) {
            self.title = title
            self.createdAt = createdAt
            self.pageCount = pageCount
            self.pages = pages
        }
    }

    // MARK: - Enhancement Filter

    public enum EnhancementFilter: String, CaseIterable, Identifiable, Sendable {
        case original = "Original"
        case blackAndWhite = "Black & White"
        case grayscale = "Grayscale"
        case highContrast = "High Contrast"
        case sharpen = "Sharpen"

        public var id: String { rawValue }

        public var icon: String {
            switch self {
            case .original: "photo"
            case .blackAndWhite: "circle.lefthalf.filled"
            case .grayscale: "paintbrush"
            case .highContrast: "sun.max"
            case .sharpen: "sparkles"
            }
        }
    }

    // MARK: - Private

    private let ciContext = CIContext()

    public init() {}

    // MARK: - Image Enhancement

    /// Apply an enhancement filter to a scanned page image.
    public func enhance(_ image: UIImage, filter: EnhancementFilter) -> UIImage {
        let prepared = preparePageForScoreReading(image)
        guard let ciImage = CIImage(image: prepared) else { return prepared }

        let filtered: CIImage
        switch filter {
        case .original:
            return prepared
        case .blackAndWhite:
            filtered = applyAdaptiveThreshold(ciImage)
        case .grayscale:
            filtered = applyGrayscale(ciImage)
        case .highContrast:
            filtered = applyHighContrast(ciImage)
        case .sharpen:
            filtered = applySharpen(ciImage)
        }

        guard let cgImage = ciContext.createCGImage(filtered, from: filtered.extent) else {
            return prepared
        }
        let enhanced = UIImage(cgImage: cgImage, scale: prepared.scale, orientation: .up)
        return renderIntoStandardPage(enhanced)
    }

    public func qualityReport(for image: UIImage) -> PageQualityReport {
        let prepared = preparePageForScoreReading(image)
        guard let cgImage = prepared.cgImage else {
            return PageQualityReport(
                score: 0,
                edgeConfidence: 0,
                contrast: 0,
                brightness: 0,
                warp: 1,
                issues: [ScanIssue(severity: .critical, title: "Unreadable Capture", message: "The page could not be analyzed. Rescan this page.")]
            )
        }

        let metrics = imageMetrics(for: cgImage)
        var issues: [ScanIssue] = []
        var score = 100

        if metrics.edgeConfidence < 0.55 {
            issues.append(ScanIssue(severity: .critical, title: "Weak Page Detection", message: "The page edges were not isolated cleanly. Rescan with the full page visible."))
            score -= 28
        } else if metrics.edgeConfidence < 0.72 {
            issues.append(ScanIssue(severity: .warning, title: "Loose Page Framing", message: "Page edges look uncertain. Check for clipped corners or background intrusion."))
            score -= 14
        }

        if metrics.warp > 0.1 {
            issues.append(ScanIssue(severity: .critical, title: "Page Warp Detected", message: "The page still looks curved after cleanup. Flatten the book or rescan from higher above."))
            score -= 26
        } else if metrics.warp > 0.05 {
            issues.append(ScanIssue(severity: .warning, title: "Residual Curl", message: "The page shows some book curvature. Verify that staves stay straight across the page."))
            score -= 10
        }

        if metrics.contrast < 0.15 {
            issues.append(ScanIssue(severity: .critical, title: "Low Notation Contrast", message: "Staff lines and noteheads may be too soft to play from comfortably. Increase light and rescan."))
            score -= 24
        } else if metrics.contrast < 0.22 {
            issues.append(ScanIssue(severity: .warning, title: "Soft Staff Detail", message: "Notation contrast is acceptable but not ideal. Fine details may look weak on stage."))
            score -= 10
        }

        if metrics.brightness < 0.68 {
            issues.append(ScanIssue(severity: .warning, title: "Dark Capture", message: "Uneven or low light was detected. Shadows can hide ledger lines and markings."))
            score -= 8
        } else if metrics.brightness > 0.97 {
            issues.append(ScanIssue(severity: .warning, title: "Washed Highlights", message: "The page is very bright and may lose pencil marks or lighter notation detail."))
            score -= 6
        }

        return PageQualityReport(
            score: max(0, score),
            edgeConfidence: metrics.edgeConfidence,
            contrast: metrics.contrast,
            brightness: metrics.brightness,
            warp: metrics.warp,
            issues: issues
        )
    }

    // MARK: - Filters

    private func applyAdaptiveThreshold(_ input: CIImage) -> CIImage {
        let grayscale = applyGrayscale(input)
        let flattened = grayscale.applyingFilter("CIHighlightShadowAdjust", parameters: [
            "inputShadowAmount": 0.85,
            "inputHighlightAmount": 0.92
        ])

        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = flattened
        sharpen.radius = 1.2
        sharpen.intensity = 1.35

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = sharpen.outputImage ?? flattened
        colorControls.contrast = 3.4
        colorControls.brightness = 0.06
        colorControls.saturation = 0
        guard let contrasted = colorControls.outputImage else { return input }

        let morphology = CIFilter.maximumComponent()
        morphology.inputImage = contrasted
        let componentFiltered = morphology.outputImage ?? contrasted

        guard let clamp = CIFilter(
            name: "CIColorClamp",
            parameters: [
                kCIInputImageKey: componentFiltered,
                "inputMinComponents": CIVector(x: 0.03, y: 0.03, z: 0.03, w: 1),
                "inputMaxComponents": CIVector(x: 0.98, y: 0.98, z: 0.98, w: 1)
            ]
        ) else { return componentFiltered }

        return clamp.outputImage ?? componentFiltered
    }

    private func applyGrayscale(_ input: CIImage) -> CIImage {
        let filter = CIFilter.photoEffectMono()
        filter.inputImage = input
        return filter.outputImage ?? input
    }

    private func applyHighContrast(_ input: CIImage) -> CIImage {
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = input
        colorControls.contrast = 1.6
        colorControls.brightness = 0.05
        colorControls.saturation = 0.0
        guard let result = colorControls.outputImage else { return input }

        // Additional sharpening for notation clarity
        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = result
        sharpen.sharpness = 0.6
        return sharpen.outputImage ?? result
    }

    private func applySharpen(_ input: CIImage) -> CIImage {
        let sharpen = CIFilter.unsharpMask()
        sharpen.inputImage = input
        sharpen.radius = 2.5
        sharpen.intensity = 0.8
        return sharpen.outputImage ?? input
    }

    // MARK: - PDF Compilation

    /// Compile an array of page images into a single PDF file.
    /// Returns the URL of the generated PDF in a temporary directory.
    public func compileToPDF(pages: [UIImage], title: String) throws -> URL {
        guard !pages.isEmpty else {
            throw ScanError.noPages
        }

        let pdfDocument = PDFDocument()

        for (index, image) in pages.enumerated() {
            let prepared = renderIntoStandardPage(preparePageForScoreReading(image))
            let targetSize = optimizedPageSize(for: prepared)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let rendered = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))

                let drawRect = aspectFitRect(for: prepared.size, in: CGRect(origin: .zero, size: targetSize).insetBy(dx: 90, dy: 90))
                prepared.draw(in: drawRect)
            }

            guard let pdfPage = PDFPage(image: rendered) else { continue }
            pdfDocument.insert(pdfPage, at: index)
        }

        // Save to temp directory
        let sanitizedTitle = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = sanitizedTitle.isEmpty ? "Scanned Score" : sanitizedTitle
        let tempDir = FileManager.default.temporaryDirectory
        let pdfURL = tempDir.appendingPathComponent("\(fileName).pdf")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: pdfURL)

        guard pdfDocument.write(to: pdfURL) else {
            throw ScanError.pdfWriteFailed
        }

        return pdfURL
    }

    public func exportSampleBundle(
        title: String,
        pages: [(original: UIImage, enhanced: UIImage?, report: PageQualityReport)]
    ) throws -> URL {
        guard !pages.isEmpty else {
            throw ScanError.noPages
        }

        let baseName = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let bundleName = baseName.isEmpty ? "ScoreScanSample" : baseName
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(bundleName)-Samples", isDirectory: true)

        try? FileManager.default.removeItem(at: rootURL)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        var manifestPages: [ExportedScanSamplePage] = []
        for (index, page) in pages.enumerated() {
            let originalName = "page-\(index + 1)-original.png"
            let originalURL = rootURL.appendingPathComponent(originalName)
            guard let originalData = page.original.pngData() else { continue }
            try originalData.write(to: originalURL)

            var enhancedName: String?
            if let enhanced = page.enhanced, let enhancedData = enhanced.pngData() {
                let name = "page-\(index + 1)-enhanced.png"
                try enhancedData.write(to: rootURL.appendingPathComponent(name))
                enhancedName = name
            }

            manifestPages.append(
                ExportedScanSamplePage(
                    index: index,
                    originalFileName: originalName,
                    enhancedFileName: enhancedName,
                    qualityReport: page.report
                )
            )
        }

        let manifest = ExportedScanSampleManifest(
            title: title,
            createdAt: Date(),
            pageCount: manifestPages.count,
            pages: manifestPages
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: rootURL.appendingPathComponent("manifest.json"))
        return rootURL
    }

    /// Calculate optimal page size maintaining aspect ratio at high DPI.
    private func optimizedPageSize(for image: UIImage) -> CGSize {
        let portrait = image.size.height >= image.size.width
        return portrait ? CGSize(width: 2550, height: 3300) : CGSize(width: 3300, height: 2550)
    }

    // MARK: - Deskew & Perspective Correction

    /// Auto-detect document edges and apply perspective correction.
    public func autoDeskew(_ image: UIImage) -> UIImage {
        preparePageForScoreReading(image)
    }

    /// Auto-straighten a slightly rotated image.
    public func autoStraighten(_ image: UIImage) -> UIImage {
        preparePageForScoreReading(image)
    }

    /// Crop an image to the given normalized rect (0-1 range).
    public func crop(_ image: UIImage, to normalizedRect: CGRect) -> UIImage {
        let size = image.size
        let cropRect = CGRect(
            x: normalizedRect.origin.x * size.width,
            y: normalizedRect.origin.y * size.height,
            width: normalizedRect.width * size.width,
            height: normalizedRect.height * size.height
        )
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Apply perspective correction with manual corner points (normalized 0-1 coordinates).
    public func perspectiveCorrect(_ image: UIImage, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let extent = ciImage.extent

        // Convert normalized coords to image coords
        func toImagePoint(_ p: CGPoint) -> CIVector {
            CIVector(x: p.x * extent.width, y: (1 - p.y) * extent.height)
        }

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": toImagePoint(topLeft),
            "inputTopRight": toImagePoint(topRight),
            "inputBottomLeft": toImagePoint(bottomLeft),
            "inputBottomRight": toImagePoint(bottomRight)
        ])

        guard let cgImage = ciContext.createCGImage(corrected, from: corrected.extent) else {
            return image
        }
        return renderIntoStandardPage(UIImage(cgImage: cgImage, scale: image.scale, orientation: .up))
    }

    // MARK: - Score Cleanup Pipeline

    /// Produces a clean single-page result from a camera capture before filtering or export.
    public func preparePageForScoreReading(_ image: UIImage) -> UIImage {
        let normalized = normalizeOrientation(image)
        let pageIsolated = cropToDetectedPage(normalized)
        let aligned = refinePageAlignment(pageIsolated)
        let reisolated = cropToDetectedPage(aligned)
        let warpCorrected = flattenBookWarpIfNeeded(reisolated)
        let finalIsolated = cropToDetectedPage(warpCorrected)
        let normalizedWhites = normalizeWhitePoint(finalIsolated)
        let shadowFlattened = flattenPageLighting(normalizedWhites)
        let despeckled = removeSpeckleNoise(from: shadowFlattened)
        let contrastBalanced = balanceNotationContrast(despeckled)
        let notationEnhanced = preserveNotationEdges(in: contrastBalanced)
        let borderTrimmed = trimBackgroundBorder(from: notationEnhanced)
        return renderIntoStandardPage(borderTrimmed)
    }

    private func cropToDetectedPage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let rect = bestDocumentRectangle(in: ciImage) else {
            return image
        }

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: rect.topLeft),
            "inputTopRight": CIVector(cgPoint: rect.topRight),
            "inputBottomLeft": CIVector(cgPoint: rect.bottomLeft),
            "inputBottomRight": CIVector(cgPoint: rect.bottomRight)
        ])

        guard let cgImage = ciContext.createCGImage(corrected, from: corrected.extent.integral) else {
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func refinePageAlignment(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let rect = bestDocumentRectangle(in: ciImage) else {
            return straightenFromContentBounds(image)
        }

        let topAngle = atan2(rect.topRight.y - rect.topLeft.y, rect.topRight.x - rect.topLeft.x)
        let bottomAngle = atan2(rect.bottomRight.y - rect.bottomLeft.y, rect.bottomRight.x - rect.bottomLeft.x)
        let averageAngle = (topAngle + bottomAngle) / 2

        guard abs(averageAngle) > 0.003 else {
            return straightenFromContentBounds(image)
        }

        let straighten = CIFilter.straighten()
        straighten.inputImage = ciImage
        straighten.angle = Float(-averageAngle)

        guard let output = straighten.outputImage?.cropped(to: straighten.outputImage?.extent ?? ciImage.extent),
              let cgImage = ciContext.createCGImage(output, from: output.extent.integral) else {
            return straightenFromContentBounds(image)
        }

        let straightened = UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
        return straightenFromContentBounds(straightened)
    }

    private func straightenFromContentBounds(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: Int(height * bytesPerRow))

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let sampleRows = stride(from: max(height / 10, 1), to: height - max(height / 10, 1), by: max(height / 8, 1))
        var leftSamples: [CGPoint] = []
        var rightSamples: [CGPoint] = []

        for y in sampleRows {
            if let left = firstDarkPixel(in: pixels, width: width, bytesPerRow: bytesPerRow, y: y, range: 0..<width / 2) {
                leftSamples.append(CGPoint(x: left, y: CGFloat(y)))
            }
            if let right = firstDarkPixel(in: pixels, width: width, bytesPerRow: bytesPerRow, y: y, range: stride(from: width - 1, through: width / 2, by: -1)) {
                rightSamples.append(CGPoint(x: right, y: CGFloat(y)))
            }
        }

        let leftAngle = regressionAngle(for: leftSamples)
        let rightAngle = regressionAngle(for: rightSamples)
        let candidateAngles = [leftAngle, rightAngle].filter { !$0.isNaN && abs($0) < (.pi / 8) }
        guard !candidateAngles.isEmpty else { return image }

        let averageAngle = candidateAngles.reduce(0, +) / CGFloat(candidateAngles.count)
        guard abs(averageAngle) > 0.003,
              let ciImage = CIImage(image: image) else {
            return image
        }

        let straighten = CIFilter.straighten()
        straighten.inputImage = ciImage
        straighten.angle = Float(-averageAngle)

        guard let output = straighten.outputImage,
              let rotated = ciContext.createCGImage(output, from: output.extent.integral) else {
            return image
        }

        return UIImage(cgImage: rotated, scale: image.scale, orientation: .up)
    }

    private func firstDarkPixel<S: Sequence>(in pixels: [UInt8], width: Int, bytesPerRow: Int, y: Int, range: S) -> CGFloat? where S.Element == Int {
        for x in range where x >= 0 && x < width {
            let offset = y * bytesPerRow + x * 4
            let r = CGFloat(pixels[offset])
            let g = CGFloat(pixels[offset + 1])
            let b = CGFloat(pixels[offset + 2])
            let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if luminance < 245 {
                return CGFloat(x)
            }
        }
        return nil
    }

    private func regressionAngle(for points: [CGPoint]) -> CGFloat {
        guard points.count >= 2 else { return .nan }

        let count = CGFloat(points.count)
        let meanX = points.reduce(0) { $0 + $1.x } / count
        let meanY = points.reduce(0) { $0 + $1.y } / count

        let covariance = points.reduce(0) { partial, point in
            partial + ((point.x - meanX) * (point.y - meanY))
        }
        let varianceY = points.reduce(0) { partial, point in
            partial + pow(point.y - meanY, 2)
        }

        guard varianceY > 0 else { return .nan }
        let slope = covariance / varianceY
        return atan(slope)
    }

    private func flattenBookWarpIfNeeded(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let bounds = contentBoundsByRow(for: cgImage)
        guard bounds.count > 24 else { return image }

        let lefts = bounds.map(\.lowerBound)
        let rights = bounds.map(\.upperBound)
        let avgLeft = lefts.reduce(0, +) / CGFloat(lefts.count)
        let avgRight = rights.reduce(0, +) / CGFloat(rights.count)
        let warpAmount = normalizedWarp(lefts: lefts, rights: rights, width: CGFloat(cgImage.width))

        guard warpAmount > 0.035 else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var sourcePixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        var outputPixels = [UInt8](repeating: 255, count: height * bytesPerRow)

        guard let sourceContext = CGContext(
            data: &sourcePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let outputContext = CGContext(
            data: &outputPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        sourceContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        for y in 0..<height {
            let row = bounds[min(y, bounds.count - 1)]
            let sourceLeft = row.lowerBound
            let sourceRight = Swift.max(row.upperBound, sourceLeft + 1)
            let targetLeft = avgLeft
            let targetRight = Swift.max(avgRight, targetLeft + 1)

            for x in 0..<width {
                let destinationX = CGFloat(x)
                let normalizedX = (destinationX - targetLeft) / Swift.max(targetRight - targetLeft, 1)
                let sourceX = sourceLeft + (normalizedX * (sourceRight - sourceLeft))
                let sampleX = min(max(Int(sourceX.rounded()), 0), width - 1)

                let sourceOffset = y * bytesPerRow + sampleX * bytesPerPixel
                let outputOffset = y * bytesPerRow + x * bytesPerPixel

                outputPixels[outputOffset] = sourcePixels[sourceOffset]
                outputPixels[outputOffset + 1] = sourcePixels[sourceOffset + 1]
                outputPixels[outputOffset + 2] = sourcePixels[sourceOffset + 2]
                outputPixels[outputOffset + 3] = sourcePixels[sourceOffset + 3]
            }
        }

        guard let warped = outputContext.makeImage() else { return image }
        return UIImage(cgImage: warped, scale: image.scale, orientation: .up)
    }

    private func contentBoundsByRow(for cgImage: CGImage) -> [ClosedRange<CGFloat>] {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var rows: [ClosedRange<CGFloat>] = []
        let fallback = 0...CGFloat(max(width - 1, 1))
        var previous = fallback

        for y in 0..<height {
            var minX: Int?
            var maxX: Int?

            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(pixels[offset])
                let g = CGFloat(pixels[offset + 1])
                let b = CGFloat(pixels[offset + 2])
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
                if luminance < 245 {
                    minX = minX.map { min($0, x) } ?? x
                    maxX = maxX.map { max($0, x) } ?? x
                }
            }

            if let minX, let maxX, maxX > minX {
                previous = CGFloat(minX)...CGFloat(maxX)
                rows.append(previous)
            } else {
                rows.append(previous)
            }
        }

        return rows
    }

    private func normalizedWarp(lefts: [CGFloat], rights: [CGFloat], width: CGFloat) -> Double {
        guard width > 0, !lefts.isEmpty, lefts.count == rights.count else { return 0 }
        let avgLeft = lefts.reduce(0, +) / CGFloat(lefts.count)
        let avgRight = rights.reduce(0, +) / CGFloat(rights.count)
        let leftDeviation = lefts.reduce(0) { $0 + abs($1 - avgLeft) } / CGFloat(lefts.count)
        let rightDeviation = rights.reduce(0) { $0 + abs($1 - avgRight) } / CGFloat(rights.count)
        return Double((leftDeviation + rightDeviation) / (2 * width))
    }

    private func imageMetrics(for cgImage: CGImage) -> (edgeConfidence: Double, contrast: Double, brightness: Double, warp: Double) {
        let rows = contentBoundsByRow(for: cgImage)
        guard !rows.isEmpty else {
            return (0, 0, 0, 1)
        }

        let width = CGFloat(cgImage.width)
        let heights = rows.map { $0.upperBound - $0.lowerBound }
        let pageCoverage = heights.reduce(0, +) / CGFloat(rows.count) / max(width, 1)
        let warp = normalizedWarp(lefts: rows.map(\.lowerBound), rights: rows.map(\.upperBound), width: width)

        let stats = luminanceStatistics(for: cgImage)
        let contrast = min(max(stats.standardDeviation / 255.0, 0), 1)
        let brightness = min(max(stats.mean / 255.0, 0), 1)
        let edgeConfidence = min(max(Double((pageCoverage - 0.45) / 0.35), 0), 1)

        return (edgeConfidence, contrast, brightness, warp)
    }

    private func luminanceStatistics(for cgImage: CGImage) -> (mean: Double, standardDeviation: Double) {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return (0, 0)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let step = max(1, min(width, height) / 240)
        var values: [Double] = []
        values.reserveCapacity((width / step) * (height / step))

        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = Double(pixels[offset])
                let g = Double(pixels[offset + 1])
                let b = Double(pixels[offset + 2])
                values.append((0.2126 * r) + (0.7152 * g) + (0.0722 * b))
            }
        }

        guard !values.isEmpty else { return (0, 0) }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return (mean, sqrt(variance))
    }

    private func bestDocumentRectangle(in image: CIImage) -> CIRectangleFeature? {
        let detector = CIDetector(ofType: CIDetectorTypeRectangle, context: ciContext, options: [
            CIDetectorAccuracy: CIDetectorAccuracyHigh,
            CIDetectorAspectRatio: 1.41,
            CIDetectorMinFeatureSize: 0.2
        ])

        let candidates = detector?.features(in: image).compactMap { $0 as? CIRectangleFeature } ?? []
        return candidates.max { lhs, rhs in
            rectangleScore(lhs) < rectangleScore(rhs)
        }
    }

    private func rectangleScore(_ rect: CIRectangleFeature) -> CGFloat {
        let width = max(distance(from: rect.topLeft, to: rect.topRight), distance(from: rect.bottomLeft, to: rect.bottomRight))
        let height = max(distance(from: rect.topLeft, to: rect.bottomLeft), distance(from: rect.topRight, to: rect.bottomRight))
        let area = width * height
        let aspectPenalty = abs((height / max(width, 1)) - 1.41) * 5000
        return area - aspectPenalty
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func trimBackgroundBorder(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitsPerComponent = 8
        var pixels = [UInt8](repeating: 0, count: Int(height * bytesPerRow))

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                let r = CGFloat(pixels[offset])
                let g = CGFloat(pixels[offset + 1])
                let b = CGFloat(pixels[offset + 2])
                let alpha = CGFloat(pixels[offset + 3])
                let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b

                if alpha > 10, luminance < 247 {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard minX < maxX, minY < maxY else { return image }

        let paddingX = max(Int(CGFloat(maxX - minX) * 0.035), 24)
        let paddingY = max(Int(CGFloat(maxY - minY) * 0.035), 24)
        let cropRect = CGRect(
            x: max(minX - paddingX, 0),
            y: max(minY - paddingY, 0),
            width: min(maxX - minX + (paddingX * 2), width - max(minX - paddingX, 0)),
            height: min(maxY - minY + (paddingY * 2), height - max(minY - paddingY, 0))
        ).integral

        guard let cropped = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private func normalizeWhitePoint(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let controls = CIFilter.colorControls()
        controls.inputImage = ciImage
        controls.brightness = 0.03
        controls.contrast = 1.08
        controls.saturation = 0

        guard let output = controls.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func flattenPageLighting(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let shadowAdjust = CIFilter.highlightShadowAdjust()
        shadowAdjust.inputImage = ciImage
        shadowAdjust.shadowAmount = 0.75
        shadowAdjust.highlightAmount = 0.95

        let controls = CIFilter.colorControls()
        controls.inputImage = shadowAdjust.outputImage
        controls.brightness = 0.02
        controls.contrast = 1.12
        controls.saturation = 0

        guard let output = controls.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func removeSpeckleNoise(from image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let median = CIFilter.median()
        median.inputImage = ciImage

        guard let output = median.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func balanceNotationContrast(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = ciImage
        colorControls.contrast = 1.18
        colorControls.brightness = 0.01

        let sharpen = CIFilter.sharpenLuminance()
        sharpen.inputImage = colorControls.outputImage
        sharpen.sharpness = 0.45

        guard let output = sharpen.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func preserveNotationEdges(in image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }

        let unsharp = CIFilter.unsharpMask()
        unsharp.inputImage = ciImage
        unsharp.radius = 1.4
        unsharp.intensity = 1.15

        let controls = CIFilter.colorControls()
        controls.inputImage = unsharp.outputImage
        controls.contrast = 1.24
        controls.brightness = 0.005
        controls.saturation = 0

        guard let output = controls.outputImage,
              let cgImage = ciContext.createCGImage(output, from: output.extent) else {
            return image
        }

        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func renderIntoStandardPage(_ image: UIImage) -> UIImage {
        let portrait = image.size.height >= image.size.width
        let canvasSize = portrait ? CGSize(width: 2550, height: 3300) : CGSize(width: 3300, height: 2550)
        let contentRect = CGRect(origin: .zero, size: canvasSize).insetBy(dx: 120, dy: 120)
        let drawRect = aspectFitRect(for: image.size, in: contentRect)

        let renderer = UIGraphicsImageRenderer(size: canvasSize)
        return renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: canvasSize))
            image.draw(in: drawRect)
        }
    }

    private func aspectFitRect(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else { return bounds }

        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let size = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        return CGRect(
            x: bounds.midX - (size.width / 2),
            y: bounds.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Errors

    public enum ScanError: LocalizedError {
        case pdfWriteFailed
        case noPages

        public var errorDescription: String? {
            switch self {
            case .pdfWriteFailed: "Failed to create PDF from scanned pages."
            case .noPages: "No pages were scanned."
            }
        }
    }
}
#endif
