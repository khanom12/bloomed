# Bloomed — Acceptance Scenarios and Verification Plan

**Document:** BLM-QA-001 · **Version:** 0.2 · **Date:** 2026-10-25

**Authority:** [PRD](PRD.md). These scenarios specify expected behavior; their presence is not evidence that a check ran. Current implementation/test evidence is recorded in the README and implementation notes.

## 1. Test conventions

- Money is integer CAD cents. Display examples use dollars only for readability.
- Unless stated otherwise, a test week uses base 5,000, stretch 8,000, personal commitment 3500 cents, consistency enabled, and no supporter.
- Under that configuration, each daily maximum is 400, base-only is 100, consistency is 700, and the condition is any five dates meeting base.
- `null` means no recorded entry; `0` means an explicitly recorded zero. They are distinct records with equal zero financial qualification.
- Numerical fixtures evaluate a completed seven-date input set, independently of whether the participant has reviewed it. Review controls posting/finality, not the formula.
- Frozen clocks, explicit timezones, deterministic IDs, and temporary isolated stores are required. Do not depend on real current time or existing personal records.

## 2. Numeric fixtures

[reward-cases.json](fixtures/reward-cases.json) contains named input/output fixtures for the baseline rule version. Each fixture defines commitment, targets, consistency, seven step entries, optional cap, and expected personal/charity/supporter outcomes. Do not regenerate expected values from the implementation under test.

Required fixture adapter output: ordered daily maxima, daily returns, qualifying-day count, reserve, consistency return, personal return, charity allocation, supporter reward, and unused supporter allowance. Assertions must include all expected fields, not just the final total.

## 3. Setup and validation

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-001 | Fresh installation | Empty store, meaningful empty tabs, no sample steps, commitments, supporters, or money |
| AC-002 | Enter base goal | Whole positive integer accepted; missing, negative, fractional, and >100,000 rejected |
| AC-003 | Stretch disabled | Single-goal plan; reaching base earns the full daily maximum |
| AC-004 | Stretch enabled | Stretch must exceed base; equal/lower rejected; only two levels created |
| AC-005 | Toggle consistency before confirmation | Same commitment is redistributed; maximum personal return remains C; exact preview updates |
| AC-006 | Money input | No prefilled stake; accept CAD 1.00–1,000.00; reject excessive precision, negatives, ambiguous parsing, out-of-bounds values |
| AC-007 | Arrangement incomplete / charity deferred | Required handler description blocks continuation for another holder/arrangement; blank charity alone does not block plan confirmation and is labelled Choose later, without changing the charity allocation rule |
| AC-008 | Back through onboarding/relaunch | Draft values retained; no commitment or assessment event created yet |
| AC-009 | Confirm plan twice rapidly | One confirmed week, one confirmation event, no duplicate budget |
| AC-010 | Confirmation save fails | No success state, partial commitment, or lost draft; retry possible |
| AC-011 | Start today | Review explicitly says whole day's entered total counts; no intraday proration |
| AC-012 | Start in past / overlapping or excess scheduled plan | Reject; timezone-aware interval overlap enforced; at most one active and one future confirmed week |

## 4. Entry, qualification, and forecast

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-013 | Record 4,999 / 5,000 / 7,999 / 8,000 | Returns 0 / 100 / 100 / 400 in baseline example; no stacked tiers |
| AC-014 | Replace 6,000 with 7,000; then save 7,000 again | Effective total is 7,000, not 13,000; predecessor retained; identical save is a no-op |
| AC-015 | Missing, zero, clear | Financial qualification zero in each; UI/source history differentiates all actions |
| AC-016 | Enter future date | Rejected without mutation |
| AC-017 | Above highest target | Raw steps preserved; progress visual capped; return unchanged |
| AC-018 | Nonconsecutive qualifying dates | Five qualify for one consistency return; no streak requirement |
| AC-019 | Four become five qualifying dates | One 700-cent bonus; earlier daily returns remain; repeated evaluation adds no duplicate |
| AC-020 | All seven highest goals | Exactly C personal return, zero charity, with or without consistency |
| AC-021 | Irregular cent commitment | Earliest remainder dates receive +1 cent; all maxima plus reserve exactly C; show real schedule |
| AC-022 | Current day base reached but stretch not reached | Earned-so-far uses base return; remaining opportunity includes today's difference |
| AC-023 | Consistency already qualifies | Its amount is included once in earned-so-far, not added twice to remaining opportunity |
| AC-024 | Consistency becomes impossible from remaining dates | Future opportunity excludes the reserve; past corrections remain separately available |
| AC-025 | Week ended, entries missing | Zero future walking opportunity; show missing dates and review actions; do not auto-post charity |

