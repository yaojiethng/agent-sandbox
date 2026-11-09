---
date: 2026-10-16
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one KV read/write pair behind every key=value record

## Objective

Land one `kv_read`, one `kv_write` and a multi-key `kv_load` behind every key=value record the harness persists, with a scan that fails when a second parser appears, so the record format is stated once. This is the record-format unit the M3.4.2 decision authorises.

## Scope

Ported from the parked draft branch, commit `726c6110`. In: `src/libs/kv_record.sh` and the four consumers (`session_state.sh`, `export_status.sh`, `dry_run_record.sh`, `session_inventory.sh`), `env_resolve.sh`'s `env_file_value`, `onboard.sh`'s refresh read, the stub `docker`, and the tests. Out: the `.draft-state` pair and the session-log upsert writer, which need their own decisions and rows; and the branch's `devlog/roadmap.md` change, which the current roadmap has superseded.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The value is the full tail after the first `=`, the first line wins, a missing file or key reads empty | `bash tests/test_kv_record.sh` | 11 passed, 0 failed |
| `kv_write` creates and appends; a missing parent directory fails loudly | the same file | 11 passed, 0 failed |
| `kv_load` answers the whole record and named keys in one call | the same file | 11 passed, 0 failed |
| The migrated consumers behave | `test_dry_run_record` 11, `test_dry_run_probe` 22, `test_session_state` 4, `test_export_status` 9 | all pass |
| The whole suite is green | `bash scripts/run_tests.sh` | 1157 passed, 1 failed; the one failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh` | clean across 9 gates |
| The port differs from the source commit only in the three recorded ways | `diff` of each ported file against `git show 726c6110:<path>` | eight files differ by zero lines; `kv_record.sh` by six, and the two dry-run tests by one each |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The port takes the source commit file for file, with three recorded deviations: it drops the commit's two record files, it retargets `docs/architecture/` to `docs/reference/` in two tests, and it sweeps the arithmetic array subscripts in `kv_record.sh` | every line differing from the source needs a reason a reader can check, and these three are the complete set | this handover |
| The branch's `docs/architecture/tool_interface.md` path is retargeted to `docs/reference/tool_interface.md` | the documentation tree moved; the old path does not exist on this tree | this handover |
| The ported files already carry the branch's own review corrections | the vacuous layer check, the CRLF disagreement in `kv_load`'s whole-record form, the `=`-bearing key, and the third `.env` parser in `onboard.sh` are fixed in the ported content, so the port carries one variable, not two | this handover |
| The KV pair is the one record primitive, and no record becomes structured in M3.4.2 | a parser is a dependency the harness then carries; JSON waits until a record demonstrably needs it | `devlog/roadmap.md` M3.4.2 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The delegated worker deviated from the source commit on one line, `assert_file_exists "$(kv "$state" record)"` to a hard-coded path, with no stated reason. Measured: the state's `record` key holds exactly that hard-coded string, because the test's own `_run_probe` writes `record=$rec` with `rec="${OUTPUT_DIR}/dryrun.<probe>.record"`, and the source line passes on this tree, 22 of 22. The deviation costs no coverage. [CORRECTION -- 2026-10-16] the entry first read "weakened one assertion", which claimed a check the worker's line did not drop; the correction is attribution, not safety. | defect, measured | reverted; the ported assertion stands | reverted in this unit |
| The capability image must be rebuilt before its probes and diff pipeline consume `kv_record.sh`: the lib ships through the `src/libs/` COPY, and the baked `/opt/sandbox/lib` predates this unit. | obstacle, inherited | the next iteration | the next iteration |
| The `.draft-state` reader and writer, and the session-log upsert writer, stay on hand-rolled paths; `kv_write` appends, and an upsert is a different operation. | scope change, inherited | their own M3.4.2 rows | their own M3.4.2 rows |
| The `opencode-dispatch` skill cannot run in this container: it sources `src/libs/dispatch.sh`, which does not exist, and the `opencode` CLI is absent. The free-tier offload runs through pi, pinned to `opencode-go/cat-jam-free` at `high`. | defect, measured | the offload path is pi | the offload path is pi |

## Completed

| File | Change |
|---|---|
| `src/libs/kv_record.sh` | new: `kv_read`, `kv_write`, `kv_load`, with the record format stated once; the arithmetic array subscripts carry no `$`, so ShellCheck is clean at `-S style` |
| `src/libs/session_state.sh` | the reader and writer delegate to the pair |
| `src/libs/export_status.sh` | the reader delegates to `kv_read` |
| `src/libs/dry_run_record.sh` | the reader delegates to `kv_read`; the second-field truncation is gone; verify reads each layer through the pair with a strict PASS check |
| `src/libs/session_inventory.sh` | the session-log reader delegates to `kv_read`; the key matches literally |
| `src/libs/env_resolve.sh` | `env_file_value`, the public face of the one `.env` read |
| `scripts/onboard.sh` | the refresh-mode `PROJECT_DIR` read moves off its grep-and-cut pipeline onto `env_file_value` |
| `tests/stubs/docker` | writes the documented record shape, so the trace exercises per-layer verification |
| `tests/test_kv_record.sh` | new: behaviour units, delegation checks, the parser tree scan |
| `tests/test_dry_run_record.sh` | new: the record reader's units |
| `tests/test_dry_run_probe.sh` | the `kv()` helper reads through the shipped contract |
| `devlog/AGENT_FEEDBACK.md` | the entry "A deviation from a ported source is not a regression" |
| `devlog/handovers/20261016-03-impl-kv_record_pair.md` | this record |
