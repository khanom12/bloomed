# Bloomed — Experience and Interface Specification

**Document:** BLM-UX-001 · **Version:** 0.1 · **Date:** 2026-10-24

**Authority:** [PRD](PRD.md). All visual tokens and layouts below are proposed design defaults, not a separately approved final brand identity.

## 1. Experience objectives

Bloomed should feel calm, precise, personal, and encouraging. The participant should understand today's opportunity, the weekly agreement, and financial outcomes without learning a financial system.

The main interaction is recording one daily step total. The weekly interaction is reviewing results and confirming the next plan. Support is optional and never blocks either action.

Design priorities, in order:

1. Understand the target and record steps easily.
2. Understand what is calculated, what is provisional, and what happened outside the app.
3. Understand the whole weekly commitment before confirming it.
4. Preserve and explain history.
5. Invite support privately with a useful, understandable summary.

Do not present deposit, payout, live monitoring, activity verification, or donation execution as available capabilities. Avoid financial dashboards full of balances before a person has entered their first plan.

## 2. Proposed visual system

### 2.1 Direction

Use warm neutral surfaces, dark evergreen text, a restrained green accent, generous spacing, and a strong typographic hierarchy. Botanical cues may appear as small, original line motifs or native shapes. Essential status must remain understandable without decoration.

The owner requested a simple identity and its integration on October 24, 2026. Use the Open loop identity in [the brand kit](../Brand/v1/README.md): an open-b symbol, outlined lowercase wordmark, and a small family of route/loop motifs. Reserve the full lockup for the Today header, shared summary, and About section. Use restrained decorative artwork in the walking and progress empty states; native symbols remain appropriate for controls and financial records. Do not make a decorative plant die after a missed day or give an illustrated hero priority over step entry.

### 2.2 Semantic colors

| Token | Light | Dark | Purpose |
|---|---|---|---|
| `background` | `#F6F8F5` | `#111B16` | Screen canvas |
| `surface` | `#FFFFFF` | `#19271F` | Cards and input surfaces |
| `ink` | `#172B24` | `#F0F5EF` | Primary text |
| `secondaryInk` | `#52645A` | `#B5C5B8` | Secondary text |
| `accent` | `#23634B` | `#A0D5AF` | Primary actions and goal progress |
| `accentSoft` | `#E8F1EB` | `#263D2E` | Selected/achievement surfaces |
| `onAccent` | `#FFFFFF` | `#13271B` | Filled action text |
| `warning` | `#805600` | `#EAC571` | Review/reconciliation text and icons |
| `warningSoft` | `#FFF3D6` | `#3B3019` | Review panels |
| `destructive` | `#A32B35` | `#FFB4BA` | Destructive actions and errors |
| `divider` | `#D7E1D9` | `#3C5142` | Decorative separators; not a sole essential boundary |

Use opaque text colors for essential labels; reducing opacity changes contrast. Controls needing a visible boundary must use an appropriately contrasting outline or another clear cue, not the decorative divider alone.

Calculated sRGB contrast for this token set: light secondary text on surface ≈6.31:1, light accent on surface ≈7.10:1, dark secondary on surface ≈8.62:1, dark accent on surface ≈9.35:1, filled-button text ≥7.10:1. Recheck actual rendered combinations, disabled states, overlays, and future changes. These calculations are design checks, not an accessibility certification.

Use at least 4.5:1 for ordinary text and 3:1 for large text, with non-color cues and adequate meaningful-control contrast. Reference: [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).

### 2.3 Typography, layout, and components

- System font and text styles with Dynamic Type; no downloaded font dependency.
- Screen title: large-title style, semibold/bold. Step total: large numeric display with monospaced digits and a scalable size near 44 points at the default text setting. Money amounts: title/title2; labels: body/subheadline. Financial rules never rely on tiny footnotes.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32 points. Standard screen margin 20; card inset 20; card radius 20; input radius 12.
- Primary button minimum height 52 at default type; all interactive targets at least 44×44 points and allowed to grow. Native navigation and tab bars; no floating custom bar that hides content.
- At larger text sizes, side-by-side values stack; buttons wrap; financial values retain their currency label; cards expand vertically. Do not shrink essential text to fit.
- One primary action per card or decision. Native sheets for focused inputs; navigation pushes for full historical week details. Respect safe areas and keyboard insets.
- Bounded, subtle transitions of approximately 150–250 ms; respect Reduce Motion. No confetti or haptics are necessary for MVP correctness.

