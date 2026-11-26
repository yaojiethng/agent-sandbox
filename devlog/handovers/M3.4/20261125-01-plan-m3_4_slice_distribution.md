---
date: 2026-11-25
milestone: M3.4 - Container Execution Model and Environment Ownership
type: Plan
status: Closed
---

# Handover - M3.4's sub-milestones re-cut into functional areas

## Objective

Re-cut M3.4's two catch-all sub-milestones into functional areas, keeping the iteration as the vertical slice, so the milestone's status and sequence can be read from its sub-milestones.

## Scope

The M3.4 task tree only: the two catch-alls (M3.4.3 Persistence contract and M3.4.7 Environment declaration plane) are split into four functional areas, and the other four sub-milestones are unchanged. The iteration grain is untouched: each open row stays one vertical slice. No row is implemented, no live run opens, and no sub-milestone status changes beyond the new names. The M3.4.1 acceptance-criteria gap is flagged, not fixed.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The M3.4 summary carries eight sub-milestones, with M3.4.3, .6, .7 and .8 named as functional areas and no M3.4.9. | the summary table read against the eight headings (`grep -n '^##### M3.4' devlog/roadmap.md`). | Agent [x] |
| Every open row from the two catch-alls sits in exactly one of the four areas, and no row is duplicated. | the four section row counts sum to 21; a `grep -c` per row name equals 1. | Agent [x] |
| The `## Sequencing` paragraph keeps the contract, trust-posture and sample-project order and names M3.4.3 as the container-harness contract's home. | read the paragraph. | Agent [x] |
| The session-identity row names the landed run id and the `${...}` conflict. | read the row. | Agent [x] |
| The stale model finding reads as realized. | read the finding. | Agent [x] |
| The record gates and lint pass. | `scripts/check_record_lifecycle.sh`, `scripts/check_record_citations.sh`, `scripts/check_record_names.sh`, `scripts/lint.sh`. | Agent [x] |
| The handover is the session record and closes at the plan close. | this file. | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The iteration is the vertical slice; the sub-milestone is a functional area. | The `task-list` and `iteration_protocol` conventions already state both; no new rule is needed. | `devlog/roadmap.md`; the conventions |
| Split the two catch-alls; keep the four function-named sub-milestones. | M3.4.3 and M3.4.7 mixed outcomes; the other four name one function each. | `devlog/roadmap.md` |
| The container-harness contract joins persistence in M3.4.3; the project-harness contract stays with the project declaration in M3.4.7. | The container contract defines the same session state the persistence layer reads; the project contract is what the declaration interface reads. | `devlog/roadmap.md` |
| Dissolve M3.4.9; session identity goes to M3.4.3, the provider hook fixture to M3.4.8. | Session identity is the container's environment block; the provider hook is the host-side session start. | `devlog/roadmap.md` |
| No ADR or discussion record was settled or retired. | The rule is already stated in the conventions; no ADR was owned, and no discussion record's roadmap row closed. | This handover |
| No roadmap task closes; the write-back is the sub-milestone re-cut and the row moves. | The session changed the M3.4 tree's shape, not the state of a task. | This handover; `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The session-identity row's premise was stale: the agent service already passes `SESSION_ID` through `${SESSION_ID:-}`, which the container-harness contract forbids. | record | A reader would re-declare what exists and miss the interpolation conflict. | Corrected in the row. |
| M3.4.1 is active and has no `**Acceptance criteria:**` block. | record | The task-list convention's active-sub-milestone requirement is unmet. | Ruled out of scope: the Scope section names the gap and leaves it to a later record pass. |
| The M3.4 model finding still said the model was stale after the re-cut landed. | record | A done item carried forward-looking text. | Rewritten as realized. |

## Completed

| File | Change |
|---|---|
| [`devlog/roadmap.md`](../../roadmap.md) | Split M3.4.3 and M3.4.7 into four functional areas; added M3.4.6 and M3.4.8; moved 21 rows; corrected the session-identity row and the model finding; updated the summary and sequencing. |
| [`20261125-01-plan-m3_4_slice_distribution.md`](20261125-01-plan-m3_4_slice_distribution.md) | This plan record. |
