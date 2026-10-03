# Design: the major and minor loops as workflows (M3.2.1)

**Status:** settled -- design captures the grill-me walk of 2026-09-28. The migration it scopes is M3.2.1. The separation of procedure from rules is settled in [`policy_declarative_framing.md`](../../docs/adr/policy_declarative_framing.md).

## Purpose and scope

M3.2.1 moves the major and minor loops out of policy and into workflows. `iteration_policy.md` and `milestone_policy.md` keep the rules; the procedure moves into workflow prompts. A workflow owns the steps and the state transitions; a policy owns the invariants those transitions must not break. A workflow is checked against its policy, and a policy change is not a workflow change.

This record captures the design decisions made in the walk. It is the design doc the ADR and the implementation conform to (decision: design doc to ADR to implementation; code conforms to the ADR at loop close).

## The loop taxonomy

The ADR defines what loops the harness targets. The loop surfaces are the four loop kinds plus the two declared expansions of `iter`.

| Loop | Kind | Artifact |
|---|---|---|
| `iter` | base interactive minor loop | rename and move of `src/reasoning/agent/prompts/new-iteration.md` to `workflow/coding-agent/prompts/iter.md` |
| `auto` | declared expansion of `iter` | exists (`auto.md`) |
| `parallel-auto` | declared expansion of `iter` | exists (`parallel-auto.md`) |
| `milestone-start` | loop kind, major-loop open | stub |
| `milestone-close` | loop kind, major and sub-milestone close | exists (`milestone-close-run.md`), refreshed |
| `plan` | loop kind, major-loop planning | stub (grill-me pointer) |
| `-run` family | out of scope for M3.2.1 | belongs to M3.2.2 consolidation |

The `-run` family (`churn-analysis-run`, `read-through-run`, `review-loop-run`, `review-pass-run`, and the review-consolidation work) is not classified by this ADR. It is M3.2.2 scope, noted as out of scope here.

## The separation rule

Folds into `docs/adr/policy_declarative_framing.md`, which already records that policy states rules declaratively and execution guidance does not belong in policy (2026-07-21).

- Policy lives in `docs/operations/`.
- Prompts (steps) live in `workflow/coding-agent/prompts/`.
- A gate is an instruction to stop and wait for operator feedback, and a check that after a prompt finishes, output conforms to the expected state. It is a check, not a step.
- Move procedure text out of policy into the prompt; the policy keeps a link to the prompt.
- Future possibility: skills-folder structure with policy as an attached workflow artifact, pending a solution for multiple skills sharing one artifact.

## The ADR

A new ADR defines what loops the harness targets and is simultaneously an index, a responsibilities separation, and a high-level conceptual reference. It is the end-goal artifact of M3.2.1, not just this planning session. It is an in-progress deliverable, completed by the end of M3.2.1, added to as the feature lands.

Parts of the ADR not relevant to decision making offload to `docs/concepts/`.

The state diagram of the major/minor loop workflow is part of the ADR, drawn as the invariant spec the migration must satisfy -- not a post-hoc record.

## Concept documents

The T1 stale-artifact-processing task folds into M3.2.1. The stale concept docs (`autonomous_agent_loop.md`, `autonomous_task.md`, the `TASK.md` promised-but-undefined seam, and the manual administrative close checklist) are cleaned up so their names recycle for the feature-generated documents.

`autonomous_agent_loop.md` becomes the conceptual home that covers the major and minor loop workflow and how it dispatches to prompts and skills. It takes over much of the non-policy content of the policy docs. It is the explanatory overview (what the loop is, how it dispatches, responsibilities). The workflow-bundled policy files carry the running prompt's scoped invariants -- complementary, not competing.

## Migration units

The migration is split into units. The skeleton pass is one unit; the policy content migration is split per unit because it is review heavy.

Unit boundaries follow the work-unit policy: one unit is one commit and one handover, and does one reviewable change.

| Unit | Contents | Commit | Review load |
|---|---|---|---|
| U1 skeleton | ADR-index shell; four prompt stubs (`iter` rename-move from `new-iteration.md`, `plan` grill-me stub, `milestone-start`, `milestone-close` refresh); `autonomous_agent_loop.md` concept shell; policy link pointers | `workflow:` | low |
| U2 | minor-loop procedure from `iteration_policy.md` into `/iter` prompt content | `workflow:` | high |
| U3 | major-loop procedure from `iteration_policy.md` and `milestone_policy.md` into `/plan` and `/milestone-start` | `workflow:` | high |
| U4 | close procedure from `milestone_policy.md` and `iteration_policy.md` Sub-milestone close into `/milestone-close` | `workflow:` | high |

After the migration, four per-prompt quality passes raise `/iter`, `/milestone-start`, `/milestone-close` and `/plan` to an operator-approved bar, each its own roadmap task and handover.
