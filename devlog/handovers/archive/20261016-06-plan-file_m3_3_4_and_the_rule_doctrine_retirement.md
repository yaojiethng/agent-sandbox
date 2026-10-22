---
date: 2026-10-16
milestone: M3.3.4 - The prose standards as principles
type: Plan
status: Closed
---

# Handover - File M3.3.4 and the rule doctrine's retirement

## Objective

File the new sub-milestone M3.3.4 with its rows, file its first principle, and file the retirement of the rule that a skill or a prompt can never hold a rule as M3.3.2's opening slice.

## Scope

`devlog/roadmap.md` only: the M3.3 intro, the Milestone Summary table, the new M3.3.2 opening row, and the new M3.3.4 section.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| M3.3.4 exists | its section and its summary-table row carry the same title and anchor | Accepted |
| Its first row files the principle | `communication-principle-show-dont-describe`, with the repo path, the install path and handover `20261016-07` | Accepted |
| The doctrine retires under M3.3.2 | its opening row names the eight carriers and the six | Accepted |
| The active milestone is unchanged | `active-milestone: M3.6.1 - Disable and ship OpenCode dispatch` | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| M3.3.4 is filed out of order | the operator directed it, and this milestone depends on M3.3.2, which is not started | the M3.3.4 scope paragraph |
| The doctrine retirement opens M3.3.2 | it is the contradiction the settled split already resolved, so it precedes the per-policy slices | the M3.3.2 row |
| Each standard is planned before it files | one planning task per source, then each spec files as its own row | the M3.3.4 rows |
| The principle shape is borrowed | `principle-minimize-reader-load` sets it, so no new shape work precedes the first principle | the M3.3.4 section |

## Decisions pending

| Decision | Why it waits |
|---|---|
| Whether a mechanical rule bundles as a script inside its principle skill | deferred to the plan, on operator direction |

## Findings

| Finding | Type | Impact |
|---|---|---|
| The rule named for dropping is eight lines across four files, plus six that state the same claim under other names, the canonical-owner test, policy membership and the policy map. | scope | it became M3.3.2's opening slice rather than an incidental edit |
| No handover was `Active` when this sidequest opened, so it names no parent and returns to nothing. | process | recorded rather than resolved by inventing a parent |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | the M3.3 intro count, the M3.3.4 summary row, the M3.3.2 opening row, the M3.3.4 section |
