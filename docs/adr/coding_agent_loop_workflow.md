# Coding Agent Loop Workflow

**Current:** 2026-09-28

## 2026-09-28 -- Loops are workflows; policy carries the rules

**Decision:** The coding agent runs its major and minor loops as invocable workflow prompts under `workflow/coding-agent/prompts/`. Loop prompts own the steps and the state transitions of a loop. Policy files under `docs/operations/` own the invariants those transitions must not break. A gate is an instruction to stop and wait for operator feedback, and a check that after a prompt finishes, the output conforms to the expected state. The loop prompts are `/iter`, `/milestone-start`, `/milestone-close` and `/plan`; `/auto` and `/parallel-auto` are declared expansions of `/iter`.

**Rationale:** The loops previously lived as step-by-step procedure interleaved with policy rules in `iteration_policy.md` and `milestone_policy.md`, which made the governance surface large and forced every loop change into a policy edit. Separating the procedure into prompts with the policy keeping the rules keeps the shared governance surface minimal, makes a loop's steps reviewable in one prompt, and lets the loops evolve without a policy change. The separation itself is already ruled by [`policy_declarative_framing.md`](policy_declarative_framing.md): policy states rules declaratively and execution guidance does not belong in policy. This ADR records the loop-specific consequence of that rule and names the loop set.

**Rejected alternatives:**

- *Keep the loops as procedure inside policy* -- rejected: the loops would stay interleaved with the rules, blocking the M3.2.1 migration's goal of a minimal shared governance surface.
- *Make the loops conceptual documents in `docs/concepts/`* -- rejected: a loop is executable, not merely descriptive; its steps must run as a prompt. The conceptual overview offloads to `docs/concepts/autonomous_agent_loop.md` instead.

**Edge cases / drivers:**

- The responsibilities separation does not move any invariant into a prompt: policy stays the owner of state rules, and a prompt is checked against its policy.
- A policy change that states a new invariant is not a workflow change; the loop prompts keep their steps and the new invariant becomes the check.
- The `-run` family of prompts (`churn-analysis-run`, `read-through-run`, `review-loop-run`, `review-pass-run`) is not in the loop taxonomy. It is one-shot operation work scoped to M3.2.2.

## The loop taxonomy

The harness targets four loop kinds, with two declared expansions of `/iter`.

| Loop | Kind | Artifact |
|---|---|---|
| `/iter` | base interactive minor loop | `workflow/coding-agent/prompts/iter.md`, renamed from `src/reasoning/agent/prompts/new-iteration.md` |
| `/auto` | declared expansion of `/iter` (autonomous run) | `workflow/coding-agent/prompts/auto.md` |
| `/parallel-auto` | declared expansion of `/iter` (fan-out autonomous run) | `workflow/coding-agent/prompts/parallel-auto.md` |
| `/milestone-start` | loop kind, major-loop open | `workflow/coding-agent/prompts/milestone-start.md` |
| `/milestone-close` | loop kind, major and sub-milestone close | `workflow/coding-agent/prompts/milestone-close.md` |
| `/plan` | loop kind, major-loop planning | `workflow/coding-agent/prompts/plan.md` |

## State diagram

The major/minor loop workflow, drawn as the invariant the loop prompts and policy must together satisfy.

```text
major loop:  milestone-brainstorm ──▶ scoping ──▶ story / investigation
                 │                                    │
                 │                                    ▼
                 │                          roadmap entry created
                 │                                    │
                 ▼                                    ▼
        minor-loop handoff ◀───────────  plan / iter dispatch
                 │
                 ▼
           pre-close verification
                 │
                 ▼
           formal close (milestone-close)
```

The minor loop iterates inside the handoff: `/iter` opens an iteration, runs its steps, and routes back to the handoff for the next iteration until the milestone's roadmap section is all checked.

## Concept offload map

The explanatory loop content moves to `docs/concepts/autonomous_agent_loop.md`: what each loop is, how it dispatches to prompts and skills, and its responsibilities. The concept doc takes over the non-policy content of the policy docs. The workflow-bundled policy files carry the running prompt's scoped invariants.

## References

- Design record: [`20260928-design-settled-loop_workflows_migration.md`](../../devlog/discussions/20260928-design-settled-loop_workflows_migration.md)
- Planning handover: `20260928-04`
- Separation rule: [`policy_declarative_framing.md`](policy_declarative_framing.md)
- Framework loop workflow: `docs/concepts/autonomous_agent_loop.md`
