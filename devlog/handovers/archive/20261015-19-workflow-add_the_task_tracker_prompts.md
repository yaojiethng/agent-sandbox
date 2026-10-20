---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Add the task tracker prompts

## Objective

Land the two operator-invoked pi prompts that record and restore the active task tracker across a pi `/tree` or `/fork` divergence, and commit the prompt for the future design that replaces them.

## Scope

Two new pi-provider prompts, one committed future-task prompt, one provider `AGENTS.md` row that declares the session-local scratch path, and the session-local tracker brought into line. The stopgap draft is consumed and is not committed.

Out of scope: the automatic mechanism, which the design prompt captures as a future task.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The two prompts exist | `ls src/reasoning/providers/pi/config/agent/prompts/{push-task,pop-task}.md` | Agent [x] |
| Their frontmatter parses | `bash scripts/check_frontmatter.sh`, clean across 78 files | Agent [x] |
| The design prompt is committed | the close commit carries it | Agent [ ] |
| The stopgap draft is consumed | `test ! -e .agents/drafts/active-task-tracker-stopgap.md` | Agent [x] |
| The canonical scratch path is declared | `grep -n 'scratchpad' AGENTS.md`, and the manifest session rows carry it | Agent [x] |
| The tracker conforms to the model | read it: the work tree, the stack, the workspace note | Agent [x] |
| Architecture documents in scope describe the system as built | the Scope table names the scratch path the prompts resolve | Agent [x] |
| Gates clean | `bash scripts/lint.sh`, clean across 8 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two prompts are pi-provider prompts | the mechanism pairs with pi's session tree, `/tree` and `/fork`, which no other provider has | M3.6.1; the stopgap draft |
| The tracker's path resolves from the provider `AGENTS.md` | the path has one declared home, per the `/tmp/` precedent, rather than a hardcoded `.scratchpad` | M3.6.1 |
| The model is a work tree plus a DFS stack | the traversal is depth-first, DFS is implemented with a stack, and the tracker is written as the tree | M3.6.1 |

## Decisions pending

The provider `AGENTS.md` row text, and the roadmap home for the future design task.

## Findings

| Finding | Type | Impact |
|---|---|---|
| Consuming the stopgap draft breaks the design prompt's reference to it, so the design prompt must reference the two landed prompts instead. | contradiction, caught while scoping | the design prompt is rewritten in this iteration |
| The `AGENTS.md` Scope tables are gated against the manifest's session rows, and a path inside the project tree named from the provider layer double-covers the project row. So the canonical scratch could not sit in the provider layer; it merged `/tmp` and the scratch into one row in the project layer, and the manifest session row moved with it. | gate, caught at the instruction-surface gate | the row, the manifest and the provider prose all changed in this iteration |
| The stopgap's convention needs a session-local scratch row in the provider `AGENTS.md`, which is a governance file and takes a section-level proposal at the scope gate. | governance | the gate below |

## Completed

| File | Change |
|---|---|
| [`push-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | new: the before-fork prompt |
| [`pop-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | new: the after-return prompt |
| [`active-task-tracker-design-prompt.md`](../../../.agents/drafts/active-task-tracker-design-prompt.md) | the future-task prompt, rewritten to reference the two landed prompts |
| [`AGENTS.md`](../../../AGENTS.md) | the canonical session-local scratch row, `.scratchpad/`, in the project layer |
| [`AGENTS.md`](../../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the `/tmp` Scope row removed, and the two `/tmp` prose references moved to `.scratchpad/`, in the repo source and the installed copy |
| [`container-interface.json`](../../../src/build/container-interface.json) | the `/tmp/` session row replaced by `/home/agentuser/sandbox/.scratchpad/` |
| [`devlog/roadmap.md`](../../roadmap.md) | the prompts row, and the future-task row it seeds |
| `.agents/drafts/active-task-tracker-stopgap.md` | consumed: deleted, not committed |
| `.scratchpad/ACTIVE_TASK_TRACKER.md` | session-local: rebuilt as the work tree plus the DFS stack |
