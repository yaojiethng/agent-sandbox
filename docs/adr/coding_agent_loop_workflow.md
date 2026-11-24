# Coding Agent Loop Workflow

## 2026-10-20 -- Record checks run before the release gate

**Decision:** At the acceptance gate, the agent presents the findings queue with every destination. It also presents the record-check reports for the records the iteration changed, and the commit message. `roadmap-maintenance` and the `work-log` handover runbook run before that gate, not inside the close. The close lands what the gate released and raises what it finds as `late`, naming the gate that should have asked.

**Rationale:** The finished record exists at the release. A check placed after it can only amend a landed commit. The cost is in the record: 108 corrections across 824 handovers and discussion records, median one day after close.

**Rejected alternatives:**

- *Keep the checks in the close.* One late discovery deserves an amendment. A class of decisions that can be read before the release does not.
- *Add a third gate.* The record is evidence about the work, so it belongs in the release decision.
- *Forbid late findings.* A late finding shows a check sits in the wrong place. The close records it, and a recurrence becomes a roadmap row against the gate that missed it.

**Edge cases / drivers:**

- `/milestone-close` keeps its `roadmap-maintenance` run, because its input is the whole milestone record rather than one iteration.
- The iteration edits the roadmap rows and completes the handover before the gate. The close sets `Status: Closed`, runs the handover format gate over the record, and commits what the gate read.

**Current:** 2026-10-20

## 2026-10-01 -- The dispatch work-loop expansions move to M3.2.3; `/auto` and `/goal` become M4

**Decision:** The autonomous dispatch shapes, previously the `/iter` work-loop expansions `(/auto`, `/parallel-auto)`, change ownership and semantics. M3.2.3 assumes ownership of the `/iter` work-loop expansions from hereon and renders them as a curated dispatch-command surface with a temporary `-work` suffix: `/sequential-work` (was `/auto`) and `/parallel-work` (was `/parallel-auto`). The `-work` suffix is placeholder-pending-final-naming and is removed when the feature lands. The `/auto` keyword is reserved for the new M4 smart dispatcher (Option A): given a roadmap task list, it resolves execution order, picks a dispatch shape, and orchestrates. `/goal` (Option B, loose-goal decomposition) is also M4's, reworked from the removed external extension. The loop taxonomy proper (the four loops) stays M3.2.1's. Semantics record: [`20261001-design-settled-auto_smart_dispatch.md`](../../devlog/discussions/archive/20261001-design-settled-auto_smart_dispatch.md).

**Rationale:** The old `/auto` (sequential autopilot) and the new `/auto` (smart dispatcher) are different things, so they cannot share a keyword. Freeing the keyword for the M4 smart dispatcher requires renaming the sequential shape at once, and M3.2.3 is the home where the dispatch shapes are refined and curated. The smart dispatcher is not an `/iter` work-loop expansion; it is a distinct M4 capability. The temporary `-work` suffix marks the family as pending final naming and gives the rename a defined completion condition at M3.2.3's close.

**Rejected alternatives:**

- Keep `/auto` as the sequential autopilot and add a separate smart dispatcher: rejected because the `/auto` keyword is the natural name for the smart dispatcher, and two autopilots under two names fragments the surface an operator must learn.
- Name the sequential shape `sequential-run` under the M3.2.2 `-run` family: rejected because `-run` names one-shot operation work (review and analysis), not dispatch shapes, and the `-work` family is the dispatch analogue.

## 2026-09-28 -- Loops are workflows; policy carries the rules

**Decision:** The coding agent runs the autonomous agent loop as invocable workflow prompts under `workflow/coding-agent/prompts/`. Workflow prompts own the steps and the state transitions of the loop. Policy files under `docs/policies/` own the invariants those transitions must not break -- since 2026-10-22 that owner is the iteration protocol, `docs/reference/iteration_protocol.md`. A gate is an instruction to stop and wait for operator feedback, and a check that after a prompt finishes, the output conforms to the expected state. The workflow prompts are `/iter`, `/milestone-start`, `/milestone-close` and `/plan`; `/auto` and `/parallel-auto` are declared expansions of `/iter`.

