# Autonomous Agent Loop

This document is the conceptual overview of the coding agent's loops: what each loop is, how it dispatches to prompts and skills, and its responsibilities. It is the explanatory home for the loop workflows the [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) ADR indexes and separates. It takes over the non-policy content of the policy docs.

This is a shell in U1 of M3.2.1. Its full content builds across the migration units U2-U4 and the per-prompt quality passes.

## The loops

The harness targets four loop kinds, with two declared expansions of `/iter`. See the ADR [`coding_agent_loop_workflow.md`](../adr/coding_agent_loop_workflow.md) for the taxonomy table and the state diagram.

- `/iter` -- the base interactive minor loop.
- `/sequential-work` and `/parallel-work` -- the `/iter` work-loop expansions for autonomous runs, owned and refined by M3.2.3 (the `-work` dispatch command surface).
- `/auto` and `/goal` -- M4's smart dispatcher and loose-goal decomposition (reserved; not `/iter` work-loop expansions).
- `/milestone-start` -- opens the major loop.
- `/milestone-close` -- closes the major and sub-milestone.
- `/plan` -- major-loop planning.

## Responsibilities

A loop owns its steps and state transitions; policy owns the invariants those transitions must not break; a gate is a stop-and-wait check that output conforms to the expected state. Details are in the ADR and in the loop prompts under `workflow/coding-agent/prompts/`.
