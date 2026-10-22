---
date: 2026-10-19
milestone: M3.6.2 - Measure
type: Plan
status: Closed
---

# Handover - file the requests-per-completed-task metric

## Objective

File the requests-per-completed-task metric as a roadmap row under M3.6.2, because the free tier's scarce resource is requests and no aggregate in the ledger divides requests by a completed task.

## Scope

A planning iteration. It adds one roadmap row and resolves the pending decision that handover `20261019-08` left open.

Out of scope: the aggregate itself, and the definition of a completed task, which the outcome taxonomy's `success` already carries.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The row exists | read `devlog/roadmap.md`, the row `Requests per completed task` under M3.6.2 | Agent [x] |
| The row names its done predicate | the row ends with the ledger emitting the metric and a test | Agent [x] |
| The pending decision is resolved | this record states the resolution of the `## Decisions pending` row in `20261019-08` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`, `bash scripts/check_handover_format.sh`, `bash scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The metric is requests per completed task, per `(provider, model)` and per role | the free tier's cost is requests, not tokens, so a per-token price misranks a cheap model that needs many turns | the roadmap row |
| The metric is keyed to the outcome taxonomy's `success` | `The outcome and latency instrument` already defines the outcome vocabulary, so a second notion of completed is a duplicate | the roadmap row |
| The row sits under M3.6.2 | the instrument is a ledger aggregate, beside `The three aggregates` | the roadmap |
| `20261019-08` keeps its `pending` row, and this record is its successor | a closed state record is corrected by addition, so the successor entry carries the resolution | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The ledger measures cost per request and the outcome instrument plans an outcome per request, so the gap is one aggregate rather than a new instrument. | measurement | the row is small |
| A request is the scarce unit on the free tier, so the ranking a per-token price produces can invert the ranking a same-task comparison produces. | inference | the metric is the one that makes the constraint actionable |

## Completed

| File | Change |
|---|---|
| `devlog/roadmap.md` | new row `Requests per completed task` under M3.6.2 |
