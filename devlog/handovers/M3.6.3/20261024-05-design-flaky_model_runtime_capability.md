---
date: 2026-10-24
milestone: M3.6.3 - Route and decide
type: Design
status: Closed
---

# Handover - A flaky model worth keeping, and the runtime that would keep it

## Objective

Park the failover A/B on operator direction, and file the capability it was meant to justify where the runtime owns it, with the evaluation named and the trigger that is missing written down.

## Scope

The roadmap's `M3.6.3` row and its scope sentence, one new row under `T12`, one paragraph in the `model-failover` extension's design record, and this record. No code, and no measurement: the point of the parking is that the measurement cannot run.

## Why the row could not run

The row asked for the same briefs with the extension off and on, comparing success rate, cost and wall clock, then a rebuild from the spec the measurement writes or a deletion. Three things stood in the way, and the first is decisive:

| Obstacle | Evidence |
|---|---|
| no model in the deployment has flaky semantics | models are up, out of quota, or unanswerable; nothing fails intermittently in a way worth persisting through |
| the extension is off by default and its only chain has one route | `model-failover/README.md` `## The flag`: inert unless `MODEL_FAILOVER_ENABLED` names a truthy value; `## The chain` records one route, and a chain of one cannot fail over |
| dispatch never selects a chain | `launch.ts:58` builds `--provider X --model Y` from the physical assignment, so the virtual chain name never appears in a dispatched run |
| the axes had no instrument | success rate and wall clock per attempt need a retained attempt stream, which is `M3.6.2`'s row |

## What the operator corrected

Two corrections changed the shape of the filing, and both are recorded here because the row they produced depends on them:

- **The cost model.** Model choice weighs output quality against dollar cost and time cost, all three. A free or cheap route with high output quality tilts the calculation toward persisting: retries that cost nothing but a few seconds are cheaper than the quality given up by walking to the next entry. That is the case the parked extension was built for, and it is a case the deployment does not have today because no route is both good and unreliable.
- **The owner.** The capability is owed to the runtime, not to the scheduler. It is a base capability, idempotent when the model is sound and buying cache rate or success rate when it is not, delivered as an intervention on the runtime through an extension -- pi only for now. The scheduler's failure rule is the other side of the same seam, which is why the row names a possible convergence rather than a dependency.

## What dispatch does today, measured

The row called the current method a dumb backoff retry, and the tree says it more precisely: a transient, rate or quota failure cools the route to `at + backoff(strikes + 1)` ([`machine.ts`](../../src/libs/dispatch/machine.ts), line 85) and the walk then tries the **next entry of the role** ([`dispatch.md`](../../docs/reference/dispatch.md) `## The route machine`). So the current method is a fixed backoff curve keyed on strike count plus a role walk: it is structurally a cross-model method, and cannot express "persist here".

## The capability as now recorded

Three unknowns, and the trigger, in the `T12` row:

| Element | What the row says |
|---|---|
| identification and retryability | whether the runtime can identify a model as flaky and hold a metric that makes persistence sanctioned by the model still standing in the recommendation list |
| the parked approach | whether `model-failover`'s approach earns its place; it is the one implementation, un-enabled, and nothing has ever priced its retries |
| worth at all | what any such intervention is worth while nothing fails that way, so the trigger is a model with flaky semantics and not a task position |
| boundaries | pi only for now, other runtimes out of scope; depends on `M3.6.2` and `M3.6.3`, may converge with `M3.6.6` |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| the A/B row closes as parked | `grep -c "^- \[x\] \*\*The failover A/B and the verdict\*\*" devlog/roadmap.md` prints 1 | Agent [x] Operator [x] |
| `M3.6.3`'s scope no longer claims the parked bakeoff | `grep -c "the failover and policy bakeoffs" devlog/roadmap.md` prints 0 | Agent [x] Operator [x] |
| the capability is filed where the runtime owns it | `grep -c "Flaky-model handling is a runtime capability" devlog/roadmap.md` prints 1, on a row under `T12` | Agent [x] Operator [x] |
| a reader at the code learns why it is off and where the comparison lives | the paragraph after the chain paragraph in `model-failover/README.md` | Agent [x] Operator [x] |
| the row prescribes no solution | the row names the property, the three unknowns and the trigger; it names no edge list, no policy and no schema | Agent [x] Operator [x] |

## Decisions

| # | Decision | Rationale | Where recorded |
|---|---|---|---|
| D1 | The A/B is parked, not run | no model has flaky semantics, so the treatment's trigger does not exist; the extension stays un-enabled, which is already its default | the `M3.6.3` row's closure |
| D2 | The capability is filed under `T12`, not `M3.6.6` | it is owed to the runtime as a base capability over all models, and `T12` owns the shipped extensions' fate and upkeep; the scheduler owns the failure rule, which is the converging side | the `T12` row; this record |
| D3 | The cost model is quality against dollar cost and time cost | a cheap, high-quality route tilts toward persistence, which is the case the extension exists for | this record; the `T12` row's opening sentence |
| D4 | Persistence is sanctioned by retryability, not by a per-call judgement | a model identified as flaky but not irreparably so, still standing in the recommendation list, may be retried | the `T12` row's first unknown |
| D5 | The row names no solution | the existing approach has to be evaluated for value before it is relied on, and the row would otherwise pre-commit to the edge list | the `T12` row |
| D6 | The row carries its dependencies instead of its filing handover | `M3.6.2` and `M3.6.3` are what it builds on and `M3.6.6` is what it may converge with; a reader gets more from that than from provenance alone | the `T12` row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| dispatch's handling of a flaky route is a backoff curve plus a role walk, which cannot express persistence on one model | measurement | the gap the parked extension fills is a capability gap, not a tuning gap | the `T12` row; this record |
| the extension is un-enabled, single-route, and never observed an outcome | measurement | the A/B has no treatment arm to run | the `M3.6.3` row's closure |
| the installed `model-failover` copy now differs from the repository's | expected | the paragraph lands in the repository; the image carries it after the next rebuild, which is blocked | this record |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the A/B row closed as parked, `M3.6.3`'s scope sentence narrowed to the policy bakeoff, and the flaky-model row added under `T12` with its dependencies |
| [`model-failover/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-failover/README.md) | one paragraph naming the parking, the missing trigger and where the comparison lives |
| this record | the measurement that blocked the A/B, the two corrections, and the decisions that filed the capability |
