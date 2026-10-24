# Bloomed — workspace instructions

## Read first

For implementation or implementation planning, read in order:

1. `docs/PRD.md`
2. `docs/UX-SPEC.md`
3. `docs/ACCEPTANCE-SCENARIOS.md`
4. `docs/fixtures/reward-cases.json`
5. `docs/CODEX-HANDOFF.md`

The PRD is the implementation source of truth. The decision register records owner decisions; the concept brief and exploration log preserve discovery. Archived or earlier discussion does not expand MVP scope. Resolve an actual conflict explicitly rather than silently merging incompatible versions.

## Current status and authorization

The user authorized implementation of the first iOS draft on October 24, 2026, connection to `https://github.com/khanom12/bloomed.git`, and installation on the owner's iPhone for testing. The canonical checkout is `~/Projects/Bloomed`. The previous documentation location is a symlink to this checkout, not another project copy. Keep all application source and the Xcode project here. Integrated money handling and public product launch remain outside scope.

Follow later explicit user instructions. Work within this Bloomed workspace unless the user authorizes a broader change. Keep the specification standalone: no other product names, assets, personal identities, code locations, or assumed prior knowledge in the implementation bundle.

## Established boundaries

Walking only; manual daily totals; personal commitment with optional capped matching; optional stretch target and consistency; external proof, money, and donations; no health integrations. Initial supporter interaction is a snapshot plus participant-recorded outside agreement. Direct supporter accounts, live access, encouragement, circles, custom challenges, and sponsor-only plans are future work.

Ongoing support relationships are distinct from financial agreements. Preserve historical weekly terms. Do not make walking qualification depend on how much personal money exists.

## Specification integrity

- Preserve the distinction between owner-established direction and proposed implementation defaults. Do not promote an example into an independently approved decision.
- v0.1 supplies deterministic provisional defaults. When asked to implement it, use them consistently unless the owner changes them; do not invent alternative money policies or repeatedly ask about choices the baseline already defines.
- Keep rule formulas, fixtures, scenarios, UX copy, and review items synchronized.
- All money uses integer cents. Return principal, additional rewards, charity allocations, and actual external records remain separate.
- Never imply custody, independent activity verification, verified payment, live sharing, or an executed donation.
- Record original values and revisions. No silent rewriting of reviewed terms or external settlement history.
- No application tests have run merely because numerical specification examples were checked.

## Maintain continuity

When authorized work changes the concept or baseline, update existing entries rather than duplicate them. Add explicit owner decisions to `docs/DECISIONS.md`; label assistant-selected defaults separately. Append a dated exploration-log entry and refresh the README/scope summary when needed. Preserve useful superseded ideas in the idea bank or archive, outside launch scope.

The user's request to discuss without edits takes precedence over routine documentation maintenance. Never treat a discussion as permission to implement an app or move money.

## Implementation quality

Use pure calculation rules, versioned weekly terms, injected time/calendar, atomic storage, audit events, and real recovery. Keep views independent of money calculations. Use the acceptance suite and fixture expectations as verification requirements. Validate implemented layouts and accessibility; do not claim high fidelity from uninspected screenshots.

Reverify time-sensitive platform, distribution, payment, or legal facts before relying on them for a future integration or release. Do not add those integrations merely because the records can describe external arrangements.
