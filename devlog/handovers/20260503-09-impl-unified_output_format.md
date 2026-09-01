# Agent Handover

**Date:** 2026-05-03
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Type:** Implementation
**Status:** Closed

## Objective

Restructure all diff packaging around a single unified output format: rewrite `package_branch.sh` as a dispatcher, add `write_uncommitted_diff` / `write_all_changes_diff` / `write_changed_files` helpers, rewrite `diff_on_exit` / `diff_on_autosave` as thin wrappers, and eliminate the sweep commit and `BASELINE_SHA` parameter.

## Scope

Targets A.1 from the roadmap (`docs/devlog/roadmap.md`  A.1). This is the largest entry in the A.x sequence.

**In scope:**
- `libs/diff.sh` — remove `diff_commit_pending`, `diff_generate`, `diff_format_patch`; add `write_uncommitted_diff`, `write_all_changes_diff`; rewrite `diff_on_exit` / `diff_on_autosave` as thin dispatchers calling `package_branch`; drop `BASELINE_SHA` param, read `init_sha` from `SESSION_STATE`
- `libs/package_branch.sh` — extract `package_commits` from old `package_branch`; rewrite `package_branch` as dispatcher (commits + uncommitted + all-changes + changed-files); preserve the existing `BASH_SOURCE` main guard; source `diff.sh` at top level
- `libs/package_diff.sh` — rename `changes.diff` → `uncommitted.diff`; remove `--baseline` flag and `resolve_baseline` function; use `git diff HEAD` as canonical; call `write_changed_files` instead of inline copy logic; **add `BASH_SOURCE` main guard** (currently missing)
- `libs/sandbox-entrypoint.sh` — remove `BASELINE_SHA` variable; update `diff_on_exit` / `diff_on_autosave` calls to 3-arg signature
- `tests/test_diff.sh` — remove `diff_commit_pending` tests; add tests for new helpers; rename `changes.diff` → `uncommitted.diff`, `staged.diff` → `all-changes.diff`; add `SESSION_STATE` setup; add end-to-end `diff_on_exit` non-empty test
- `tests/test_package_branch.sh` — update for dispatcher pattern; add `write_changed_files` tests
- `tests/test_package_diff.sh` — update for `uncommitted.diff` rename and shared helper

**Explicitly deferred:**
- A.2 (CLI contract: `--channel`, routers) — depends on A.1 output format
- A.4 (changed-files extraction) — folded into A.1's scope (helper lives in `diff.sh`)
- A.3 (documentation alignment) — depends on A.1, A.2, A.4
- Any CLI or Makefile changes

## Carried forward

None.

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0
2. `package_branch` writes `patches/*.diff`, `uncommitted.diff`, `all-changes.diff`, and `changed-files/` to output directory
3. `diff_on_exit` produces `session/uncommitted.diff`, `session/all-changes.diff`, `session/patches/*.diff`, `session/changed-files/` — no `session/changes.diff`, no `session/staged.diff`, no sweep commit
4. `diff_on_autosave` produces `autosave/uncommitted.diff`, `autosave/patches/*.diff` — no `autosave/changes.diff`
5. `diff_on_exit` produces **non-empty output** for a session with changes (end-to-end test)
6. `package_diff.sh` writes `uncommitted.diff` (not `changes.diff`) and `changed-files/`
7. `sandbox-entrypoint.sh` has no `BASELINE_SHA` variable or reference to it
8. `write_changed_files` helper exists in `libs/diff.sh` and is called from both `package_branch` and `package_diff.sh`
9. `package_diff.sh` has a `BASH_SOURCE` main guard (sourceable); `package_branch.sh` retains its existing guard
10. Architecture documents in scope describe the system as built. (Design doc `design_change_a_contract.md` will be referenced; no architecture docs updated in this entry.)

## Hot files

| File | Why in scope |
|---|---|
| [`libs/diff.sh`](../../libs/diff.sh) | New helpers; remove old functions; thin dispatchers |
| [`libs/package_branch.sh`](../../libs/package_branch.sh) | Dispatcher rewrite with `package_commits` extraction |
| [`libs/package_diff.sh`](../../libs/package_diff.sh) | Rename `changes.diff` → `uncommitted.diff`; add main guard |
| [`libs/sandbox-entrypoint.sh`](../../libs/sandbox-entrypoint.sh) | Drop `BASELINE_SHA` variable; update call signatures |
| [`tests/test_diff.sh`](../../tests/test_diff.sh) | New tests; rename assertions |
| [`tests/test_package_branch.sh`](../../tests/test_package_branch.sh) | Dispatcher tests |
| [`tests/test_package_diff.sh`](../../tests/test_package_diff.sh) | `uncommitted.diff` tests |

