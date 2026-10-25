---
date: 2026-10-24
milestone: T1 - Workflow + Policy Organization
type: Workflow
status: Closed
---

# Handover - Undo the work-log restorations

## Objective

Return `.agents/skills/work-log/SKILL.md` to the version it held before the retirement's rule-loss audit, removing the six rules that audit restored.

## Scope

One skill file, this record, and a correction note in the audit. The audit's other two files, `.agents/skills/decision-records/SKILL.md` and `.agents/skills/docs/SKILL.md`, are not touched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The live file is the pre-audit file, byte for byte | `git show f71f3fae^:.agents/skills/work-log/SKILL.md \| diff - .agents/skills/work-log/SKILL.md` prints nothing | Agent [x] |
| The five phrases the census marks `restored` no longer appear | grep each of "It is written for the agent that opens the next iteration", "Implementation steps -- the file-by-file changes", "An iteration declares its own scope", "The prior record reads `Closed`", "A pending decision is not a task" | Agent [x] |
| The `investigation` alias clause is gone | `grep -c 'was an earlier name for' .agents/skills/work-log/SKILL.md` is 0 | Agent [x] |
| The gates stay clean | `bash scripts/lint.sh` across 12 gates | Agent [x] |
| The record passes its gate | `bash scripts/check_handover_format.sh devlog/handovers/20261024-09-workflow-undo_the_work_log_restorations.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The whole pre-audit file is restored, not the six hunks deleted by hand | no commit touched the file between `f71f3fae` and this one, so byte equality with `f71f3fae^` is a check a reader can rerun | this record |
| The audit takes a correction tag, not a rewrite of its rows | the rows record what that pass did, which is still true; the tag records the later reversal, which is what the tree now contradicts | the audit's `handover_policy` section |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The census marked rows 1, 2, 4, 5 and 12 `restored` at `.agents/skills/work-log/SKILL.md`, and none of those phrases is at the file now | record | a reader of the census is told six rules landed that did not | **applied:** [`20261023-report-retirement_rule_loss_audit.md`](../discussions/20261023-report-retirement_rule_loss_audit.md) carries a correction tag on the `handover_policy` walk and a sentence that names this record |
| Handover `20261023-03` Completed row states the same restorations | record | the same stale claim, in the record that closed the audit | **applied:** the correction tag in that record's census names this record, and the census is the audit's own account; the handover row is left as what the audit did |
| The audit's five restorations were the operator's call, and this reversal is the operator's | decision | the work-log convention is thinner by one purpose paragraph, one brevity paragraph, one scope-independence paragraph, one pending-decision clause and the alias | this record |

## Completed

| File | Change |
|---|---|
| [`.agents/skills/work-log/SKILL.md`](../../.agents/skills/work-log/SKILL.md) | restored to `f71f3fae^`; the audit's five `restored` rules and the `investigation` alias are removed |
| [`devlog/discussions/20261023-report-retirement_rule_loss_audit.md`](../discussions/20261023-report-retirement_rule_loss_audit.md) | the `handover_policy` walk records the reversal and carries a correction tag |
| [`devlog/handovers/20261024-09-workflow-undo_the_work_log_restorations.md`](20261024-09-workflow-undo_the_work_log_restorations.md) | this record |
