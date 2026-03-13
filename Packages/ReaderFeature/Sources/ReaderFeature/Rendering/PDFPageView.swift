import SwiftUI

/// Displays a single rendered PDF page.
public struct PDFPageView: View {
    let image: CGImage?
    let pageSize: CGSize

    public init(image: CGImage?, pageSize: CGSize) {
        self.image = image
        self.pageSize = pageSize
    }

    public var body: some View {
        if let image {
            Image(decorative: image, scale: 2.0)
                .resizable()
                .aspectRatio(pageSize, contentMode: .fit)
        } else {
            Rectangle()
                .fill(Color.white)
                .aspectRatio(pageSize.width / max(pageSize.height, 1), contentMode: .fit)
                .overlay {
                    ProgressView()
                }
        }
    }
}
