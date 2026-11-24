---
date: 2026-11-24
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - close the thermonuclear review's findings

## Objective

Fix the confirmed findings from the one-pass thermonuclear review of the four M3.4.2 head commits (69133b2c..13d8b983), so the branch's defects are repaired and its stale carriers are gone.

## Scope

The four M3.4.2 commits only. The review log is `.scratchpad/review/thermonuclear-branch-20261124/seat1-turn1.log`.

In scope: the empty-`--sandbox` regression and its missing tests; `resolve_and_validate` sourcing; the timestamp convention -- one owner for date/time formatting, a UTC date-window helper for prune, and a structural gate that forbids date display formats outside the owner; the false-green JSON test; the stale path and flag carriers; the timestamp ADR's overbroad scope; the three small code-judo simplifications the review named; and the incorrect mutation command in the closed catalogue handover. The 730 predecessor commits, the residual-risk items the review listed, and any new milestone work are out of scope. The roadmap check found no open M3.4.2 row and no maintenance write: M3.4.2 stays In progress until its own close.

Code defects are fixed by TDD: the test that states the positive case is written and shown failing before the fix, then shown passing after it. Propagation and documentation defects are corrected directly. Every finding was reproduced before this handover: the empty sandbox writes into the CWD, the sourced onboard function fails with `path_abs: command not found`, the variable-literal timestamp fixture is invisible to the scan, and the broken-vocabulary JSON pipeline passes the current test.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| An empty path is rejected by `path_abs`, and direct onboarding with `--sandbox=` exits non-zero without writing into the CWD. | `bash tests/test_common_lib.sh`, case `test_path_abs_rejects_empty`; `bash tests/test_onboard.sh`, case `test_onboard_rejects_empty_sandbox`; both red before the fix | Agent [x] |
| `resolve_and_validate` is callable after sourcing `onboard.sh` alone. | `bash tests/test_onboard.sh`, case `test_resolve_and_validate_available_when_sourced`; red before the fix | Agent [x] |
| The timestamp convention has one owner: `time_format.sh` provides the UTC date-window helper, prune calls it, and no `date` display format remains outside the owner. | `bash tests/test_time_format.sh`, case `test_date_days_ago_is_utc`; `bash tests/test_prune.sh`; `rg -n 'date[^#]*\+' src scripts --glob '*.sh'` shows only the owner and epoch calls | Agent [x] |
| The timestamp gate rejects any `date` display format outside the owner, allows `date +%s`, and catches a variable-held or unenumerated format. | `bash tests/test_time_format.sh`, cases `test_the_scan_bites_a_variable_literal`, `test_the_scan_bites_a_non_harness_stamp`, and `test_the_scan_allows_epoch_calls`; red before the structural gate | Agent [x] |
| The JSON vocabulary test asserts CLI success and valid JSON before deriving, so broken vocabulary fails it. | `bash tests/test_agent_cli_dispatch.sh`; the broken-vocabulary probe now fails rather than returning an empty pass | Agent [x] |
| The old `_env_abs_path` name appears only in the historical 2026-11-23 line beside its dated correction; the current path name, the old selector and the old `realpath` wording are gone. | `rg -n -e '_env_abs_path' -e 'name dir sandbox' -e 'resolved to absolute via realpath' docs/adr/cli_surface.md scripts/agent-sandbox.sh scripts/onboard.sh src/libs/common.sh`; lines 82-84 read together | Agent [x] |
| The timestamp claim covers only stamps the harness chooses; observed `stat` metadata is named out of scope. | `rg -n -e 'harness chooses' -e 'observed file mtime' docs/adr/time_format.md src/libs/time_format.sh`; both files read against the diff | Agent [x] |
| `_ENV_RECORD_LOADED` is gone and record reads still cost one parse. | `rg -n '_ENV_RECORD_LOADED' src` prints nothing; `bash tests/test_env.sh` and `bash tests/test_env_read_discipline.sh` | Agent [x] |
| The unknown-field catalogue error has one owner. | `rg -c 'declares unknown identity field' scripts/agent-sandbox.sh` prints 1; `bash tests/test_resolution_contract.sh`; dispatcher mutation subject 15/15 | Agent [x] |
| The `env_parse` counting wrapper has one home. | `rg -n 'declare -f env_parse' tests` names only `tests/libs/env_parse_counter.sh`; both counter suites pass | Agent [x] |
| The closed catalogue handover no longer cites the `MUTATIONS_STRICT=1` command. | `rg -n 'MUTATIONS_STRICT' devlog/handovers/M3.4/20261124-02-impl-catalogue_field_vocabulary.md` prints nothing; the replacement command is read against the diff | Agent [x] |
| Every decision this iteration records is realized in the files. | the `## Decisions` table read against the delivery diff | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| An empty path is rejected in both layers: `path_abs` fails on empty, and `resolve_and_validate` names the empty flag before calling it. | A library function cannot both construct a path and decide the caller's error policy; the caller needs the flag name, and the library needs to stop treating an empty string as the CWD. | This table; `src/libs/common.sh`, `scripts/onboard.sh` |
| The timestamp invariant covers the stamps the harness chooses. Observed file metadata, such as a `stat` mtime, is not a harness stamp and gets no format exception. | The harness does not choose the mtime, and the gate correctly requires a `date` producer. Scoping the rule states what the code does instead of widening the gate to platform metadata. | This table; `docs/adr/time_format.md` entry 2026-11-24; `src/libs/time_format.sh` |
| The timestamp convention is one owner and one call shape: `time_format.sh` is the only file that calls `date` with a display format, and every other producer uses its helpers or `date +%s`. The prune date window moves into the owner. | A gate that recognizes formats is still a list; forbidding the `date` call is the structural rule. The prune cutoff was the last carrier and was also on the local clock. | This table; `src/libs/time_format.sh`, `scripts/prune.sh`, `tests/test_time_format.sh` |
| The review's small code-judo items are fixed here because they are inside the four-commit surface and existing tests hold them. | `_ENV_RECORD_LOADED` is a third cache state; the catalogue error has three homes; the test wrapper has two. Each removal is local and behaviour-preserving, so filing it would leave avoidable complexity in the reviewed delta. | This table; `src/libs/env.sh`, `scripts/agent-sandbox.sh`, `tests/libs/env_parse_counter.sh` |
| The JSON test asserts the CLI status and JSON validity before deriving the vocabulary. | The old pipeline passed on an empty string when the CLI had already failed. The test's precondition is part of its claim, and a parse failure must be red. | This table; `tests/test_agent_cli_dispatch.sh` |
| The closed catalogue handover is corrected in place as a claim-record correction, with no marker. | The command was factually wrong when written, and a closed claim record is corrected in place under the project's closed-record rule. | This table; `docs/adr/closed_record_corrections.md`; `devlog/handovers/M3.4/20261124-02-impl-catalogue_field_vocabulary.md` |

