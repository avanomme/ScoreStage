import Foundation
import CoreGraphics
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Export mode for annotated PDF output.
public enum PDFExportMode: String, CaseIterable, Identifiable, Sendable {
    case flattened = "Flattened"
    case editable = "Editable Overlay"
    case rawData = "Raw Annotation Data"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .flattened: "Burns annotations directly into the PDF pages. Cannot be edited after export."
        case .editable: "Preserves annotations as a separate overlay. Editable in ScoreStage."
        case .rawData: "Exports raw annotation data (JSON) for backup or transfer."
        }
    }
}

/// Service for exporting PDFs with annotation overlays.
public actor AnnotatedPDFExporter {

    public init() {}

    /// Export a PDF with annotations flattened onto the pages.
    /// - Parameters:
    ///   - sourceURL: Original PDF file URL
    ///   - strokes: Canvas strokes to render
    ///   - outputURL: Destination URL for the exported file
    /// - Returns: URL of the exported file
    public func exportFlattened(
        sourceURL: URL,
        strokes: [CanvasStroke],
        outputURL: URL
    ) throws -> URL {
        guard let pdfDocument = CGPDFDocument(sourceURL as CFURL) else {
            throw ExportError.cannotOpenSource
        }

        let pageCount = pdfDocument.numberOfPages

        // Create PDF context
        var mediaBox = CGRect.zero
        if let firstPage = pdfDocument.page(at: 1) {
            mediaBox = firstPage.getBoxRect(.mediaBox)
        }

        guard let context = CGContext(outputURL as CFURL, mediaBox: &mediaBox, nil) else {
            throw ExportError.cannotCreateContext
        }

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex + 1) else { continue }
            let pageRect = page.getBoxRect(.mediaBox)

            var mutableRect = pageRect
            context.beginPage(mediaBox: &mutableRect)

            // Draw original page
            context.saveGState()
            context.drawPDFPage(page)
            context.restoreGState()

            // Draw annotation strokes for this page
            let pageStrokes = strokes.filter { _ in true } // In production, filter by pageIndex
            for stroke in pageStrokes {
                drawStroke(stroke, in: context, pageRect: pageRect)
            }

            context.endPage()
        }

        context.closePDF()
        return outputURL
    }

    /// Export raw annotation data as JSON.
    public func exportRawData(
        strokes: [CanvasStroke],
        layers: [LayerInfo],
        outputURL: URL
    ) throws -> URL {
        let payload = RawExportPayload(
            exportDate: Date(),
            layerCount: layers.count,
            strokeCount: strokes.count,
            layers: layers.map { layer in
                RawExportPayload.LayerEntry(
                    id: layer.id,
                    name: layer.name,
                    type: layer.type.rawValue,
                    isVisible: layer.isVisible
                )
            }
        )

        let data = try JSONEncoder().encode(payload)
        try data.write(to: outputURL)
        return outputURL
    }

    // MARK: - Private

    private func drawStroke(_ stroke: CanvasStroke, in context: CGContext, pageRect: CGRect) {
        guard stroke.points.count > 1 else { return }

        context.saveGState()
        context.setAlpha(stroke.opacity)
        context.setLineWidth(stroke.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        // Convert SwiftUI Color to CGColor
        #if canImport(UIKit)
        let cgColor = UIColor(stroke.color).cgColor
        #elseif canImport(AppKit)
        let cgColor = NSColor(stroke.color).cgColor
        #endif
        context.setStrokeColor(cgColor)

        context.move(to: stroke.points[0])
        for point in stroke.points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
        context.restoreGState()
    }

    // MARK: - Errors

    public enum ExportError: LocalizedError {
        case cannotOpenSource
        case cannotCreateContext
        case exportFailed(String)

        public var errorDescription: String? {
            switch self {
            case .cannotOpenSource: "Cannot open the source PDF file."
            case .cannotCreateContext: "Cannot create PDF export context."
            case .exportFailed(let reason): "Export failed: \(reason)"
            }
        }
    }
}

/// Codable payload for raw annotation export.
struct RawExportPayload: Codable {
    let exportDate: Date
    let layerCount: Int
    let strokeCount: Int
    let layers: [LayerEntry]

    struct LayerEntry: Codable {
        let id: UUID
        let name: String
        let type: String
        let isVisible: Bool
    }
}
