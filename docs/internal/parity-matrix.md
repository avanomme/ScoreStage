# ScoreStage Parity Matrix

Execution plan to reach credible parity with forScore and MobileSheets without drifting into cosmetic-only work.

## Command Contract

When you say:

`Complete next Sprint`

I will:
- implement every in-scope task for the next unfinished sprint
- close obvious sub-gaps required for that sprint to be functionally complete
- verify with builds/tests available in the repo
- commit the sprint work to git
- tell you the sprint is complete and the next sprint is ready

I will not treat a sprint as complete if core functionality in that sprint is still stubbed, missing, or only visually represented.

## Status Scale

- `done`: implemented and verified
- `partial`: exists but is incomplete, shallow, or not production-ready
- `missing`: not implemented

## Sprint Order

1. Sprint 1: Reader / Navigation / Performance
2. Sprint 2: Annotation / Markup
3. Sprint 3: Setlists / Live Show Tools
4. Sprint 4: Library / Import / Metadata
5. Sprint 5: Sync / Backup / Export / Share
6. Sprint 6: Pedals / MIDI / Bluetooth / External Control
7. Sprint 7: Stabilization / QA / Store-readiness

## Sprint 1

### Reader / Navigation / Performance

| Feature | Current | Target |
|---|---|---|
| Single page / paged / scroll / spread reading | `partial` | production-ready and consistent across score types |
| Linked two-device spread | `partial` | stable role behavior, recoverable session state, in-reader controls |
| Mirrored sync / conductor-performer | `partial` | role switching and session controls from reader |
| Bookmark workflow | `partial` | fast save/remove/recall during performance |
| Reader session resume | `partial` | per-score last-page/view restore |
| Performance HUD | `partial` | polished, low-friction, complete live-use command surface |
| Non-linear navigation (DS/DC/Coda, jump links) | `missing` | explicit jump graph and jump UI |
| Repeats / section navigation | `missing` | rehearsal-friendly navigation shortcuts |
| Page cropping / margin presets | `missing` | per-score readable page cleanup controls |
| Brightness / contrast / paper tuning | `partial` | full readable page adjustment controls |
| Performance lock / accidental input prevention | `partial` | reliable stage-safe behavior |
| Half-page turns / alternate turn models | `missing` | configurable page-turn behavior |
| Auto page turns from playback | `partial` | predictable and controllable |
| Quick-jump palette | `missing` | page / bookmark / rehearsal quick access |

### Sprint 1 Done Criteria

- A musician can open a score and perform from it without needing the library UI mid-song.
- Linked-device sessions can be created, switched, and ended from inside the reader.
- Reader state survives closing and reopening the score.
- Jump-heavy scores have explicit navigation tools, not manual workarounds.
- Page presentation controls are usable enough for real scanned music.

### Sprint 1 Task List

- Harden display mode behavior and per-score reader state restore.
- Finish bookmark workflow for live navigation.
- Add quick-jump panel for page/bookmark/rehearsal navigation.
- Implement jump links and non-linear navigation model.
- Add page crop and margin controls with saved score preferences.
- Add readable page tuning controls for contrast/brightness/theme.
- Refine linked-session control surface and role/layout switching.
- Tighten performance lock and touch-safe reading behavior.
- Add configurable page-turn behavior including half-page flow where appropriate.

## Sprint 2

### Annotation / Markup

| Feature | Current | Target |
|---|---|---|
| Pen / pencil / highlighter / eraser | `partial` | polished tool behavior with predictable state |
| Text / shape tools | `partial` | editable created objects, not just placeholders |
| Layer persistence | `partial` | fully persistent create/rename/show/hide/delete |
| Snapshots | `partial` | reliable create/restore/delete flow |
| Musical stamps | `partial` | usable stamp insertion workflow |
| Object selection / move / resize | `missing` | full markup editing pass |
| Annotation export | `partial` | flattened and editable export paths |
| Shared annotation visibility in linked sessions | `missing` | controlled collaborative display behavior |
| Undo / redo depth and reliability | `partial` | stable editing history |

### Sprint 2 Done Criteria

- Annotation workflows are credible for rehearsal, teaching, and performance.
- Objects and layers can be manipulated without destructive workarounds.
- Snapshots and exports are reliable enough to trust.

### Sprint 2 Task List

- Complete persistent layer CRUD and ordering behavior.
- Implement selection/lasso semantics for annotation objects.
- Finish text/shape/stamp placement and editing.
- Harden undo/redo and page-scoped editing.
- Finish snapshot management and export polish.
- Add linked-session annotation display rules.

## Sprint 3

### Setlists / Live Show Tools

