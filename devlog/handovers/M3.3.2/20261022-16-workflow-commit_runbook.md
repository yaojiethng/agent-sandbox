---
date: 2026-10-22
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - Give the commit its own runbook

## Objective

Make the delivery commit an operation with its own runbook, so the five prompts that perform a commit name one document instead of reaching a commit step inside the close.

## Scope

The roadmap row **Give the commit its own runbook** under M3.3.2: `wrapup` Part A and its B9-B11 commit steps move to a new `commit.md`, `wrapup` keeps the close, and each prompt that lands a commit names the new runbook. The loop inventory, the protocol's `scope` declaration, the reference and ADR descriptions of the loop, and the two instruction-writing surfaces that cite the handoff all follow the split.

The operator directed this iteration from the check-in inventory as **autopilot**, and that direction is this iteration's release for both gates; the scope proposal, acceptance criteria, pre-close summary and release gate are presented in the iteration report rather than awaited.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The new runbook carries both operations: the in-session checkpoint and the close's commit steps | `grep -c '^### A1\.\|^### A7\.\|^### C1\.\|^### C3\.' workflow/coding-agent/prompts/commit.md` is 4 | Agent [x] |
| The old owner no longer carries the commit | `grep -En 'Part A\|B1[0-2]\.\|git reset --soft' workflow/coding-agent/prompts/wrapup.md` prints nothing | Agent [x] |
| `/wrapup` names the handoff to `/commit` | `grep -c 'Hand the commit to /commit' workflow/coding-agent/prompts/wrapup.md` is 1 | Agent [x] |
| Every prompt that performs a commit names `/commit` | `grep -l '/commit' workflow/coding-agent/prompts/iter.md workflow/coding-agent/prompts/document.md workflow/coding-agent/prompts/plan.md workflow/coding-agent/prompts/sidequest.md workflow/coding-agent/prompts/merge.md \| wc -l` is 5 | Agent [x] |
| The loop inventory and the protocol scope both carry `/commit`, and the gate holds them | `grep -c 'commit.md' AGENTS.md` is 1, `grep -c '"/commit"' docs/reference/iteration_protocol.md` is 1, `bash scripts/check_instruction_surfaces.sh` exits 0 | Agent [x] |
| The loop reference and ADR describe the split | `grep -c '/commit' docs/reference/autonomous_agent_loop.md` and `grep -c '/commit' docs/adr/coding_agent_loop_workflow.md` are each at least 1 | Agent [x] |
| The authoring convention and the handoff principle name the commit runbook | `grep -c '/commit' docs/development/prompt-authoring-conventions.md src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` counts one in each | Agent [x] |
| No live instruction still calls the old commit steps from `/wrapup` | `grep -rn 'wrapup.*Part A\|wrapup.*B9\|wrapup.*B10\|wrapup.*B11\|wrapup.*B12\|/wrapup` Part B' workflow docs/reference docs/adr docs/development src/reasoning/providers/pi/config/agent/skills .agents/skills AGENTS.md` prints nothing | Agent [x] |
| Every decision this iteration recorded is realized in the files | the Decisions table's documents and the tree agree | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `/commit` owns the checkpoint and the commit, `/wrapup` owns the close | The commit is one operation with one set of rules across five callers; the close edits records rather than history, so a caller that only commits should not open a close runbook | this record, and `docs/adr/coding_agent_loop_workflow.md` |
| The handover status flip moves to `/commit` | `Status: Closed` is a preparation step of the commit, and the commit is the moment the record and the history agree | `docs/adr/coding_agent_project_bindings.md` |
| `/milestone-close` keeps its own close commit | The milestone-record close lands bookkeeping at milestone grain, not a unit delivery, and the row names five prompts, not six | this record |

## Decisions pending

None.

## Findings

None.

## Completed

| File | Change |
|---|---|
| `workflow/coding-agent/prompts/commit.md` | new runbook: the checkpoint A1-A7 and the commit C1-C3 |
| `workflow/coding-agent/prompts/wrapup.md` | the close B1-B9, the handoff to `/commit`, and no commit step |
| `workflow/coding-agent/prompts/iter.md` | Steps 8-9 and the acceptance gate name the split |
| `workflow/coding-agent/prompts/document.md` | the close and commit handoffs name the split |
| `workflow/coding-agent/prompts/plan.md` | the close and commit handoffs name the split |
| `workflow/coding-agent/prompts/sidequest.md` | the close handoff names the split |
| `workflow/coding-agent/prompts/merge.md` | the fold names `/commit` |
| `workflow/coding-agent/prompts/scope.md` | the next-prompt line names `/wrapup` without a part letter |
| `AGENTS.md` | the loop inventory carries `/commit` |
| `docs/reference/iteration_protocol.md` | the `scope` declaration carries `/commit`, and the close handoff names it |
| `docs/reference/autonomous_agent_loop.md` | the workflow table, diagram and prose carry the split |
| `docs/adr/coding_agent_loop_workflow.md` | the shared-runbook paragraph and transition note carry the split |
| `docs/adr/coding_agent_project_bindings.md` | the status writer is `commit` |
| `docs/development/prompt-authoring-conventions.md` | the handoff shape names the commit runbook |
| `src/reasoning/providers/pi/config/agent/skills/communication-principle-hand-off-by-naming-the-boundary/SKILL.md` | the worked example names the commit runbook |
| `devlog/roadmap.md` | the row closes with its landing note |
