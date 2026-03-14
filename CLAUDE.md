# ScoreStage — Development Guidelines

## UI Environment Architecture (MANDATORY)

The app uses **4 strictly separated UI environments**. Each has its own layout, gestures, styling, controls, and animations. They must **never share the same UI layer**.

### 1. Library Environment
- Media library browser (Apple Music / Lightroom / FCP browser style)
- Layout: Sidebar + Score Grid (large cover thumbnails) + Inspector Panel
- Score cards look like album art / score covers, NOT file system items or list rows
- Must NEVER resemble a document editor

### 2. Reader Environment (Performance Mode)
- Sacred full-screen display — **no persistent toolbars, no side panels, no chrome**
- **Score ALWAYS uses light-mode paper** (white/cream/sepia) even if app uses dark UI elsewhere
- Controls appear as floating translucent overlay on tap/mouse move, auto-fade after 3s
- Performance Lock Mode: disables all input except page turn zones

### 3. Annotation Environment
- Separate layer over Reader, NOT mixed into Reader chrome
- Floating Procreate-style palette — NOT a document editor ribbon
- Supports layers (performer / teacher / rehearsal / personal)
- Entering annotation mode reveals toolbar + enables drawing input

### 4. Playback Environment
- Slide-up panel from bottom (DAW transport style)
- Never covers score unnecessarily
- Playback cursor uses accent color

## Design Rules
- **Animations**: 150–250ms, ease-in-out. No bouncing, no slow page curls
- **Icons**: Thin line, monochrome, simple geometry. No colorful icons or emoji
- **Typography**: SF Pro, editorial spacing, not dense
- **The app must feel like**: Logic Pro, Final Cut Pro, Dorico, Ableton Live
- **The app must NEVER feel like**: Notes, Notion, Todo apps, document editors

## Technical
- **Project generation**: `xcodegen generate` (project.yml is source of truth)
- **Build**: `make mac` / `make iphone` / `make ipad`
- **Tests**: `make test`
- **Swift 6.0** with strict concurrency
- **SwiftData** for persistence (14 model types in CoreDomain)
- **App name**: ScoreStage (never AureliaScore)
- **Bundle ID**: com.scorestage.app
- **Team**: FTBBTCJ34T
