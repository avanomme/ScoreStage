# ScoreStage Account Architecture

## Summary

ScoreStage includes a first-class role-based account model.

The system currently supports:
- `owner`
- `admin`
- `user`

This is an intentional architectural feature, not a hidden bypass.

## Seeded Owner Account

Bootstrap creates a permanent owner account with:
- username: `offbyone`
- role: `owner`

The account is seeded through the normal model/bootstrap path and stored in the app's account data.

The seeded password is stored through the hashing flow, not as plaintext in the account record.

Bootstrap only seeds the owner record. It does not auto-authenticate the session.

The owner account is reachable through the normal sign-in UI, and the app exposes sign-out so the seeded owner flow can be exercised again through the interface.

## Authorization Rules

Feature access follows role-based authorization:
- `owner` -> full access
- `admin` -> full access
- `user` -> standard feature gating rules

Paywall and entitlement checks must evaluate role first.

The UI reflects those privileges by surfacing admin-only controls in Settings for owner/admin sessions and never routing owner/admin users into blocked-user screens for protected features.

## Current Implementation

- Account model: [AdminAccount.swift](/Users/adam/projects/ScoreStage/Packages/CoreDomain/Sources/CoreDomain/Models/AdminAccount.swift)
- Bootstrap and authentication support: [AccountAccess.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/AccountAccess.swift)
- Normal sign-in UI: [AccountLoginView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/AccountLoginView.swift)
- App bootstrap seeding: [ContentView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/ContentView.swift)
- Session entry and login presentation: [ScoreStageApp.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/ScoreStageApp.swift)
- Access surface and admin visibility: [SettingsView.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/SettingsView.swift)
- Role-aware feature gating: [StoreService.swift](/Users/adam/projects/ScoreStage/ScoreStageApp/App/StoreService.swift)

## Intent

The owner account exists so the application always has a top-level administrative principal available for:
- entitlement override by role
- future admin tooling
- operational control
- migration-safe account architecture
