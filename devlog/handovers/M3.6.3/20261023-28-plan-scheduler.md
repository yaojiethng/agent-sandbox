---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Plan
status: Closed
---

# Handover - The scheduler gets its own sub-milestone

## Objective

Give the class of work that outgrows both dispatch and the task queue a place in the roadmap, filed unscoped, so every mechanism can state its own boundary and stop there instead of proposing an extension of its neighbour.

## Scope

A new sub-milestone under M3.6, its summary-table row, one unscoped row inside it, and the three records that earlier proposed the task queue as the answer to finer control.

The seam this milestone records: dispatch is M3.6.3's, and a fine scheduler is out of scope, scheduled to its own sub-milestone. That gives one standard for judging a mechanism change, because a proposal either stays inside its own boundary or is filed here.

Out of scope: cutting the row into work units, its design, and any acceptance criteria. The row states what is known and what is unknown and stops, because a scope cut now would be a forecast made before the work has an owner.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The sub-milestone exists and appears in the summary table | `grep -n "M3.6.6 - The scheduler" devlog/roadmap.md` prints the table row and the section heading | Agent [x] |
| The row is open and states itself unscoped | `sed -n '/^##### M3.6.6/,/^### T/p' devlog/roadmap.md` carries `unscoped on purpose` and `not yet cut` | Agent [x] |
| The row separates what is known from what is not | the same range carries a `Known:` and an `Unknown:` clause | Agent [x] |
| No record proposes the task queue as the answer to finer control | `grep -rn "extends the queue\|finer control is the queue's" devlog/roadmap.md docs/adr devlog/handovers/20261023-26-design-seat_rule.md` prints nothing, and the sub-milestone's own ownership sentence is a statement of what each mechanism holds today | Agent [x] |
| The boundary reads the same in all three records | the M3.2.2 row, the ADR's edge case and the seat handover each point at this sub-milestone | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The sub-milestone sits under M3.6 | both mechanisms it subsumes serve this milestone's routing payoff, so the scheduler belongs beside them rather than in a new top-level group | [`devlog/roadmap.md`](../roadmap.md) M3.6.6 |
| The row is filed unscoped, with no acceptance criteria and no sequencing | a scope cut made before the work has an owner is a forecast; the row exists to hold the boundary and say what is known | the row, and this record |
| The three records point here instead of proposing an extension | a suggestion that the queue "could be used" leaves the reader to decide a boundary; naming the sub-milestone makes the answer one row a reader can open | the M3.2.2 row, [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md), and handover `20261023-26` |
| The summary table carries it as `Not started` | the state vocabulary has no entry for filed-and-uncut, and `Not started` is what the table says for a sub-milestone no iteration has scoped | the summary table |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The seat record had proposed `taskq_*` as the route for anything finer than a turn boundary, while the queue serves the workers pi spawns and would need extending for a mixed-runtime fan-out | record | a mechanism change would read the queue as the answer and extend it by accident | fixed here: the seat handover, the ADR's edge case and the M3.2.2 row now point at this sub-milestone |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | `##### M3.6.6 - The scheduler` with its objective, dependencies, sequencing, the measured seam and one unscoped row; a summary-table row reading `Not started` |
