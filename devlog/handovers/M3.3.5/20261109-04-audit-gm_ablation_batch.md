---
date: 2026-11-09
milestone: M3.3.5 - The eval pipeline
type: Audit
status: Closed
---

# Handover - The `/gm` ablation batch runs in isolation

## Objective

Screen the viable models and run the declared ablation batch in isolation, then record each configuration's cost and milestone alignment against the control.

## Scope

Continues the parent row **The `/gm` ablation run, and the pipeline as the authority for an instruction edit** from `20261109-03-impl-gm_case_reproduces.md`, and works its second sub-row: screen the viable models and run the declared ablation batch in isolation.

The case `tests/eval/cases/gm-focus-milestone.json` and its fixture are read-only this iteration. The evidence lands under `$HOME/workspace/output/evals/gm-focus-milestone/`: one screen directory per model and one batch directory. The iteration produces the table and this record; the accepted ablations land in the next sub-row.

Out of scope, one sentence each with the reason: the prompt edit and the write-back are the third sub-row; a pipeline defect the batch finds routes to the M3.3.5 row that owns it; the `opencode/*-free` ids are struck for cost measurement because the route writes no pi transcript.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| Every `opencode-go/*` model is screened on `baseline` with one run, and the outcome is recorded with its reason. | the screen's `measure-baseline.json`; crouton 4/4 at 796k/52 s, beam 2/4 at 276k/21 s, iceman 4/4 at 655k/125 s; all valid, every report present | Agent [x] |
| The batch is one `--cells` invocation with the control and every declared configuration at `runs=2`, on the chosen model, and every cell is valid or struck. | `benchmark.json`: 19 cells, 38 runs, 38 valid, 0 invalid; the batch ran on crouton | Agent [x] |
| The baseline's per-turn attribution names the top five cost drivers by path and turn. | `cell-baseline/case-baseline/run-1/session.json`: `devlog/roadmap.md` 215,971 B at turns 4/14/15/16; `work-log/SKILL.md` 11,330 B and `task-list/SKILL.md` 10,414 B at turn 4; `gm.md` 7,034 B at turn 1; `inventory.md` 8,061 B at turn 21 | Agent [x] |
| Every cell's recommendation is graded against the alignment rule, and the verdict is joined to the map only after the grade. | `blind-grade.tsv` (38 verdicts) and `blind-grade.log` (the clean-context `_REVIEWER`); `grade-map.json` opened only to join | Agent [x] |
| The table states each configuration's structural score, alignment, total tokens, wall clock and verdict under the case's decision rule. | the findings row and the pre-close table; `benchmark.json` | Agent [x] |
| A batch that does not reproduce the alignment complaint amends the list and records the amendment. | the control is misaligned (M3.1.2) and unstable (3/4 then a no-report); the aligned cells reproduce the separation, so no amendment | Agent [x] |
| The suite and the lint umbrella are green. | `tests/test_eval_harness.sh` 38/38; `scripts/lint.sh` clean across 26 gates | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The screen is one baseline canary per `opencode-go/*` model, one run each. | A canary is a viability check, not a measurement; a strike removes a model before the batch spends its requests. | this record; the screen directories |
| A model is struck when the route refuses, the cell is invalid, `inventory.md` is absent, or the structural score is below the case's floor. | The same four conditions the pilot used; a cell that cannot produce a report cannot be compared. | this record; the screen table |
| The batch model is the first survivor in the order `crouton-alpha-free`, `beam-free`, `iceman-contributor-free`. | The order is declared before the screen, so the result is not chosen after seeing it, and crouton first keeps the comparison with the pilot and replicate. | this record; the batch command |
| The batch is one `--cells` invocation, every declared configuration, `runs=2`, at `EVAL_MAX_PARALLEL=5`. | The case declares two runs; one invocation is the isolated batch the operator asked for, not a hillclimb. | this record; the batch root |
| The alignment rule is graded blind: the sanitized `grade/` is read before `grade-map.json`. | The grade directory carries no label; the map is the only place the label is recorded, so reading the map first destroys the blind. | this record; the grade |
| Cost is total tokens plus wall clock, with correctness first and size as the tie-break. | The brief's cost metric; the per-turn attribution is the diagnostic, not the verdict. | this record; the batch table |
| If the control is already aligned and no ablation separates, the list is amended and the amendment recorded. | A case that does not reproduce the complaint cannot measure an edit against it; the amendment is the evidence that it did not. | this record; the case's configurations |
| The evidence stays under the output root; no case or fixture file changes. | The fixture is pinned by hash and the case is the declaration; a run that edits either is not evidence about the prompt. | this record; the output root |
| The batch runs on `crouton-alpha-free`, the first survivor. | The order was declared before the screen; beam struck at 2/4 and iceman survived, so crouton runs the batch and keeps the comparison with the pilot. | this record; the screen dirs |
| The accepted ablation is `no-close-prefactor-tail`. | It is the only cell aligned on both runs, structural 4/4 on both, and cheaper than the control: 780k tokens / 50.5 s against 1.245M / 113 s. | this record; the pre-close table; the next sub-row |
| The control is misaligned and unstable: run 1 is 3/4 and recommends M3.1.2, run 2 is a 3-turn no-report. | The control sets the bar; the table reads the report-bearing run and flags the failed run instead of averaging it in. | this record; the findings |
| The blind grade runs through a clean-context `_REVIEWER` over a label-free copy; the map is opened only to join. | The grade directory carries no label; the map is the only place it is recorded. The parent's earlier sample read is disclosed in the findings. | this record; `blind-grade.tsv`, `blind-grade.log` |
| The write-back lands in the next sub-row, not here. | One iteration is one slice; the batch is the evidence, and the prompt edit is its own iteration. | the roadmap's third sub-row |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Screen: crouton 4/4 at 796k tokens / 52 s; beam 2/4 at 276k / 21 s; iceman 4/4 at 655k / 125 s. All three valid, every report present. | measurement | beam is struck below the floor; crouton is the first survivor and runs the batch; iceman is the fallback. | this record; the batch table |
| Batch: 19 cells x 2 runs, 38/38 valid; the control is 3/4 then a no-report; `no-close-prefactor-tail` is the only cell aligned on both runs, 4/4 on both, and cheaper (780k / 50.5 s against 1.245M / 113 s). | measurement | the accepted ablation; the control's alignment is misaligned (M3.1.2). | this record; the next sub-row |
| The blind reviewer graded 16 aligned, 21 misaligned, 1 no-report: every M3.1.2 one-line gate fix misaligned, every M3.3.5 row aligned, every M3.3.6 command-table row misaligned. | measurement | the aligned cells are the quality gain over the control; the M3.1.2 family lacks an accepted basis. | this record; `blind-grade.tsv` |
| The control's second run stopped at 3 turns with a status summary and no `inventory.md`; `run_case.sh` marks it valid, and the summary's `correctness` is null for a report run that does not commit. | harness | the table reads `rules`, not `correctness`; a 0/4 is a failed cell even when the harness calls it valid. | this record; M3.3.5's stopped-run and assertion-record rows |
| The baseline read `devlog/roadmap.md` (215,971 bytes) four times, turns 4/14/15/16; the per-turn input grew from 15.7k to 79k across those turns. | measurement | the roadmap is the dominant read surface, not the prompt prose. | this record; the next sub-row |
| The initial blind was compromised by a sample of `grade-map.json` (three labels) before the grade; the clean-context `_REVIEWER` re-graded a label-free copy, and the map was opened only to join. | record | the grade reported here is the reviewer's, not the parent's; the disclosure keeps the record honest. | this record |

## Completed

| File | One-line change summary |
|---|---|
| `$HOME/workspace/output/evals/gm-focus-milestone/screen-{crouton-alpha-free,beam-free,iceman-contributor-free}/` | One baseline canary per model, with its measure and report. |
| `$HOME/workspace/output/evals/gm-focus-milestone/batch-20261109/benchmark.json` | The 19-cell table: structural score, tokens, wall clock, validity. |
| `$HOME/workspace/output/evals/gm-focus-milestone/batch-20261109/grade/`, `grade-map.json` | The 38 blind grade files and the label map. |
| `$HOME/workspace/output/evals/gm-focus-milestone/batch-20261109/blind-grade.tsv`, `blind-grade.log` | The clean-context reviewer's 38 verdicts and its transcript. |
| `devlog/handovers/M3.3.5/20261109-04-audit-gm_ablation_batch.md` | This record. |
| `devlog/roadmap.md` | Sub-row 2 marked `[x]` at close. |