| Feature | Current | Target |
|---|---|---|
| Basic setlist CRUD | `partial` | production-ready set management |
| Reordering and song navigation | `partial` | seamless set flow in performance |
| Set notes / cues / pauses | `missing` | live-use show tools |
| Medleys / segues / auto-advance | `missing` | multi-song continuity support |
| Per-set performance presets | `missing` | saved display / playback / link state by set item |
| Fast set navigation during show | `partial` | command surfaces for live use |
| Conductor/band coordination | `partial` | usable linked performance workflow |

### Sprint 3 Done Criteria

- A rehearsal or show can run fully from setlist mode.
- Set transitions are fast and stateful.
- Per-song performance context can be preserved inside a set.

### Sprint 3 Task List

- Complete setlist detail and performance session flow.
- Add set item notes, pauses, and cue surfaces.
- Implement medley/segue/auto-advance behaviors.
- Add per-set-item performance presets.
- Refine setlist navigation overlays and linked session interaction.

## Sprint 4

### Library / Import / Metadata

| Feature | Current | Target |
|---|---|---|
| Library dashboard / browsing | `partial` | complete power-user library workflow |
| Metadata editing | `partial` | broad editable metadata with bulk operations |
| Search / sort / filter | `partial` | advanced filtering and saved organization patterns |
| Collections / tags / favorites | `partial` | robust organization at scale |
| Batch import | `missing` | practical large-library ingestion |
| Image-to-score cleanup | `partial` | reliable single-page crop / deskew / normalize |
| Duplicate detection / merge | `missing` | safe import hygiene |
| Smart collections | `missing` | rules-based organization |

### Sprint 4 Done Criteria

- Users can manage a large library without manual metadata cleanup pain.
- Importing scans and mixed files is robust.
- Search and filters feel like a serious score manager, not a demo library.

### Sprint 4 Task List

- Complete batch import and folder ingestion.
- Add duplicate detection and merge/replace flows.
- Expand metadata model and bulk editing.
- Add smart collections and stronger filtering.
- Refine image import cleanup pipeline and import previews.

## Sprint 5

### Sync / Backup / Export / Share

| Feature | Current | Target |
|---|---|---|
| Cloud sync | `missing` | real sync implementation, not stub |
| Backup / restore | `missing` | dependable recovery workflow |
| Score export | `partial` | score package and annotated export |
| Metadata / setlist export | `missing` | portable project data |
| Conflict handling | `missing` | deterministic recovery behavior |
| Device migration | `missing` | trustworthy transfer path |
| Share workflows | `missing` | practical outbound sharing |

### Sprint 5 Done Criteria

- A user can safely back up, restore, migrate, and sync their library.
- Export and import workflows preserve enough state to be useful in practice.

### Sprint 5 Task List

- Replace sync stubs with real app-level sync architecture.
- Add backup/export packaging for scores, metadata, annotations, and sets.
- Add restore/import flows and conflict handling.
- Implement migration-safe recovery behavior.

## Sprint 6

### Pedals / MIDI / Bluetooth / External Control

| Feature | Current | Target |
|---|---|---|
| Bluetooth pedal support | `partial` | broad device support and configurable actions |
| Keyboard shortcuts | `partial` | customizable and complete |
| MIDI input mapping | `missing` | assignable control actions |
| External transport/navigation control | `missing` | reader and playback command support |
| Linked-device command propagation | `missing` | control behavior across paired devices |

### Sprint 6 Done Criteria

- Common pedal and MIDI workflows function reliably for practice and performance.
- External controls are configurable rather than hardcoded.

### Sprint 6 Task List

- Finish pedal handling abstraction and configuration UI.
- Add MIDI mapping and external command routing.
- Connect external controls to reader, playback, and linked sessions.

## Sprint 7

### Stabilization / QA / Store-readiness

| Feature | Current | Target |
|---|---|---|
| Regression coverage | `partial` | coverage for critical workflows |
| Crash / edge-case hardening | `partial` | stable production behavior |
| Onboarding / paywall / settings polish | `partial` | commercial-ready product surfaces |
| Accessibility | `partial` | acceptable shipping baseline |
| App Store readiness | `partial` | coherent commercial package |

### Sprint 7 Done Criteria

- Core workflows are tested and stable.
- Product surfaces outside the reader are commercially credible.
- Remaining work is incremental polish, not missing core functionality.

## Implementation Notes

- We should not start Sprint 4 before Sprint 1 to 3 are done. The app wins or loses first on live-use credibility.
- Sprint completion is based on functional completeness inside sprint scope, not visual polish alone.
- If a task reveals a prerequisite in shared infrastructure, that prerequisite becomes part of the active sprint.
