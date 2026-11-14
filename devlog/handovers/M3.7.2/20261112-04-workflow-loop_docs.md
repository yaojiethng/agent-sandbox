---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The loop's three documents have one job each

## Objective

Give the loop's three documents one job each: the statechart owns the model and
its grammar, the concept document explains the split and points at the chart,
and the ADR keeps the dated decisions with no current table.

## Scope

Works M3.7.2's *The loop's three documents have one job each*. Out of scope: the
change model's peer-reference relation and the statechart's change-flow table
(the next row), and the model-as-code move.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The gate grammar appears once, in the statechart's opening; the ADR's `## Transitions` and the concept's grammar are gone. | `grep -rn "Three edge types" docs` names the statechart alone; `grep -n "## Transitions" docs/adr/coding_agent_loop_workflow.md` is empty | Agent [x] |
| The workflow set appears once, in the statechart's `## Commands`; the ADR's taxonomy table and the concept's nine-row table are gone. | `grep -n "## The loop taxonomy\|## Workflows"` over the three documents is empty | Agent [x] |
| The ADR carries no current taxonomy or offload instruction. | `grep -n "## The loop taxonomy\|## Concept offload map" docs/adr/coding_agent_loop_workflow.md` is empty | Agent [x] |
| The concept document links only targets the shipped tree carries; no `docs/adr/` link remains in it. | `grep -n "docs/adr" docs/reference/autonomous_agent_loop.md` is empty; `scripts/check_instruction_surfaces.sh` clean | Agent [x] |
| `**Current:**` names the newest ADR entry. | `grep -n "Current:" docs/adr/coding_agent_loop_workflow.md` reads `2026-10-20` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The statechart's opening owns the transition grammar (three edge types, three gate states), not the ADR. | The statechart is shipped and the ADR is repository-only; a grammar a shipped reader cannot reach is a routing defect. The chart and its rules now sit together. | This record; `docs/reference/workflow_statechart.md` |
| The workflow set is the statechart's `## Commands` table; the ADR and concept tables are deleted. | Two current tables disagreed (eleven rows against nine); one set has to be the authority, and the chart is the shipped model. | This record; the roadmap row |
| The concept document names the ADR without linking it. | The ADR is repository-only; the statechart already states that it cannot be linked from the shipped tree. | This record; `docs/reference/autonomous_agent_loop.md` |
| The ADR's 2026-10-03 correction is re-dated to 2026-11-12 to name the statechart as the home of the rules. | The correction pointed at a section this iteration deleted; leaving it would be a dangling reference. | This record; `docs/adr/coding_agent_loop_workflow.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The ADR's correction block still said the diagram's home was the concept document, which the statechart had already superseded. | record | a stale pointer that the row's deletion would have dangled | fixed in this iteration; the Decisions table |
| The concept document's `## Workflows` table omitted `/auto`, `/goal` and `/backlog-triage` while the ADR included them; the statechart's `## Commands` carries the full set. | record | the disagreement the row named | fixed by removing both tables |

## Completed

| File | One-line change summary |
|---|---|
| `docs/adr/coding_agent_loop_workflow.md` | deleted the taxonomy, transitions and offload sections; re-dated the correction; `**Current:**` is the newest entry |
| `docs/reference/autonomous_agent_loop.md` | removed the grammar, the workflow table and the ADR links; points at the statechart |
| `docs/reference/workflow_statechart.md` | the opening states the edge types and gate states |
| `devlog/roadmap.md` | the row closed |
| `devlog/handovers/M3.7.2/20261112-04-workflow-loop_docs.md` | this record |
