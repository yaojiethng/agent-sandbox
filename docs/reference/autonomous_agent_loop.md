---
reader: [agent]
---

# Autonomous Agent Loop

The autonomous agent loop is the continuous cycle by which the coding agent advances work: a milestone is opened, scoped, iterated, and closed, then the next milestone begins. It is one loop, not two cadences. The workflow runbooks under `workflow/coding-agent/prompts/` drive the loop's state transitions; each workflow enforces a different transition in the loop. The iteration protocol, [`iteration_protocol.md`](iteration_protocol.md), owns the invariants those transitions must not break.

The `docs/adr/coding_agent_loop_workflow.md` ADR records the decisions behind the loop-and-workflow split and the rule behind each transition. This document draws the model.

## The loop

One workflow is one arrow. A node is a state the loop rests in; a gate is a node where the loop waits for the operator, and the arrow out of a gate is a decision. The loop runs at two grains, drawn once each. The rules behind each arrow -- the three edge types and the three gate states -- are in `docs/adr/coding_agent_loop_workflow.md#transitions`.

The diagram is [`workflow_statechart.md`](workflow_statechart.md), which draws the whole surface: both grains, every slash command, every dispatch from one prompt to another, and every maintenance check a runbook invokes. A state there is cited by its id, and a behaviour here is a path through it.

At the acceptance gate, the agent presents the findings queue, with each entry's destination. It also presents the record-check reports for the records the iteration changed.

Closing is the work that follows a gate decision, not a state. It lands what the gate confirmed and raises what the gate missed. The close-seam rules are in `docs/adr/coding_agent_loop_workflow.md#transitions`.

## Workflows

Each workflow enforces one group of state transitions in the loop.

| Workflow | Transition it drives |
|---|---|
| `/milestone-start` | shapes and opens a milestone |
| `/plan` | scopes a milestone; commissions stories and investigations; produces the roadmap entry |
| `/iter` | runs one iteration: scope, design, implementation, documentation, handover |
| `/sidequest` | pauses an open iteration for operator-directed work, then returns to the handover it interrupted |
| `/wrapup` | closes the handover, writes back the roadmap task and seeds the next iteration; the shared close runbook |
| `/commit` | lands the unit's delivery commit; the shared commit runbook |
| `/sequential-work`, `/parallel-work` | run an iteration autonomously (single or fan-out); the `-work` dispatch family, which is a pair of drafts and not a shipped prompt, owned and refined by M3.2.3 |
| `/milestone-close` | records a milestone or sub-milestone close: compaction, the changelog, the close boundary |

`/wrapup` and `/commit` are shared runbooks, not standalone loop workflows. `/iter`, `/plan` and `/document` invoke `/wrapup` after their release point, and the close hands the commit to `/commit`. `/commit` is also reached directly by `/sidequest`, which lands its own delivery commit, and by `/merge`, which folds a replay's corrections. `/milestone-start` does not invoke either -- the milestone-record close is `/milestone-close` and lands its own bookkeeping commit.

`/wrapup` closes the handover to the `work-log` convention, and `/commit` lands the work, the status flip and the write-back as one delivery commit. The pre-commit handover format gate checks the record's shape.

The `/auto` smart dispatcher and `/goal` loose-goal decomposition are M4's. They are not `/iter` work-loop expansions and they do not drive a transition in this loop yet.

`/backlog-triage` drives no transition either. It sorts the open roadmap rows into the ones a dispatch shape can run and the ones carrying a question, so those questions are answered before a run starts rather than at a mid-run stop. The autonomous rows above consume its output.

## Skills

A workflow dispatches a narrow, repeatable job to a skill rather than inlining its procedure. The record-check skills [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) and [`handover-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/handover-maintenance/SKILL.md) own the record checks and report the violations they find; they write nothing, and the workflow that dispatches one applies the report. A skill owns its procedure; the workflow owns the transition that invokes it.

Which command invokes which skill is not stated here. [`workflow_statechart.md`](workflow_statechart.md) declares the maintenance set and draws the edge from each dispatching command, and its `## Checks` section names the query that finds a check no command reaches.

## Responsibilities

A workflow owns its steps and the transitions it drives. Policy owns the invariants those transitions must not break. A gate is a stop-and-wait check that output conforms to the expected state. A finding is a record with a destination from the moment it is written. The handover's Findings section is the one surface it lives on. Details are in the ADR and in the workflow prompts under `workflow/coding-agent/prompts/`.
