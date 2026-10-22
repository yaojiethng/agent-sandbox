---
reader: [agent]
---

# Autonomous Agent Loop

The autonomous agent loop is the continuous cycle by which the coding agent advances work: a milestone is opened, scoped, iterated, and closed, then the next milestone begins. It is one loop, not two cadences. The workflow runbooks under `workflow/coding-agent/prompts/` drive the loop's state transitions; each workflow enforces a different transition in the loop. The iteration protocol, [`iteration_protocol.md`](iteration_protocol.md), owns the invariants those transitions must not break.

The `docs/adr/coding_agent_loop_workflow.md` ADR records the decisions behind the loop-and-workflow split and the rule behind each transition. This document draws the model.

## The loop

One workflow is one arrow. A node is a state the loop rests in; a gate is a node where the loop waits for the operator, and the arrow out of a gate is a decision. The loop runs at two grains, drawn once each. The rules behind each arrow -- the three edge types and the three gate states -- are in `docs/adr/coding_agent_loop_workflow.md#transitions`.

```text
MILESTONE GRAIN

  [ms:none]                                  no active milestone
      |
      |  "milestone to promote?"              workflow-assisted operator decision
      |    no  -> /milestone-start shapes one     (/milestone-start presents the shapes)
      |    yes -> the operator picks one
      v
  [ms:active]  ----------  iterations run against this milestone
      |
      |  /milestone-close                     workflow-implemented
      v
  [ms:close-gate]                            compaction, changelog, boundary presented
      |
      |  operator release                     operator decision
      v
  [ms:successor?]                            handwaved: one milestone is modelled
      |
      |  yes -> promote                       workflow-assisted operator decision
      |  no  -> shape one                    (edge to ms:none above)
      v
  [ms:active]  (the successor)

ITERATION GRAIN  (drawn once; runs against whichever node is ms:active)

  [it:open] --/iter--> [it:scope-gate] --operator decision--> [it:implementing]
                                                                    |
                                                             /iter Step 7
                                                                    v
  [it:closed] <--operator decision-- [it:acceptance-gate] --/wrapup--> (Part B)
      |
      |  all tasks complete? /wrapup recommends
      +-- yes --> ms:close-gate
      +-- no  --> [it:open]   (operator picks the next task)
```

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
| `/wrapup` | lands the delivery commit and closes the handover; the shared close runbook |
| `/sequential-work`, `/parallel-work` | run an iteration autonomously (single or fan-out); the `-work` dispatch family, owned and refined by M3.2.3 |
| `/milestone-close` | records a milestone or sub-milestone close: compaction, the changelog, the close boundary |

`/wrapup` is a shared close runbook, not a standalone loop workflow: `/iter`, `/plan` and `/document` invoke it after their release point. `/milestone-start`, `/sequential-work` and `/parallel-work` do not invoke it.

`/wrapup` closes the handover to the `work-log` convention. The pre-commit handover format gate checks the record's shape.

The `/auto` smart dispatcher and `/goal` loose-goal decomposition are M4's. They are not `/iter` work-loop expansions and they do not drive a transition in this loop yet.

`/backlog-triage` drives no transition either. It sorts the open roadmap rows into the ones a dispatch shape can run and the ones carrying a question, so those questions are answered before a run starts rather than at a mid-run stop. The autonomous rows above consume its output.

## Skills

A workflow dispatches a narrow, repeatable job to a skill rather than inlining its procedure. The record-check skills [`roadmap-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/roadmap-maintenance/SKILL.md) and [`handover-maintenance`](/opt/workflow/agent/modules/coding-agent/skills/handover-maintenance/SKILL.md) own the record checks and report the violations they find; they write nothing, and the workflow that dispatches one applies the report. `/gm` runs both when the operator asks for an exhaustive check. `/iter` runs both before the release gate, over the records the iteration changed. `/milestone-close` runs `roadmap-maintenance` for the compaction pass, whose input is the whole milestone record. `/plan` and `/document` pass their session context to the `grill-me` skill for the interview. A skill owns its procedure; the workflow owns the transition that invokes it.

## Responsibilities

A workflow owns its steps and the transitions it drives. Policy owns the invariants those transitions must not break. A gate is a stop-and-wait check that output conforms to the expected state. A finding is a record with a destination from the moment it is written. The handover's Findings section is the one surface it lives on. Details are in the ADR and in the workflow prompts under `workflow/coding-agent/prompts/`.
