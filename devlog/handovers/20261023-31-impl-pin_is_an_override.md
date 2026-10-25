---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - A pin is an override

## Objective

Correct the rule the seat path was built with. Resolution is the default mechanism, and a caller who names an assignment pins it: the pin is taken as given rather than refused.

## Scope

The seat refusal of `--model`, the entrypoint's pin pass-through, the library's pinned candidate, the state flag that keeps a pinned run out of the route memory, the one test that held the refusal, and every document that read resolution as a requirement.

The correction, in one line: the walk had taken `--model` as a pin since before the seat path existed, and the seat path invented a refusal the walk never had. The reserved terms and the ADR said "names a role and never a model", which is the shape of the default path read as a prohibition.

Out of scope: the pin's precedence over the route memory, which is unchanged and remains the caller's risk to take, and any new way to name an assignment, which stays `--model` with `--thinking` beside it.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A seat run takes a pin | `test_a_pin_seats_every_seat_on_one_assignment`: two seats on one pinned model both run it | Agent [x] |
| The pin's level rides with it | the same case asserts `opencode/s2-free at low` twice, so every seat carries the level | Agent [x] |
| A pin seats every seat and deals nothing else | the same case asserts the role's first entry is attempted zero times | Agent [x] |
| A pinned run records nothing | the same case asserts the state file names no pinned route | Agent [x] |
| The refusal is gone from the entrypoint | `run_seats --role _SEAT --seats 2 --model <pin>` exits 0 rather than 2 | Agent [x] |
| The library keeps the two paths apart | `pinnedCandidates` returns one candidate taken as given; `seatCandidates` keeps the memory filter for a resolved role | Agent [x] |
| The state carries the distinction | the unit case `a pinned run carries the flag that keeps it out of the memory` | Agent [x] |
| No live document calls resolution a requirement | `grep -rn "never a model\|cannot be pinned\|pin is refused" docs src scripts workflow` prints nothing | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1309 tests over 94 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A pin is the caller's stated value, allowed wherever a role may be named | resolution is a default, and a default the caller cannot step over is a requirement. The operator stated the rule directly: pins and manual specification are always allowed | [`dispatch.md`](../../docs/reference/dispatch.md) `## Requirements`, [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) |
| A pinned seat run seats every seat on the one assignment | the caller who pins a review wants that model twice, which is a repeat by choice; the rotation is what a caller who names a role gets | `dispatch.md` `## Seats`, the shipped `## Running Review Subagents` |
| A pinned run records nothing, in the seat path as in the walk | a pin is not a route decision, so recording it would let a pin revive a route the router had put to sleep. The seat path had written the memory unconditionally until this unit | [`cli.ts`](../../src/libs/dispatch/cli.ts), [`seats.ts`](../../src/libs/dispatch/seats.ts) |
| The distinction lives in the seat state, not in the call | the turn call carries results and no `--model`, so the start step records whether the run is pinned and the turn step reads it | `SeatState.pinned` |
| The ADR\x27s headline reads as a default rather than a prohibition | its own rationale already distinguishes a hidden skill default, which restates the table, from a pin, which the invocation states | [`pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The seat path refused a pin and a test asserted the refusal, so the check could not disagree with the code it had just been written for | defect, fixed here | a test written beside a new refusal ratifies it rather than judging it | [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md), entry of 2026-10-23 |
| The seat path wrote every outcome to the route memory, including a pinned one, while the walk skips the write for a pin | defect, fixed here | a pinned review of a cooling model would have marked the route ready | `SeatState.pinned`, and the state-file assertion in the pin case |
| The refusal was recorded as a decision in handover `20261023-30` | record, corrected here | the closed record states the reversed rule, which is what a record does; this record and the terms state what holds | this record, and the ADR |

## Completed

| File | Change |
|---|---|
| [`src/libs/dispatch/seats.ts`](../../src/libs/dispatch/seats.ts) | `pinnedCandidates`, and `SeatState.pinned` set by `startSeats` |
| [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) | `seats start` takes `--model` and `--thinking`; a pinned run writes no route record |
| [`scripts/dispatch.sh`](../../scripts/dispatch.sh) | the pin refusal removed, the pin and its level passed to `seats start`, the header states the rule |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | the refusal case removed; `test_a_pin_seats_every_seat_on_one_assignment`, with the memory assertion |
| [`tests/dispatch/seats/seating.test.ts`](../../tests/dispatch/seats/seating.test.ts) | the pinned-flag case |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the pin rule in `## Requirements` and `## Seats`; a pinned run is a launch site that resolves nothing |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## launch site`: resolution is the default and a pin is its override |
| [`docs/adr/pi_subagent_dispatch.md`](../../docs/adr/pi_subagent_dispatch.md) | the decision states resolution as the default; the rationale separates a pin from a hidden skill default |
| [`src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md) | the seat form accepts `--model` and states what it does |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md) | `## Running Review Subagents` states the pin, and what a pinned review produces |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | an entry for the class: a default hardened into a requirement |
