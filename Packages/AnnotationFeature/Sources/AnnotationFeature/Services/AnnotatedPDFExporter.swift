import Foundation
import CoreGraphics
import CoreText
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
        objects: [CanvasAnnotationObject],
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
            let pageStrokes = strokes.filter { $0.pageIndex == pageIndex }
            for stroke in pageStrokes {
                drawStroke(stroke, in: context, pageRect: pageRect)
            }

            let pageObjects = objects.filter { $0.pageIndex == pageIndex }
            for object in pageObjects {
                drawObject(object, in: context)
            }

            context.endPage()
        }

        context.closePDF()
        return outputURL
    }

    /// Export raw annotation data as JSON.
    public func exportRawData(
        strokes: [CanvasStroke],
        objects: [CanvasAnnotationObject],
        layers: [LayerInfo],
        outputURL: URL
    ) throws -> URL {
        let payload = RawExportPayload(
            exportDate: Date(),
            layerCount: layers.count,
            strokeCount: strokes.count,
            objectCount: objects.count,
            layers: layers.map { layer in
                RawExportPayload.LayerEntry(
                    id: layer.id,
                    name: layer.name,
                    type: layer.type.rawValue,
                    isVisible: layer.isVisible
                )
            },
            objects: objects.map { object in
                RawExportPayload.ObjectEntry(
                    id: object.id,
                    layerID: object.layerID,
                    type: object.type.rawValue,
                    pageIndex: object.pageIndex,
                    x: object.position.x,
                    y: object.position.y,
                    width: object.size.width,
                    height: object.size.height,
                    rotation: object.rotation,
                    colorHex: object.color.hexString,
                    text: object.text,
                    fontSize: object.fontSize,
                    shapeType: object.shapeType?.rawValue,
                    stampType: object.stampType?.rawValue
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

    private func drawObject(_ object: CanvasAnnotationObject, in context: CGContext) {
        #if canImport(UIKit)
        let cgColor = UIColor(object.color).cgColor
        #elseif canImport(AppKit)
        let cgColor = NSColor(object.color).cgColor
        #endif

        let rect = CGRect(
            x: object.position.x - object.size.width / 2,
            y: object.position.y - object.size.height / 2,
            width: object.size.width,
            height: object.size.height
        )

        context.saveGState()
        context.translateBy(x: object.position.x, y: object.position.y)
        context.rotate(by: object.rotation * .pi / 180)
        context.translateBy(x: -object.position.x, y: -object.position.y)
        context.setStrokeColor(cgColor)
        context.setFillColor(cgColor)
        context.setLineWidth(2)

        switch object.type {
        case .textBox:
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: platformColor(from: object.color),
            .font: platformFont(size: object.fontSize ?? 24)
        ]
            let attributed = NSAttributedString(string: object.text ?? "", attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: rect.minX, y: rect.midY - (object.fontSize ?? 24) / 2)
            CTLineDraw(line, context)
        case .shape:
            drawShapeObject(object, rect: rect, in: context)
        case .stamp:
            let attributes: [NSAttributedString.Key: Any] = [
                .foregroundColor: platformColor(from: object.color),
                .font: platformFont(size: object.fontSize ?? 22)
            ]
            let attributed = NSAttributedString(string: object.text ?? "", attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributed)
            context.textPosition = CGPoint(x: rect.minX, y: rect.midY - (object.fontSize ?? 22) / 2)
            CTLineDraw(line, context)
        case .image:
            context.stroke(rect)
        }
        context.restoreGState()
    }

    private func drawShapeObject(_ object: CanvasAnnotationObject, rect: CGRect, in context: CGContext) {
        switch object.shapeType ?? .rectangle {
        case .circle:
            context.strokeEllipse(in: rect)
        case .rectangle:
            context.stroke(rect)
        case .underline:
            let underlineRect = CGRect(x: rect.minX, y: rect.maxY - 4, width: rect.width, height: 3)
            context.fill(underlineRect)
        case .arrow:
            context.move(to: CGPoint(x: rect.minX, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX - 16, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX - 28, y: rect.midY - 10))
            context.move(to: CGPoint(x: rect.maxX - 16, y: rect.midY))
            context.addLine(to: CGPoint(x: rect.maxX - 28, y: rect.midY + 10))
            context.strokePath()
        }
    }

    private func platformFont(size: Double) -> Any {
        let fontSize = CGFloat(size)
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: fontSize, weight: .semibold)
        #elseif canImport(AppKit)
        return NSFont.systemFont(ofSize: fontSize, weight: .semibold)
        #else
        return CTFontCreateWithName("HelveticaNeue" as CFString, fontSize, nil)
        #endif
    }

    private func platformColor(from color: Color) -> Any {
        #if canImport(UIKit)
        return UIColor(color)
        #elseif canImport(AppKit)
        return NSColor(color)
        #else
        return color
        #endif
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
    let objectCount: Int
    let layers: [LayerEntry]
    let objects: [ObjectEntry]

    struct LayerEntry: Codable {
        let id: UUID
        let name: String
        let type: String
        let isVisible: Bool
    }

    struct ObjectEntry: Codable {
        let id: UUID
        let layerID: UUID
        let type: String
        let pageIndex: Int
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let rotation: Double
        let colorHex: String
        let text: String?
        let fontSize: Double?
        let shapeType: String?
        let stampType: String?
    }
}
