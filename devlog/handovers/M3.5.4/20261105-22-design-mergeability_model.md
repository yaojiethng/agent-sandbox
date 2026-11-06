---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Design
status: Closed
---

# Handover - The change model reduces to mergeability

## Objective

Replace the branch-shaped chart with the mergeability machine: three states over one branch's relationship to the head, and the prepare/queue/accept primitives. Align the two runbooks to prepare and accept.

## Scope

The design record, the `Mergeability` TLA+ model and its chart, the two runbooks, the `git-discipline` runbook table, and the M3.5.4 rows in the roadmap. The branch-work machine is named as separate and is not modelled here.

Out of scope, with reasons: the branch-work machine, which is a later chart; the recovery split, which stays the "leave recovery" row; the command names, which stay `/merge` and `/rebase`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The chart is over mergeability, not the branch | `Mergeability.tla` has `state` in `not-ready`, `ready`, `accepted` | Agent [x] |
| `stale` is an event, not a state | the `ready -> not-ready` edge is the head advance | Agent [x] |
| The trunk is `stable` with a head, and accept is a CAS | the record's `## The accept operation`; the runbooks | Agent [x] |
| The model checks | TLC reaches 11 states and 22 steps; `TypeOK` and `NoDeadlock` hold; 3 states and 3 arrows | Agent [x] |
| The runbooks say prepare and accept | `rebase.md` prepares; `merge.md` accepts by fast-forward CAS | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The state machine is over mergeability, not the branch | the branch has a separate work lifecycle; only its fast-forwardability is the trunk's question | the design record |
| `stale` is an event, not a state | the mergeability value is derived; the head advance lands a ready branch in `not-ready` | the design record |
| The trunk is `stable`; accept is an atomic CAS | a transient `accepting` state is the operation, not a state; verify then CAS, so failure is a no-op | the design record |
| Accept is a fast-forward, not a replay | the branch prepares its own conflicts; the trunk only moves the pointer | the design record; `merge.md` |
| Prepare/queue/accept replace the request vocabulary | there is no reviewer; the consumer is deterministic | the design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The old chart mixed branch work with mergeability | defect | `cut`, `working`, `blocked`, `parked` are not states of the trunk's question | fixed: the branch-work machine is separate |
| `/merge` replayed and resolved, so the trunk was an author and the CAS was impossible | defect | the accept was not atomic and the trunk could resolve | fixed in `merge.md` |
| The `ready` predicate is derived, so the model cannot go stale | observation | the chart is a diagnostic, not stored state | the design record |

## Completed

| File | Change |
|---|---|
| `devlog/discussions/20261105-design-open-change_flow.md` | the mergeability model, the chart, the atomic accept, the six bugs |
| `workflow/coding-agent/prompts/rebase.md` | prepare: make the branch fast-forwardable |
| `workflow/coding-agent/prompts/merge.md` | accept: fast-forward by compare-and-swap |
| `.agents/skills/git-discipline/SKILL.md` | the runbook table says prepare and accept |
| `devlog/roadmap.md` | the M3.5.4 rows use the mergeability vocabulary |
| `devlog/handovers/M3.5.4/20261105-22-design-mergeability_model.md` | this record |