Forecast examples for a 3500-cent two-target consistency week:

- Day 1 open, no entry: earned 0, maximum attainable 3500, remaining 3500.
- Six dates closed: four stretch and two below base; Day 7 open at base: earned 2400 (1600 + 100 + 700), maximum attainable 2700, remaining 300.
- Six dates closed: three stretch and three below base; Day 7 open at stretch: earned/max attainable 1600; consistency cannot be reached, remaining 0.

These forecasts hold closed entries unchanged. They must not prevent a later correction.

## 5. Support agreements and recurrence

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-026 | Share invitation | No matching agreement activated; no message-delivery or acceptance claim |
| AC-027 | Record external match | Required outside-agreement acknowledgement; alias, cap, coverage and recorder saved |
| AC-028 | R=1400, cap=700 | Match 700, unused 0; additional personal success cannot exceed cap |
| AC-029 | R=1400, cap=2000 | Match 1400, unused 600; unused portion belongs to supporter |
| AC-030 | Consistency contributes to R | Included in matching once; no separate or excluded bonus rule |
| AC-031 | No supporter | Personal outcomes unchanged; supporter fields zero/absent, not fabricated funding |
| AC-032 | Record midweek support | Default next week; current whole-week coverage needs explicit inclusion of past activity and immediate-match preview |
| AC-033 | Attempt partial-week or post-review new support | No undefined proration or retroactive new historical agreement; explain whole-week scope |
| AC-034 | Correct existing support record | Append new effective revision; old revision retained; reviewed week requires rereview and reconciliation |
| AC-035 | Standing agreement, unchanged terms | Eligible new confirmed week receives its own snapshot; cap resets for that week, no money moves |
| AC-036 | Changed goal, amount, rule, currency, timezone, or cap | Existing standing terms do not silently apply; self-funded confirmation remains possible |
| AC-037 | Standing agreement expires during week | Does not cover the whole new week; no partial-week automatic match |
| AC-038 | Pause/end standing support | Future reuse stops; confirmed prior/week snapshots remain; no deleted pledge or payment |
| AC-039 | Future weeks absent for a month | No automatic obligations or backfilled weeks; next draft defaults to a new available date |

## 6. Week lifecycle and history

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-040 | Void scheduled week | Before-start void event; no assessed return, match, or charity; no fictitious refund |
| AC-041 | Stop activity during active week | Original period retained; no future date immediately failed, no early charity posting or invented proration |
| AC-042 | Period ends while app closed | Foreground derives awaitingReview accurately; midnight background execution not required |
| AC-043 | Review with missing dates | Must enter them or explicitly acknowledge named missing dates receive no return |
| AC-044 | First weekly review | Opening R/A/M events posted once; no payment/donation automatically recorded |
| AC-045 | New week while older unpaid/awaiting review | Allowed if interval nonoverlap; old work remains visible |
| AC-046 | Change next week | Prior targets, entries, allocation schedule, assessments and support terms unchanged |
| AC-047 | Higher target, more actual steps but lower completion | History shows both actual walking and applicable target; no misleading success-only chart |
| AC-048 | Cross-month/cross-year week | Outcome attribution uses plan start date; settlement summaries use effective payment date, labelled distinctly |

