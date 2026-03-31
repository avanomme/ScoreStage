# ScoreStage Release Validation Checklist

This checklist tracks the post-parity closure work that still needs explicit validation before ScoreStage should be called production-ready.

## Release Blockers

| Area | Closure Needed | Evidence |
|---|---|---|
| Reader end-to-end QA on real devices | Long-session reading, interruptions, resume, and imported-scan behavior on actual tablets | Device session notes and issue log |
| Linked-device reliability soak testing | Pair, reconnect, drift, role switching, spread mode, mirrored mode | Multi-device test matrix and defect log |
| Cloud/backups under failure conditions | Conflict handling, rollback, partial imports, migration restore | Backup/restore destructive-path checklist |
| Store/access policy validation | Confirm owner/admin/user feature behavior matches policy and UI entry points | Feature-gate audit from admin console plus manual walkthrough |

## Claimed Features Needing Explicit Closure

| Feature | Closure Needed | Evidence |
|---|---|---|
| Head tracking page turns | Reader integration, permissions review, supported-device behavior | Device test notes |
| Eye gaze page turns | Accessibility interaction review and supported-device behavior | Device test notes |
| Score following from microphone | Real user workflow, permissions behavior, reliability | Rehearsal workflow validation |
| MIDI practice / score-following workflow | Final practice UI pass and mapping clarity | Product walkthrough and regression notes |
| Handoff / cross-device continuation | Entry/restore surfaces and continuity QA | Continuity test cases |
| Score family / part relationships | Confirm complete part-management workflow is exposed in UI | Workflow checklist |

## Hardening / Ops

| Work Item | Closure Needed | Evidence |
|---|---|---|
| Accessibility sweep | VoiceOver labels, keyboard navigation, contrast, dynamic type across app surfaces | Accessibility review log |
| Crash/edge-case regression suite | Coverage for restore, linked sessions, exports, set transitions | Test additions and pass logs |
| Offline-first review | Import, reading, backup, playback, and sync failure behavior | Offline walkthrough notes |
| Performance profiling | Large libraries, scanned PDFs, memory pressure, long sessions | Instruments captures |
| Support/recovery documentation | Backup, restore, pairing, imports, pedals | Published help content |

## Admin Console Support

The app now includes a dedicated admin console in Settings for:
- session and owner-account visibility
- feature-gate audits by role
- sync and backup status inspection
- release-validation tracking and operational actions

Primary implementation:
- [AdminConsoleView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/AdminConsoleView.swift)
- [SettingsView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/SettingsView.swift)
