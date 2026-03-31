# Progress Log

Append short session notes here (what changed, why, next steps).

---

## 2026-03-31 — Owner/Admin Account Chain Completed

**What changed:**
- Added a first-class `AdminAccount` model and `AccountRole` enum for `owner`, `admin`, and `user`
- Seeded the permanent owner account through bootstrap using the real password hashing flow instead of a UI-only unlock
- Added a normal sign-in surface so the seeded owner account can authenticate through the application interface
- Wired session state through `AppStorage` so the active account and role drive authorization and UI visibility
- Updated feature gating so owner/admin roles always receive protected features through the authorization layer, including paywall-exempt access
- Added owner/admin surfaces in Settings and a real sign-out path so the full account chain is reachable and testable through the UI
- Documented the architecture in [account-architecture.md](/Users/adam/projects/ScoreStage/docs/internal/account-architecture.md)

**Verification:**
- `swift test` in `Packages/CoreDomain`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Expand the admin surface beyond Settings into a dedicated operational panel when account management and support tooling are added
- Execute the post-parity backlog from [post-parity-backlog.md](/Users/adam/projects/ScoreStage/docs/internal/post-parity-backlog.md)

---

## 2026-03-31 — Post-Parity Backlog: Admin Console + Release Validation

**What changed:**
- Added a dedicated in-app admin console for owner/admin sessions with session diagnostics, feature-gate audits, sync/backup status, and operational actions
- Wired Settings to open that admin console so the remaining backlog can be worked from a visible internal control surface instead of scattered status text
- Added [release-validation-checklist.md](/Users/adam/projects/ScoreStage/docs/internal/release-validation-checklist.md) to turn the remaining post-parity work into explicit closure items with evidence targets
- Updated the post-parity backlog notes to reflect that admin surfaces now exist and the remaining gap is validation, not missing control access

**Verification:**
- `swift test` in `Packages/CoreDomain`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Use the admin console and release checklist to close the remaining verification-heavy backlog items in order
- Prioritize real-device reader and linked-device validation next

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

---

## 2026-03-30 — Post-MVP Parity Matrix Established

**What changed:**
- Added [parity-matrix.md](/Users/adam/projects/ScoreStage/docs/internal/parity-matrix.md) to define the execution path from current state to practical parity with forScore and MobileSheets
- Reframed delivery into 7 sequential sprints focused on musician workflows instead of broad historical phases
- Defined a strict command contract for `Complete next Sprint` so sprint completion means functional completeness, verification, git commit, and readiness for the next sprint
- Captured current status by capability (`done` / `partial` / `missing`) across:
  - reader / navigation / performance
  - annotation / markup
  - setlists / live show tools
  - library / import / metadata
  - sync / backup / export / share
  - pedals / MIDI / Bluetooth / external control
  - stabilization / QA / commercial readiness

**Next steps:**
- Start Sprint 1 from the parity matrix
- Use `Complete next Sprint` as the execution command for each sprint in sequence

---

## 2026-03-30 — Sprint 2 Complete: Annotation / Markup

**What changed:**
- Expanded the annotation model from stroke-only markup into a mixed stroke/object editing system with persistent text, shape, and stamp objects
- Added object selection, move, resize, duplicate, delete, and inspector-driven editing so annotation objects can be revised instead of recreated
- Hardened annotation history behavior to cover layers, page clears, object creation, and object edits through undo/redo
- Upgraded layer management with rename and reordering support, then persisted layer/object state back through the reader save path
- Kept saved annotations visible during normal reading, with linked-session visibility filtering for conductor/performer use cases
- Finished annotation export so flattened PDF export and raw editable data export both include object-based markup in addition to strokes

