---
date: 2026-10-29
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - Write the fork-and-strip convention and strip the first fork

## Objective

Write the convention a fork of an upstream skill reads, fix the two Claude-only subagent calls in `improve-codebase-architecture`, and record that skill's provenance.

## Scope

Works the first subtask of the parent row **Package skill ingestion as its own workflow**, filed in this iteration. Delivers the subtask **Fork-and-strip convention**. The convention lands as a pattern beside `skill-scaffolder`, the skill a skill author already opens. The two concrete instances are `improve-codebase-architecture/SKILL.md` and its `INTERFACE-DESIGN.md`, each naming the Agent tool and `subagent_type=Explore` or a parallel Agent-tool fan-out. The forked skill lands with its `MAINTENANCE.md`, because the fork is the pipeline's first real instance and a fork without its record does not demonstrate the convention.

Out of scope, one sentence each with the reason: the remaining skill backfill stays with the M3.3.3 row **Every skill in the tree carries a maintenance record**, because this iteration records one fork, not the tree; the `pstack` ingest stays with its own row, because that row holds the batch and the record-shape test; and the merged instruction-writing surface stays with its row, because this iteration writes one procedure, not the surface it will be folded into.

Operator direction at the gate, 2026-10-29: the convention lives under `skill-scaffolder`, which is already at `.agents/skills/skill-scaffolder/`; `skill-scaffolder` later subsumes `prompt-authoring-conventions.md`; and the three skill-ingestion members are packaged as their own workflow in a future task. The last two are roadmap rows, not this unit.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| No provider-specific subagent call remains in the two live files, and each names the `dispatch` skill | `rg -n 'Agent tool\|subagent_type'` over `SKILL.md` and `INTERFACE-DESIGN.md` prints nothing; `rg -n 'dispatch'` prints a hit in each; `rg -n 'pi -p'` prints nothing in either file or the pattern | Agent [x] |
| Each replacement preserves the read-only capability and the parallel form | both files name the `dispatch` skill; `INTERFACE-DESIGN.md` names the parallel dispatch, one brief each | Agent [x] |
| The convention is reachable from `skill-scaffolder`, carries its steps, and names the maintained provider-artifact list | the index row and step-1 pointer name the pattern; the pattern has `## The steps` and `## The test`; `rg -n 'provider-artifacts'` hits the fork pattern; the list file exists | Agent [x] |
| The forked skill carries a maintenance record naming its source and each stripped mechanic | `MAINTENANCE.md` exists; `rg -n '^## (Source\|Adapted\|Name)$'` prints 3; it names `mattpocock` and both stripped APIs | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table read against `git diff` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The convention is a `skill-scaffolder` pattern, not a new top-level document or a new skill | The next fork is a skill-creation act, and `skill-scaffolder` is what that author already opens. A pattern is the nested-file form for a mechanical move, and a new top-level skill would add a second entry point beside the scaffolder. The operator directed this placement on 2026-10-29; `skill-scaffolder` is already at `.agents/skills/skill-scaffolder/`, so no move is needed. | this record; the pattern |
| A subagent goes through the `dispatch` skill; the fork convention delegates the invocation and does not restate it | The dispatch skill resolves the role, runs the child and records the log. A model, flag or read-only tool set named in the fork convention would be a second copy of the invocation, so the convention names the interface and stops. | this record; the pattern |
| The fork lands with `MAINTENANCE.md` | A fork without its record is a copy. This is the pipeline's first real fork, so the record is the test of the convention rather than a later backfill. | this record; `improve-codebase-architecture/MAINTENANCE.md` |
| The record names the upstream as `mattpocock/skills` at the import commit, and states the revision is unrecorded | The import commit names the source repository, and the absence of a revision is a fact. Inventing a revision would make the record read as provenance it does not have. | `improve-codebase-architecture/MAINTENANCE.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Operator direction 2026-10-29: the convention stays with `skill-scaffolder`; `skill-scaffolder` later subsumes `prompt-authoring-conventions.md`; the skill-ingestion parent is split into three subtasks | steering | settles the placement; the second is a future task and the third files the parent with this fork as its first subtask | roadmap M3.3.3, the subsumption row and the parent's three sub-rows |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/skill-scaffolder/patterns/fork-and-strip.md`](../../.agents/skills/skill-scaffolder/patterns/fork-and-strip.md) | the fork-and-strip convention: pin, copy, inventory, strip, record, verify |
| [`.agents/skills/skill-scaffolder/patterns/provider-artifacts.md`](../../.agents/skills/skill-scaffolder/patterns/provider-artifacts.md) | the maintained inventory of provider artifacts and their replacements |
| [`.agents/skills/skill-scaffolder/SKILL.md`](../../.agents/skills/skill-scaffolder/SKILL.md) | the index rows and step-1 pointer that make the patterns reachable |
| [`improve-codebase-architecture/SKILL.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/SKILL.md) | the exploration call now dispatches a read-only child through the `dispatch` skill |
| [`improve-codebase-architecture/INTERFACE-DESIGN.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/INTERFACE-DESIGN.md) | the parallel fan-out now dispatches read-only children through the `dispatch` skill, one brief each |
| [`improve-codebase-architecture/MAINTENANCE.md`](../../src/reasoning/agent/skills/improve-codebase-architecture/MAINTENANCE.md) | the fork's record: source, adaptation, name |
| [`devlog/roadmap.md`](../roadmap.md) | roadmap check at start; the skill-ingestion parent split into three subtasks; the subsumption row retitled; the fork-and-strip subtask marked complete |
| [`devlog/handovers/20261029-11-workflow-fork_and_strip_convention.md`](20261029-11-workflow-fork_and_strip_convention.md) | this record |
