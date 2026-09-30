---
description: Milestone planning workflow. Runs a plan session for planning and design work in place of `/iter` - opens the session, records the goal and problem, aligns scope, interviews, and routes the outcome to its write-back target. Deliverable is documents. Use when a plan or design needs shaping and iteration is not required.
argument-hint: "[goal or scope to plan - required]"
---

> $@

# Plan - Milestone Planning

Run a plan session for planning and design work. Run `/iter` for feature work.

## Orient

Read the most recent handover and the roadmap:

```text
ls devlog/handovers/ | sort | tail -1 | xargs -I{} read devlog/handovers/{}
read devlog/roadmap.md
```

Read the prior handover's What's Next section and any open stories in `devlog/discussions/` that concern the session goal.

## Open the session

Capture the goal and the problem for this session. Read the goal from the invocation argument or from the operator's direction. When no goal is stated, state it and confirm it with the operator. Capture the problem statement from the invocation argument or from the operator as well. Keep every planned item inside the goal.

Open a plan-session handover per [`handover_policy.md`](../../../docs/operations/handover_policy.md), mirroring `/iter` Step 1. Record the goal and the problem in the handover so they are a durable record. Assign the handover to the session's milestone. When no major milestone is open, stop and ask the operator.

**Skip condition.** If the work is already well-scoped and needs no planning, record that decision in the handover, say so, and end the session.

## Gather context

Read the documents the plan needs before interviewing:

- Documents in `docs/` and `devlog/` related to the session goal.
- `devlog/discussions/` on the same subject.
- Past handovers touching the same problem.
- Associated `roadmap.md` tasks.

## Align scope

Present the gathered context and the session goal. Set the session's scope and deliverables with the operator and confirm both. Stop and wait for the operator to confirm the scope and the deliverables.

## Interview

Pass the session context -- the recorded goal and problem, the gathered context, and the confirmed scope -- to the [`grill-me`](../../../src/reasoning/agent/skills/grill-me/SKILL.md) skill for the interview. The skill resolves each branch of the decision tree. Treat its resolved branches as the interview result.

## Decide the outcome

Route the interview result to a write-back target. Choose one: a written report in `devlog/discussions/`, a design document, a `roadmap.md` entry, the handover, or the session's persisted record. Match the target to the decision's scope. Confirm the choice with the operator before writing.

## Write back

Write the plan to the confirmed target: the roadmap entry, the scoped sub-milestone, decisions, and ADRs. Apply the binding rules in [`milestone_policy.md`](../../../docs/operations/milestone_policy.md), [`iteration_policy.md`](../../../docs/operations/iteration_policy.md) [Iteration Invariants](docs/operations/iteration_policy.md#iteration-invariants), [`roadmap_policy.md`](../../../docs/operations/roadmap_policy.md), and [`adr_policy.md`](../../../docs/operations/adr_policy.md). When one decision crosses several `roadmap.md` rows, run a propagation checklist per [`propagation-check.md`](../../../src/reasoning/agent/prompts/propagation-check.md).

A plan is complete when the operator confirms the written plan. Stop and wait for that confirmation.

## Close

After the operator confirms the written plan, run the consolidated close from [`/wrapup`](wrapup.md) Part B. `/wrapup` owns the close steps -- roadmap write-back and compaction, closing ADRs and discussion docs whose work landed, closing the handover, and seeding what's next -- applied to a planning session, whose write-back produces roadmap rows, decisions, and ADRs rather than a delivery commit. Land the plan single commit per `git_policy.md`.
