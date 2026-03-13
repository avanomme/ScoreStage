# PDF Reader Feature

The Reader feature provides high-performance PDF rendering with multiple display modes and a distraction-free performance mode.

## Package: `ReaderFeature`

### PDF Rendering (`PDFRenderService`)

High-performance rendering service:
- **Backend**: PDFKit for document loading, CGContext for page rendering to CGImage
- **Caching**: NSCache with 10-page limit for rendered images
- **Prefetching**: Preloads adjacent pages (current ± 1) for smooth navigation
- **Concurrency**: Dedicated concurrent DispatchQueue (`com.scorestage.pdfrender`)
- **Scale**: Renders at 2x scale for Retina displays

### Reader View Model (`ReaderViewModel`)

Observable state manager:
- Page navigation (next/previous with bounds checking)
- Display mode management (single, horizontal, vertical, two-page spread)
- Paper theme and background color
- Zoom level control (50% - 300%)
- Performance mode toggle
- Score viewing preferences persistence

### Score Reader (`ScoreReaderView`)

Main reader interface with 4 display modes:

| Mode | Description |
|---|---|
| **Single Page** | One page at a time with tap-to-turn gesture |
| **Horizontal Paged** | TabView-based horizontal swiping |
| **Vertical Scroll** | Continuous vertical scrolling through all pages |
| **Two-Page Spread** | Side-by-side pages for landscape/large screens |

Features:
- Paper theme backgrounds (white, cream, warm, dark)
- Tap gesture: right 60% = next page, left 40% = previous page
- Page number indicator overlay
- Toolbar with view options (display mode picker, zoom, paper theme, performance mode toggle)

### Performance Mode (`PerformanceModeView`)

Distraction-free reading for live performance:
- Full-screen with no navigation chrome
- Large tap zones: right 60% forward, left 40% back
- Auto-hiding controls (visible for 3 seconds after interaction)
- Top strip to toggle control visibility
- Minimal page number overlay
- Status bar hidden (iOS)

### Bookmarks (`BookmarksPanel`)

Side panel for page bookmarks:
- List of bookmarks with page numbers and labels
- Tap to jump to bookmarked page
- Add bookmark for current page
- Delete bookmarks with swipe
- Color support via hex string parsing (`Color(hex:)` extension)