Reference platform guidance: [Apple accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility). These choices are Bloomed's baseline requirements; verify actual platform behavior during implementation.

### 2.4 Reusable components

`ScreenHeader`, `WeekRangeLabel`, `StatusBadge`, `StepProgressCard`, `GoalMarker`, `StepEntrySheet`, `SevenDayStrip`, `ConsistencyCard`, `MoneyBreakdownRow`, `ExternalStatusRow`, `AgreementCard`, `WeekHistoryRow`, `AssessmentComparison`, `InlineValidation`, `EmptyState`, `SaveErrorBanner`, `SharePreview`.

Reusable appearance must not hide business rules inside a UI component. Components consume already calculated values.

## 3. Information architecture

```text
First launch / no confirmed plan
  Create a walking plan
    Base → optional stretch → optional consistency → commitment/arrangement
    → dates/review → confirm → optional support invitation

Today       My plan                 Progress              Money
  Steps       Current agreement      Current week           Current outcome
  Goals       Support arrangement    Past weeks             Reviewed totals
  Returns     Share                  Historical day/week    External records
  Consistency Next-week draft                              Reconciliation

Settings: name/preferences, progression prompts, backup/restore, delete local data, about
```

Tabs remain available when no plan exists, with purposeful empty states. Do not force the person through unrelated screens before recording today's steps.

## 4. Onboarding screens

### O1 — Base goal

Title: **A walking goal for everyday life.**

Prompt: “What daily step count could you realistically commit to, including on a busy day?”

Whole-number input with `steps per day` unit, optional suggestion chips labelled as examples, and a short note that the user chooses a target appropriate to their circumstances. Suggest fitting short walks into existing routines; do not guarantee a number of steps per minute or claim a goal is easy for everyone.

Primary: `Continue`. Optional collapsed `Your personal reason` text field; never shared by default. Invalid/empty goal keeps the action unavailable with an explanatory label, not a color-only state.

### O2 — Optional stretch

Title: **Add a higher target?**

Toggle: `Include a stretch goal`, initially off.

When off: “One daily goal, one daily return.” When on: show input and explain that base earns a smaller return and stretch earns the daily maximum. Copy: “Choose a target you could repeat regularly, rather than your biggest possible walking day.” Enforce stretch > base.

### O3 — Optional consistency

Title: **Make room for consistency.**

Toggle: `Include a consistency return`, initially off.

Show one rule: “Reach your base goal on any 5 of the 7 days.” Explain that the days need not be consecutive, and that part of the same personal commitment is reserved for this condition. No configurable challenge menu.

### O4 — Money and outside arrangement

Title: **Choose your weekly commitment.**

Enter one seven-day amount with CAD visible. No prefilled stake. Explain: “Choose an amount you are comfortable committing, including the possibility that some will not be returned.” Show the developing daily/consistency allocation after valid input.

Require the external handling selection and charity description from PRD §4. Avoid charity logos, search integrations, and tax-receipt language. Explain that Bloomed records the agreement and will not take money.

### O5 — Dates and review

Title: **Review this week's plan.**

Sections in reading order:

1. Seven dates and timezone; start-date selector.
2. Base and optional stretch target.
3. Exact daily return schedule, expanding a seven-row list if amounts differ by cents.
4. Consistency reserve and exact qualification rule, if enabled.
5. Personal commitment and maximum personal return.
6. Charity and outside handling description.
7. Manual entry and external money explanation.
8. Original seven-day rules remain the calculation basis once the week starts; no automatic early-stop prorating.

For today start: “Today is Day 1. Your whole day's recorded steps count.”