## 7. Corrections and external settlement

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-049 | Reviewed five-base week corrected to four-base | R changes 1200→400; A 2300→3100; with cap1000, M 1000→400; rereview required |
| AC-050 | Same correction before rereview | Provisional revision exists; no compensating financial events posted yet; new settlement posting disabled |
| AC-051 | Confirm corrected review | Deltas personal −800, charity +800, supporter −600; prior reviewed events preserved; cumulative values equal new R/A/M |
| AC-052 | Prior settlements personal1200/supporter1000/charity2300 | After corrected review, personal excess800, supporter excess600, charity outstanding800; never cross-offset categories |
| AC-053 | Correction increases R after charity was recorded | Preserve donation, display excess charity if target fell; no automatic refund/repayment claim |
| AC-054 | Source edit with same rounded financial result | Preserve edit and require rereview for a reviewed week; financial deltas zero, not duplicate opening events |
| AC-055 | Partial supporter receipt | R=1400/cap2000 gives target1400; receipt500 gives outstanding900; received500 remains separate from earned1400 |
| AC-056 | Invalid settlement | Zero/negative/future-date/above-outstanding rejected; cannot record against an unreviewed week |
| AC-057 | Duplicate settlement submission | One record and audit event; no double receipt |
| AC-058 | Correct mistaken settlement | Reason required; original preserved via void/replacement; target assessment unchanged |
| AC-059 | External exception/resolution | Note and flag preserved; neither walking result nor numerical discrepancy silently disappears |
| AC-060 | Repeat corrections/relaunch/replay | Effective entries, reviewed amounts, events and settlements remain idempotent |

## 8. Dates and timezone fixtures

- **AC-061 — Spring DST:** America/Toronto, 2026-03-02 through 2026-03-08 inclusive; exclusive end 2026-03-09 local midnight. Exactly seven dates and 167 elapsed hours. No missing daily opportunity.
- **AC-062 — Autumn DST:** America/Toronto, 2026-10-26 through 2026-11-01 inclusive; exclusive end 2026-11-02 local midnight. Exactly seven dates and 169 elapsed hours. Repeated clock hour does not create an eighth date.
- **AC-063 — Travel:** active Toronto week, device switches to another timezone. Plan dates/entries and financial boundaries stay pinned; UI identifies plan timezone.
- **AC-064 — Sheet across midnight:** step sheet opened for Day 3, saved after Day 4 begins. Prompt about date context; no silent reassignment/addition.
- **AC-065 — Clock jump/relaunch:** period state is recomputed without deleting records or posting duplicate assessments. The MVP does not claim tamper-proof activity/time verification.
- **AC-066 — Two planned intervals with different timezones:** reject absolute overlap even when local date labels differ.

## 9. Sharing and privacy

- **AC-067:** Invitation/progress/final exports reflect the same values as their source screen and assessment revision.
- **AC-068:** Every export includes dates, timezone, as-of timestamp, static/manual disclosure, and provisional/reviewed/correction status.
- **AC-069:** Default export excludes private motivation, notes, handler details, unrelated weeks, and backup data. Progress-only can omit money.
- **AC-070:** Share preview shows exact financial disclosure. Cancelling changes no plan/agreement/settlement. Sharing does not mark the supporter joined. Drafts export only draft-labelled invitations; unreviewed corrections cannot export new values as final.
- **AC-071:** Regenerating a file after correction leaves the old external file unchanged; app explains nonrevocability.
- **AC-072:** Image and text contain equivalent substantive information; long labels wrap without hiding currency, limits, or status.

## 10. Persistence and recovery

