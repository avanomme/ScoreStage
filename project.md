Mobile Sheet Music App — Project Outline for Claude Code

Working Title

Aurelia Score

A premium sheet music performance, practice, playback, and library-management app for iOS and macOS, combining:
	•	the polished professional reading workflow and library tools of forScore
	•	the performance and setlist power of MobileSheets
	•	the playback, notation-awareness, and score-following depth of MuseScore

This app is intended for commercial distribution and sale, with a high-end Apple-native user experience, deep score interaction, synchronized annotations, advanced page-turning options, and best-in-class playback for musicians, teachers, accompanists, conductors, pit musicians, church musicians, choirs, and students.

This App must be very well documented with a complete wiki created as we do inside docs/
Ensure to push after every Phase is completed

⸻

1. Product Vision

Goal

Build the best premium sheet music app on Apple platforms for serious musicians.

It must feel:
	•	fast
	•	elegant
	•	rock-solid in performance settings
	•	deeply musical rather than just document-based
	•	more modern and refined than current competitors

Core Promise

A musician can:
	•	import and organize scores
	•	annotate naturally with Apple Pencil / touch / mouse / trackpad
	•	perform from them reliably on stage
	•	build set lists and performance books
	•	sync across devices
	•	turn pages hands-free
	•	open two-page spreads locally or across linked devices
	•	use rich playback and practice tools from structured notation files
	•	work seamlessly on both iPhone/iPad and macOS

⸻

2. Platforms

Required Platforms
	•	iOS
	•	iPadOS
	•	macOS

Recommended Technical Direction

Use a shared native Swift codebase built around:
	•	SwiftUI for most interface work
	•	AppKit bridges where macOS-specific control is needed
	•	UIKit bridges where high-performance custom rendering is needed
	•	Core Data or SwiftData for metadata/local persistence
	•	CloudKit for sync
	•	PDFKit only where appropriate, but do not rely on it as the main high-end rendering engine if it becomes limiting
	•	custom rendering pipeline for annotations, page overlays, device linking, and performance mode

Why native Apple stack

Because this is a premium product and must have:
	•	buttery scrolling and zooming
	•	Pencil-quality ink latency
	•	strong accessibility and system integration
	•	excellent offline storage behavior
	•	pro-grade windowing and multi-device integration
	•	first-class distribution on App Store / Mac App Store

⸻

3. Target Users

Primary Users
	•	pianists and accompanists
	•	singers and vocal coaches
	•	choir directors
	•	conductors
	•	pit musicians
	•	church musicians
	•	music students
	•	teachers
	•	gigging musicians
	•	musical theatre staff

Secondary Users
	•	composers and arrangers
	•	rehearsal pianists
	•	chamber groups
	•	educators managing student libraries

⸻

4. Competitive Benchmark Targets

Must Match / Exceed forScore
	•	premium library browsing
	•	tags / metadata / collections
	•	annotation workflow
	•	bookmarks / links / jumps
	•	polished reading mode
	•	half-page turn / smart turn modes
	•	elegant UI and professional feel

Must Match / Exceed MobileSheets
	•	deep setlist creation
	•	large library handling
	•	performance workflow
	•	custom metadata fields
	•	linked scores / alternate versions
	•	external trigger support

Must Match / Exceed MuseScore Playback
	•	notation-aware playback
	•	tempo control
	•	looping
	•	metronome / count-in
	•	mixer-like control of staves/parts
	•	cursor / highlighted playback position
	•	transposition-aware playback where possible
	•	support for rich notation formats beyond plain PDF

⸻

5. Core Product Pillars

Pillar 1 — Performance Reading

The app must be the best possible live-performance score reader.

Pillar 2 — Musical Intelligence

The app must understand notation formats and use that knowledge for playback, navigation, rehearsal, and study.

Pillar 3 — Annotation Excellence

Markup must feel immediate, accurate, layered, and safely saved forever.

Pillar 4 — Device Ecosystem

The app must support syncing, linked devices, mirrored displays, and two-page/companion setups.

Pillar 5 — Premium UI/UX

The app must look expensive, modern, clean, and unmistakably pro.

⸻

6. File and Score Format Strategy

Document Formats to Support

Required
	•	PDF
	•	MusicXML / MXL

Strongly Recommended
	•	MEI
	•	MuseScore package support via import conversion path, not necessarily native .mscz editing

Optional / Nice-to-have
	•	images (PNG, JPG, TIFF)
	•	plain text or chord charts
	•	MIDI attachments linked to scores

Best Format Strategy

For fixed performance documents

Use PDF as the canonical display format for page-faithful reading.

