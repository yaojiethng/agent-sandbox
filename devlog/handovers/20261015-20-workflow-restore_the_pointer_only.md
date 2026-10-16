---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Restore the pointer only

## Objective

Fix the two task-tracker prompts so a return restores the traversal pointer and stops, and so the tracker names one resume node instead of three. The reorientation had run away into fresh work because `pop-task` said "resume" without saying "do not start the work", and the tracker's resume marker, stack path and frame return node could disagree.

## Scope

The two prompts, in the repository and installed into the agent home.

Out of scope: the tracker's own content, and the `read-back` prompt.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `pop-task` restores the pointer and stops | the prompt states "Restore the traversal pointer only. Do not start the work." and closes with "Then stop." | Accepted |
| `pop-task` bounds its reads | it names `<scratch>/ACTIVE_TASK_TRACKER.md` and says to read nothing else | Accepted |
| `pop-task` resolves the node ambiguity | the resume marker owns the node, and a disagreement is reported in line 2 | Accepted |
| `push-task` names the resume node once | the marker line owns it and the file names it nowhere else | Accepted |
| `push-task` marks the stack top | the stack names `top: <frame>` | Accepted |
| Repo and installed copies match | `diff` on both files, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Restore the pointer, not restart the work | the operator's stated intention for `/pop-task` | this record; the prompt |
| One authoritative resume node | three markers that can disagree forced reconciliation the operator did not want to watch | the prompt |
| Bound the reads to the tracker | "do not re-derive the tree" was ambiguous between the work tree and the repository tree, and the repository read is what made the turn expensive | the prompt |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The prompt said "resume" without a terminal stop, and a standing autonomy grant read that as an instruction to execute, so an orientation call began implementation. An orientation prompt needs an explicit stop, or the grant supplies the missing "go". | defect, fixed | the prompt; this record |
| The tracker's resume marker, its stack path and the popped frame's return node each named a current node, and they disagreed (`B6`, `D6`, `D5`). The marker now owns the node. | defect, fixed in the prompt; the live tracker is not rewritten | `push-task` |

## Completed

| File | Change |
|---|---|
| [`pop-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | restore the pointer only, bound the reads, resolve the node ambiguity, stop |
| [`push-task.md`](../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | one resume marker, the stack top marked |
| `$AGENT_HOME/agent/prompts/` | both prompts installed identical to the repository |
