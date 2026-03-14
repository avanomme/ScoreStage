# Phase 2: Advanced Annotation & Device Sync

## Overview

Phase 2 extends the annotation system with multi-layer support, musical stamps, version snapshots, and PDF export. It also introduces peer-to-peer device linking via Multipeer Connectivity for two-device page spread and conductor/performer modes.

---

## Annotation Layers (P2-001)

### Architecture

Annotation layers allow musicians to organize markings by purpose — teacher notes, performer markings, rehearsal cues — with independent visibility toggling.

**Data Model** (`CoreDomain.AnnotationLayer`):
- `AnnotationLayerType`: `.default`, `.teacher`, `.performer`, `.rehearsal`, `.custom`
- Each layer has `name`, `type`, `isVisible`, `sortOrder`
- Layers own `strokes` and `objects` via cascade relationships

**UI State** (`AnnotationFeature.AnnotationState`):
- `layers: [LayerInfo]` — lightweight UI models decoupled from SwiftData
- `activeLayerID: UUID?` — currently active layer for new strokes
- `visibleLayerIDs: Set<UUID>` — computed from `layers.filter(\.isVisible)`

**Layer Manager** (`LayerManagerView`):
- Floating panel matching annotation toolbar style (`.ultraThinMaterial`)
- Create new layers with name and type picker
- Tap to select active layer, eye icon to toggle visibility
- Delete non-default layers

**Canvas Integration** (`AnnotationCanvasView`):
- `CanvasStroke` struct stores `layerID`, `color`, `lineWidth`, `opacity` per stroke
- Canvas only renders strokes for visible layers
- New strokes are written to the active layer

### Layer Type Color Coding

| Type       | Color   | Icon              |
|------------|---------|-------------------|
| Default    | Primary | `square.stack`    |
| Teacher    | Blue    | `person.fill`     |
| Performer  | Green   | `music.note`      |
| Rehearsal  | Purple  | `metronome`       |
| Custom     | Red     | `paintbrush`      |

---

## Stamps & Symbols Library (P2-002)

### Musical Stamps

Pre-defined musical notation stamps organized by category:

| Category   | Stamps                        |
|------------|-------------------------------|
| Breathing  | Breath Mark, Cutoff           |
| Bowing     | Up Bow, Down Bow              |
| Dynamics   | Fermata                       |
| Rehearsal  | Cue Marker                    |
| Symbols    | Fingering                     |

**Components**:
- `StampSymbol` — stamp definition with id, name, category, icon, stampType
- `StampLibrary` — static collection of all available stamps
- `StampPickerView` — floating categorized grid with category tabs
- Toolbar integration via `music.note` button

---

## Version Snapshots (P2-003)

### Snapshot System

Point-in-time snapshots of annotation state for restore/rollback.

**Data Model** (`CoreDomain.AnnotationSnapshot`):
- SwiftData model with `name`, `createdAt`, `snapshotData` (JSON)
- Linked to `Score` via cascade relationship

**Serialization** (`AnnotationSnapshotPayload`):
- Codable struct capturing layers, strokes, and objects
- Nested `LayerPayload`, `StrokePayload`, `ObjectPayload`

**UI** (`SnapshotManagerView`):
- Create snapshots with custom names
- Browse existing snapshots (newest first)
- Restore via callback, delete individual snapshots
- Empty state with guidance text

---

## Annotated PDF Export (P2-004)

### Export Modes

| Mode             | Description                                           |
|------------------|-------------------------------------------------------|
| Flattened        | Burns annotations into PDF pages (non-editable)       |
| Editable Overlay | Preserves as separate layer (ScoreStage-editable)     |
| Raw Data         | JSON export of annotation data for backup/transfer    |

**Service** (`AnnotatedPDFExporter`):
- Actor-isolated for thread safety
- `exportFlattened()` — renders strokes onto each PDF page via CoreGraphics
- `exportRawData()` — serializes layer/stroke info as JSON

**UI** (`ExportAnnotationsView`):
- Sheet with radio-button mode selection
- Description text for each mode
- Async export with progress indicator
- Success/error feedback

---

