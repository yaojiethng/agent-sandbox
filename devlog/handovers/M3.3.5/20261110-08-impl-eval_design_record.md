---
date: 2026-11-10
milestone: M3.3.5
type: Implementation
status: Closed
---

# Handover - The declaration is generated from the case and its checks are proven

## Objective

Make the procedure's check-admission rule deterministic and generate the declaration from the case: a case holds the intent, instruction and rubric; an experiment holds the fixture, arms, measure and decision; `--check` refuses a check the measure passes on its known-bad, and the generator recomputes the fixture hashes. Retire the committed declarations under `tests/eval/cases/`.

## Scope

The eval skill's scripts, `tests/eval/`, `scripts/check_eval_fixtures.sh`, the ADR, the skill and harness references, and one new test. The frozen payloads (`instruction-cleanup`, `smart-merge`) are untouched.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A case may declare `design` and `checks`, validated when present. | `--check` on the case and the synthetic test case | Agent [x] |
| Each check declares `id`, `role` and `known_bad`; `--check` runs the measure on the known-bad and rejects a check that passes there. | `test_run_case_check_proves_a_check_against_its_known_bad` | Agent [x] |
| A design with no checks, or checks with no design, is rejected. | the same test's `nochecks` case | Agent [x] |
| A case file carries the subject, instruction and rubric, and no `harness` block. | the five case files under `tests/eval/<subject>/case.json` | Agent [x] |
| The generator merges the case and the experiment and recomputes the fixture hashes. | `test_compile_declaration_recomputes_the_fixture_hashes` | Agent [x] |
| The existing declarations compile and validate. | four declarations generated under the output roots, `case ok` each | Agent [x] |
| A case file carrying a `harness` block is rejected. | `check_eval_fixtures.sh` reports the run harness in a case file | Agent [x] |
| The gates stay clean. | `check_eval_fixtures.sh`, lint, the eval suite and the full suite | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `design` and `checks` are optional-together, not required. | a frozen observation carries neither; a required field would edit a case this milestone must not touch | `check_case()`; `references/harness.md` |
| `known_bad` is a fixture-relative directory. | the measure's contract is `<project-dir> <base-count>`, so a directory is the one input every measure accepts | `references/harness.md` |
| `--check` invokes the measure with `bash`. | the measure scripts are committed without the execute bit, and the run path already calls `bash "$MEASURE"` | `run_case.sh` |
| The case holds the intent, instruction and rubric; the experiment holds the method. | a format change then edits the experiment, never a frozen case | `references/harness.md`; ADR 2026-11-10 |
| The declaration is generated under the output root. | the fixture already lives there, and the declaration is a run artifact | `SKILL.md` `## The stores` |
| The generator recomputes `fixture_sha256`. | a hand-maintained hash drifts from the fixture, and the generator owns the file | `compile_declaration.sh` |
| A case file lives at `tests/eval/<subject>/case.json`. | `tests/eval/cases/` held declarations, not cases | `check_eval_fixtures.sh` |
| `placement-check` keeps a case file and no experiment. | it is an observation, and observations have no run block | `tests/eval/placement-check/case.json` |

## Decisions pending

| Question | What it blocks | Options |
|---|---|---|
| None | - | - |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The measure scripts are not executable. | harness | A direct `timeout "$measure"` fails with permission denied; the run path already used `bash`, and `--check` now matches it. | this row |
| The old `harness.md` said a case never names a measure by path. | documentation | `resolve_measure()` already accepted a case-relative path; the reference now states the case-owned form the protocol relies on. | this row |
| The old declarations mixed the case and the run. | architecture | Moving them out without a generator would leave hand-maintained hashes and a fixture path in a transient file. The split removes both. | this row |
| The generator's first `expand_home` handled only `~`. | harness | The declarations carry `$HOME/...`, so the generator could not resolve the fixture. It expands both forms, and the test covers the path. | this row |
| The gate treated a directory under `tests/eval/` without `SHA256SUMS` as an unnamed fixture. | harness | A case directory holds a `case.json` and is not a fixture; the gate now skips it, and rejects a case file that carries the `harness` block. | this row |

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/scripts/run_case.sh` | Validates `design` and `checks`, and runs the measure on each known-bad. |
| `.agents/skills/evals/scripts/compile_declaration.sh` | Merges a case and an experiment and recomputes the fixture hashes. |
| `tests/eval/<subject>/case.json` | The five case files, without the run harness. |
| `tests/eval/cases/` | Retired. |
| `scripts/check_eval_fixtures.sh` | Scans `case.json`, rejects a case file carrying `harness`, and skips a case directory in the fixture check. |
| `.agents/skills/evals/SKILL.md`, `references/harness.md` | State the procedure, the design record and the case, experiment and declaration split. |
| `docs/adr/eval_harness_contract.md` | Amends R1 and records the decision. |
| `tests/test_eval_harness.sh` | Proves the known-bad rejection and the generator's hashes. |
| `devlog/roadmap.md` | Closes the declaration and generator rows. |
| `devlog/handovers/M3.3.5/20261110-08-impl-eval_design_record.md` | This record. |
