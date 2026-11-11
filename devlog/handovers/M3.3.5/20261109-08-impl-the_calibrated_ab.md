---
date: 2026-11-09
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - The control is calibrated and the current-milestone rule lands

## Objective

Establish the `/gm` control's distribution on `opencode-go/crouton-alpha-free` at a declared run count: the four structural rules, the blind alignment reading, the no-report rate, the credits, the wall clock and the per-turn read surface.

## Scope

The M3.3.5 row **The `/gm` eval calibrates the control against the model, and the calibration is the A/A**, the first of the two experiment rows. The control's two batch runs disagreed (one 3/4 report, one 0/4 no report), so the control was not established. This run repeats the control prompt eight times on one model and records the observed distribution. The case's `runs: 2` is the floor; the calibration declares eight. A no-report run is a failed calibration run, not a harness-invalid one.

The runs and records merged here: `20261109-08-impl-calibration` and `20261109-09-audit-current_milestone_rule`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The control runs at the declared count with no stop and no invalid run. | `calibration-20261109/measure-baseline.json`: `runs: 8`, `valid: 8`, `invalid: 0`, `runs_detail[].stop_class` all null | Agent [x] |
| The no-report rate is recorded, and a no-report run is read as a failed calibration run. | `report_present` per run: 8/8 true; no-report rate 0/8 | Agent [x] |
| The four structural rules are recorded per run and their distribution is stated. | seven runs 4/4; one run 3/4, `state_summary` the failed assertion | Agent [x] |
| The alignment reading is a blind grade over the sanitized grade directory. | `calibration-grade.tsv` / `calibration-grade-joined.tsv`: 5 aligned, 3 misaligned under the case's basis-inclusive rule (2 aligned under the narrow M3.3.5-only reading); the map was opened only to join | Agent [x] |
| Cost and the per-turn read surface are recorded. | 4,817,719 tokens, 106 turns, 115.75 s mean; `devlog/roadmap.md` 431,942 B aggregate | Agent [x] |
| The calibration row is marked `[x]` with the outcome. | `devlog/roadmap.md` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The calibration runs the control eight times, above the case's declared floor of two | eight gives a distribution for the binary no-report outcome and the alignment rate, and fits the free-model budget; the case's `runs` stays the floor | this record |
| The model is `opencode-go/crouton-alpha-free` at `medium` thinking | the survivor of the 2026-11-09 model screen; the route writes a pi transcript, so cost is measurable | this record |
| A no-report run is a failed calibration run, not a stop class or a harness-invalid run | the harness validity is evidence (return code and attribution); the calibration reads report presence as an outcome | this record; `harness.md` |
| The alignment reading is over the label-free `grade/` directory, with the label map opened only after the grade; the grader was the agent that ran the experiment | the grader must not read the configuration out of the label; the calibration has one arm, so the blind discipline is structural, not independent, and the second-rater work is deferred in `roadmap_future.md` | this record |
| The first hypothesis is S2's current-milestone rule, inserted in `## Close` | the calibration's dominant failure is the cross-milestone M3.1.2 recommendation; S2 targets that failure | this record |
| The A/B runs both cell orders: control-then-rule and rule-then-control | the pool runs cells sequentially, so one order cannot separate the arm from a time effect; the reversed order is the check | this record |
| A cross-milestone recommendation that states a recent/urgent basis is counted as aligned, per the case's expected output; the narrow M3.3.5-only count is recorded beside it | the case's assertions accept a cross-milestone item "whose report names a basis: it blocks a task under M3.3.5, or it is a recent, urgent problem"; the narrow count is the sensitivity for a reader who rejects a stated urgency as a basis | this record; `tests/eval/cases/gm-focus-milestone.json` |
| The case's decision rule is applied as written, and the cost clause is flagged | the rule was written for the ablation batch, where a lower cost is the point; this hypothesis is an addition, so eligibility under the rule is recorded, not treated as a formal significance test | this record |
| The S2 prompt edit is not landed | the A/B is the test; the operator resolves whether the alignment and cost outcomes justify the edit | this record; `devlog/roadmap.md` |
| The grade is the running agent's reading over the label-free `grade/` directory, not a second independent rater | the maps were opened only after the grade; a clean-context reviewer would remove the residual knowledge, and the second-rater and kappa work is deferred in `roadmap_future.md` | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|

## Completed

| File | One-line change summary |
|---|---|
| File | One-line change summary |
| `$HOME/workspace/output/evals/gm-focus-milestone/calibration-20261109/` | The eight runs, the benchmark, the label-free grade, the grade map and the joined grade. |
| `devlog/roadmap.md` | Marks the calibration row `[x]` and records the distribution. |
| `devlog/handovers/M3.3.5/20261109-08-impl-calibration.md` | This record. |
| File | One-line change summary |
| `tests/eval/cases/gm-focus-milestone.json` | Adds the `current-milestone-rule` configuration and the extended notes. |
| `$HOME/workspace/output/evals/gm-focus-milestone/ab-20261109/` | The first order: sixteen runs, the benchmark with `batch` and `analysis`, the label-free grade, the grade map and the joined grades. |
| `$HOME/workspace/output/evals/gm-focus-milestone/ab-reversed-20261109/` | The reversed order: the same sixteen-run record. |
| `devlog/roadmap.md` | Marks the A/B row `[x]`, records the outcome, and leaves the S2 row open with the result. |
| `devlog/handovers/M3.3.5/20261109-09-audit-current_milestone_rule.md` | This record. |
