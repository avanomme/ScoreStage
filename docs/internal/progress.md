# Progress Log

Append short session notes here (what changed, why, next steps).

---

## 2026-03-13 — Bootstrap: Task Generation

**What changed:**
- Generated `.claude/tasks.json` with 63 tasks across 7 phases (Phase 0–6)
- Populated `docs/internal/scope.md` with full project scope, tech stack, phase summary, MVP definition, and architectural decisions
- All tasks derived from `project.md` — no invented requirements

**Phase breakdown:**
- Phase 0: 6 scaffolding tasks (Xcode, SPM, models, design system, navigation, samples)
- Phase 1: 19 MVP tasks (import, library, PDF reader, annotations, setlists, bookmarks, sync, pedals, polish)
- Phase 2: 9 tasks (annotation layers, stamps, versioning, export, device linking)
- Phase 3: 11 tasks (MusicXML, playback engine, mixer, looping, cursor)
- Phase 4: 5 tasks (head/eye tracking, calibration, safety)
- Phase 5: 6 tasks (jump logic, score families, Handoff, MIDI, score-following)
- Phase 6: 7 tasks (onboarding, IAP, analytics, accessibility, App Store)

**Next steps:**
- Begin Phase 0: Create Xcode project and SPM package structure
- Run `/next_phase` to start implementing Phase 0 scaffolding

---

## 2026-03-13 — Phase 0: Project Scaffolding Complete

**What changed:**
- Created Xcode project via XcodeGen with iOS and macOS targets (P0-001)
- Created 11 local SPM packages under Packages/ with proper dependencies (P0-002)
- Defined 14 SwiftData models in CoreDomain: Score, ScoreAsset, AnnotationLayer, AnnotationStroke, AnnotationObject, SetList, SetListItem, Bookmark, JumpLink, PlaybackProfile, ScoreFamily, RehearsalMark, SyncRecord, UserPreference (P0-003)
- Built DesignSystem package with color tokens (ASColors), typography (ASTypography), spacing (ASSpacing/ASRadius), and reusable components: GlassCard, PremiumButton, EmptyStateView (P0-004)
- Set up app entry point with platform-adaptive navigation: TabView on iOS, NavigationSplitView sidebar on macOS. Three tabs: Library, Setlists, Settings (P0-005)
- Generated 3 sample PDF scores (Moonlight Sonata, Clair de Lune, Ave Maria) with staff lines (P0-006)
- 5 CoreDomain unit tests passing
- Both iOS and macOS targets build successfully

**Architecture decisions:**
- XcodeGen for project generation (project.yml is source of truth)
- iCloud/CloudKit entitlements deferred until proper team setup (personal dev team limitation)
- Cross-platform colors via `#if canImport(UIKit/AppKit)` conditionals
- Swift 6.0 with strict concurrency enabled
- ViewingPreferences as a Codable struct (not @Model) since it's stored as a property on Score

**Next steps:**
- Begin Phase 1: Premium PDF Reader MVP
- Run `/next_phase` to start implementing Phase 1

---

## 2026-03-13 — Phase 1: Premium PDF Reader MVP Complete

**What changed:**
- Built ScoreImportService with SHA256 dedup, metadata extraction from filename, PDF page count (P1-001)
- Created ScoreMetadataEditor with full field editing and TagsEditor (P1-002)
- Built LibraryHomeView with grid/list toggle, search, sort (5 modes), favorites filter, context menus (P1-003)
- Built CollectionsBrowserView for tags/composers/genres browsing (P1-004)
- Built ScoreDetailView with header, metadata card, tags FlowLayout, assets, actions (P1-005)
- Built PDFRenderService with NSCache (10 pages), CGContext rendering, prefetch (P1-006)
- Built ScoreReaderView with 4 display modes: single, horizontal, vertical, two-page spread (P1-007)
- Built PerformanceModeView with auto-hiding controls, large tap zones (P1-008)
- Built AnnotationToolbarView with 6 tools, color palette, line width, opacity, undo/redo (P1-009)
- Built AnnotationCanvasView with SwiftUI Canvas + DragGesture drawing (P1-010)
- Built SetlistListView with create, duplicate, delete (P1-011)
- Built SetlistDetailView with reorder, add scores sheet (P1-012)
- Built BookmarksPanel with add/delete, page jump (P1-013)
- Created CloudKitSyncService stub with SyncState enum (P1-014)
- Built PageTurnService and ReaderKeyboardShortcuts (P1-015, P1-016)
- Built SettingsView with display, page turning, sync, storage sections (P1-017)
- Added UI polish: entrance animations, hover effects, press animations, transitions (P1-018)
- Created wiki docs (9 pages) in docs/wiki/ (P1-019)
- Renamed entire project from AureliaScore to ScoreStage

**Next steps:**
- Begin Phase 2: Advanced Annotation + Device Sync

---

## 2026-03-13 — Phase 2: Advanced Annotation + Device Sync Complete

**What changed:**
- Built multi-layer annotation system with LayerInfo, LayerManagerView, layer-aware CanvasStroke rendering (P2-001)
- Added musical stamps library with StampSymbol, StampCategory, StampPickerView, StampLibrary (P2-002)
- Created annotation version snapshots with AnnotationSnapshot SwiftData model, SnapshotManagerView, AnnotationSnapshotPayload (P2-003)
- Built annotated PDF export with AnnotatedPDFExporter (flattened/raw modes), ExportAnnotationsView (P2-004)
- Implemented AnnotationSyncService with conflict resolution strategies, per-layer sync status (P2-005)
- Built DeviceLinkService with Multipeer Connectivity (MCSession, MCNearbyServiceAdvertiser/Browser), LinkMessage protocol, DevicePairingView (P2-006)
- Created TwoDeviceSpreadView with left/right page distribution, spread navigation (P2-007)
- Created ConductorPerformerView with role-based UI, conductor navigation controls, performer follow mode (P2-008)
- Wrote comprehensive Phase 2 wiki documentation (P2-009)

**Architecture decisions:**
- CanvasStroke stores per-stroke visual properties + layerID for layer-aware rendering
- LayerInfo is a lightweight UI struct decoupled from SwiftData AnnotationLayer
- AnnotatedPDFExporter uses actor isolation for thread safety
- DeviceLinkService uses nonisolated(unsafe) for MCSession to bridge @MainActor and delegate callbacks
- Multipeer auto-accepts invitations (can add user confirmation later)

**Next steps:**
- Begin Phase 3: Structured Notation Playback
