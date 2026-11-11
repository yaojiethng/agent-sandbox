# The harness reference

The fields a case may carry, the stores, the measure kinds, the fields a measure emits, and the layout a run leaves. The runner is [`../scripts/run_case.sh`](../scripts/run_case.sh). The layout is declared once, in [`../assets/layout.json`](../assets/layout.json), read by [`../scripts/layout.sh`](../scripts/layout.sh); the runner and `scripts/check_eval_fixtures.sh` consume it.

## The stores

| Store | Holds | Named by | Lifetime |
|---|---|---|---|
| This skill directory | the runner, the process measures and the case fields | the skill | committed |
| The case directory | one `case.json` carrying the intent, the instruction and the rubric, plus the frozen payload | `caseRoot` in the layout | committed |
| The output root | the experiment file, the generated declaration, the fixture, the candidate overlays, and one directory per run | `outputRoot` in the layout; `--out` overrides it | persists, never committed |
| The work root | the throwaway clone and the run's project | `--work`, or a temporary root | does not outlive the run |

## Process and content measures

The **process measures** - tokens, turns, wall clock, validity and stop class - belong to the harness and are reused across cases. A **content measure** is case-bound: it reads the case's artefact, is hashed with the fixture, is proven against a known-bad input, and dies with the case. A content measure promoted into the harness becomes a second source of truth for a subject the case owns. A **blind rubric** is single-use: one case, one judgement, one prompt. A content measure that saturates is a validity floor; the discriminating judgement is the blind grade. The outcome is the measure the decision rule names, and the rest are diagnostics.

A measure is a script that prints one JSON object on stdout, and the case names it.

## A case file

Top-level fields, beside the `cases` array:

| Field | Meaning |
|---|---|
| `subject` | the instruction set under test, named by the file it lives in |
| `subject_kind` | what kind of text that is: a policy wording, a skill, a prompt |
| `source` | where the negative case came from, with the record and date that showed it |
| `configuration_variable` | the one thing that differs between configurations |
| `cases` | the case array below |
| `notes` | what the run taught, or what the reader needs before running it |
| `harness` | absent from a case file; the generated declaration carries it |

Each entry in `cases` carries `id`, `prompt`, `expected_output`, `fixture`, `assertions` and `measurement`, and may carry `observed` once a run has been scored.

## The case, the experiment and the declaration

A case file holds what the task is; the table above lists its fields. An experiment file holds how the run is built and judged: `{ "harness": { fixture_root, bundle, patch, measure, prompt, configurations, stop_classes, decision, design, checks, observation } }`. It lives under the output root beside the fixture.

`compile_declaration.sh <case.json> <experiment.json> --out=<declaration.json>` merges them and recomputes `fixture_sha256` from the bundle and the patch, so no hash is hand-maintained. The runner reads the declaration, and `--check` validates it.

## The `harness` block

| Field | Required | Meaning |
|---|---|---|
| `fixture_root` | yes | the fixture directory, absolute or relative to the case file; `$HOME` expands |
| `bundle` | yes | the fixture's base, as a git bundle inside `fixture_root` |
| `patch` | yes | the workload applied over the base |
| `fixture_sha256` | yes | the fixture hashes `--check` compares before a run |
| `measure` | yes | a measure by **bare name**, resolved beside the runner, or a path relative to the case file |
| `prompt` | yes | the operator message the run receives |
| `configurations` | yes | one entry per configuration, each naming its `overlay` tree or its package root |
| `overlay_committed` | no | when true, the overlay is committed as the starting state, so the run reads it as the repository's own and the grade carries only the run's work |
| `stop_classes` | no | the run outcomes that halt a `--cells` dispatch: `timeout`, `exit-nonzero`, `unattributed`, `escaped`; absent means no class stops it |
| `decision` | yes | `runs`, the planned run count; a graded case also carries `control`, the live configuration it compares against, an optional `aa` that names the control's repeat, and `rule`. A case with a `rule` is **graded**; a case without one is an **observation**. |
| `design` | graded | the experiment's stable fields: `method`, `primary_measure`, `valid_n`, `attrition`, and an optional `arms` naming its configurations |
| `checks` | graded | one entry per assertion the measure emits: `{id, role, known_bad}`, where `role` is `gate` or `discriminator` and `known_bad` is a fixture-relative directory |
| `observation` | observation | why the case is an observation rather than a graded experiment; a case with no `decision.rule` carries it and no `design` or `checks` |

A bare measure name is resolved beside the runner, so a case names a shipped process measure such as `measure_commit.sh` without a path; a content measure names a path relative to the case file, so it lives with its case. An ad-hoc run names its measure with `--measure` or `EVAL_MEASURE`; there is no default measure.