## CloudKit Annotation Sync (P2-005)

### Conflict Resolution

Extends the base `CloudKitSyncService` with annotation-specific sync:

**Strategies** (`AnnotationConflictStrategy`):
- Keep Local — local changes overwrite remote
- Keep Remote — remote changes overwrite local
- Merge Both — combine strokes from both
- Ask Each Time — present conflict resolution UI

**Conflict Model** (`AnnotationConflict`):
- Tracks `layerID`, `layerName`, local/remote modification dates
- `ConflictResolution` enum for resolution choice

**Per-Layer Status** (`LayerSyncStatus`):
- `.synced`, `.pendingUpload`, `.pendingDownload`, `.conflict`, `.error`

---

## Device Linking (P2-006)

### Multipeer Connectivity

Peer-to-peer device pairing using Apple's Multipeer Connectivity framework.

**Service** (`DeviceLinkService`):
- Service type: `scorestage-lnk`
- `MCSession` with required encryption
- Advertise + Browse simultaneously
- Auto-accept invitations (can add confirmation)
- JSON-encoded `LinkMessage` protocol for communication

**Message Types**:
- `pageChanged(pageIndex:)` — sync navigation
- `displayModeChanged(mode:)` — switch display mode
- `roleAssignment(role:)` — assign device roles
- `scoreOpened(scoreID:)` — open same score
- `sessionEnded` — clean disconnect

**UI** (`DevicePairingView`):
- Connection status indicator
- Connected peers list with role badges
- Nearby device discovery with connect buttons
- Start/stop scanning, disconnect actions

---

## Two-Device Page Spread (P2-007)

### Architecture

One score displayed across two devices — left page on primary, right page on secondary.

**View** (`TwoDeviceSpreadView<PageContent>`):
- Generic over page content
- Primary shows even-indexed page, secondary shows odd-indexed
- Role indicator overlay (left/right page badge)
- End-of-score placeholder for secondary beyond last page

**Navigation**:
- `nextSpread()` — advance by 2 pages
- `previousSpread()` — go back by 2 pages
- `configureSpreadRoles()` — assign primary/secondary

---

## Conductor/Performer Mode (P2-008)

### Architecture

Conductor controls navigation; performers follow in sync.

**Roles**:
- **Conductor** — has navigation controls, sends page changes
- **Performer** — follows conductor, no navigation controls

**View** (`ConductorPerformerView<PageContent>`):
- Top bar with role badge, connection status, page indicator
- Conductor bottom controls: back/forward chevrons with page display
- Floating translucent control bar matching app design language

**Setup**:
- `configureConductorMode()` — set self as conductor, assign connected peers as performers
- `configurePerformerMode()` — follow conductor navigation

---

## File Map

| File | Purpose |
|------|---------|
| `AnnotationFeature/Views/LayerManagerView.swift` | Layer management floating panel |
| `AnnotationFeature/Views/StampPickerView.swift` | Musical stamps grid picker |
| `AnnotationFeature/Views/SnapshotManagerView.swift` | Snapshot create/browse/restore |
| `AnnotationFeature/Views/ExportAnnotationsView.swift` | PDF export mode selection sheet |
| `AnnotationFeature/Views/AnnotationCanvasView.swift` | Layer-aware drawing canvas |
| `AnnotationFeature/Views/AnnotationToolbar.swift` | Updated with layers, stamps, snapshots state |
| `AnnotationFeature/Services/AnnotatedPDFExporter.swift` | Flattened/raw PDF export actor |
| `CoreDomain/Models/AnnotationSnapshot.swift` | SwiftData snapshot model + payload |
| `SyncFeature/AnnotationSyncService.swift` | CloudKit annotation sync + conflicts |
| `DeviceLinkFeature/DeviceLinkFeature.swift` | Multipeer service + messages |
| `DeviceLinkFeature/Views/DevicePairingView.swift` | Device pairing UI |
| `DeviceLinkFeature/Views/TwoDeviceSpreadView.swift` | Two-device spread display |
| `DeviceLinkFeature/Views/ConductorPerformerView.swift` | Conductor/performer mode |