For playback and notation intelligence

Use MusicXML as the primary structured notation format.

Why MusicXML should be the main structured format
	•	widely supported
	•	practical for interchange
	•	easier to parse and render than proprietary formats
	•	strong compatibility across notation tools
	•	supports playback-related semantics and notation structure

MEI Role

Support MEI as an advanced import option for future-proofing and research-grade notation support.

MuseScore File Strategy

Do not build the structured playback engine around raw .mscz as the primary internal format.

Instead:
	•	support .mscz / .mscx import through conversion to MusicXML plus asset extraction where feasible
	•	preserve the original file for re-import/rebuild if needed
	•	use internal normalized representation for rendering/playback

That avoids tying the product to a competitor’s internal package model.

⸻

7. Functional Feature Set

7.1 Library Management

Users must be able to:
	•	import files from Files, iCloud Drive, Finder, AirDrop, email, and share sheets
	•	bulk import entire folders
	•	auto-detect score metadata where possible
	•	edit title, composer, arranger, genre, key, instrumentation, difficulty, duration, notes, and custom tags
	•	assign categories, collections, playlists, set lists, and folders
	•	search by title, composer, tag, text, and custom metadata
	•	sort by recent, title, composer, composer surname, genre, duration, difficulty, last performed, and manual order
	•	mark favorites
	•	archive seldom-used files without losing metadata
	•	deduplicate imported scores
	•	attach multiple assets to a score (PDF, MusicXML, MIDI, audio rehearsal tracks, notes)

7.2 Score Viewing

The score reader must support:
	•	single-page view
	•	vertical scroll view
	•	horizontal paged view
	•	true two-page spread on large displays
	•	cropped margin mode
	•	safe performance mode with accidental-touch prevention
	•	landscape and portrait layouts
	•	quick jump to page / rehearsal mark / bookmark
	•	night mode / dark paper mode / sepia mode
	•	high-contrast mode
	•	smart zoom presets
	•	per-score viewing preferences

7.3 Annotation System

Annotations are mandatory and must be a flagship feature.

Annotation types
	•	freehand pen
	•	pencil-style writing
	•	highlighter
	•	eraser
	•	typed text
	•	text boxes with styling
	•	shapes (circle, rectangle, underline, arrow)
	•	stamps / symbols (breath mark, bowing, fingering, cue marker, cutoff, fermata reminder, etc.)
	•	image stickers
	•	color-coded rehearsal markings

Annotation behaviors
	•	annotations saved per document
	•	annotations optionally saved per layer / version
	•	support multiple annotation layers
	•	separate teacher / performer / rehearsal layers
	•	hide/show layers instantly
	•	undo/redo history
	•	autosave continuously
	•	version snapshots / restore points
	•	export annotated PDF
	•	flatten or preserve editable annotations on export
	•	sync annotations across devices

Apple Pencil / input requirements
	•	ultra-low-latency ink
	•	palm rejection
	•	pressure / tilt support if useful
	•	double-tap tool switching where applicable
	•	finger input toggle

7.4 Playback and Practice Tools

This is where the app must stand apart.

Playback features
	•	play from MusicXML / imported notation
	•	visual playhead / cursor through score
	•	staff highlighting / note highlighting
	•	tempo control
	•	loop region playback
	•	per-measure looping
	•	section looping by rehearsal mark
	•	count-in
	•	metronome overlay
	•	mute / solo staves
	•	volume balance by part
	•	instrument sound assignment by part
	•	transpose playback if notation model allows
	•	playback from arbitrary measure
	•	follow playback with auto-scroll or auto-page-turn

Practice features
	•	slow practice mode
	•	gradual tempo increase mode
	•	hands-separate / part isolate mode
	•	rehearsal marks navigation
	•	MIDI keyboard input comparison in future phases
	•	pitch-following / score-following expansion path

Audio engine direction

Use a modern audio/MIDI engine with:
	•	Core MIDI
	•	AVAudioEngine
	•	high-quality sample playback or built-in soundfont engine
	•	optional premium sound set later

7.5 Page Turning Options

This is a core professional requirement.

Manual turning
	•	tap zones
	•	swipe
	•	hardware keyboard / foot pedal shortcuts
	•	Apple Pencil gesture options

External trigger support
	•	Bluetooth page-turn pedals
	•	keyboard shortcuts
	•	MIDI trigger options for advanced users

Motion-based turning

User explicitly requested movement-based options, so these should be built in carefully.

Required experimental page-turn triggers
	•	head movement tracking
	•	eye gaze / gaze dwell page-turning
	•	configurable sensitivity and debounce
	•	preview/training mode
	•	left/right movement assignment
	•	accessibility-safe fallback handling

