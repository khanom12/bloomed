# Bloomed — implementation and validation notes

## Walkthrough improvements — version 0.2.0 (3)

**Date:** October 25, 2026
**Scope:** Implement the owner’s walkthrough review in the existing native app, test it, and commit/push. PRD and UX specification v0.2 describe the resulting behavior. These changes do not add payments, health imports, live supporter access, or independent verification.

### What changed

- First-use Today explains walking goals, the participant’s own money, charity, and outside money handling. Established-plan screens prioritize status and next actions instead of repeated marketing headings.
- Setup now asks for everyday goal, weekly amount/arrangement, optional higher goal, optional consistency, then dates/review. Exact evaluator-derived amounts and the higher-goal tradeoff are visible before confirmation. The any-five-days condition uses the everyday goal, not the higher one.
- Charity naming can be deferred. A positive charity result cannot be reviewed until a destination is recorded; a zero-charity result can. A later choice is one immutable, audited record, leaving the original plan terms and financial calculations untouched. Cancelling an upcoming plan retains any choice recorded before cancellation.
- Draft typing changes are coalesced for 350 milliseconds. Continue, Back, Save & close, dismissal, and inactive/background transitions flush valid draft context. Confirm/discard cancel pending work. A short monotonic guard prevents repeated Continue activation from skipping a choice. Previously saved setup steps migrate to the corresponding stage or first missing prerequisite without losing input.
- Draft-only persistence no longer revalidates every confirmed historical record on each text change. It still atomically saves a compact full snapshot after a pause or explicit flush. Confirmed mutations and restore retain full graph validation. This reduces work while typing; it is not proof that all physical-device latency has been eliminated.
- Support has separate invitation and already-agreed-recording paths. Invitation and reviewed-summary entry points select their actual export type. Limits above the personal commitment show the real one-to-one maximum, rather than implying a larger multiplier.
- Invitations address the recipient’s request and next conversation. Progress and reviewed exports have distinct content, grouped readable text, accurate upcoming/missing states, timestamps, and manual/static/outside-money disclosures. Private motivation, handler details, notes, and unrelated weeks remain excluded.
- Progress has Week/Month views, a native selectable calendar, distinct date states, and walking-specific historical detail. Original targets stay attached to their dates. Calendar dates with more than one saved plan timezone retain all records instead of overwriting one.
- Money distinguishes estimates, reviewed outcomes, and the participant’s outside records. Upcoming plans show readiness rather than zero earnings; reviewed totals appear only once there is reviewed history. A missing outside record is not described as proof of nonpayment.
- Date choices stack at accessibility sizes. Field labels, chart alternatives, internal chevrons, notices, and keyboard handling follow the existing native design and green palette.

### Financial and data integrity

The `bloomed.walk.v1` formulas, integer-cent allocation, 20% consistency reserve, 25% everyday-only return with a higher goal, exact dated remainders, and one-to-one capped matching are unchanged. All 28 authored numerical fixtures still pass. Adding a higher goal remains a financial tradeoff and is now explained explicitly.

Optional additive destination/setup-version fields let this version decode previous schema-v1 installations and backups. Destination ownership, unique plan/transaction, timing, and positive-reviewed-allocation requirements are validated during restore. New draft identities cannot collide with existing durable records. Original financial terms, reviews, outside records, and audit history remain preserved. Restoring a newer backup into an older build is not supported.

### Verification performed

Xcode 26.3; iPhone 17 Pro simulator on iOS 26.2.

