# Agent Handover

**Session date:** 2026-03-24
**Milestone:** M2.2 — Reasoning Layer Modularisation
**Session type:** Workflow

## Objective
Identify and close the doc-update enforcement gap in the minor loop: architecture and concepts documents were intended to land before implementation but lacked gates preventing deferral.

## Scope
Workflow audit of doc update sequencing. No roadmap tasks — this session addressed a policy gap identified by operator review of the minor loop step sequence.

## Acceptance criteria

Not yet defined.

## Hot files

| File | Why in scope |
|---|---|
| [`docs/operations/iteration_policy.md`](docs/operations/iteration_policy.md) | Principles, Step 6, Step 7, and Step 8 updated to enforce doc-state as a blocking condition |

## Decisions made this session

| Decision | Rationale | Recorded in |
|---|---|---|
| Doc deferral blocks Trigger B | Without a hard block, doc updates accumulated as cleanup across milestones. Tying Trigger B to doc state makes deferral costly and visible. | `iteration_policy.md` — Principles, Step 8 |
| Doc divergence found during implementation must be corrected before Step 7 exits | Implementation that reveals a spec divergence is a signal the spec slipped — the correction belongs in the same session, not the next one. | `iteration_policy.md` — Step 7 |
| Doc state added as a required acceptance criterion for architecture-touching sessions | File-state checks are not normally acceptance criteria, but doc correctness has no runtime observable — this is the appropriate form for this class of criterion. | `iteration_policy.md` — Step 6 |

## Completed this session

| File | Change |
|---|---|
| `docs/operations/iteration_policy.md` | Principles: "Documentation is part of the task" strengthened to name pre-implementation intent, in-session correction requirement, and Trigger B block. Step 6: required doc-state acceptance criterion added for architecture-touching sessions. Step 7: exit condition extended to require architecture documents reflect system as built; mid-implementation correction rule added. Step 8: doc-state verification added to action; doc divergence blocking Trigger B made explicit. |

## Deferred items

None.

## Next session
**M2.2 — Reasoning Layer Modularisation.**

This session was a workflow-only change. M2.2 implementation work is unaffected. Resume from the prior session's (20260318-07) watch-out items:

1. The policy files edited in session 20260318-07 (`roadmap_policy.md`, `iteration_policy.md`, `handover_policy.md`) plus `iteration_policy.md` edited this session must be committed before M2.2 implementation work begins.
2. M2.2 opens with a design step — audit `start_agent.sh` and `container-entrypoint.sh` before any files are changed.
3. The base reasoning image extraction must not bake project-specific content — constraint carried from M2.1.
