# Bloomed — Product Requirements Specification

| Field | Value |
|---|---|
| Document ID | BLM-PRD-001 |
| Version | 0.2 |
| Date | 2026-10-25 |
| Status | Development baseline incorporating the authorized walkthrough improvements; implementation defaults remain identified separately |
| Product | Bloomed MVP |
| Audience | Product owner, designer, Codex, application developer, QA |
| Implementation status | Implemented native draft; current build, test, and device evidence are tracked in the repository README and implementation notes |

> **Product promise:** Make a realistic walking commitment, earn your own commitment back, and optionally invite someone to match your progress.

## 1. Authority, scope, and decision integrity

This document is self-contained. Implement Bloomed from this specification and its companion files; no knowledge of another application or earlier conversation is required.

### 1.1 Specification bundle and precedence

1. **This PRD:** scope, product behavior, calculation rules, lifecycle, and invariants.
2. [UX specification](UX-SPEC.md): screen composition, interaction, copy, accessibility, and proposed visual system.
3. [Acceptance scenarios](ACCEPTANCE-SCENARIOS.md): examples and verification requirements.
4. [Reward fixtures](fixtures/reward-cases.json): machine-readable calculation examples.
5. [Codex handoff](CODEX-HANDOFF.md): implementation sequence and delivery standards.

The PRD takes precedence if companion documents conflict. Report and repair a conflict rather than implement two interpretations. Earlier concept and exploration documents preserve discovery history; they are not additional MVP requirements.

**MUST** and **SHALL** express requirements within this proposed baseline. They do not imply that the product owner separately approved every engineering default. The defaults in §1.3 are concrete proposals so the baseline can be implemented consistently. Do not describe them as individually owner-approved. A later explicit owner instruction supersedes the affected requirement and must be recorded prospectively.

### 1.2 Established product direction

| ID | Direction |
|---|---|
| DIR-01 | Walking is the only initial activity; daily step totals are entered manually. |
| DIR-02 | The participant starts independently with a personal financial commitment. |
| DIR-03 | A single daily goal is the simplest configuration; an optional higher goal enables tiered returns. |
| DIR-04 | Optional consistency rewards may be included within the same personal budget. |
| DIR-05 | One optional supporter can match qualifying personal returns up to a cap. |
| DIR-06 | Successful completion can return the entire personal commitment. Lower walking tiers return substantially less than the highest tier. |
| DIR-07 | Money handling, proof, and verification occur outside Bloomed. Health integrations are deferred. |
| DIR-08 | Unearned personal commitment is allocated to the participant's selected charity. Unused supporter allowance belongs to the supporter. |
| DIR-09 | Bloomed's revenue must not increase because a participant misses goals. Pricing is separate future work. |
| DIR-10 | Initial supporter involvement uses shared snapshots and participant-recorded external agreements. |
| DIR-11 | Preserve historical targets and results as future weeks change. |
| DIR-12 | Preserve room for ongoing relationships, nonfinancial encouragement, recurring support, and future fully sponsored participation without including those interactive modes in this release. |

### 1.3 Proposed implementation defaults

These are provisional baseline choices, not claims of independently approved policies. They apply consistently throughout this bundle unless the owner revises them.

| ID | Default | Reason |
|---|---|---|
| DEF-01 | Native iPhone app using SwiftUI; iOS 17+ target; local persistence; no backend or login | Complete offline participant experience with a bounded implementation |
| DEF-02 | Seven consecutive calendar dates per plan; every date has a walking opportunity | One understandable period and allocation model |
| DEF-03 | First start date defaults to tomorrow; today is allowed with disclosure | Make the first full day possible without preventing immediate use |
| DEF-04 | Consistency is optional and off initially; when enabled, meet base on any five of seven dates | One challenge template; no consecutive-day requirement |
| DEF-05 | Consistency receives 20% of the commitment, rounded down to cents; daily returns receive the remainder | Simple automatic allocation |
| DEF-06 | With two targets, base-only returns 25% of that day's maximum, rounded down; stretch returns the full maximum | Stronger return at higher effort, without stacking |
| DEF-07 | Supporter matching is 1:1 against total personal return, including consistency, subject to one weekly cap | One funding rule |
| DEF-08 | Currency CAD; personal commitment $1.00–$1,000.00; positive supporter cap $0.01–$1,000.00 | Explicit input bounds, not recommended amounts or pricing |
| DEF-09 | Each week pins its timezone; changes to goals or financial terms ordinarily apply to a new week | Stable history and dates |
| DEF-10 | Static image and text sharing through the system share sheet; no hosted links | Useful invitations and summaries without shared accounts |
| DEF-11 | Confirm every new weekly commitment; saved templates and recorded standing support may prefill it | Repetition without automatic financial obligations |
| DEF-12 | Active weeks retain their original seven-day rules; no automatic early-stop prorating | Avoid an unagreed exception formula; see §5.5 |

The owner authorized implementing the walkthrough improvements on October 25, 2026, including the earlier suggestion to make charity entry optional during setup. The revised five-screen order, progressive disclosure, deferred-destination record, calendar treatment, and draft-save strategy are implementation choices made within that authorization, not claims of independently approved design details.

Changing a default that affects calculated outcomes requires updating the rule version, examples, fixtures, and acceptance scenarios together. The changes in v0.2 preserve `bloomed.walk.v1`, the numerical fixtures, and the existing integer-cent formulas; changing display design or when a destination is supplied does not change financial qualification.

## 2. Product, audience, and boundaries

### 2.1 Initial audience and benefit

An adult who wants to walk consistently, is willing to record an affordable personal commitment, and may seek support from someone they know. Bloomed structures the commitment and the request for support; it does not prescribe exercise or guarantee behavior change, weight loss, financial recovery, or supporter payment.

