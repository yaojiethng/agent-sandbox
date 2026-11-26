---
date: 2026-11-23
milestone: M3.4.2 - The resolution model and record primitives
type: Plan
status: Closed
---

# Handover - the review's design debts have a task-list home

## Objective

The three design debts the thermonuclear review named are open rows under M3.4.2, each with an outcome, a mechanism and the review handover that raised it.

## Scope

Record write-back only: the record-read API, the catalogue field vocabulary and the timestamp invariant scope. The `stop_probe.sh` size note and the `env_resolve_identity` name/dir duplication stay notes, not rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The record-read API is an open M3.4.2 row with its outcome and mechanism. | `grep -n 'The record read is one cached primitive' devlog/roadmap.md` | Agent [x] |
| The catalogue field vocabulary is an open M3.4.2 row with its outcome and mechanism. | `grep -n "The catalogue's fields are one vocabulary" devlog/roadmap.md` | Agent [x] |
| The timestamp invariant scope is an open M3.4.2 row with its outcome and mechanism. | `grep -n 'The timestamp invariant states its scope' devlog/roadmap.md` | Agent [x] |
| Each row cites the review handover that raised it. | the same greps show `20261123-04` | Agent [x] |
| No file outside the roadmap and this handover changes. | `git diff --stat` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The rows sit under M3.4.2, not a new milestone. | Each owns a subject the resolution milestone already carries: the record primitive, the catalogue and the timestamp invariant. | This table; `devlog/roadmap.md` |
| `stop_probe.sh` and the `env_resolve_identity` duplication stay notes. | They are a size concern and a small cleanup, not design debts with an outcome of their own. | This table |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | Three open M3.4.2 rows added from the review. |
