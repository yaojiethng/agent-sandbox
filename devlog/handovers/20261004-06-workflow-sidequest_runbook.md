---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Workflow
status: Closed
---

# Handover - Workflow: the intermission workflow becomes `/sidequest`

## Objective

Formalize the intermission workflow as `/sidequest`: an operator-invoked runbook for work raised while an iteration is open, which runs the standard lifecycle at its own grain and names the iteration it resumes.

## Scope

Operator-directed, 2026-10-04. Two intermissions ran this way already (`20261004-04`, the archive boundary and the gate blind spot; `20261004-05`, the DeepSeek effort diagnosis and the dead config keys), and this iteration writes the pattern down.

Targets the new runbook, the policy invariants it must not break, the ADR prompt table, and the concept-doc mention.

Out of scope: changing the handover status vocabulary. The paused parent keeps `Active`; the sidequest names it. A new status was considered and declined to keep the handover format gate unchanged.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `workflow/coding-agent/prompts/sidequest.md` exists, follows the prompt-authoring structure, and parses under the frontmatter gate | the frontmatter gate reports 37 prompt, skill and policy files clean | Agent [x] |
| 2 | `iteration_policy.md` carries the `## Sidequests` invariants and lists `/sidequest` among the loop prompts | read the file; the anchor `iteration_policy.md#sidequests` resolves | Agent [x] |
| 3 | The ADR prompt table names `/sidequest` and its artifact | read `docs/adr/coding_agent_loop_workflow.md` | Agent [x] |
| 4 | The concept doc's workflow table names the sidequest transition | read `docs/concepts/autonomous_agent_loop.md` | Agent [x] |
| 5 | The prompt-authoring conventions list `/sidequest` among the loop prompts | read `docs/development/prompt-authoring-conventions.md` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| `workflow/coding-agent/prompts/sidequest.md` | new: the runbook |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | the sidequest invariants and the loop-prompt list |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | the prompt table gains `/sidequest` |
| [`docs/concepts/autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) | the loop description names the sidequest transition |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the loop-prompt list |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The paused parent handover keeps `Active`; the sidequest names it | the handover status vocabulary and the format gate stay unchanged, and the paused iteration is genuinely still open | this record |
| The operator invokes a sidequest; the agent does not open one unprompted | both precedents were operator-directed, and an agent-opened sidequest is scope drift with a new handover attached | this record |
| A sidequest raises its roadmap row at close, not at open (option a) | operator, 2026-10-04: the operator's direction is the task, and the sidequest's own scope gate confirms it exactly as a roadmap task's scope is confirmed; a durable outcome raises a row marked `[x]` in the close commit | this record; `iteration_policy.md` `## Sidequests` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| A sidequest breaks the unit rule as written: `iteration_policy.md` says one iteration is one roadmap task, and a sidequest starts with no roadmap task | contradiction | resolved this iteration: the `## Sidequests` section makes the operator's direction the task, with the roadmap row raised at close for a durable outcome | Triaged to: `iteration_policy.md` `## Sidequests` |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/sidequest.md` | new: the runbook |
| [`docs/operations/iteration_policy.md`](../../docs/operations/iteration_policy.md) | the `## Sidequests` invariants and the `/sidequest` loop-prompt entry |
| [`docs/adr/coding_agent_loop_workflow.md`](../../docs/adr/coding_agent_loop_workflow.md) | the prompt table row for `/sidequest` |
| [`docs/concepts/autonomous_agent_loop.md`](../../docs/concepts/autonomous_agent_loop.md) | the workflow table row for the sidequest transition |
| [`docs/development/prompt-authoring-conventions.md`](../../docs/development/prompt-authoring-conventions.md) | the loop-prompt list names `/sidequest` |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the T1 row for the runbook, and the loop-prompt count in the `AGENTS.md` row |