- Full regression run: **72 tests passed, 0 failures, 0 skipped**. This included 64 unit tests and 8 UI tests. The MCP wrapper reached its 300-second response limit; the completed `.xcresult` independently reports Passed with all 72 tests. This is a verified result, not an inferred pass from partial output.
- Follow-up after the direct agreement route and actual export rendering were added: **66 tests passed, 0 failures/skips** (all 65 unit tests plus the new direct-route UI test).
- Final run after the date-layout and wording corrections: **67 tests passed, 0 failures/skips** (all 65 unit tests plus standard-size and actual largest-accessibility-text/dark setup → entry → update flows). No warnings or errors were reported for this run.
- Across these runs, **74 unique automated tests** passed: 65 unit tests and 9 UI journeys. The unit suite includes financial fixtures, calendar/DST, backup compatibility, correction/reconciliation, failed saves, draft migration, deferred charity, snapshot privacy, and actual export rendering. This does not mean every item in the 100-scenario acceptance checklist was separately automated or manually completed.
- UI journeys cover purposeful empty tabs; higher-goal validation and exact consistency amounts; correct invitation mode without activating support; largest-text dark setup and entry; Week/Month/history routing; rapid Continue activation; shared draft resume; single-goal setup/entry/money/replacement; and direct recording of an already-agreed match.
- The actual production share card was rendered at 390 points, scale 3, in fixed light/large export style for invitation, progress, and reviewed output. All three images rendered successfully with long synthetic public labels; image attachments were inspected for wrapping and clipping. Readable text remains available.
- Screenshots of first-use/active Today, Money estimates, higher-goal setup, monthly calendar, historical walking, invitation preview, actual exports, and the corrected largest-text date layout were inspected. Native dates and amounts remain readable; the actual preferred-content-size launch setting covers sheets as well as tabs.
- An early UI run found an ambiguous test selector for multiple Done buttons in nested sheets. The selector was scoped to the preview navigation bar; the complete rerun passed. This is not left as a product failure.
- Swift parsing, whitespace checks, internal specification links, all 100 acceptance IDs, and unchanged numerical-fixture files were checked. The project generator and Xcode project both identify version 0.2.0, build 3.

The signed arm64 iPhone Debug build succeeded and passed strict code-signature verification using host signing trust. The build emitted only the platform’s App Intents metadata-extraction notice because this app has no AppIntents dependency. Version **0.2.0 (3)** was installed in place on the owner’s intended iPhone Air with the existing bundle identity, then launched successfully. Device app metadata independently confirmed the installed version/build. No uninstall, local-data deletion, production sample seeding, or test-mode launch was performed on that phone.

### Remaining review boundaries

Physical-device VoiceOver reading order, compact-width hardware, sharing through the owner’s chosen recipient apps, and sustained device performance profiling remain manual review work. Simulator success and semantic labels do not certify those experiences. The reduction in typing-related saves is implemented and regression-tested; no measured physical-device latency claim is made. There was no new independent-user comprehension study or evidence of improved conversion/retention.

The monthly calendar is included. Botanical progress artwork, custom consistency rules, PDF export, a different return curve, and integrations remain separate future product choices. Distribution, brand clearance, and commercial launch are unchanged in scope.

---

## Bloomed — first implementation notes

**Date:** October 24, 2026

**Version:** 0.1.0 (2)

**Scope:** Native iPhone draft for owner testing against PRD v0.1.

### What is implemented

The four-tab participant experience includes guided saved drafts, explicit weekly confirmation, single/base-stretch goals, optional five-of-seven consistency, manual step totals, corrections, weekly review, optional whole-week matching, standing external agreements, continuation, historical walking targets, financial reconciliation, static sharing, backup/restore, deletion, and storage recovery.

A participant confirms each week. No recurring charge, automatic plan obligation, supporter authentication, health connection, independent verification, or actual payment/donation is performed. Production launches contain no fabricated activity or financial history.

### Deliberate implementation choices

- **Persistence adapter:** A validated Codable graph is atomically saved to Application Support, with iOS file protection until first unlock. This replaces the specification's suggested SwiftData adapter while preserving its required transaction and history semantics. A complete mutation is saved before publication; save/load failure never silently becomes a new empty history. Backups use a versioned envelope and the same graph validation.
- **Boundaries:** All model evaluation and date rules are Foundation-only. SwiftUI reads the same evaluator as assessments and exports. Money uses integer cents; display formatting does not calculate rewards.
- **History:** Walking/support changes retain revisions. A reviewed correction requires another review; signed ledger differences are posted then. Original outside settlements survive and excess/outstanding amounts remain distinct.
- **Time:** Each confirmed week keeps its seven Gregorian dates and timezone. Foreground, significant-time-change and pinned-midnight refresh keep displays current; entry saves independently reject stale/future date assumptions.
- **Local privacy:** No network client, analytics SDK, accounts, contacts permission, or health permission is included. iOS/device backups may include local app data. Exported backups are complete, unencrypted JSON records. Snapshot content excludes private motivation, handler details, notes, and unrelated weeks.
- **Support history:** An inapplicable corrected agreement remains inspectable. Ending or pausing standing support affects future reuse and does not erase a confirmed week's support snapshot.
- **Project:** Dependency-free Xcode project with synchronized source folders, reproducible generator, shared scheme, and separate unit/UI test targets. The initial working icon has been replaced by the owner-requested Open loop identity, documented in `Brand/v1/README.md`. Production assets are reproducible vectors with an outlined licensed wordmark; interface text retains the system font.

