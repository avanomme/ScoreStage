# Phase 3: Structured Notation Playback

## Overview

Phase 3 adds MusicXML/MEI parsing, a normalized in-memory score model, audio playback via AVAudioEngine, DAW-style transport controls, looping, a per-part mixer, visual playhead, rehearsal mark navigation, and transposition-aware playback.

---

## Normalized Score Model (P3-001)

### Architecture

The `NormalizedScore` is a transient, in-memory representation of parsed notation — NOT a SwiftData model. It's consumed by the playback engine, measure map, and rehearsal marks panel.

**Key Types** (`NotationFeature/Models/NormalizedScore.swift`):

| Type | Purpose |
|------|---------|
| `NormalizedScore` | Top-level container: title, composer, parts, metadata |
| `Part` | Single instrument/voice: name, MIDI program/channel, transpose, measures |
| `Measure` | Bar: time sig, key sig, tempo, notes, directions, barlines, repeats |
| `NoteEvent` | Note/rest: pitch, duration, voice, staff, articulations, dynamics |
| `Pitch` | Step (C–B) + alter (-2 to +2) + octave → `midiNote` computed |
| `TimeSignature` | beats/beatType → `quarterNotesPerMeasure` |
| `KeySignature` | fifths (-7 to +7) + mode → `keyName` computed |
| `TempoMarking` | BPM + beat unit + text label |
| `Direction` | Rehearsal marks, segno, coda, D.C., D.S., dynamics, text |

---

## MusicXML Parser (P3-001)

**File**: `NotationFeature/Parsers/MusicXMLParser.swift`

- Actor-isolated (`public actor MusicXMLParser`)
- Parses `.xml`, `.musicxml`, and compressed `.mxl` (ZIP) files
- Uses Foundation `XMLParser` with a delegate for streaming parse
- Extracts: parts, measures, notes, rests, pitches, durations, time/key signatures, tempo, dynamics, articulations, directions, barlines, repeats, endings
- MXL decompression via `/usr/bin/unzip` on macOS

---

## MEI Parser (P3-002)

**File**: `NotationFeature/Parsers/MEIParser.swift`

- Actor-isolated (`public actor MEIParser`)
- Parses MEI XML into the same `NormalizedScore` model
- Maps MEI elements: `<staffDef>` → Part, `<measure>` → Measure, `<note>` → NoteEvent
- Handles MEI-specific: `pname`/`oct` pitch format, duration as integers ("4" = quarter), `key.sig` format ("3f" = 3 flats), `<reh>` rehearsal marks, `<dynam>` dynamics

---

## Measure Map & Timing Engine (P3-003)

**File**: `NotationFeature/Models/MeasureMap.swift`

### MeasureMap

Pre-computed timeline mapping every measure to absolute seconds.

- Built from `NormalizedScore` + optional tempo override
- Handles tempo changes and time signature changes
- Binary search for measure lookup by time
- `withTempo()` creates a rescaled copy

### MeasureTimingEntry

Per-measure data: `startTime`, `duration`, `tempo`, `timeSignature`, `keySignature`, `rehearsalMark`, `directions`.

### PlaybackEventScheduler

Generates a flat, sorted `[PlaybackEvent]` from score + measure map:
- `noteOn` / `noteOff` events with MIDI note, velocity, timing
- Supports transposition via `transposeSemitones` parameter

---

## Audio Playback Engine (P3-004)

**File**: `PlaybackFeature/Engine/PlaybackEngine.swift`

- `@MainActor @Observable` for SwiftUI binding
- AVAudioEngine + AVAudioUnitSampler for soundfont rendering
- Loads `GeneralUser.sf2` if available in bundle
- ~120Hz update loop via `Task.sleep(for: .milliseconds(8))`
- Real-time event processing with binary search index

### Transport Controls

| Method | Behavior |
|--------|----------|
| `play()` | Start/resume playback |
| `pause()` | Pause, preserve position |
| `stop()` | Stop, reset to beginning |
| `seek(toMeasure:)` | Jump to measure start |
| `seek(to:)` | Jump to absolute time |
| `setTempo(_:)` | Change tempo, rescale events |

### Mixer

- Per-part volume (`partVolumes: [Float]`)
- Mute set (`mutedParts: Set<Int>`)
- Solo (`soloPart: Int?`)
- Velocity scaling by volume

---

## Playback Controls UI (P3-005)

**File**: `PlaybackFeature/Views/PlaybackControlsView.swift`

Floating transport bar matching the app's DAW aesthetic:
- `.regularMaterial` background, radius 24pt
- Stop / Back / Play-Pause / Forward buttons
- Tempo display with popover slider (40–240 BPM)
- Count-in, Metronome, Loop toggle buttons
- Measure number indicator (mono font)

---

## Loop Region (P3-006)

**File**: `PlaybackFeature/Views/PlaybackControlsView.swift` (LoopRegionView)

- Start/end measure steppers
- Toggle loop on/off
- Engine loops back to start measure when reaching end measure

---

## Mixer Panel (P3-007)

**File**: `PlaybackFeature/Views/MixerPanelView.swift`

DAW-style channel strip mixer:
- Per-part volume slider with percentage display
- Mute (M) button — amber when active
- Solo (S) button — accent when active
- Reset all button
- Dark chrome surface background

---

## Visual Playhead (P3-008)

**File**: `PlaybackFeature/Views/PlayheadOverlayView.swift`

Two overlay modes:
- **PlayheadOverlayView**: Cursor line + glow + swept region highlight
- **MeasureHighlightView**: Highlights active measure region

Uses `ASColors.cursorLine` (accent at 80%), `cursorGlow` (accent at 15%), `cursorActive` (accent at 40%).

---

## Rehearsal Marks Panel (P3-009)

**File**: `PlaybackFeature/Views/RehearsalMarksPanel.swift`

- Extracts marks from `MeasureMap.rehearsalEntries`
- Tap-to-navigate: calls `onNavigate(measureNumber)`
- Active mark highlighted with accent badge
- Shows measure number and formatted time
- Empty state for scores without rehearsal marks

---

## Transposition (P3-010)

**File**: `PlaybackFeature/Views/TransposeControlView.swift`

- ±12 semitone range
- Interval name display (Minor 2nd up, Perfect 5th down, etc.)
- Reset to concert pitch
- `PlaybackEventScheduler` applies transpose at event generation time

---

## File Map

| File | Purpose |
|------|---------|
| `NotationFeature/Models/NormalizedScore.swift` | In-memory score model |
| `NotationFeature/Parsers/MusicXMLParser.swift` | MusicXML/MXL parser |
| `NotationFeature/Parsers/MEIParser.swift` | MEI parser |
| `NotationFeature/Models/MeasureMap.swift` | Timing engine + event scheduler |
| `PlaybackFeature/Engine/PlaybackEngine.swift` | AVAudioEngine playback |
| `PlaybackFeature/Views/PlaybackControlsView.swift` | Transport + loop controls |
| `PlaybackFeature/Views/MixerPanelView.swift` | Per-part mixer |
| `PlaybackFeature/Views/PlayheadOverlayView.swift` | Visual cursor overlays |
| `PlaybackFeature/Views/RehearsalMarksPanel.swift` | Rehearsal mark navigation |
| `PlaybackFeature/Views/TransposeControlView.swift` | Transposition controls |
