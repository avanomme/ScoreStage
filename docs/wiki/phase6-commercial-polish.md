# Phase 6: Commercial Polish

## Overview

Phase 6 adds onboarding, monetization (StoreKit 2), privacy-first analytics, VoiceOver accessibility, library backup/restore, and App Store optimization.

---

## Onboarding (P6-001)

### Architecture

**File**: `ScoreStageApp/App/OnboardingView.swift`

Five-screen premium onboarding flow shown on first launch:

| Screen | Icon | Title |
|--------|------|-------|
| 1 | `music.note.list` | Your Sheet Music, Elevated |
| 2 | `doc.richtext` | Import & Organize |
| 3 | `pencil.and.outline` | Annotate with Precision |
| 4 | `play.circle` | Playback & Practice |
| 5 | `hand.raised` | Hands-Free Turning |

### Integration

- `@AppStorage("hasCompletedOnboarding")` controls first-launch display
- iOS: presented as `.fullScreenCover`
- macOS: presented as `.sheet` with minimum 500x600 size
- Skip button available on all pages except the last
- "Get Started" button on final page completes onboarding

---

## StoreKit 2 Monetization (P6-002)

### Architecture

**Files**:
- `ScoreStageApp/App/StoreService.swift` — Purchase management
- `ScoreStageApp/App/PaywallView.swift` — Upgrade UI

### Product Configuration

| Product ID | Type | Description |
|-----------|------|-------------|
| `com.scorestage.pro.monthly` | Auto-renewable | Monthly Pro subscription |
| `com.scorestage.pro.yearly` | Auto-renewable | Yearly Pro subscription |
| `com.scorestage.pro.lifetime` | Non-consumable | One-time Pro unlock |

### ProFeature Gating

| Feature | Free | Pro |
|---------|------|-----|
| Score imports | 5 max | Unlimited |
| Basic annotations | Yes | Yes |
| Notation playback | No | Yes |
| Head/eye tracking | No | Yes |
| iCloud sync | No | Yes |
| Score following | No | Yes |
| Device linking | No | Yes |
| Export annotations | No | Yes |

### StoreService API

- `purchase(_ product:)` — Purchase a product
- `restorePurchases()` — Restore via `AppStore.sync()`
- `isPro` — Whether user has active Pro access
- `canAccess(feature:)` — Check feature gate
- Transaction listener auto-updates status on purchase/renewal/revocation

---

## Privacy Analytics (P6-003)

### Architecture

**File**: `ScoreStageApp/App/AnalyticsService.swift`

Minimal, on-device-only analytics:

- **No network calls** — all data stays in UserDefaults
- **No PII** — only feature usage counts
- **User-controllable** — toggle in Settings
- **Resettable** — clear all data with `resetAll()`

### Tracked Events

| Event | Description |
|-------|-------------|
| `scoreOpened` | Score opened in reader |
| `scoreImported` | New score imported |
| `annotationCreated` | Annotation stroke created |
| `playbackStarted` | Playback session started |
| `headTrackingUsed` | Head tracking activated |
| `eyeGazeUsed` | Eye gaze tracking used |
| `jumpLinkTapped` | Navigation link tapped |
| `performanceModeEntered` | Performance mode used |
| (+ 8 more) | See Event enum |

### Usage

```swift
analyticsService.track(.scoreOpened)
let report = analyticsService.usageReport() // [(name, count)]
```

---

## Accessibility (P6-004)

### Architecture

**File**: `DesignSystem/Accessibility/AccessibilityModifiers.swift`

Reusable SwiftUI modifiers for accessibility compliance:

| Modifier | Purpose |
|----------|---------|
| `.largeTapTarget()` | Ensures 44×44pt minimum touch target |
| `.highContrastBorder()` | Adds visible border when Increase Contrast is on |
| `.readerAccessibility(...)` | VoiceOver actions for score reader (next/previous page) |
| `.accessibleCard(_:hint:)` | Combines card children into single VoiceOver element |
| `.dynamicTypeIcon(baseSize:)` | Scales icon with Dynamic Type setting |

### VoiceOver Support

- Reader: custom accessibility actions for page navigation
- Cards: combined labels for score title + composer + metadata
- Buttons: 44pt minimum targets throughout
- High contrast: automatic border overlay when system setting enabled
- Reduce Motion: animation disabling when system setting enabled

---

## Backup & Restore (P6-005)

### Architecture

**File**: `LibraryFeature/Services/BackupRestoreService.swift`

### Backup Bundle Format

```
ScoreStage-Backup-2026-03-14.scorestagebackup/
├── metadata.json          # Score metadata, setlists, settings
└── ImportedScores/        # PDF files
```

### BackupMetadata Schema

```json
{
  "version": 1,
  "createdAt": "2026-03-14T...",
  "appVersion": "1.0.0",
  "scores": [{ "id", "title", "composer", "fileHash", ... }],
  "setlists": [{ "id", "name", "scoreIDs": [...] }]
}
```

### API

| Method | Description |
|--------|-------------|
| `exportBackup(to:)` | Export full library to .scorestagebackup bundle |
| `importBackup(from:)` | Import backup, skipping duplicates by fileHash |
| `state` | Observable export/import progress |

### Deduplication

Scores are matched by `fileHash` during import — existing scores are not overwritten.

---

## App Store (P6-006)

**File**: `docs/appstore/listing.md`

Complete App Store listing including:
- App name, subtitle, description
- Keywords (100 chars)
- Privacy nutrition labels (Data Not Collected)
- Screenshot requirements for iPhone, iPad, Mac
- In-app purchase descriptions and pricing
- Category: Music / Productivity

---

## File Map

| File | Purpose |
|------|---------|
| `ScoreStageApp/App/OnboardingView.swift` | First-launch onboarding flow |
| `ScoreStageApp/App/StoreService.swift` | StoreKit 2 purchase management |
| `ScoreStageApp/App/PaywallView.swift` | Pro upgrade paywall UI |
| `ScoreStageApp/App/AnalyticsService.swift` | On-device privacy analytics |
| `DesignSystem/Accessibility/AccessibilityModifiers.swift` | Accessibility view modifiers |
| `LibraryFeature/Services/BackupRestoreService.swift` | Library backup/restore |
| `docs/appstore/listing.md` | App Store listing content |
