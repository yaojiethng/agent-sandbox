---
date: 2026-11-06
milestone: M3.5.4 - The git and change model
type: Design
status: Closed
---

# Handover - The change model's ADR and reference

## Objective

Conclude the change model into an ADR and a reference -- the three mergeability states, the prepare/queue/accept primitives, the trunk's atomic accept, the branch-work separation and the defect-flow relation -- so the M3.5.4 model row closes.

## Scope

The M3.5.4 model row: the design record's conclusion, its ADR, its reference, the statechart's change-flow region and the roadmap write-back.

The two prior M3.5.4 handovers lose the `## Next session` section the template does not hold, and the track-folder link defect gets its own M3.5.1 row, both found at pre-close.

Out of scope, with reasons: the bare-unit sweep, which is M3.5.4's second open row and the next unit; the milestone close, which runs after both rows; the concurrency proof and the parallel-rule de-coupling, which are the units after the close.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The ADR records the decision, its rationale and its rejected alternatives | `docs/adr/change_model.md` | Agent [x] |
| The reference states the model once: the states, the primitives, the branch work and the defect flow | `docs/reference/change_model.md` | Agent [x] |
| The design record is deleted and no closed row names it | `scripts/check_record_lifecycle.sh` | Agent [x] |
| The statechart's change-flow region matches the model | `scripts/check_statechart.sh` | Agent [x] |
| The M3.5.4 model row closes with its landing note | `devlog/roadmap.md` | Agent [x] |
| The gates are clean | `scripts/lint.sh`, `scripts/run_tests.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The model row's outcome is an ADR and a reference, not a third design record | the design record's content concludes; the ADR is the decision and the reference the model | this record |
| The design record is deleted and the roadmap link re-points to the ADR | `work-log` deletes a record when the row that names it closes; the ADR is the authority and the record is evidence | this record |
| The reference owns the state table and the transitions; the ADR owns the decision and the rejected alternatives | one subject in one mode, per `principle-single-source-of-truth` | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The track id block is not materialized | defect | `reserve-id --track M3.5.4` and `--track M3.5.1` both return `20261106-01`; two tracks writing today collide, which is the identity guarantee the block exists for | M3.5.1's folder-and-field gate, extended to the track `README.md` and its `ids:` block |
| The design record's fate was stated as a rename | defect | a `-concluded-` record with no open row is a second source the lifecycle gate deletes | fixed: the record is deleted and the row re-points to the ADR |
| The roadmap audit reports 18 record defects, none on the model row, including the T5 empty section and the T1 eval placement | gap | the classes are the M3.5.3 record-check backlog's | M3.5.3's record-check backlog (defer) |
| The handover audit reports 813 broken relative links across 126 live handovers | defect | the track-folder move left the links resolving into `devlog/<root>` paths; the migration's claim that it re-paths them is false | the M3.5.1 row "The track-folder move re-paths every relative link" |
| Two M3.5.4 handovers carry a `## Next session` the template does not hold | defect | the section forecasts work the roadmap holds; the format gate misses it | fixed: the sections are removed |

## Completed

| File | Change |
|---|---|
| `docs/adr/change_model.md` | the decision, requirements and rejected alternatives |
| `docs/reference/change_model.md` | the states, transitions, primitives, accept, early change, defect flow, check and the model |
| `devlog/discussions/20261105-design-open-change_flow.md` | deleted; the ADR and reference replace it |
| `devlog/roadmap.md` | the model row closes and re-points; the M3.5.1 link row is filed |
| `devlog/handovers/M3.5.4/20261105-27-workflow-branch_topology.md` | removed the `## Next session` section; `[AMENDMENT]` |
| `devlog/handovers/M3.5.4/20261105-28-workflow-iteration_usage.md` | removed the `## Next session` section; `[AMENDMENT]` |
| `devlog/handovers/M3.5.4/20261106-01-design-change_model.md` | this record |
