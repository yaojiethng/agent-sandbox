---
date: 2026-11-11
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - A graded run admits only a declared experiment

## Objective

Make the declaration the unit a run admits: a case is either graded, carrying the design, the checks and the decision rule together, or an explicit observation, and no run starts on a declaration `--check` would reject.

## Scope

Two M3.3.5 rows, consolidated because the second's refusal is unenforceable without the first's predicate:

- *A graded case cannot skip its design and its checks.*
- *A run validates its declaration before it starts.*

Out of scope, with the reason:

- *A verdict records the grader's own agreement* -- re-scoped rather than landed, on operator direction. The agreement is a measured output, so declaring it in the declaration would freeze a value the next grading pass can falsify, the defect `20261111-01` closed. Its real requirement is that the run record carry the blind grade and the grader's agreement; the row is amended to say so and to start from the carrier decision.
- The typed decision rule -- filed as its own open row, because it changes the declaration interface another iteration builds against.
- The stored `gm` experiment's `decision.control` and `decision.min_effect` -- their own open row. `min_effect` is no longer required, so the stored experiment stays runnable.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A graded case declares design, checks and the decision rule together; `--check` rejects one with a rule and no design. | `bash tests/test_eval_harness.sh`, case `test_run_case_check_requires_the_graded_triple` | Agent [x] |
| A case declares its kind: an observation carries `observation` and no design or checks, and `--check` rejects a case that declares neither kind or an observation with a design. | `bash tests/test_eval_harness.sh`, case `test_run_case_check_requires_a_declared_kind` | Agent [x] |
| A configuration floor follows the kind: an observation is valid with one configuration, a graded case needs two. | `bash tests/test_eval_harness.sh`, case `test_run_case_check_rejects_a_single_configuration` | Agent [x] |
| `min_effect` is gone from the declaration shape, and the specification derives the threshold from the band and `n`. | `grep -rn 'min_effect' .agents/skills/evals/references/` prints nothing | Agent [x] |
| The run path refuses an unvalidated declaration before it resolves the fixture or creates the output. | `bash tests/test_eval_harness.sh`, case `test_run_case_refuses_an_unvalidated_declaration` | Agent [x] |
| A `--cells` dispatch refuses a rejected declaration before scheduling any cell. | `bash tests/test_eval_harness.sh`, case `test_pool_refuses_an_unvalidated_declaration` | Agent [x] |
| The skill and the harness reference state the two kinds and what `--check` reads. | `grep -n 'observation' .agents/skills/evals/SKILL.md .agents/skills/evals/references/harness.md` | Agent [x] |
| The ADR records the decision and its rejected alternatives. | `sed -n '/A run admits only a declared experiment/,$p' docs/adr/eval_harness_contract.md` | Agent [x] |
| Every decision this iteration recorded is realized in the files. | the Decisions table read against the diff | Agent [x] |
| Architecture documents in scope describe the system as built. | the ADR section read against `check_case` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The two rows are one iteration. | The run path cannot refuse a case the gate accepts without the kind predicate, so the rule and its enforcement land together. | this table |
| A case is graded when `decision.rule` is present; otherwise it is an observation and must declare `observation`. | One predicate decides the kind, so no second marker can disagree with the decision rule. | this table; `docs/adr/eval_harness_contract.md` |
| A graded case declares `design`, `checks` and `decision.rule` together; an observation declares neither `design` nor `checks`. | The graded triple is what a verdict rests on; an observation says so instead of reading as a graded case with its evidence missing. | this table; `docs/adr/eval_harness_contract.md` |
| The two-configuration floor applies to a graded case only; an observation needs one. | A comparison needs two arms, an observation does not, and the run-mechanics cases are legitimate observations. | this table |
| `min_effect` is deleted from the declaration shape. | It is a threshold derived from the measured A/A band and `n` (`1/n`), it was validated for type and read by no consumer, and a fixed value goes stale as the band moves. | this table; `docs/adr/eval_harness_contract.md` |
| The grader's agreement is not declared; row 3 is re-scoped to the run record. | The agreement is a measured output. Freezing it in the declaration is the rule-versus-number defect the previous iteration closed. | this table; the amended roadmap row |
| The decision block stays one object, not one file per field. | The checks are relational (`control` must be a live configuration, `aa` must not repeat it), so separate files force a join and give one plan three writers with no gate gained. | this table |
| The run path validates once per invocation: `--case` validates unless the caller is a `--cells` child, and the `--cells` parent validates once before scheduling. | The cost is one known-bad measurement per declared check per invocation, not per run and not per cell, and a bad declaration creates no fixture and no work root. | this table |
| `compile_declaration.sh` is unchanged. | It already merges the `harness` block wholesale, so it needs no rule of its own for the new fields. | this table |
| The typed decision rule is filed as an open row. | Making `rule` structured changes the declaration interface and the Methods vocabulary, so it needs a design step rather than a field edit here. | `devlog/roadmap.md` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `min_effect` was validated for its type and read by no consumer, and it froze a threshold the measured band and `n` derive. | record | A declared threshold outlives the band it was read from and decides a later run on stale numbers. | fixed: removed from the shape, the reference and the specification |
| The measured blind grade has no field in the run record, while `design.primary_measure` names it. | record | The primary measure a verdict rests on lives only in the grade directory and handover prose, so no run record carries the number. | the amended row *A verdict records the grader's own agreement* |
| A case with one configuration was refused even when its intent was an observation. | harness | The comparison floor was applied to every run, so an observation could not be declared. | fixed: the floor follows the kind |
| A direct `--case` run aborted under `set -u` when `EVAL_CELL` was unset, and the new validation exposed it. | harness | Every run not launched by a `--cells` parent would have failed before the gate. | fixed: the reference is defaulted |
| The relative-fixture-root and package-root-only test fixtures carried no hashes or kind, so they were valid under the old run path and invalid as declarations. | test | A fixture that the gate rejects cannot exercise the run path. | fixed: both fixtures are complete observation declarations |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/scripts/run_case.sh` | `check_case` gains the graded/observation predicate, the graded triple, the kind-dependent configuration floor and the removal of `min_effect`; the `--case` path validates once before resolving the fixture, with the `--cells` parent validating and its children skipping. |
| `.agents/skills/evals/SKILL.md` | Step 1 names the two kinds and states that a run admits only a declaration `--check` accepts. |
| `.agents/skills/evals/references/harness.md` | The `harness` field table states the graded triple, the observation marker and the kind-dependent `decision` fields. |
| `.agents/skills/evals/references/specification.md` | A1 derives its invalid condition from the measured band and `n`, not a declared `min_effect`. |
| `.agents/skills/evals/references/methods.md` | The minimum detectable effect is derived from `n` and the band, never declared as a threshold. |
| `docs/adr/eval_harness_contract.md` | Records the kind predicate, the run-path validation, the `min_effect` deletion and the rejected alternatives. |
| `tests/test_eval_harness.sh` | Fixtures become observation declarations; four new cases cover the graded triple, the declared kind, the run-path refusal and the `--cells` refusal; `run_test` registrations added. |
| `devlog/roadmap.md` | Closes the two rows; amends row 3 to the run-record requirement; files the typed-rule row; the maintenance fix to the doc-maintenance restart row. |
| `devlog/handovers/M3.3.5/20261111-04-impl-graded_declaration_gate.md` | This record. |