### Validation record

The initial functional baseline (build 1) passed **46 tests, zero failures or skips**, on the iPhone 17 Pro simulator running iOS 26.2 with Xcode 26.3. This includes 43 domain/store/sharing tests and 3 UI tests. The run reported no build warnings or errors. Earlier runs found and corrected onboarding scrolling/keyboard issues; those failures are not counted as passes.

After the final layout adjustments, the complete single-goal setup → entry → money → replacement-entry UI flow also passed in **dark mode at the largest accessibility text size**. This checks actual interaction, not only text scaling. The test driver scrolls controls into the visible form viewport and avoids native date controls while dragging.

The final normal-size/light-appearance UI rerun passed **all 3 UI tests**, with no warnings or errors.

A signed arm64 iPhone Debug build also succeeded, and its code signature passed strict verification. Version 0.1.0 (1) was successfully installed on the owner’s intended iPhone Air. After the phone was unlocked, the app launched successfully through the device tools. Device installation records confirm version 0.1.0 (1), with the independent bundle identifier `com.khanom12.bloomed`. No other connected device was used as a substitute.

The automated suite covers all 28 authored fixture cases, financial conservation/rounding, bounds, missing versus zero, DST and timezone boundaries, unchanged-term recurrence, settlement corrections, duplicate operations, failed writes, validated backup restoration, and snapshot privacy. UI integration covers the empty four-tab shell, stretch validation, and setup → confirmation → saved walking total → money.

### Review boundaries

This is a first device-testing draft, not a commercial release. The acceptance suite includes broader manual checks that should continue on the owner's real device, particularly VoiceOver reading order, the largest accessibility sizes, keyboard/sheet behavior on small phones, backup round trips through Files, and sharing through chosen destination apps. Automated checks do not certify those manual experiences.

The initial defaults remain those in PRD v0.1: CAD, limits, exact allocations, whole-week support coverage, and external exception handling. Product-policy review, brand clearance, pricing, deployment/distribution planning, payments, and live supporter access remain separate work.


### Open loop identity integration — build 2

The owner requested a simple logo and matching reusable assets, then explicitly requested natural integration and a commit/push. The brand kit is in `Brand/v1/`: outlined SVGs, vector PDFs, transparent PNGs, a review sheet, licensed type source, and a reproducible Core Graphics/Core Text generator. The app consumes template PDFs for the Today identity, walking/progress empty states, Settings About, and shared summaries. The app icon uses the same mark on moss. Support-pair artwork is included for future use.

Validation for this change: all **3 existing UI tests passed**; the four-tab empty-state check also passed in **dark mode at the largest accessibility text size**. Both runs reported no build warnings or errors. Light/dark Today and Progress screens and the static share preview were visually inspected. The sharing image renderer successfully prepared the system share sheet. The 11 SVG exports parse as self-contained paths, five template PDF asset sets resolve, and the app icon is opaque RGB at 1024×1024. No new financial or persistence behavior was introduced.

The shared card uses an explicit, fixed export text size for matching preview/render layout while the readable text version and normal interface keep Dynamic Type. Native prominent buttons use the theme's contrasting foreground color in dark mode. Settings shows the actual bundle version and build.

The branded build 2 was signed, passed strict code-signature verification, and was installed and launched on the owner’s iPhone Air. Device records confirm version 0.1.0 (2).
