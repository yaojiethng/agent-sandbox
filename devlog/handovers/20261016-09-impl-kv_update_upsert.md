---
date: 2026-10-16
milestone: M3.4.2 - The resolution model and record primitives
type: Implementation
status: Closed
---

# Handover - one upsert primitive behind the session log

## Objective

Give the key-value records one upsert, so the session log's writer stops carrying its own read-modify-write path. `kv_write` appends, and an upsert is a different operation, which is why this pair is a third entry point rather than a mode of the second.

## Scope

Harvested from the parked draft branch's squash `3dbc5dda`. In: `src/libs/kv_record.sh` gains `kv_update FILE KEY VALUE`; `src/libs/session_inventory.sh`'s `session_log_set` becomes three lines that create the directory and delegate, replacing a `grep` probe plus a `sed` rewrite with four substitution escapes and a sibling temp file. New here, because the branch carried none: three units in `tests/test_kv_record.sh` covering the replace arm, the append arm, the duplicate-key collapse, and the missing-parent contract.

Out: the `.draft-state` reader and writer, which is unit R5.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The primitive replaces in place and appends, with one line per key | `bash tests/test_kv_record.sh` | 14 passed, 0 failed |
| The session log's writer still behaves | `bash tests/test_session_log.sh` | 10 passed, 0 failed |
| Every reader of the log is unaffected | `bash tests/test_session_inventory.sh`, `bash tests/test_resume_list.sh` | 23 passed and 16 passed |
| The teardown and start paths that write the log are unaffected | `bash tests/test_run_agent.sh` | 41 passed, 0 failed |
| The whole suite is green | `bash scripts/run_tests.sh` | 1168 passed, 1 failed; the failure is the pre-existing `test_model_refresh_node_suite`, a T12 row |
| Gates clean | `bash scripts/lint.sh`, `bash scripts/check_shell.sh`, `bash scripts/check_lib_contract.sh` | clean across 9 gates; 0 warnings across 175 files; 0 findings across 24 files |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| `kv_update` drops a later duplicate of the key rather than leaving it | the read rule is first-line-wins, so a duplicate is already invisible; dropping it makes the upsert converge on one line instead of accumulating | `src/libs/kv_record.sh` |
| The temp file is `<file>.tmp.$$` in the record's own directory | `mv` within one directory is the atomic replace, and the pid keeps two writers apart | `src/libs/kv_record.sh` |
| The missing-parent directory stays a caller error | `kv_write` already carries that contract, and `session_log_set` creates the directory before the call, so the failure names a caller that skipped its own step | `src/libs/kv_record.sh` |
| The three units land with this change rather than in a later test sweep | the branch carried the primitive with no coverage at all, for either arm | `tests/test_kv_record.sh` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `kv_update` has no test on the parked branch, for either the replace or the append arm, and its missing-parent branch is unexercised. Measured: `grep -c kv_update` on the branch's `tests/test_kv_record.sh` is zero. | gap, measured | covered here | covered in this unit |
| The replaced path rewrote the record through `sed -i` on a sibling temp file, with four escapes to keep `&`, `\` and the delimiter literal. The primitive needs none of them, because it splits on the first `=` and re-emits with `printf`. | simplification, measured | removed | this unit |
| Two concurrent `session_log_set` calls can still lose one update, because the primitive is read-modify-write. The property is unchanged from the replaced path, and the record's writers are the start and teardown paths of one session. | observation, inferred | none; recorded so a later reader does not read the new primitive as synchronised | recorded here |

## Completed

| File | Change |
|---|---|
| `src/libs/kv_record.sh` | `kv_update FILE KEY VALUE`, with the header's function list updated |
| `src/libs/session_inventory.sh` | `session_log_set` creates the directory and delegates to `kv_update`; the `grep`-and-`sed` path is gone |
| `tests/test_kv_record.sh` | three units: replace and append, duplicate collapse, missing parent |
