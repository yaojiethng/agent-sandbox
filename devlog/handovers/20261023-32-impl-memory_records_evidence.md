---
date: 2026-10-23
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The memory records evidence

## Objective

Separate the cache from the choice. A route memory holds what an attempt observed about a route, and it does so whichever way the attempt was chosen; what routing does with it is a different question, and the answer stays in selection.

## Scope

The record write in the walk and in the seat path, the two invariants that were holding a held route still, the two transition rows that name them, and the tests and records that stated the older shape.

The correction the operator made: caching works the same either way, and only routing changes. The tree had implemented the opposite, a pinned attempt teaching the memory nothing, and the seat path had inherited it from the walk.

Out of scope: the classifier, the backoff arithmetic, and the seat rotation.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A pinned walk records its outcome | `test_cli_a_pinned_run_records_its_outcome` asserts the state file names the pinned route | Agent [x] |
| A pinned seat run records each attempt | `test_a_pin_seats_every_seat_on_one_assignment` asserts the route is `ready` afterwards | Agent [x] |
| A success does not ready a cooling route | `[R11]` asserts a success leaves the cooldown where it is | Agent [x] |
| A failure still moves a cooling route further out | the same case asserts a later transient failure extends `until`, never shortens it | Agent [x] |
| A capability fault still kills a cooling route | the same case asserts `dead` | Agent [x] |
| A dead route stays dead through every attempt | `[R12]` asserts `success`, transient, quota, timeout and unknown all leave it dead | Agent [x] |
| The escalation still applies | `[R3]` passes unchanged, so a second failure still lengthens the wait | Agent [x] |
| The gate is clean | `bash scripts/lint.sh` across 12 gates, `bash scripts/run_tests.sh` at 1309 tests over 94 files | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A pinned attempt is recorded like any other | the memory is evidence about the route, not about the decision that chose it. The operator stated the rule: caching works the same either way, and only routing changes | [`dispatch.md`](../../docs/reference/dispatch.md) `## Requirements`, and the walk and seat writes |
| A held route freezes against improvement, not against evidence | a success on a cooling route would end a cooldown the router set, so the record keeps it cooling. A later failure still extends the wait and counts a strike, and a capability fault still kills the route, because severity only moves down | `applyOutcome`, rows R11 and R12 |
| A dead route is terminal at the transition | I4 was true only because nothing wrote to a dead route; a pinned success would have readied it and revived a route the session had killed | `applyOutcome`, row R12 |
| The two invariant rows are named rather than implied | an invariant enforced by the absence of a writer cannot be tested and does not survive the next writer. R11 and R12 name I6 and I4 the way R1 to R10 name theirs | [`machine.ts`](../../src/libs/dispatch/machine.ts) `TRANSITIONS`, and the mapping check |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| I4 and I6 held only because a pinned attempt wrote nothing: `applyOutcome` moved a cooling route to `ready` on a success and a dead route to `ready` too | defect, fixed here | the invariant was a fact about the callers, not about the machine, so the next writer would have broken it without a failing test | `applyOutcome`, rows R11 and R12 |
| The seat path could already revive a cooling route when two seats shared a candidate: seat 1 cools the route and seat 2's success readied it inside the same turn | defect, fixed here | reachable before this unit, when n seats exceed the candidate count | the freeze, and `[R11]` |
| The previous unit\x27s test asserted that a pin writes nothing, so the recording behaviour had no case and the older shape looked deliberate | record, corrected here | the test now asserts the write | [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) |

## Completed

| File | Change |
|---|---|
| [`src/libs/dispatch/machine.ts`](../../src/libs/dispatch/machine.ts) | `applyOutcome` freezes a held route against improvement and keeps dead terminal; rows R11 and R12; the failure rows name their states |
| [`src/libs/dispatch/seats.ts`](../../src/libs/dispatch/seats.ts) | the pinned candidate states that its attempt is recorded; the `pinned` state flag removed |
| [`src/libs/dispatch/cli.ts`](../../src/libs/dispatch/cli.ts) | the seat path records every outcome |
| [`scripts/dispatch.sh`](../../scripts/dispatch.sh) | the walk records a pinned attempt: both `-z "$MODEL"` guards removed |
| [`tests/dispatch/machine/machine.test.ts`](../../tests/dispatch/machine/machine.test.ts) | `[R11]` and `[R12]` |
| [`tests/test_dispatch.sh`](../../tests/test_dispatch.sh) | the pinned walk case inverted; the pinned seat case asserts the record |
| [`tests/dispatch/seats/seating.test.ts`](../../tests/dispatch/seats/seating.test.ts) | the pinned-flag case removed |
| [`docs/reference/dispatch.md`](../../docs/reference/dispatch.md) | the transition table states what a held route does; the pin rule and the invariants say the memory records evidence |
| [`docs/reference/terminology.md`](../../docs/reference/terminology.md) | `## launch site` distinguishes evidence about the route from evidence about the choice |
| [`devlog/AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) | the entry\x27s closing line states the record rule |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../src/reasoning/providers/pi/config/agent/AGENTS.md), [`skills/dispatch/SKILL.md`](../../src/reasoning/providers/pi/config/agent/skills/dispatch/SKILL.md) | a pinned attempt records its outcome |
