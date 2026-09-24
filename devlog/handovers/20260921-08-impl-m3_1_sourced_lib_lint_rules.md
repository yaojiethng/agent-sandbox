# Agent Handover

**Date:** 2026-09-21
**Milestone:** M3.1 - Backpressure
**Type:** Implementation
**Status:** Closed

## Objective

Add a lint gate enforcing the sourced-library conventions: library functions `return`, never `exit`, and sourced-lib reads do not redirect from unguarded paths.

## Scope

- New gate `scripts/check_lib_contract.sh` wired into `scripts/lint.sh`, scanning `src/libs/` and `src/build/`.
- Rule 1 (convention 3.1): an `exit` command inside a function body is a finding. Top-level `exit` in an exec-guard main flow is allowed.
- Rule 2 (convention 4.4): a `done < "$VAR"` redirect in a sourced lib is a finding unless the enclosing function guards the read (`[[ -f "$VAR" ]]`) before it.
- Fix the two current-tree violations so the gate opens with zero findings: `parse_help_flag` in `src/libs/common.sh` (exit 0 in a function) and `env_load` in `src/libs/env.sh` (unguarded read).
- Tests: new `tests/test_lib_contract.sh` with a scan-root seam (`LIB_CONTRACT_SCAN_ROOT`), covering the exit rule, the guard exemption, the read rule, the guarded-read pass, and a real-tree zero-findings regression guard.
- Update `scripts/lint.sh` and the Makefile gate description; roadmap write-back at close.

**Deferred:** the `[O]` library return-not-exit feedback entry is surfaced at the M3.1 pre-close review, not edited here.

**Questions:** None - the `parse_help_flag` contract refactor is behavior-preserving (help -> usage + exit 0 from the caller, other invocations unchanged) and visible in the pre-close for review.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `check_lib_contract.sh` exits 0 on the current tree | `bash scripts/check_lib_contract.sh` | Agent [x] -- clean after the two fixes; pins `test_real_tree_is_clean` |
| 2 | A fixture lib with a function-level `exit` fails the gate and names the file and line | `bash tests/test_lib_contract.sh` | Agent [x] -- `test_function_exit_fails` names `bad.sh:4` |
| 3 | A fixture lib with a top-level `exit` inside a `BASH_SOURCE[0] == "$0"` guard passes | `bash tests/test_lib_contract.sh` | Agent [x] -- `test_exec_guard_exit_passes` |
| 4 | An unguarded `done < "$VAR"` read fails the gate; a guarded read passes | `bash tests/test_lib_contract.sh` | Agent [x] -- `test_unguarded_read_fails` and `test_guarded_read_passes` |
| 5 | `lint.sh` includes the new gate (a contract finding fails `make lint`) | `bash scripts/lint.sh` on a fixture violation | Agent [x] -- fixture violation -> umbrella rc 1, gate named |
| 6 | `start_agent.sh --help` still prints usage and exits 0 after the `parse_help_flag` refactor | `bash scripts/start_agent.sh --help` | Agent [x] -- rc 0, usage printed; no-flag path unchanged |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/check_lib_contract.sh`](scripts/check_lib_contract.sh) | new gate: exit rule + read rule |
| [`scripts/lint.sh`](scripts/lint.sh) | umbrella gains the lib-contract gate |
| [`src/libs/common.sh`](src/libs/common.sh) | `parse_help_flag` function-level `exit 0` |
| [`src/libs/env.sh`](src/libs/env.sh) | `env_load` unguarded `done < "$FILE"` |
| [`scripts/start_agent.sh`](scripts/start_agent.sh) | help path owns the exit after the refactor |
| [`tests/test_lib_contract.sh`](tests/test_lib_contract.sh) | fixture tests + real-tree guard |
| [`Makefile`](Makefile) | lint target description names the gate |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The gate flags `exit` only inside function bodies; exec-guard main flow may exit | convention 3.1 governs functions in sourced libs; `package_branch.sh`'s main block is legitimate entrypoint logic | `scripts/check_lib_contract.sh` header |
| The read rule flags `done < "$VAR"` without an in-function `-f` guard for the same variable | convention 4.4 prescribes the `[[ -f ]]` + `return 0` guard pattern | `scripts/check_lib_contract.sh` header |
| Fix `parse_help_flag` by returning a status the caller turns into an exit | keeps the helper's help-termination contract while removing the function-level `exit` | this handover; `src/libs/common.sh` |

## Findings

None.

## Completed

| File | Change | Status |
|---|---|---|
| `devlog/handovers/20260921-08-impl-m3_1_sourced_lib_lint_rules.md` | opened and closed this handover | done |
| `scripts/check_lib_contract.sh` | new gate: rule 3.1 exit-in-function, rule 4.4 guarded-read, scan-root seam | done |
| `scripts/lint.sh` | umbrella runs the lib-contract gate between shell and markdown | done |
| `scripts/start_agent.sh` | help path owns the exit via `if parse_help_flag; then exit 0; fi` | done |
| `src/libs/common.sh` | `parse_help_flag` returns 0 on help; header comment updated | done |
| `src/libs/env.sh` | `env_load` guards the read with a `[[ -f ]]` test | done |
| `tests/test_lib_contract.sh` | 8 tests, 14 assertions incl. the real-tree guard | done |
| `Makefile` | lint target description names the third gate | done |

## Deferred items

None.

## What's Next

M3.1 - Backpressure.

Next iteration (`20260921-09`): the lint-and-tests-duration study (`devlog/discussions/20260921-study-active-lint_and_tests_duration.md`) - measure the 30s `scripts/lint.sh` run, confirm the staged-file hook scope, present approaches; no fix without operator input.

Watch-outs: (1) the pre-commit hook from iteration `20260921-07` now gates staged shell files - a lint-speed fix that touches `check_shell.sh` affects both the gate and the hook; (2) the study must time `check_shell.sh`, `check_markdown.sh`, and the new `check_lib_contract.sh` separately.