The participant's private reason may be recorded as optional text. Weight, food intake, fasting, calories, heart rate, and medical conditions are not required inputs or payable conditions.

### 2.2 Roles

- **Participant:** owns plans; records walking, outside agreements, and external settlements; chooses what to export.
- **Supporter:** an optional known person represented by a local alias and recorded financial agreement. No independent login or in-app confirmation in the MVP.
- **External money handler:** the participant or another person identified in the outside arrangement. This role does not imply app access or custody by Bloomed.
- **Charity destination:** a participant-entered external destination, not an integrated or app-validated partner.

A future account may both participate and support others. Do not encode one permanent, exclusive account role.

### 2.3 Included

Guided plan setup; one or two daily walking targets; optional five-of-seven consistency allocation; personal commitment; at most one applicable supporter match per week; static invitations and progress/final summaries; participant-recorded recurring support; manual steps and corrections; weekly review; optional charity entry during setup with an audited later choice before reviewing a positive charity amount; separate walking and money history, including Week/Month walking views; partial external settlement records; accessible light/dark interface; offline storage; full-fidelity backup export/import; deterministic calculations and meaningful automated tests.

### 2.4 Excluded

Money collection, custody, charges, bank connection, refunds, payouts, donation execution, tax receipts, service billing, HealthKit, wearables, activity proof uploads, independent verification, supporter accounts, live shared progress, in-app messages, encouragement notifications, multiple simultaneous supporters, circles, public profiles, feeds, leaderboards, sponsor-only plans, custom challenges, recovery challenges, carryover reward pools, automatic new weekly commitments, automatic difficulty escalation, and other activity types.

Nonfinancial encouragement, live supporter access, custom challenges, and sponsor-only funding are future directions, not hidden acceptance requirements.

## 3. Vocabulary and navigation

| Term | Definition |
|---|---|
| Journey | The participant's continuing history across independent weekly plans |
| Weekly plan | A dated seven-day agreement with preserved goals and calculation rules |
| Base goal | The single goal, or the lower target when stretch is enabled |
| Stretch goal | Optional higher repeatable daily target; not a maximal one-off effort |
| Personal commitment | Participant-owned money described in an external arrangement |
| Personal return | The part of that commitment qualifying to be returned or retained |
| Consistency return | A reserved part of the same commitment unlocked by five qualifying dates |
| Supporter reward | Additional money earned under the applicable matching agreement |
| Charity allocation | Personal commitment not qualifying for return in a reviewed assessment |
| Assessment | A calculation revision derived from a week's preserved terms and entries |
| External settlement | A participant's record of money retained, returned, received, or donated outside Bloomed |
| Snapshot | A static export as of a timestamp, not a live or independently verified record |

Four persistent tabs: **Today**, **My plan**, **Progress**, **Money**. Today prioritizes the next daily/review action; My plan preserves agreed goals, dates, and amounts; Progress explains walking over time; Money distinguishes calculations from outside records. Settings, backup, and app information are secondary destinations. A dedicated challenge tab is unnecessary for one embedded consistency challenge. Screens must use the same evaluator and assessment records.

User-facing copy uses **everyday goal** for the domain's base goal, **higher goal** for stretch, **your weekly amount** for personal commitment, **money earned back** for personal return, and **supporter match** for additional supporter reward. Domain identifiers and rule meanings do not change. Explain the own-money/charity mechanism before asking the participant to interpret its amounts; do not rely on prior marketing exposure.

Progress provides Week and Month views. The native month calendar distinguishes no plan, upcoming date, missing record, recorded below everyday goal, everyday goal reached, and higher goal reached. Explicit zero stays an actual recorded value, distinct from missing. Calendar details use each date's preserved targets and timezone; if two nonoverlapping plans in different timezones share a local date key, retain and show both records. Historical week cards open walking detail first, with secondary links to the preserved plan and money.

## 4. Onboarding and plan confirmation

### 4.1 Required setup sequence

Use five screens in this order: **Everyday goal → Your weekly amount and outside arrangement → Optional higher goal → Optional consistency → Dates and review**. Amounts are known before financial options are explained. The stable requirement IDs below are not screen numbers.

**ONB-01 — Everyday goal:** ask for a realistic everyday step target. Input is a positive whole number from 1 to 100,000. Suggestions are examples, not health recommendations, minimum requirements, or preaccepted commitments. No plan starts with an unconfirmed suggested value. An optional private reason is collapsed and excluded from sharing by default.

**ONB-04 — Weekly amount:** require one seven-day amount in CAD within DEF-08. No default monetary stake. Parse decimal input safely, rejecting more than two decimal places, negatives, ambiguous separators, and amounts outside bounds. Explain that this is the participant's own money, walking determines how much is retained/returned, and the amount not earned back is for charity after review. No money is collected by Bloomed.

**ONB-05 — Outside arrangement and optional destination:** show who keeps the money: the participant, another person, or another outside arrangement. Require a short handler description for the latter two; no bank/contact details are needed. Charity name/description is optional during setup. Blank means **Choose later**, not that unearned money is kept or that the charity rule is waived. A positive charity allocation cannot be reviewed until its destination has been recorded under §5.3. Explain that the participant arranges any donation outside Bloomed.

**ONB-02 — Higher goal:** off by default. If enabled, require a whole-number target strictly greater than the everyday goal and no greater than 100,000. Explain that it should be repeatable. Before confirmation, visibly explain the material tradeoff: enabling a higher goal reduces the return for reaching only the everyday goal to 25% of that day's maximum, rounded down; the higher goal earns the full daily maximum. These are alternatives, not additive amounts. Show actual amount/range previews and the seven-everyday-days outcome; exact dated amounts remain available. There are exactly two rewarded levels; no automatic middle tier. This disclosure changes no formula.

