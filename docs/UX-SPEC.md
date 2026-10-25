# Bloomed — Experience and Interface Specification

**Document:** BLM-UX-001 · **Version:** 0.2 · **Date:** 2026-10-25

**Authority:** [PRD](PRD.md). The owner authorized implementing the walkthrough improvements; exact layouts, copy, and interaction details remain implementation selections rather than separately approved design decisions. Use the integrated Open loop identity and preserve the existing green palette.

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
- Use the native navigation title; avoid repeating it with a generic marketing headline on populated tabs. First-use/setup titles may use large-title style, semibold/bold. Step total: large numeric display with monospaced digits and a scalable size near 44 points at the default text setting. Money amounts: title/title2; labels: body/subheadline. Financial rules never rely on tiny footnotes.
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
    Everyday goal → weekly amount/arrangement → optional higher goal
    → optional consistency → dates/review → confirm → optional support

Today       My plan                 Progress              Money
  Steps       Current agreement      Current week           Current outcome
  Goals       Support arrangement    Week / Month           Reviewed totals
  Returns     Share                  Historical day/week    External records
  Consistency Next-week draft                              Reconciliation

Settings: name/preferences, progression prompts, backup/restore, delete local data, about
```

Tabs remain available when no plan exists, with purposeful empty states explaining the information that will appear there. Today introduces own money earned back through walking, the unearned portion for charity, and outside money handling before setup. Do not rely on App Store familiarity. All four empty tabs can create the plan or **Continue your walking plan** when a draft exists; every route resumes the same saved draft. Do not force unrelated screens before recording today's steps.

Use internal chevrons and one whole-card navigation target. A diagonal outward arrow must not imply a different destination from the card's text. Keep essential choices/consequences visible; reserve expandable sections for schedules, calculations, and uncommon details. An information notice has a consistent role and treatment, not a requirement to repeat identical unrelated text on every tab.

## 4. Onboarding screens

### O1 — Everyday goal

Title: **Choose your everyday goal.** Prompt: “How many steps could you aim for each day, including a busy day?”

Whole-number input with steps/day unit; 3,000/5,000/7,000 suggestion chips are examples, not recommendations or already accepted values. One brief tip suggests short walks within existing routines. Collapse **Your reason · optional**; explain that it stays private and is excluded from shared summaries.

### O2 — Your weekly amount and outside arrangement

Title: **Choose an amount for this week.** Explain immediately: this is the participant's own money, walking determines what is earned back, and after review the rest is for charity.

No prefilled stake. CAD is visible and invalid amount messages identify allowed bounds/precision. Once valid, show the total available to earn back; higher/consistency options and exact amounts follow.

**Who keeps the money?** uses a native menu with participant-keeps, someone-else-holds, and another-arrangement choices. Only the latter two require a short description. Keep “Bloomed does not collect or transfer this money” visible. **Charity or cause · optional for now** may be blank. Explain Choose later: a destination is required before reviewing a positive charity amount, and the participant arranges the donation. Additional charity-record detail is expandable.

### O3 — Optional higher goal

Title: **Add a higher daily goal?** Toggle: **Add a higher goal**, initially off.

Off: the everyday goal earns the full daily amount. On: visibly warn that adding a higher goal lowers the amount earned at the everyday goal. Require a valid higher repeatable target. Show actual amounts for both targets, without stacking, and an all-seven-everyday-days example against the participant's own weekly amount. This makes the unchanged 25% everyday-only tradeoff tangible. Use ranges when cents differ and give access to the exact dated schedule before confirmation.

### O4 — Optional consistency

Title: **Include a consistency goal?** Toggle: **Include consistency**, initially off.

Explain any five of seven everyday-goal days, nonconsecutive, higher-goal days count. Show the actual consistency amount taken from the same weekly amount, the daily amount remaining, and the updated daily amounts. State that this is the participant's own money, not an extra payment. Keep the exact 20%/round-down/four-does-not-qualify explanation in **How this amount works**. No configurable challenge menu.

### O5 — Dates and review

Title: **Review your week.** Prompt: “Check your goals, dates, and money before you confirm.”

Sections:

1. Native compact start-date selector; adjacent **Start today**/**Start tomorrow** shortcuts; full seven-day range; human-readable time zone with Change and a short explanation that it stays fixed when travelling.
2. Daily amounts next to their step thresholds; explain higher amounts replace, rather than add to, everyday amounts. **Amounts for each day** reveals all seven preserved dated amounts; identify one-cent variation in the summary.
3. Consistency amount and exact five-of-seven condition when enabled.
4. Weekly amount, full-return requirement, charity destination or Choose later, and who keeps the money.
5. When repeating, prior/new targets and amount with preserved-history explanation; applicable recurring support preview.
6. Visible manual/outside-money explanation and the original seven-day rule if activity stops early; exceptional arrangements disclosed separately.

For a today start, explicitly say the whole day's steps count, including before confirmation. Full return requires the highest selected goal on all seven dates; five qualifying dates alone are insufficient.

Primary: **Confirm this week's plan**. Success shows the saved dates, everyday/higher goals, weekly amount, and “No money has moved,” then **Done** and **Invite a supporter · optional**. The support entry offers inviting or recording as separate choices, not an assumed accepted agreement.

### Draft and footer behavior

Show Step N of 5 and the named stage with a five-part progress bar. When resuming, identify the saved draft and current stage. All entry-point resume labels are **Continue your walking plan**. Earlier saved draft stages map into the new order without clearing fields.

Keep Continue/Back in a footer that remains usable with the keyboard and larger text. A disabled Continue includes the specific missing requirement. Provide a keyboard Done action and interactive dismissal where safe.

Typing autosaves are coalesced after 350 ms; show Saving draft while pending. Continue/Back save before the step changes, and Save & close/confirmation/backgrounding/disappearance flush pending changes. Save failures preserve values, identify the error, and offer retry. Prevent interactive dismissal while saving, failed, or submitting. Do not report the original lag's cause as proven; validate single-activation transitions on device.

## 5. Today

### 5.1 Default hierarchy

1. Bloomed wordmark, current plan date, and Day N of 7.
2. Main step card: actual total or `Not recorded`, progress track, base and optional stretch markers.
3. Primary action: **Update today's steps**.
4. Money earned back today, with an adjacent estimate label while unreviewed.
5. Weekly walking strip; optional consistency explains “N of 5 days at your everyday goal” and its amount.
6. Compact supporter card with the person, matching limit, and clearly weekly estimate; Money holds detailed calculations.
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
| No plan | Explain the walking/own-money/charity mechanism, then `Create your walking plan` or `Continue your walking plan`; no fake steps, money, or supporters |
| Upcoming plan | Start date, preserved goals/amount, and View plan; no zero-day dashboard, missed future dates, or future-date entry |
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

Use everyday/higher goal, weekly amount, and earned-back language. Show the effective charity destination; if blank, say Choose later and explain it can be named during a positive-charity weekly review. Actions: Share, separate Prepare invitation/Record an agreement already made or View recorded agreement, Adjust next week, and Review this week when ended. If a next week is already confirmed, show it as a distinct upcoming agreement with its own dates/budget; do not merge it into the active card. Put exceptional notes and scheduled-plan voiding in a clearly labelled secondary menu, not beside ordinary step entry.

Active terms are read-only. Explain future changes next to `Adjust next week`; do not put a hidden destructive edit behind an ordinary field.

### 6.2 Support agreement

Empty: explain matching, then separate **Prepare invitation** and **Record agreed match** decisions. Preparing opens the Invitation preview. Recording opens terms already discussed outside Bloomed; do not put the full form in front of someone only preparing an invitation.

Record form: alias, weekly cap, covered week/standing coverage, agreement date, optional note, and required `We agreed to this outside Bloomed` acknowledgement. The form does not send a notification or authenticate the supporter.

If recorded during an active week, default to next week. Selecting current week requires confirmation that coverage includes the whole week and previously recorded progress. Preview the immediate match.

Explain the actual maximum as min(weekly amount, agreed limit), including why a limit above the weekly amount does not multiply a dollar-for-dollar match. Recurrence copy says the limit resets for each whole eligible week that the participant confirms; it is not a total across the date range. Saved card: **Agreement recorded by you**, alias, dollar-for-dollar rule, weekly limit, dates, and recurrence where applicable. No “verified supporter,” “funded,” or “accepted in app” badges.

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
5. Missing-date acknowledgement when required; a destination input/save action if a positive charity amount has no destination.
6. **Confirm weekly review**.

Before confirmation, label amounts `Awaiting review`. Explain that confirmation records the result from entered activity and does not verify exercise or transfer money. Missing dates cannot be skipped accidentally: list them and require explicit acknowledgement that they receive no return.

A blank setup destination never changes the charity formula. Save a later charity choice as an immutable audited record, not a change to the original agreement. A positive charity amount cannot be reviewed without this choice; a zero-charity result can. If a later correction creates a positive amount, require the destination before corrected review. Show the effective destination consistently in plan, money, review, repeat drafts, and exports.

After confirmation: **Record money received, kept, or donated**, **Share reviewed summary** (opens Reviewed), and next-week actions. Review does not demand immediate payment and does not block another week.

## 8. Progress

### 8.1 Week view

Use a native segmented **Week / Month** control. Week presents the current plan's dates and state. An upcoming plan explains its start and goals instead of displaying zero progress. A cancelled-before-start plan retains its dates and targets as history.

For an active/ended week, show actual total, recorded-day coverage, average across recorded dates, and seven bars with the everyday-goal line. Seven readable dated rows expose actual steps or Upcoming/Not recorded, and the target reached. Missing dates are not known zero activity; explicit zero reads 0 steps. Future dates cannot be entered. Preserve the plan's original everyday/higher thresholds.

### 8.2 Month view

Use the native month calendar with selectable dates. Six states are distinct through symbols and readable selected-date detail: no plan (no marker), upcoming, not recorded, recorded below everyday goal, everyday goal reached, and higher goal reached. Zero is a recorded below-goal value, not missing.

Selecting a date shows actual steps/status, saved timezone, preserved targets, and **View this week's walking**. The calendar groups by each plan's local date key. Two nonoverlapping absolute plans can share a local date label after timezone changes: use a stacked marker and show both records with their zones instead of overwriting one. Include a Calendar key and readable text/announcements; chart decoration alone is insufficient. No botanical/plant stages or monthly financial aggregation are required by this implementation.

### 8.3 History and first use

Newest-first week cards show dates, status, original goals, and recorded-day coverage/actual steps when applicable. They open **Weekly walking**, containing all seven dates, preserved goals, records, and secondary links to that week's plan and money. Do not send the main Progress history action directly to an agreement screen.

Empty Progress explains daily records, reached goals, week history, and the month view, then offers Create/Continue your walking plan. No sample records enter storage. Later target changes never reclassify earlier days. All views read the same historical records rather than maintaining a separate classification cache.

## 9. Money

### 9.1 Current-week presentation

An upcoming card shows the weekly amount, date range/start, and maximum own-money return and optional match. It does not display a zero-earnings dashboard or imply missed days/donations before the week starts.

Active/awaiting-review cards distinguish **Earned back so far · estimate**, optional consistency included in that amount, and **Supporter match · estimate**. During activity, Still available is an estimate from PRD §7.5; a separate not-earned-on-ended-days amount appears only when positive. Explain that missing entries/corrections can change it. Reviewed values use reviewed labels and remain calculations rather than proof of money received.

Hide **All reviewed weeks** until a reviewed week exists. Its personal, supporter, and charity totals exclude unreviewed estimates and retain the last reviewed values while a correction is pending. All amounts have visible CAD context.

Empty Money explains earned-back money, extra matches, and recorded donations, with Create/Continue your walking plan. Keep the outside-money boundary visible in plain language.

### 9.2 Weekly financial detail

Separate **Your money earned back**, **Extra supporter match**, and **For charity**. Before review, label estimates beside values and explain review is required before recording money. During an upcoming week, show possible amounts and conditions instead of zero calculations. Display the effective destination or a Choose later explanation.

After review, distinguish Reviewed amount, Recorded by you, and **No outside record for** the difference. No record does not mean an amount is unpaid or that money has not changed hands. A correction may produce an excess-record warning; history preserves it. Keep supporter unused allowance separate, with no charity claim.

Actions:

- **Record money kept** when the participant holds their funds.
- **Record money returned** when another holder returns them.
- **Record supporter money received**.
- **Record a donation**.

**Money recorded outside Bloomed** lists dated participant records and saved corrections, with access to calculations/change history. Amounts are not spendable app funds. No Withdraw action, bank-balance visual, or animated transfer graphic.

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

Direct actions open the correct initial type: Prepare invitation → Invitation; Share this week's progress → Progress; Share reviewed summary → Reviewed. The shared preview may then offer the other valid types. Preview → system share sheet remains explicit; nothing is sent in the background.

Drafts can produce only a draft-labelled invitation. A correction awaiting review cannot produce a final-labelled summary of its new values. Voided plans are historical records, not active invitations or progress exports.

Preview has an explicit `Include financial details` choice for progress exports; invitation financial content is clearly shown. Private reason, notes, handling details, and unrelated history remain excluded. Show the exact generated image and offer a readable text version.

Export layout:

1. Bloomed wordmark, type, and optional display name.
2. A personal headline/introduction appropriate to the recipient: invitations ask for help building a walking routine; progress/review explain the recorded week.
3. Dates, human-readable timezone, and proposal/review status.
4. Everyday/higher goals and consistency rule.
5. Recorded activity summary and seven dates for Progress/Reviewed; invitations omit the daily activity ledger.
6. Separated own money and extra match when selected/applicable. Invitations show the participant's commitment, maximum possible match, and a clear outside-conversation request. An unnamed destination says not chosen yet.
7. Next-step explanation, as-of timestamp, and concise static/manual/outside-money disclosure.

Use comfortable section spacing and wrapping in both image and selectable text. A supporter unfamiliar with Bloomed should understand the request without interpreting an accounting report.

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
| Money earned back · estimate/reviewed | Profit / app cash balance |
| Supporter match · estimate/reviewed | Supporter payment received before recording it |
| For charity / planned donation | Donated before an external record |
| Agreement recorded by you | Verified / funded / supporter accepted in app |
| Ready for weekly review | Week paid / settled automatically |
| Check outside records | App debt / unpaid when no outside record / automatic recovery |
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

Required visual QA scenes: fresh install; single-goal active week; two-goal active week; consistency enabled/disabled; no entry/zero/below/base/stretch; supporter absent/present/capped; upcoming week; missing-day review; reviewed and partial settlement; correction with excess donation; next-week changed goals; empty and populated Week/Month history; same-local-date records with different timezones; optional setup destination and positive-charity review; draft autosave/flush failure; correct invitation/progress/reviewed initial preview; store failure; backup restore rejection. Review light/dark and large text, including a compact-width iPhone.

Do not claim visual QA occurred merely because these scenes are listed. Capture and inspect implemented screens during development and record actual evidence in the implementation delivery.
