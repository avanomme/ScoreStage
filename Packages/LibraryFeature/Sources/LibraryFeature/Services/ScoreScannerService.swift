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
        guard let ciImage = CIImage(image: image) else { return image }

        let filtered: CIImage
        switch filter {
        case .original:
            return image
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
            return image
        }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
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
        let pdfDocument = PDFDocument()

        for (index, image) in pages.enumerated() {
            // Render at high quality for print-like output
            let targetSize = optimizedPageSize(for: image)
            let renderer = UIGraphicsImageRenderer(size: targetSize)
            let rendered = renderer.image { ctx in
                // White background
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: targetSize))
                // Draw image scaled to fit
                image.draw(in: CGRect(origin: .zero, size: targetSize))
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
        let maxDimension: CGFloat = 3300 // ~11" at 300 DPI (letter size)
        let size = image.size
        let scale = min(maxDimension / size.width, maxDimension / size.height, 1.0)
        return CGSize(width: size.width * scale, height: size.height * scale)
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
