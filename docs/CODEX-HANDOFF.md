# Bloomed — Codex Implementation Handoff

**Version:** 0.2 · **Date:** 2026-10-25

**Purpose:** A portable maintenance and implementation entry point for the accompanying specification. A native draft exists; the README and implementation notes hold current build, test, device, and limitation evidence. Requirements listed here are not claims that a check passed.

## 1. Read in this order

1. [PRD.md](PRD.md): authority, scope, rules, defaults, and exceptions.
2. [UX-SPEC.md](UX-SPEC.md): exact screens, states, interactions, and proposed design tokens.
3. [ACCEPTANCE-SCENARIOS.md](ACCEPTANCE-SCENARIOS.md): required verification coverage.
4. [fixtures/reward-cases.json](fixtures/reward-cases.json): numerical inputs and expected results.

The PRD is authoritative. Earlier discovery notes are background, not requirements. The package is sufficient to understand the product independently. Preserve relative links when moving these files into a development repository.

## 2. Suggested instruction for implementation and maintenance

> Implement the Bloomed MVP from this specification bundle. Use PRD v0.2 as the source of truth and implement its explicitly labelled provisional defaults unless I revise them. Do not silently replace financial or date policies with alternatives. Start with domain types, weekly lifecycle, integer-cent calculations, date rules, fixtures, and a persistence/recovery plan. Then build the complete native participant experience described in UX-SPEC.md. Work in small, reviewable milestones. Use the same evaluator for screens, history, and exports. Include deterministic tests for financial rules, lifecycle, corrections, recurrence, and recovery. Keep external money handling, manual activity, and snapshot support boundaries accurate. Identify a genuine contradiction or blocking environment issue with a concrete proposed resolution, while continuing independent work. Report what was actually built and tested. Do not add accounts, live sharing, payments, health integrations, or other deferred features.

## 3. Engineering boundaries

- Proposed baseline: native SwiftUI iPhone app, iOS 17+, local persistence, no login/backend. Verify the installed toolchain and chosen deployment target when implementation begins; do not claim the specification confirms local build readiness.
- Domain models and pure evaluators must not import UI or persistence frameworks.
- Separate walking results from personal commitment and optional matching. A future new funding policy must be possible without redefining recorded walking.
- Preserve plan terms, effective entry revisions, effective support revisions, additive charity destinations, assessment revisions, posted financial events, and external settlement records separately. A later destination may fill an originally blank plan once; never overwrite named/original terms. Require a destination before reviewing a positive charity allocation, including after a zero-charity review is corrected.
- Inject clock, date/timezone handling, persistence, ID generation, and rendering. Do not bury rules in view callbacks.
- Use checked integer cents. All examples must reproduce exactly, including remainder dates and capped matches.
- Use atomic persistence and explicit schema versions. Keep existing schema-v1 data readable when optional destination collections and setup-flow version are absent. Validate restored record uniqueness, ownership, references, and review-time destination requirements before replacement. Store failure cannot silently reset records.
- Preserve goal → amount → higher → consistency → review. Make the unchanged 25% everyday-only tradeoff visible when adding a higher goal; consistency is part of C, not extra money. Fixtures and `bloomed.walk.v1` remain unchanged.
- Coalesce typing autosaves, but flush a validated complete draft before a transition/close/confirmation and on background/disappearance. Preserve inputs on save failure and cancel pending tasks after discard/confirmation. The draft-only fast path must not weaken confirmation or restore validation.
- Invite, progress, and reviewed actions open their correct preview types. Static sharing never creates an agreement. Week/Month walking history uses preserved per-plan targets, missing/zero/future distinctions, and retains colliding local dates from different saved timezones.
- Native controls, accessible layouts, restrained motion, semantic colors, and the specified hierarchy are part of fidelity. A screenshot resembling a dashboard is insufficient if its state transitions are missing.
- No new third-party package, paid service, hosted infrastructure, or app permission is required by this spec. Introduce one only for a demonstrated need within scope and document the tradeoff.

## 4. Milestones and exit criteria

| Milestone | Deliverable | Exit evidence |
|---|---|---|
| M0 — Domain | Terms, dates, calculation types, lifecycle and reconciliation | Numerical fixtures and boundary/invariant tests passing |
| M1 — Storage | Repository adapter, transactions, audit/revisions, migrations, backup format | Relaunch, save-failure, round-trip and invalid-restore tests |
| M2 — Shell and setup | Four tabs, revised five-stage setup, optional charity, coalesced draft saving, review/confirmation, no-plan/upcoming states | Single/two-goal flows, explicit higher-goal tradeoff, old-draft stage mapping, transition save failure, compact/large text |
| M3 — Daily and weekly loop | Entry, qualification, forecasts, consistency, review, continuation | End-to-end week with missing/zero/corrections, DST/date tests |
| M4 — History and money | Week/Month walking history and dedicated walking detail, historical terms, reviewed/estimated money, deferred destination and outside records | Old-target/calendar state/date-collision checks; positive/zero-charity reviews; correction deltas and preserved payments |
| M5 — Support and export | Outside agreement entry, standing applicability, static invitation/progress/final export | Matching fixtures, recurrence checks, privacy preview and exported content inspection |
| M6 — Hardening | Accessibility, backup/restore UI, deletion, failure states, device readiness | Required scene matrix, VoiceOver/large-text checks, final build/test evidence |

Build a complete vertical flow early: confirm a plan → save a daily total → close/review a week under an injected clock → inspect financial outcome → record outside settlement → reopen history. Do not rely on production sample balances to demonstrate correctness.

## 5. Required handoff from the implementing agent

Provide:

1. What works, aligned to the milestones and scope.
2. Any changed product defaults, with the owner's instruction or documented reason.
3. Exact build/run/test commands and actual outcomes.
4. Device/simulator and OS used for visual checks; representative screenshots and unresolved layout/accessibility issues.
5. Persistence schema and backup/restore behavior, including destructive operations.
6. Known limitations and outstanding release decisions.
7. A current README describing the implemented app truthfully.

Never describe static sharing as live access, participant acknowledgement as supporter verification, an allocation as a completed donation, an earned amount as received, or a local record as a bank balance. Never report tests as passing if they were only specified or could not run.

## 6. Product-review items

Exact allocation percentages, input bounds, CAD, seven-day defaults, early-stop handling, recurrence restrictions, deployment target, and visual tokens are explicitly proposed in this baseline. They are not individually approved historical decisions. A request to implement this baseline authorizes using them as written unless the owner gives a change; it does not authorize integrated money handling or a public launch.

The October 25 owner request authorized implementation, testing, commit and push of the walkthrough improvements. The selected flow, deferred-destination design, calendar, copy, and save strategy are implementation decisions within that authorization, not individually approved historical policies.

Before a real-money pilot or distribution, revisit the PRD's named review items, especially early-stop/external exceptions and privacy/recovery disclosures. Pricing, brand clearance, and distribution planning remain separate product work.
