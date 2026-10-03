# Coding Agent Loop Workflow

**Current:** 2026-10-03

## 2026-10-01 -- The dispatch work-loop expansions move to M3.2.3; `/auto` and `/goal` become M4

**Decision:** The autonomous dispatch shapes, previously the `/iter` work-loop expansions `(/auto`, `/parallel-auto)`, change ownership and semantics. M3.2.3 assumes ownership of the `/iter` work-loop expansions from hereon and renders them as a curated dispatch-command surface with a temporary `-work` suffix: `/sequential-work` (was `/auto`) and `/parallel-work` (was `/parallel-auto`). The `-work` suffix is placeholder-pending-final-naming and is removed when the feature lands. The `/auto` keyword is reserved for the new M4 smart dispatcher (Option A): given a roadmap task list, it resolves execution order, picks a dispatch shape, and orchestrates. `/goal` (Option B, loose-goal decomposition) is also M4's, reworked from the removed external extension. The loop taxonomy proper (the four loops) stays M3.2.1's. Semantics record: [`20261001-design-settled-auto_smart_dispatch.md`](../../devlog/discussions/archive/20261001-design-settled-auto_smart_dispatch.md).

**Rationale:** The old `/auto` (sequential autopilot) and the new `/auto` (smart dispatcher) are different things, so they cannot share a keyword. Freeing the keyword for the M4 smart dispatcher requires renaming the sequential shape at once, and M3.2.3 is the home where the dispatch shapes are refined and curated. The smart dispatcher is not an `/iter` work-loop expansion; it is a distinct M4 capability. The temporary `-work` suffix marks the family as pending final naming and gives the rename a defined completion condition at M3.2.3's close.

**Rejected alternatives:**

- Keep `/auto` as the sequential autopilot and add a separate smart dispatcher: rejected because the `/auto` keyword is the natural name for the smart dispatcher, and two autopilots under two names fragments the surface an operator must learn.
- Name the sequential shape `sequential-run` under the M3.2.2 `-run` family: rejected because `-run` names one-shot operation work (review and analysis), not dispatch shapes, and the `-work` family is the dispatch analogue.

## 2026-09-28 -- Loops are workflows; policy carries the rules

**Decision:** The coding agent runs the autonomous agent loop as invocable workflow prompts under `workflow/coding-agent/prompts/`. Workflow prompts own the steps and the state transitions of the loop. Policy files under `docs/operations/` own the invariants those transitions must not break. A gate is an instruction to stop and wait for operator feedback, and a check that after a prompt finishes, the output conforms to the expected state. The workflow prompts are `/iter`, `/milestone-start`, `/milestone-close` and `/plan`; `/auto` and `/parallel-auto` are declared expansions of `/iter`.

