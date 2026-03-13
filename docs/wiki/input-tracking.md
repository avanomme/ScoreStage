# Input Tracking & Page Turning

The InputTrackingFeature package handles keyboard shortcuts and page-turn input methods.

## Package: `InputTrackingFeature`

### Page Turn Service (`PageTurnService`)

Unified page-turn handler supporting multiple input sources:

| Direction | Description |
|---|---|
| `forward` | Advance to next page |
| `backward` | Go to previous page |

| Trigger | Description |
|---|---|
| `tap` | Screen tap gesture |
| `swipe` | Swipe gesture |
| `keyboard` | Physical keyboard input |
| `pedal` | Bluetooth HID pedal |
| `headMovement` | Head tracking (future) |
| `eyeGaze` | Eye tracking (future) |

Supports configurable callbacks: `onPageTurn`, `onTogglePerformanceMode`, `onToggleAnnotation`.

Handles keyboard key mapping:
- Right arrow, Space, Down arrow → Forward
- Left arrow, Up arrow → Backward
- `p` → Toggle performance mode
- `a` → Toggle annotation

### Keyboard Shortcuts (`ReaderKeyboardShortcuts`)

SwiftUI ViewModifier for reader keyboard handling:
- Right arrow → Next page
- Left arrow → Previous page
- Space → Next page
- Down arrow → Next page
- Up arrow → Previous page

Usage:
```swift
scoreView
    .readerKeyboardShortcuts(
        onNextPage: { viewModel.nextPage() },
        onPreviousPage: { viewModel.previousPage() }
    )
```

## Bluetooth Pedal Support

Bluetooth HID pedals are handled as standard keyboard input — they send arrow key or space key events that are captured by `ReaderKeyboardShortcuts`. No special pairing code is needed beyond standard system Bluetooth pairing.
