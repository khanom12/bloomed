# Bloomed

A native iPhone app for a walking commitment, one week at a time.

Choose a daily step goal and an amount of your own money for seven days. Record your steps to earn it back; the rest is for charity after review. Optionally add a higher goal, consistency amount, or a supporter match.

**Version 0.2.0 (3) — walkthrough improvements for owner review.** Bloomed calculates and records arrangements. It does not hold money, transfer funds, execute donations, or independently verify walking or payments.

## Open the app project

The canonical checkout on the owner's Mac is `~/Projects/Bloomed`. Keep the source, specification, and Xcode project together here; do not create another copy when opening Xcode. The previous documentation folder redirects to this checkout through a symlink.

```sh
cd ~/Projects/Bloomed
open Bloomed.xcodeproj
```

Select the **Bloomed** scheme and an iPhone simulator, then Run. The deployment target is iOS 17.0. This draft is built with Xcode 26.3 and has no third-party packages or service credentials.

For a connected iPhone, select the device in Xcode and use your development team under Signing & Capabilities. The project uses automatic signing and bundle identifier `com.khanom12.bloomed`.

## The app

- **Today:** manually enter or correct a total, see the next step target and daily return, and inspect the seven-day record.
- **My plan:** everyday goal → weekly amount → optional higher goal → optional consistency → review. Exact amounts and the higher-goal tradeoff are explained before confirmation. Saved drafts, including drafts from the previous order, resume without losing input.
- **Progress:** weekly walking charts, a monthly calendar, recorded-day averages, and dedicated historical walking details with the goals that applied then. Upcoming, missing, zero/below-goal, and goal-reached dates stay distinct.
- **Money:** separate own-money estimates/reviewed amounts, additional supporter matches, money for charity, user-recorded payments/donations, and correction history. Upcoming plans show readiness rather than zero earnings.
- **Support and sharing:** separate inviting someone from recording an outside agreement. Preview a recipient-oriented invitation, progress snapshot, or reviewed summary in image and readable text before using the system share sheet. Private motivation, handling details, and notes are excluded.
- **Recovery:** local persistence, validated JSON backups, replacement restore with confirmation, and explicit recovery if saved records cannot be opened.

There is no login or cloud service. Supporter agreements are entered by the participant after an outside conversation; a snapshot does not give someone live access. Device backups may include local app data according to iOS settings. Exported backup files contain the complete history and are not encrypted by Bloomed.

The app opens empty. UI tests use an isolated in-memory repository and do not seed ordinary app launches.

## Brand assets

The [Open loop identity kit](Brand/v1/README.md) contains the logo, icon, and companion artwork in SVG, PDF, and PNG, plus an overview sheet and licensed type source. The app uses lightweight template PDF vectors that follow its existing light/dark colors. Regenerate production artwork with `swift scripts/GenerateBrand.swift`.

## Rules implemented

The detailed baseline is [the current PRD](docs/PRD.md). Its proposed defaults are used consistently: CAD, seven pinned local dates, a positive personal commitment, optional stretch, optional consistency on any five dates, and one optional 1:1 weekly match.

All monetary calculations use integer cents. The personal commitment is split across daily opportunities and, when selected, a consistency reserve. Meeting the highest goal on all seven dates returns the full commitment. The charity destination can be chosen during setup or later. A positive amount for charity requires a destination before review can be confirmed; choosing it later creates a separate audited record and does not rewrite the original plan. Unreturned personal commitment becomes an amount for charity after review; unused supporter allowance stays with the supporter. Corrections retain the earlier assessment and outside records, then post only the difference upon another review.

Goals, limits, allocations, and the initial visual identity remain product defaults for evaluation. They are not claims of a final commercial policy or cleared brand.

## Project structure

| Location | Responsibility |
|---|---|
| `Bloomed/Domain` | Pure models, reward evaluation, date boundaries, graph validation |
| `Bloomed/Storage` | Observable app store and atomic local repository |
| `Bloomed/Features` | Participant screens and system sharing/recovery flows |
| `Bloomed/DesignSystem` | Adaptive colors, type, reusable cards and controls |
| `Bloomed/Services` | Privacy-controlled snapshot content |
| `BloomedTests` | Numerical, lifecycle, correction, persistence, and sharing tests |
| `BloomedUITests` | Onboarding and daily-use integration tests |
| `scripts` | Reproducible Xcode project and vector brand asset generation |

Storage uses a versioned, validated Codable graph written atomically to Application Support. A mutation becomes visible only after its complete save succeeds. Typing changes are coalesced briefly, while navigation, Save & close, and lifecycle transitions flush the draft. Draft saves validate their own context without revalidating confirmed history on every keystroke. The additive optional destination and setup-version fields allow previous backups to open in this version; restoring newer backups into older builds is not supported. This deliberately implements the spec's persistence contract using an atomic JSON adapter rather than its suggested SwiftData adapter: source revisions, assessments, ledger events, and audit records commit together, and restore uses the same validation. The Foundation-only domain does not depend on the storage choice. A larger future dataset can adopt another repository without redefining the reward rules.

## Build and test

```sh
xcodebuild -project Bloomed.xcodeproj -scheme Bloomed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Choose an installed simulator name on your Mac. The tests include all 28 authored numerical fixtures plus conservation, rounding, DST and pinned-timezone boundaries, historical corrections, duplicate transaction handling, failed saves, restore validation, and outside settlement reconciliation.

The current review pass has 74 unique passing automated tests across the documented runs, including 9 UI journeys and all 28 authored calculation fixtures. Version 0.2.0 (3) was also installed and launched on the owner’s intended iPhone. See [implementation and validation notes](docs/IMPLEMENTATION-NOTES.md) for the actual checks run, deliberate implementation choices, and remaining device-review work. The full acceptance document is a review checklist, not a claim that every manual scenario has already passed.

The Xcode project uses synchronized source folders. Regenerate it only when changing project configuration:

```sh
python3 scripts/generate_project.py
```

## Specification

| Document | Purpose |
|---|---|
| [Product requirements](docs/PRD.md) | Scope, lifecycle, rules, data integrity, and review items |
| [Screens and UX](docs/UX-SPEC.md) | Interactions, states, copy, and accessibility intent |
| [Acceptance scenarios](docs/ACCEPTANCE-SCENARIOS.md) | Functional, failure, privacy, and recovery checks |
| [Reward fixtures](docs/fixtures/reward-cases.json) | Machine-readable numerical examples |
| [Development handoff](docs/CODEX-HANDOFF.md) | Implementation contract and milestones |

## Repository

[github.com/khanom12/bloomed](https://github.com/khanom12/bloomed)

The owner's checkout uses SSH authentication. Signing profiles, device identifiers, personal exports, build products, and historical discovery notes are excluded from Git. No payment, health-data, supporter account, or live-sharing integration is included in this draft.
