---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The change model is a peer reference the statechart points at

## Objective

Make the change model a peer machine the workflow statechart points at: replace
its two-row change-flow table with a pointer, read the command-coverage query
against the prompt table alone, and state the orthogonal relation in the change
model.

## Scope

Works M3.7.2's *The change model is a peer reference the statechart points at*.
Out of scope: the model-as-code move and the unified fork-to-deletion lifecycle.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The statechart's change-flow table is a pointer to `change_model.md`; the `## Change-flow commands` table is gone. | `grep -n "## Change-flow commands" docs/reference/workflow_statechart.md` is empty; the pointer names `change_model.md` | Agent [x] |
| The `## Commands` query reads only the prompt table, and the command-coverage row says so. | `grep -n "reads both\|Change-flow commands" docs/reference/workflow_statechart.md` is empty | Agent [x] |
| No stale count of the change-flow commands remains. | `grep -n "three commands\|two commands" docs/reference/workflow_statechart.md` is empty | Agent [x] |
| The change model states that the two machines are orthogonal and the flow is entered at packaging. | `grep -n "peer machine\|orthogonal" docs/reference/change_model.md` finds the relation section | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The change flow is a peer machine, not nested: the two charts have different objects and may rest at any pair of states. | The statechart's own opening called it "a separate machine", while its table listed two of the eleven events and implied nesting. | This record; `docs/reference/change_model.md` |
| The statechart points at `change_model.md` and keeps no change-flow rows. | One source per mode: the change model is shipped and owns the transitions; a second two-row table was a partial copy. | This record; the roadmap row |
| The command-coverage query reads the prompt table alone. | The change flow has no prompt on this chart; a query naming a section that no longer carries rows is dead. | This record; `docs/reference/workflow_statechart.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The `## Commands` intro called the change flow "three commands" after `/merge-queue` was retired; the change-flow table held two. | record | a stale count and a partial copy in the same section | fixed in this iteration |
| The statechart had no statement of how the change flow relates to the iteration's states. | record | a reader could read the two charts as nested | fixed in `change_model.md`'s `## The iteration relation` |

## Completed

| File | One-line change summary |
|---|---|
| `docs/reference/workflow_statechart.md` | the change-flow table replaced by a pointer; the coverage query reads the prompt table; the stale count removed |
| `docs/reference/change_model.md` | the `## The iteration relation` section states the orthogonal relation |
| `devlog/roadmap.md` | the row closed |
| `devlog/handovers/M3.7.2/20261112-05-workflow-change_model_peer.md` | this record |
