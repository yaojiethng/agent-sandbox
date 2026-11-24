---
reader: [agent]
---

# Autonomous Agent Loop

The autonomous agent loop is the continuous cycle by which the coding agent advances work: a milestone is opened, scoped, iterated, and closed, then the next milestone begins. It is one loop, not two cadences. The workflow runbooks under `workflow/coding-agent/prompts/` drive the loop's state transitions; each workflow enforces a different transition in the loop. The iteration protocol, [`iteration_protocol.md`](iteration_protocol.md), owns the invariants those transitions must not break.

The ADR `coding_agent_loop_workflow.md` (repository-only) records the decisions behind the loop-and-workflow split. The model is [`workflow_statechart.md`](workflow_statechart.md); this document explains why the loop is split and points at it.

## The loop

The loop runs at two grains, the milestone and the iteration, and the whole surface -- every state, gate, command and maintenance check -- is drawn in [`workflow_statechart.md`](workflow_statechart.md). Its opening states the grammar: a node is a state, a gate is where the loop waits for the operator, an arrow is a command or a release, and closing is the work that follows a gate decision rather than a state. A state there is cited by its id, and a behaviour here is a path through it.

The release gate's rules, including the record checks that run before it, are the ADR's 2026-10-20 entry.

## The workflow set

Each workflow enforces one group of the loop's transitions. The set -- the command, the state it fires from, the state it leaves and the skills it dispatches -- is the statechart's `## Commands` table, and the chart is the authority for the set. `/wrapup` and `/commit` are shared runbooks rather than standalone workflows: `/iter` and `/plan` invoke the close after their release point, and the close hands the commit to `/commit`. `/sidequest` and the `prepare` runbook reach `/commit` directly.

`/auto` and `/goal` are M4's and drive no transition here. `/backlog-triage` drives none either: it sorts the open rows so a dispatch shape can run them, rather than running an iteration.

## Skills

A workflow dispatches a narrow, repeatable job to a skill rather than inlining its procedure. The record-check skills [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) and the `work-log` handover runbook own the record checks and report the violations they find; they write nothing, and the workflow that dispatches one applies the report. A skill owns its procedure; the workflow owns the transition that invokes it.

Which command invokes which skill is not stated here. [`workflow_statechart.md`](workflow_statechart.md) declares the maintenance set and draws the edge from each dispatching command, and its `## Checks` section names the query that finds a check no command reaches.

## Responsibilities

A workflow owns its steps and the transitions it drives. Policy owns the invariants those transitions must not break. A gate is a stop-and-wait check that output conforms to the expected state. A finding is a record with a destination from the moment it is written. The handover's Findings section is the one surface it lives on. Details are in the ADR and in the workflow prompts under `workflow/coding-agent/prompts/`.
