---
date: 2026-11-05
milestone: M3.3.6 - The instruction corpus and its map
type: Workflow
status: Closed
---

# Handover - The operator's commands route to an entry point

## Objective

State the install/vendor routing the operator's phrase decides, and file the defect-flow statechart and the capability gap it exposes.

## Scope

The session installed the wrong skill because `install` and `vendor` were not distinguished anywhere the agent reads. This unit adds one routing section to the project layer, the subject-table row the instruction gate requires, the defect-flow statechart as a design record, and the M3.3.6 row that files the state-machine specification upgrade. The chart is evidence for that row; the upgrade is not delivered here.

Out of scope, with reasons: the upgrade itself, which the M3.3.6 row holds; the defect flow's landing as an ADR, which the chart record leaves open; the task-list carriers, which M3.5.2 owns.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The routing section exists and is filed | `bash scripts/check_instruction_surfaces.sh` clean | Agent [x] |
| Install and vendor name different destinations | the section states both, and the table's rows point at the owning entry points | Agent [x] |
| The chart record is named and stated | `bash scripts/check_record_names.sh` clean | Agent [x] |
| The record is owned by an open row | `bash scripts/check_record_lifecycle.sh` clean | Agent [x] |
| The capability row is filed, not closed | the M3.3.6 row reads `[ ]` and names its mechanism | Agent [x] |
| The gates pass | `bash scripts/lint.sh` clean | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The routing rule is a new section, not a paragraph under Constraints | the operator's phrase is a route to an entry point, not a constraint on where work is written | `AGENTS.md` |
| The statechart is filed as a design record under the M3.3.6 row | the chart is evidence for the capability gap, and the row is what keeps the record owned | this record |
| The capability upgrade is filed as a row, not done | it is a separate unit with its own design and its own checks | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The agent installed the project's `state-machine-specification` where the operator asked for the pstack `statechart`, because no instruction distinguished an install from a vendor | defect | a wrong personal install, corrected in place; the operator loses trust in the phrase-to-entry-point routing | this unit's routing section |
| The project's `state-machine-specification` produces no machine-checked model and no rendered chart, while the pstack `statechart` does | defect | the capability gap is real and the operator asked for the chart the procedure cannot produce | `devlog/roadmap.md`, M3.3.6 |

## Completed

| File | Change |
|---|---|
| `AGENTS.md` | `## Operator commands` after `## Instruction Surface` |
| `docs/development/instruction-surface-conventions.md` | the `Operator commands` subject-table row |
| `devlog/discussions/20261105-design-open-defect_flow.md` | the defect-flow chart, its TLA+ spec, config and view, and the TLC finding |
| `devlog/roadmap.md` | the M3.3.6 row for the state-machine specification upgrade |
| `devlog/handovers/M3.3.6/20261105-18-workflow-operator_command_routing.md` | this record |