- **AC-073:** Complete setup, entries, review, support, partial receipts, and corrections survive termination/relaunch and work offline.
- **AC-074:** Inject failure during an atomic mutation; no half-saved step/reward/audit state, and input remains recoverable.
- **AC-075:** Storage cannot open; show recovery/error, never silently create an empty substitute store or overwrite records.
- **AC-076:** Full backup export → clean-store restore round-trip preserves IDs, events, rule versions, assessment amounts, source revisions and settlements.
- **AC-077:** Reject unsupported schema, duplicate IDs, broken references, invalid cents, inconsistent assessment, or malformed date input before replacement; existing store unchanged.
- **AC-078:** Restore failure during commit preserves current store. No partial merge or new transactions.
- **AC-079:** Deleting local data needs explicit confirmation and backup option; exported files and outside obligations are not claimed to be deleted.
- **AC-080:** No personal activity/financial details in production logs; temporary sharing files cleaned where possible.

### Walkthrough improvement coverage — 2026-10-25

The following are required outcomes, not test-result claims. Use deterministic data and failure injection where relevant.

| ID | Scenario | Expected outcome |
|---|---|---|
| AC-081 | Fresh five-screen setup | Everyday goal → weekly amount/arrangement → higher goal → consistency → review; amount known before financial option previews, with the own-money/charity/outside-app mechanism explained |
| AC-082 | Enable higher goal with C=3500, no consistency | Explicit warning that everyday-only return drops; everyday=125/day and higher=500/day, alternatives not stacked; all-seven-everyday example=875, full return still requires seven higher days |
| AC-083 | Leave charity blank at setup | Valid amount/handler permits confirmation; original charity remains blank, no invented destination or skipped-allocation policy, Choose later displayed consistently |
| AC-084 | End unnamed plan with positive charity amount | Review blocked until destination saved; save creates one destination record/audit event without changing original terms, entries, assessment amounts, or financial formula; review then permitted |
| AC-085 | Review unnamed plan with zero charity, then correct to positive | Initial zero-charity review allowed; corrected positive review blocked until destination exists; earlier review/history retained |
| AC-086 | Repeat or replace later destination | Same trimmed destination is idempotent; different destination, second record, or a record for originally named/voided/unconfirmed plan rejected; no terms overwrite |
| AC-087 | Restore destination history | Original schema-v1 file without new optional collection/flow version decodes; additive records round-trip; duplicate plan/transaction, unrelated actor, invalid timing, or positive reviewed unnamed allocation rejected before replacement |
| AC-088 | Resume an earlier-order saved draft | All entered values preserved; old stage maps to the same conceptual screen in the new order; current flow version recorded; Review remains Review |
| AC-089 | Type rapidly then Continue/Back/Save & close | Typing saves coalesce; valid transition flushes final text and next stage exactly once, unchanged saves are no-ops, relaunch resumes durable values |
| AC-090 | Inject draft save failure / discard / confirm | Failure keeps screen/input and retry; close does not claim success; pending autosave cannot recreate a discarded/confirmed draft; failed confirmed mutation leaves recoverable draft |
| AC-091 | Create/resume from each empty tab | Today, My Plan, Progress, and Money use the same draft and Continue your walking plan label; no duplicate drafts/commitments |
| AC-092 | Support choice and initial share type | Invite opens Invitation without activating support; Record opens existing-agreement fields; progress opens Progress; reviewed-summary action opens Reviewed; corrections cannot export new values as reviewed |
| AC-093 | C=3500 and supporter limit=35000 | Explanation shows dollar-for-dollar weekly rule and maximum possible match=3500; higher cap does not multiply it; each eligible confirmed week resets its cap, unused stays with supporter |
| AC-094 | Calendar and history across changed targets | Missing, explicit zero/below, everyday, higher, future, and no-plan dates remain distinguishable; thresholds are those preserved for each plan; a later goal never reclassifies the earlier record |
| AC-095 | Nonoverlapping plans share local date key in different zones | Month groups rather than overwrites both records; selected date shows both with saved zones and correct week links; no false absolute-overlap acceptance |
| AC-096 | Open a historical Progress week | Opens seven-date walking detail with original targets/records first, plus secondary plan/money links; does not route directly to the agreement |
| AC-097 | Upcoming plan and no reviewed history | Today/Money show readiness/start/goals or possible amounts; no missed future dates, earned-zero dashboard, or empty reviewed-total card; no automatic donation |
| AC-098 | Estimated/reviewed amounts without outside records | State/period labels remain beside the correct values; no record is not called unpaid; reviewed totals exclude current estimates and preserve last reviewed values during correction |
| AC-099 | New controls at accessibility sizes / VoiceOver | Footer remains usable with keyboard; validation identifies missing field; native calendar selection has readable date/state/zone detail; charts have dated text equivalents; essential distinctions do not rely on color |
| AC-100 | Invitation image and text | Personal request, goals, dates, commitment, possible match, next outside conversation, and limits readable in both formats; no private reason/notes or daily activity ledger in invitation; no acceptance/payment claim |

