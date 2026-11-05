---
date: 2026-11-05
milestone: M3.3.3 - The skill maintenance pipeline
type: Workflow
status: Closed
---

# Handover - the pass ends at three runbooks, and its rows compact to one

## Objective

`sidequest.md`, `rebase.md` and `merge.md` take the pass, and the prompt-surface work ends: the operator stopped it here. The four roadmap rows it accumulated -- one per prompt family, filed as the work moved -- compact into one outcome summary that names every runbook that took the pass, because a row per family is the bookkeeping this closing state does not need.

## Scope

Eleven edits across the three runbooks, and the compaction.

The three are replayed rather than read, so the same classes held: `sidequest` restated `/iter`'s scope gate and, in its own pre-close step, `/iter`'s section count -- which it got wrong, five where `/iter` states six; `rebase` explained why a port is not a rebase three times; `merge` re-explained `.draft-state` in its mandate and again in its exclusion section, and closed a rule with the rationale of a rule it had already given.

The compaction also corrects a misfiling this session introduced: the three prompt-family rows had been inserted under T5 - Archival, where the cutover row belongs, rather than under M3.3.3, whose surface they change.

Ruled out of scope, on the operator's word: `bootstrap`, `backlog-triage`, `record-correction`, `package-eval-snapshot` and `read-back` stay unpassed, and no row carries them.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `sidequest` names `/iter`'s section count correctly | `rg -n 'six sections are unchanged' workflow/coding-agent/prompts/sidequest.md` prints one line, and `rg -n 'five sections'` prints nothing | Agent [x] |
| The three runbooks keep every rule and guard | the removed-line audit over `git diff` finds no imperative that does not appear in the file after the pass, and the one that did -- `merge`'s history shape -- was restored | Agent [x] |
| No rule the pass removed is silently gone | `rg -n 'target history reads as if the work was done there' workflow/coding-agent/prompts/merge.md` prints the restored clause | Agent [x] |
| The prompt-surface rows are one | `rg -c 'took the pass' devlog/roadmap.md` prints 1, and no row names the unpassed runbooks | Agent [x] |
| The compacted row sits under the milestone whose surface it changes | the row appears between `##### M3.3.3` and `##### M3.3.4`, and T5's first row is the cutover cleanup | Agent [x] |
| Every decision this unit recorded is realized in the files | the `## Decisions` table read against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The pass stops at these three | the operator's call: the remaining five are run rarely enough that the class is not worth a further unit, and their being unpassed is a decision rather than a backlog | `devlog/roadmap.md` |
| The four prompt-family rows compact to one | the work is closed, and the task-list rule folds resolved sub-rows into an outcome summary; the handovers retain the per-family detail | `devlog/roadmap.md` |
| The one row lists every runbook that took the pass | the row's reader asks which prompts are clean, and a count would go stale while the list does not | `devlog/roadmap.md` |
| The compaction moves the rows from T5 to M3.3.3 | they were filed under the anchor the cutover row uses, and their subject is the prompt surface | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `sidequest` said `/iter`'s pre-close summary "has five sections"; `/iter` states six | defect, text | the sidequest's pre-close would present five and skip the record checks | this unit |
| The three prompt-family rows sat under T5 - Archival, because each was inserted at the anchor the cutover row uses | defect, record | a reader of T5 reads prompt-surface work as archival work | this unit, by the compaction |
| `merge`'s mandate re-explained `.draft-state` and its exclusion section explained it again; the second is now the only place, and the reason is left to `docs/adr/diff_packaging.md` | defect, text | the same exclusion stated twice drifts, and the reason belongs where the packaging decision lives | this unit |

## Completed

| File | Action |
|---|---|
| [`workflow/coding-agent/prompts/sidequest.md`](../../workflow/coding-agent/prompts/sidequest.md) | six edits: the duplicated trigger, the invocation pair merged, the orient rationale, the parent-handle restatement, `/iter`'s gate steps, and the section count corrected to six |
| [`workflow/coding-agent/prompts/rebase.md`](../../workflow/coding-agent/prompts/rebase.md) | six edits: the precondition, the raw-material rule, the scaffolding duplicate, the guess instruction, the report rationale, and two port-record restatements |
| [`workflow/coding-agent/prompts/merge.md`](../../workflow/coding-agent/prompts/merge.md) | eight edits: the port distinction, the history shape kept, the mandate's `.draft-state` reason, the base rationale, the exclusion's reason, the report rationale, and two replay explanations |
| [`devlog/roadmap.md`](../roadmap.md) | four rows compact to one, and the compaction moves it from T5 to M3.3.3 |