For two targets: “Your full commitment is available by reaching the stretch goal on all 7 days.” For one target, substitute “daily goal.” Do not imply five qualifying dates guarantee a full return.

Primary: **Confirm this week's commitment**. On successful save, show dates and a calm confirmation, then `Go to Today` and optional `Invite a supporter`. Do not show a supporter agreement before one is recorded.

## 5. Today

### 5.1 Default hierarchy

1. Bloomed wordmark, current plan date, and Day N of 7.
2. Main step card: actual total or `Not recorded`, progress track, base and optional stretch markers.
3. Primary action: **Update today's steps**.
4. Personal return today, with provisional label while the week is unreviewed.
5. Optional consistency card, “N of 5 qualifying days,” with all seven dates.
6. Optional supporter weekly match card: amount earned so far and weekly cap.
7. Link to the full plan or weekly review when applicable.

The step total is more visually prominent than money. The progress track caps at the highest target while the displayed total continues above it. Two target markers must remain understandable with VoiceOver and without color.

No per-day supporter reward promise: weekly cap means the return-to-match relationship is shown at weekly level.

### 5.2 Step entry sheet

Title includes the selected full date. Use a whole-number keypad, current effective value, and `Save total`. Help text: “Enter the day's total steps. Saving replaces the previous total.”

Show applicable targets and proposed personal return. Provide explicit `Record zero steps` and, for existing records, `Clear recorded total`. Empty input does not silently record zero. Confirm clearing. Before correcting reviewed data, use the comparison flow in §10.

Prevent duplicate submission. On failure, preserve input and expose retry; success only after durable save. If midnight passes, show the selected date and ask whether to save to that original date or reopen today's entry; no silent reassignment.

### 5.3 Required states

| State | Presentation/action |
|---|---|
| No plan | `Create your walking plan`; no fake steps, money, or supporters |
| Upcoming plan | Start date and agreement preview; no future-date entry |
| Active, unrecorded | `Not recorded`; record action; distinguish from zero |
| Explicit zero / below base | Actual value, remaining steps, neutral language |
| Base reached | Base achievement; stretch opportunity if enabled |
| Highest goal reached | Goal reached; raw extra steps visible; financial maximum unchanged |
| Week ended | `Ready for weekly review`; open review, not a future step entry |
| No new week after completion | Previous result plus `Start another week`; no automatic obligation |
| Store/save failure | Saved data retained, factual error and retry; no reset to demo/empty state |

## 6. My plan

### 6.1 Current agreement

Show dates/timezone and status badge, base/stretch targets, exact daily returns, consistency, total personal commitment, charity destination, external handler, and applicable supporter agreement.

Actions: `Share`, `Invite a supporter` or `View support agreement`, `Adjust next week`, and `Review this week` when ended. If a next week is already confirmed, show it as a distinct upcoming agreement with its own dates/budget; do not merge it into the active card. Put exceptional notes and scheduled-plan voiding in a clearly labelled secondary menu, not beside ordinary step entry.

Active terms are read-only. Explain future changes next to `Adjust next week`; do not put a hidden destructive edit behind an ordinary field.

### 6.2 Support agreement

Empty: explain matching, show `Prepare invitation` and `Record an agreement`.

Record form: alias, weekly cap, covered week/standing coverage, agreement date, optional note, and required `We agreed to this outside Bloomed` acknowledgement. The form does not send a notification or authenticate the supporter.

If recorded during an active week, default to next week. Selecting current week requires confirmation that coverage includes the whole week and previously recorded progress. Preview the immediate match.

Saved card: **Agreement recorded by you**, alias, 1:1 rule, cap, dates, and recurrence where applicable. No “verified supporter,” “funded,” or “accepted in app” badges.

### 6.3 Continuation and progression

`Repeat this plan` creates a draft. `Adjust next week` opens the same draft with editable targets and budget. Show a before/after comparison at confirmation; previous weeks remain untouched.

If standing support no longer matches the proposed terms, show: “This plan differs from the recorded support agreement. Agree the changes outside Bloomed before applying support.” Allow confirming a self-funded week without support; never block independent participation.