## Decisions made this session

None.

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `diff_on_exit` and `diff_on_autosave` are nearly identical — both build a subfolder path and call `package_branch`. Unify into a single `diff_export(SANDBOX_DIR, OUTPUT_DIR)` where path construction moves to callers (`sandbox-entrypoint.sh`). Reduces test surface; aligns with A.2's path-resolution focus. | scope change | A.2 — CLI contract; `libs/diff.sh` and `libs/sandbox-entrypoint.sh` updated together

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | Removed `diff_commit_pending`, `diff_generate`, `diff_format_patch`; renamed `diff_write_changes_diff` → `write_uncommitted_diff`; added `write_all_changes_diff`, `write_changed_files`; rewrote `diff_on_exit`/`diff_on_autosave` as thin 4-arg dispatchers calling `package_branch` |
| `libs/package_branch.sh` | Extracted `package_commits`; rewrote `package_branch` as dispatcher orchestrating all 4 helpers; preserved `BASH_SOURCE` main guard |
| `libs/package_diff.sh` | Simplified to `git diff HEAD` only; renamed `changes.diff` → `uncommitted.diff`; uses `write_changed_files` shared helper; added `BASH_SOURCE` main guard; removed `--baseline` flag and inline copy logic |
| `libs/sandbox-entrypoint.sh` | Removed `BASELINE_SHA` variable and redundant SESSION_STATE writes; updated `diff_on_exit`/`diff_on_autosave` calls to 4-arg signature |
| `tests/test_diff_helpers.sh` | Created — 18 tests for `write_uncommitted_diff`, `write_all_changes_diff`, `write_changed_files`; added `set -uo pipefail`, `FIXTURE_DIR`+trap |
| `tests/test_diff_dispatch.sh` | Created — 22 tests for `diff_on_exit` and `diff_on_autosave` (rewritten for new signature); added `set -uo pipefail`, `FIXTURE_DIR`+trap |
| `tests/test_package_branch.sh` | Rewritten — 18 tests for dispatcher pattern; added `set -uo pipefail`, `FIXTURE_DIR`+trap |
| `tests/test_package_diff.sh` | Rewritten — 14 tests for simplified API; added `set -uo pipefail`, `FIXTURE_DIR`+trap |
| `tests/test_diff.sh` | **Deleted** — replaced by `test_diff_helpers.sh` + `test_diff_dispatch.sh` |
| `tests/knowledge/knowledge_binary_diff_apply.sh` | Updated header comment — `package_diff.sh` no longer uses selective strip (uses `write_uncommitted_diff` which strips all index lines); `package_commits` in `package_branch.sh` still uses selective strip |

## Deferred items

None.

## Next session

**A.2 — CLI contract: `--channel` flag and routing** (or **A.4 — `changed-files/` extraction** — these can run in parallel after A.1)

**Type:** Implementation

**Objective:** Add `--channel` flag, router functions, new `apply_run`/`draft_run` signatures, Makefile flag mappings.

**A.2 design reference:** `docs/devlog/discussions/design_change_a_contract.md`  4.
**A.2 roadmap:** `docs/devlog/roadmap.md`  A.2.

**Expanded A.2 scope (from mid-session finding):** Unify `diff_on_exit` and `diff_on_autosave` into a single `diff_export(SANDBOX_DIR, OUTPUT_DIR)` function. Path construction (subfolder, `EXPORT-TIME.txt`) moves to callers (`sandbox-entrypoint.sh`). Reduces test surface; aligns with A.2's path-resolution focus. Hot files expanded to include `libs/diff.sh`, `libs/sandbox-entrypoint.sh`, `tests/test_diff_dispatch.sh`.

**A.4 status:** Complete — `write_changed_files` was folded into A.1 and is live in `libs/diff.sh`. Both `package_branch.sh` and `package_diff.sh` already call it. A.4 roadmap entry marked (complete).

**Hot files (A.2):** `scripts/agent-sandbox.sh`, `libs/diff.sh`, `libs/diff_workflow.sh`, `libs/draft_workflow.sh`, `libs/_templates/Makefile.template`, `libs/session.sh`, `scripts/onboard.sh`, `libs/sandbox-entrypoint.sh`, `libs/dirs.sh`, `tests/test_diff_dispatch.sh`, `tests/test_diff_workflow.sh`, `tests/test_draft_workflow.sh`

**Context:** A.1 is complete. A.4 is complete (folded into A.1). Remaining: A.2 (expanded) and A.3.
