---
date: 2026-10-15
milestone: M3.6.1 - Disable and ship OpenCode dispatch
type: Plan
status: Closed
---

# Handover - Settle the cost-aware dispatch design

## Objective

Settle the complete design of M3.6 - Cost-Aware Dispatch, and split it into sub-milestones with an order, so the remaining work is planned before it is dispatched.

## Scope

The M3.6 rows, the run directive, and the decomposition into sub-milestones. The interview settled the ordering, the measurement boundary, and the router boundary.

Out of scope: implementing the remainder, and the M3.3.2 and M3.3.3 sub-milestones deferred behind M3.6.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The settled design is written | [`20261015-design-settled-cost_aware_dispatch.md`](../discussions/20261015-design-settled-cost_aware_dispatch.md) | Accepted |
| M3.6 is split into sub-milestones | `devlog/roadmap.md` M3.6.1, M3.6.2, M3.6.3, and three summary rows | Accepted |
| The frontmatter names the active sub-milestone | `active-milestone: M3.6.1 - Disable and ship OpenCode dispatch` | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Disable `model-failover` before judging it | across 592 sessions no `model-failover/outcome` entry exists, and its only chain declares one route, so the feature has never run | the design record; M3.6.1 |
| Ship OpenCode dispatch before measuring | the ASAP goal needs no failover, and the seam makes the later A/B cheap at scale | the design record; M3.6.1 |
| The outcome instrument lives in the ledger, keyed by `(provider, model)` | the measurement must read a pi session and an OpenCode dispatch alike, so it cannot live in the pi extension | the design record; M3.6.2 |
| One shared state and policy, one adapter per runtime | the extension today holds both halves, which is why its state is unreachable from an OpenCode dispatch | the design record; M3.6.3 |
| The one-record-per-dispatch output is the storage grain, not the surface | the reading grain is per subagent call, per main-agent call, and an iteration summary | the design record; M3.6.2 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Across 592 sessions, zero carry a `"type":"model-failover/outcome"` entry. The only chain declares one route, and the extension landed at commit `ba170963` when the image pinned pi 1.2.0. | measurement | the design record; M3.6.3 |
| A first claim by the agent that `model-failover` mis-routed `cat-jam-free` was wrong. The session records show `provider: opencode-go, model: cat-jam-free`. The startup log lines were read as routing output. | contradiction, self-corrected | this record |
| `cat-jam-free` is in pi's installed `models-store.json` and in the live opencode-go catalog, so the model list is in sync. | measurement | the design record |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261015-design-settled-cost_aware_dispatch.md`](../discussions/20261015-design-settled-cost_aware_dispatch.md) | new: the settled shape, the ordering, the measurement boundary, the router boundary, the failure taxonomy, the split |
| [`devlog/roadmap.md`](../roadmap.md) | M3.6 becomes a parent with M3.6.1, M3.6.2 and M3.6.3; the rows are regrouped; three summary rows and the frontmatter follow |
| [`devlog/handovers/20261015-11-plan-settle_the_cost_aware_dispatch_design.md`](20261015-11-plan-settle_the_cost_aware_dispatch_design.md) | this record |