**ONB-03 — Consistency:** off by default. If enabled, explain: everyday goal on any five of the seven dates; higher-goal days count; days need not be consecutive. Show the actual reserved amount and daily amount/range after the same weekly budget is redistributed. The reserve is 20% rounded down to cents, not extra money above the commitment. The participant does not configure percentages, streak lengths, or bonus types.

**ONB-06 — Dates:** choose a start date of today or later; no backdated financial plans. Default tomorrow in the selected plan timezone. Provide start-today/start-tomorrow shortcuts and a start-date selector. Show all seven dates and a human-readable timezone, with a change action; retain the IANA identifier in data. The timezone initially follows the device and stays pinned for the confirmed week. Starting today counts the whole date's manually entered total, including walking before confirmation; show that explicitly. Do not prorate the first day.

**ONB-07 — Review:** show exact daily return amounts, consistency amount and condition, maximum personal return, charity destination or Choose later, handling arrangement, all dates, timezone, and external/manual boundaries. Daily summary ranges must identify cent variation and provide the exact dated schedule. Full return requires the highest selected goal on all seven dates. Five-day consistency does not by itself guarantee full return. Keep the original seven-day/early-stop rule visible in plain language, with exceptional-arrangement detail disclosed separately.

**ONB-08 — Confirm:** require an explicit **Confirm this week's plan** action. Save preserved terms and audit event atomically before showing success. Show goals, amount, dates, and that no money has moved. Offer Done and optional supporter setup; support never blocks independent participation.

### 4.2 Drafts, validation, and responsive transitions

Drafts survive navigation and relaunch after durable save. All plan entry points use **Continue your walking plan** when a draft exists and resume its saved step. Earlier drafts with no setup-flow version retain values and map their saved step into the revised order; current drafts use setup-flow version 2.

Coalesce typing autosaves after a 350 ms quiet interval rather than saving and reevaluating all confirmed history on every keystroke. Saving an unchanged draft is a no-op. The draft-only storage path validates draft identity, timezone, start date, and supported flow/step against already validated confirmed state; complete confirmed mutations and loaded/restored data still receive full validation. This optimization does not bypass financial validation at confirmation.

Continue/Back save the complete next draft before advancing. Save & close, confirmation, backgrounding, and disappearance flush pending draft changes; cancel a scheduled autosave after confirmation or discard so it cannot recreate the draft. Show pending/error feedback, preserve entered values on failure, provide retry, and prevent an accidental swipe from discarding pending/failed input. A sudden termination before an autosave/flush can recover only the last durable draft; do not claim unsaved keystrokes were committed.

Validation is inline and accessible. A disabled Continue explains the specific missing requirement. Back preserves values, keyboard dismissal is available, and a valid action responds to one activation without duplicate commitments. The reported multi-tap/lag behavior is a reproduction and validation concern, not a proven performance root cause. No contact permission, health permission, payment information, or supporter recruitment is required.

## 5. Plan lifecycle, dates, and continuation

### 5.1 States

| State | Meaning | Permitted actions |
|---|---|---|
| `draft` | Editable, not a commitment | Edit, delete draft, confirm |
| `scheduled` | Confirmed, start date not reached | View, share, void before start |
| `active` | Within the seven-date interval | Enter elapsed/current steps, record eligible support, prepare future draft |
| `awaitingReview` | Interval ended | Complete/correct entries, review results, prepare/start later nonoverlapping week |
| `reviewed` | Participant confirmed an assessment revision | Record external settlement, share, correct with history, repeat |
| `voidedBeforeStart` | Confirmed plan cancelled before its first midnight | Historical view only; no assessed return, charity, or match |

Settlement completeness is independent of these states. A reviewed week may remain unsettled. A new week must not be blocked by unpaid amounts or an older week awaiting review.

### 5.2 Time and overlap

**TIME-01:** Save an IANA timezone identifier, calendar-date start key, seven ordered date keys, and an exclusive end at local midnight after date seven. Dates use the Gregorian calendar for rules; display respects locale. Derive dates by calendar arithmetic, never seven multiples of 24 hours.

**TIME-02:** The active week retains its timezone during travel. Explain the active plan's date when it differs from the device date. New weeks may choose another timezone. Existing entries never migrate between dates.

**TIME-03:** No overlapping confirmed, nonvoided weekly intervals for the participant. Compare absolute intervals when timezones differ. Allow one unconfirmed future draft. Multiple older weeks may await review. Recheck overlap at confirmation, including duplicate taps.

At most one week may be active and one later confirmed week scheduled. Preparing a draft is allowed while either exists; confirming an additional future week is blocked until the existing scheduled week starts or is voided. Today selects the active week, otherwise the earliest scheduled week, otherwise the latest ended week with a review/continuation action. My plan exposes the active/current agreement and any scheduled next week without merging their budgets.

**TIME-04:** Refresh state on launch, foreground, midnight, timezone notifications, and before committing a mutation. Background execution is not required. Never require the app to run at midnight to calculate correctly.

### 5.3 Review and finality

At the end, present seven entries and the assessment. Missing entries provisionally contribute zero but remain labelled `Not recorded`, not fabricated zero-step records. To review, the participant must enter the missing totals or explicitly acknowledge that the identified missing dates receive no return. Do not automatically finalize a charity allocation because the app was not opened.

Review confirms a calculation from participant records; it does not verify walking or payment. Store the entry revision, assessment revision, review timestamp, and acknowledgement of missing dates. A changed source entry or applicable support record on a reviewed week transitions it back to `awaitingReview`, even when rounded financial totals happen to remain equal. Retain all prior reviewed assessments and mark this specifically as a correction awaiting review.

