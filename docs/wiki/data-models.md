# Data Models

All models are SwiftData `@Model` classes defined in the `CoreDomain` package. They are registered in `ScoreStageApp.swift` via `allModelTypes`.

## Entity Relationship Diagram

```
Score ──┬── ScoreAsset (1:many)
        ├── AnnotationLayer ── AnnotationStroke (1:many)
        │                   └── AnnotationObject (1:many)
        ├── Bookmark (1:many)
        ├── JumpLink (1:many)
        ├── PlaybackProfile (1:1)
        └── ScoreFamily (many:1)

SetList ── SetListItem (1:many) ── Score (many:1)

RehearsalMark ── Score (many:1)
SyncRecord (standalone)
UserPreference (standalone, key-value)
```

## Core Models

### Score
The primary entity. Fields include:
- Identity: `id`, `title`, `composer`, `arranger`
- Classification: `genre`, `key`, `instrumentation`, `difficulty` (1-10), `duration`
- State: `isFavorite`, `isArchived`, `customTags: [String]`
- File info: `pageCount`, `fileHash` (SHA256 for dedup)
- Timestamps: `createdAt`, `modifiedAt`, `lastOpenedAt`
- Embedded: `viewingPreferences: ViewingPreferences` (Codable struct)

### ScoreAsset
File attachments with types: `.pdf`, `.musicXML`, `.mei`, `.midi`, `.audio`, `.image`. Stores `fileName`, `fileSize`, `relativePath`.

### Annotation System
- **AnnotationLayer**: Named layers with types (default, teacher, performer, rehearsal, custom). Per-page with visibility toggle.
- **AnnotationStroke**: Freehand strokes with tool type (pen/pencil/highlighter/eraser), color, width, opacity, and serialized point data.
- **AnnotationObject**: Typed objects (textBox, shape, stamp, image) with position, size, rotation, and content.

### SetList / SetListItem
Ordered collections of scores for performances. SetListItem links a Score to a SetList with `sortOrder`, `performanceNotes`, and `pauseDuration`.

### Bookmark
Page bookmarks with optional `label`, `color` (hex string), linked to a Score.

### JumpLink
Navigation links for repeats/coda/etc. Types: `coda`, `dalSegno`, `daCapo`, `repeat`, `fine`, `custom`.

### ViewingPreferences (Codable, not @Model)
Per-score display settings: `displayMode`, `paperTheme`, `zoomLevel`, `isCropMarginsEnabled`.

## All Model Types

Registered in `CoreDomain.allModelTypes` (14 types):
Score, ScoreAsset, AnnotationLayer, AnnotationStroke, AnnotationObject, SetList, SetListItem, Bookmark, JumpLink, PlaybackProfile, ScoreFamily, RehearsalMark, SyncRecord, UserPreference
