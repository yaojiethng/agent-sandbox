---
date: 2026-11-10
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - The check-in write rule is stated once and lands

## Objective

Assess the approved check-in write-rule text as an A/B candidate against the landed prompt, on structural outcome, milestone alignment and token cost, and decide whether to land it; because the edit is clearer and shorter, unchanged behaviour is an acceptable outcome.

## Scope

The check-in prompt `workflow/coding-agent/prompts/gm.md`: the approved replacement of the write rule across `## Scope`, `## Survey`, `## Non-goals`, `## Inventory` and `## Close`. The rule becomes: the check-in's only write is an inert fix, and a discrepancy about what the record asserts is surfaced as a finding. The commit type is delegated to `git-discipline`, the `does not repair` / `do not fix` negations are removed, and `record defect` / `record contradiction` become `discrepancy`. The control is the pre-repair landed prompt, carried as the `baseline` overlay; the candidate is the `checkin-write-rule` fixture overlay. The run is eight runs per cell on `opencode-go/iceman-contributor-free`.

The runs and records merged here: `20261110-02-audit-checkin_write_rule` and `20261110-03-impl-checkin_write_rule`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The baseline overlay equals the pre-repair landed prompt; the candidate differs only by the approved edits. | `diff` of `fixture/configurations/baseline/.../gm.md` against `git show HEAD:workflow/coding-agent/prompts/gm.md` is empty before the run; `diff` against the candidate is the seven approved edits | Agent [x] |
| `--check` accepts the case with the new configuration. | `run_case.sh --check=tests/eval/cases/gm-focus-milestone.json` prints `case ok` | Agent [x] |
| Both cells complete eight runs with no invalid run, in both orders. | the candidate ran 8/8 valid; the control ran 8 with one timeout in each of two batches; the pool stopped twice, so the reversed order was dropped and the two control batches bracket the candidate | Agent [x] one order; reversed pushed |
| The structural outcome is recorded per arm. | `benchmark.json`: baseline r2 0.9643 (one `inventory_table` failure), candidate 0.9643 (one `direction_form` failure) | Agent [x] |
| The blind milestone-alignment reading is recorded per arm. | the label-free `blind-checkin-write-rule-20261110/` and its `joined.tsv`: baseline 2/8, candidate 2/8 | Agent [x] |
| Token cost, turns and wall clock are recorded per arm. | the benchmark's `tokens_total`, `turns`, `wall_seconds`, `elapsed_mean` | Agent [x] |
| The operator's acceptance rule is applied: unchanged behaviour is accepted, since the edit is clearer and shorter; the case's stricter rule is recorded alongside. | this record's Findings and Decisions | Agent [x] |
| The outcome decides the landing: the text lands only if the reading shows no regression, and otherwise stays a candidate. | the text landed in `workflow/coding-agent/prompts/gm.md`; `20261110-03` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The control is the pre-repair landed prompt, carried as the `baseline` overlay | the only variable between the arms is the approved text; the baseline overlay is identical to HEAD before the landing | this record |
| The control is the baseline r2 cell (7 valid); the r1 cell (7 valid) is the second control | both carry the pre-repair prompt; the two batches give the control's own spread, and the r2 batch is the one graded blind with the candidate | this record |
| The candidate cell ran alone after the pool stopped | the stop held the remaining cell; the baseline's 7 valid runs are the control and the candidate ran 8/8 | this record |
| The operator's acceptance governs: unchanged behaviour is accepted, because the edit is clearer and shorter; an improvement is not required | the edit is a clarity and length repair, so the case's lower-cost clause would reject a neutral result the operator accepts | this record; the operator's directive |
| The case's own decision rule is recorded alongside as the stricter reading: structural at or above (met), lower token cost (not met against the r2 control), lower wall clock (met), blind grade not preferring the control (met) | the formal bar and the operator's decision are both visible; the token difference sits inside the control's own batch spread | this record; `tests/eval/cases/gm-focus-milestone.json` |
| The run uses `opencode-go/iceman-contributor-free` | `crouton-alpha-free` is deprecated (HTTP 410); iceman is the declared survivor | this record |
| The text lands | structural and alignment are equal, the cost sits inside the control's spread, the candidate cell had no timeout, and the text is clearer and shorter; the operator's acceptance decides | this record; `20261110-03` |
| The text lands | the A/B shows structural and blind-alignment outcomes equal to the control, the per-run token median inside the control's batch spread, and no timeout in the candidate cell; the text is clearer and shorter, and the operator accepted unchanged behaviour | this record; `20261110-02` |
| The landing is the measured candidate, not a re-worded version | the evidence is about that exact text; an untested rewording would detach the edit from its measurement | this record |
| The fixture keeps the pre-repair baseline | the historical A/B stays reproducible; the next experiment refreshes the baseline to the landed prompt | this record; `tests/eval/cases/gm-focus-milestone.json` |
| No new ADR | the rule is a prompt repair with its evidence in the handover and the case, not an architecture decision | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The structural outcome is equal and the failing assertion swaps. | measurement | baseline 0.9643 (one `inventory_table` failure in eight), candidate 0.9643 (one `direction_form` failure in eight); 27 of 28 assertions pass in both | this record; the landing decision |
| The blind milestone alignment is equal. | measurement | baseline 2/8, candidate 2/8; the narrow M3.3.5-only count is 2/8 each; the baseline's count includes the timeout's empty report, which the rule reads as misaligned | this record |
| The token cost sits inside the control's batch spread. | measurement | candidate median 1.20M against the control's 1.04M (r2) and 1.23M (r1), combined 1.12M; candidate mean 1.24M against 1.00M and 1.30M; turns median 13 against 13; the case's lower-cost clause is not met against the r2 control, and the control's own batches differ by more than that | this record; the landing decision |
| The baseline cell timed out twice, the candidate cell not at all. | harness | `timeout` at baseline run 6 (600 s) and run 2 (900 s); R7 named the class, cell and run and held the remaining `checkin-write-rule`; each baseline cell finished 7/8 valid; the candidate alone ran 8/8 | this record; the eval's reliability note |
| The blind grade is the running agent's reading. | methods | one clean-context `pi -p` reviewer over the label-free reports; no second independent rater (deferred in `roadmap_future.md`) | `devlog/roadmap_future.md` |
| None new | - | the landing changes no code and no gate | - |

## Completed

| File | One-line change summary |
|---|---|
| File | One-line change summary |
| `tests/eval/cases/gm-focus-milestone.json` | Adds the `checkin-write-rule` configuration and the fixture note. |
| `devlog/handovers/M3.3.5/20261110-02-audit-checkin_write_rule.md` | This record. |
| `$HOME/workspace/output/evals/gm-focus-milestone/` | The two stopped baseline batches, the candidate cell, and the blind grading set. |
| File | One-line change summary |
| `workflow/coding-agent/prompts/gm.md` | Replaces the write rule across Scope, Survey, Non-goals, Inventory and Close with one inert-fix rule. |
| `tests/eval/cases/gm-focus-milestone.json` | The notes name the baseline as the pre-repair control and the candidate as the landed text. |
| `devlog/roadmap.md` | Adds the `[x]` row with the A/B outcome. |
| `devlog/handovers/M3.3.5/20261110-03-impl-checkin_write_rule.md` | This record. |
