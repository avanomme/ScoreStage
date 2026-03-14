# Phase 5: Advanced Musical Intelligence

## Overview

Phase 5 adds structural navigation (D.C., D.S., Coda, repeats), score family linking (full score + parts + editions), cross-device Handoff, MIDI keyboard practice comparison, and experimental microphone-based score following.

---

## Jump Navigation Engine (P5-001)

### Architecture

**File**: `NotationFeature/Navigation/JumpNavigationEngine.swift`

Resolves structural navigation markers in a `NormalizedScore` into a linear playback sequence. Handles:

- **Repeats** — forward/backward repeat barlines with configurable repeat count
- **D.C. (Da Capo)** — return to the beginning
- **D.S. (Dal Segno)** — return to the segno marker
- **Coda** — jump to coda section (resolves paired coda markers)
- **Fine** — end playback after a D.C./D.S. return
- **Endings** — first/second ending support

### PlaybackStep

Each step in the resolved sequence contains:

| Field | Type | Description |
|-------|------|-------------|
| `measureNumber` | `Int` | Measure to play |
| `isRepeat` | `Bool` | Whether this is a repeated visit |
| `reason` | `String` | Why we're here ("D.C.", "Coda", "Repeat", "Fine") |

### NavigationHotspot

Tappable markers extracted from the score for UI navigation:

| Field | Type | Description |
|-------|------|-------------|
| `measureNumber` | `Int` | Measure containing the marker |
| `type` | `DirectionType` | segno, coda, daCapo, dalSegno, fine |
| `label` | `String` | Display text (𝄋, 𝄌, D.C., D.S., Fine) |
| `destinationMeasure` | `Int?` | Where tapping would jump to |

### Usage

```swift
let engine = JumpNavigationEngine()
let steps = engine.resolvePlaybackOrder(from: normalizedScore)
let hotspots = engine.extractHotspots(from: normalizedScore)
```

---

## Score Family Linking (P5-002)

### Enhanced ScoreFamily Model

**File**: `CoreDomain/Models/ScoreFamily.swift`

Extended the existing `ScoreFamily` SwiftData model with:

| Field | Type | Purpose |
|-------|------|---------|
| `composer` | `String` | Work composer |
| `catalogNumber` | `String` | Opus/catalog number |
| `scoreRoles` | `[String: String]` | Role per score (UUID → ScoreRole) |
| `pageReferences` | `[String]` | JSON-encoded cross-references |
| `modifiedAt` | `Date` | Last modification |

### ScoreRole Enum

| Role | Description |
|------|-------------|
| `.fullScore` | Conductor's full score |
| `.part` | Individual instrument part |
| `.pianoReduction` | Piano/vocal reduction |
| `.alternateEdition` | Different edition of same work |
| `.arrangement` | Different instrumentation |

### ScoreFamilyService

**File**: `LibraryFeature/Services/ScoreFamilyService.swift`

CRUD operations for score families:

| Method | Description |
|--------|-------------|
| `createFamily(name:composer:scores:)` | Create family with initial scores |
| `addScore(_:to:role:)` | Add score with role |
| `removeScore(_:from:)` | Unlink score |
| `setRole(_:for:in:)` | Change score's role |
| `relatedScores(for:)` | Find siblings |
| `addPageReference(from:page:to:page:in:)` | Cross-reference pages |
| `pageReferences(for:in:)` | Get page references |

### Computed Properties on ScoreFamily

- `fullScore` — The conductor score, if any
- `parts` — All part scores
- `alternateEditions` — All alternate editions

---

## Cross-Device Handoff (P5-003)

### Architecture

**File**: `SyncFeature/HandoffService.swift`

Uses `NSUserActivity` for native Apple Handoff between iPhone, iPad, and Mac.

### Activity Types

| Type | Description |
|------|-------------|
| `com.scorestage.viewing-score` | Currently viewing a specific score |
| `com.scorestage.setlist-session` | Active setlist performance |
| `com.scorestage.browsing` | Browsing the library |

### HandoffState

Serializable state transferred between devices:

| Field | Type | Description |
|-------|------|-------------|
| `scoreID` | `UUID?` | Current score |
| `pageIndex` | `Int` | Current page position |
| `setlistID` | `UUID?` | Active setlist |
| `setlistItemIndex` | `Int?` | Position in setlist |
| `displayMode` | `String?` | Reader display mode |
| `timestamp` | `Date` | When state was captured |

