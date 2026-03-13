import SwiftUI
import CoreDomain
import DesignSystem

/// Full-screen clutter-free performance mode with large tap zones and accidental-touch prevention.
public struct PerformanceModeView: View {
    @State var viewModel: ReaderViewModel
    let fileURL: URL
    @Environment(\.dismiss) private var dismiss
    @State private var showingControls = false
    @State private var controlsTimer: Task<Void, Never>?

    public init(score: Score, fileURL: URL) {
        self._viewModel = State(initialValue: ReaderViewModel(score: score))
        self.fileURL = fileURL
    }

    public var body: some View {
        ZStack {
            viewModel.paperBackgroundColor
                .ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView()
            } else {
                performanceContent
            }

            if showingControls {
                controlsOverlay
            }
        }
        .task {
            await viewModel.loadDocument(from: fileURL)
            viewModel.isPerformanceMode = true
            viewModel.markAsOpened()
        }
        #if os(iOS)
        .statusBarHidden()
        #endif
        .persistentSystemOverlays(.hidden)
    }

    private var performanceContent: some View {
        GeometryReader { geo in
            let pageImage = viewModel.renderedPages[viewModel.currentPageIndex]
            let pageSize = viewModel.pageSize(at: viewModel.currentPageIndex)

            PDFPageView(image: pageImage, pageSize: pageSize)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(performanceTapGesture(in: geo.size))
        }
        .overlay(alignment: .bottomTrailing) {
            Text("\(viewModel.currentPageIndex + 1)")
                .font(ASTypography.captionSmall)
                .foregroundStyle(.white.opacity(0.4))
                .padding(ASSpacing.sm)
        }
    }

    private func performanceTapGesture(in size: CGSize) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let x = value.location.x / size.width
                let y = value.location.y / size.height

                // Top strip: toggle controls
                if y < 0.08 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                    if showingControls { scheduleControlsHide() }
                    return
                }

                // Large right zone (right 60%): next page
                if x > 0.4 {
                    Task { await viewModel.nextPage() }
                }
                // Left zone (left 40%): previous page
                else {
                    Task { await viewModel.previousPage() }
                }
            }
    }

    private var controlsOverlay: some View {
        VStack {
            HStack {
                Button {
                    viewModel.isPerformanceMode = false
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Text("\(viewModel.currentPageIndex + 1) / \(viewModel.pageCount)")
                    .font(ASTypography.label)
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.black.opacity(0.6))

            Spacer()
        }
        .transition(.opacity)
    }

    private func scheduleControlsHide() {
        controlsTimer?.cancel()
        controlsTimer = Task {
            try? await Task.sleep(for: .seconds(3))
            if !Task.isCancelled {
                withAnimation { showingControls = false }
            }
        }
    }
}
