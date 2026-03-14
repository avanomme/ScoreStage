1. The Core UI Problem Most Music Apps Have

Most sheet music apps eventually become unusable because they mix three fundamentally different interaction environments into one UI system:
	1.	Library management
	2.	Score reading
	3.	Editing / annotation

When these are not separated architecturally, the result becomes:
	•	cluttered toolbars
	•	overlapping gestures
	•	constant accidental taps
	•	UI elements covering the score
	•	“Notes app with sheet music” appearance

This project must not allow this to happen. The Current UI looks like a carbon copy of the Apple Notes application./

The solution is a strict UI environment architecture.

⸻

2. UI Environment Architecture

The application must be divided into four completely separate UI environments.

Each environment has its own:
	•	layout rules
	•	gesture system
	•	visual styling
	•	control set
	•	animation behavior

These environments must never share the same UI layer.

Library Environment
Reader Environment
Annotation Environment
Playback Environment

Transitions between environments should be explicit and controlled.

⸻

3. Library Environment

Purpose: manage music collection.

This behaves like a media library application, similar to:
	•	Apple Music
	•	Lightroom
	•	Final Cut Pro browser

Layout Structure

Sidebar
Main Score Grid
Inspector Panel

Sidebar

Contains:
	•	Library
	•	Set Lists
	•	Composers
	•	Genres
	•	Recently Played
	•	Favorites

Score Grid

Scores appear as large cover thumbnails, not rows in a list.

Each card contains:
	•	thumbnail of first page
	•	title
	•	composer
	•	optional tags
	•	duration

Cards should resemble album art or score covers, not file system items.

Inspector Panel

Displays detailed metadata when a score is selected:
	•	title
	•	composer
	•	instrumentation
	•	duration
	•	tags
	•	notes

Important Rule

The Library UI must never resemble a document editor.

It must resemble a music library browser.

⸻

4. Reader Environment (Performance Mode)

This is the primary environment musicians use while performing.

It must be treated as a sacred full-screen display mode.

Absolute Rule

The score display must always remain light-mode paper.

Even if the application uses dark UI elsewhere, the score itself must remain:

white paper background
dark notation

Reason:

Musicians read printed notation and expect the same visual contrast.

Dark-mode scores reduce readability and are not used in professional contexts.

Reader Layout

Full-screen score
No persistent toolbars
No side panels
No UI chrome

Controls appear only when invoked.

Reader Controls

Controls appear as a floating translucent overlay when:
	•	the user taps the screen
	•	the mouse moves (macOS)
	•	keyboard shortcut invoked

Controls fade away automatically.

Floating Control Bar

Contains:
	•	annotation toggle
	•	playback
	•	page navigation
	•	bookmarks
	•	display settings

The toolbar must be:
	•	minimal
	•	semi-transparent
	•	centered or bottom-aligned
	•	auto-hidden

Performance Lock Mode

A special mode that disables accidental input.

Options include:
	•	ignore all taps except page turn zones
	•	ignore gestures
	•	lock zoom

This is critical for stage reliability.

⸻

5. Annotation Environment

Annotation must be a separate environment layered over the Reader.

Entering annotation mode should:
	•	reveal annotation toolbar
	•	enable pencil / drawing input
	•	keep score fully visible

Annotation Toolbar

Displayed as a floating palette.

Tools include:
	•	pen
	•	highlighter
	•	eraser
	•	shapes
	•	text
	•	stamps

Toolbar must resemble Procreate-style drawing tools, not a document editor ribbon.

Annotation Layers

Annotations must support layers:
	•	performer markings
	•	teacher markings
	•	rehearsal notes
	•	personal notes

Layers can be toggled on/off instantly.

⸻

6. Playback Environment

Playback controls should appear as a slide-up panel from the bottom of the screen.

This prevents playback UI from covering the score unnecessarily.

Playback Panel Contents

Play / Pause
Tempo slider
Loop controls
Measure selection
Metronome toggle
Staff mute/solo
Volume mixer

This panel should resemble a mini transport panel from a DAW.

Playback Cursor

Playback must show a cursor moving through the score.

Cursor color should use the application’s accent color.

⸻

7. Gesture Architecture

Gestures must be predictable and configurable.

Default Page Turn Zones

Right side tap → next page
Left side tap → previous page

Additional Gestures

Pinch → zoom
Two finger tap → toggle annotation
Long press → bookmarks

Users must be able to customize gesture zones.

⸻

8. Motion / Eye Tracking Page Turns

Movement-based page turning must operate independently of other gestures.

Motion Detection Module

Uses:
	•	Vision framework
	•	ARKit face tracking (when available)

Calibration Screen

User must calibrate head movement sensitivity.

Interface shows:
	•	camera preview
	•	head detection box
	•	movement threshold slider
	•	page turn preview

All tracking must be processed on device only.

⸻

9. Device Linking UI

When linking devices, use a pairing interface similar to AirDrop.

Display devices as cards:

iPad Pro — Left Page
MacBook — Right Page

Users can choose layout orientation.

Once paired:
	•	page turns synchronize
	•	annotations sync
	•	playback sync optional

⸻

10. Animation Rules

Animations must be:

fast
subtle
predictable

Recommended timing:

150–250 ms
ease-in-out

Avoid:
	•	bouncing animations
	•	slow page curls
	•	exaggerated transitions

Performance must always take priority.

⸻

11. Icon System

Icons must follow a consistent style.

Rules:
	•	thin line icons
	•	monochrome
	•	simple geometry

Avoid colorful icons or emoji-like visuals.

⸻

12. Typography Rules

Primary UI font:

SF Pro

Hierarchy example:

Library Title: 34–40pt
Score Title: 24–28pt
Metadata: 13–15pt

Spacing must feel editorial and calm, not dense.

⸻

13. UI Customization

Users must be able to customize:
	•	page turn zones
	•	gestures
	•	annotation tool presets
	•	UI accent color
	•	reader display modes

Reader Background Options

Even though the UI may support dark themes, the score itself must remain light.

Reader options may include:

white paper
cream paper
sepia paper
high contrast paper

All variants must maintain light paper backgrounds.

⸻

14. The Most Important UI Rule

The interface must always feel like professional music software.

If the UI begins to resemble:
	•	Notes
	•	Notion
	•	Todo applications
	•	document editors

then the design direction is incorrect and must be revised.

This app should feel closer to:

Logic Pro
Final Cut Pro
Dorico
Ableton Live

than any productivity tool.

⸻

15. Implementation Directive

Claude Code should implement the UI using:
	•	modular environment-based architecture
	•	separate view models for each UI environment
	•	explicit transitions between environments
	•	strict separation between Reader and UI chrome

This architecture ensures the interface remains:
	•	uncluttered
	•	performance-focused
	•	reliable during live use
	•	visually premium
	•	scalable as features grow
:::
