---
date: 2026-11-09
milestone: M3.3.5
type: Implementation
status: Closed
---

# Handover - A stopped `--cells` dispatch names its class and its remaining cells

## Objective

Implement R7 of the eval harness contract: a `--cells` dispatch records a declared stop class and names the cells that ran and the cells that remain.

## Scope

The M3.3.5 row **A stopped run names its remaining cells**, the first of the two harness rows the `/gm` calibration row depends on; the assertion-record row and then the calibration follow. A `--cells` dispatch today reports valid and invalid runs but records no stop, so a truncated batch reads as a smaller one. The iteration adds the case's `stop_classes` declaration, the runner's halt on a matching class, and the benchmark's `batch` record. It also updates R7's edge-case line in the contract, which still states that no implementation holds the requirement.

The scope proposal owns the file list; this record carries none.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| A stopped `--cells` dispatch halts and its benchmark carries the class and the cells run and remaining. | `test_pool_stops_and_names_the_remaining_cells` | Agent [x] |
| A batch with no stop carries `batch.stop: null`, every cell in `cells_run`, none remaining. | `test_pool_dispatches_cells_under_the_cap` | Agent [x] |
| `--check` accepts the declared vocabulary and rejects an unknown or repeated class. | `test_run_case_check_rejects_an_unknown_stop_class` and the accepts test | Agent [x] |
| The `gm-focus-milestone` case declares its stop classes and passes `--check`. | `run_case.sh --check=tests/eval/cases/gm-focus-milestone.json` prints `case ok` | Agent [x] |
| The harness reference and the contract describe the implemented stop record. | `harness.md` names `stop_classes` and `batch`; R7's line in the ADR states the implemented behaviour | Agent [x] |
| Every decision this iteration records is realized in the files. | the Decisions table against the diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The stop-class vocabulary is fixed (`timeout`, `exit-nonzero`, `unattributed`, `escaped`) and the case lists which classes stop its dispatch | the runner observes these signals already; a per-case expression language would add machinery the contract does not need, and `--check` can validate a closed list | this record; `harness.md` |
| A run with no report is a recorded run outcome, not a stop class | it is evidence the calibration reads, not a truncated batch; stopping on it would discard the distribution the A/A measures | this record; `run_case.sh` |
| A stop halts scheduling, lets running cells finish, and records the cells that started and the cells that did not | a stop must not discard a cell already in flight, and the split is what makes a truncated batch legible | this record; `run_case.sh` |
| The benchmark gains a top-level `batch` object; the per-cell results stay flat | a stopped batch stays readable by the existing per-cell consumers | this record; `harness.md` |
| The benchmark and case-schema change is documented in the harness reference, with no separate design document | the reference already owns the `harness` block and the benchmark shape; the change is a field addition, not a decision between live options | this record; `harness.md` |
| R7's edge-case line in the contract is updated to the implemented state | the "no implementation holds yet" sentence is stale once this lands | `docs/adr/eval_harness_contract.md` |

## Decisions pending

None.

## Findings

None.

## Completed

| File | One-line change summary |
|---|---|
| `.agents/skills/evals/scripts/run_case.sh` | `--check` validates `stop_classes`; the pool classifies each run's outcome, halts on a declared class, and writes the `batch` record; `runs_detail` carries `stop_class`. |
| `tests/eval/cases/gm-focus-milestone.json` | Declares the four stop classes. |
| `tests/test_eval_harness.sh` | Adds the stop-halt, no-stop, unknown-class and declared-class tests; 39 pass. |
| `.agents/skills/evals/references/harness.md` | Documents the `stop_classes` field and the `batch` record. |
| `docs/adr/eval_harness_contract.md` | Moves R7's edge-case line from "no implementation holds yet" to the implemented state. |
| `devlog/roadmap.md` | Marks the row `[x]` and records the outcome. |
| `devlog/handovers/M3.3.5/20261109-06-impl-stopped_run.md` | This record. |
