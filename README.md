# Bloomed

A native iPhone app for a walking commitment, one week at a time.

Choose a daily step goal, make a personal commitment, and track what you earn back. Optionally add a higher target, a consistency incentive, or a supporter who matches your return up to an agreed weekly cap.

**Version 0.1.0 — installed and launched on the owner’s iPhone for testing.** Bloomed calculates and records arrangements. It does not hold money, transfer funds, execute donations, or independently verify walking or payments.

## Open the app project

The canonical checkout on the owner's Mac is `~/Projects/Bloomed`. Keep the source, specification, and Xcode project together here; do not create another copy when opening Xcode. The previous documentation folder redirects to this checkout through a symlink.

```sh
cd ~/Projects/Bloomed
open Bloomed.xcodeproj
```

Select the **Bloomed** scheme and an iPhone simulator, then Run. The deployment target is iOS 17.0. This draft is built with Xcode 26.3 and has no third-party packages or service credentials.

For a connected iPhone, select the device in Xcode and use your development team under Signing & Capabilities. The project uses automatic signing and bundle identifier `com.khanom12.bloomed`.

## The first draft

- **Today:** manually enter or correct a total, see the next step target and daily return, and inspect the seven-day record.
- **My plan:** guided setup, exact dated allocations, optional stretch and five-of-seven consistency, supporter agreements, weekly review, and prospective continuation.
- **Progress:** daily walking charts, recorded-day averages, and historical goals preserved for every week.
- **Money:** separate personal returns, supporter rewards, charity allocations, outside settlement records, and correction history.
- **Sharing:** preview a static invitation, progress snapshot, or reviewed summary before using the system share sheet. Private motivation, handling details, and notes are excluded.
- **Recovery:** local persistence, validated JSON backups, replacement restore with confirmation, and explicit recovery if saved records cannot be opened.

There is no login or cloud service. Supporter agreements are entered by the participant after an outside conversation; a snapshot does not give someone live access. Device backups may include local app data according to iOS settings. Exported backup files contain the complete history and are not encrypted by Bloomed.

The app opens empty. UI tests use an isolated in-memory repository and do not seed ordinary app launches.

## Rules implemented

The detailed baseline remains [PRD v0.1](docs/PRD.md). Its proposed defaults are used consistently: CAD, seven pinned local dates, a positive personal commitment, optional stretch, optional consistency on any five dates, and one optional 1:1 weekly match.

All monetary calculations use integer cents. The personal commitment is split across daily opportunities and, when selected, a consistency reserve. Meeting the highest goal on all seven dates returns the full commitment. Unreturned personal commitment becomes a charity allocation after review; unused supporter allowance stays with the supporter. Corrections retain the earlier assessment and outside records, then post only the difference upon another review.

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
| `scripts` | Reproducible Xcode project and original draft icon generation |

Storage uses a versioned, validated Codable graph written atomically to Application Support. A mutation becomes visible only after its complete save succeeds. This deliberately implements the spec's persistence contract using an atomic JSON adapter rather than its suggested SwiftData adapter: source revisions, assessments, ledger events, and audit records commit together, and restore uses the same validation. The Foundation-only domain does not depend on the storage choice. A larger future dataset can adopt another repository without redefining the reward rules.

## Build and test

```sh
xcodebuild -project Bloomed.xcodeproj -scheme Bloomed \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

Choose an installed simulator name on your Mac. The tests include all 28 authored numerical fixtures plus conservation, rounding, DST and pinned-timezone boundaries, historical corrections, duplicate transaction handling, failed saves, restore validation, and outside settlement reconciliation.

See [implementation and validation notes](docs/IMPLEMENTATION-NOTES.md) for the actual checks run, deliberate implementation choices, and remaining device-review work. The full acceptance document is a review checklist, not a claim that every manual scenario has already passed.

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
