# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Design
**Status:** Closed

## Objective

Decide the loop-documentation structure: whether major/minor loop docs split into separate policies, the form of the split, and the canonical `milestone_policy` / `iteration_policy` boundary, so the `milestone_policy` expansion to own the whole major loop can ride on it.

## Scope

Roadmap task `Loop-documentation structure decision`, deferred from session `20260809-04`. Decision and its structural application; the milestone_policy expansion itself is a separate follow-up.

## Carried forward

| Item | From handover |
|---|---|
| Decide whether loop docs split on the major/minor line, the form, and the canonical milestone_policy / iteration_policy boundary | roadmap (`20260809-04`) |
| The milestone_policy expansion to own the whole major loop | rides on this decision |

## Acceptance criteria

- `autonomous_agent_loop.md` becomes the model home: one autonomous agent loop, its sequence diagram, and the workflow-to-transition mapping.
- `major loop` / `minor loop` / `two loops` terminology is removed from all live surfaces, replaced by `milestone workflow` / `iteration workflow` / `autonomous agent loop` (historical handovers and `docs/adr/archive/` keep their dated wording).
- `iteration_policy.md` drops the two-loops and major-loop sections; `milestone_policy.md` reads milestone-workflow.
- The `coding_agent_loop_workflow.md` ADR realigns its taxonomy and state diagram.
- Markdown lint clean.

## Hot files

| File | Why in scope |
|---|---|
| `docs/operations/iteration_policy.md` | currently carries the two-loop taxonomy and a Major Loop section overlapping milestone_policy |
| `docs/operations/milestone_policy.md` | the major loop policy |
| `docs/concepts/autonomous_agent_loop.md` | the concept offload target for the two-loop taxonomy (per the offload map) |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Keep `milestone_policy` / `iteration_policy` as the two canonical loop policies; do not create synthetic `major_loop_policy` / `minor_loop_policy` | the existing names already encode the split (milestone = milestone workflow, iteration = iteration); a rename would churn every inbound link for no boundary change | this handover |
| Drop `major loop` / `minor loop` terminology from all live surfaces; the agent runs the one autonomous agent loop, and workflows enforce its state transitions | the terms were a coarse stand-in from before precise names existed; milestone and iteration now name the two phases, and the loop model + sequence diagram land in the concept doc | this handover; `autonomous_agent_loop.md`; `coding_agent_loop_workflow.md` |

## Findings

| Finding | Type | Impact |
|---|---|---|
| `iteration_policy.md` carried both a two-loop taxonomy and a major-loop section that duplicated `milestone_policy.md` -- the major/minor framing was redundant with the precise milestone/iteration names | duplication | resolved this iteration - removed from `iteration_policy`; the model moved to `autonomous_agent_loop.md`, the milestone phase to `milestone_policy.md` |
| `major loop` / `minor loop` were a coarse stand-in for milestone / iteration eras; the repo now has precise terms and workflow runbooks to name the phases | terminology | replaced this iteration across ~18 live files (policy, ADR, concept, prompts, AGENTS) |

## Completed

| File | Change |
|---|---|
| `docs/concepts/autonomous_agent_loop.md` | became the loop model home: the single autonomous agent loop, a sequence diagram, and the workflow-to-transition table |
| `docs/operations/iteration_policy.md` | removed the two-loops and major-loop sections; retitled `## Iteration Invariants` (anchor changed); terminology swept |
| `docs/operations/milestone_policy.md` | `major loop` to `milestone workflow` throughout; section titles renamed (Purpose of the Milestone Workflow, Stories, Investigations, Closing the Milestone Workflow) |
| `docs/adr/coding_agent_loop_workflow.md` | decision text, workflow taxonomy table, and state diagram realigned to the one-loop / workflows model |
| story/study/handover/discussion/roadmap/documentation policy + `agent_workflow` + `prompt-authoring-conventions` | major/minor to milestone/iteration; `#iteration-invariants` anchor repointed |
| `plan.md`, `milestone-start.md`, `iter.md` prompts | title/description and anchor updates |
| `AGENTS.md` | iteration terminology + `#iteration-invariants` anchor |
| `devlog/roadmap.md` | task marked done with the landing note |

## Deferred items

| Item | Reason | Where it goes next |
|---|---|---|
| The `milestone_policy` expansion to own the whole milestone workflow | the structural decision is landed; the expansion is a separate growth task | the Docs-and-ADR consolidation group |

## What's Next

Docs-and-ADR-consolidation group: the `milestone_policy` expansion to own the whole milestone workflow, and continued `autonomous_agent_loop` growth.

**Conclusions:** the loop-documentation structure decision is landed - two canonical files (`milestone_policy` = milestone workflow, `iteration_policy` = iteration), the `major loop` / `minor loop` terms removed from every live surface, and the single autonomous agent loop with its sequence diagram established in `autonomous_agent_loop.md`. Lint clean.
