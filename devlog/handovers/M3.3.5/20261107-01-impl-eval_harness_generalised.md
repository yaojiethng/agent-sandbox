---
date: 2026-11-07
milestone: M3.3.5 - The eval pipeline
type: Implementation
status: Closed
---

# Handover - the eval harness runs a general declaration

## Objective

Make the eval harness carry any subject from a case declaration, with no default measure and no subject-specific file layout, and state the contract that declaration answers.

## Scope

The harness row and the convention row of M3.3.5. It moves the runner, the measures, the cases and the reference documents to `.agents/skills/evals/` and `tests/eval/cases/` in one placement, and writes the eval harness contract as an ADR. The case-set gates are the next record; the record census and the roadmap write-back are `20261107-03`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A case file declares the fixture, the measure, the prompt and its configurations, and a run takes them without editing `run_case.sh` | `test_run_case_runs_a_case_file_declaration` and `test_run_case_seeds_a_package_root_onto_the_config_copy` in `bash tests/test_eval_harness.sh` | Agent [x] |
| An ad-hoc run names its measure, and the harness has no default measure | `test_run_case_needs_a_measure` exits 2 before a clone | Agent [x] |
| A measure can carry another budget, and the report measure can read a named path | `EVAL_SUBJECT_MAX` and `EVAL_BODY_MAX` in `measure_commit.sh`; `test_measure_report_reads_a_named_path` | Agent [x] |
| A run's cost and validity come from every session it wrote | `bash tests/test_eval_contract.sh` (6 of 6), including the seat sum, the working-directory lookup and the escape counter | Agent [x] |
| A run leaves no worktree and returns its change as a bundle plus a patch | `test_run_case_leaves_no_worktree`, `test_run_case_writes_a_change_bundle`, `test_run_case_writes_a_patch_for_a_dirty_run` | Agent [x] |
| A grader reads sanitized names and the label map lives outside the grade directory | `test_run_case_writes_a_sanitized_grade_dir` | Agent [x] |
| A frozen fixture is checked against its manifest, and the case-set directory can be named | `bash tests/test_eval_fixtures.sh` (9 of 9), including `test_a_named_case_set_is_reported` | Agent [x] |
| The harness, the cases and the references have one home | `rg -n 'workflow/coding-agent/skills/eval' .agents/skills/evals tests/eval` returns nothing | Agent [x] |
| The suite is green | `bash tests/test_eval_harness.sh` (31 of 31); `bash tests/test_eval_contract.sh` (6 of 6) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The case file is the domain model: fixture, hashes, measure, prompt, configurations and decision rule | One declarative contract replaces a flag per dimension, and `--check` validates it before a run | `docs/adr/eval_harness_contract.md`; `run_case.sh` `check_case` |
| The harness has no default measure | A default is the commit-body subject hiding in generic machinery; a run names its measure in the case, `--measure` or `EVAL_MEASURE` | `run_case.sh`; `references/harness.md` |
| The harness moves to `.agents/skills/evals/` once, and the cases to `tests/eval/cases/` | The skill is the mechanism and the case is test data; writing the files under the old workflow path and moving them later is an inversion | this record's Completed table |
| The measurement contract is a reference beside the runner | A field no row names is not added, and a row no decision acts on is not kept | `references/contract.md` |
| No run record is committed | A run's evidence is outside the repository, and a committed run makes every later diff carry a number nobody re-derives | `docs/adr/eval_harness_contract.md`; `SKILL.md` `## The stores` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| What restores a fixture when the output root is cleared? | Whether a case runs on a fresh host, and whether the answer is a recipe or a copy | re-copy the fixture from the operator store; or add a builder that reconstructs it from a declared source |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The ported harness wrote its runner under `workflow/coding-agent/skills/eval/` and moved it to `.agents/skills/evals/` in a later commit | inversion | The cleanup writes the final tree once at its declared home, so no commit adds a file that a later commit deletes | fixed in this iteration |
| The runner defaulted to `measure_commit.sh`, so an unrelated case inherited the commit-body subject | harness defect | The default is removed; a run names its measure and `test_run_case_needs_a_measure` pins the refusal | fixed in this iteration |
| The session measure could not find a transcript by its working directory when the config home moved | harness defect | `PI_CODING_AGENT_DIR` is read, and `test_contract_finds_a_session_by_working_directory` pins it | fixed in this iteration |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/SKILL.md` | States the stores, the run, the invariants and the close over the general declaration |
| `.agents/skills/evals/references/harness.md` | States every case field, measure field and run layout |
| `.agents/skills/evals/references/contract.md` | States the six questions a run must answer and the condition that voids each |
| `.agents/skills/evals/playbooks/hillclimb.md` | Carries the sustained-improvement loop beside the harness |
| `.agents/skills/evals/scripts/run_case.sh` | Runs a case declaration, requires a measure, blinds the grade and writes the change back |
| `.agents/skills/evals/scripts/measure_commit.sh` | Scores a delivery commit against configurable budget and type rules |
| `.agents/skills/evals/scripts/measure_report.sh` | Scores a named report file's presence, line count and size |
| `.agents/skills/evals/scripts/measure_session.mjs` | Sums every session's cost and reports escapes, attribution and abnormal stops |
| `tests/eval/cases/commit-body-budget.json` | Declares the commit-body case and its known answer |
| `tests/eval/cases/doc-maintenance-review.json` | Declares the doc-maintenance review case and its contrast |
| `tests/eval/cases/placement-check.json` | Keeps the placement observation with no harness block |
| `tests/test_eval_harness.sh` | Holds the declaration, the measure, the pool, the grade and the write-back |
| `tests/test_eval_contract.sh` | Holds the measurement contract against stub runs |
| `docs/adr/eval_harness_contract.md` | Records the seven requirements and the declaration decision |
| `scripts/check_eval_fixtures.sh` | Holds fixture manifests and validates the named case set |
| `tests/test_eval_fixtures.sh` | Adds the named case-set case |
| `workflow/coding-agent/skills/eval/` | Removed after the content moved to its one home |

Merged from handovers `20261107-02-impl-eval_case_set_gates`; their decisions and findings remain in the pre-rewrite history.
