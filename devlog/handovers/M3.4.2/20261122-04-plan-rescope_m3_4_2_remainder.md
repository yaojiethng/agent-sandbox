---
date: 2026-11-22
milestone: M3.4.2 - The resolution model and record primitives
type: Plan
status: Closed
---

# Handover - rescope M3.4.2's blocked remainder

## Objective

Move the three M3.4.2 rows that cannot close inside it to the milestones that own their subject, so the sub-milestone closes on three actionable rows.

## Scope

The M3.4.2 rows **The Makefile and the CLI keep two invocation idioms**, **Structured where it helps: JSON and the parser dependency** and **Remove the carrier census when its entries are resolved**. Each is blocked on work outside the milestone: T4's make evaluation, a record that demonstrably needs structure, and eleven unfiled defects in the census. No code changes.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Each blocked row sits in the milestone that owns its subject | `awk '/^#### T4/,/^#### T5/' devlog/roadmap.md \| grep -c 'two invocation idioms'` is 1; the same over T10 for the census and T11 for the structured-record row | Agent [x] |
| M3.4.2 carries only actionable rows | `awk '/^##### M3.4.2/,/^##### M3.4.3/' devlog/roadmap.md \| grep -c '^- \[ \]'` is 3 | Agent [x] |
| Every moved row names the move, its date and its dependency | `grep -n 'Moved from M3.4.2 on operator direction' devlog/roadmap.md` finds three, and the Makefile row carries its `**Depends on:**` | Agent [x] |
| No section intro still claims a moved row as foreign | `grep -n 'CLI and Makefile contracts moved' devlog/roadmap.md` prints nothing, and T11's intro names the JSON decision as its own again | Agent [x] |
| The record gates pass | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The Makefile invocation-idiom row moves to T4, under the make evaluation. | Its outcome is that evaluation's answer -- the work if make stays, a deletion if it goes -- so it belongs beside the gate that decides it, and T4 owns the make wrapper's future. The row keeps `**Depends on:**` the evaluation. | This table; `devlog/roadmap.md` T4 |
| The structured-record row moves to T11 in its trigger form. | T11's objective is the persisted record formats, "structured where structured pays"; the row was never a live question, and M3.4.2's decision of 2026-10-16 settled it with the reversal word `json-now`. | This table; `devlog/roadmap.md` T11 |
| The carrier census row moves to T10, re-scoped as a drain. | The census's remainder is a census of settings, carriers and precedence, plus document corrections -- T10's surface, not the resolution primitive. The re-scoped row states what it drains and where each cluster goes, so it can close. | This table; `devlog/roadmap.md` T10 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| T10's and T11's section intros still read as though the CLI/Makefile contract and the JSON decision lived in M3.4.2. | record | A reader following the intro looks in the wrong milestone for a row that had just moved back. | Fixed in this commit with both intros. |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | The three blocked rows move to T4, T11 and T10, each naming the move and its basis; the T10 and T11 intros are corrected. |
