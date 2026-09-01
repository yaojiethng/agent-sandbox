# Agent Handover

**Date:** 2026-08-01
**Milestone:** M2.6.5 — Copy Model: Volume-backed Sandbox
**Type:** Implementation — Unified export path convention and single autosave
**Status:** Closed

## Pre-close verification

Test results:

- `tests/test_routing.sh` — 27/27 passed
- `tests/test_diff_dispatch.sh` — 16/16 passed
- `grep -rn session_export_path\|output_export_path` — 0 stale references (1 comment-line only)
- `bash -n` — 9/9 shell scripts pass

AC summary:

| # | Criterion | Status |
|---|---|---|
| 1 | `export_path` replaces both old functions; RUN_ID mandatory, LABEL optional | Accepted |
| 2 | Session export writes to `session/<EXPORT_TIME>-<RUN_ID>/` | Accepted |
| 3 | Autosave writes to `autosave/<RUN_ID>/` and overwrites each cycle | Accepted |
| 4 | `EXPORT-TIME.txt` inside autosave dir updates each cycle | Accepted |
| 5 | Package branch writes to `bundles/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | Accepted |
| 6 | Package diff writes to `diffs/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | Accepted |
| 7 | `make draft` and `make apply` still resolve sessions correctly | Accepted |
| 8 | No remaining references to old function names | Accepted |
| 9 | All shell scripts pass `bash -n` | Accepted |

## Objective

Unify the two divergent path-naming conventions (`session_export_path` / `output_export_path`) into one function anchored on `EXPORT_TIME`, simplify autosave to a single overwritten directory per session, and make RUN_ID mandatory across all paths.

## Scope

Three units:

1. **Merge path functions** — Replace `session_export_path` and `output_export_path` with a single `export_path` function. Convention: `PARENT_DIR/SUBDIR/<EXPORT_TIME>[-LABEL]-RUN_ID/`. RUN_ID mandatory, LABEL optional. EXPORT_TIME is `date -u` at invocation.

2. **Single autosave** — Overwrite `autosave/<RUN_ID>/` each cycle instead of timestamped accumulation. `rm -rf` before each write. Simplifies the autosave loop and eliminates unbounded growth within a session.

3. **Update call sites** — session export (`_session_export`), autosave loop, `package_branch.sh`, `package_diff.sh`, channel resolvers, interactive picker, draft/apply resolvers.

## Design

### Path convention

```
<PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<RUN_ID>/
<PARENT_DIR>/<SUBDIR>/<EXPORT_TIME>-<LABEL>-<RUN_ID>/
```

| Mechanism | Path | EXPORT_TIME | LABEL |
|---|---|---|---|
| Session export | `session/<EXPORT_TIME>-<RUN_ID>/` | `date -u` | — |
| Autosave | `autosave/<RUN_ID>/` | via `EXPORT-TIME.txt` | — |
| Package branch | `bundles/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | `date -u` | user summary |
| Package diff | `diffs/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | `date -u` | user summary |

Autosave is the exception: no EXPORT_TIME in the directory name because it's overwritten each cycle. `EXPORT-TIME.txt` inside records the write time.

### export_path function

```
export_path PARENT_DIR SUBDIR RUN_ID [LABEL]
```

- RUN_ID is mandatory (no backward compat)
- LABEL is optional — when present, inserted as `-LABEL-` before RUN_ID
- EXPORT_TIME is always `date -u` at call time
- Creates parent directories with `mkdir -p`

### Autosave loop change

Before writing, `rm -rf autosave/<RUN_ID>`. Then write to that directory. No timestamp in path.

### Channel resolver impacts