[CORRECTION -- 2026-11-12: the diagram and the transition rules are both in [`workflow_statechart.md`](../reference/workflow_statechart.md); this ADR records the decisions behind them. The decision above otherwise stands.]

**Rationale:** The loop workflows previously lived as step-by-step procedure interleaved with policy rules in `iteration_protocol.md` and `milestone_policy.md`, which made the governance surface large and forced every change into a policy edit. Separating the procedure into prompts with the policy keeping the rules keeps the shared governance surface minimal, makes a workflow's steps reviewable in one prompt, and lets the workflows evolve without a policy change. The separation itself is already ruled by `docs/adr/archive/20260721-adr-settled-policy_declarative_framing.md`, retired with the policy form: rules are stated declaratively and execution guidance does not belong in the rule's own document. This ADR records the loop-specific consequence of that rule and names the loop set.

**Rejected alternatives:**

- *Keep the loop workflows as procedure inside policy* -- rejected: the workflows would stay interleaved with the rules, blocking the M3.2.1 migration's goal of a minimal shared governance surface.
- *Make the loop workflows conceptual documents in `docs/reference/`* -- rejected: a workflow is executable, not merely descriptive; its steps must run as a prompt. The conceptual overview offloads to `docs/reference/autonomous_agent_loop.md` instead.

**Edge cases / drivers:**

- The responsibilities separation does not move any invariant into a prompt: policy stays the owner of state rules, and a prompt is checked against its policy.
- A policy change that states a new invariant is not a workflow change; the loop prompts keep their steps and the new invariant becomes the check.
- A rule has one owner, which can be the policy or the prompt. The two do not conflict: the policy states the rule as an invariant; the prompt states it as a series of procedural checks that operationalise it. A rule whose variant differs by workflow (for example how a workflow treats open questions) is owned by the workflow that applies it, not by a single policy. A rule that is general to all workflows or to the collaboration protocol is owned by its policy or by the project `AGENTS.md`, and each loop prompt that depends on it echoes it as a runbook step.
- The runbook is not a second owner. A prompt's procedural restatement of a rule is the runbook around the rule, not an independent authority claim. Echo a rule by linking its owner and stating the applying check.
- The `-run` family has retired. It was never in the loop taxonomy: one-shot operation work, drafted in `.agents/drafts/` pending operator review (2026-10-02). The churn survey landed as a reference under the `code-review` shell on 2026-10-28, `review-loop-run` and `review-pass-run` were retired into that shell's loop reference, and `read-through-run` was replaced by the [`close-read`](../../workflow/coding-agent/skills/close-read/SKILL.md) skill.

[CORRECTION -- 2026-11-23: the shell's loop reference was removed. The review runs one pass, and repetition is the invoking task's decision; the two retired drafts stay retired.]

- The `-work` family of dispatch prompts (`sequential-work`, `parallel-work`) is the renamed `/iter` work-loop expansion surface; both live in `.agents/drafts/` in draft status pending operator review (2026-10-02). It is not in the loop taxonomy proper; it is owned by M3.2.3 and refined there, with the temporary `-work` suffix removed when final naming lands. The new `/auto` smart dispatcher and `/goal` are M4's, not `/iter` work-loop expansions.
- `backlog-triage` is a pre-dispatch classifier, not a dispatch shape. It sorts open roadmap rows into those an autonomous run can dispatch and those carrying a question, and runs no iteration. It is owned by M3.2.3 alongside the dispatch family it feeds.

## References

- Design record: [`20260928-design-settled-loop_workflows_migration.md`](../../devlog/discussions/archive/20260928-design-settled-loop_workflows_migration.md)
- Planning handover: `20260928-04`
- Separation rule: [`instruction_modality.md`](instruction_modality.md), and the retired framing at `docs/adr/archive/20260721-adr-settled-policy_declarative_framing.md`
- Framework loop workflow: `docs/reference/autonomous_agent_loop.md`
