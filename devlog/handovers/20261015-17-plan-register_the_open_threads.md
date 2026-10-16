---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Plan
status: Closed
---

# Handover - Register the open threads

## Objective

Write down every thread open at this point, so none is lost or skipped. The session grew several tasks faster than it filed them.

## Scope

The register of open threads, the M3.6.4 rows, and the two defects the session found. Out of scope: starting any of them.

## The register

| Thread | Status | Durable home |
|---|---|---|
| M3.6.1 close | six commits landed, awaiting the operator's release; review presented in chat | [`devlog/roadmap.md`](../roadmap.md) M3.6.1; handovers `20261015-12` to `20261015-16` |
| The build and layer work | approved in scope and prompt, filed | M3.6.1: the build-skip fix, the dispatch-CLI pin and gate, the install-step census, the invalidation history, the layer install design. M3.6.2: the host build probe |
| The launch-site sweep | filed | M3.6.3 |
| M3.6.2, the four measurement rows | queued | M3.6.2 |
| M3.6.3, the six routing rows | queued | M3.6.3 |
| M3.3.2, ten rows | deferred behind M3.6 | M3.3.2 |
| M3.3.3, seven rows | deferred behind M3.6 | M3.3.3 |

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every open thread has a durable home | the register table, each row citing a roadmap section or a handover | Accepted |
| The orphaned build task is filed | `devlog/roadmap.md` M3.6.4, five rows and a summary row | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The build and install work lands in M3.6.1 and M3.6.2, not a new M3.6.4 | M3.6.1 owns the durable install, so it carries the build fix, the pin and gate, the census, the history and the layer design; the host probe verifies the build after M3.6.1 changes it | the roadmap |
| The register lives in a handover | the roadmap holds tasks, and a handover holds a session's open state | this record |

## Decisions pending

The home of the model-pin mismatch. M3.6.3's model-catalog track owns the role table's tie-in, or the skill reads the role table directly.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The free worker model has two pins. `$AGENT_HOME/model-recommendations.md` names `_IMPLEMENTER: opencode-go/cat-jam-free`, while the `opencode-dispatch` skill defaults to `opencode/deepseek-v4.1-flash-free`. Both are free; they are not the same model. | contradiction, unfiled | resolve when the model-catalog track lands under M3.6.3, or move the skill to read the role table |
| The provider-decision landing is inert on a machine with an existing `pi-base` image, because `build_if_missing` does not hash the Dockerfile. This is recorded in M3.6.1's build-skip row rather than left implicit. | defect, filed | M3.6.1 |
| The build suppresses per-step progress with `docker build --quiet`, so the harness cannot report what it rebuilt. The host probe supplies that data instead. | measurement gap, filed | M3.6.2 |
| A roadmap reassignment landed without the presentation gate, and the operator caught it by reading the reply rather than at a gate. The commit was amended after the assignment was confirmed. | process, tracked | a recurrence on `[O] 2026-09-25` in [`AGENT_FEEDBACK.md`](../AGENT_FEEDBACK.md) |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../roadmap.md) | the build and layer rows re-filed into M3.6.1 and M3.6.2; M3.6.4 removed |
| [`devlog/handovers/20261015-17-plan-register_the_open_threads.md`](20261015-17-plan-register_the_open_threads.md) | this register |
