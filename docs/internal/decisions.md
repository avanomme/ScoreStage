# Decisions

Record key decisions here as short entries (date, decision, rationale, alternatives).

## 2026-03-13 — App Rename: AureliaScore → ScoreStage
**Decision**: Renamed all targets, bundle IDs, and references from AureliaScore to ScoreStage.
**Rationale**: User direction — the app is called ScoreStage.

## 2026-03-13 — Canvas + DragGesture over PencilKit
**Decision**: Use SwiftUI Canvas with DragGesture for annotation drawing instead of PencilKit.
**Rationale**: Full control over rendering, cross-platform compatibility (macOS), and custom tool behavior. PencilKit is iOS-only and opinionated about tool UX.

## 2026-03-13 — CGContext rendering over PDFView
**Decision**: Use PDFKit only for document loading, render pages via CGContext to CGImage.
**Rationale**: PDFView has limited customization for display modes and page transitions. CGContext rendering gives full control over scaling, caching, and overlay composition.

## 2026-03-13 — iCloud entitlements deferred
**Decision**: Removed iCloud/CloudKit entitlements; CloudKitSyncService is a stub.
**Rationale**: Personal development team (FTBBTCJ34T) does not support iCloud capability. Will enable when enrolled in Apple Developer Program.