### Usage

```swift
// Advertise on source device
handoffService.advertiseScoreViewing(scoreID: score.id, pageIndex: currentPage)

// Handle on receiving device (in app's onContinueUserActivity)
if let state = handoffService.handleIncomingActivity(activity) {
    navigateToScore(state.scoreID, page: state.pageIndex)
}
```

### Info.plist Requirement

Add to `NSUserActivityTypes`:
- `com.scorestage.viewing-score`
- `com.scorestage.setlist-session`
- `com.scorestage.browsing`

---

## MIDI Keyboard Input (P5-004)

### Architecture

**File**: `PlaybackFeature/MIDI/MIDIInputService.swift`

`@MainActor @Observable` service using CoreMIDI for real-time MIDI input.

### Features

- Auto-connects to all available MIDI sources
- Real-time note on/off processing via `MIDIInputPortCreateWithProtocol`
- Chord detection (tracks all active notes)
- Note comparison against expected score position
- Running accuracy statistics

### Match Results

| Result | Meaning |
|--------|---------|
| `.correct` | Played notes match expected notes |
| `.incorrect` | No overlap with expected notes |
| `.partial` | Some chord tones correct |
| `.none` | No expected notes set |

### Integration

```swift
let midiInput = MIDIInputService()
midiInput.start()

// Set expected notes from current measure
midiInput.setExpectedNotes(from: currentMeasure.notes, transposeSemitones: 0)

// Check match result
switch midiInput.lastMatchResult {
case .correct: showGreenHighlight()
case .incorrect: showRedHighlight()
}
```

### Accuracy Tracking

- `correctCount` / `incorrectCount` — running totals
- `accuracy` — percentage (0–100)
- `resetCounters()` — reset for new practice session

---

## Score Following (P5-005)

### Architecture

**File**: `PlaybackFeature/MIDI/ScoreFollowingService.swift`

**Status**: Experimental prototype

Microphone-based pitch detection using autocorrelation, with alignment against the score's note sequence for automatic score position tracking.

### Pitch Detection

- Uses `AVAudioEngine` input tap for real-time audio capture
- Autocorrelation-based fundamental frequency detection via Accelerate framework (`vDSP_dotpr`)
- Frequency range: 50 Hz – 2000 Hz
- Buffer size: 4096 samples for ~93ms analysis windows
- Confidence metric from normalized autocorrelation peak

### Score Alignment

1. Score notes loaded as `(measureNumber, midiNote, position)` sequence
2. Detected pitch converted to MIDI note number
3. Sliding window search (±2 behind, +10 ahead) for matching note
4. 1 semitone tolerance for temperament/tuning differences
5. 3 consecutive matches required before updating position
6. Reports `estimatedMeasure` and `measureProgress`

### States

| State | Meaning |
|-------|---------|
| `.idle` | Not started |
| `.listening` | Microphone active, waiting for first match |
| `.following` | Actively tracking score position |
| `.lost` | Can't match — performer may have skipped ahead |
| `.micUnavailable` | No microphone access |
| `.permissionDenied` | User denied microphone permission |

### Limitations (Research Notes)

- Autocorrelation works best for single monophonic lines
- Polyphonic/chordal input may produce unreliable results
- Environmental noise degrades confidence
- Latency of ~100ms from buffer analysis
- No rhythm tracking — pitch only
- Future work: FFT-based detection, DTW alignment, ML models

---

## File Map

| File | Purpose |
|------|---------|
| `NotationFeature/Navigation/JumpNavigationEngine.swift` | D.C./D.S./Coda/repeat resolution |
| `CoreDomain/Models/ScoreFamily.swift` | Enhanced family model with roles |
| `LibraryFeature/Services/ScoreFamilyService.swift` | Family CRUD operations |
| `SyncFeature/HandoffService.swift` | NSUserActivity Handoff |
| `PlaybackFeature/MIDI/MIDIInputService.swift` | MIDI keyboard input + comparison |
| `PlaybackFeature/MIDI/ScoreFollowingService.swift` | Microphone pitch detection + alignment |
