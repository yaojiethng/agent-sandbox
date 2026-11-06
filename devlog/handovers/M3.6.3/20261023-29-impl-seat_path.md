---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The seat path

## Objective

Let a caller ask for n seats of one role and have the entrypoint deal them, so a review is the same mechanism as a worker rather than a second launch site beside it.

## Scope

The seating and its bookkeeping in the dispatch library, the two entrypoint steps that drive it, the `--seats` flag with its refusals, the four cases that hold the behaviour, and the eleven unit cases over the bookkeeping.

The split this unit settled, on operator direction: the library holds the vocabulary, the state and every decision, including the seating; the entrypoint holds the process, including the firing, the supervision and the log. The seat rule had been written in the reserved terms and implemented nowhere, and the loop that carried it in bash was where the bugs lived  --  two of them unbound-variable aborts, one a status read through `if !`.

Out of scope: retiring `review-dispatch.sh` and its allowlist entry, porting its nine cases, and rewriting the shipped `## Running Review Subagents` section. Those stay with the M3.2.2 row, which this unit advances and does not close.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A seat count reaches the entrypoint | `bash scripts/dispatch.sh --role _R --brief <brief> --dir <dir> --seats 2 --run` over the fixture runs two seats | Agent [x] |
| The seats rotate over the candidates | `test_seats_rotate_over_the_candidates`: two candidates fill three seats as first, second, first | Agent [x] |
| A dead candidate is dropped and the seat moves on | `test_a_seat_drops_a_dead_candidate_and_rotates`: the dead candidate is attempted once, its seat then takes the next in the rotation | Agent [x] |
| A retryable outcome keeps the seat and the run reports the wait | `test_a_retryable_outcome_keeps_the_seat_and_blocks`: one attempt, then `blocked` with the earliest wait, exit 3 | Agent [x] |
| The contradictory forms are refused | `test_seats_refuse_the_contradictory_forms`: without `--run`, on a worker, with a pin, and at zero | Agent [x] |
| The bookkeeping is unit-tested away from any process | `node --test tests/dispatch/seats/seating.test.ts` passes 11 cases over the rotation, the drop, the retry, the stop and the verdict | Agent [x] |
| The mechanism is stated where the caller reads it | [`dispatch.md`](../../docs/reference/dispatch.md) `## Seats`, and the skill's form names `--seats` | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1315 tests | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The seat bookkeeping is TypeScript | it is text and policy, not process: the rotation, the drop set, the turn boundary and the verdict are decisions over data. Written in bash it produced two unbound-variable aborts and a status read through `if !`, each caught by a test rather than by review | [`seats.ts`](../../src/libs/dispatch/seats.ts), and the two halves in [`dispatch.md`](../../docs/reference/dispatch.md) `## The Launch Sites` |
| The entrypoint asks the library per turn, not per seat | one call in, one call out per turn: the library returns the orders for the whole turn, so the candidate set has one writer per turn as the seat rule requires | `seat_run` in [`scripts/dispatch.sh`](../../scripts/dispatch.sh) |
| A capability failure rotates; a timeout or an unknown stops the run | the reference already says both stop a walk, and a reassignment on a failure that says nothing about the route is a guess with a model attached | [`seats.ts`](../../src/libs/dispatch/seats.ts) `seatResult` |
| Every seat finishing on a working model exits zero | a seat that was reassigned and then succeeded ended on a working model; the run's success is that, not the first attempt's code | `seatVerdict`, case `test_a_seat_drops_a_dead_candidate_and_rotates` |
| The door has two faces over one library, and only the first is built | a shell caller reaches the entrypoint; a caller inside pi reaches the library through codemode, which nothing exports to yet. Recorded as the decision, filed as a row | [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md), the roadmap row **The library is reachable from codemode** |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `select` takes no `--file`; it reads the table from the environment, so passing the entrypoint's table arguments to it refuses every candidate | defect, fixed here | a seat run would have read every role as unroutable | fixed in `seat_run`, with the reason stated where the call is |
| `read -r _ seat runtime` gives the last variable the whole remainder, so a three-name read cannot split a `fire` line | defect, fixed here | the entry `fire 1 opencode ...` reached the table parser as an assignment | fixed in `seat_run`; the fourth name takes the entry |
| `report_failures` was defined below the seat block that called it | defect, fixed here | the run died with `command not found` at exit 127 after every seat had succeeded | fixed by moving the definition above its first caller |
| The launch-site gate allowlists `review-dispatch.sh`, which still fires two seats of one assignment at once | carrier, open | the tree carries two seat behaviours until the M3.2.2 row closes | the M3.2.2 row, which this unit annotated |

## Completed

| File | Change |
|---|---|
| [`src/libs/dispatch/seats.ts`](../../src/libs/dispatch/seats.ts) | new: the candidates, the rotation, the orders, the outcome rule and the verdict |
| [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) | `seats start` and `seats turn`, the per-turn orders, the blocked report and the verdict |
| [`scripts/dispatch.sh`](../../scripts/dispatch.sh) | `--seats` with its four refusals, `seat_run` as the process half, a run directory for a seat run |
| [`tests/dispatch/seats/seating.test.ts`](../../tests/dispatch/seats/seating.test.ts) | new: 11 cases over the bookkeeping |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | four seat cases: the rotation, the drop, the retry and the refusals |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | `## Seats`, and the two halves named in `## The Launch Sites` |
| [`docs/adr/pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) | the door's two faces over one library |
| [`src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md) | the seat form, and what it refuses |
| [`devlog/roadmap.md`](../roadmap.md) | the M3.2.2 row records the seat path built; a row for the codemode face |
