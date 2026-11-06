---
date: 2026-11-05
milestone: M3.5.4 - The git and change model
type: Workflow
status: Closed
---

# Handover - The three change workflows are named and handed off

## Objective

Name the three workflows `prepare-rebase`, `/merge-queue` and `accept-fast-forward`, and make each a self-contained unit that hands off to the next.

## Scope

The two prompts renamed as `prepare-rebase.md` and `accept-fast-forward.md`, the new `merge-queue.md`, the `git-discipline` runbook table and recovery reference, the statechart's command table and recovery edges, the current mentions in the ADR, the loop reference, `/commit` and `/record-correction`, the M3.5.4 rows, and the change-flow record.

Out of scope, with reasons: moving the two states out of the recovery region, which is the "prepare/accept path leaves recovery" row; the branch-work machine; the queue's storage, which is derived.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The three workflows exist | `prepare-rebase.md`, `accept-fast-forward.md`, `merge-queue.md` | Agent [x] |
| Each names its boundary and hands off | a `## Handoff` section in each | Agent [x] |
| The old prompt names are gone from the live tree | no `prompts/merge.md` or `prompts/rebase.md` | Agent [x] |
| The command table matches the prompt root | `docs/reference/workflow_statechart.md` `## Commands` | Agent [x] |
| The recovery reference points at the new names | `references/recovery.md` | Agent [x] |
| The gates are clean | `bash scripts/lint.sh` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| State-first compounds: `prepare-rebase`, `accept-fast-forward` | the operator asks for the state; the operation is how it is reached | this record |
| `/merge-queue` | the established noun; it names the queue, not the `git merge` command | this record |
| Each prompt hands off | a workflow is a self-contained unit, and the next step is named where this one stops | this record |
| The queue is derived, not stored | it is a function over the ready set; a head advance recomputes it | the change-flow record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The recovery reference's replay/port split no longer matches the runbooks | defect | a lost branch is now prepared by a rebase and accepted by a fast-forward; the split implied two methods | fixed in `references/recovery.md` |
| The old `/merge` name collided with `git merge` | defect | "merge a PR" and `git merge` meant different things | fixed: `accept-fast-forward` names the operation |
| The queue had no workflow | defect | the order was an operator decision with no procedure | fixed: `/merge-queue` reads mergeability and emits the order |

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/prepare-rebase.md` | the prepare workflow, renamed, with the handoff |
| `workflow/coding-agent/prompts/accept-fast-forward.md` | the accept workflow, renamed, with the handoff |
| `workflow/coding-agent/prompts/merge-queue.md` | the queue workflow |
| `workflow/coding-agent/prompts/merge.md`, `rebase.md` | removed |
| `.agents/skills/git-discipline/SKILL.md` | the runbook table names the three workflows |
| `.agents/skills/git-discipline/references/recovery.md` | the links and the replay/port split |
| `docs/reference/workflow_statechart.md` | the command table and the recovery edges |
| `docs/adr/coding_agent_loop_workflow.md`, `docs/reference/autonomous_agent_loop.md` | the `/merge` mentions |
| `workflow/coding-agent/prompts/commit.md`, `record-correction.md` | the `/merge` and `/rebase` mentions |
| `devlog/roadmap.md` | the M3.5.4 rows and the reviewer row |
| `devlog/discussions/20261105-design-open-change_flow.md` | the workflow names and the carrier names |
| `devlog/handovers/M3.5.4/20261105-23-workflow-merge_queue.md` | this record |