If the original weekly terms name no charity, require an effective destination before confirming **any** review whose charity allocation is positive, including a corrected review after an earlier zero-charity result. A zero-charity review may remain unnamed. Do not replace a blank destination with a fictitious charity or silently change the allocation formula.

Record a later choice as one immutable, additive `CharityDestinationRecord` for the confirmed, nonvoided plan. It contains stable ID, plan/participant/actor IDs, destination, timestamp, and transaction key, plus an audit event. It is permitted only when the original `PlanTerms.charity` is blank. An identical repeated choice is a no-op; an attempt to replace it, add another destination, or overwrite an originally named charity is rejected. Its timestamp must be at or after plan confirmation and at or before every reviewed positive allocation that relies on it. Resolve display/export/repetition through the original destination when named, otherwise the additive record. If the plan is later cancelled before its start, retain the earlier destination record; reject a new choice after cancellation. Neither original terms nor R/A/M are rewritten by choosing a destination. A separate future policy is needed to change an already named destination.

There is no arbitrary late-entry deadline in the MVP. Past entries can be corrected under §10. Future dates cannot be entered.

### 5.4 Repeat and progression

**PLAN-01:** `Repeat this plan` prepares a new draft with the same targets, allocation rule, commitment, effective charity destination, and handling arrangement. Default the start to the later of the prior week's next date or tomorrow, adjusted forward to avoid confirmed overlaps. The participant can explicitly select today if nonoverlapping and accept the partial-day disclosure. Show any gap. Do not extend the old budget or silently create obligations during inactivity.

**PLAN-02:** `Adjust next week` edits the draft; the active and historical weeks remain unchanged. Goal changes never automatically increase personal money or supporter caps.

**PLAN-03:** At review, always offer `Keep this plan` and `Adjust next week`. A provisional optional progression prompt may appear after two consecutively dated reviewed weeks in which all seven highest-goal targets were reached. It offers review, not an automatically chosen increment. Permit dismissal and disablement. Maintaining a goal is a valid outcome.

**PLAN-04:** Every next week requires explicit confirmation even when a reusable template or standing supporter agreement exists. No scheduled automatic charges or automatic weekly plan creation.

### 5.5 Stopping, voiding, and exceptional arrangements

A scheduled week may be voided before its start: retain the original confirmation and void event, assess no earnings or charity, and instruct the participant to notify anyone involved externally. Do not record a fictitious refund.

An active week cannot be converted into a shorter financial period in this baseline. The participant may stop activity at any time and choose not to start another week; no exercise is forced. Original seven-day calculations remain the app's basis. Do not mark future dates missed, allocate their money to charity early, raise later targets, or invent a recovery challenge.

If parties agree an exceptional external resolution, record a note and a `reconciliationRequired` flag on the week. Do not rewrite the walking assessment or manufacture custom financial amounts. Keep computed and externally recorded outcomes visible, labelled as differing where relevant. Clear the review flag only with a participant-recorded resolution note; retain numerical discrepancies. Automatic cancellation/prorating and exception formulas require a later policy revision. This default must be explained before plan confirmation and is a product-review item under OD-04.

## 6. Manual walking entries

**ACT-01:** One effective total per plan date. Saving a new number replaces that date's total; it never adds a session. Store a nonnegative whole number from 0 to 100,000, source `manual`, actor, recorded timestamp, revision ID, and superseded revision ID when applicable.

**ACT-02:** `Not recorded` is different from explicit `0`. Neither qualifies, but missing history must never be represented as a known zero. Provide an explicit action to clear an entry back to missing, with audit history.

Saving the exact existing effective total is a no-op, not a new correction or review requirement. A genuinely different total is a source revision even if it stays within the same reward tier.

**ACT-03:** Allow editing elapsed dates within existing plans, including reviewed ones. Reject future dates. Show the selected date prominently; reject a stale date context or ask the participant to confirm it when a sheet spans midnight. Do not silently save to another date.

**ACT-04:** Current-day amounts and unreviewed weekly outcomes are provisional and can decrease after corrections. Reaching a goal provides immediate feedback but does not claim independent verification or external payment.

**ACT-05:** Steps above the highest target remain visible as actual activity. Their monetary return is capped. Show remaining steps to the next target where applicable; no target or debt is added after a miss.

There are no timers, sessions, before-meal conditions, photo evidence, approvals, or health imports.

## 7. Deterministic personal returns

### 7.1 Inputs and allocation

All monetary arithmetic uses integer minor units (CAD cents), with checked arithmetic. Never use binary floating-point for amounts, allocations, caps, totals, or stored assessments.

For personal commitment `C` cents, seven dates indexed `i = 0...6`:

```text
K = consistencyEnabled ? floor(C / 5) : 0
D = C - K
q = floor(D / 7)
r = D mod 7
dailyMaximum[i] = q + (i < r ? 1 : 0)
baseOnlyReturn[i] = floor(dailyMaximum[i] / 4)  // only if stretch enabled
```

The earliest `r` dates receive the extra cent. The exact per-date schedule is preserved in the plan. The sum of daily maxima plus consistency reserve is exactly `C`. This rule is deterministic; do not distribute remainders randomly or round every day independently.

### 7.2 Daily and weekly qualification

```text
if entry is missing or steps < baseGoal: dailyReturn[i] = 0
else if stretch is disabled: dailyReturn[i] = dailyMaximum[i]
else if steps >= stretchGoal: dailyReturn[i] = dailyMaximum[i]
else: dailyReturn[i] = baseOnlyReturn[i]

qualifyingDays = count(dates with recorded steps >= baseGoal)
consistencyReturn = (consistencyEnabled && qualifyingDays >= 5) ? K : 0
personalReturn R = sum(dailyReturn) + consistencyReturn
charityAllocation A = C - R
```

