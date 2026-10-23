---
date: 2026-10-23
milestone: M3.3.2 - Retire the policy form
type: Workflow
status: Closed
---

# Handover - The handover content checks get a runbook and a caller

## Objective

Split `handover-maintenance` into two runbooks with the skill as an index, and give the two content checks a dispatcher at the scope gate and the pre-close.

## Scope

This iteration continues the milestone's cheap-row pass from handover `20261023-16`, and works the roadmap row **The two remaining handover content checks have no dispatcher**. The operator named the shape on 2026-10-23: the tracks become runbooks and the skill becomes a reference table. The checks themselves do not change; what changes is where they live and who opens them. `iter.md` gains the dispatch, so the checks are read at the two moments they name.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The skill is an index over two runbooks | `ls workflow/coding-agent/skills/handover-maintenance/runbook/` lists `content.md` and `chain.md`, and `SKILL.md` links both | Accepted: both files exist and the index links them |
| The content checks live in the content runbook | `grep -n "Structured output format\|Validation tool coverage" workflow/coding-agent/skills/handover-maintenance/runbook/content.md` finds both | Accepted: both headings are present |
| The chain checks live in the chain runbook | `grep -n "Dangling references\|The correction form" workflow/coding-agent/skills/handover-maintenance/runbook/chain.md` finds both | Accepted: both headings are present |
| No check was lost in the move | every step heading in the old skill appears in one runbook | Accepted: the two content steps and the seven chain steps cover the old nine |
| `/iter` opens the content runbook at the scope gate | `grep -n 'content runbook' workflow/coding-agent/prompts/iter.md` finds the scope-gate dispatch | Accepted: line 100 is the Step 5 dispatch |
| `/iter` opens it again at the pre-close | the same grep finds the Step 7 dispatch | Accepted: line 173 is the Step 7 dispatch |
| The roadmap row is closed | `grep -n 'handover content checks' devlog/roadmap.md` shows `[x]` and handover `20261023-17` | Accepted: line 250 reads `[x]` and cites the handover |
| The umbrella is clean | `bash scripts/lint.sh` | Accepted: clean in 8s across 11 gates |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Two runbooks, not three | The correction form belongs to the chain, where closed records are; a third file would separate a step from the run that owns it | this record |
| The skill keeps the shared shape table | Both runbooks check the same shape against the same convention, so the table has one owner | `SKILL.md` |
| `/iter` dispatches the content runbook, not the whole skill | The chain runbook's subject is closed handovers, and the iteration's subject is the record it is writing | `iter.md` |

## Decisions pending

None.

## Findings

- **The row said `wrapup` B8 dispatches the correction-form report.** B8 closes documents; B9 runs the record checks. The row's citation is corrected with it: B9 opens the content runbook over the closed handover, and the chain runbook stays with `check-in` and operator audits.

## Completed

| File | One-line change summary |
|---|---|
| [`workflow/coding-agent/skills/handover-maintenance/SKILL.md`](../../workflow/coding-agent/skills/handover-maintenance/SKILL.md) | the tracks become a runbook index, with the shared shape table and output shape |
| [`workflow/coding-agent/skills/handover-maintenance/runbook/content.md`](../../workflow/coding-agent/skills/handover-maintenance/runbook/content.md) | the two content checks and their run points |
| [`workflow/coding-agent/skills/handover-maintenance/runbook/chain.md`](../../workflow/coding-agent/skills/handover-maintenance/runbook/chain.md) | the chain audit, its seven steps and its failure modes |
| [`workflow/coding-agent/prompts/iter.md`](../../workflow/coding-agent/prompts/iter.md) | the scope gate and the pre-close open the content runbook |
| [`devlog/roadmap.md`](../roadmap.md) | the row is closed with the dispatcher named |