## 11. Invariant/property verification

Across representative/random valid inputs, assert:

1. Daily maxima sum to D; D+K=C, including commitments not divisible by seven/five.
2. Personal return and charity allocation are nonnegative, bounded, and sum to C.
3. Matching and unused allowance sum to the applicable cap; absent support leaves personal results unchanged.
4. Increasing one day's steps with fixed rules never reduces R or M.
5. Highest-goal success on every date returns exactly C in every configuration.
6. Changing personal commitment does not change recorded step qualification or which dates met base/stretch.
7. Re-evaluation of identical inputs/revision never changes outputs or creates additional posted events.
8. Historical rule versions reproduce their original values after newer defaults are introduced.
9. Cumulative assessment bucket events equal latest reviewed outcomes; raw settlement records do not change those outcomes.
10. Correction or recurrence in one week does not mutate another week's immutable terms or entries.

## 12. Visual and accessibility verification

Use the scene matrix in [UX specification §14](UX-SPEC.md#14-accessibility-and-visual-acceptance). Check compact/standard iPhone widths, light/dark, default/accessibility text sizes, VoiceOver, Reduce Motion, keyboard and sheet presentation. Check actual contrast, not only token definitions.

End-to-end journeys:

1. Solo single-goal plan → entries → missing-day review → personal return/donation records → repeat.
2. Two goals + consistency → external supporter agreement → shared snapshot → reviewed summary → partial supporter receipt.
3. Standing agreement → unchanged next week → changed target week → renewed agreement or solo continuation.
4. Historical correction after settlements → rereview → visible excess/outstanding → outside-resolution note.
5. Backup → restore → continue entries and settlement without duplicates.

## 13. Required delivery evidence

An implementation handoff must state which checks actually ran, results, device/simulator and OS used, screenshots inspected, any outstanding failures, and unimplemented scope. Specification validation alone is not an application test result. Do not claim payment, independent activity verification, live supporter access, or public-release readiness from this MVP's tests.

## 14. Specification checks performed — 2026-10-24

The documentation package itself was checked before delivery:

- All 28 authored numerical fixtures matched a separate integer-cent formula evaluation, including every expected daily and aggregate field. An independent reviewer also checked these examples and cross-document consistency.
- Both documented Toronto daylight-saving weeks were checked using calendar dates and an IANA timezone database: seven dates, respectively 167 and 169 elapsed hours.
- Forecast examples, correction deltas, capped matching, and remainder-cent examples were checked against the stated rules.
- At the original v0.1 delivery, all 80 acceptance IDs were unique and contiguous. All 28 fixture IDs were unique. The v0.2 scenarios below extend coverage; this historical check does not certify the additions.
- All 38 internal links across the implementation and current continuity documents resolved; referenced section anchors and Markdown code fences were checked.
- The implementation bundle was checked for portability and independence: no machine-specific paths or references to another product are required.
- Proposed semantic foreground/background contrast pairs were calculated; actual rendered accessibility remains an implementation check.

These were specification checks performed before application development. They did not include an application build, application test suite, simulator/device run, screen rendering, or payment/health integration. Current implementation verification is recorded separately in the repository README. Provisional product defaults remain identified as such in the baseline.
