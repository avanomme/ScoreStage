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