The highest tier pays once; do not add base and stretch values. Base and stretch days both count towards consistency. The bonus is awarded once per week. Five qualifying dates need not be consecutive; four do not earn a partial bonus. A correction from five to four removes the bonus in the new assessment.

Twenty percent and twenty-five percent describe allocation rules before cent rounding. Display exact dollar values; do not promise an exact aggregate percentage where rounding changes it.

### 7.3 Worked example

Illustrative configuration: `C = 3500`, consistency enabled, base 5,000, stretch 8,000.

- Consistency reserve: 700 cents.
- Daily pool: 2800 cents; each daily maximum: 400 cents.
- Base-only daily return: 100 cents.

| Recorded pattern | Daily return | Consistency | Personal return | Charity allocation |
|---|---:|---:|---:|---:|
| Seven stretch dates | $28 | $7 | $35 | $0 |
| Seven base-only dates | $7 | $7 | $14 | $21 |
| Six stretch, one below base | $24 | $7 | $31 | $4 |
| Five stretch, two below base | $20 | $7 | $27 | $8 |
| Four stretch, three below base | $16 | $0 | $16 | $19 |

This explicitly creates a consistency threshold. UI copy must explain it without implying that earlier daily returns are lost.

### 7.4 Invariants

- `0 <= R <= C`; `0 <= A <= C`; `R + A = C` for an assessed nonvoided week.
- Seven highest-goal dates always return exactly `C`.
- For a fixed plan, increasing recorded steps cannot decrease the personal return.
- Single-goal success receives the full daily amount; base-only discount exists only when stretch was selected.
- Evaluation is deterministic and idempotent for identical inputs and rule version.
- No reward carries into another week's budget. Unsettled external obligations remain visible but are not new earning opportunities.
- Do not present an active week's provisional `C - R` as a donation already due. Separate earned to date, remaining opportunity, and unearned portions of elapsed dates; final allocation awaits review.

### 7.5 Active-week forecast

For this forecast only, hold closed-date entries unchanged. An open date is the current plan date or a future date in the interval; closed dates are earlier dates. Missing closed dates contribute zero to this forecast, while remaining correctable under the entry rules.

```text
earnedSoFar = R calculated from the entries currently present
closedReturn = sum(dailyReturn for closed dates)
closedQualifying = count(closed dates meeting base)
openCount = number of current/future dates still in the plan
attainableConsistency = K if closedQualifying + openCount >= 5 else 0
maximumAttainable = closedReturn + sum(dailyMaximum for open dates)
                    + attainableConsistency
remainingWalkingOpportunity = max(maximumAttainable - earnedSoFar, 0)
```

When consistency is disabled, `K` is zero. The current day's unearned difference remains available until its boundary. Once five qualifying dates are recorded, their consistency amount is included in `earnedSoFar` and must not be counted again as additional opportunity. If five can no longer be reached without correcting past entries, the reserve is not shown as attainable through future walking. Label the assumption: `Based on completed days as currently recorded; corrections may change this.` After the interval ends, future walking opportunity is zero; past entry/review actions remain available. Final charity allocation is shown only after review; an awaiting-review preview is explicitly an estimate.

## 8. Optional supporter matching and recurrence

### 8.1 Agreement record

**SUP-01:** At most one applicable supporter per weekly plan. Capture local alias, cap `S`, currency, coverage, externally agreed date, recorder, and optional standing-agreement reference. Require `We agreed to this outside Bloomed` before activating the record. Alias is not an authenticated identity. Do not store contact details by default.

Offer distinct **Prepare invitation** and **Record agreed match** actions. Invitation starts an invitation preview, not a progress export; recording opens the outside-agreement form. An invitation is a proposal, not a commitment. An exported invitation does not activate matching, contact the supporter automatically, or establish acceptance. Label applicable records `Agreement recorded by you`.

Explain a cap in plain dollars and show the largest possible match for the current plan. A cap above C remains allowed within the input bounds, but cannot multiply the 1:1 match: with C=$35 and S=$350, the maximum possible match is $35 and the remainder stays with the supporter.

### 8.2 Matching formula

```text
supporterReward M = agreementApplies ? min(R, S) : 0
unusedSupporterAllowance U = agreementApplies ? S - M : 0
```

The match includes daily personal returns and consistency. Cap applies to the entire week. Do not invent guaranteed per-day matching amounts or split a capped match across days. Show weekly earned matching and remaining allowance.

`M + U = S` when an agreement applies. Unused allowance belongs to the supporter and is never included in charity or Bloomed revenue. Combined amount to participant is `R + M`; never label that whole sum profit or new reward.

### 8.3 Joining later

Support may begin in a later week. MVP coverage is whole-week only. Default a midweek recording to the next confirmed week or next-week draft. An active current week may be selected only with explicit confirmation that the external agreement covers **this entire week, including already-recorded activity**. Show the resulting immediate matching amount before saving.

No silent partial-week cap, session-based matching, or retroactive application to a reviewed historical week. If an upcoming draft changes before confirmation, recheck applicability. An erroneous saved agreement may be corrected through an audited correction; do not hide changes behind ordinary plan editing.

### 8.4 Standing external agreements

A standing agreement records a weekly cap, effective start, optional inclusive end date or `until stopped`, and the preserved terms under which it was agreed. A whole week must fall within its coverage. Reuse only when goals, allocation rules, commitment, currency, timezone, and cap match those recorded terms. New dates and plan IDs alone do not invalidate recurrence.

