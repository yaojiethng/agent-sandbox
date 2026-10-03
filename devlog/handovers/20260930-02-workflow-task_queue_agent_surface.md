# Agent Handover

**Date:** 2026-09-30
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Workflow
**Status:** Closed

## Objective

Fix the taskq/task-queue documentation gap: surface the task-queue prompt into the agent's context so a parallel-dispatch agent reaches for the fork/join/merge primitive over the raw `git worktree add` + `pi -p` loop. This iteration changes the documentation/pointer surfaces; it does not change queue mechanics.

## Scope

- `src/reasoning/providers/pi/config/agent/AGENTS.md` - add the `/task-queue` line to the "Tools you have access to" block, directly below `/package-branch`.
- `workflow/coding-agent/prompts/parallel-auto.md` - add a "Not this template" routing row: operator decides at worker-detected boundaries - use `/task-queue`.
- `devlog/roadmap.md` - mark the documentation-gap row `[x]`; add a roadmap task: the task-queue per-prompt quality pass includes reading the taskq `registerTool` descriptions and checking them against the communication guidelines.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Mention just the `/task-queue` prompt in AGENTS.md "Tools you have access to", not the taskq tools | the tools load automatically and self-document (registerTool descriptions + distinct error codes); AGENTS.md names the orchestration reader, not the tool registry; the prompt already names all eight operations | this handover + operator steer 2026-09-30 |
| Land the `/task-queue` routing line in `parallel-auto.md`'s "Not this template" block | the operator confirmed it; a parallel prompt the agent reads first should forward the operator-boundary case to the primitive | this handover + operator steer 2026-09-30 |
| Add a roadmap task: the task-queue quality pass reads the `registerTool` descriptions against the communication guidelines | operator raise 2026-09-30; the descriptions are agent-facing prose and should meet the writing bar | roadmap row |

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The provider `AGENTS.md` "Tools you have access to" block names `/task-queue` directly below `/package-branch` | `grep -n` the repo source | Accepted at scope gate (to confirm) |
| 2 | `parallel-auto.md`'s "Not this template" block routes the operator-boundary case to `/task-queue` | `grep -n` on `parallel-auto.md` | Accepted at scope gate (to confirm) |
| 3 | The documentation-gap roadmap row is marked `[x]` and a task-queue quality-pass task noting the `registerTool` description check is added | `grep -n` the roadmap rows | Accepted at scope gate (to confirm) |
| 4 | No node/queue code changed; only doc surfaces | `git status` shows the two doc files + roadmap + handover | Accepted at scope gate (to confirm) |
| 5 | Lint clean | `bash scripts/lint.sh` | precondition, at pre-close |

## Completed

| File | Change | Status |
|---|---|---|
| `src/reasoning/providers/pi/config/agent/AGENTS.md` | `/task-queue` line added to "Tools you have access to" below `/package-branch` | done |
| `workflow/coding-agent/prompts/parallel-auto.md` | "Not this template" block routes the operator-boundary case to `task-queue.md` | done |
| `devlog/roadmap.md` | documentation-gap row marked `[x]` (Landed note + landing decision); task-queue quality-pass row gained the `registerTool`-description check | done |
| `devlog/handovers/20260930-02...md` | handover: scope, decisions, AC, completed | done |

## Deferred items

_(filled at close)_

## What's Next

The `/task-queue` per-prompt quality pass is the next task-queue iteration: raise the task-queue prompt to the per-prompt quality bar, and -- in scope per the operator raise -- read the taskq `registerTool` descriptions and check them against the communication guidelines (the row's in-scope note records it). Deferred items take priority; this is the named next task-queue row.
