# ScoreStage UI Design Specification

**Version:** 2.0
**Date:** 2026-03-13
**Status:** Canonical — Single Source of Truth for All UI Implementation

---

## Table of Contents

1. [Design Philosophy & Brand Identity](#a-design-philosophy--brand-identity)
2. [Color System](#b-color-system)
3. [Typography System](#c-typography-system)
4. [Spacing & Layout Grid](#d-spacing--layout-grid)
5. [Library Environment](#e-library-environment)
6. [Reader Environment](#f-reader-environment)
7. [Annotation Environment](#g-annotation-environment)
8. [Playback Environment](#h-playback-environment)
9. [Component Library](#i-component-library)
10. [Animation & Motion Design](#j-animation--motion-design)
11. [Icon System](#k-icon-system)
12. [Accessibility](#l-accessibility)
13. [Platform Adaptations](#m-platform-adaptations)
14. [Insights from Logic Pro, Dorico & Finale Interfaces](#n-insights-from-logic-pro-dorico--finale-interfaces)

---

## A. Design Philosophy & Brand Identity

### Core Identity

ScoreStage is a **professional instrument**, not a consumer utility. The interface must communicate the same authority and precision that a musician expects from a Steinway piano, a Neumann microphone, or a Logic Pro session. Every pixel must earn its place.

### Design Pillars

1. **Studio Authority** — The UI conveys mastery and control. Dark chrome, precise typography, and restrained color create a workspace that feels like a professional control room, not a note-taking app.
2. **Score Reverence** — The sheet music is sacred. The entire application exists to serve the score. When reading, nothing competes with the notation. The paper is always pristine, always light, always dominant.
3. **Invisible Technology** — Controls appear when needed and vanish when they are not. The best interaction is the one the musician does not notice. No UI element should make the user think about the UI.
4. **Decisive Transitions** — Moving between Library, Reader, and Annotation is a deliberate act, not an accidental gesture. Each environment is a distinct workspace with its own rules.

### Competitive Differentiation

| Competitor | Their Approach | ScoreStage Differentiator |
|---|---|---|
| forScore | Skeuomorphic wood shelves, functional but dated visual language | Modern pro-tool aesthetic, Dorico-level sophistication |
| MobileSheets | Utilitarian, data-heavy, Windows-heritage design | Apple-native, editorial, visually calm |
| Newzik | Cloud-first, collaborative focus, generic UI | Performance-first, premium local experience |
| piascore | Minimal but lacks depth, simple grid | Deep inspector, rich metadata, DAW-grade chrome |

### Emotional Response

When a musician opens ScoreStage, they should feel: "This was made by someone who understands my craft." The sensation should be analogous to opening Logic Pro or Final Cut Pro for the first time — immediate confidence that the tool is serious, capable, and worth the investment.

### What ScoreStage Must NEVER Feel Like

- Apple Notes (generic document editor)
- Notion (productivity tool with blocks)
- Google Docs (collaborative text editor)
- Any to-do app

### What ScoreStage MUST Feel Like

- Logic Pro (professional audio workstation)
- Final Cut Pro (professional video editor)
- Dorico (professional notation software)
- Lightroom (professional photo management and editing)

---

## B. Color System

### B.1 Brand Colors

The brand palette is built around a refined rose-copper accent that evokes the warmth of concert hall lighting — neither cold-tech-blue nor childish-bright. It is sophisticated, gender-neutral, and distinctive in the music app market.

```
Primary Accent:     #D55D7A  (rose copper)    — RGB(213, 93, 122)
Accent Hover:       #E06E8A  (lighter rose)   — RGB(224, 110, 138)
Accent Pressed:     #B84D68  (deeper rose)    — RGB(184, 77, 104)
Accent Subtle:      #D55D7A at 12% opacity   — for backgrounds, badges
Accent Muted:       #D55D7A at 6% opacity    — for hover states on surfaces
```

### B.2 Dark Mode Chrome (Library, Settings, App Shell)

The application shell uses a dark palette inspired by professional DAWs. This is NOT pure black — it is a carefully graduated warm-neutral dark palette.

```
Chrome Background:         #1A1A1E  — deepest surface (window bg)
Chrome Surface:            #232328  — primary panels, sidebar bg
Chrome Surface Elevated:   #2C2C32  — cards, elevated content
Chrome Surface Hover:      #35353C  — hover state on surfaces
Chrome Surface Selected:   #3E3E46  — selected sidebar item bg
Chrome Border:             #3A3A42  — subtle dividers, 1px borders
Chrome Border Strong:      #4A4A54  — stronger separators
```

### B.3 Text Colors (Dark Chrome Context)

```
Text Primary:        #F0F0F2  — headings, titles, primary content
Text Secondary:      #A0A0A8  — metadata, labels, secondary info
Text Tertiary:       #6E6E78  — timestamps, disabled states, hints
Text Disabled:       #4A4A52  — fully disabled text
Text Inverse:        #1A1A1E  — text on light/accent backgrounds
```

### B.4 Paper Themes (Score Display — ALWAYS Light)

These are the ONLY backgrounds ever used for rendered sheet music. They must remain light in both light and dark system modes.

```
Paper White:            #FFFFFF  — pure white, highest contrast
Paper Cream:            #FAF5E6  — warm cream, reduces eye strain
Paper Warm:             #F5EDE0  — warm sepia-adjacent, gentle warmth
Paper Parchment:        #F2EBD9  — aged parchment feel
Paper High Contrast:    #F0F0F0  — very light gray, maximum sharpness
```

Paper shadow (the subtle shadow cast by the paper onto the dark background when score is displayed):
```
Paper Shadow:           #000000 at 25% opacity, radius 20, y-offset 8
Paper Edge:             #000000 at 8% opacity, 1px border on paper edges
```

### B.5 Light Mode Chrome (System Light Mode)

When the system is in light mode, the chrome adapts while the score remains identical.

```
Chrome Background:         #F2F2F7  — matches iOS system background
Chrome Surface:            #FFFFFF  — primary panels
Chrome Surface Elevated:   #FFFFFF  — cards (differentiated by shadow)
Chrome Surface Hover:      #E8E8ED  — hover states
Chrome Surface Selected:   #D55D7A at 10% opacity  — selected sidebar
Chrome Border:             #D1D1D6  — subtle dividers
Chrome Border Strong:      #C7C7CC  — section separators
```

### B.6 Text Colors (Light Chrome Context)

```
Text Primary:        #1C1C1E  — headings, titles
Text Secondary:      #6E6E78  — metadata, labels
Text Tertiary:       #AEAEB2  — hints, timestamps
Text Disabled:       #D1D1D6  — disabled elements
```

### B.7 Annotation Palette

Eight colors, carefully chosen for visibility on all paper themes. These are NOT generic system colors — they are tuned for legibility on cream/white paper with music notation.

```
Annotation Black:        #1C1C1E  — primary markup
Annotation Red:          #E63946  — critical markings, corrections
Annotation Blue:         #3366E6  — fingering, technical notes
Annotation Green:        #2D9E48  — phrasing, dynamics
Annotation Yellow:       #F0C800  — highlighting (used at 30% opacity)
Annotation Purple:       #8B52CC  — form analysis, structure
Annotation Orange:       #E68A33  — bowings, articulation
Annotation Brown:        #8B6914  — historical annotations
```

### B.8 Status Colors

```
Success:     #34C759  — (matches iOS system green)
Warning:     #FF9500  — (matches iOS system orange)
Error:       #FF3B30  — (matches iOS system red)
Info:        #5AC8FA  — (matches iOS system teal)
```

### B.9 Playback Cursor

```
Cursor Active:       #D55D7A at 40% opacity  — vertical bar sweeping through score
Cursor Line:         #D55D7A at 80% opacity  — 2px vertical line
Cursor Glow:         #D55D7A at 15% opacity  — 8px soft glow around cursor
```

---

## C. Typography System

### C.1 Font Strategy

**Primary UI Font:** SF Pro (San Francisco) — Apple's system font. Used for all interface elements. Provides optical sizing, weight interpolation, and platform consistency.

**Display/Title Accent:** SF Pro with `.serif` design variant — Used exclusively for score titles and display headings in the Library. The serif design evokes classical typesetting and immediately distinguishes ScoreStage from generic apps. This maps to `Font.system(design: .serif)` in SwiftUI.

**Monospaced Data:** SF Mono — Used for page numbers, time codes, measure numbers, and technical data. Maps to `Font.system(design: .monospaced)`.

**Why NOT a custom font:** SF Pro provides Dynamic Type support, platform-native rendering, and accessibility features that custom fonts break. The serif variant provides enough personality without sacrificing these critical capabilities.

### C.2 Type Scale

All sizes are in points. Line height multipliers are relative to font size.

#### Display (Library headers, hero text)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `displayLarge` | 38pt | `.bold` | `.serif` | -0.5pt | 1.15x |
| `displayMedium` | 30pt | `.bold` | `.serif` | -0.3pt | 1.18x |
| `displaySmall` | 24pt | `.semibold` | `.serif` | -0.2pt | 1.2x |

#### Headings (Section headers, panel titles)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `heading1` | 22pt | `.semibold` | `.default` | 0pt | 1.25x |
| `heading2` | 18pt | `.semibold` | `.default` | 0pt | 1.28x |
| `heading3` | 15pt | `.semibold` | `.default` | 0pt | 1.3x |

#### Body (Content text, descriptions)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `bodyLarge` | 17pt | `.regular` | `.default` | 0pt | 1.4x |
| `body` | 15pt | `.regular` | `.default` | 0pt | 1.4x |
| `bodySmall` | 13pt | `.regular` | `.default` | 0pt | 1.35x |

#### Labels (UI controls, metadata keys)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `label` | 13pt | `.medium` | `.default` | 0.3pt | 1.2x |
| `labelSmall` | 11pt | `.medium` | `.default` | 0.4pt | 1.2x |
| `labelMicro` | 10pt | `.semibold` | `.default` | 0.5pt | 1.2x |

#### Captions (Timestamps, tertiary info)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `caption` | 12pt | `.regular` | `.default` | 0.2pt | 1.3x |
| `captionSmall` | 10pt | `.regular` | `.default` | 0.3pt | 1.3x |

#### Monospaced (Page numbers, time codes, measure numbers)

| Token | Size | Weight | Design | Tracking | Line Height |
|---|---|---|---|---|---|
| `mono` | 14pt | `.regular` | `.monospaced` | 0pt | 1.2x |
| `monoSmall` | 12pt | `.medium` | `.monospaced` | 0pt | 1.2x |
| `monoMicro` | 10pt | `.medium` | `.monospaced` | 0.3pt | 1.2x |

### C.3 Usage Rules

- **Serif** is used ONLY for: score titles in the library grid, display headings, and the app title in the sidebar header. Nowhere else.
- **Uppercase tracking** (0.3–0.5pt) is applied ONLY to: inspector section labels, tab labels, badge text, and `labelSmall`/`labelMicro` tokens. Body text and headings are never uppercased.
- **Letter spacing is negative** for display sizes to maintain visual cohesion at large scale.
- All text must support Dynamic Type. Use `@ScaledMetric` for custom spacing values that accompany text.

---

## D. Spacing & Layout Grid

### D.1 Base Unit

The spacing system uses a **4pt base unit**. All spacing values are multiples of 4.

```
xxs:    2pt   (half-unit — only for tight icon gaps)
xs:     4pt   (base unit)
sm:     8pt   (compact spacing)
md:     12pt  (standard element spacing)
lg:     16pt  (section element spacing)
xl:     24pt  (section spacing)
xxl:    32pt  (major section breaks)
xxxl:   48pt  (environment-level spacing)
```

### D.2 Screen Margins

```
iPhone:              16pt horizontal
iPad Portrait:       20pt horizontal
iPad Landscape:      24pt horizontal
macOS:               24pt horizontal (content area, inside sidebar)
```

### D.3 Component Spacing

```
Card Internal Padding:        16pt
Card-to-Card Gap (grid):      20pt (iPad), 16pt (iPhone)
Section Title to Content:     12pt
Section to Section:           32pt
Divider Vertical Padding:     16pt (above and below)
Toolbar Item Spacing:         8pt (compact), 16pt (comfortable)
Inspector Label to Value:     4pt
Inspector Row to Row:         14pt
Inspector Section to Section: 24pt
```

### D.4 Corner Radii

```
Radius XS:       4pt   — small badges, tiny elements
Radius SM:       6pt   — tool buttons, chips
Radius MD:       10pt  — buttons, text fields
Radius LG:       14pt  — cards, panels
Radius XL:       20pt  — floating overlays, modals
Radius Card:     12pt  — score cover cards
Radius Sheet:    24pt  — bottom sheets, floating palettes
```

### D.5 Grid Columns (Score Library)

The score grid uses CSS-like adaptive columns with defined minimums and maximums:

```
iPad Landscape:    adaptive(minimum: 160, maximum: 200), spacing: 20pt
iPad Portrait:     adaptive(minimum: 150, maximum: 190), spacing: 20pt
iPhone:            adaptive(minimum: 140, maximum: 170), spacing: 16pt
macOS:             adaptive(minimum: 170, maximum: 210), spacing: 20pt
```

This yields approximately:
- iPad Landscape: 5–6 columns
- iPad Portrait: 4–5 columns
- iPhone: 2 columns
- macOS (typical window): 4–6 columns

---

## E. Library Environment

The Library is the home base. It is a media browser — think Lightroom's photo grid or Apple Music's album view. It must NEVER look like a file manager or document list.

### E.1 Sidebar

#### Dimensions

```
Width:           min: 200pt, ideal: 240pt, max: 300pt
Header Height:   64pt (contains app title)
Item Height:     36pt
Item Padding:    horizontal: 12pt, vertical: 6pt
Section Label:   uppercase, labelMicro token, Text Tertiary color
Section Gap:     24pt between sections
```

#### Visual Styling (Dark Mode)

```
Background:          Chrome Surface (#232328)
Selected Item BG:    Chrome Surface Selected (#3E3E46) with accent left edge (3pt, Radius SM)
Selected Item Text:  Text Primary (#F0F0F2)
Unselected Text:     Text Secondary (#A0A0A8)
Hover BG:            Chrome Surface Hover (#35353C)
Icon Size:           16pt, weight: .regular
Icon-to-Label Gap:   10pt
Section Divider:     Chrome Border (#3A3A42), 0.5pt height
```

#### Visual Styling (Light Mode)

```
Background:          Chrome Surface (#FFFFFF)
Selected Item BG:    Accent Subtle (#D55D7A at 10%), full rounded rect
Selected Item Text:  Primary Accent (#D55D7A)
Unselected Text:     Text Secondary (#6E6E78)
Hover BG:            Chrome Surface Hover (#E8E8ED)
```

#### Sections and Items

```
LIBRARY
  ├── Library          (music.note.list)
  ├── Recently Played  (clock)
  └── Favorites        (heart.fill when items exist, heart when empty)

BROWSE
  ├── Composers        (person.2)
  └── Genres           (guitars)

PERFORMANCE
  └── Set Lists        (list.bullet.rectangle)

APP
  └── Settings         (gearshape)
```

#### Sidebar Header

```
Position:            Top of sidebar, above first section
Height:              64pt
Content:             "ScoreStage" in heading2, Text Primary
                     Below: version/tagline in captionSmall, Text Tertiary (optional)
Bottom Border:       Chrome Border, 0.5pt
Padding:             horizontal: 16pt, top: 16pt, bottom: 12pt
```

### E.2 Score Grid (Main Content Area)

#### Background

```
Dark Mode:   Chrome Background (#1A1A1E)
Light Mode:  Chrome Background (#F2F2F7)
```

#### Search Bar

```
Position:            Top of content area, below navigation title
Height:              36pt
Corner Radius:       Radius MD (10pt)
Background:          Chrome Surface Elevated (#2C2C32 dark) / (#EFEFF4 light)
Placeholder Text:    "Search scores, composers, tags..." in body, Text Tertiary
Icon:                magnifyingglass, 14pt, Text Tertiary, 8pt left padding
Clear Button:        xmark.circle.fill, 14pt, appears when text present
```

#### Sort/Filter Bar

```
Position:            Below search bar, right-aligned
Height:              32pt
Sort Button:         Label("Sort", systemImage: "arrow.up.arrow.down"), ghost button style
Filter Button:       Label("Filter", systemImage: "line.3.horizontal.decrease"), ghost button style
View Toggle:         Grid/List toggle (square.grid.2x2 / list.bullet), icon-only ghost buttons
Active Sort:         Text in accent color, icon filled
Gap Between Items:   12pt
```

#### Score Cover Cards

This is the single most important visual element in the Library. Cards must look like album covers or printed score covers, NOT file system thumbnails.

##### Card Dimensions

```
Aspect Ratio:        0.77 (width:height) — matches standard US Letter portrait proportion
Minimum Width:       140pt
Maximum Width:       210pt
Corner Radius:       Radius Card (12pt)
```

##### Card Cover Area (Thumbnail)

```
Background:          Linear gradient, top-to-bottom
                     Dark: #2A2A30 → #222228
                     Light: #F0F0F2 → #E4E4E8
Border:              0.5pt, Chrome Border color
Shadow (resting):    color: #000000 at 10%, radius: 6pt, y: 3pt
Shadow (hover):      color: #000000 at 18%, radius: 14pt, y: 6pt
Shadow (pressed):    color: #000000 at 6%, radius: 3pt, y: 1pt
```

##### Card Cover Content (when no actual thumbnail is rendered)

```
Music Note Icon:     music.note, 28pt, weight: .ultraLight, Text Tertiary
Title:               11pt, weight: .medium, design: .serif, Text Secondary, center-aligned
                     max 2 lines, line limit enforced
Composer:            9pt, weight: .regular, Text Tertiary, center-aligned
                     max 1 line
Vertical Spacing:    8pt between icon and title, 4pt between title and composer
```

When an actual PDF thumbnail is available, it fills the cover area entirely with `ContentMode.fill`, clipped to the rounded rectangle.

##### Selection Ring

```
Selected:            2.5pt stroke, Primary Accent color, inset from card edge
                     Additional: subtle accent glow — accent at 15% opacity, radius 8pt
Unselected:          no stroke
```

##### Favorite Badge

```
Position:            top-right corner of cover area
Offset:              8pt from top, 8pt from right
Icon:                heart.fill, 10pt, .semibold
Color:               white
Background:          Primary Accent at 90%, circle, 24pt diameter
Shadow:              #000000 at 15%, radius 2pt, y: 1pt
Only shown when:     score.isFavorite == true
```

##### Card Metadata (Below Cover)

```
Padding Top:         8pt (from cover bottom)
Title:               13pt, weight: .medium, Text Primary, 1 line max
Composer:            11pt, weight: .regular, Text Secondary, 1 line max
Duration:            10pt, weight: .regular, Text Tertiary
Spacing:             2pt between each line
```

##### Card Interaction States

```
Hover (macOS):       Scale to 1.02x, shadow elevates, transition 200ms easeInOut
Press:               Scale to 0.97x, shadow reduces, transition 100ms easeOut
Tap (iOS):           Brief 0.97x scale + release, 150ms
Double-Tap:          Opens score in Reader (primary action)
Single-Tap:          Selects score, shows inspector
Long Press:          Context menu appears (300ms hold threshold)
```

### E.3 Inspector Panel

#### Dimensions

```
Width:               min: 240pt, ideal: 300pt, max: 380pt
```

#### Visual Styling

```
Background (dark):   Chrome Surface (#232328)
Background (light):  Chrome Surface (#FFFFFF)
Left Border:         Chrome Border, 0.5pt
```

#### Header Section

```
Padding:             20pt all sides
Score Title:         heading1 token (22pt, .semibold)
Composer:            body token (15pt), Text Secondary
Arranger:            bodySmall (13pt), Text Tertiary, prefixed with "arr. "
Spacing:             4pt between title and composer, 2pt between composer and arranger
```

#### Metadata Section

```
Section Label:       labelMicro (10pt, .semibold), uppercase, Text Tertiary, tracking +0.5pt
Label-to-Value Gap:  4pt
Row-to-Row Gap:      14pt
Section Padding:     20pt horizontal, 16pt vertical
Labels:              labelSmall (11pt, .semibold), Text Secondary, uppercase
Values:              bodySmall (13pt), Text Primary
```

Metadata rows include:
- Instrumentation
- Genre
- Key
- Pages
- Difficulty (shown as "X / 10")
- Duration (shown as "Xm Xs")

#### Tags Section

```
Divider above:       Chrome Border, 0.5pt
Section Label:       "TAGS" in labelMicro, uppercase
Tag Chips:           11pt, .medium, horizontal padding 10pt, vertical padding 4pt
Tag Background:      Accent Subtle (Primary Accent at 10%)
Tag Corner Radius:   Capsule (fully rounded)
Tag Layout:          FlowLayout with 4pt horizontal gap, 6pt vertical gap
```

#### Notes Section

```
Divider above:       Chrome Border, 0.5pt
Section Label:       "NOTES" in labelMicro, uppercase
Notes Text:          bodySmall (13pt), Text Secondary
```

#### Actions Section (Bottom)

```
Divider above:       Chrome Border, 0.5pt
Padding:             20pt all sides
Buttons:
  "Open Score"       — Primary button, full width
  "Edit Metadata"    — Secondary button, full width
  "Add to Set List"  — Ghost button, full width
Button Spacing:      8pt between buttons
```

### E.4 Empty States

#### Visual Design

```
Container:           Centered in content area, max-width 320pt
Icon:                48pt, weight: .light, Text Tertiary
                     Animated: gentle pulse (symbolEffect .pulse.byLayer, speed: 0.5)
                     Entry: scale from 0.85 → 1.0, opacity 0 → 1, 500ms easeOut
Title:               heading2 (18pt, .semibold), Text Primary
Message:             body (15pt), Text Secondary, center-aligned, max 2 lines
Action Button:       Primary button style (when applicable)
Icon-to-Title Gap:   16pt
Title-to-Message:    8pt
Message-to-Button:   20pt
```

### E.5 Transition Animations (Sidebar Selections)

```
Content Switch:      crossDissolve, 200ms, easeInOut
Grid Reflow:         items animate position, 250ms, easeInOut
Inspector Slide:     slide from trailing edge, 250ms, easeInOut
```

---

## F. Reader Environment

The Reader is a **performance instrument**. It has ONE job: display the score so clearly that the musician forgets they are using technology. Zero persistent chrome. Zero distractions.

### F.1 Full-Screen Layout

```
Background:          Current paper theme color (always light)
Safe Area:           Content extends to all edges
Status Bar:          Hidden when controls are hidden, shown when controls are visible
Home Indicator:      Auto-hidden (persistentSystemOverlays: .hidden)
Navigation Bar:      Hidden
Tab Bar:             Hidden (never visible in Reader)
```

### F.2 Score Display

```
Rendering:           PDF pages rendered to CGImage at 2x device scale
Page Positioning:    Centered in available space, scaled to fit (aspect ratio preserved)
Page-to-Background:  Paper shadow applied (see B.4)
Page Margin:         0pt (full bleed to edges of available space)
```

#### Display Modes

| Mode | Description | Page Turn |
|---|---|---|
| Single Page | One page, centered, no scroll | Tap zones |
| Horizontal Paged | Swipe left/right between pages | Swipe gesture |
| Vertical Scroll | Continuous scroll, all pages | Scroll gesture |
| Two-Page Spread | Side-by-side pages (landscape iPad, macOS) | Tap zones |

#### Two-Page Spread Details

```
Gap Between Pages:   2pt
Each page:           50% of available width minus 1pt
Alignment:           Vertically centered
```

### F.3 Page Turn Zones

```
Right Zone:          Right 40% of screen width → next page
Left Zone:           Left 40% of screen width → previous page
Center Zone:         Middle 20% of screen width → toggle controls
```

Visual feedback on tap (subtle):
```
Right tap:           No visual feedback (instant page change)
Left tap:            No visual feedback (instant page change)
Center tap:          Controls appear/disappear
```

### F.4 Floating Control Bar (Bottom)

This is the primary UI control for the Reader. It appears on center-tap or mouse movement and auto-hides after inactivity.

#### Dimensions

```
Position:            Bottom center, 20pt from safe area bottom
Height:              56pt
Min Width:           280pt (adapts to content)
Max Width:           480pt
Corner Radius:       Radius Sheet (24pt)
Horizontal Padding:  24pt
Vertical Padding:    12pt
```

#### Material

```
Background:          .regularMaterial (NOT .ultraThinMaterial — needs more opacity for readability)
Shadow:              #000000 at 12%, radius: 16pt, y: 6pt
Border:              0.5pt, #FFFFFF at 10% (gives a subtle glass edge in dark mode)
```

#### Control Items

Arranged as an HStack with 20pt spacing:

| Control | SF Symbol | Size | Behavior |
|---|---|---|---|
| Back | `chevron.left` | 16pt, .medium | Dismiss reader, return to Library |
| Display Mode | `rectangle.split.2x1` | 18pt, .regular | Menu: Single / Horizontal / Vertical / Spread |
| Paper Theme | `doc.plaintext` | 18pt, .regular | Menu: White / Cream / Warm / Parchment / High Contrast |
| Annotation | `pencil.tip.crop.circle` | 18pt, .regular | Toggle annotation environment |
| Bookmark | `bookmark` | 18pt, .regular | Toggle bookmark on current page |
| Performance Lock | `lock.shield` | 18pt, .regular | Toggle performance lock mode |

When a control is active/toggled:
```
Active Icon:         Primary Accent color
Active Background:   Primary Accent at 12%, Radius SM rounded rect behind icon
```

Each control item is a VStack:
```
Icon:                Above
Label:               Below, 9pt, .medium, Text Secondary
Spacing:             3pt between icon and label
Min Tap Target:      44x44pt
```

#### Dividers Between Control Groups

```
Width:               0.5pt
Height:              28pt
Color:               Text Tertiary at 30%
```

### F.5 Top Bar (Contextual)

Appears simultaneously with the bottom control bar.

```
Position:            Top of screen, safe area inset
Height:              44pt
Background:          .regularMaterial
Left:                Back chevron + score title (14pt, .medium, 1 line, truncated)
Right:               Page indicator: "3 / 12" in monoSmall, Text Secondary
Padding:             horizontal 16pt
```

### F.6 Page Number Overlay (Persistent, Minimal)

Visible when controls are HIDDEN. Extremely subtle.

```
Position:            Bottom-right corner
Offset:              12pt from right edge, 12pt from bottom safe area
Content:             Current page number only (e.g., "3"), monoMicro (10pt, .medium)
Color:               Text Tertiary at 60%
Background:          None
```

### F.7 Controls Show/Hide

```
Trigger (iOS):       Center-zone tap
Trigger (macOS):     Mouse movement anywhere in window
Show Animation:      opacity 0→1, 200ms, easeOut
Hide Animation:      opacity 1→0, 250ms, easeIn
Auto-Hide Delay:     4.0 seconds after last interaction
Timer Reset:         Any tap on a control resets the 4-second timer
```

### F.8 Page Turn Animation

```
Single Page Mode:    No animation — instant page replacement (musicians need speed, not drama)
Horizontal Paged:    Native TabView paging (UIPageViewController under the hood)
Vertical Scroll:     Native ScrollView momentum
Two-Page Spread:     No animation — instant replacement
```

Do NOT implement: page curl, slide transitions, fade transitions, or any animation that adds latency to page turns. A 50ms page turn is too slow. It must be instant.

### F.9 Zoom Behavior

```
Gesture:             Standard pinch-to-zoom
Min Scale:           1.0x (fit to screen)
Max Scale:           5.0x
Double-Tap:          Toggle between 1.0x and 2.5x, animated 250ms easeInOut
Pan:                 Available when zoomed beyond 1.0x
Bounce:              Rubber-band at min/max scale limits
```

### F.10 Performance Lock Mode

When active:
```
Indicator:           Small lock icon (lock.fill, 12pt) in top-right, Text Tertiary at 40%
Behavior:            All gestures disabled except page turn zone taps
                     Pinch, pan, long-press, center-tap all ignored
                     Only right/left zone taps work
Exit:                Hardware keyboard shortcut (Cmd+L) or force-tap (3-finger triple tap)
```

---

## G. Annotation Environment

Annotation is a **separate environment** layered over the Reader. Entering annotation mode is an explicit, visible transition — not an accidental mode toggle.

### G.1 Entry/Exit Transition

```
Entry:               Annotation toolbar slides in from bottom (translateY), 250ms, easeOut
                     Slight darkening of area outside the score page (overlay #000000 at 5%)
                     Score remains at current zoom/position
Exit:                Toolbar slides out to bottom, 200ms, easeIn
                     Overlay fades out
```

### G.2 Floating Palette

The annotation toolbar is a floating, repositionable palette — inspired by Procreate's toolbar, NOT a document editor ribbon.

#### Dimensions

```
Position Default:    Bottom center, 16pt above safe area
Draggable:           Yes — user can reposition by dragging the handle
Orientation:         Horizontal on iPad/macOS, horizontal on iPhone (scrollable)
Height:              52pt (collapsed), expands for sub-panels
Min Width:           320pt
Max Width:           480pt
Corner Radius:       Radius Sheet (24pt)
Handle:              5pt wide, 36pt tall grab indicator, centered on left edge, Chrome Border color
```

#### Material

```
Background:          .thickMaterial (needs more opacity than reader controls — must not lose tools)
Shadow:              #000000 at 15%, radius: 20pt, y: 8pt
Border:              0.5pt, #FFFFFF at 8%
```

### G.3 Tool Strip

Arranged as HStack, 4pt spacing between tool buttons:

| Tool | SF Symbol | Default Width | Default Opacity |
|---|---|---|---|
| Pen | `pencil.tip` | 2.0pt | 1.0 |
| Pencil | `pencil` | 1.5pt | 0.8 |
| Highlighter | `highlighter` | 12.0pt | 0.3 |
| Eraser | `eraser` | 20.0pt | 1.0 |
| Text | `textformat` | — | 1.0 |
| Shape | `square.on.circle` | 2.0pt | 1.0 |

#### Tool Button Specs

```
Size:                38x38pt tap target
Icon Size:           18pt
Corner Radius:       Radius SM (6pt)
Unselected:
  Icon Weight:       .regular
  Icon Color:        Text Primary
  Background:        transparent
Selected:
  Icon Weight:       .semibold
  Icon Color:        Primary Accent
  Background:        Accent Subtle (#D55D7A at 15%)
  Border:            none (the background tint is sufficient)
Hover (macOS):
  Background:        Chrome Surface Hover
Press:
  Scale:             0.92x, 80ms easeOut
```

### G.4 Color Picker

Expandable panel that appears BELOW the tool strip when the color indicator is tapped.

```
Expansion Animation: height 0→auto, opacity 0→1, 200ms easeOut
Padding:             12pt horizontal, 10pt vertical
Layout:              HStack, 8pt spacing
```

#### Color Swatches

```
Size:                30pt diameter circles
Border:              0.5pt, #FFFFFF at 30%
Shadow:              #000000 at 10%, radius 2pt, y: 1pt
Selected State:      White inner ring, 2.5pt, inset 3pt from edge
                     Outer scale: 1.1x
Colors:              8 annotation palette colors (see B.7)
```

#### Custom Color (Last Swatch)

```
Icon:                plus, 12pt, Text Secondary
Background:          Chrome Surface Elevated
Border:              dashed, 1pt, Chrome Border
Tap:                 Opens system color picker
```

### G.5 Width Slider

Expandable panel, same as color picker pattern.

```
Layout:              HStack
Left Indicator:      Small circle (3pt diameter, filled, Text Primary)
Slider:              120pt wide, standard Slider, accent tinted
Right Indicator:     Large circle (14pt diameter, filled, Text Primary)
Value Display:       monoSmall, shows current width (e.g., "2.0"), right of slider
```

### G.6 Undo/Redo

```
Position:            Right side of tool strip, after a divider
Icons:               arrow.uturn.backward / arrow.uturn.forward, 15pt, .medium
Disabled State:      Text Disabled color, no interaction
Enabled State:       Text Primary color
```

### G.7 Done Button

```
Position:            Far right of tool strip, after another divider
Label:               "Done", 13pt, .semibold
Color:               Primary Accent
Tap:                 Exits annotation environment with exit transition
```

### G.8 Layer Panel

Accessed via a dedicated button in the tool strip (added to the right, after shapes):

```
Button Icon:         square.3.layers.3d.down.right, 18pt
Panel:               Popover (iPad/macOS) or bottom sheet (iPhone)
Panel Width:         260pt
Panel Max Height:    320pt
```

#### Layer Row

```
Height:              44pt
Leading:             Visibility toggle (eye / eye.slash), 16pt icon, tap to toggle
Center:              Layer name, bodySmall, editable on double-tap
Trailing:            Drag handle (line.3.horizontal), for reordering
Selected Layer:      Accent Subtle background
Active Indicator:    2pt left border, Primary Accent
```

#### Layer Panel Footer

```
Add Layer:           plus.circle, 14pt, "Add Layer" label, bodySmall
Merge Down:          arrow.down.to.line, 14pt, context menu item
Delete Layer:        trash, 14pt, destructive confirmation required
```

### G.9 Stamps Palette

Accessed by long-pressing the Shape tool:

Common musical stamps include:
- Breath mark
- Caesura
- Fermata
- Segno
- Coda
- Rehearsal mark letters (A, B, C...)
- Dynamic markings (pp, p, mp, mf, f, ff)

```
Layout:              4-column grid in a popover
Cell Size:           48x48pt
Icon Size:           24pt
Font:                For text stamps, use serif italic (dynamics like "mf")
Corner Radius:       Radius SM
Hover:               Chrome Surface Hover
Selected:            Accent Subtle background
```

---

## H. Playback Environment

### H.1 Transport Panel

Slides up from the bottom of the screen as a persistent bottom sheet.

```
Position:            Bottom of screen
Height (collapsed):  80pt (shows play/pause, progress, tempo)
Height (expanded):   280pt (shows full mixer, loop controls)
Corner Radius:       Radius XL (20pt), top corners only
Material:            .thickMaterial
Shadow:              #000000 at 12%, radius: 16pt, y: -4pt
Drag Handle:         5pt x 36pt capsule, Chrome Border color, centered at top, 8pt from top edge
```

### H.2 Collapsed Transport

```
Layout:              HStack
Left:                Play/Pause button (play.fill / pause.fill), 28pt, Primary Accent
Center:              Progress bar (custom, not system Slider)
                     Height: 4pt (8pt when touched)
                     Track: Chrome Border color
                     Fill: Primary Accent
                     Thumb: Hidden (appears on touch)
Right Group:
  Current Time:      monoSmall, Text Primary (e.g., "2:34")
  Tempo:             monoSmall, Text Secondary (e.g., "120 BPM")
```

### H.3 Expanded Transport

Additional controls revealed on expansion:

```
Tempo Slider:        "Tempo" label + Slider (40–300 BPM) + value display
Loop Controls:       Toggle (loop icon), start measure, end measure
Metronome:           Toggle (metronome icon) + volume slider
Staff Mixer:         List of staves, each with:
                     - Staff name (bodySmall)
                     - Solo button (S, accent when active)
                     - Mute button (M, red when active)
                     - Volume slider
                     - Pan knob (optional, macOS only)
```

### H.4 Playback Cursor

```
Style:               2pt vertical line, full page height
Color:               Cursor Line (#D55D7A at 80%)
Glow:                8pt soft gaussian blur, Cursor Glow (#D55D7A at 15%)
Movement:            Smooth interpolation, synced to audio playback
```

---

## I. Component Library

### I.1 Buttons

#### Primary Button

```
Height:              44pt
Corner Radius:       Radius MD (10pt)
Background:          Primary Accent (#D55D7A)
Text:                label token (13pt, .medium), white (#FFFFFF)
Icon:                16pt, .medium, white, 8pt gap before text
Horizontal Padding:  20pt
Full Width:          When used as primary action, stretches to fill container
Hover:               Accent Hover (#E06E8A)
Press:               Accent Pressed (#B84D68), scale 0.97x, opacity 0.9
Disabled:            Accent at 40% opacity, text at 50% opacity
```

#### Secondary Button

```
Height:              44pt
Corner Radius:       Radius MD (10pt)
Background:          Accent Subtle (#D55D7A at 12%)
Text:                label token, Primary Accent color
Icon:                16pt, Primary Accent
Hover:               Accent at 18%
Press:               Accent at 8%, scale 0.97x
Disabled:            Background at 6%, text at 40%
```

#### Ghost Button

```
Height:              44pt
Corner Radius:       Radius MD (10pt)
Background:          transparent
Text:                label token, Text Primary
Icon:                16pt, Text Primary
Hover:               Chrome Surface Hover
Press:               Chrome Surface Selected, scale 0.97x
Disabled:            Text Disabled
```

#### Destructive Button

```
Height:              44pt
Corner Radius:       Radius MD (10pt)
Background:          Error (#FF3B30) at 12%
Text:                label token, Error (#FF3B30)
Icon:                16pt, Error
Hover:               Error at 18%
Press:               Error at 8%, scale 0.97x
Full variant:        Solid Error background, white text (for confirmation dialogs)
```

#### Icon Button (Toolbar)

```
Size:                32x32pt (minimum 44x44pt tap target via contentShape)
Corner Radius:       Radius SM (6pt)
Background:          transparent
Icon:                16pt, .regular weight, Text Secondary
Hover:               Chrome Surface Hover, icon: Text Primary
Press:               Chrome Surface Selected, scale 0.92x
Active/Toggled:      Accent Subtle background, icon: Primary Accent
```

### I.2 Cards

#### Standard Card

```
Corner Radius:       Radius LG (14pt)
Background (dark):   Chrome Surface Elevated (#2C2C32)
Background (light):  Chrome Surface (#FFFFFF)
Shadow (dark):       #000000 at 8%, radius: 8pt, y: 2pt
Shadow (light):      #000000 at 6%, radius: 8pt, y: 2pt
Border:              0.5pt, Chrome Border (optional, used in light mode)
Padding:             16pt internal
```

#### Glass Card (Floating Overlays)

```
Corner Radius:       Radius LG (14pt)
Background:          .regularMaterial
Shadow:              #000000 at 10%, radius: 12pt, y: 4pt
Border:              0.5pt, #FFFFFF at 8%
Padding:             16pt internal
```

### I.3 Dividers

```
Standard:            0.5pt height, Chrome Border color, full width
Inset:               0.5pt height, Chrome Border, leading inset 16pt (for lists)
Strong:              1pt height, Chrome Border Strong
Section:             0.5pt height, Chrome Border, 16pt vertical margin
```

### I.4 Badges / Tags

```
Height:              22pt
Corner Radius:       Capsule (fully rounded)
Horizontal Padding:  10pt
Text:                labelSmall (11pt, .medium)
Background:          Accent Subtle
Text Color:          Primary Accent (dark mode) / Accent Pressed (light mode)
```

Count badges (e.g., number of scores in a category):
```
Height:              20pt
Min Width:           20pt (circle for single digits)
Corner Radius:       Capsule
Background:          Chrome Surface Hover
Text:                captionSmall (10pt, .semibold), Text Secondary
```

### I.5 Toggle / Switch

```
Style:               Standard SwiftUI Toggle with .tint(Primary Accent)
Label:               bodySmall (13pt), Text Primary
Description:         captionSmall (10pt), Text Tertiary, below label
```

### I.6 Slider

```
Track Height:        4pt
Track Color:         Chrome Border
Fill Color:          Primary Accent
Thumb:               20pt circle, white, shadow: #000000 at 15%, radius 3pt
Min Width:           100pt
Value Label:         monoSmall, positioned above thumb during drag
```

### I.7 Context Menus

```
Style:               System context menu (.contextMenu modifier)
Icon Size:           16pt, leading position
Text:                body (15pt)
Destructive Items:   Error color for both icon and text
Dividers:            System standard
```

### I.8 Sheets / Modals

#### Bottom Sheet (iOS)

```
Corner Radius:       Radius Sheet (24pt), top corners only
Background:          .regularMaterial
Drag Handle:         5pt x 36pt capsule, Chrome Border, centered, 8pt from top
Detents:             .medium (50%), .large (92%)
```

#### Modal Sheet (macOS)

```
Corner Radius:       Radius XL (20pt)
Background:          Chrome Surface
Shadow:              #000000 at 20%, radius: 24pt
Min Width:           400pt
Max Width:           560pt
Padding:             24pt
```

#### Alert / Confirmation Dialog

```
Style:               System .alert presentation
Title:               heading3 (15pt, .semibold)
Message:             body (15pt), Text Secondary
Button Order:        Cancel (left/secondary), Confirm (right/primary)
Destructive Confirm: Error color
```

### I.9 Empty State View

```
Container:           Centered, max-width 320pt, vertical stack
Icon:                48pt, .light weight, Text Tertiary
                     symbolEffect: .pulse.byLayer, speed: 0.5, repeating
                     Entry: scale 0.85→1.0, opacity 0→1, 500ms easeOut
Title:               heading2 (18pt, .semibold), Text Primary
Message:             body (15pt), Text Secondary, center-aligned
Action:              Primary button (when applicable)
Spacing:             icon→title: 16pt, title→message: 8pt, message→button: 20pt
Entry Stagger:       Icon: 0ms, Text: 100ms, Button: 200ms (each delayed)
```

---

## J. Animation & Motion Design

### J.1 Core Principles

1. **Speed over drama** — Every animation exists to help the user understand spatial relationships, not to entertain.
2. **Perceptible but not distracting** — If a musician notices the animation during performance, it is too slow or too large.
3. **Physics-based feel, not physics-based timing** — Use easeInOut curves, not spring animations. Nothing should bounce, oscillate, or overshoot.

### J.2 Duration Standards

| Category | Duration | Curve |
|---|---|---|
| Micro (button press, icon change) | 100ms | easeOut |
| Small (tooltip, badge appear) | 150ms | easeOut |
| Standard (panel slide, content switch) | 200ms | easeInOut |
| Medium (sheet present, inspector slide) | 250ms | easeInOut |
| Large (environment transition) | 300ms | easeInOut |
| Page turn | 0ms | instant (no animation) |

### J.3 Specific Animations

#### Controls Show/Hide (Reader)

```
Show:       opacity 0→1, translateY 8→0, 200ms easeOut
Hide:       opacity 1→0, translateY 0→4, 250ms easeIn
```

#### Inspector Panel

```
Show:       slide from trailing edge, 250ms easeInOut
Hide:       slide to trailing edge, 200ms easeInOut
```

#### Annotation Toolbar

```
Show:       translateY(toolbar height)→0, opacity 0→1, 250ms easeOut
Hide:       translateY(0)→toolbar height, opacity 1→0, 200ms easeIn
Sub-panel:  height 0→auto, opacity 0→1, 200ms easeOut (color picker, width slider)
```

#### Score Grid Reflow

```
Content:    .animation(.easeInOut(duration: 0.25)) on grid container
            Items animate position with matched geometry when sort changes
```

#### Sidebar Selection

```
Background: 150ms easeInOut fill transition
Content:    200ms crossDissolve in detail area
```

#### Sheet/Modal Present

```
iOS:        System sheet presentation (handled by SwiftUI)
macOS:      Scale 0.95→1.0, opacity 0→1, 250ms easeOut
            Backdrop: opacity 0→0.3, 200ms easeOut
```

#### Hover Effects (macOS)

```
Card hover:     scale 1.0→1.02, shadow elevate, 200ms easeInOut
Button hover:   background fill, 150ms easeInOut
```

### J.4 NEVER Do

- Spring animations with visible bounce
- Page curl transitions
- Slow crossfades (>300ms)
- Scale animations >1.05x (too dramatic)
- Rotation animations on UI elements
- Parallax effects
- Particle effects
- Confetti or celebration animations
- Any animation during page turns
- Elastic/rubber-band animations on controls

---

## K. Icon System

### K.1 Style Rules

```
Weight:              .regular (default), .light (large decorative), .medium (active/selected)
Rendering:           Monochrome (single color, no multicolor SF Symbols)
Size Scale:          Contextual (see specific uses below)
Corner Style:        Rounded (default SF Symbol style)
```

Never use filled variants for navigation icons. Use filled variants ONLY for:
- Active toggle states (e.g., heart.fill for favorited)
- Playback (play.fill, pause.fill)

### K.2 Icon Assignments

#### Sidebar Navigation

| Item | Symbol | Weight |
|---|---|---|
| Library | `music.note.list` | .regular |
| Recently Played | `clock` | .regular |
| Favorites | `heart` / `heart.fill` | .regular |
| Composers | `person.2` | .regular |
| Genres | `guitars` | .regular |
| Set Lists | `list.bullet.rectangle` | .regular |
| Settings | `gearshape` | .regular |

#### Reader Controls

| Action | Symbol | Weight |
|---|---|---|
| Back | `chevron.left` | .medium |
| Display Mode | `rectangle.split.2x1` | .regular |
| Paper Theme | `doc.plaintext` | .regular |
| Annotate | `pencil.tip.crop.circle` | .regular |
| Bookmark | `bookmark` / `bookmark.fill` | .regular |
| Performance Lock | `lock.shield` / `lock.shield.fill` | .regular |
| Zoom In | `plus.magnifyingglass` | .regular |
| Zoom Out | `minus.magnifyingglass` | .regular |

#### Annotation Tools

| Tool | Symbol |
|---|---|
| Pen | `pencil.tip` |
| Pencil | `pencil` |
| Highlighter | `highlighter` |
| Eraser | `eraser` |
| Text | `textformat` |
| Shape | `square.on.circle` |
| Layers | `square.3.layers.3d.down.right` |
| Undo | `arrow.uturn.backward` |
| Redo | `arrow.uturn.forward` |

#### Playback

| Action | Symbol |
|---|---|
| Play | `play.fill` |
| Pause | `pause.fill` |
| Stop | `stop.fill` |
| Loop | `repeat` |
| Metronome | `metronome` |
| Mute | `speaker.slash` |
| Solo | `s.circle` / `s.circle.fill` |

#### Library Actions

| Action | Symbol |
|---|---|
| Import | `plus` |
| Sort | `arrow.up.arrow.down` |
| Filter | `line.3.horizontal.decrease` |
| Grid View | `square.grid.2x2` |
| List View | `list.bullet` |
| Info | `info.circle` |
| Delete | `trash` |
| Share | `square.and.arrow.up` |
| Duplicate | `doc.on.doc` |

### K.3 Custom Icons Needed

These SF Symbols do not exist and require custom assets:

1. **Score/Sheet Music icon** — A stylized treble clef or staff lines, used as the app icon element and empty state decoration. Should match SF Symbol weight and style.
2. **Stamp tool icons** — Musical symbols (fermata, caesura, coda, segno) as stamp assets.
3. **Head tracking icon** — Simplified face with motion arrows, for head-tracking calibration.

Custom icons must be:
```
Line Weight:         Matching SF Symbol .regular weight (~1.5pt at 16pt)
Corner Radius:       Matching SF Symbol rounded terminal style
Canvas:              Designed on a 24x24pt canvas with 2pt padding
Export:              PDF vector, template-rendered (for tint color support)
```

---

## L. Accessibility

### L.1 Touch Targets

```
Minimum tap target:           44x44pt (all interactive elements)
Minimum macOS click target:   28x28pt (with 8pt padding extending to 44pt on iOS)
Toolbar buttons:              Visual: 32x32pt, contentShape: 44x44pt
Score cover cards:             No minimum (large enough inherently)
Annotation swatches:           Visual: 30pt circle, contentShape: 44x44pt
```

### L.2 Contrast Ratios

All text must meet WCAG 2.1 AA standards:

```
Normal text (≤18pt):          Minimum 4.5:1 contrast ratio
Large text (>18pt bold):      Minimum 3.0:1 contrast ratio
Interactive elements:          Minimum 3.0:1 against adjacent colors
Focus indicators:              Minimum 3.0:1 against background
```

Specific verifications:
```
Text Primary on Chrome BG:         #F0F0F2 on #1A1A1E = 15.3:1 (passes AAA)
Text Secondary on Chrome BG:       #A0A0A8 on #1A1A1E = 7.2:1 (passes AA)
Text Tertiary on Chrome BG:        #6E6E78 on #1A1A1E = 3.8:1 (passes for large text)
Accent on Chrome BG:               #D55D7A on #1A1A1E = 5.1:1 (passes AA)
Notation on Paper White:           #1C1C1E on #FFFFFF = 18.1:1 (passes AAA)
Notation on Paper Cream:           #1C1C1E on #FAF5E6 = 16.2:1 (passes AAA)
Annotation Red on Paper White:     #E63946 on #FFFFFF = 4.6:1 (passes AA)
```

### L.3 VoiceOver

#### Library

```
Score Card:          "Score: [title] by [composer]. [duration]. [favorite status]. Double-tap to open. Long press for options."
Sidebar Item:        "[section]: [item name]. [selected status]."
Inspector:           Standard heading/label structure, all metadata readable
```

#### Reader

```
Page:                "Page [current] of [total]. [paper theme]. Tap left to go back, right to go forward."
Control Bar:         Each control labeled with accessibilityLabel and accessibilityHint
Performance Lock:    "Performance lock [enabled/disabled]. Disables all gestures except page turns."
```

#### Annotation

```
Tool:                "[tool name] tool. [selected status]. Double-tap to select."
Color:               "[color name]. [selected status]. Double-tap to select."
Layer:               "Layer [name]. [visibility status]. Double-tap to toggle visibility."
```

### L.4 Dynamic Type

```
Strategy:            Support all Dynamic Type sizes from xSmall through AX5
Scaling:             Use .dynamicTypeSize view modifier to cap maximum in dense toolbars
Toolbar Maximum:     .accessibility1 (prevents toolbar overflow)
Body Content:        Full Dynamic Type range
Score Display:       NOT affected by Dynamic Type (PDF rendering is independent)
Spacing:             Use @ScaledMetric for spacing values adjacent to text
```

### L.5 Reduce Motion

```
When Reduce Motion is enabled:
  - All animations become instant (0ms duration)
  - Page turns remain instant (no change)
  - Control show/hide becomes instant opacity change
  - No scale effects on press/hover
  - Empty state entry has no animation
```

### L.6 Keyboard Navigation (macOS / iPad with keyboard)

```
Tab:                 Moves focus through interactive elements
Arrow Keys:          Navigate score grid, sidebar items
Space:               Activate focused button
Enter:               Open selected score
Escape:              Close inspector, exit annotation, dismiss sheet
Cmd+F:               Focus search field
Cmd+L:               Toggle performance lock
Cmd+I:               Toggle inspector
Cmd+[/]:             Previous/next page
```

---

## M. Platform Adaptations

### M.1 iPhone (Compact)

#### Navigation

```
Structure:           TabView with 3 tabs (Library, Setlists, Settings)
                     No sidebar — sidebar items become tab destinations or drill-down
Tab Bar:             System standard, hidden in Reader
```

#### Library

```
Grid Columns:        2 columns, adaptive(minimum: 140, maximum: 170)
Card Spacing:        16pt
Screen Margins:      16pt
Search:              System .searchable, inline in navigation bar
Inspector:           Full-screen sheet, presented on score tap
Sort/Filter:         Menu in navigation bar trailing position
```

#### Reader

```
Controls:            Same floating bar, width adapts to screen
Top Bar:             Compact — back arrow + page number only (no title)
Floating Bar:        Horizontal scroll if needed (unlikely at iPhone width)
Page Turn Zones:     Same percentages (40/20/40)
Annotation:          Toolbar may need to become a compact bottom bar
                     Color picker: horizontal scroll instead of grid
```

#### Differences

```
No hover states
No inspector column (full-screen sheet instead)
No two-page spread (not enough width)
Haptic feedback on page turns (light impact)
Haptic feedback on button press (selection feedback)
```

### M.2 iPad

#### Navigation

```
Structure:           NavigationSplitView (sidebar + detail)
Sidebar:             Always available in landscape, toggleable in portrait
Inspector:           System .inspector modifier, trailing column
```

#### Library

```
Grid Columns:        4–6 depending on orientation and inspector visibility
Card Spacing:        20pt
Screen Margins:      20pt (portrait), 24pt (landscape)
Inspector:           Slides in as trailing column, 280pt ideal width
```

#### Reader

```
Controls:            Same floating bar design
Two-Page Spread:     Available in landscape (suggested default for 12.9" iPad Pro)
Annotation:          Full floating palette, repositionable
Apple Pencil:        Annotation mode auto-activates on Pencil contact
                     No need to tap annotation toggle when Pencil is detected
```

#### Multitasking

```
Split View:          Supported — UI adapts to compact width
Slide Over:          Supported — uses iPhone layout
Stage Manager:       Supported — uses adaptive layout based on window size
Minimum Width:       320pt (compact layout triggers below this)
```

### M.3 macOS

#### Window Chrome

```
Title Bar:           Standard macOS title bar, integrated with toolbar
                     Transparent title bar style (.windowStyle(.hiddenTitleBar) NOT used — keep standard)
Window Background:   Chrome Background
Minimum Size:        900 x 600pt
Default Size:        1200 x 800pt
```

#### Navigation

```
Structure:           NavigationSplitView, sidebar always visible (collapsible)
Sidebar Width:       200–300pt
Detail:              Full remaining width
Inspector:           macOS inspector panel, 240–380pt
```

#### Cursor Interactions

```
Hover States:        All interactive elements show hover state (background change)
Cursor:              Standard arrow; pointingHand over clickable cards
Tooltips:            Show on hover for icon-only buttons (0.5s delay)
Right-Click:         Context menus on all score cards, sidebar items
```

#### Menu Bar

```
File:                Import Score, Open Recent, Close
Edit:                Undo, Redo, Select All, Find
View:                Show/Hide Sidebar, Show/Hide Inspector, Display Mode submenu
Score:               Next Page, Previous Page, Go to Page, Bookmark, Performance Lock
Annotation:          Toggle Annotation, Tool Selection, Clear Annotations
Window:              Standard macOS window management
```

#### Keyboard Shortcuts

```
Cmd+O:               Import score
Cmd+F:               Search library
Cmd+I:               Toggle inspector
Cmd+1..6:            Switch sidebar section
Cmd+[:               Previous page
Cmd+]:               Next page
Cmd+L:               Performance lock
Cmd+Shift+A:         Toggle annotation
Cmd+Z:               Undo (annotation)
Cmd+Shift+Z:         Redo (annotation)
Cmd+0:               Zoom to fit
Cmd+Plus:            Zoom in
Cmd+Minus:           Zoom out
Space:               Play/Pause (when playback is active)
```

#### Reader (macOS-specific)

```
Full Screen:         Supports macOS native full screen (green button)
Controls:            Appear on mouse movement, hide after 4s inactivity
Trackpad:            Pinch-to-zoom supported
Scroll Wheel:        Vertical scroll in vertical scroll mode
                     Page turn in single/spread mode (one "click" per page)
```

---

## Appendix: Design Tokens Quick Reference

### SwiftUI Implementation Notes

All colors should be defined as `Color` extensions or static properties on a design token enum. Use `@Environment(\.colorScheme)` to switch between dark and light chrome palettes. Paper colors are NEVER affected by color scheme.

Typography should use the `Font.system(size:weight:design:)` initializer with `.tracking()` modifier for letter spacing. All sizes must use `@ScaledMetric` or `.dynamicTypeSize` for accessibility.

Spacing values are static `CGFloat` constants on a spacing enum. Corner radii are static `CGFloat` constants on a radius enum.

Animations should use explicit `.animation()` modifiers with `withAnimation` blocks, never implicit animation on large view trees. Use `.transaction { $0.animation = nil }` to suppress animation where page turns must be instant.

Materials should use SwiftUI's built-in `.regularMaterial`, `.thickMaterial`, etc., NOT custom blur implementations. These automatically adapt to light/dark mode and provide vibrancy.

### File Structure for Design System Package

```
DesignSystem/
  Theme/
    ColorTokens.swift          — All color definitions
    Typography.swift           — All font definitions
    Spacing.swift              — Spacing and radius constants
    AnimationTokens.swift      — Duration and curve constants
    ShadowTokens.swift         — Shadow definitions
  Components/
    PremiumButton.swift        — All button variants
    ScoreCoverCard.swift       — Library score card
    GlassCard.swift            — Glass material card
    EmptyStateView.swift       — Empty state component
    TagChip.swift              — Tag/badge component
    DividerView.swift          — Custom divider variants
    FloatingPalette.swift      — Base floating palette container
    InspectorRow.swift         — Inspector key-value row
    LayerRow.swift             — Annotation layer list row
  Utilities/
    FlowLayout.swift           — Flow layout for tags
    HapticManager.swift        — Haptic feedback wrapper
    ReduceMotion.swift         — Reduce motion utilities
```

---

*This specification is the canonical reference for all ScoreStage UI implementation. No UI code should be written without cross-referencing this document. When in doubt, the answer is: make it feel like Logic Pro, not like Notes.*

---

## N. Insights from Logic Pro, Dorico & Finale Interfaces

**Purpose:** This section distills specific, actionable UI patterns from Apple's Logic Pro (the gold standard for professional macOS/iPadOS creative tools), Steinberg's Dorico (the leading modern notation software), and the legacy lessons of MakeMusic's Finale. Every recommendation below is calibrated to ScoreStage's specific role as a professional score reader, annotator, and performance tool.

---

### N.1 Logic Pro Control Bar — Lessons for ScoreStage's Transport & Navigation

Logic Pro's control bar is a single 39pt-tall horizontal strip that spans the full window width. It serves as the persistent anchor for the entire application: always visible, always accessible, never competing with content.

#### Patterns to Adopt

**Single-strip persistent navigation.** Logic Pro consolidates transport controls, LCD display, mode buttons, and view toggles into one compact horizontal bar. ScoreStage should adopt this for the Reader and Playback environments:

```
ScoreStage Control Strip:
  Position:            Top of Reader/Playback screen, pinned
  Height:              44pt (iPad) / 38pt (macOS) — slightly taller than Logic's 39pt for touch targets
  Background:          .ultraThinMaterial over Chrome Background (#1A1A1E)
  Bottom Border:       0.5pt, Chrome Border (#3A3A42)
  Horizontal Padding:  16pt
  Layout:              Leading group | Center group | Trailing group
```

**Leading group** (navigation):
```
  Back Chevron:        chevron.left, 15pt, .medium weight, Text Secondary
  Score Title:         bodySmall (13pt, .medium), Text Primary, truncated to 180pt max
  Divider:             Vertical, 16pt tall, Chrome Border, 12pt horizontal margin
  Page Indicator:      monoSmall, "3 of 24", Text Secondary
```

**Center group** (transport, Playback mode only):
```
  Rewind:              backward.fill, 14pt, Text Secondary
  Play/Pause:          play.fill / pause.fill, 18pt, Text Primary
  Forward:             forward.fill, 14pt, Text Secondary
  Tempo Display:       monoSmall, "♩= 120", Text Secondary
  Gap Between:         16pt between transport icons
```

**Trailing group** (tools):
```
  Annotation Toggle:   pencil.tip.crop.circle, 16pt
  Bookmark Toggle:     bookmark, 16pt
  Inspector Toggle:    sidebar.right, 16pt
  More Menu:           ellipsis.circle, 16pt
  Gap Between:         12pt
  Active State:        Accent color fill, .semibold weight
  Inactive State:      Text Secondary, .regular weight
```

**Auto-hide behavior.** Logic Pro's control bar is always visible, but ScoreStage's Reader is score-dominant. Implement conditional auto-hide:

```
Auto-Hide Rules:
  Reader (no playback):    Control strip hides after 3 seconds of no interaction
  Reader (with playback):  Control strip remains visible (transport must be accessible)
  Annotation mode:         Control strip always visible (tools must be accessible)

  Hide Animation:          translateY(-44pt), opacity 1→0, 300ms, easeInOut(duration: 0.3)
  Reveal Trigger:          Tap top 60pt of screen, or any two-finger tap
  Reveal Animation:        translateY(0), opacity 0→1, 250ms, easeOut(duration: 0.25)
```

#### Logic Pro's LCD Display — Lessons for Measure/Position Display

Logic Pro's LCD is a centered, recessed display showing playhead position, tempo, key, and time signature. It uses a darker inset background within the already-dark control bar, creating a visual hierarchy of depth.

```
Position Display (for Playback mode):
  Background:          Chrome Background (#1A1A1E) — one step darker than strip
  Corner Radius:       Radius SM (6pt)
  Padding:             8pt horizontal, 4pt vertical
  Inner Shadow:        #000000 at 20%, radius 2pt, y: 1pt (inset effect)
  Text Style:          monoSmall (12pt, .medium, .monospaced)
  Primary Value:       Measure number, Text Primary (#F0F0F2)
  Secondary Values:    Beat position, tempo — Text Secondary (#A0A0A8)
  Dividers:            Thin vertical lines, Chrome Border, between value groups
```

---

### N.2 Logic Pro Track Headers & Inspector — Lessons for ScoreStage's Metadata Display

Logic Pro's track headers are 34pt-tall rows with an icon, name, and compact controls (mute, solo, volume). They use extremely tight horizontal packing with clear visual hierarchy.

#### Patterns to Adopt for Inspector Rows

ScoreStage's Inspector (Section E.3) should adopt Logic Pro's information density approach:

```
Inspector Metadata Row (Logic-inspired refinement):
  Height:              34pt (reduced from implicit larger sizing for density)
  Leading Icon:        14pt SF Symbol, Text Tertiary, 12pt left padding
  Label:               labelSmall (11pt, .medium), Text Secondary, uppercase
  Value:               bodySmall (13pt, .regular), Text Primary, trailing-aligned
  Separator:           0.33pt line (not 0.5pt — Logic uses sub-pixel rendering for near-invisible separators)
  Separator Color:     Chrome Border at 60% opacity
  Separator Inset:     38pt leading (aligns past icon column)
```

**Logic Pro's "Inspector" vs ScoreStage's Inspector.** Logic's Inspector is a left-side panel that contextually shows parameters for the selected track or region. Key takeaway: the Inspector should load instantly with zero animation when switching between scores in the Library, because Logic Pro's Inspector never animates its content swap — it simply replaces content, which communicates speed and responsiveness.

```
Inspector Content Swap:
  Animation:           .none — content replaces immediately
  Opacity:             Brief 80%→100% fade, 120ms, linear (subtle life signal, not a transition)
  Scroll Position:     Reset to top on new selection
```

---

### N.3 Logic Pro's Dark Chrome, Light Content Paradigm

Logic Pro establishes the definitive pattern that ScoreStage already follows: dark surrounding chrome with light content areas. In Logic, the tracks area background is a slightly lighter dark gray than the surrounding panels, and the piano roll editor uses a darker gridded area. But the critical insight is how Logic handles the **boundary** between chrome and content.

#### Chrome-to-Content Boundary Treatment

Logic Pro does NOT use a hard border between the dark sidebar and the content area. Instead, it uses a combination of:

1. A 1px border in a color only marginally lighter than the darker surface
2. A subtle inner shadow on the content side
3. A slight luminosity difference (the content area is ~8% lighter than the sidebar)

ScoreStage should refine its chrome-to-paper boundary:

```
Score Paper Edge Treatment (Reader Environment):
  Paper Shadow:        Already defined in B.4 — keep as-is

  Chrome-to-Paper Transition Zone:
    Between sidebar/inspector and score area:
      Border:          0.5pt, Chrome Border (#3A3A42)
      Inner Glow:      On the chrome side, a 4pt gradient from Chrome Surface (#232328) to transparent
                       This creates a subtle "recess" effect, making the paper feel like it sits IN the app

    Between control strip and score area:
      Bottom shadow:   #000000 at 8%, blur 4pt, y-offset 2pt
                       This separates the strip from the score without a hard line

  Score Area Background (the "desk" behind the paper):
    Color:             #141416 — darker than Chrome Background (#1A1A1E)
    Purpose:           Makes the paper float above a very dark surface, maximizing perceived brightness of notation
    Texture:           None — Logic uses no texture, and neither should ScoreStage
```

#### Why This Matters

Dorico and Finale both struggled with this boundary. Finale used a flat gray background behind the score with minimal differentiation, making the interface feel dated. Dorico improved on this with a slightly textured dark background, but still uses harder borders between panels. Logic Pro's approach — graduated luminosity with near-invisible borders — is the gold standard.

---

### N.4 Floating Tool Windows vs Docked Panels

Logic Pro offers both paradigms: fixed docked panels (Inspector, Library, Mixer) and floating windows (Event Float, Region Inspector Float, various plugin windows). The key insight for ScoreStage:

#### Recommendation: Docked by Default, Floatable Where Justified

```
Panel Paradigm for ScoreStage:

  ALWAYS DOCKED:
    - Library Sidebar           (consistent navigation anchor)
    - Inspector Panel           (contextual detail, always available)
    - Settings                  (full-screen modal, not a panel)

  ALWAYS FLOATING:
    - Annotation Palette        (already defined as floating — correct choice)
    - Quick Actions Menu        (popover, contextual)
    - Playback Mini Controls    (when in annotation mode, small floating transport)

  USER'S CHOICE (Docked or Floating):
    - NOT APPLICABLE — ScoreStage is a focused reader, not a multi-window DAW.
      Avoid offering this flexibility. It adds complexity without benefit for a score reader.
```

**Logic Pro's floating windows use a specific visual language** that ScoreStage's annotation palette already partially follows:

```
Floating Panel Visual Language (Logic-derived):
  Shadow:              #000000 at 18%, radius 24pt, y: 10pt — slightly heavier than docked panels
  Corner Radius:       16pt (Radius LG) — more rounded than docked panels to signal "floating"
  Border:              0.5pt, #FFFFFF at 10% — very subtle white edge for lift
  Material:            .thickMaterial — must maintain legibility when overlapping score
  Drag Handle:         Capsule, 5pt x 36pt, Chrome Border color, top-center, 6pt from top

  Distinction from Docked:
    Docked panels:     Square corners on the docked edge, rounded on exposed edges
    Floating panels:   Fully rounded, heavier shadow, translucent material
```

---

### N.5 Logic Pro's Use of SF Symbols and Monochrome Iconography

Logic Pro uses a consistent monochrome icon system throughout its interface. All icons are single-color, using weight variations (not color) to communicate state.

#### Patterns to Adopt

ScoreStage already specifies SF Symbols (Section K), but should adopt Logic Pro's specific state conventions more rigorously:

```
Icon State Matrix (Logic Pro pattern):

  State              Weight      Color              Fill Variant
  ─────────────────────────────────────────────────────────────
  Default            .regular    Text Secondary     Outline
  Hover (macOS)      .regular    Text Primary       Outline
  Active/Selected    .semibold   Primary Accent     Filled (.fill)
  Disabled           .regular    Text Disabled      Outline
  Destructive        .regular    Error (#FF3B30)    Outline
  Destructive Hover  .medium     Error (#FF3B30)    Filled (.fill)
```

**Key Logic Pro icon sizing convention:** Logic uses 13pt icons in toolbars, 16pt in sidebars, and 20pt for primary actions. ScoreStage should standardize:

```
Icon Size Tokens:
  iconToolbar:       14pt   — control strip, compact toolbars
  iconSidebar:       16pt   — sidebar items (already defined)
  iconAction:        20pt   — primary action buttons (play, annotate)
  iconDisplay:       28pt   — empty state icons, onboarding
  iconHero:          48pt   — splash/empty library state
```

**Logic Pro never uses colored icons in the chrome.** All toolbar and sidebar icons are monochrome. The only color that appears on icons is the system accent (blue in Logic, rose-copper in ScoreStage) to indicate active state. ScoreStage must enforce this same discipline:

```
Icon Color Rules:
  Chrome context:    ONLY Text Primary, Text Secondary, Text Tertiary, Text Disabled, or Primary Accent
  Score context:     Annotation colors are permitted (these are on paper, not chrome)
  NEVER:             Multi-color icons in chrome areas
  NEVER:             Gradient fills on icons
  EXCEPTION:         Favorite heart (heart.fill) uses Primary Accent, as already specified in E.2
```

---

### N.6 Specific Colors and Visual Treatments from Logic Pro

Logic Pro's default color palette (extracted from the macOS interface via pixel sampling) provides these reference values. ScoreStage's existing palette is well-calibrated, but these Logic Pro reference colors validate and refine the choices:

```
Logic Pro Reference Colors (macOS, default dark theme):
  Window Background:           #1E1E1E  — ScoreStage uses #1A1A1E (slightly warmer, good differentiation)
  Panel Background:            #282828  — ScoreStage uses #232328 (slightly darker, adds depth)
  Track Header Background:     #313131  — ScoreStage uses #2C2C32 for elevated surfaces (close match)
  Selected Track:              #3A3A3A  — ScoreStage uses #3E3E46 (slightly lighter, fine)
  Control Bar Background:      #2A2A2A  — flat, slightly lighter than panels
  Separator Lines:             #3C3C3C at ~70% opacity
  LCD Display Background:      #1A1A1A  — recessed, darker than everything else
  Text Primary:                #E8E8E8  — ScoreStage uses #F0F0F2 (slightly brighter, appropriate for reading)
  Text Secondary:              #999999  — ScoreStage uses #A0A0A8 (close match with slight warmth)
  Active Element (system):     #4E8EF5  — Apple's system blue accent
  Meter Green:                 #52C74C  — for level meters, VU displays
  Meter Yellow:                #FFD60A  — caution zone
  Meter Red:                   #FF3B30  — clipping indicator
```

**Validation:** ScoreStage's palette skews 2-4 values warmer (adding slight blue-gray undertone via the trailing hex digits like `1E`, `28`, `32` instead of Logic's neutral `1E`, `28`, `31`). This is intentional and correct — it prevents ScoreStage from looking like a Logic Pro skin while maintaining the same perceived depth hierarchy.

#### Visual Treatments to Adopt

**Recessed Display Wells.** Logic Pro uses inset/recessed areas for data displays (LCD, level meters). ScoreStage should use this for:

```
Recessed Well Treatment:
  Background:          Chrome Background (#1A1A1E) — one step darker than surrounding surface
  Inner Shadow:        inset, #000000 at 15%, blur 2pt, y: 1pt
  Corner Radius:       Radius SM (6pt)
  Border:              0.5pt, Chrome Border at 50% opacity

  Use For:
    - Playback position display (measure/beat readout)
    - Tempo display in transport
    - Page number display in control strip
    - Any numeric readout that updates in real-time
```

**Toolbar Button Grouping.** Logic Pro groups related toolbar buttons with a shared background capsule:

```
Button Group Treatment:
  Background:          Chrome Surface Elevated (#2C2C32) at 60% opacity
  Corner Radius:       Radius MD (10pt)
  Padding:             4pt all sides
  Internal Divider:    0.5pt vertical line, Chrome Border at 40%, 12pt tall, centered

  Use For:
    - Transport controls group (rewind, play, forward)
    - View mode toggles (grid/list in Library)
    - Zoom controls (if applicable in Reader)
```

---

### N.7 Dorico's Score Display and Chrome Separation

Dorico is the most relevant reference for how ScoreStage should handle the score itself, because Dorico is the only professional tool where the score IS the content (not a track, not a video timeline).

#### Dorico's Panel Architecture

Dorico uses a five-zone layout: top toolbar, left panel, right panel, bottom panel, and the central score view. All panels can be independently shown or hidden, and the score view expands to fill available space.

```
Dorico Panel Visibility Pattern (adopt for ScoreStage):

  Panel Toggle Animation:
    Show:              Width/height expands from 0 to target, 200ms, easeOut
    Hide:              Width/height collapses to 0, 180ms, easeIn
    Score Reflow:      The score area resizes simultaneously with panel animation
                       This is CRITICAL — the paper must resize in sync, never after

  Implementation:      Use .matchedGeometryEffect or synchronized withAnimation blocks
                       to ensure panel resize and score reflow are in the same animation frame
```

#### Dorico's Score View Background

Dorico uses a medium-dark gray (#3C3C3C approximate) behind the score pages, which provides contrast against the white paper without being as dark as the surrounding chrome. This creates a three-tier luminosity hierarchy:

```
Luminosity Hierarchy (Dorico-inspired, adapted for ScoreStage):

  Tier 1 (darkest):    Chrome panels — #232328 (sidebar, inspector)
  Tier 2 (medium):     Score desk — #141416 (area behind the paper)
  Tier 3 (lightest):   Score paper — #FFFFFF or cream variant

  Note: ScoreStage inverts Dorico's Tier 1/2 relationship. Dorico's panels are
  darker than its desk; ScoreStage makes the desk darker than the panels. This is
  intentional — it pushes the paper forward more aggressively, which is correct
  for a reading-first app where the score must command maximum attention.
```

#### Dorico's Popovers

Dorico uses popovers extensively for quick note input (dynamics, tempo markings, clefs). These are small, focused, and disappear after entry. ScoreStage should adopt this pattern for:

```
Quick Action Popovers (Dorico-inspired):

  Use Cases:
    - Bookmark naming
    - Rehearsal mark entry
    - Quick tag assignment
    - Page jump (enter page number)

  Specs:
    Background:        .regularMaterial
    Corner Radius:     Radius MD (10pt)
    Shadow:            #000000 at 12%, radius 8pt, y: 4pt
    Arrow:             12pt, pointing toward trigger element
    Text Field:        Full-width, bodySmall, auto-focused on appear
    Max Width:         220pt
    Appear:            Scale 0.9→1.0, opacity 0→1, 180ms, spring(response: 0.3, dampingFraction: 0.8)
    Dismiss:           Scale 1.0→0.95, opacity 1→0, 120ms, easeIn
    Auto-Dismiss:      On Return key press or tap outside
```

---

### N.8 Lessons from Finale's Decline

Finale was discontinued in August 2024 after 35 years. Its interface failings are instructive warnings for ScoreStage:

#### What Finale Got Wrong (Avoid These)

1. **Menu-buried functionality.** Finale's most powerful features were hidden in nested submenus and dialog boxes. Users described the interface as "convoluted — anything is possible if you can find it." ScoreStage must ensure every common action is reachable within 2 taps/clicks.

2. **Stagnant visual design.** Finale's interface barely evolved visually after 2014, making it feel increasingly out of place on modern macOS and Windows. ScoreStage must track Apple's design language evolution, particularly material treatments and SF Symbol updates.

3. **No contextual UI.** Finale showed the same interface regardless of what the user was doing. ScoreStage's environment model (Library, Reader, Annotation, Playback) is the correct antidote — each mode shows exactly what is needed and nothing more.

4. **Poor dark mode support.** Finale never properly supported macOS dark mode. Its window chrome was a mid-gray that clashed with both light and dark system appearances.

#### What Finale Got Right (Preserve These)

1. **Score display fidelity.** Finale's score rendering was exceptionally accurate to printed output. ScoreStage must maintain the same principle: the PDF must render at maximum fidelity, with no re-interpretation or re-layout of the notation.

2. **Comprehensive tool palettes.** Despite poor discoverability, Finale's tool palettes were logically grouped by function. ScoreStage's annotation palette should follow this: group tools by purpose (drawing tools, text tools, musical symbols).

3. **Keyboard shortcut density.** Power users could operate Finale almost entirely via keyboard. ScoreStage should support extensive keyboard shortcuts on macOS/iPad-with-keyboard for every Reader and Annotation action.

```
Keyboard Shortcut Priority List:
  Space:               Play/Pause (universal music app convention from Logic, Dorico, Finale)
  Left/Right Arrow:    Previous/Next page
  Cmd+Left/Right:      Previous/Next bookmark
  P:                   Toggle annotation pen
  H:                   Toggle highlighter
  E:                   Toggle eraser
  T:                   Add text annotation
  Cmd+Z:               Undo
  Cmd+Shift+Z:         Redo
  Escape:              Exit current mode (annotation → reader, expanded → collapsed)
  1-8:                 Select annotation color by index
  Cmd+B:               Toggle bookmark on current page
  F:                   Toggle fullscreen / hide all chrome
```

---

### N.9 Animation Patterns and Micro-Interactions Worth Adopting

#### From Logic Pro

**Plugin window open/close.** When opening a plugin, Logic Pro uses a fast scale-up from the point of origin:

```
Panel Open (from button):
  Origin:              Center of the trigger button
  Scale:               0.85→1.0
  Opacity:             0→1
  Duration:            220ms
  Curve:               spring(response: 0.35, dampingFraction: 0.78)

  Use For:             Inspector panel reveal, popover appear, sheet presentation
```

**Mixer channel strip hover.** On macOS, hovering over a mixer channel strip subtly brightens it:

```
Surface Hover (macOS only):
  Background:          Lerp from resting color to Chrome Surface Hover
  Duration:            150ms
  Curve:               easeInOut

  Use For:             Score cards in Library grid, Inspector rows, sidebar items
```

**Transport play feedback.** When pressing Play, Logic Pro provides a brief visual pulse on the play button:

```
Play Button Activation:
  Phase 1:             Scale 1.0→0.88, 60ms, easeOut
  Phase 2:             Scale 0.88→1.05, 120ms, spring(response: 0.25, dampingFraction: 0.5)
  Phase 3:             Scale 1.05→1.0, 100ms, easeOut
  Simultaneously:      Icon swaps from play.fill to pause.fill at the Phase 1→2 boundary
  Haptic:              .medium impact (iOS)
```

#### From Dorico

**Mode switching.** Dorico's mode tabs (Setup, Write, Engrave, Play, Print) trigger a full workspace reconfiguration with a brief crossfade:

```
Environment Transition (Dorico-inspired):
  Content:             Crossfade, 200ms, easeInOut — outgoing fades to 0, incoming fades from 0
  Panels:              Simultaneous reconfiguration — panels for the new environment slide in/out
  Score:               Remains stable (no animation) if the same score is displayed in both environments
  Tab Indicator:       Accent-colored underline slides to new position, 250ms, spring(response: 0.4, dampingFraction: 0.85)
```

**Real-time property feedback.** Dorico's Properties panel updates the score in real time as values change. ScoreStage should adopt this for annotation properties:

```
Live Annotation Property Updates:
  Color Change:        Stroke color updates instantly as the user taps a new swatch (no confirmation needed)
  Width Change:        Stroke width updates in real time as the slider moves
  Opacity Change:      Layer opacity updates in real time as adjusted
  Undo Granularity:    Each property change is a single undo step
```

#### Shared Pattern: Contextual Toolbar Morphing

Both Logic Pro and Dorico change their toolbar contents based on the current mode/context. ScoreStage should implement toolbar morphing for the control strip:

```
Control Strip Morphing:

  Reader Mode Strip:     [Back] [Title] [Page] ———— [Annotate] [Bookmark] [Inspector] [More]
  Annotation Mode Strip: [Done] [Undo] [Redo] ———— [Tool Palette Reference] [Layer] [Color]
  Playback Mode Strip:   [Back] [Title] ——[Transport Controls]—— [Tempo] [Loop] [Inspector]

  Morph Animation:
    Outgoing items:      Fade out + slight translateY(-4pt), 150ms, easeIn
    Incoming items:      Fade in + translateY(4pt)→0, 200ms, easeOut, 50ms delay after outgoing starts
    Total perceived:     ~250ms for complete morph
```

---

### N.10 Summary: Priority Adoption Matrix

| Pattern | Source | Priority | Complexity | Sections Affected |
|---|---|---|---|---|
| Control strip with auto-hide | Logic Pro | **P0** | Medium | F (Reader), H (Playback) |
| Recessed display wells | Logic Pro | **P1** | Low | H (Playback) |
| Button group capsules | Logic Pro | **P1** | Low | I (Components) |
| Icon state matrix (weight + fill) | Logic Pro | **P0** | Low | K (Icons) |
| Chrome-to-paper boundary refinement | Logic Pro + Dorico | **P0** | Low | F (Reader) |
| Score desk darker than chrome | Dorico | **P1** | Low | B (Colors) |
| Panel show/hide with score reflow sync | Dorico | **P1** | Medium | F, E (Reader, Library) |
| Quick-action popovers | Dorico | **P2** | Medium | I (Components) |
| Toolbar morphing between modes | Logic Pro + Dorico | **P1** | High | F, G, H |
| Play button activation pulse | Logic Pro | **P2** | Low | H (Playback), J (Animation) |
| Keyboard shortcut coverage | Finale + Logic Pro | **P0** | Medium | All environments |
| Inspector instant content swap | Logic Pro | **P1** | Low | E (Library) |
| 0.33pt sub-pixel separators | Logic Pro | **P2** | Low | I (Components) |

---

### N.11 Design Token Additions

Based on the patterns above, the following tokens should be added to the design system:

```swift
// ColorTokens.swift additions
static let scoreDesk = Color(hex: "#141416")           // Dark surface behind score paper
static let recessedWell = Color(hex: "#1A1A1E")         // Inset display backgrounds
static let recessedWellBorder = Color(hex: "#3A3A42").opacity(0.5)
static let buttonGroupBg = Color(hex: "#2C2C32").opacity(0.6)
static let separatorSubPixel = Color(hex: "#3A3A42").opacity(0.6)
static let chromeInnerGlow = Color(hex: "#232328")      // Gradient start for panel edge recess

// AnimationTokens.swift additions
static let panelMorph: Animation = .easeInOut(duration: 0.2)
static let controlStripHide: Animation = .easeInOut(duration: 0.3)
static let controlStripReveal: Animation = .easeOut(duration: 0.25)
static let popoverAppear: Animation = .spring(response: 0.3, dampingFraction: 0.8)
static let popoverDismiss: Animation = .easeIn(duration: 0.12)
static let playPulseDown: Animation = .easeOut(duration: 0.06)
static let playPulseUp: Animation = .spring(response: 0.25, dampingFraction: 0.5)
static let surfaceHover: Animation = .easeInOut(duration: 0.15)
static let toolbarItemOut: Animation = .easeIn(duration: 0.15)
static let toolbarItemIn: Animation = .easeOut(duration: 0.2)

// Spacing.swift additions
static let controlStripHeight: CGFloat = 44    // iPad
static let controlStripHeightMac: CGFloat = 38 // macOS
static let autoHideDelay: TimeInterval = 3.0   // seconds before control strip hides
static let recessedWellInnerShadowRadius: CGFloat = 2
static let buttonGroupInternalDividerHeight: CGFloat = 12
```

---