**Verification:**
- `swift build` in `Packages/AnnotationFeature`
- `swift build` in `Packages/ReaderFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Start Sprint 3 from the parity matrix
- Focus on full setlist and live show workflow completeness before moving to library power-user features

---

## 2026-03-30 — Sprint 3 Complete: Setlists / Live Show Tools

**What changed:**
- Expanded setlist data to carry show-level notes, cueing, transition behavior, medley grouping, auto-advance timing, and per-item reader presets
- Rebuilt the setlist detail workflow into a true performance editor with running-order controls, quick start, item editing, and richer live metadata per song
- Added item-level editing for cues, pause behavior, auto-advance timing, medley labels, and per-song reader presets such as start page, display mode, paper theme, and page-turn behavior
- Upgraded the reader’s setlist session support so live sets can surface cues, set notes, medley context, transition behavior, and countdown-based pauses/auto-advance directly in performance view
- Prevented set-specific reader presets from overwriting the score’s normal saved reading preferences

**Verification:**
- `swift build` in `Packages/CoreDomain`
- `swift build` in `Packages/SetlistFeature`
- `swift build` in `Packages/ReaderFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Start Sprint 4 from the parity matrix
- Focus on library scale, import robustness, metadata power tools, and scan cleanup quality

---

## 2026-03-30 — Sprint 4 Complete: Library / Import / Metadata

**What changed:**
- Rebuilt file import around a staged review flow with duplicate detection, merge/replace decisions, recursive folder ingestion, and batch import summaries instead of blind one-shot imports
- Added smart collections for import triage, missing metadata, rehearsal-active material, performance-ready charts, and scan-heavy libraries
- Added bulk metadata editing from multi-select so library cleanup can happen across many scores at once instead of file by file
- Extended collection browsing to include smart collections as first-class library slices
- Tightened the scan cleanup pipeline with white-point normalization, despeckling, and notation-focused contrast balancing before page export

**Verification:**
- `swift build` in `Packages/CoreDomain`
- `swift build` in `Packages/LibraryFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Start Sprint 5 from the parity matrix
- Focus on real sync, backup, restore, export packages, and migration-safe recovery flows

---

## 2026-03-30 — Sprint 5 Complete: Sync / Backup / Export / Share

**What changed:**
- Replaced the old backup stub with a full package-based backup and restore service that exports library metadata, setlists, bookmarks, score assets, and imported files into a portable `.scorestagebackup` bundle
- Added restore-point creation ahead of imports so destructive or conflicting restores have a local rollback path before library state is changed
- Implemented restore strategies for merge, replace-existing, and keep-both workflows so backup imports can safely coexist with an existing library instead of assuming a blank target
- Added a practical sync mirror flow that snapshots the current library, updates `SyncRecord` state, detects timestamp conflicts, and can import a mirrored library file back into local storage
- Expanded Settings with real backup and restore controls, manual sync execution, conflict visibility, and restore-strategy selection so these workflows are accessible from the app instead of hidden in service code

**Verification:**
- `swift build` in `Packages/SyncFeature`
- `swift build` in `Packages/LibraryFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Start Sprint 6 from the parity matrix
- Focus on pedal support, MIDI mapping, Bluetooth/external control, and live-performance hardware reliability

---

## 2026-03-31 — Sprint 6 Complete: Pedals / MIDI / Bluetooth / External Control

**What changed:**
- Added a shared external-control profile model covering keyboard, pedal, and MIDI mappings, plus linked-session propagation rules, so control behavior is configurable instead of hardcoded
- Reworked page-turn routing into an action-aware control service that can map keyboard keys, Bluetooth pedal roles, and MIDI events into reader, playback, setlist, and lock actions
- Added Bluetooth pedal monitoring through Game Controller input, which covers common pedal-style HID/controller hardware while keyboard-emulating pedals continue to work through configurable key mappings
- Extended MIDI input handling to emit note and control-change events for live control mapping in addition to the existing score-following/practice note tracking
- Integrated external controls directly into the reader with live status badges, an in-reader control panel, configurable command handling for page turns/playback/setlist navigation, and linked-device command propagation for shared performance actions
- Expanded Settings with real external-control configuration for pedal actions, keyboard actions, MIDI mappings, and linked-session propagation behavior

