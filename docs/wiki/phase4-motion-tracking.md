# Phase 4: Motion / Head / Eye Page Turning

## Overview

Phase 4 adds hands-free page turning via head movement tracking and eye gaze detection using Apple's Vision framework. All processing is on-device with no camera data transmitted externally. The system includes calibration UI, configurable sensitivity, safety controls, battery-aware operation, and accessibility-safe fallback handling.

---

## Head Movement Tracking (P4-001)

### Architecture

**File**: `InputTrackingFeature/HeadTrackingService.swift`

- `@MainActor` class with `ObservableObject` for SwiftUI binding
- Uses `AVCaptureSession` with front camera + `VNDetectFaceLandmarksRequest`
- Separate `FrameProcessor` delegate handles AVFoundation callbacks on background queue
- Face observation results dispatched to MainActor for gesture detection

### Head Pose Detection

| Property | Description |
|----------|-------------|
| `currentYaw` | Left/right rotation in radians (negative = left) |
| `currentPitch` | Up/down tilt in radians |
| `currentRoll` | Head tilt in radians |
| `confidence` | Vision detection confidence (0.0–1.0) |

### Gesture Detection

- Compares `currentYaw` against `baselineYaw` (set during calibration)
- When adjusted yaw exceeds `yawThreshold`, triggers a page turn
- Default threshold: 0.35 radians (~20°)
- Debounce prevents repeated triggers within `debounceInterval` (default 1.0s)
- Direction mapping configurable via `leftTurnsForward` toggle

### Tracking States

| State | Meaning |
|-------|---------|
| `idle` | Not started |
| `starting` | Camera session initializing |
| `tracking` | Actively detecting face |
| `noFaceDetected` | Camera running, no face in frame |
| `cameraUnavailable` | No front camera found |
| `permissionDenied` | User denied camera access |

---

## Eye Gaze Detection (P4-002)

### Architecture

**File**: `InputTrackingFeature/EyeGazeService.swift`

- Same camera pipeline architecture as head tracking
- Uses `VNFaceObservation.landmarks.leftPupil` / `rightPupil` for gaze direction
- Classifies gaze into left/center/right regions based on pupil position
- Dwell-time mechanism — sustained gaze triggers page turn

### Gaze Classification

Pupil x-position in normalized face coordinates:
- `< 0.35` → Right region
- `0.35–0.65` → Center region
- `> 0.65` → Left region

### Dwell Logic

1. Gaze enters left or right region → dwell timer starts
2. `dwellProgress` fills from 0.0 to 1.0 over `dwellDuration`
3. When progress reaches 1.0 → page turn fires
4. Gaze returning to center resets the timer
5. After a turn, `cooldownInterval` prevents immediate re-trigger

### Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| `dwellDuration` | 1.5s | 0.5–4.0s | Time gaze must hold to trigger |
| `cooldownInterval` | 2.0s | 0.5–5.0s | Minimum time between gaze turns |
| `confidenceThreshold` | 0.5 | 0.3–0.95 | Minimum detection confidence |
| `holdToConfirm` | false | — | Require sustained hold vs auto-fire |

---

## Calibration & Training Screen (P4-003)

### Architecture

**File**: `InputTrackingFeature/MotionTrackingCalibrationView.swift`

SwiftUI view with tabbed interface for head and eye gaze calibration.

### Sections

| Section | Purpose |
|---------|---------|
| Detection Status Card | Face detected indicator, confidence meter, current reading |
| Tracking Visualization | Head: 2D position dot in threshold ring. Eye: three-zone display with dwell progress |
| Sensitivity Controls | Sliders for threshold, debounce, confidence, dwell duration |
| Direction Mapping | Toggle left/right assignment for forward/backward |
| Training Mode | Practice turns without affecting score, counts detected turns |
| Privacy Notice | On-device processing disclosure |

### Head Position Visualization

- Circular display showing head position as a dot
- Dashed ring indicates yaw threshold boundary
- Crosshair at center for reference
- Real-time animation tracking head movement

### Eye Gaze Visualization

- Three-zone display (Left / Center / Right)
- Active zone highlighted with accent color
- Progress bar showing dwell fill status
- Time display showing elapsed vs required dwell

### Training Mode

- Enables gesture detection without triggering actual page turns
- Counts detected turns for practice feedback
- Visual arrow indicators for forward/backward

---

## Safety Controls & Manager (P4-004)

### Architecture

**File**: `InputTrackingFeature/MotionTrackingManager.swift`

Unified coordinator wrapping both tracking services with safety logic.

### Availability Checks

| Check | Action |
|-------|--------|
| No front camera | Sets `availability = .noCameraAvailable` |
| Permission denied | Sets `availability = .permissionDenied` |
| VoiceOver / Switch Control active | Sets `availability = .accessibilityOverride` |
| Permission not requested | Sets `availability = .permissionNotDetermined` |

### Battery-Aware Operation (iOS)

- Monitors `UIDevice.batteryState` and `batteryLevel`
- Sets `isBatteryConstrained = true` when unplugged and below 20%
- Consuming code can reduce frame rate or disable tracking when constrained

### Accessibility Fallback

- When `respectAccessibility = true` (default), tracking is suppressed if:
  - VoiceOver is running (iOS: `UIAccessibility.isVoiceOverRunning`, macOS: `NSWorkspace.shared.isVoiceOverEnabled`)
  - Switch Control is active (iOS only)
- Users can override with `respectAccessibility = false`

### Configuration Presets

| Preset | Yaw Threshold | Debounce | Dwell | Purpose |
|--------|--------------|----------|-------|---------|
| Conservative | 29° | 1.5s | 2.5s | Maximum safety, first-time users |
| Default | 20° | 1.0s | 1.5s | Balanced for most users |
| Responsive | 14° | 0.5s | 0.8s | Experienced users, fast response |

### Integration with PageTurnService

```swift
let manager = MotionTrackingManager()
manager.connect(to: pageTurnService)
manager.headTrackingEnabled = true
await manager.startTracking()
```

The manager routes detected gestures through `PageTurnService.triggerTurn(_:from:)` with appropriate `.headMovement` or `.eyeGaze` triggers.

---

## Privacy

- All Vision framework processing runs on-device
- No camera frames are stored, transmitted, or logged
- Camera session is released when tracking stops
- Privacy notice displayed in calibration UI
- Camera usage description required in Info.plist:
  - `NSCameraUsageDescription`: "ScoreStage uses the camera for hands-free page turning via head movement and eye gaze detection. All processing happens on your device."

---

## File Map

| File | Purpose |
|------|---------|
| `InputTrackingFeature/HeadTrackingService.swift` | Vision-based head pose tracking |
| `InputTrackingFeature/EyeGazeService.swift` | Pupil-based gaze detection with dwell |
| `InputTrackingFeature/MotionTrackingCalibrationView.swift` | Calibration and training UI |
| `InputTrackingFeature/MotionTrackingManager.swift` | Unified manager with safety controls |
| `InputTrackingFeature/PageTurnService.swift` | Core page turn service (extended with `.headMovement`, `.eyeGaze` triggers) |

---

## TurnTrigger Extensions

Phase 4 added two new cases to `PageTurnService.TurnTrigger`:

| Trigger | Source |
|---------|--------|
| `.headMovement` | Head yaw exceeds threshold |
| `.eyeGaze` | Gaze dwells on left/right region |