Likely implementation direction
	•	Vision framework
	•	ARKit / face tracking where supported
	•	front camera pose estimation
	•	strong privacy controls
	•	on-device processing only

Safety requirements
	•	no accidental page turns from casual movement
	•	rehearsal calibration screen
	•	confidence threshold tuning
	•	optional hold-to-confirm gaze method

7.6 Set Lists and Performance Books

Users must be able to:
	•	create set lists
	•	reorder scores with drag and drop
	•	create gigs / events / services / rehearsals
	•	link one score to the next in sequence
	•	add pause timers or spoken notes between items
	•	attach performance notes per set item
	•	auto-open next score
	•	create alternate setlist versions
	•	duplicate a setlist quickly
	•	share set lists between devices / users in future phases

7.7 Bookmarks, Links, and Navigation

Must support:
	•	bookmarks to pages
	•	jumps to coda / DS / DC / repeats via manual links
	•	tappable navigation hotspots
	•	index pages / table of contents
	•	links from one score to another
	•	links from score to audio or notes
	•	“return” behavior after jumps
	•	rehearsal marks panel
	•	movement / section markers

7.8 Syncing Between Devices

This is essential.

Sync requirements
	•	library metadata sync
	•	annotations sync
	•	set list sync
	•	preferences sync where appropriate
	•	bookmarks sync
	•	playback settings sync where appropriate

Cloud direction

Primary:
	•	CloudKit

Optional later:
	•	cross-platform account backend for non-Apple future expansion

Sync behavior
	•	offline first
	•	background sync when available
	•	conflict resolution for annotations and metadata edits
	•	explicit status indicators
	•	per-device download optimization

7.9 Linked Devices / Companion Display

User specifically wants two-page expansion with linked device.

Required linked-device modes
	•	extend one score across two devices
	•	left page on one device, right page on another
	•	conductor/performer mirrored mode
	•	primary/secondary controller mode
	•	page-turn sync between linked devices
	•	annotation visibility options per device
	•	portrait/landscape negotiation

Example use cases
	•	iPad + iPad for two-page spread
	•	iPad + Mac as score desk
	•	performer display + assistant/controller device

Connectivity options
	•	local network peer-to-peer
	•	Multipeer Connectivity
	•	optionally Cloud relay for remote sync state later

7.10 Cross-Device Continuity
	•	Handoff-like continuation between iPhone, iPad, and Mac
	•	pick up where you left off
	•	transfer active setlist session to another device
	•	sync current page and position

7.11 Part Extraction / Alternate Views
	•	attach full score and parts together as a score family
	•	switch between part and conductor score
	•	linked page references between versions
	•	alternate editions for same work
	•	capo/transposed display variants in future phases

7.12 Import / Export

Import
	•	Files app
	•	drag and drop
	•	Finder import on macOS
	•	AirDrop
	•	share extension
	•	iCloud Drive import
	•	Dropbox / Google Drive as file providers if available through Files

Export
	•	annotated PDF
	•	raw annotation data backup
	•	set list export/share
	•	metadata backup
	•	library backup bundle

⸻

8. Non-Functional Requirements

Performance
	•	instant page response for normal scores
	•	fast import of large libraries
	•	no visible lag when annotating
	•	smooth zoom and pan at 120Hz-capable hardware where possible
	•	pre-render adjacent pages for turns

Reliability
	•	no data loss on crash
	•	robust autosave
	•	journaling/version restore for annotations
	•	offline operation must remain excellent

Privacy
	•	all camera-based motion/eye features processed on-device
	•	clear privacy disclosures
	•	no unnecessary telemetry

Accessibility
	•	VoiceOver support
	•	large controls in performance mode
	•	high contrast
	•	switch control compatibility where possible
	•	configurable gesture/touch zones

Battery
	•	camera-based tracking should be optional and efficient
	•	background tasks minimized
	•	performance mode battery optimizations

⸻

9. UI / UX Direction

Design Language

The UI must feel:
	•	luxurious
	•	restrained
	•	modern Apple-native
	•	professional rather than gimmicky
	•	visually calm during performance

Visual style
	•	glass/subtle material effects used sparingly
	•	typography-forward layout
	•	smooth micro-interactions
	•	rich thumbnail browsing
	•	elegant iconography
	•	dark and light themes
	•	performance mode stripped of clutter

Key UX principles
	•	one-tap access to performance-critical actions
	•	everything else stays out of the way
	•	customization without chaos
	•	advanced features discoverable but not noisy
	•	no ugly enterprise-panel energy