**Verification:**
- `swift build` in `Packages/CoreDomain`
- `swift build` in `Packages/InputTrackingFeature`
- `swift build` in `Packages/PlaybackFeature`
- `swift build` in `Packages/ReaderFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- Start Sprint 7 from the parity matrix
- Focus on stabilization, regression coverage, onboarding/paywall/settings polish, accessibility, and store readiness

---

## 2026-03-31 — Sprint 7 Complete: Stabilization / QA / Commercial Readiness

**What changed:**
- Refined onboarding so the final conversion step now supports both a clean free-library path and a premium upsell path, with clearer value framing and larger accessible tap targets
- Reworked the paywall into a more production-ready purchase surface with plan highlighting, subscription-state feedback, stronger premium messaging, and better accessibility semantics for offer cards and actions
- Expanded Settings with subscription management, analytics/privacy controls, support links, and release-readiness status so operational and commercial workflows are surfaced inside the app
- Added reader-level accessibility actions for page navigation so VoiceOver users can advance through scores without relying on precise gesture targets
- Added regression coverage for external-control defaults/mutation in CoreDomain and page-turn command routing in InputTrackingFeature to lock down recent sprint behavior
- Stabilized the reader root view composition to eliminate the compiler/type-check bottleneck introduced by the now larger performance HUD and reader overlays

**Verification:**
- `swift build` in `Packages/CoreDomain`
- `swift build` in `Packages/InputTrackingFeature`
- `swift build` in `Packages/ReaderFeature`
- `swift test` in `Packages/CoreDomain`
- `swift test` in `Packages/InputTrackingFeature`
- `xcodebuild -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -configuration Debug -destination 'platform=macOS' build`

**Next steps:**
- All currently defined parity-matrix sprints are complete
- The next phase should be a fresh backlog pass for remaining competitive gaps, deeper QA, and App Store submission assets/review prep

---

## 2026-03-31 — Post-Parity Backlog Opened

**What changed:**
- Added [post-parity-backlog.md](/Users/adam/projects/ScoreStage/docs/internal/post-parity-backlog.md) to capture the work that still needs explicit closure after the parity sprint sequence
- Separated remaining work into release blockers, claimed-feature validation, product hardening, and commercial/operations packaging so "parity complete" does not get mistaken for "ship complete"
- Flagged high-risk areas that still need confirmation despite broad feature coverage, including head/eye tracking validation, score-following workflow closure, Handoff exposure, StoreKit production checks, cloud failure-path testing, and real-device linked-session soak testing

**Next steps:**
- Work through the backlog in order, starting with release blockers and claimed-feature validation
- Keep marketing/paywall/App Store copy aligned with only the features that have passed release validation

---

## 2026-03-31 — Owner/Admin Account Architecture Added

**What changed:**
- Added a first-class account model with explicit `owner`, `admin`, and `user` roles in [AdminAccount.swift](/Users/adam/projects/ScoreStage/Packages/CoreDomain/Sources/CoreDomain/Models/AdminAccount.swift)
- Added bootstrap/auth/session support in [AccountAccess.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/AccountAccess.swift), including seeded owner-account creation and hashed password storage flow
- Added a normal sign-in UI in [AccountLoginView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/AccountLoginView.swift) so the seeded owner account is usable through the app interface
- Seeded the permanent owner account `offbyone` through app bootstrap in [ContentView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/ContentView.swift)
- Updated role-based authorization in [StoreService.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/StoreService.swift) so `owner` and `admin` roles get full access through authorization policy rather than UI gating
- Surfaced the active role, seeded accounts, and admin panel status in [SettingsView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/SettingsView.swift)
- Documented the architecture and owner/paywall relationship in [account-architecture.md](/Users/adam/projects/ScoreStage/docs/internal/account-architecture.md)

**Next steps:**
- Add a real sign-in/account-management UI when account workflows are expanded beyond the seeded owner role
- Build future admin tooling on top of the seeded owner/admin role system instead of introducing parallel override paths

**Next steps:**
- Start Sprint 7 from the parity matrix
- Focus on stabilization, QA coverage, commercial polish, accessibility, and store-readiness
