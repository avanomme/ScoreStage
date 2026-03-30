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

    // MARK: - Filters

    private func applyAdaptiveThreshold(_ input: CIImage) -> CIImage {
        // Convert to grayscale first
        let grayscale = applyGrayscale(input)

        // Increase contrast dramatically for B&W effect
        let colorControls = CIFilter.colorControls()
        colorControls.inputImage = grayscale
        colorControls.contrast = 3.0
        colorControls.brightness = 0.1
        guard let contrasted = colorControls.outputImage else { return input }

        // Clamp to pure B&W using CIFilter key-value API
        guard let clamp = CIFilter(
            name: "CIColorClamp",
            parameters: [
                kCIInputImageKey: contrasted,
                "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 1),
                "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
            ]
        ) else { return contrasted }

        return clamp.outputImage ?? contrasted
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
        let borderTrimmed = trimBackgroundBorder(from: pageIsolated)
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