Major screens
	•	Library Home
	•	Collections / Tags / Composers browser
	•	Score Detail page
	•	Reader / Performance view
	•	Annotation toolbar
	•	Setlist builder
	•	Playback / Mixer panel
	•	Device Link panel
	•	Sync status center
	•	Settings / Input / Page-turn calibration

⸻

10. Recommended Architecture

App Architecture
	•	modular feature-based architecture
	•	strong separation between rendering, score model, audio/playback, sync, and UI layers

Major modules
	1.	Library Module
	•	import
	•	metadata
	•	storage
	•	search
	2.	Reader Module
	•	page rendering
	•	zoom/pan
	•	display modes
	•	page turn state
	3.	Annotation Module
	•	strokes
	•	layers
	•	versioning
	•	export
	4.	Notation Module
	•	MusicXML parser
	•	MEI importer
	•	normalized score model
	•	rehearsal marks / measure indexing
	5.	Playback Module
	•	timing map
	•	MIDI/events
	•	metronome
	•	mixer
	•	cursor sync
	6.	Sync Module
	•	CloudKit sync
	•	conflict resolution
	•	device state sync
	7.	Link Module
	•	peer-to-peer device pairing
	•	linked page state
	•	two-device spread coordination
	8.	Input & Tracking Module
	•	Bluetooth pedal handling
	•	keyboard shortcuts
	•	head/eye tracking
	•	calibration
	9.	Setlist Module
	•	ordering
	•	performance sessions
	•	transitions
	10.	Monetization / Licensing Module

	•	purchases
	•	subscriptions if any
	•	trial gating

⸻

11. Data Model Overview

Core entities
	•	Score
	•	ScoreAsset
	•	AnnotationLayer
	•	AnnotationStroke
	•	AnnotationObject
	•	SetList
	•	SetListItem
	•	Bookmark
	•	JumpLink
	•	PlaybackProfile
	•	DeviceLinkSession
	•	UserPreference
	•	SyncRecord
	•	ScoreFamily
	•	RehearsalMark

Important relationships
	•	one Score can have many ScoreAssets
	•	one Score can have many AnnotationLayers
	•	one SetList has ordered SetListItems
	•	one Score may belong to a ScoreFamily
	•	one Score may have one structured notation model and one display PDF

⸻

12. Rendering Strategy

PDF rendering
	•	efficient tiled rendering
	•	page cache
	•	prefetch adjacent pages
	•	annotation overlay compositing

Structured notation rendering

There are two possible directions:

Option A — Import structured notation, render to internal display model

Pros:
	•	complete control
	•	strong playback integration
	•	future editing potential

Cons:
	•	much more engineering effort

Option B — Use a notation rendering engine or web-based engraving layer wrapped natively

Pros:
	•	faster time to market
	•	MEI/MusicXML support possible through existing engines

Cons:
	•	integration complexity
	•	may feel less native if done lazily

Best recommendation

Use a hybrid strategy:
	•	PDF remains the main performance display asset
	•	MusicXML/MEI power playback, navigation, and structured features
	•	where structured rendering is needed, use a mature engraving engine behind a native shell, then optimize later

⸻

13. Suggested External Technology Choices

Best-fit engraving/rendering candidate

Investigate Verovio for:
	•	MEI rendering
	•	MusicXML conversion compatibility routes
	•	notation-aware page and timing logic

Why this is interesting
	•	open-source
	•	modern engraving ecosystem presence
	•	good fit for structured notation exploration

Playback support direction
	•	build native playback engine from parsed notation events
	•	do not depend entirely on web playback frameworks

PDF / annotation layer
	•	custom overlay engine over rendered pages

⸻

14. Phased Delivery Plan

Phase 1 — Premium PDF Reader MVP

Goal: ship a beautiful, reliable premium sheet music reader.

Features
	•	library import and metadata
	•	PDF reading
	•	set lists
	•	bookmarks
	•	annotation basics
	•	CloudKit sync basics
	•	Bluetooth pedal turns
	•	premium performance mode

Phase 2 — Advanced Annotation + Device Sync

Features
	•	annotation layers
	•	export options
	•	improved sync/conflict handling
	•	linked devices
	•	mirrored sessions
	•	two-device spread

Phase 3 — Structured Notation Playback

Features
	•	MusicXML import
	•	structured measure map
	•	playback engine
	•	looping / tempo / mixer / cursor
	•	rehearsal marks and playback navigation

Phase 4 — Motion / Head / Eye Page Turning

Features
	•	calibration
	•	on-device tracking
	•	confidence controls
	•	accessibility and performance tuning

