---
date: 2026-10-15
milestone: M3.6 - Cost-Aware Dispatch
type: Plan
status: Closed
---

# Handover - Activate M3.6 ahead of M3.3.2

## Objective

Make M3.6 - Cost-Aware Dispatch the active milestone, ahead of M3.3.2 and M3.3.3, because parallel dispatch is the prerequisite for running the policy-form slices concurrently.

## Scope

| In | Out |
|---|---|
| The activation of M3.6 and the deferral of M3.3's remaining children | M3.6's own units, which open at their own scope gate |
| The `active-milestone` field, the M3.6 summary row, and the two sequencing notes | Any renumbering; order is not identity |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `active-milestone` names M3.6 | `sed -n '2p' devlog/roadmap.md` | Accepted |
| 2 | M3.6's summary row reads `In progress` | `grep` the Milestone Summary row | Accepted |
| 3 | M3.6's dependency is satisfied | M3.3.1 closed at handover `20261015-07`; the `model-failover` extension landed at `20261014-14` | Accepted |
| 4 | M3.3.2 names its deferral | the section's `**Sequencing:**` line | Accepted |
| 5 | Gates and suite clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Accepted |

## Decisions

1. **M3.6 activates ahead of M3.3.2 and M3.3.3.** The operator directed it: M3.3 is a long serial body of work, and cost-aware dispatch is what lets its slices run in parallel. The three remain siblings under M3.3; only the work order changed.
2. **The numbering is unchanged.** The milestone keeps its identifier `M3.6`. Order is a property of the `active-milestone` field and the sequence of iterations, not of the number.
3. **M3.3 stays `In progress`.** Its remaining children are not started, so the node is not complete. The deferral is stated in M3.3.2's section rather than by changing the parent's status.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| M3.6's Phase 1 transport proof needs a live OpenCode runtime, and `opencode-ai` is absent from this reasoning container. It is installed only in the opencode provider's base image (`src/reasoning/providers/opencode/base.dockerfile`), and `command -v opencode` finds nothing. Phase 1 must resolve the runtime before it can prove the transport. | obstacle, measured | the M3.6 opening scope gate |

## Completed

Set `active-milestone` to `M3.6 - Cost-Aware Dispatch`; flipped the M3.6 summary row to `In progress`; added a `**Sequencing:**` line to M3.6 and a deferral line to M3.3.2.
