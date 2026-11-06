---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - The seat rule is a walk, not a refusal

## Objective

Record what a seat count means, on operator direction, and correct the two records that state the opposite, so the consolidation row can be built without re-deciding it.

## Scope

The reserved term `role` and `role line` in `docs/reference/terminology.md`, the role-table ADR's rejected alternative, and the M3.2.2 row that owns the build.

The rule, as the operator stated it: given n seats and m candidates, where the candidates are the recommendation list filtered to the models reachable now, the seats fill by rotating through the candidates in a cyclic manner. In one line: seat i takes candidate ((i - 1) mod m) + 1. A request with n at most m runs distinct models, and one with n above m repeats them in order. There is no per-seat choice beyond that rotation, because an unreachable model never enters the candidate set. On failure the rule is the operator's: a retryable outcome retries the seat's own assignment, and an unretryable one drops the candidate and moves the seat to the next in the remaining rotation, wrapping to the first when the failed one was last. Seats fire concurrently within a turn and are read at its boundary, so a turn costs its slowest attempt rather than the sum of its seats, and the candidate set has one writer per turn. The wall clock the parallel runner has is therefore kept, and a reassignment still needs no lock, because the next turn reads a settled list.

Two records said otherwise. The term `role line` said fewer distinct entries than the request needs is a failure and that a seat is never filled by duplicating a model, and the role-table ADR rejected giving the reviewer seats a role line on the premise that one line names one assignment.

Out of scope: building the seat path, and rewriting the shipped reviewer section, which describes a runner that still behaves the other way. Both are the M3.2.2 row's work, and the row now carries the decision.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The term states the rotation, seat i from candidate ((i - 1) mod m) + 1 | `docs/reference/terminology.md` `## role` Scope and `## role line` Relationships | Agent [x] |
| The shortage-is-a-failure clause is gone | `grep -n "never filled by duplicating" docs/reference/terminology.md` prints nothing | Agent [x] |
| Candidates are filtered before seating, so no unreachable model is dealt | `grep -n "filtered to those that can be attempted now" docs/reference/terminology.md` | Agent [x] |
| The ADR's rejected alternative records the superseding rule | `grep -n "Superseded on 2026-10-23" docs/adr/single_source_model_recommendations.md` | Agent [x] |
| The consolidation row carries the decision instead of an open question | `grep -n "Resolved on operator direction, 2026-10-23" devlog/roadmap.md` | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seating is one rotation over the reachable candidates, with failure handled per seat | the simplest statement of the operator's rule: n seats, m candidates, seat i takes candidate ((i - 1) mod m) + 1; a retryable outcome retries, an unretryable one drops the candidate and continues the rotation | [`terminology.md`](../../docs/reference/terminology.md) `## role` and `## role line` |
| Seats fire within a turn and are read at its boundary | a turn gives concurrent wall clock and a single writer, so a reassignment reads a settled list and needs no lock, and a turn costs its slowest seat rather than the sum | this record, and the row |
| A turn boundary is this mechanism's limit, and finer control is a scheduler's | the seam is stated and the rest is filed as its own unscoped sub-milestone, so neither this mechanism nor the queue grows into the other by accident | [`M3.6.6 - The scheduler`](../roadmap.md#m366---the-scheduler) |
| The terms state the rule before the mechanism holds it | the alternative leaves a reader with two contradictory contracts and no statement of the intended one; the build gap is named in the row rather than hidden | the M3.2.2 row, and this record |
| The shipped reviewer section is not edited here | it describes `review-dispatch.sh` as built, which still runs two seats of one assignment, so the sentence retires with the runner rather than ahead of it | the M3.2.2 row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The provider `AGENTS.md` still says both seats run one assignment and a second seat is a repeat, which the seat rule supersedes | doc | a reader of the shipped section learns the rule the terms replaced | the M3.2.2 row, whose build rewrites that section with the runner's retirement |

## Completed

| File | Change |
|---|---|
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## role` and `## role line` state the seat walk, the wrap and the refusal, dated 2026-10-23 |
| [`docs/adr/single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md) | the rejected alternative records that one line now serves a two-seat review |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.2 consolidation row carries the decided rule and the records left to correct |
