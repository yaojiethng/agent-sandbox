---

date: 2026-10-10
milestone: M3.4.1 - Configuration and Persisted Record Formats
type: Implementation
status: Closed
---

# Handover - Implementation: one KV read/write pair behind every key=value record

## Objective

Land the M3.4 contract: one `kv_read` with one `kv_write` plus a multi-key `kv_load` behind every key=value record the harness persists, with a gate that fails when a second parser appears.

## Scope

New `src/libs/kv_record.sh` carries the pair and the load, with the record format stated once: one `KEY=VALUE` pair per line, the value everything after the first `=`, the first line for a key winning, a missing file or key reading empty. Four consumers migrated in the same wave, per the migrate-then-delete rule: `session_state_read`/`session_state_write` (`src/libs/session_state.sh`), `export_status_read` (`src/libs/export_status.sh`), `dry_run_record_value` (`src/libs/dry_run_record.sh`), and `session_log_read` (`src/libs/session_inventory.sh`). The test-side `kv()` helper in `tests/test_dry_run_probe.sh` now calls `kv_read` rather than its own `awk -F=`, so assertions read records through the shipped contract too. `tests/test_kv_record.sh` carries the behaviour units, the delegation checks, and a tree scan that fails when any file under `src/` or `scripts/` parses a record by another path.

The migration fixes one live defect on the way: `dry_run_record_value` truncated a value at its second `=` (`awk -F= '{print $2}'`), and `session_log_read` matched its key as an unescaped regex, so a key carrying a `.` could match a neighbouring line -- the contradiction its own docstring carried. Both shapes are pinned by new units.

The reviewer dispatch on the first version of this unit returned three corrections, all verified and applied: `dry_run_record_verify` still hand-parsed the same record inside the file the commit opened to migrate (and its layer check passed on any value that was not literally `FAIL`, including a missing layer line -- a vacuous path the trace fixture never caught because the stub `docker` wrote two-line records); `kv_load`'s whole-record form was a raw `cat`, disagreeing with the keyed form on CRLF and stray lines; and `kv_read`'s second parse inverted to a silent miss for a key containing `=`. The tree scan widened to the `${line%%=*}` family and caught a third `.env` parser, in `scripts/onboard.sh`, which now reads through `env_file_value`. The stub `docker` writes the documented record shape, so the trace exercises per-layer verification for the first time. The first version of the strict layer check also failed five trace tests, which is how the vacuous path surfaced; the stub's record shape, not the check, was the defect.

