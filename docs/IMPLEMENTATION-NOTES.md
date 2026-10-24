# Bloomed — first implementation notes

**Date:** October 24, 2026

**Version:** 0.1.0 (1)

**Scope:** Native iPhone draft for owner testing against PRD v0.1.

## What is implemented

The four-tab participant experience includes guided saved drafts, explicit weekly confirmation, single/base-stretch goals, optional five-of-seven consistency, manual step totals, corrections, weekly review, optional whole-week matching, standing external agreements, continuation, historical walking targets, financial reconciliation, static sharing, backup/restore, deletion, and storage recovery.

A participant confirms each week. No recurring charge, automatic plan obligation, supporter authentication, health connection, independent verification, or actual payment/donation is performed. Production launches contain no fabricated activity or financial history.

## Deliberate implementation choices

- **Persistence adapter:** A validated Codable graph is atomically saved to Application Support, with iOS file protection until first unlock. This replaces the specification's suggested SwiftData adapter while preserving its required transaction and history semantics. A complete mutation is saved before publication; save/load failure never silently becomes a new empty history. Backups use a versioned envelope and the same graph validation.
- **Boundaries:** All model evaluation and date rules are Foundation-only. SwiftUI reads the same evaluator as assessments and exports. Money uses integer cents; display formatting does not calculate rewards.
- **History:** Walking/support changes retain revisions. A reviewed correction requires another review; signed ledger differences are posted then. Original outside settlements survive and excess/outstanding amounts remain distinct.
- **Time:** Each confirmed week keeps its seven Gregorian dates and timezone. Foreground, significant-time-change and pinned-midnight refresh keep displays current; entry saves independently reject stale/future date assumptions.
- **Local privacy:** No network client, analytics SDK, accounts, contacts permission, or health permission is included. iOS/device backups may include local app data. Exported backups are complete, unencrypted JSON records. Snapshot content excludes private motivation, handler details, notes, and unrelated weeks.
- **Support history:** An inapplicable corrected agreement remains inspectable. Ending or pausing standing support affects future reuse and does not erase a confirmed week's support snapshot.
- **Project:** Dependency-free Xcode project with synchronized source folders, reproducible generator, shared scheme, and separate unit/UI test targets. The icon is an original generated draft, not a final approved brand identity.

## Validation record

The complete integrated suite passed **46 tests, zero failures or skips**, on the iPhone 17 Pro simulator running iOS 26.2 with Xcode 26.3. This includes 43 domain/store/sharing tests and 3 UI tests. The run reported no build warnings or errors. Earlier runs found and corrected onboarding scrolling/keyboard issues; those failures are not counted as passes.

After the final layout adjustments, the complete single-goal setup → entry → money → replacement-entry UI flow also passed in **dark mode at the largest accessibility text size**. This checks actual interaction, not only text scaling. The test driver scrolls controls into the visible form viewport and avoids native date controls while dragging.

The final normal-size/light-appearance UI rerun passed **all 3 UI tests**, with no warnings or errors.

A signed arm64 iPhone Debug build also succeeded, and its code signature passed strict verification. Version 0.1.0 (1) was successfully installed on the owner’s intended iPhone Air. After the phone was unlocked, the app launched successfully through the device tools. Device installation records confirm version 0.1.0 (1), with the independent bundle identifier `com.khanom12.bloomed`. No other connected device was used as a substitute.

The automated suite covers all 28 authored fixture cases, financial conservation/rounding, bounds, missing versus zero, DST and timezone boundaries, unchanged-term recurrence, settlement corrections, duplicate operations, failed writes, validated backup restoration, and snapshot privacy. UI integration covers the empty four-tab shell, stretch validation, and setup → confirmation → saved walking total → money.

## Review boundaries

This is a first device-testing draft, not a commercial release. The acceptance suite includes broader manual checks that should continue on the owner's real device, particularly VoiceOver reading order, the largest accessibility sizes, keyboard/sheet behavior on small phones, backup round trips through Files, and sharing through chosen destination apps. Automated checks do not certify those manual experiences.

The initial defaults remain those in PRD v0.1: CAD, limits, exact allocations, whole-week support coverage, and external exception handling. Product-policy review, brand clearance, pricing, deployment/distribution planning, payments, and live supporter access remain separate work.
