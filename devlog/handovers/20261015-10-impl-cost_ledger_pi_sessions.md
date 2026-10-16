---
date: 2026-10-15
milestone: M3.6 - Cost-Aware Dispatch
type: Implementation
status: Closed
---

# Handover - The cost ledger over pi sessions

## Objective

Turn a pi session JSONL into one cost record per dispatch, so a dispatch's price and its wall clock are readable.

## Scope

The pi source of the M3.6 task `The cost ledger`, the W1.1 unit of the run directive. Dispatched with the `sequential-work` shape on `opencode-go/cat-jam-free`.

Out of scope: the OpenCode JSON event stream and the same-brief-on-two-models comparison. Both wait on the runner seam. The row stays open with the pi half landed.

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | One record per session, summed tokens and cost | `bash tests/test_cost_ledger.sh` is 2 passed, 0 failed, over literal expected values | Accepted |
| 2 | It reads the real session store | `node scripts/cost_ledger.mjs --root /home/agentuser/.pi/agent/sessions` prints 591 records | Accepted |
| 3 | The sum is not a constant | mutation: a token class pinned to a constant fails the test, restored byte-identical | Accepted |
| 4 | Lint and suite clean | `bash scripts/lint.sh` clean across 8 gates; `bash scripts/run_tests.sh` 1147 passed | Accepted |

## Decisions

1. **The record is one per session, not one per message.** One session is one dispatch, so the record aggregates the turns and carries the dominant provider and model.
2. **The script takes a `--session` file or a `--root` tree.** The tree form is what makes the whole store readable in one command.
3. **The primary corrected the return by four lines.** The subagent's script threw an unhandled `EPIPE` when a reader closed the pipe early, so `| head` crashed. The primary added a stdout error guard that exits on `EPIPE`. Recorded here because the correction is in the primary's turn.

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The ledger is pi-only. The `backend` field is written `"pi"`, and the OpenCode JSON event stream is unread until the runner seam lands. | scope | the row stays open |
| A first probe of the free seat through pi routed to the `step-5-preview-free` failover chain rather than `cat-jam-free`. `cat-jam-free` is absent from the baked opencode-go models and from `routes.json`, so pi cannot address it; OpenCode can. Triaged to: the runner seam's role-to-backend resolution. | obstacle, measured | the runner seam |

## Completed

| File | Change |
|---|---|
| [`scripts/cost_ledger.mjs`](../../scripts/cost_ledger.mjs) | new: one record per session, with an `EPIPE` guard added by the primary |
| [`tests/test_cost_ledger.sh`](../../tests/test_cost_ledger.sh) | new: literal sums over a fixture session |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | the cost-ledger row records the pi half and names the OpenCode half pending |
| [`devlog/handovers/20261015-10-impl-cost_ledger_pi_sessions.md`](20261015-10-impl-cost_ledger_pi_sessions.md) | this record |