Progression prompt: “You've been meeting these targets regularly. Keep this plan or adjust next week?” Buttons: `Keep this plan`, `Adjust next week`, optional `Not now`. No automatically selected increase or financial escalation.

## 7. Weekly review

Use a dedicated review screen reached from Today, My plan, Progress, or Money. All routes open the same record.

1. Dates and preserved plan targets.
2. Seven dated rows: actual steps or missing, level reached, daily return.
3. Consistency count and reserve outcome.
4. Personal return, charity allocation, supporter reward, unused supporter allowance.
5. Missing-date acknowledgement when required.
6. **Confirm weekly review**.

Before confirmation, label amounts `Awaiting review`. Explain that confirmation records the result from entered activity and does not verify exercise or transfer money. Missing dates cannot be skipped accidentally: list them and require explicit acknowledgement that they receive no return.

After confirmation: `Record external settlement`, `Share summary`, and `Prepare next week`. Review does not demand immediate payment and does not block another week.

## 8. Progress

### 8.1 Current week

Show seven dated bars or a seven-row list with actual steps, base/stretch reference, and goal state. Include totals/average for recorded dates with coverage explicitly labelled, such as `Average across 5 recorded days`; never treat missing dates as known zero activity. Financial assessment may still use zero return for missing dates under the PRD.

Show qualifying-date count and consistency result. Do not require monthly/yearly charts in MVP.

### 8.2 History

Newest-first week list. Each row includes dates, recorded-day coverage, actual total steps, base/stretch targets, qualifying-day count, and review status. Tap for the original agreement, dated results, and a link to that week's money detail.

Compare activity fairly when targets change: actual steps and historical targets are both visible. A later higher goal never changes the color/state of an earlier day under its original goal.

Future monthly/yearly aggregation can read the same dates. Do not build a separate history cache that loses applicable target versions.

## 9. Money

### 9.1 Current-week presentation

Use two groups:

**Your commitment:** committed amount; personal return so far; optional consistency component labelled `Included in your return`; remaining walking opportunity from PRD §7.5 while active. Do not add the consistency component to a total that already includes it. Final charity allocation appears after review; before then show estimates without presenting them as already payable.

**Supporter matching:** applicable cap; calculated reward; remaining allowance; agreement recorded by participant. Omit the group when no agreement applies.

Use reviewed historical totals below the current-week card. Current/unreviewed estimates must not be mixed into those totals. All amounts include currency or have an unambiguous currency-labelled group heading.

### 9.2 Weekly financial detail

Separate rows for personal return, supporter reward, and charity allocation. Each has calculated target, external amount recorded, outstanding amount, and excess amount if a correction created one. Show original agreement, latest reviewed revision, and audit/revision access.

Actions:

- `Record return retained` when participant holds their funds.
- `Record return received` when another holder returns them.
- `Record supporter payment received`.
- `Record donation made`.

Amounts are not spendable app funds. No `Withdraw` action, bank balance visual, or animated transfer graphic.

### 9.3 External record sheet

Show category, week, current target, prior recorded amount, and remaining amount. Enter a positive amount, date, and optional note. Confirm: “This records what happened outside Bloomed. Bloomed does not transfer or verify money.”

Partial records are allowed. Reject more than the current outstanding target for a new record. Posted records show `Recorded by you` and a timestamp. Correcting a mistake requires a reason and preserves the original record; never erase it silently.

### 9.4 Reconciliation

Use a warning panel with exact before/after values and a plain explanation. A correction may mean more is outstanding or more was already recorded than the new assessment calls for. Do not say the app recovered money, that a charity owes a refund, or that a supporter automatically owes a new amount.

Show categories independently. A resolution note acknowledges an outside agreement; it does not hide a mathematical difference or alter recorded walking.

## 10. Historical corrections

For reviewed information, show the selected date, old total, proposed total, and impacts on daily return, consistency, personal return, charity, and matching. Require an explanatory reason and confirmation.