Phase 5 — Advanced Musical Intelligence

Features
	•	jump logic
	•	score family linking
	•	score-following research path
	•	MIDI practice tools
	•	future smart accompanist features

Phase 6 — Commercial Polish

Features
	•	onboarding
	•	trial/paywall
	•	in-app purchase/subscription strategy
	•	analytics with privacy respect
	•	App Store optimization
	•	customer support / backup / migration tools

⸻

15. Monetization Strategy

Options

Option A — Premium one-time purchase

Good for pro-market trust.

Option B — Free tier + Pro unlock

Likely strongest adoption path.

Option C — Subscription for sync/cloud/advanced features

Viable but users often hate this unless handled carefully.

Recommended monetization
	•	paid app or free with generous trial
	•	optional Pro unlock
	•	optional cloud-plus tier only if absolutely necessary

Do not nickel-and-dime basic musician workflows or people will roast it into the ground.

⸻

16. Risks and Challenges

Technical Risks
	•	high-quality structured notation playback is non-trivial
	•	CloudKit conflict handling for annotations is tricky
	•	camera-based eye/head turning must be robust enough not to be a joke
	•	linked-device low-latency state sync needs careful engineering
	•	PDF + overlay performance must remain excellent for large libraries

Product Risks
	•	trying to build notation editing too early
	•	overstuffing UI with power features
	•	poor import reliability from real-world messy files
	•	subscription backlash

Strategic Risks
	•	copying competitors too literally instead of surpassing them with a cohesive design

⸻

17. Recommended MVP Definition

Absolute MVP
	•	beautiful PDF library and score reader
	•	annotation system
	•	set lists
	•	bookmarks and navigation links
	•	pedal page turning
	•	CloudKit sync
	•	iPad + macOS support
	•	polished commercial UI

MVP+1
	•	linked-device two-page spread
	•	advanced annotation layers
	•	rehearsal workflow improvements

MVP+2
	•	MusicXML playback engine
	•	looping / tempo / mixer / highlighted playback

⸻

18. Product Differentiators

This product should win on:
	•	best visual design in the category
	•	best annotation experience on Apple devices
	•	best multi-device score experience
	•	best combination of fixed-sheet reading and intelligent playback
	•	serious performance features without clunky UI

⸻

19. Claude Code Build Instructions

High-Level Mandate

Claude Code should treat this as a premium commercial app, not a hackathon prototype.

Every design and engineering decision should optimize for:
	•	stability
	•	responsiveness
	•	extensibility
	•	clean architecture
	•	beautiful UI
	•	App Store readiness

Engineering standards
	•	modular architecture
	•	testable core logic
	•	protocol-driven service boundaries where useful
	•	clear domain models
	•	no giant god objects
	•	no fragile one-off parsing logic scattered everywhere
	•	benchmark rendering and annotation latency early

UI standards
	•	native-feeling SwiftUI-first interface
	•	custom components where stock controls feel cheap
	•	rich gestures but with explicit discoverability
	•	premium empty states and onboarding
	•	zero visual clutter in reader mode

Product standards
	•	assume musicians will trust this live on stage
	•	assume users will own thousands of scores
	•	assume annotations are mission-critical and cannot be lost
	•	assume playback timing and page turns must be dependable

⸻

20. Suggested Initial Repository Structure

AureliaScore/
  Apps/
    iOS/
    macOS/
  Packages/
    CoreDomain/
    LibraryFeature/
    ReaderFeature/
    AnnotationFeature/
    PlaybackFeature/
    NotationFeature/
    SyncFeature/
    DeviceLinkFeature/
    SetlistFeature/
    InputTrackingFeature/
    DesignSystem/
  Resources/
    SampleScores/
    Soundfonts/
  Docs/
    product/
    architecture/
    UX/
    parsing/
    sync/
  Scripts/
  Tests/


⸻

21. Stretch Goals
	•	score-following with microphone or MIDI input
	•	AI-assisted repeat/jump detection from PDFs
	•	automatic metadata extraction from title pages
	•	collaborative annotation sharing
	•	conductor broadcast mode for ensembles
	•	Apple Watch page-turn companion
	•	external display performance mode
	•	practice analytics
	•	built-in scanner / camera import cleanup

⸻

22. Final Product Statement

Build a premium Apple-native sheet music ecosystem that merges the best performance reading, annotation, setlist management, synchronization, linked-display workflow, and notation-aware playback into one polished commercial product.

The app should not feel like a PDF viewer with music features taped on.
It should feel like it was designed from the ground up by people who actually perform.

That is the whole game.