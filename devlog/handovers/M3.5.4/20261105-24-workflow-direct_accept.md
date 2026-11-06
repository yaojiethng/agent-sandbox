---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - The accept has a direct path and a stated preflight

## Objective

Let `prepare-rebase` hand a ready branch straight to `accept-fast-forward`, make the queue optional, and state the accept's pattern: preflight, staged verification, compare-and-swap.

## Scope

The three prompts' handoff sections, the `## Why preflight, then CAS` section in `accept-fast-forward.md`, and the change-flow record's queue sentence and early-change step.

Out of scope, with reasons: the queue's storage, which stays derived; the recovery region; the branch-work machine.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The direct path is named | `prepare-rebase`'s handoff offers both `/merge-queue` and `/accept-fast-forward` | Agent [x] |
| The queue is optional | the record says so; `merge-queue` hands back when nothing is ready | Agent [x] |
| The accept states its pattern | `## Why preflight, then CAS` | Agent [x] |
| The rollback pattern is rejected | the same section says why | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Preflight, staged verification, then CAS | each failure is a no-op; the CAS closes the race; no cleanup path | `accept-fast-forward.md` |
| Act-then-rollback is rejected | the rollback is a second write that can fail, leaving the trunk advanced and red | `accept-fast-forward.md` |
| The queue is optional | the operator may inspect the order or accept a branch directly; both are the same accept | the change-flow record |
| A queue that finds nothing ready hands back to prepare | an empty queue is a diagnosis, not a dead end | `merge-queue.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A preflight alone is a TOCTOU race | defect | the head can move between the check and the act | fixed: the CAS carries the expected old head |
| Rolling back after an act is a second fallible write | defect | a failed rollback leaves the trunk advanced and red | fixed: verify before the commit |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/prepare-rebase.md` | the handoff offers the direct path and the queue |
| `workflow/coding-agent/prompts/merge-queue.md` | an empty queue hands back to prepare |
| `workflow/coding-agent/prompts/accept-fast-forward.md` | the preflight, staged verification and CAS section; the optional queue |
| `devlog/discussions/20261105-design-open-change_flow.md` | the queue is optional; the early-change step |
| `devlog/handovers/M3.5.4/20261105-24-workflow-direct_accept.md` | this record |