Not migrated, and now their own rows: the `.draft-state` reader and writer (the reader parses a git-show string, not a file), and the session log's upsert writer (`kv_write` appends; an upsert is a different operation).

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The value is the full tail after the first `=`, first line wins, missing file or key reads empty | `bash tests/test_kv_record.sh` | accepted: 9 passed, 0 failed |
| `kv_write` creates and appends; a missing parent directory fails loudly | the same file | accepted |
| `kv_load` answers the whole record and named keys in one call | the same file | accepted |
| No second record parser exists in the tree | the scan unit | accepted: 0 hits outside kv_record.sh |
| The migrated consumers behave | `bash tests/test_dry_run_probe.sh`, `bash tests/test_session_env.sh`, `bash tests/test_session_state.sh`, `bash tests/test_export_status.sh`, `bash tests/test_session_inventory.sh` | accepted: all pass |
| The whole suite is green | `bash scripts/run_tests.sh` | accepted: 1066 passed, 0 failed |
| Gates clean | `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh`, `bash scripts/lint.sh` | accepted: 0 warnings, 0 findings, clean |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/kv_record.sh`](../../src/libs/kv_record.sh) | new: the one reader/writer pair and the multi-key load |
| [`src/libs/session_state.sh`](../../src/libs/session_state.sh) | the SESSION_STATE reader and writer delegate to the pair |
| [`src/libs/export_status.sh`](../../src/libs/export_status.sh) | the export-status reader delegates to `kv_read` |
| [`src/libs/dry_run_record.sh`](../../src/libs/dry_run_record.sh) | the dry-run record reader delegates to `kv_read` |
| [`src/libs/session_inventory.sh`](../../src/libs/session_inventory.sh) | the session-log reader delegates to `kv_read` |
| [`tests/test_kv_record.sh`](../../tests/test_kv_record.sh) | new: behaviour units, delegation checks, the parser tree scan |
| [`tests/test_dry_run_probe.sh`](../../tests/test_dry_run_probe.sh) | the `kv()` assertion helper reads through the shipped contract |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `kv_read` returns the full tail, not the second field | three of the four hand-rolled readers already had full-tail semantics; the `awk` reader was the outlier and truncated a legal value | this handover |
| The tree scan covers `src/` and `scripts/`, not `tests/` | test fixtures deliberately embed parser idioms (the lib-contract gate's own fixtures use `IFS='=' read`); the production tree is where a second parser would ship | this handover |
| Leave the identity re-assert in place and reword the milestone criterion | a load-before-resolve order lets the `.env` promote its own `AGENT_SANDBOX_*` lines into the environment level and defeat the two-level guard; the three-line re-assert is the minimal correct implementation of flag-wins | this handover, and the roadmap criterion amendment |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The identity triple cannot be asserted once without inverting precedence: the prelude re-asserts the triple after the bulk load precisely because a load-before-resolve order would let the file's own `AGENT_SANDBOX_*` lines beat its file-level keys. The assertion shape is a design question with two options and their consequences, written back as an M3.4 row. [A] 2026-10-10 | contradiction | roadmap |
| The capability image must be rebuilt before its probes and diff pipeline consume `kv_record.sh`: the lib ships through the `src/libs/` COPY, and the baked `/opt/sandbox/lib` predates this commit. [A] 2026-10-10 | obstacle | next iteration |
| The `.draft-state` pair and the session-log upsert writer remain on hand-rolled paths; both are written back as M3.4 rows with their blockers named. [A] 2026-10-10 | scope change | roadmap |
| The dry-run trace fixture wrote two-line records, so per-layer verification had never run green or red in the trace suite; an absent layer line passed as "not FAIL". The stub now writes the documented shape and a unit pins the strict check. [A] 2026-10-10 | bug | current iteration |
| The reviewer's own glob claim (`layerXYZ` matching `layer.*`) was verified false -- the pattern requires the literal `layer.` prefix -- while its lax-value and contract-bypass claims were verified true and fixed. Recorded so the correction is not propagated unchecked. [A] 2026-10-10 | bug | current iteration |
| The keyed `kv_load` re-opened the file once per key, measured 1,246ms against 388ms for a single tail read on a 50,000-line record. The first single-pass rewrite then measured 8.4s for 50 early keys, because the inner loop kept testing seen keys on every line. The shipped form exits when the last named key resolves: 18ms for 50 early keys, 1.3s for three tail keys, which is the floor for one bash line traversal of that record. Practical records run about ten lines, so the numbers bound the shape rather than a hot path. No migrated reader ever did one file read per line; that class is the `.draft-state` reader, which the follow-on row carries. [A] 2026-10-10 | bug | current iteration |

## Completed

| File | Change |
|---|---|
| [`src/libs/kv_record.sh`](../../src/libs/kv_record.sh) | new: `kv_read`, `kv_write`, `kv_load`, with the record format stated once |
| [`src/libs/session_state.sh`](../../src/libs/session_state.sh) | reader and writer delegate to the pair |
| [`src/libs/export_status.sh`](../../src/libs/export_status.sh) | reader delegates to `kv_read` |
| [`src/libs/dry_run_record.sh`](../../src/libs/dry_run_record.sh) | reader delegates to `kv_read`; the second-field truncation is gone; verify reads each layer through the pair with a strict PASS check |
| [`src/libs/session_inventory.sh`](../../src/libs/session_inventory.sh) | session-log reader delegates to `kv_read`; the key is matched literally |
| [`src/libs/env_resolve.sh`](../../src/libs/env_resolve.sh) | `env_file_value`, the public face of the one `.env` read |
| [`scripts/onboard.sh`](../../scripts/onboard.sh) | the refresh-mode `PROJECT_DIR` read moves off its grep-and-cut pipeline onto `env_file_value` |
| [`tests/stubs/docker`](../../tests/stubs/docker) | writes the documented record shape, so the trace exercises per-layer verification |
| [`tests/test_kv_record.sh`](../../tests/test_kv_record.sh) | new: behaviour units, delegation checks, the parser tree scan |
| [`tests/test_dry_run_probe.sh`](../../tests/test_dry_run_probe.sh) | the `kv()` helper reads through the shipped contract |
| [`devlog/roadmap.md`](../../devlog/roadmap.md) | M3.4 criterion 2 reworded to the achievable form; three follow-on rows filed |

[CORRECTION -- 2026-10-10: the milestone was retitled. This handover was filed under M3.4 - Configuration and Persisted Record Formats, which became M3.4 - Environment and Argument Resolution with the record work re-attributed to M3.4.1. The unit, its scope and its verdict are unchanged; only the milestone it answers to moved.]