## Decisions pending

None.

## Findings

| # | Finding | Impact | Triaged to |
|---|---|---|---|
| F1 | An empty `--sandbox` is anchored to the CWD, and direct onboard writes `.env`, `Makefile` and `.workspace/` there. | A silent, destructive write into the invocation directory. | This iteration |
| F2 | `resolve_and_validate` calls `path_abs` before `onboard.sh` sources the path library, so a shell that sources the script alone cannot call it. | The function's direct-call contract is broken. | This iteration |
| F3 | The timestamp gate requires `date` on the same line, so a producer that stores the format in a variable is invisible. | A second definition can be reintroduced without a red gate. | This iteration |
| F4 | `test_json_rows_carry_one_flag_per_identity_field` discards the CLI status and jq failure, so broken vocabulary passes as an empty result. | The test is a false green. | This iteration |
| F5 | The deleted `_env_abs_path`, the old `dir` selector and the old `realpath` wording remain in comments, usage and the CLI ADR. | Readers are sent to names the tree no longer carries. | This iteration |
| F6 | The timestamp ADR says every timestamp is the harness format, but `stop_probe.sh` writes observed file mtimes from `stat`. | The contract is broader than the gate and the code. | This iteration |
| F7 | `_ENV_RECORD_LOADED` is a third cache state that adds no distinction over `_ENV_RECORD_FILE`. | A redundant global and condition in the record primitive. | This iteration |
| F8 | The unknown-field catalogue error is repeated in the validator and both consumers. | One message has three homes. | This iteration |
| F9 | The `env_parse` counting wrapper is duplicated in two test files. | Test-only duplication and a fragile `declare -f` incantation in two places. | This iteration |
| F10 | The closed catalogue handover cites a mutation command with `MUTATIONS_STRICT=1`, which exits 1 on unrelated survivors even though the dispatcher subject is 15/15. | A reader reruns a command that cannot pass as written. | This iteration |
| F11 | `prune.sh` computed its age cutoff with a local-clock `date` format, the last date format outside the timestamp owner. | The cutoff can disagree with UTC session stamps near a day boundary, and the convention had no structural rule. | This iteration |