[CORRECTION -- 2026-10-03: the diagram's home is the concept document, not this ADR. The state diagram is drawn in [`autonomous_agent_loop.md`](../concepts/autonomous_agent_loop.md#the-loop), and this section states the transition rules behind it. The decision above otherwise stands.]

**Rationale:** The loop workflows previously lived as step-by-step procedure interleaved with policy rules in `iteration_policy.md` and `milestone_policy.md`, which made the governance surface large and forced every change into a policy edit. Separating the procedure into prompts with the policy keeping the rules keeps the shared governance surface minimal, makes a workflow's steps reviewable in one prompt, and lets the workflows evolve without a policy change. The separation itself is already ruled by [`policy_declarative_framing.md`](policy_declarative_framing.md): policy states rules declaratively and execution guidance does not belong in policy. This ADR records the loop-specific consequence of that rule and names the loop set.

**Rejected alternatives:**

- *Keep the loop workflows as procedure inside policy* -- rejected: the workflows would stay interleaved with the rules, blocking the M3.2.1 migration's goal of a minimal shared governance surface.
- *Make the loop workflows conceptual documents in `docs/concepts/`* -- rejected: a workflow is executable, not merely descriptive; its steps must run as a prompt. The conceptual overview offloads to `docs/concepts/autonomous_agent_loop.md` instead.

**Edge cases / drivers:**

- The responsibilities separation does not move any invariant into a prompt: policy stays the owner of state rules, and a prompt is checked against its policy.
- A policy change that states a new invariant is not a workflow change; the loop prompts keep their steps and the new invariant becomes the check.
- A rule has one owner, which can be the policy or the prompt. The two do not conflict: the policy states the rule as an invariant; the prompt states it as a series of procedural checks that operationalise it. A rule whose variant differs by workflow (for example how a workflow treats open questions) is owned by the workflow that applies it, not by a single policy. A rule that is general to all workflows or to the collaboration protocol is owned by its policy or by the project `AGENTS.md`, and each loop prompt that depends on it echoes it as a runbook step.
- The runbook is not a second owner. A prompt's procedural restatement of a rule is the runbook around the rule, not an independent authority claim. Echo a rule by linking its owner and stating the applying check.
- The `-run` family of prompts (`churn-analysis-run`, `read-through-run`, `review-loop-run`, `review-pass-run`) is not in the loop taxonomy. It is one-shot operation work scoped to M3.2.2; the family lives in `workflow/coding-agent/drafts/` in draft status pending operator review (2026-10-02).
- The `-work` family of dispatch prompts (`sequential-work`, `parallel-work`) is the renamed `/iter` work-loop expansion surface; both live in `workflow/coding-agent/drafts/` in draft status pending operator review (2026-10-02). It is not in the loop taxonomy proper; it is owned by M3.2.3 and refined there, with the temporary `-work` suffix removed when final naming lands. The new `/auto` smart dispatcher and `/goal` are M4's, not `/iter` work-loop expansions.
- `backlog-triage` is a pre-dispatch classifier, not a dispatch shape. It sorts open roadmap rows into those an autonomous run can dispatch and those carrying a question, and runs no iteration. It is owned by M3.2.3 alongside the dispatch family it feeds.

## The loop taxonomy

The harness targets four workflow kinds, with two declared expansions of `/iter`.

| Workflow | Kind | Artifact |
|---|---|---|
| `/iter` | the iteration workflow | `workflow/coding-agent/prompts/iter.md`, renamed from `src/reasoning/agent/prompts/new-iteration.md` |
| `/auto` | **M4 smart dispatcher (reserved stub), not an `/iter` work-loop expansion** | `workflow/coding-agent/drafts/auto.md` (draft: the reserved stub pending operator review) |
| `/goal` | **M4 loose-goal decomposition (Option B), not an `/iter` work-loop expansion** | M4 |
| `/sequential-work` | curated dispatch shape (was `/auto`), `/iter` work-loop expansion owned by M3.2.3 | `workflow/coding-agent/drafts/sequential-work.md` (draft) |
| `/parallel-work` | curated dispatch shape (was `/parallel-auto`), `/iter` work-loop expansion owned by M3.2.3 | `workflow/coding-agent/drafts/parallel-work.md` (draft) |
| `/backlog-triage` | pre-dispatch classifier: sorts open roadmap rows into runnable and parked; labels the workflow-assisted operator decision at the iteration close, owned by M3.2.3 | `workflow/coding-agent/prompts/backlog-triage.md` |
| `/milestone-start` | opens a milestone | `workflow/coding-agent/prompts/milestone-start.md` |
| `/milestone-close` | closes a milestone or sub-milestone | `workflow/coding-agent/prompts/milestone-close.md` |
| `/plan` | milestone planning | `workflow/coding-agent/prompts/plan.md` |

`/wrapup` is a shared close runbook, not a workflow prompt: the active-operator prompts (`/iter`, `/plan`, `/document`) invoke its Part B close rather than opening it, so the close steps live once in `workflow/coding-agent/prompts/wrapup.md` instead of once per prompt. `milestone-start`, `sequential-work` and `parallel-work` do not invoke it -- the milestone-record close is `/milestone-close`, and the work runs substitute an autonomous review for the operator gate.

## Transitions

One workflow is one arrow. A node is a state the loop rests in; a gate is a node where the loop waits for the operator, and the arrow out of a gate is a decision. The state diagram is the model, drawn once in [`autonomous_agent_loop.md`](../concepts/autonomous_agent_loop.md#the-loop); this section states the rules behind it.

Three edge types: **workflow-implemented** (a prompt performs the transition), **operator decision** (the operator releases the gate), and **workflow-assisted operator decision** (a workflow or skill narrows the choice, and the operator picks). `/backlog-triage` and `/milestone-start` are labels of the third type, not types of their own.

Three gate states, each an arrow's source rather than a resting place for closing work: `it:scope-gate`, `it:acceptance-gate`, `ms:close-gate`. Closing is the work that follows the acceptance decision, not a state.

One milestone is modelled, the active one. Its successors are handwaved behind `ms:successor?`, so a per-milestone state set does not appear, and several milestones may be shaped at once without the diagram growing. The autonomous-run prompts -- `/auto`, `/goal`, `/sequential-work`, `/parallel-work` -- are out of the diagram until the milestone that lands them; the drafts tree holds them, and `/backlog-triage` drives no transition of its own.

`/iter` runs one iteration and stops at the acceptance gate; `/wrapup` takes it from there, lands the commit and closes the handover. The next iteration opens only after the operator picks a task, and when the milestone has no open row left the operator calls `/milestone-close` instead.

## Concept offload map

The explanatory loop content moves to `docs/concepts/autonomous_agent_loop.md`: what each loop is, how it dispatches to prompts and skills, and its responsibilities. The concept doc takes over the non-policy content of the policy docs. The workflow-bundled policy files carry the running prompt's scoped invariants.

## References

- Design record: [`20260928-design-settled-loop_workflows_migration.md`](../../devlog/discussions/archive/20260928-design-settled-loop_workflows_migration.md)
- Planning handover: `20260928-04`
- Separation rule: [`policy_declarative_framing.md`](policy_declarative_framing.md)
- Framework loop workflow: `docs/concepts/autonomous_agent_loop.md`
