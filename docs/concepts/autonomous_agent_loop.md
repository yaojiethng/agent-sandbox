# Autonomous Agent Loop

The autonomous agent loop is the continuous cycle by which the coding agent advances work: a milestone is opened, scoped, iterated, and closed, then the next milestone begins. It is one loop, not two cadences. The workflow runbooks under `workflow/coding-agent/prompts/` drive the loop's state transitions; each workflow enforces a different transition in the loop. Policy files under `docs/operations/` own the invariants those transitions must not break.

The [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) ADR records the decisions behind the loop-and-workflow split and the state diagram.

## The loop

```text
milestone-start        plan (scoping)         story / investigation
     │                     │                          │
     ▼                     ▼                          ▼
streamlined open    scoped milestone           roadmap entry
     │                     │                          │
     └─────────────────────┴──────────────────────────┘
                              │
                              ▼
          iteration (iter / sequential-work / parallel-work)
             runs an iteration, closes in a handover
                              │
                              ▼
                    pre-close verification
                              │
                              ▼
      milestone-close (records the close)  ──▶  next milestone
```

The loop returns to the top: closing a milestone opens the next one.

## Workflows

Each workflow enforces one group of state transitions in the loop.

| Workflow | Transition it drives |
|---|---|
| `/milestone-start` | opens a milestone |
| `/plan` | scopes a milestone; commissions stories and investigations; produces a roadmap entry |
| `/iter` | runs one iteration: scope, design, implementation, documentation, handover |
| `/sequential-work`, `/parallel-work` | run an iteration autonomously (single or fan-out); the `-work` dispatch family, owned and refined by M3.2.3 |
| `/milestone-close` | records a milestone or sub-milestone close; pre-close verification |

The `/auto` smart dispatcher and `/goal` loose-goal decomposition are M4's. They are not `/iter` work-loop expansions and they do not drive a transition in this loop yet.

## Responsibilities

A workflow owns its steps and the transitions it drives. Policy owns the invariants those transitions must not break. A gate is a stop-and-wait check that output conforms to the expected state. Details are in the ADR and in the workflow prompts under `workflow/coding-agent/prompts/`.
