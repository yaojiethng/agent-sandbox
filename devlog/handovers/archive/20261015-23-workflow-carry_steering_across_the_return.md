---
date: 2026-10-15
milestone: M3.2.3 - Dispatch Workflows as a Command Surface
type: Workflow
status: Closed
---

# Handover - Carry steering across the return

## Objective

Persist cross-task steering so a divergence no longer loses it. The need is immediate and demonstrated: steering given in one branch was lost to a `/tree`, and the same steering arrived again. The mechanism is an OptMem-shaped tool, an append-only log for storage and a bounded view for the reading budget.

## Scope

The tool and its test, the two prompts in the repository and installed, the live log and view, and the deep design prompt persisted beside them.

Out of scope: the measured design, which is the draft, and the write-back of earlier commits.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The tool owns the mechanics | `bash tests/test_steer.sh`, 10 cases: note, restatement, wake, merge, the budget, zoom, forget, mark, diff, clip | Accepted |
| Two grains, one per file | the log records occurrences; the view holds one line per directive; a restatement appends with `--restates` and adds no view line | Accepted |
| The timestamp is UTC to the second | every log entry carries `ts` as `2026-10-16T04:14:30Z` | Accepted |
| The view is bounded and clipped | at most 16 lines by 240 characters, newest first | Accepted |
| The prompts call the tool | `push-task` writes the view from `wake` and reports the merge; `pop-task` reports the view | Accepted |
| The write-back is defined | `push-task` reports the tree diff and the memory diff before writing | Accepted |
| The deep design is drafted | [`.agents/drafts/steering-memory-design-prompt.md`](../../../.agents/drafts/steering-memory-design-prompt.md), naming OptMem's mechanisms and the tool | Accepted |
| Gates clean | `bash scripts/lint.sh` clean across 8 gates | Accepted |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| A tool, not a prompt, owns the mechanics | the budget, the merge trigger and the range bookkeeping are deterministic, and a prompt an agent can drift from is the wrong home | this record; [`steer.mjs`](../../scripts/steer.mjs) |
| The design is reimplemented, not `memo` forked | OptMem's tree and lifetime persistence serve a million records; the view is 16 lines and session-scoped | this record; the draft |
| Occurrences and directives are two grains | a restatement must not duplicate a view line, and a stale directive must be able to leave the view while staying in the log | the tool; the prompt |
| A UTC timestamp, not a date | six entries arrived in minutes, and the deep design measures the arrival rate | the tool |
| The write-back is reported, not committed | the tracker is session-local scratch, and the diff is for the operator's eyes at the write | the prompt |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The stopgap first landed the mechanics before the rules were settled, so the write rule, the timestamp and the compaction were undefined and six entries arrived in minutes on one date. The correction is the two grains, the UTC timestamp, and the resolution rule. | defect, self-raised and fixed | this record; the tool |
| The commit that first landed the stopgap passed a red gate, because the shell chain piped the lint output through `tail` and the pipeline's status replaced the gate's. | defect, fixed | this record |
| A drop in the write-back names its node, so a prune is visible at the write. | design choice | the prompt |

## Completed

| File | Change |
|---|---|
| [`scripts/steer.mjs`](../../scripts/steer.mjs) | new: note, merge, wake, zoom, forget, diff, mark; the OptMem shape without the tree |
| [`tests/test_steer.sh`](../../tests/test_steer.sh) | new: 10 cases |
| [`push-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/push-task.md) | the tool's commands, the two grains, the write-back |
| [`pop-task.md`](../../../src/reasoning/providers/pi/config/agent/prompts/pop-task.md) | report the view, expand a range with `zoom` |
| [`.agents/drafts/steering-memory-design-prompt.md`](../../../.agents/drafts/steering-memory-design-prompt.md) | the OptMem mechanisms named, the tool as the stopgap's implementation, the URL inside the prompt |
| `<scratch>/STEERING_LOG.jsonl` and the tracker's `## Steering` | the live steering, six directives |
| `$AGENT_HOME/agent/prompts/` | both prompts installed identical to the repository |