`design` and `checks` are declared together or not at all. `--check` proves each check by running the measure on the check's `known_bad` directory with a base count of zero, and rejects the case when the assertion passes there: a check the measure cannot fail is not a check. A check's `role` is `gate` when it must pass in every arm and `discriminator` when it is the outcome. The arms of a run are named by the `--cells` dispatch, so `design.arms` is only for a case whose arms are fixed.

## What a measure prints

One JSON object on stdout. [`measure_commit.sh`](../scripts/measure_commit.sh) prints the commit fields, [`measure_report.sh`](../scripts/measure_report.sh) the report fields and the check-in fields where a case ships its own measure:

| Field | Meaning |
|---|---|
| `committed` | whether a commit landed above the base |
| `one_commit`, `new_commits` | the delivery shape |
| `clean` | whether the tree was left clean |
| `subject_len`, `body_chars`, `prefix_ok`, `subject_len_ok`, `body_len_ok`, `no_path_list` | the per-rule reading |
| `rules_satisfied`, `rules_total` | the rule count the grade divides by |
| `assertions` | one object per graded rule: `{id, text, pass, evidence}`, so a cell names the assertion it failed |
| `report_present`, `report_lines`, `report_bytes` | the report-shaped alternative |
| `state_summary`, `inventory_table`, `inventory_rows`, `direction_form`, `asks_direction`, `record_defects_apart` | the check-in report's structural reading |

A measure that cannot read its subject prints the same keys with a null or a zero, so the benchmark never has to distinguish a missing measure from a failed one.

## What the benchmark carries

Per case: `correctness`, `consistency`, `correctness_sd`, `failed_assertions`, `invalid`, `invalid_rate`, `valid`, `elapsed_mean`, `wall_seconds`, `runs`, `runs_detail`. Each row of `runs_detail` carries the run number, its return code, whether it was valid, the model the session recorded, that run's stop class, and that run's measure object. A cell whose run is invalid stays in the table and is excluded from the means; `failed_assertions` names the ids that failed in its valid runs.

The analyst read is the benchmark's top-level `analysis` object, written by a `--cells` dispatch: `non_discriminating` names the assertion ids that passed in every valid run of every cell, `cells_without_spread` names the cells whose valid runs all scored the same, and `failed_assertions` maps a cell to the ids it failed. A rule that never fails cannot separate the configurations, and a cell with no spread across runs contributes no contrast, so the analysis is read before the decision.

A `--cells` dispatch adds a top-level `batch` object beside the flat per-cell rows: `stop` is `{class, cell, run}` or `null`, `cells_run` names the cells that launched, and `cells_remaining` names the cells a stop kept from launching. A run's `stop_class` is the first class it matches in the order `timeout`, `exit-nonzero`, `unattributed`, `escaped`, but only when the case declares that class; any other run records `null`.

## What the session measure prints

`measure_session.mjs` reads the run's transcripts and prints one JSON object. The aggregate fields answer A5 and A2:

| Field | Meaning |
|---|---|
| `sessions` | transcripts read |
| `turns` | assistant turns summed over them |
| `attributed` | whether any transcript was found |
| `tokens` | `input`, `output` and `total` sums |
| `wall_ms_transcript`, `wall_ms_sum_of_turns` | wall from the first and last timestamp, and the sum of the turns' durations |
| `files_opened` | distinct paths the run's tool calls named |
| `escapes` | paths outside the clone that resolve under the harness repository or a sibling cell |
| `stop_reasons`, `raw_stop_reasons` | the stop reasons seen |
| `tool_calls` | tool name to count |
| `invalid`, `invalid_reason` | whether the run is evidence (A2) |
| `turns_detail` | one object per assistant turn (A7) |

Each `turns_detail` object carries `turn`, `input_tokens`, `output_tokens`, `total_tokens`, `tool_calls` (name to count for that turn), and `paths`: an array of `{path, bytes}`. `path` is relative to the clone when inside it and absolute otherwise; `bytes` is the file's size, or `null` when the path is absent or not a file.

The object is written to `runs.jsonl` as the run's `session`, and to `case-<config>/run-<n>/session.json`.

## The layout of one run

Rendered from [`../assets/layout.json`](../assets/layout.json), which owns the names:

```text
<output-root>/
  case-<config>/run-<n>/     measure.json, prompt.txt, log, session, run.bundle, patch
  grade-raw/                 one file per run, before shuffling
  grade/case-<NN>.txt        shuffled, label-free
  grade-map.json             the only place the label is recorded
  measure-<config>.json      the benchmark row per configuration
```

`--out` names `<output-root>`; without one the run uses `outputRoot` and names the directory for the case's subject.

The work root holds `<n>/project`, the clone the run worked in. The root is a neutral `ws.XXXXXX` path that names no experiment, and the clone carries no `origin` pointing at the fixture. It is removed at exit unless `EVAL_KEEP_WORK` names it.