Changes outside those terms require recording renewed external agreement. An applicable standing agreement is snapshotted when the new week is confirmed; a later whole-week agreement is snapshotted when it is recorded. Preserve snapshots as append-only revisions with exactly one effective support state per week. Correcting a mistaken cap, coverage, or applicability creates a new revision, never an in-place overwrite. Corrections to reviewed weeks follow §10, including rereview and settlement posting restrictions. Pausing or ending standing support prevents future reuse and does not erase an already-confirmed week's agreement. External exceptions use §5.5.

The participant still confirms every week. Clearly state that the cap resets for each eligible confirmed week; it is not one allowance spread across the whole recurrence period. A recorded recurring pledge is not a bank subscription, proof of funds, or independently confirmed supporter action.

## 9. Money records and external settlement

### 9.1 Categories and language

Show personal commitment, personal return, charity allocation, supporter cap, supporter reward, and unused supporter allowance separately. Identify provisional/unreviewed versus reviewed assessment revisions beside the values they qualify, using estimate or reviewed labels. An absent outside record does not establish that a payment was not made; label the recording gap without calling it unpaid. Do not use `Withdraw`, `Deposit now`, app-held balance, verified donation, or automatic refund language.

The outside handling arrangement determines whether the participant retains their return or receives it from another holder. Both have the same calculated entitlement but different accurate action labels.

### 9.2 Settlement actions

**SET-01:** After a reviewed assessment, allow participant records for:

1. Personal return retained/received.
2. Supporter reward received.
3. Charity donation made.

Capture positive amount, date, category, week ID, actor, currency, creation timestamp, and optional note. Default to that category's outstanding amount; allow partial amounts. Reject new records above the outstanding amount. A category with zero outstanding has no record-payment action. No receipt upload or financial verification.

Require a short factual confirmation before posting. Record saves and their audit entries are atomic and idempotent. Corrections use preserved void/replacement records with reasons; never delete a posted transaction silently. Future dated settlements are not allowed.

Unused supporter allowance is informational. There is no required supporter-return transaction because Bloomed never collected it. An actual outside reimbursement may be described in an exception note; no new earning or charity calculation follows from it.

### 9.3 Reconciliation

For each category, let `T` be its latest reviewed target and `P` the sum of nonvoided external settlement records:

```text
outstanding = max(T - P, 0)
excessRecorded = max(P - T, 0)
```

Never show a negative outstanding amount as an app debt or automatically offset one category against another. Corrections may create excess previously recorded returns, supporter payments, or donations. Preserve them and show `Review external settlement`, with before/after values.

An excess donation is not an automatic refund entitlement. Bloomed does not recover money, contact a charity, or create a repayment claim. A resolution note can acknowledge outside handling while numerical history remains visible.

### 9.4 Historical totals

Money opens with a state-specific current-week card and a history list. An upcoming week shows readiness, weekly amount, start date, and possible match, rather than a zero-earnings dashboard. Hide reviewed-history totals until at least one reviewed week exists. Separate confirmed commitment totals, reviewed personal returns, reviewed supporter rewards, reviewed charity allocations, externally recorded settlements, outstanding amounts, and excess records. Do not add personal principal to supporter rewards under a misleading total-earnings label.

Exclude voided plans and drafts from assessed totals. Keep current/unreviewed estimates outside reviewed totals. Outstanding balances may remain while new weeks begin. Use date filters consistently and never mix currencies.

For historical outcome summaries, attribute an entire week's commitment and latest reviewed R/A/M to its plan start date; do not split the weekly consistency return across months. Attribute actual settlement totals to each settlement's effective date. Label outcome-period and payment-date summaries separately. A week awaiting correction review retains its latest previously reviewed values in posted historical totals, with a correction-pending indicator; do not silently replace them with unreviewed values. Money requires a history list, not financial date-filter controls; the walking Month view does not change financial attribution. Later financial aggregates must follow these attribution rules.

## 10. Corrections, audit, and reliability

**COR-01:** Every change to an effective step total, matching record, reviewed assessment, or posted settlement preserves the prior value, actor, timestamp, and reason where correcting reviewed information.

**COR-02:** Recalculate the entire affected week after an entry correction, including consistency and matching. Do not modify another week's rules or entries. Present proposed before/after financial changes before confirming a correction to a reviewed week.

**COR-03:** A corrected reviewed week needs a new review. Keep the prior reviewed revision and all external settlement records. Freeze new settlement posting until the new review is confirmed; previously recorded settlements remain visible. Shares of the revised week are labelled `Correction awaiting review` until then.

**COR-04:** Entry/support edits create provisional assessment revisions. Financial assessment events are posted only when review is confirmed: the first review posts opening R/A/M bucket values; subsequent reviews post each bucket's signed difference from the last reviewed assessment. Cumulative posted bucket events must equal the latest reviewed R/A/M. Do not post projected financial deltas while a correction awaits review. Applying the same revision twice creates no duplicate event. Store a stable transaction/idempotency key for each mutation and assessment posting.

**COR-05:** Use one atomic persistence transaction for effective entry changes, assessment revision, and related audit events. On save failure, show the last saved state, preserve unsaved input where possible, and give a retry action. Do not show a saved success or silently switch to an empty store.

### 10.1 Accounting events

Minimum event categories: `PLAN_CONFIRMED`, `PLAN_VOIDED`, `ENTRY_RECORDED`, `ENTRY_CORRECTED`, `ENTRY_CLEARED`, `SUPPORT_RECORDED`, `SUPPORT_CORRECTED`, `ASSESSMENT_REVIEWED`, `ASSESSMENT_ADJUSTED`, `EXTERNAL_SETTLEMENT_RECORDED`, `EXTERNAL_SETTLEMENT_VOIDED`, `EXCEPTION_NOTED`, `RESOLUTION_NOTED`.

