# Bloomed — Codex Implementation Handoff

**Version:** 0.1 · **Date:** 2026-10-24

**Purpose:** A portable implementation entry point for the accompanying specification. This file does not claim that application code exists.

## 1. Read in this order

1. [PRD.md](PRD.md): authority, scope, rules, defaults, and exceptions.
2. [UX-SPEC.md](UX-SPEC.md): exact screens, states, interactions, and proposed design tokens.
3. [ACCEPTANCE-SCENARIOS.md](ACCEPTANCE-SCENARIOS.md): required verification coverage.
4. [fixtures/reward-cases.json](fixtures/reward-cases.json): numerical inputs and expected results.

The PRD is authoritative. Earlier discovery notes are background, not requirements. The package is sufficient to understand the product independently. Preserve relative links when moving these files into a development repository.

## 2. Suggested instruction to begin development

> Implement the Bloomed MVP from this specification bundle. Use PRD v0.1 as the source of truth and implement its explicitly labelled provisional defaults unless I revise them. Do not silently replace financial or date policies with alternatives. Start with domain types, weekly lifecycle, integer-cent calculations, date rules, fixtures, and a persistence/recovery plan. Then build the complete native participant experience described in UX-SPEC.md. Work in small, reviewable milestones. Use the same evaluator for screens, history, and exports. Include deterministic tests for financial rules, lifecycle, corrections, recurrence, and recovery. Keep external money handling, manual activity, and snapshot support boundaries accurate. Identify a genuine contradiction or blocking environment issue with a concrete proposed resolution, while continuing independent work. Report what was actually built and tested. Do not add accounts, live sharing, payments, health integrations, or other deferred features.

## 3. Engineering boundaries

- Proposed baseline: native SwiftUI iPhone app, iOS 17+, local persistence, no login/backend. Verify the installed toolchain and chosen deployment target when implementation begins; do not claim the specification confirms local build readiness.
- Domain models and pure evaluators must not import UI or persistence frameworks.
- Separate walking results from personal commitment and optional matching. A future new funding policy must be possible without redefining recorded walking.
- Preserve plan terms, effective entry revisions, effective support revisions, assessment revisions, posted financial events, and external settlement records separately.
- Inject clock, date/timezone handling, persistence, ID generation, and rendering. Do not bury rules in view callbacks.
- Use checked integer cents. All examples must reproduce exactly, including remainder dates and capped matches.
- Use atomic persistence and explicit schema versions. Store failure cannot silently reset records.
- Native controls, accessible layouts, restrained motion, semantic colors, and the specified hierarchy are part of fidelity. A screenshot resembling a dashboard is insufficient if its state transitions are missing.
- No new third-party package, paid service, hosted infrastructure, or app permission is required by this spec. Introduce one only for a demonstrated need within scope and document the tradeoff.

## 4. Milestones and exit criteria

| Milestone | Deliverable | Exit evidence |
|---|---|---|
| M0 — Domain | Terms, dates, calculation types, lifecycle and reconciliation | Numerical fixtures and boundary/invariant tests passing |
| M1 — Storage | Repository adapter, transactions, audit/revisions, migrations, backup format | Relaunch, save-failure, round-trip and invalid-restore tests |
| M2 — Shell and setup | Four tabs, design tokens, onboarding, review/confirmation, no-plan/upcoming states | Walk through single-goal and two-goal setup; inspect compact/large text |
| M3 — Daily and weekly loop | Entry, qualification, forecasts, consistency, review, continuation | End-to-end week with missing/zero/corrections, DST/date tests |
| M4 — History and money | Historical terms, financial assessments, partial settlements and reconciliation | Correct a reviewed/paid week; verify signed deltas and preserved payments |
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

Before a real-money pilot or distribution, revisit the PRD's named review items, especially early-stop/external exceptions and privacy/recovery disclosures. Pricing, brand clearance, and distribution planning remain separate product work.
