import Foundation
import PDFKit
import SwiftUI
import CoreDomain

/// High-performance PDF rendering service with page caching and prefetching.
public final class PDFRenderService: @unchecked Sendable {
    private var document: PDFDocument?
    private let cache = NSCache<NSNumber, CGImage>()
    private let renderQueue = DispatchQueue(label: "com.scorestage.pdfrender", qos: .userInitiated, attributes: .concurrent)

    public init() {
        cache.countLimit = 10 // Keep ~10 rendered pages in memory
    }

    // MARK: - Document Management

    public func loadDocument(from url: URL) -> Bool {
        guard let doc = PDFDocument(url: url) else { return false }
        self.document = doc
        cache.removeAllObjects()
        return true
    }

    public func loadDocument(from data: Data) -> Bool {
        guard let doc = PDFDocument(data: data) else { return false }
        self.document = doc
        cache.removeAllObjects()
        return true
    }

    public var pageCount: Int {
        document?.pageCount ?? 0
    }

    public var isLoaded: Bool {
        document != nil
    }

    // MARK: - Page Rendering

    /// Render a single page as a CGImage at the given scale.
    public func renderPage(at index: Int, scale: CGFloat = 2.0) async -> CGImage? {
        let key = NSNumber(value: index * 1000 + Int(scale * 100))
        if let cached = cache.object(forKey: key) { return cached }

        guard let page = document?.page(at: index) else { return nil }

        return await withCheckedContinuation { (continuation: CheckedContinuation<CGImage?, Never>) in
            renderQueue.async { [weak self] in
                let bounds = page.bounds(for: .mediaBox)
                let width = Int(bounds.width * scale)
                let height = Int(bounds.height * scale)

                guard let ctx = CGContext(
                    data: nil,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: 0,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                ) else {
                    continuation.resume(returning: nil)
                    return
                }

                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
                ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
                ctx.scaleBy(x: scale, y: scale)

                #if canImport(UIKit)
                // PDFPage.draw applies a flip; we need to match coordinate systems
                ctx.translateBy(x: 0, y: bounds.height)
                ctx.scaleBy(x: 1, y: -1)
                #endif

                page.draw(with: .mediaBox, to: ctx)

                let image = ctx.makeImage()
                if let image {
                    self?.cache.setObject(image, forKey: key)
                }
                continuation.resume(returning: image)
            }
        }
    }

    /// Prefetch adjacent pages for smooth page turns.
    public func prefetchPages(around index: Int, scale: CGFloat = 2.0) {
        let indices = [index - 1, index + 1, index + 2].filter { $0 >= 0 && $0 < pageCount }
        for i in indices {
            Task { _ = await renderPage(at: i, scale: scale) }
        }
    }

    /// Get page size at the given index.
    public func pageSize(at index: Int) -> CGSize {
        guard let page = document?.page(at: index) else { return .zero }
        let bounds = page.bounds(for: .mediaBox)
        return CGSize(width: bounds.width, height: bounds.height)
    }

    public func clearCache() {
        cache.removeAllObjects()
    }
}
