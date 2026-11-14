---
date: 2026-11-12
milestone: M3.7.2 - The change model and its refinements
type: Workflow
status: Closed
---

# Handover - The agent operations are primitives, not prompts

## Objective

Land the branch-preparation artifact and retire the two change prompts and the
scheduler prompt: a `prepare` runbook, the convention's primitives in the
agent's terms, every live carrier on the runbook or the host verb, and a gate
that keeps the old paths out.

## Scope

Continues [`20261112-02`](20261112-02-design-two_lane_change_model.md); the
parent row is M3.7.2's *The branch-preparation surface is one host flow*. This
iteration works *The agent operations are primitives, not prompts*, and
absorbs *The records name the host flow* because the deletion's carrier sweep
is that row's contract. Out of scope: the convention's history-as-commons
rewrite (B1), the host hint's code (B2), the recovery consolidation (B5), the
model's placement beside the tests, and the unified fork-to-deletion lifecycle.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A `prepare` runbook exists at `git-discipline/references/prepare.md` with the scenario, inputs, method, handoff and close; both change prompts and the scheduler prompt are absent. | `tests/test_agent_primitives.sh`; the paired positive and negative path checks | Agent [x] |
| Every live carrier names the `prepare` runbook or the host verb, and no live file links a retired prompt. | `tests/test_agent_primitives.sh`'s grep, excluding `devlog/` and the closed rows | Agent [x] |
| The convention names `prepare` and `history-cleanup` as the branch-preparation primitives and the host verbs as the surface, without the model's lane vocabulary, and its runbook table has no scheduler row. | `.agents/skills/git-discipline/SKILL.md`'s runbook table and primitives paragraph | Agent [x] |
| `branching.md` keeps the readiness and stack rules, and the runbook is the procedure. | `.agents/skills/git-discipline/references/branching.md` | Agent [x] |
| The change-flow table names the `prepare` runbook and `make confirm`, and no live file links the scheduler prompt. | `docs/reference/workflow_statechart.md`; `tests/test_agent_primitives.sh` | Agent [x] |
| The change model's `T01` and primitives table name the prepare runbook, not the retired prompt. | `docs/reference/change_model.md`; `scripts/check_change_model.sh` | Agent [x] |
| The gate fails when a retired prompt path returns or the runbook is missing. | `tests/test_agent_primitives.sh` mutates the fixture and asserts the failure | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The prepare artifact is a runbook under `git-discipline`, not a skill. | The operation is the convention's own, beside `branching.md` and `correction.md`; the old artifact was a prompt, and a reference is the smaller form. | This record; the roadmap B3 |
| The scheduler prompt is retired; the queue is the host's order. | `make confirm` already carries the queue-head guard; the agent prepares and reports branch state, and the agent does not own the operator's scheduling judgement. | This record; the roadmap B3 |
| `branching.md` keeps the readiness and stack rules; the runbook is the procedure. | The reference holds the rule; the runbook holds the ordered steps; neither restates the other. | This record; `branching.md` |
| The convention states the primitives in the agent's terms: prepare the branch, then the operator runs `make confirm`. | The convention is read by the agent in the container; the lane vocabulary belongs to the model, not the instruction. | This record; the summary's review point 1 |
| The gate carries a paired negative check on the retired prompt paths. | A deletion needs a check that the old path stays gone, or the habit returns it. | This record; `tests/test_agent_primitives.sh` |
| *The records name the host flow* (B6) folds into this iteration. | The carrier sweep is the deletion's propagation, and B3's own done condition required it; the scope gate confirmed the fold. | The roadmap; this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The roadmap's B3 and B6 are one task by the maintenance check's 3.7: both end at the same carrier sweep. | record | the scope either folds B6 or splits the sweep by kind | the scope gate: folded; the roadmap |
| The operator rejected the skill form and the `prepare-branch` name; the artifact is a reference runbook. | design | the skill root is gone; the runbook sits under `git-discipline` | the Decisions table; this record |
| The operator retired the scheduler prompt: it was the operator's scheduling written as an agent prompt. | design | `merge-queue` is deleted; the host's queue owns the order | the Decisions table; the roadmap |
| The prior model rows (A and A1) were still uncompacted in the roadmap; the release gate's maintenance check caught it. | record | the two closed rows are compacted to one line and the handover link in this write-back; the task-list owner is `/wrapup`, which missed it at the prior close | this write-back; the next `/wrapup` |

## Completed

| File | One-line change summary |
|---|---|
| the roadmap maintenance check | clean; B3 and B6 folded at the scope gate |
| `.agents/skills/git-discipline/SKILL.md` | the `prepare` row and the primitives paragraph; the scheduler row removed |
| `.agents/skills/git-discipline/references/prepare.md` | the prepare runbook (new) |
| `.agents/skills/git-discipline/references/branching.md` | the runbook link and the stack rule |
| `.agents/skills/git-discipline/references/recovery.md` | the prepare runbook redirect |
| `workflow/coding-agent/prompts/prepare-rebase.md` | deleted |
| `workflow/coding-agent/prompts/accept-fast-forward.md` | deleted |
| `workflow/coding-agent/prompts/merge-queue.md` | deleted |
| `workflow/coding-agent/prompts/commit.md` | the prepare runbook |
| `workflow/coding-agent/prompts/record-correction.md` | the prepare runbook |
| `workflow/coding-agent/skills/recovery/SKILL.md` | the prepare runbook |
| `docs/reference/change_model.md` | `T01`, the primitives table and the early change |
| `docs/reference/workflow_statechart.md` | the change-flow table names the runbook and the host verb; the scheduler row removed |
| `docs/reference/autonomous_agent_loop.md` | the prepare runbook |
| `docs/adr/coding_agent_loop_workflow.md` | the prepare runbook |
| `scripts/check_agent_primitives.sh` | the gate (new) |
| `scripts/lint.sh` | the gate in the umbrella |
| `tests/test_agent_primitives.sh` | the gate test (new) |
| `devlog/roadmap.md` | B3 and B6 closed |
| `devlog/handovers/M3.7.2/20261112-03-workflow-agent_primitives.md` | this record |