Financial assessment entries carry a signed delta in exactly one bucket: `personalReturn`, `charityAllocation`, or `supporterReward`. Commitment amounts and unused allowance are agreement/assessment fields, not fictitious money transfers. Preserve both current projection and historical review revisions.

## 11. Sharing, invitations, and privacy

**SHR-01:** Generate static image and accessible text representations from the same plan/evaluator/assessment used by the screens. Sharing never changes commitments, step records, or settlement state.

A draft may be exported only as a clearly labelled `Draft invitation — not a confirmed commitment`. Progress exports require a confirmed nonvoided plan. Reviewed summaries require the latest effective assessment to be reviewed; a corrected week awaiting review cannot export its new values as final.

Three export types:

- **Invitation:** targets, dates, personal commitment, proposed matching explanation; visibly `Invitation — no supporter agreement recorded` unless applicable.
- **Progress snapshot:** selected week, as-of timestamp and timezone, recorded steps/qualifying dates, applicable targets, personal return and supporter reward separately, provisional status.
- **Reviewed summary:** final reviewed assessment, relevant agreement, amounts and destinations; clearly distinguish recorded external settlement if included.

**SHR-02:** Preview and explicitly confirm each export through the system share sheet. No background sending or contact access. Include only selected week. Optional public display name; omit private motivation, free-text notes, handler details, settlement notes, and the broader history by default. Financial terms are necessary for a financial invitation; clearly show them in preview. Progress-only exports may omit money.

**SHR-03:** Every export identifies it as static, participant-recorded, and not independently verified. Show creation timestamp, plan dates, timezone, assessment/review status, and a short statement that money is arranged outside Bloomed. A screenshot's delivery/acceptance is unknown; do not display `Supporter joined` after sharing.

**SHR-04:** Explain that previously shared files cannot be recalled or remotely revoked. Regeneration does not alter an earlier file. Clear temporary export files after completion/cancellation where possible; never include backups in an ordinary share action.

No telemetry, third-party analytics, advertising SDK, contact upload, or external network service is required in the MVP. Never log personal notes, step histories, or financial records in production logs.

## 12. Data model and architecture

### 12.1 Required conceptual records

| Record | Minimum responsibility |
|---|---|
| `ParticipantProfile` | Stable local ID, optional display name, preferences; no account credential |
| `SupportPerson` | Stable local ID and alias; not an authenticated external user |
| `SupportRelationship` | Participant/person association, relationship lifecycle; future permissions are separate from funding |
| `PlanTemplate` | Reusable draft defaults; not an automatically active obligation |
| `WeeklyPlan` | ID, participant, state, seven dates, timezone, currency, preserved target/rule/arrangement terms, rule version |
| `DailyStepRevision` | Plan date, total or cleared/missing state, manual source, actor, timestamps, predecessor |
| `CharityDestinationRecord` | Single additive, audited destination for an originally unnamed confirmed plan; never mutates original terms |
| `SupportAgreement` | Outside agreement metadata, whole-week or standing coverage, cap, rate/rule, terms fingerprint, recorder |
| `WeeklySupportSnapshot` | Append-only applicable-terms revisions for one week, one effective state, separately from standing agreement |
| `AssessmentRevision` | Input revision fingerprint, exact daily schedule/results, consistency, R/A/M/U, review status |
| `FinancialAssessmentEvent` | Signed bucket delta, revision linkage, idempotency key |
| `ExternalSettlementRecord` | Category, amount, date, actor, original/void linkage, reason |
| `AuditEvent` | Stable ID, entity, action, timestamp, actor, reason, before/after references |
| `ExceptionRecord` | External disagreement/resolution note with preserved history |

All durable records require stable IDs, a versioned export representation, and ownership metadata. Enforce uniqueness of effective step total by plan/date, effective support revision by plan, and later charity destination by plan and transaction key. Names never serve as identity keys.

### 12.2 Separation of concerns

Keep walking qualification, monetary calculation, lifecycle transitions, and reconciliation independent of UI and persistence. Pure evaluators consume immutable inputs and return deterministic results; they do not send messages, write a database, or read device time directly. Inject clock, calendar/timezone service, ID generator, persistence, and export renderer.

Use a local repository/storage adapter, with atomic transactions and explicit schema migrations. The implemented adapter is an atomic JSON repository, not a dependency of business rules. Do not build speculative microservices, a plugin system, generic challenge language, or an unused live-sharing backend.

### 12.3 Future compatibility boundaries

- A relationship may exist without a funding agreement. Do not require an amount to represent a future supporter.
- Snapshot sharing and future live views must read the same weekly results. A static export never grants live permission.
- Walking qualification must not depend on personal money. Future sponsor-only funding needs a new explicit funding rule; matching a personal return of zero cannot create a sponsor-only reward.
- A future account may own both participant and supporter actions. Local alias records must not be automatically linked to external accounts by name.
- Rule changes are versioned, prospective, and reproduce historical results.
- Standing agreements and each week's actual terms remain separate.

Future accounts, authorization, synchronization, conflict resolution, revocation, delivery, and encouragement require real additional work. This architecture preserves the core records and calculations; it does not claim to implement those capabilities now.

## 13. Storage, backup, and deletion

**DATA-01:** Manual entry, review, history, sharing preparation, and settlement recording work offline. Every acknowledged save survives termination/relaunch. New installations start empty. Synthetic preview/test data never enters a production store.

**DATA-02:** Provide `Export backup` and `Restore backup` in Settings. The versioned JSON envelope contains the complete profile, plans, revisions, agreements, assessments, events, settlements, and preferences with IDs preserved, including any additive charity destination. Preserve schema-v1 compatibility: the destination collection and setup-flow version are optional when decoding older installations/backups. Missing collections mean no deferred choices; never manufacture records. A share snapshot is not a backup. Export explicitly warns that the file includes private activity and financial information and is not encrypted by Bloomed.