- `resolve_channel_base_dir` — no change (still maps channel names to base dirs)
- `resolve_source_for_draft` — no change (resolves session dirs by listing)
- `resolve_diff_for_apply` — no change
- `resolve_latest_dir` — still works with new naming (sorted by timestamp prefix)
- Interactive picker — no change (lists directories under channel base)

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Verified by |
|---|---|---|---|
| 1 | `export_path` replaces both old functions; RUN_ID mandatory, LABEL optional | `bash tests/test_routing.sh` | Agent ✅ |
| 2 | Session export writes to `session/<EXPORT_TIME>-<RUN_ID>/` | `bash tests/test_diff_dispatch.sh` | Agent ✅ |
| 3 | Autosave writes to `autosave/<RUN_ID>/` and overwrites each cycle | `bash tests/test_diff_dispatch.sh` | Agent ✅ |
| 4 | `EXPORT-TIME.txt` inside autosave dir updates each cycle | `bash tests/test_diff_dispatch.sh` | Agent ✅ |
| 5 | Package branch writes to `bundles/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | Manual | Operator |
| 6 | Package diff writes to `diffs/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | Manual | Operator |
| 7 | `make draft` and `make apply` still resolve sessions correctly | Resolvers unchanged — covered by existing resolver tests | Operator |
| 8 | No remaining references to `session_export_path` or `output_export_path` | `grep -rn` across repo | Agent ✅ |
| 9 | All shell scripts pass `bash -n` | `bash -n` on every changed .sh file | Agent ✅ |

## Hot files

| File | Why in scope |
|---|---|
| [`src/libs/routing.sh`](../../src/libs/routing.sh) | Replace two path functions with unified `export_path` |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | Session export + autosave loop call sites |
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Call site for export path |
| [`src/libs/package_diff.sh`](../../src/libs/package_diff.sh) | Call site for export path |
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) | Dry-run path construction check |
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | Updated tests for export_path |
| [`tests/test_diff_dispatch.sh`](../../tests/test_diff_dispatch.sh) | Updated tests for new path convention |
| [`tests/knowledge/diagnose_autosave.sh`](../../tests/knowledge/diagnose_autosave.sh) | Updated autosave path construction |
| [`tests/knowledge/knowledge_diff_export_container.sh`](../../tests/knowledge/knowledge_diff_export_container.sh) | Updated exit trap simulation |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Updated path documentation and autosave section |

## Decisions made this session

None.

## Mid-session findings

None.

## Completed this session

| File | Change |
|---|---|
| [`src/libs/routing.sh`](../../src/libs/routing.sh) | Merged `session_export_path` + `output_export_path` into unified `export_path`; RUN_ID mandatory, LABEL optional, autosave special-case (no EXPORT_TIME) |
| [`src/capability/entrypoint.sh`](../../src/capability/entrypoint.sh) | `_session_export` uses `export_path`; autosave loop overwrites single `autosave/<RUN_ID>/` dir |
| [`src/libs/package_branch.sh`](../../src/libs/package_branch.sh) | Uses `export_path` with optional LABEL |
| [`src/libs/package_diff.sh`](../../src/libs/package_diff.sh) | Uses `export_path` with RUN_ID required; skips default "snapshot" LABEL |
| [`scripts/dry_run_capability.sh`](../../scripts/dry_run_capability.sh) | Updated path construction check to `export_path` |
| [`tests/test_routing.sh`](../../tests/test_routing.sh) | Rewrote tests for `export_path` signature (session, autosave, bundles, diffs, missing args) |
| [`tests/test_diff_dispatch.sh`](../../tests/test_diff_dispatch.sh) | Updated all dispatch tests for new `export_path` convention |
| [`tests/knowledge/diagnose_autosave.sh`](../../tests/knowledge/diagnose_autosave.sh) | Updated autosave path construction |
| [`tests/knowledge/knowledge_diff_export_container.sh`](../../tests/knowledge/knowledge_diff_export_container.sh) | Updated exit trap simulation and all call sites |
| [`docs/architecture/sandbox_lifecycle.md`](../../docs/architecture/sandbox_lifecycle.md) | Updated join phase and autosave documentation |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.6.6 — Mount Model: Host-backed Sandbox

**Conclusions from this session:** TBD
