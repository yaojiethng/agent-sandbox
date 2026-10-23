---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - One review surface

## Objective

Close the second launch mechanism. A review now names a role and a seat count, like every other dispatch, and the fixed runner that pinned its own assignment is gone.

## Scope

`review-dispatch.sh` and its allowlist entry, its test file, the shipped section that instructed its use, the fixed-run concept in the reserved terms and the two ADRs that carried it, and the two runner checks the seat path did not yet make.

The runner's contract, check by check, and where each one went:

| The runner's check | What carries it now |
|---|---|
| four arguments, usage | the entrypoint's own parsing, `dispatch: ROLE, BRIEF and DIR are required` |
| the assignment is `provider/model` | the role resolves it, and a pin is refused in seat mode |
| a non-empty thinking level | the table's entry grammar |
| the brief exists and is non-empty | the entrypoint's brief guard |
| the scratch directory exists and is writable | `dispatch: run directory is not a writable directory` |
| the tree is clean | added here: a seat run refuses a dirty tree before the first attempt |
| a seat that logs nothing fails the run | added here: a zero exit with an empty log stops the run |
| a seat that bound another model fails the run | retired: the entrypoint passes the full id from the table, so the short-id substitution the check existed for cannot happen |
| the runner carries no model, provider or assignment | the launch-site gate, whose allowlist is now the library, the entrypoint and the gate itself |

Out of scope: the walk loop and the worker supervision, which stay in bash, and any seat behaviour finer than a turn boundary, which the M3.6.6 sub-milestone holds.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The runner is gone | `git log --diff-filter=D --name-only -1` names `review-dispatch.sh` and `tests/test_review_dispatch.sh` | Agent [x] |
| No live carrier names it | `grep -rn "review-dispatch" docs src scripts tests workflow .agents/skills` prints nothing | Agent [x] |
| The allowlist is the mechanism's own surface | `grep -A4 "^ALLOWED=(" scripts/check_launch_sites.sh` names `launch.ts`, `dispatch.sh` and the gate | Agent [x] |
| A launch site is still caught outside it | `bash tests/test_check_launch_sites.sh` passes 4 cases over the retargeted fixture | Agent [x] |
| A dirty tree is refused before the first attempt | `test_a_dirty_tree_is_refused` asserts exit 1 and that no attempt was spent | Agent [x] |
| A silent seat stops the run | `test_a_silent_seat_stops_the_run` and the unit case `a seat that logs nothing stops the run` | Agent [x] |
| The shipped section states the seat invocation | `grep -A2 "## Running Review Subagents" src/reasoning/providers/pi/config/agent/AGENTS.md` names `--seats 2 --run` and the dirty-tree precondition | Agent [x] |
| No live document states a fixed run | `grep -rn "fixed run" docs .agents/skills src scripts tests` prints nothing | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1308 tests over 94 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The reviewer resolves `_REVIEWER` instead of pinning an assignment | the runner's pin was what made two seats a repeat of one model; the rotation is what makes them two families, which is the property a review is for | [`dispatch.md`](../../docs/reference/dispatch.md) `## Seats`, and the shipped `## Running Review Subagents` |
| The model-binding check retires rather than ports | it guarded a `--model` substring match, and the entrypoint now passes the full id from the assignment, so the defect it caught cannot be constructed. The property is kept, the check is not | this record, and the criteria row above |
| The dirty-tree and empty-log checks move into the seat path | both are properties of a review rather than of the runner: a review reads one revision, and a silent seat is not evidence of work | [`scripts/dispatch.sh`](../../scripts/dispatch.sh), [`seats.ts`](../../src/libs/dispatch/seats.ts) |
| `fixed run` leaves the reserved terms as a separate kind of site | no fixed run exists in the tree, and a term whose exemplar is deleted reads as a promise. The distinction it carried survives as the pin rule | [`terminology.md`](../../docs/reference/terminology.md) `## launch site`, [`dispatch.md`](../../docs/reference/dispatch.md) `## Requirements` |
| The seat checks read `--dir`, not `$PWD` | a review of another tree is the normal case, and the runner's `$PWD` reading was an accident of where it was invoked | `scripts/dispatch.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A seat that exited zero with an empty log counted as a success, so a review could report two silent seats as two reports | defect, fixed here | the runner's only evidence rule was lost in the first seat port | fixed in `seatResult`, with the bash and unit cases that hold it |
| The seat path had no precondition on the tree, so a review of uncommitted work produced findings with no revision to attribute them to | defect, fixed here | the runner's attribution property was lost in the first seat port | fixed in the entrypoint's seat branch |
| The role-table ADR's rejected-alternative concession named the reviewer's fixed run as the right form for a fixed contract, and the retirement deletes that form | carrier, fixed here | a reader would look for a runner that no longer exists | the ADR states that the reviewer's runner was the last such skill and retired into the seat path |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/bin/review-dispatch.sh` | deleted, with the directory |
| `tests/test_review_dispatch.sh` | deleted; its checks live on in the seat cases |
| [`src/libs/dispatch/seats.ts`](../../src/libs/dispatch/seats.ts) | a zero exit with an empty log stops the run |
| [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) | the stop message names a silent seat as such |
| [`scripts/dispatch.sh`](../../scripts/dispatch.sh) | a seat run refuses a dirty tree; the pin comment states the seat refusal |
| [`tests/dispatch/seats/seating.test.ts`](../../tests/dispatch/seats/seating.test.ts) | the silent-seat case; successes carry a log line |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | `silent` stub mode, the dirty-tree case and the silent-seat case |
| [`tests/test_check_launch_sites.sh`](../../tests/test_check_launch_sites.sh) | the fixture allowlists the entrypoint instead of the retired runner |
| [`scripts/check_launch_sites.sh`](../../scripts/check_launch_sites.sh) | the runner leaves the allowlist; the refusal names the mechanism, not a fixed run |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | `## Running Review Subagents` states the seat invocation, the rotation and the exit codes |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the seat preconditions, the pin rule, and the allowlist stated without a fixed run |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## launch site` carries the pin distinction instead of a fixed run |
| [`docs/adr/pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md), [`docs/adr/single_source_model_recommendations.md`](../../docs/adr/single_source_model_recommendations.md) | a pinned run rather than a fixed run |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.2 row closes |
| `.agents/drafts/seat-contract-run.md` | the carrier list names `seats.ts` |
