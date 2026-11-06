---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The chart records the operator's dispatch of history-cleanup

## Objective

Correct the statechart's account of how `history-cleanup` is dispatched, and close the roadmap row whose premise was that no dispatcher exists.

## Scope

This iteration continues the milestone's cheap-row pass from handover `20261023-13`, and works the roadmap row **A maintenance check no command reaches**. The subject is the chart's model of one procedure, not the procedure: `history-cleanup` itself does not change. The operator stated on 2026-10-23 that the skill is dispatched by hand, with directions naming the units to target, so the finding is about the chart's missing operator route rather than about a missing command.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The chart draws no `/rebase` dispatch of `history-cleanup` | `grep -n 'history-cleanup' docs/reference/workflow_statechart.md` shows the operator label and no dispatch cell | Accepted: line 151 labels the operator and line 225 reads `none` |
| The `/rebase` dispatch cell names only what the prompt reaches | read the row against `workflow/coding-agent/prompts/rebase.md` | Accepted: the prompt names neither token, and the cell now reads `none` |
| The gap states the operator route | read the `## Gaps` entry | Accepted: the entry names the hand dispatch and the undrawn packaging case |
| The roadmap row is closed with the corrected premise | `grep -n 'maintenance check no command' devlog/roadmap.md` shows `[x]` and handover `20261023-14` | Accepted: line 252 reads `[x]` and cites the handover |
| The statechart gate is clean | `bash scripts/check_statechart.sh` | Accepted: clean across 40 states |
| The umbrella is clean | `bash scripts/lint.sh` | Accepted: clean in 9s across 11 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The edge keeps its source and gains an operator label | The drawn edge is the recovery case, and the packaging invocation is the same operator event; moving the source would invent a flow the chart does not otherwise carry | the chart's `## Gaps` |
| `history-cleanup` is not retired | The operator invokes it by hand with a target, which is a legitimate dispatch; the row's premise that a check must be command-dispatched is what was wrong | the roadmap row |
| The `/commit` half of the same cell is corrected with it | The cell is the artifact being changed, and `rebase.md` names neither token; leaving one false token beside a corrected one would be a half-fix | this record, `## Findings` |

## Decisions pending

None.

## Findings

- **The `/rebase` command row overstated both tokens.** `workflow/coding-agent/prompts/rebase.md` names neither `history-cleanup` nor `/commit`, and the row listed both. The `history-cleanup` half is this row's subject; the `/commit` half is a carrier of the same cell, so both are corrected here. The wider question, whether any dispatch cell can be gated against its prompt, is filed with the command-table row in handover `20261023-17`.

## Completed

| File | One-line change summary |
|---|---|
| [`docs/reference/workflow_statechart.md`](../../docs/reference/workflow_statechart.md) | the `chk_history` edge names the operator, the `/rebase` dispatch cell is emptied, and the gap states the operator route |
| [`devlog/roadmap.md`](../roadmap.md) | the row is closed with its premise corrected |
