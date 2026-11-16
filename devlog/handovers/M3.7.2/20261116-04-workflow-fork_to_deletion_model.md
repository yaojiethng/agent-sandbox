---
date: 2026-11-16
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - one branch lifecycle from fork to deletion

## Objective

Replace the split of the branch work, the mergeability relation and the draft with one lifecycle model, from the branch's fork to its deletion, in one home with one gate.

## Scope

M3.7.2, the row **The change model is one lifecycle from fork to deletion**, continuing the model-as-code work of [`20261112-06`](20261112-06-workflow-model_as_code.md).

The model's object becomes the change from the fork to the branch's deletion. The states are the mergeability relation and the host's staging of it: `Working` while the trunk head is not an ancestor of the tip, `Ready` while it is, `Drafted` while a draft exists, `Accepted` when the trunk advances, `Deleted` when the branch is removed. Lanes are the actors; delivery is a parameter of the fork. The operator's choice is the queue, not a branch state: `blocked` and `parked` are not states, because the meaningful question is whether the branch can merge and whether the operator has taken it.

The draft's package and confirm detail becomes a section of the same model: the package forms and the fork-point rule, and the confirm sequence with its record invariants and failure states. The separate draft chart retires, and `branching.md`'s lifecycle section links to the model rather than restating it.

Out of scope: the host verb mechanics, the draft worktree's implementation, the queue's order, the TLA+ proof of the new module beyond its structure, and the other open M3.7.2 rows.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The model document renders one chart and one `## The transitions` table covering the fork to deletion, with mergeability as the axis. | `bash scripts/check_change_model.sh`; `grep -c "Working\|Deleted" tests/model/change_model/chart.mmd` is non-zero | Agent [x] |
| The home holds the unified chart and table, and `--write` reproduces the rendered copy. | `bash tests/test_model_home.sh` | Agent [x] |
| `draft_branch_statechart.md` is retired; `## The package` and `## The confirm sequence` carry its content; no link to it remains. | `grep -rn "](.*draft_branch_statechart" docs .agents scripts` is empty; `grep -n "## The package\|## The confirm sequence" docs/reference/change_model.md` finds both | Agent [x] |
| The draft statechart gate is retired; `scripts/lint.sh` runs the change model gate only. | `grep -rn "check_draft_statechart" scripts tests` is empty; `bash scripts/lint.sh` clean | Agent [x] |
| `branching.md`'s `## Lifecycle` links the model and states no separate lifecycle. | `grep -n "change_model" .agents/skills/git-discipline/references/branching.md` | Agent [x] |
| The ADR carries the dated decision and links the model. | `grep -n "2026-11-16" docs/adr/change_model.md` | Agent [x] |
| Every transition has a lane, actor, event, guard, invariant, test and mutation. | `bash scripts/check_change_model.sh` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table against the file table | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The model's object is the change from its fork to its deletion; lanes are actors; delivery is a parameter of the fork. | The split made the branch work, mergeability and the draft three machines with no shared state; the lifecycle is the object they all describe. | this handover |
| The lifecycle's axis is mergeability, not branch-work states: `Working` is not-ready, `Ready` is mergeable, `Accepted` is merged; `Blocked` and `Parked` are not states. | A dependency and a decision both leave the branch mergeable-but-not-taken or not-yet-mergeable; the operator's choice is the queue, which the model already states as a view over the ready set. | this handover |
| The draft chart's package and confirm detail becomes sections of the unified model; `draft_branch_statechart.md` retires; `branching.md`'s lifecycle links here. | One subject in one mode has one source; the detail survives as sections, not a peer chart. | this handover |
| One home and one gate: `tests/model/change_model/` holds the chart, the table and the TLA; `check_change_model.sh` holds the unified table to the chart; the draft statechart gate retires. | Two gates over one model is a second source for the same claim. | this handover |
| The confirm sequence keeps its record invariants and failure states as a section contract; its tests remain. | The record's presence is the host flow's safety property and outlives the chart's shape. | this handover |
| The TLA module models the lifecycle states and transitions; TLC stays a manual check. | The home's module is the executable statement of the model; the suite does not run TLC. | this handover |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The model is split across `change_model.md`, `draft_branch_statechart.md` and `branching.md`; the change model's own edge case delegates the draft's internals to another document, contradicting R4's "one model". | design | a reader must assemble one lifecycle from three documents | this iteration |
| `draft_branch_statechart.md` carries two charts and its own gate; `branching.md` carries the branch lifecycle as prose with no chart. | record | the same subject has three sources and one has no model | this iteration |
| The draft chart's record and confirm content is current and is the evidence for its tests; it must survive the move. | record | a retirement that drops it loses the contract | this iteration, the confirm section |
| `draft_branch_statechart.md` is linked from `diff_packaging.md`, `change_model.md` and the change model ADR. | record | a retired file leaves dangling links | this iteration |
| The draft chart's `P`/`C` gates check edge ids, tests and mutations; retiring the chart without a replacement loses those checks. | gate | the package and confirm detail would be unguarded | this iteration, the unified table and section contract |
| `change_model.md` delegates `cut`, `working`, `blocked` and `parked` to `branching.md`, which defines none of them; the four names have no source. | record | a reader cannot learn what `blocked` and `parked` mean, and the model would inherit an undefined state | this iteration |
| `Blocked` and `Parked` are not distinct states: a dependency and a decision both leave the branch not-yet-mergeable or mergeable-but-not-taken; the operator's choice is the queue. | design | a branch-work state would be a second source for what mergeability derives | this iteration, D2 |

## Completed

| File | One-line change |
|---|---|
| `devlog/roadmap.md` | `roadmap-maintenance` run: 0 findings; the row closes with its outcome and handover link |
| `docs/reference/change_model.md` | One lifecycle from fork to deletion; package and confirm sections; the rendered chart and table |
| `tests/model/change_model/chart.mmd` | The unified lifecycle chart |
| `tests/model/change_model/transitions.md` | The unified transition table |
| `tests/model/change_model/ChangeModel.tla` | The lifecycle module and config |
| `tests/model/change_model/ChangeModel.cfg` | Verified; the config is unchanged |
| `tests/model/change_model/model.md` | Provenance for the unified home |
| `docs/reference/draft_branch_statechart.md` | Retired; its content is in the model |
| `docs/reference/workflow_statechart.md` | The change-flow pointer names the branch's life |
| `docs/reference/workflow_statechart.md` | The change-flow pointer names the branch's life |
| `docs/adr/change_model.md` | The 2026-11-16 entry and the current date |
| `docs/adr/diff_packaging.md` | The confirm section link |
| `.agents/skills/git-discipline/references/branching.md` | `## Lifecycle` links the model |
| `scripts/lint.sh` | Runs the change model gate only |
| `scripts/check_change_model.sh` | Unchanged; reads the unified home |
| `scripts/lint/change_model.mjs` | Unchanged; the lifecycle vocabulary and table pass |
| `tests/test_change_model.sh` | Unchanged; the fixture and real-tree cases pass |
| `tests/test_model_home.sh` | Unchanged; 4/4 against the unified home |
| `tests/test_change_model_delivery.sh` | Unchanged; the delivery phrases remain |
| `scripts/check_draft_statechart.sh` | Retired with the draft chart |
| `scripts/lint/draft_statechart.mjs` | Retired with the draft chart |
| `tests/test_draft_statechart.sh` | Retired with the gate |
