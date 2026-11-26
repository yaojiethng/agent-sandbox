---
date: 2026-11-23
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - the review's defect and duplication findings are closed

## Objective

The thermonuclear review's defect-grade findings and unowned duplication are fixed, tested and removed, without taking on the record-API and catalogue-vocabulary redesigns that need their own iteration.

## Scope

The one-pass review at `.scratchpad/review/thermonuclear-branch-20261123/seat1-turn1.log`. Fixed: the vacuous read gate, the dead `GATE_FAILED` assignment, the stale liveness carriers, the unbalanced `yaml_unquote`, the source-text C3 assertion, the three unowned duplications (`sandbox_dir_canon` wrappers, the compose-label reader, the probe helpers), and a pre-existing convention-pointer failure the suite found. No roadmap row: these are defects in the current surface, not new work. The record-API collapse, the catalogue field vocabulary, the `time_format` scope and the `stop_probe.sh` decomposition stay open as design debts.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The read gate names the current API and passes only when the prelude reaches no parser or raw open. | `bash tests/test_env_read_discipline.sh` case `test_prelude_reaches_no_parser_or_open` | Agent [x] |
| The count line follows the mutation tier, so `GATE_FAILED` covers every gate that sets it. | `bash tests/test_runner_contract.sh`; `bash tests/test_runner_selftest.sh` | Agent [x] |
| The liveness gate's header and docs name four defects. | `grep -c DEFINED-AFTER-EPILOGUE` in the script and the docs page | Agent [x] |
| `yaml_unquote` removes only a matching surrounding pair. | `bash tests/test_common_lib.sh` case `test_yaml_unquote_requires_a_pair` | Agent [x] |
| C3 is carried by the behavioural dispatch test, not a source-string grep. | `tests/test_resolution_contract.sh` has no `forwarded+=` assertion; `cli_surface.md` C3 names the dispatch test | Agent [x] |
| The five canonicalize-or-exit copies use one helper. | `grep -RIn 'sandbox_dir_canon' scripts` names only the helper call sites; `test_common_lib.sh` covers success and exit | Agent [x] |
| The compose-label reader is one function in `common.sh`. | `record_label` is defined once; `test_session_inventory.sh` and `test_dry_run_record.sh` pass | Agent [x] |
| The probe helpers are one definition each in `common.sh`. | `json_array`, `join_commas`, `sha256_of` appear once; `test_build_probe.sh` and `test_stop_probe.sh` pass | Agent [x] |
| The suite and the gates pass. | `bash scripts/run_tests.sh` (1712), `bash scripts/lint.sh` (30 gates) | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `sandbox_dir_canon_assign VARIABLE DIR [MESSAGE]` sets the target through a nameref and exits on failure. | A function that prints a value cannot both exit the caller and be captured by `$(...)`; the nameref lets one helper replace five `if ! ... exit 1` copies without a subshell. | This table; `src/libs/common.sh` |
| The read gate asserts no parser or raw open, not no read. | The prelude legitimately consumes `env_record_view` and `record_get`; the old pattern named only retired functions, so it certified the opposite of the code. | This table; `tests/test_env_read_discipline.sh` |
| The count line follows the mutation tier. | `GATE_FAILED` is set by the mutation tier; a count line before that tier cannot report it. The verdict remains last. | This table; `scripts/run_tests.sh` |
| `record_label`, `json_array`, `join_commas` and `sha256_of` live in `common.sh`. | Both probes and both label readers already source `common.sh`; the copies were the second declaration the earlier consolidation should have removed. | This table; `src/libs/common.sh` |

## Decisions pending

None.

## Findings

| # | Finding | Triaged to |
|---|---|---|
| F1 | The suite's convention-pointer gate failed at HEAD: `workflow/coding-agent/skills/code-review/SKILL.md` carried a variant of the pointer sentence. | Applied here: the standard pointer is present, and `tests/test_convention_pointer.sh` passes. |

## Completed

| File | Change |
|---|---|
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | The prelude gate names the current API and the invariant it actually holds. |
| [`scripts/run_tests.sh`](../../../scripts/run_tests.sh) | The count line moves after the mutation tier. |
| [`scripts/check_test_liveness.sh`](../../../scripts/check_test_liveness.sh), [`docs/development/test_harness_mechanism.md`](../../../docs/development/test_harness_mechanism.md) | The fourth liveness check is named in both carriers. |
| [`src/libs/common.sh`](../../../src/libs/common.sh) | `yaml_unquote` requires a pair; `sandbox_dir_canon_assign`, `json_array`, `join_commas`, `sha256_of` and `record_label` added. |
| [`src/libs/session_inventory.sh`](../../../src/libs/session_inventory.sh), [`src/libs/dry_run_record.sh`](../../../src/libs/dry_run_record.sh) | The duplicated label reader is gone; both call `record_label`. |
| [`scripts/start_agent.sh`](../../../scripts/start_agent.sh), [`scripts/stop.sh`](../../../scripts/stop.sh), [`scripts/prune.sh`](../../../scripts/prune.sh), [`scripts/resume_agent.sh`](../../../scripts/resume_agent.sh), [`scripts/stop_probe.sh`](../../../scripts/stop_probe.sh) | The five canonicalize-or-exit copies use the helper. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh), [`scripts/build_probe.sh`](../../../scripts/build_probe.sh), [`scripts/stop_probe.sh`](../../../scripts/stop_probe.sh) | The duplicate `json_array`, `join_commas` and `sha256_of` are removed. |
| [`tests/test_common_lib.sh`](../../../tests/test_common_lib.sh) | Cases for the new helpers and the unquote pair rule. |
| [`tests/test_resolution_contract.sh`](../../../tests/test_resolution_contract.sh), [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | C3 is carried by the behavioural dispatch test. |
| [`workflow/coding-agent/skills/code-review/SKILL.md`](../../../workflow/coding-agent/skills/code-review/SKILL.md) | The standard convention pointer replaces the variant. |
