# Settings

The Settings screen provides app-wide preference management.

## Location: `ScoreStageApp/App/SettingsView.swift`

### Sections

#### Display Preferences
- **Display Mode**: Default reader view mode (single page, vertical scroll, horizontal paged, two-page spread)
- **Paper Theme**: Default paper background (white, cream, warm, dark)

#### Page Turning
- **Tap Zone Width**: Configurable tap zone width percentage (20-40%)
- **Half-Page Turn**: Toggle for half-page turn behavior

#### Sync & Storage
- **iCloud Sync**: Toggle for CloudKit synchronization
- **Storage Used**: Displays total library storage consumption

#### About
- App version display
- Build number

### Storage Calculation

Storage size is computed asynchronously by scanning the `ScoreStageScores` directory in Application Support. The calculation runs on a background thread (`nonisolated`) using `FileManager.contentsOfDirectory(at:)`.

### Data Persistence

Settings are stored using `@AppStorage` for simple key-value preferences backed by UserDefaults. Display mode and paper theme use string raw values for storage compatibility.
