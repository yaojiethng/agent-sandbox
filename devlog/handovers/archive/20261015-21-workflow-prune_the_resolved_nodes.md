---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Prune the resolved nodes from the tracker

## Objective

Make the tracker a call stack. A returned node is popped, a spent frame is dropped, and only resumable nodes are kept, so the file stops growing with the session.

## Scope

`push-task`, the only writer, in the repository and installed.

Out of scope: `pop-task`, which stays read-only.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A returned node is pruned | the prompt drops every `[x]` node and states why it is safe: it is neither on the path nor in the frontier | Accepted |
| A spent frame is pruned | the prompt drops every frame whose divergence is resolved | Accepted |
| A suspended or delegated node is kept | the prompt keeps `[~]` and `[-]` | Accepted |
| The legend states the stack's meaning | `[ ]` open, `[~]` continues later, `[-]` continues elsewhere, and no resolved state | Accepted |
| Repo and installed copies match | `diff`, identical | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Prune at the writer | `/push-task` is the only writer and the only place a frame is pushed; keeping `/pop-task` read-only keeps pointer restoration risk-free | this record; the prompt |
| Drop `[x]` rather than collapse it | a collapsed line is still a ledger, and the roadmap is the ledger; a stack keeps only what can be resumed | this record |
| Keep `[~]` and `[-]` | neither returned, and a fork can resume either, which needs the frame to exist | the prompt |
| Rename the legend to `continues later` and `continues elsewhere` | the states mean what a stack needs, and neither is "resolved" | the prompt |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| A `/pop-task` reads only, so a popped frame stays in the fork stack. The writer drops it on the next push, by the resolved-divergence rule. | defect, handled in the writer | the prompt |
| The proof that pruning `[x]` is safe: such a node is never on the current path and never in the frontier, because both hold unresolved nodes by construction. | reasoning, recorded | this record |

## Completed

| File | Change |
|---|---|
| [`push-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the prune step, the resolved-frame drop, the stack legend |
| `$AGENT_HOME/agent/prompts/push-task.md` | installed identical to the repository |