## Completed

| File | Change |
|---|---|
| [`src/libs/common.sh`](../../../src/libs/common.sh) | `path_abs` now rejects an empty path; the API header lists `path_canon`, `path_abs` and `sandbox_dir_canon`. |
| [`scripts/onboard.sh`](../../../scripts/onboard.sh) | Rejects an empty path flag, sources the path library at module scope, and names `path_abs` in the usage text. |
| [`tests/test_common_lib.sh`](../../../tests/test_common_lib.sh) | New `test_path_abs_rejects_empty`; red with rc 0 and `<cwd>/`, green after the guard. |
| [`tests/test_onboard.sh`](../../../tests/test_onboard.sh) | New empty-`--sandbox` direct test and sourced-function test; red with a CWD write and `path_abs: command not found`, green after the fixes. |
| [`tests/test_time_format.sh`](../../../tests/test_time_format.sh) | Date-format gate fixtures: variable, slash, date-only, and epoch-allowed; red before the structural gate, green after. |
| [`tests/test_agent_cli_dispatch.sh`](../../../tests/test_agent_cli_dispatch.sh) | The JSON test asserts CLI status and valid JSON before deriving; the broken-vocabulary probe now fails it. |
| [`src/libs/env.sh`](../../../src/libs/env.sh) | `_ENV_RECORD_LOADED` retired; `_ENV_RECORD_FILE` alone distinguishes the cached file. |
| [`scripts/agent-sandbox.sh`](../../../scripts/agent-sandbox.sh) | `catalog_require` owns the unknown-field error; the validator and both consumers call it. The `project` selector comment is corrected. |
| [`tests/libs/env_parse_counter.sh`](../../../tests/libs/env_parse_counter.sh) | New shared counter wrapper for the parser. |
| [`tests/test_env.sh`](../../../tests/test_env.sh) | Uses the shared counter helper. |
| [`tests/test_env_read_discipline.sh`](../../../tests/test_env_read_discipline.sh) | Uses the shared counter helper. |
| [`docs/adr/cli_surface.md`](../../../docs/adr/cli_surface.md) | Dated corrections name `path_abs` and `CLI_FIELDS`/`flags` beside the historical lines. |
| [`docs/adr/time_format.md`](../../../docs/adr/time_format.md) | The rule covers chosen stamps and names the one-owner display-format convention; observed `stat` mtime is out of scope. |
| [`src/libs/time_format.sh`](../../../src/libs/time_format.sh) | Owns `ts_date_days_ago` and states the one-owner convention. |
| [`scripts/prune.sh`](../../../scripts/prune.sh) | The age cutoff calls `ts_date_days_ago` instead of formatting a local-clock date. |
| [`tests/test_prune.sh`](../../../tests/test_prune.sh) | Uses `ts_date_days_ago 0` for fixture dates; the failing-date stub catches the helper's `-d` call. |
| [`scripts/install.sh`](../../../scripts/install.sh) | The GNU-date hint names `time_format.sh`, the helper's owner. |
| [`20261124-02-impl-catalogue_field_vocabulary.md`](20261124-02-impl-catalogue_field_vocabulary.md) | The mutation command no longer forces strict mode; it names `required findings: 0`. |
