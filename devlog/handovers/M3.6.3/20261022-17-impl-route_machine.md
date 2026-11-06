---
date: 2026-10-22
milestone: M3.6.3 - Route and decide
type: Implementation
status: Closed
---

# Handover - The route machine, keyed by a route

## Objective

Make a dispatch's route decision a pure state machine over `<provider>/<model>`, with one case and one mutation row per invariant, so a failure cools or kills a route by its own scope.

## Scope

The roadmap row **The dispatch-policy axis, re-keyed to `(provider, model)`**. The machine, the outcome classifier, the session state and their tests. The machine is not wired into the entrypoint here: the walk that consumes it is the next unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The machine is pure: it holds no clock, opens no file and spawns nothing | read [`machine.ts`](../../src/libs/dispatch/machine.ts) | Agent [x] |
| A route is keyed `<provider>/<model>`, and a selection names one route | `node --test tests/dispatch/machine/machine.test.ts` | Agent [x] |
| Every invariant names a transition and a mutation row | `node --test tests/dispatch/machine/mutation.test.ts` | Agent [x] |
| A capability failure is rejected by scope, not by price | `node --test tests/dispatch/machine/classify.test.ts` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh`; `bash tests/test_dispatch_machine.sh` prints `2 passed, 0 failed` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A route is `<provider>/<model>`, and its record is `untried`, `ready`, `cooling` or `dead` | two readers of one table disagreed because the unit was never named | [`machine.ts`](../../src/libs/dispatch/machine.ts), [`types.ts`](../../src/libs/dispatch/types.ts) |
| The clock is the only way out of cooling | a record a later attempt can shorten thrashes | invariant I6 |
| A `capability:request` failure leaves the route untouched | a bad brief must not demote a good model | R8 and I2 |
| A `capability:model`, `capability:provider` or `capability:account` failure makes the route dead for the session | the route cannot answer this session at any price | R7 and I4 |
| Backoff doubles from 15 seconds to a 15-minute cap | the base bounds a transient failure, the cap bounds a cooling route's cost | [`machine.ts`](../../src/libs/dispatch/machine.ts) |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The machine is pure and unwired, so no live dispatch uses it yet | result | the acceptance is the machine's own, and the next unit wires it | recorded here |

## Completed

| File | Change |
|---|---|
| [`machine.ts`](../../src/libs/dispatch/machine.ts) | the transition table, the six invariants and the selection |
| [`classify.ts`](../../src/libs/dispatch/classify.ts) | the provider's sentence to a verdict, by declared pattern order |
| [`state.ts`](../../src/libs/dispatch/state.ts), [`types.ts`](../../src/libs/dispatch/types.ts) | the session state and the shared vocabulary |
| [`tests/dispatch/machine/`](../../tests/dispatch/machine/) | the machine, the classifier, the state, the mapping and one mutation row per invariant |
| [`test_dispatch_machine.sh`](../../tests/test_dispatch_machine.sh) | the unit's runner |
| [`devlog/roadmap.md`](../roadmap.md) | the row closed and the active milestone set to M3.6.3 |
