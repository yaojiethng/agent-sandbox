# Autonomous Agent Loop

The autonomous agent loop is the continuous cycle by which the coding agent advances work: a milestone is opened, scoped, iterated, and closed, then the next milestone begins. It is one loop, not two cadences. The workflow runbooks under `workflow/coding-agent/prompts/` drive the loop's state transitions; each workflow enforces a different transition in the loop. Policy files under `docs/operations/` own the invariants those transitions must not break.

The [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) ADR records the decisions behind the loop-and-workflow split and the rule behind each transition. This document draws the model.

## The loop

One workflow is one arrow. A node is a state the loop rests in; a gate is a node where the loop waits for the operator, and the arrow out of a gate is a decision. The loop runs at two grains, drawn once each. The rules behind each arrow -- the three edge types and the three gate states -- are in [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md#transitions).

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

Closing is the work that follows a gate decision, not a state; the close-seam rules are in the [ADR](../adr/coding_agent_loop_workflow.md#transitions).

## Workflows

Each workflow enforces one group of state transitions in the loop.

| Workflow | Transition it drives |
|---|---|
| `/milestone-start` | shapes and opens a milestone |
| `/plan` | scopes a milestone; commissions stories and investigations; produces the roadmap entry |
| `/iter` | runs one iteration: scope, design, implementation, documentation, handover |
| `/wrapup` | lands the delivery commit and closes the handover; the shared close runbook |
| `/sequential-work`, `/parallel-work` | run an iteration autonomously (single or fan-out); the `-work` dispatch family, owned and refined by M3.2.3 |
| `/milestone-close` | records a milestone or sub-milestone close: compaction, the changelog, the close boundary |

`/wrapup` is a shared close runbook, not a standalone loop workflow: `/iter`, `/plan` and `/document` invoke it after their release point. `/milestone-start`, `/sequential-work` and `/parallel-work` do not invoke it.

The `/auto` smart dispatcher and `/goal` loose-goal decomposition are M4's. They are not `/iter` work-loop expansions and they do not drive a transition in this loop yet.

`/backlog-triage` drives no transition either. It sorts the open roadmap rows into the ones a dispatch shape can run and the ones carrying a question, so those questions are answered before a run starts rather than at a mid-run stop. The autonomous rows above consume its output.

## Skills

A workflow dispatches a narrow, repeatable job to a skill rather than inlining its procedure. The record-check skills [`roadmap-maintenance`](../../workflow/coding-agent/skills/roadmap-maintenance.md) and [`handover-maintenance`](../../workflow/coding-agent/skills/handover-maintenance.md) own the record checks, the corrections each may apply, and the defects each reports: `/gm` runs both over the roadmap and the handover chain, `/milestone-close` runs `roadmap-maintenance` for the compaction pass, and `/wrapup` runs `handover-maintenance` to close a landed record. `/plan` and `/document` pass their session context to the `grill-me` skill for the interview. A skill owns its procedure; the workflow owns the transition that invokes it.

## Responsibilities

A workflow owns its steps and the transitions it drives. Policy owns the invariants those transitions must not break. A gate is a stop-and-wait check that output conforms to the expected state. Details are in the ADR and in the workflow prompts under `workflow/coding-agent/prompts/`.