After saving, preserve the old assessment, label the new result `Correction awaiting review`, and direct the participant to review it. Keep prior external records. Do not allow fresh settlement posts against an unreviewed correction. If the final reviewed revision differs from recorded settlements, show reconciliation visibly.

A mistaken payment/donation record is corrected by voiding/replacing that record with a reason, independently of step corrections.

## 11. Sharing

Use `Share` → choose `Invitation`, `Progress`, or `Reviewed summary`, where applicable → preview → system share sheet.

Drafts can produce only a draft-labelled invitation. A correction awaiting review cannot produce a final-labelled summary of its new values. Voided plans are historical records, not active invitations or progress exports.

Preview has an explicit `Include financial details` choice for progress exports; invitation financial content is clearly shown. Private reason, notes, handling details, and unrelated history remain excluded. Show the exact generated image and offer a readable text version.

Export layout:

1. Bloomed wordmark and snapshot type.
2. Optional chosen display name.
3. Week dates and timezone.
4. Targets and consistency rule.
5. Recorded activity summary.
6. Financial groups when selected/applicable.
7. Status, as-of timestamp, manual/static/external explanation.

Financial exports distinguish own return from additional rewards. Invitation proposals differ visibly from saved outside agreements. Sharing never marks a proposal accepted.

Use a deterministic fixed export style for legibility, with readable type and content that grows to fit. Long aliases/charity names must wrap or move to the text version without changing meaning. Exports must not capture app navigation, hidden notes, or full-screen screenshots containing unintended information.

Before first share, explain that recipients can keep or forward an exported file and Bloomed cannot revoke it. Cancelling the share sheet changes no app records.

## 12. Settings, backup, and recovery

Settings contains optional display name, locale display preferences, progression-prompt toggle, `Export backup`, `Restore backup`, `Delete local data`, and app information.

Backup export explains that this is a private full-record file, distinct from a supporter summary, and is not encrypted by Bloomed. Restore previews supported schema/version and record counts, offers current backup first, and explicitly confirms replacement. Invalid restore leaves existing data intact with a specific error.

Do not present persistent storage failure as an empty first installation. Offer retry/recovery without overwriting the failed store. Destructive reset must be explicit and separate from routine error recovery.

## 13. Copy and state language

| Use | Avoid |
|---|---|
| Not recorded | Zero steps when unknown |
| Below your goal | Failed / lazy / punishment |
| Personal return calculated | Profit / app cash balance |
| Supporter reward earned | Supporter payment received before recording it |
| Allocated to charity | Donated before an external record |
| Agreement recorded by you | Verified / funded / supporter accepted in app |
| Ready for weekly review | Week paid / settled automatically |
| Review external settlement | App debt / automatic recovery |
| Prepare next week | Subscribe / auto-charge |

No weight-loss promises, fasted-activity prompts, exercise prescriptions, or pressure to recover missed money with a larger target.

## 14. Accessibility and visual acceptance

- VoiceOver reads date, actual steps/missing status, applicable goals, qualification, and return in a coherent order.
- Labels and hints explain update, clear, correction, share, and external-record actions without duplicating decorative content.
- Charts and seven-day markers have readable equivalents; focus order follows the visual hierarchy.
- Accessibility text sizes do not truncate amounts, prevent review confirmation, cover controls with the keyboard, or hide warnings.
- Standard contrast and increased-contrast settings remain legible; essential states use text/icon/shape as well as color.
- Reduced Motion removes nonessential transitions without removing feedback.
- Forms identify specific invalid fields and return focus appropriately.
- Share text contains the substantive information in the image.

Required visual QA scenes: fresh install; single-goal active week; two-goal active week; consistency enabled/disabled; no entry/zero/below/base/stretch; supporter absent/present/capped; upcoming week; missing-day review; reviewed and partial settlement; correction with excess donation; next-week changed goals; empty and populated history; store failure; backup restore rejection. Review light/dark and large text, including a compact-width iPhone.

Do not claim visual QA occurred merely because these scenes are listed. Capture and inspect implemented screens during development and record actual evidence in the implementation delivery.
