# Agent Handover

**Date:** 2026-08-12
**Milestone:** M2.6 — Session Persistence (general CLI/infra track)
**Type:** Investigation

## Objective

Audit the diff pipeline end-to-end for git rename handling. Determine whether
renames survive the full cycle: `git format-patch`/`diff` → export → `git apply`/`am`.

Mid-session finding from previous session (20260812-01): our prior convention
reorganization used create+delete instead of `git mv` because rename-handling
durability is unverified.

## Scope

- Trace `package_branch.sh`'s per-commit diff generation
- Trace `diff_export.sh`'s patch packaging
- Trace `draft.sh`'s patch application (`git apply`)
- Identify what flags are used (`--find-renames`? `-M`? `git am` vs `git apply`?)
- Determine if renames produce unambiguous diffs that apply cleanly
- Determine if rename+content-edit produces correct diffs that apply cleanly

## Files in scope

| File | Role |
|---|---|
| `src/libs/package_branch.sh` | Generates per-commit diffs |
| `src/libs/diff.sh` | Diff primitives |
| `src/libs/diff_export.sh` | Export pipeline, calls package_branch |
| `scripts/workflows/draft.sh` | Applies patches to branch |
| `scripts/workflows/apply.sh` | Applies uncommitted diff |
| `src/capability/entrypoint.sh` | Capability layer diff pipeline |

## Deferred

(none yet)

## Completed this session

- [x] Traced full diff pipeline: `git diff` → `git apply` rename handling
- [x] Confirmed `git apply` handles renames in all three cases (pure, small-edit, big-edit)
- [x] Identified pre-existing bug: `package_branch` passed `INIT_SHA` as 3rd arg to `package_commits`, which reads arg 3 as `NO_RENAMES` — `--no-renames` was silently broken
- [x] Fixed `package_branch.sh` line 288: removed `$INIT_SHA` from `package_commits` call
- [x] Hardened `diff_export.sh`: now passes `"true"` to `package_branch` by default
- [x] 15-case knowledge test: pure rename, rename+edit, big edit, `--no-renames`, destination conflict, binary, multi-file, cross-directory, `package_branch` with/without flag, `diff_export` integration
- [x] Full test suite: 470 passed, 0 failed

## Decisions

- **`diff_export` defaults to `--no-renames` (safe).** Produces delete+create
  diffs instead of rename operations. Renames are handled correctly by
  `git apply` in most cases but fail hard when destination already exists.
  `--no-renames` transforms hard failures into content conflicts, which are
  safer to resolve. Manual `agent-sandbox package-branch` (without
  `--no-renames`) remains available for rename detection when desired.

## Mid-session findings

- **String "true" for boolean NO_RENAMES is non-idiomatic bash.** Conventional
  approach: `[[ -n "$NO_RENAMES" ]]` (any non-empty = on), or `--flag` style.
  The `"true"` string comparison is the existing convention in
  `package_branch.sh` (line 131). Consistent but worth standardising across
  all boolean flags in a future sweep. Not scoped for this session.
