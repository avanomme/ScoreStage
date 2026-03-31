# ScoreStage Post-Parity Backlog

Work that still needs explicit closure after the 7 parity sprints are complete.

This backlog exists so "sprint complete" does not become "ship complete" by accident.

## Status Key

- `verify`: feature exists in code but needs end-to-end validation, UI exposure review, or production hardening
- `finish`: partial implementation exists but user-facing completion is still missing
- `package`: implementation may be adequate, but release/admin/commercial work is still needed

## Release Blockers

These items should be closed before calling the app production-ready.

| Area | Status | Why It Still Matters |
|---|---|---|
| Reader end-to-end QA on real devices | `verify` | The reader is the core product surface; it needs multi-device, long-session, and interruption testing under real usage conditions |
| Linked-device reliability soak testing | `verify` | Pairing, reconnect, page sync drift, role switching, and two-screen spread need repeated device testing, not just build success |
| StoreKit production validation | `verify` | Product loading, restore, renewal state, offline behavior, and paywall edge cases still need StoreKit test coverage and release validation |
| Cloud/backups under failure conditions | `verify` | Sync conflicts, restore rollback, partial imports, and migration safety need destructive-path testing |
| App Store submission package | `package` | Screenshots, feature copy, privacy answers, review notes, support URLs, and final pricing setup are separate deliverables |

## Claimed Features Needing Explicit Closure

These are the highest-risk gaps because the app copy or platform permissions imply they are part of the product experience.

| Feature | Status | Notes |
|---|---|---|
| Head tracking page turns | `verify` | Services and calibration UI exist in `InputTrackingFeature`, but this needs reader integration validation, permission handling review, and device support testing |
| Eye gaze page turns | `verify` | Same risk profile as head tracking, plus stronger accessibility conflict testing |
| Score following from microphone | `verify` | `ScoreFollowingService` exists, but the real user workflow, reliability, and permissions behavior still need a product-level pass |
| MIDI practice / score-following workflow | `finish` | MIDI input and routing exist, but practice UX and score-following clarity still need final product shaping |
| Handoff / cross-device continuation | `finish` | `HandoffService` exists, but user-facing entry/restore surfaces and QA are still needed before it should be treated as shipped |
| Score family / part relationships | `finish` | Planned in historical scope docs; needs confirmation that the actual product workflow is complete and exposed |

## Product Hardening Backlog

| Work Item | Status | Notes |
|---|---|---|
| Accessibility sweep beyond reader page actions | `finish` | Full VoiceOver labels, keyboard navigation, dynamic type, and contrast review across library, setlists, onboarding, and settings |
| Crash/edge-case regression suite expansion | `finish` | Add tests around restore conflicts, linked-session mode changes, annotation exports, and setlist transitions |
| Purchase/feature gating audit | `verify` | Every Pro feature gate should be validated against the actual UI entry points so free/pro boundaries are coherent |
| Offline-first behavior review | `verify` | Import, reading, annotations, playback, backups, and sync surfaces should degrade cleanly without network or StoreKit availability |
| Settings/admin surfaces for internal ops | `finish` | Dedicated admin console now exists in-app; remaining work is using it to close the rest of the backlog with real validation evidence |
| Performance profiling | `verify` | Large libraries, scanned PDFs, memory pressure, and long rehearsal sessions need Instruments-based review |

## Commercial / Operations Backlog

| Work Item | Status | Notes |
|---|---|---|
| Final App Store copy alignment | `finish` | Ensure marketing claims only mention features that pass release validation |
| Privacy/legal link review | `finish` | Make sure support, privacy policy, and terms URLs are final and live |
| Analytics event audit | `verify` | Confirm events match business questions and respect the app's privacy posture |
| Support/recovery documentation | `package` | Backup restore, linked-device setup, pedals, and imports need user-facing help content |
| Beta checklist / TestFlight protocol | `package` | Define scenarios, supported hardware, and bug triage for pre-release musician testing |

## Recommended Execution Order

1. Close the release blockers.
2. Validate claimed features against real user flows.
3. Run the product-hardening backlog.
4. Finalize the commercial/operations package.

## Command Contract

If we want the same workflow as the parity sprints, the next command should operate against this backlog rather than the old sprint list.

Suggested command:

`Complete next backlog item`
