# Architecture Overview

ScoreStage is a premium Apple-native sheet music app built with SwiftUI, SwiftData, and a modular SPM architecture.

## Project Structure

```
ScoreStage/
├── ScoreStageApp/           # App targets (iOS + macOS shared source)
│   ├── App/                 # Entry point, ContentView, SettingsView
│   ├── Info.plist
│   └── ScoreStage.entitlements
├── Packages/                # Modular SPM packages
│   ├── CoreDomain/          # SwiftData models & domain types
│   ├── DesignSystem/        # Color tokens, typography, components
│   ├── LibraryFeature/      # Score import, browsing, metadata
│   ├── ReaderFeature/       # PDF rendering, reader views
│   ├── AnnotationFeature/   # Drawing tools, canvas overlay
│   ├── SetlistFeature/      # Setlist management
│   ├── InputTrackingFeature/# Keyboard shortcuts, page turning
│   ├── SyncFeature/         # CloudKit sync (stub)
│   ├── PlaybackFeature/     # Notation playback (stub)
│   ├── NotationFeature/     # MusicXML/MEI parsing (stub)
│   └── DeviceLinkFeature/   # Multipeer connectivity (stub)
├── Tests/                   # Unit tests
├── Resources/SampleScores/  # Development test PDFs
├── project.yml              # XcodeGen project definition
└── project.md               # Product specification
```

## Key Technologies

| Technology | Purpose |
|---|---|
| **SwiftUI** | All UI, cross-platform (iOS 17+ / macOS 14+) |
| **SwiftData** | Persistence layer (14 model types) |
| **PDFKit + CGContext** | PDF loading and high-performance page rendering |
| **XcodeGen** | Xcode project generation from `project.yml` |
| **Swift 6.0** | Strict concurrency with `SWIFT_STRICT_CONCURRENCY: complete` |

## Platform Adaptations

- **iOS/iPadOS**: TabView navigation with Library, Setlists, Settings tabs
- **macOS**: NavigationSplitView sidebar layout
- **Cross-platform colors**: `#if canImport(UIKit)` / `#if canImport(AppKit)` conditionals in `ASColors`

## Build & Run

```bash
# Generate Xcode project
xcodegen generate

# Build iOS
xcodebuild build -project ScoreStage.xcodeproj -scheme ScoreStage-iOS -destination 'generic/platform=iOS Simulator'

# Build macOS
xcodebuild build -project ScoreStage.xcodeproj -scheme ScoreStage-macOS -destination 'generic/platform=macOS'

# Run tests
xcodebuild test -project ScoreStage.xcodeproj -scheme ScoreStageTests -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Signing

- **Team**: `FTBBTCJ34T` (Adam Vo)
- **Bundle ID**: `com.scorestage.app`
- **Code Sign Style**: Automatic
- **Note**: iCloud entitlements deferred (personal dev team limitation)
