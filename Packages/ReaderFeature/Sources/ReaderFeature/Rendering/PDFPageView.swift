import SwiftUI
import AVFoundation
import CoreDomain

public enum ReaderPageSlice {
    case full
    case topHalf
    case bottomHalf
}

/// Displays a single rendered PDF page.
public struct PDFPageView: View {
    let image: CGImage?
    let pageSize: CGSize
    let cropInsets: NormalizedPageInsets
    let brightness: Double
    let contrast: Double
    let slice: ReaderPageSlice

    public init(
        image: CGImage?,
        pageSize: CGSize,
        cropInsets: NormalizedPageInsets = .none,
        brightness: Double = 0,
        contrast: Double = 1.0,
        slice: ReaderPageSlice = .full
    ) {
        self.image = image
        self.pageSize = pageSize
        self.cropInsets = cropInsets
        self.brightness = brightness
        self.contrast = contrast
        self.slice = slice
    }

    public var body: some View {
        GeometryReader { geo in
            if let image {
                renderedPage(image: image, in: geo.size)
            } else {
                Rectangle()
                    .fill(Color.white)
                    .aspectRatio(pageSize.width / max(pageSize.height, 1), contentMode: .fit)
                    .overlay {
                        ProgressView()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func renderedPage(image: CGImage, in size: CGSize) -> some View {
        let pageAspect = max(pageSize.width, 1) / max(pageSize.height, 1)
        let fullRect = AVMakeRect(aspectRatio: CGSize(width: pageAspect, height: 1), insideRect: CGRect(origin: .zero, size: size))
        let needsHalfPagePresentation = slice != .full
        let pageWidth = needsHalfPagePresentation
            ? min(size.width, size.height * 2 * pageAspect)
            : fullRect.width
        let pageHeight = pageWidth / pageAspect
        let overflowY = max(0, pageHeight - size.height)
        let yOffset: CGFloat

        switch slice {
        case .full:
            yOffset = 0
        case .topHalf:
            yOffset = overflowY / 2
        case .bottomHalf:
            yOffset = -overflowY / 2
        }

        let visibleWidth = max(0.2, 1 - cropInsets.leading - cropInsets.trailing)
        let visibleHeight = max(0.2, 1 - cropInsets.top - cropInsets.bottom)
        let scaleX = 1 / visibleWidth
        let scaleY = 1 / visibleHeight
        let offsetX = ((cropInsets.leading - cropInsets.trailing) / visibleWidth) * (pageWidth / 2)
        let offsetCropY = ((cropInsets.top - cropInsets.bottom) / visibleHeight) * (pageHeight / 2)

        return Image(decorative: image, scale: 2.0)
            .resizable()
            .frame(width: pageWidth, height: pageHeight)
            .scaleEffect(x: scaleX, y: scaleY, anchor: .center)
            .offset(x: -offsetX, y: yOffset + offsetCropY)
            .brightness(brightness)
            .contrast(contrast)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .drawingGroup()
    }
}