**DATA-03:** Restore validates file type/version, IDs and references, integer bounds, date semantics, rule versions, and accounting identities before changing storage. Recompute and compare derivable assessments. Reject incompatible, corrupt, or inconsistent data without partial import. Restore replaces the store after clear confirmation; no merge behavior in MVP. Offer backup of current data first. Save atomically; a failed restore leaves existing records intact. Import never executes a payment or marks anything newly verified.

**DATA-04:** Use platform application sandbox/data protection and protected local files. No credentials, contact data, or bank information. Clear temporary files after export. Validate the installed platform's storage and file-protection behavior during technical design; do not promise stronger encryption than implemented.

**DATA-05:** Settings offers a destructive local-data deletion action with confirmation, backup option, and explicit explanation that exported files and external obligations are unaffected. Deletion removes the app's records and returns to empty onboarding. No supporter or charity is contacted.

## 14. Quality requirements

- Native-feeling navigation, safe-area layouts, keyboard handling, system sharing, light/dark support, and no placeholder production UI.
- Dynamic Type through accessibility sizes; VoiceOver navigation and labels; readable financial amounts; minimum 44-point action targets; information never conveyed only by color.
- Respect Reduce Motion; animation is supplementary and cannot delay saving or hide financial status.
- Charts have equivalent readable entries. Error, missing, provisional, reviewed, and reconciliation states are explicit.
- Currency and dates are localized for display while rule values stay stable. Baseline copy is English; avoid hardcoded layout assumptions that prevent later localization.
- Local interactions show immediate feedback; save failure never masquerades as success. Do not add network-dependent spinners to offline features.
- App foreground refresh, period transitions, and replay do not duplicate dates, assessments, matching, or settlements.
- No shame language, financial escalation after misses, promised medical benefit, or urgency to make up money by excessive activity.

## 15. Acceptance and release gates

The companion [acceptance scenarios](ACCEPTANCE-SCENARIOS.md) are required verification coverage, not optional examples. The fixture JSON is the numerical oracle for its named cases.

Before implementation completion:

1. All fixtures and invariant/property checks pass.
2. Plan transitions, review, corrections, recurrence, and settlement reconciliation pass.
3. Persistence failure, migration, backup round-trip, invalid restore, and relaunch recovery pass.
4. Primary end-to-end flows are exercised on iPhone simulator and, before distribution, a physical device.
5. Every screen's empty, populated, error, large-text, dark-mode, and relevant provisional/corrected states are visually reviewed.
6. VoiceOver and non-color goal/financial states are checked.
7. Shared exports match current on-screen calculations and exclude unselected private information.
8. No excluded money, health, live sharing, or verification behavior has been added.

Product review of provisional defaults is a baseline approval step, not a request to treat all open commercial questions as engineering blockers. Actual public release additionally requires an appropriate independent brand, platform, privacy, distribution, and commercial review for the shipped product.

## 16. Review items and unresolved decisions

| ID | Item | Baseline behavior / remaining choice |
|---|---|---|
| OD-01 | Platform and audience | Native iPhone, iOS 17+, adults; confirm intended devices and distribution before project setup |
| OD-02 | Monetary configuration | CAD and DEF-08 bounds; confirm market/currency and input limits before release |
| OD-03 | Return curve | Proposed 80/20 consistency allocation and 25% base-only return; validate comprehension and motivation |
| OD-04 | Illness, early stop, outside exceptions | No active-week prorating; explicit external reconciliation; confirm this policy before real-money pilot |
| OD-05 | Later supporter entry | Whole-week matching only, explicit current-week inclusion or next week; confirm this restriction |
| OD-06 | Standing support | Unchanged recorded terms, weekly confirmation, no automatic charges; confirm recurrence usability |
| OD-07 | Visual identity | UX token set is an implementation design proposal; final logo and brand clearance remain separate |
| OD-08 | Recovery/privacy | Local unencrypted backup with explicit disclosure; validate chosen protection and export UX before distribution |
| OD-09 | Revenue | No service fee or billing in MVP; future pricing must remain independent of missed goals |

These entries must not be presented as unimplemented features when this baseline already supplies behavior. They identify choices for owner review and later revision. Do not improvise alternative money rules during coding.

## 17. Delivery sequence

1. Domain types, date semantics, formulas, fixtures, state transitions, and invariants.
2. Persistence adapter, audit/revisions, backup schema, failure handling, migrations.
3. Design tokens, navigation, onboarding, empty states, and complete plan confirmation.
4. Today entry and weekly calculations; My plan and continuation.
5. Progress history and preserved terms; Money, review, settlements, corrections.
6. Support agreements, recurrence applicability, invitation/progress/final exports.
7. Accessibility, recovery, device validation, and visual/state QA.

Do not stop at an attractive dashboard with simulated balances. The definition of done is a complete, persistent, auditable manual loop with the required states and accurate copy. See [Codex handoff](CODEX-HANDOFF.md).

## 18. Change log

- **0.2 — 2026-10-25:** Authorized walkthrough improvements: amount-before-options setup, explicit higher-goal tradeoff, optional setup charity with immutable later choice, responsive draft persistence, separated supporter actions, purposeful states, and Week/Month walking history. Formulas, rule version, and fixtures unchanged. Test evidence is reported separately.
- **0.1 — 2026-10-24:** First standalone development specification. Consolidates walking plans, personal commitment, optional matching and consistency, snapshots, weekly history, recurrence records, and explicit implementation defaults. Prepared for review; no application code created.
