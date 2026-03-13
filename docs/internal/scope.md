# Scope — ScoreStage

A premium Apple-native sheet music app for iOS, iPadOS, and macOS targeting serious musicians. Combines the best of forScore (library/annotation), MobileSheets (setlists/performance), and MuseScore (playback/notation intelligence).

## Tech Stack
- **UI:** SwiftUI-first, AppKit/UIKit bridges where needed
- **Persistence:** SwiftData
- **Sync:** CloudKit (offline-first)
- **Playback:** AVAudioEngine + Core MIDI + soundfont
- **Rendering:** Custom PDF tiled renderer + annotation overlay
- **Notation:** MusicXML/MEI parser to normalized internal model
- **Tracking:** Vision framework / ARKit for head/eye page turning
- **Linked Devices:** Multipeer Connectivity
- **Architecture:** Modular SPM packages per feature domain

## Phases & Task Summary

| Phase | Description | Tasks |
|-------|-------------|-------|
| **Phase 0** | Project Scaffolding | 6 tasks — Xcode project, SPM packages, data models, design system, navigation, sample data |
| **Phase 1** | Premium PDF Reader MVP | 19 tasks — Import, library UI, PDF rendering, reader modes, performance mode, basic annotations, setlists, bookmarks, CloudKit sync, pedal support, page turning, settings, polish, docs |
| **Phase 2** | Advanced Annotation + Device Sync | 9 tasks — Annotation layers, stamps, versioning, export, annotation sync, linked devices, two-device spread, mirrored mode, docs |
| **Phase 3** | Structured Notation Playback | 11 tasks — MusicXML/MEI parsing, measure map, audio engine, playback controls, looping, mixer, playhead cursor, rehearsal marks, transposition, docs |
| **Phase 4** | Motion / Head / Eye Page Turning | 5 tasks — Head tracking, eye gaze, calibration, safety controls, docs |
| **Phase 5** | Advanced Musical Intelligence | 6 tasks — Jump logic, score families, Handoff, MIDI practice, score-following, docs |
| **Phase 6** | Commercial Polish | 7 tasks — Onboarding, IAP/subscription, analytics, accessibility, backup/migration, App Store, docs |

**Total: 63 tasks across 7 phases**

## MVP Definition (Phase 0 + Phase 1)
- Beautiful PDF library and score reader
- Annotation system (pen, pencil, highlighter, shapes, text)
- Set lists with performance session flow
- Bookmarks and page navigation
- Bluetooth pedal page turning
- CloudKit sync for library metadata
- iPad + macOS support
- Premium commercial-grade UI

## Key Architectural Decisions
- **PDF as canonical display format** for page-faithful performance reading
- **MusicXML as primary structured notation format** for playback intelligence
- **Hybrid rendering strategy:** PDF for performance, structured notation for playback/navigation
- **Modular SPM packages** for clean separation of concerns
- **SwiftData** over Core Data for modern persistence
- **Offline-first sync** with CloudKit background reconciliation

## Target Users
Pianists, accompanists, singers, vocal coaches, choir directors, conductors, pit musicians, church musicians, music students, teachers, gigging musicians, musical theatre staff.

## Core Pillars
1. **Performance Reading** — Best live-performance score reader
2. **Musical Intelligence** — Notation-aware playback and navigation
3. **Annotation Excellence** — Immediate, accurate, layered markup
4. **Device Ecosystem** — Sync, linked devices, mirrored displays
5. **Premium UI/UX** — Luxurious, modern, unmistakably pro
