# Spec: apply_workspace Refactor

**Type:** Design spec — implementation ready  
**Status:** Approved for implementation  
**Scope:** `scripts/`, `libs/`, `tests/`, `agent-sandbox.sh`

---

## Problem

`scripts/apply_workspace.sh` is doing the work of three files:

- It owns the CLI entry point (flag parsing, validation)
- It contains the full `draft` command body (verify current line count before extraction)
- It contains the full `apply` command body (verify current line count before extraction)
- It duplicates session resolution logic across both commands with diverged implementations

Additionally, `agent-sandbox.sh` re-parses every flag it already parsed before delegating to `apply_workspace.sh`, meaning every new flag must be added in two places.

The test surface has the same problem: `test_apply.sh` and `test_apply_workspace.sh` both cover the draft/confirm/reject workflow with different fixtures and overlapping cases, and neither maps cleanly to a workflow boundary.

---

## Decisions

### 1. `scripts/apply_workspace.sh` is deleted

`agent-sandbox.sh` becomes the sole operator-facing entry point. It calls library functions directly — no subprocess delegation, no double flag-parse.

The Makefile targets that currently call `apply_workspace.sh` are updated to call `agent-sandbox` directly — `agent-sandbox` already accepts the same flags, so no interface change is required. Before deletion, grep the entire codebase for references to `apply_workspace.sh` and confirm every caller has been patched. Do not proceed to deletion until the grep returns no results outside the file itself.

### 2. Libs split into four files

| File | Owns |
|---|---|
| [`libs/session.sh`](#libssessionsh) | Session directory resolution — shared by both workflows |
| [`libs/draft_workflow.sh`](#libsdraft_workflowsh) | All draft branch logic: state helpers + `draft_run`, `confirm_run`, `reject_run` |
| [`libs/diff_workflow.sh`](#libsdiff_workflowsh) | `apply_run` |
| `libs/package_branch.sh` | Unchanged |
| `libs/package_diff.sh` | Unchanged |

The existing `libs/draft.sh` is absorbed into `libs/draft_workflow.sh` and deleted. Before absorbing, read `libs/draft.sh` to confirm the function list below matches what is currently in the file — the list was accurate at spec-writing time but may have changed.

### 3. Session resolver uses a string subpath arg, not a callback

```bash
# resolve_session_dir BASE_DIR SESSION_ARG REQUIRE_SUBPATH
# Prints resolved absolute path to stdout.
# Returns 1 with error message to stderr on failure.
#
# REQUIRE_SUBPATH: if non-empty, the resolved dir must contain this subpath.
#   draft uses: "session/patches"
#   apply uses: "" (directory existence is sufficient)
resolve_session_dir "$CHANGES_DIR" "$SESSION_ARG" "session/patches"
resolve_session_dir "$OUTPUT_DIR/diffs" "$SESSION_ARG" ""
```

No bash function-reference callbacks. The validation difference between the two workflows is expressed as a data argument.

### 4. Tests split by workflow, fixtures extracted

| File | Replaces | Covers |
|---|---|---|
| `tests/test_draft_workflow.sh` | `test_apply.sh` + draft/confirm/reject portion of `test_apply_workspace.sh` | `package_branch` → `draft_run` → `confirm_run`/`reject_run` pipeline |
| `tests/test_diff_workflow.sh` | apply portion of `test_apply_workspace.sh` | `package_diff` → `apply_run` pipeline |
| `tests/lib/git_fixtures.sh` | `make_project`, `make_committed_repo`, `make_sandbox` (verify names against current files at implementation time) | Git repo setup helpers |
| `tests/lib/session_fixtures.sh` | `make_export_with_diffs`, `make_diffs_session`, `make_changes_session` (verify names against current files at implementation time) | Workspace/session structure helpers |

`test_apply.sh` and `test_apply_workspace.sh` are deleted once coverage is confirmed in the new files.

`test_package_branch.sh` and `test_package_diff.sh` are updated to source `tests/lib/git_fixtures.sh` instead of defining their own repo setup helper. Verify that each file defines its own helper before removing it — do not remove a local definition that is still used within the same file.

---

## File Specifications

### `libs/session.sh`

Two public functions: `validate_project_dir` and `resolve_session_dir`.

**`validate_project_dir PROJECT_DIR`** — checks that `PROJECT_DIR` exists, is a git repository, and has at least one commit. Returns 1 with a descriptive error message on any failure. Called at the top of each `*_run` function in both workflow libs.

**`resolve_session_dir BASE_DIR SESSION_ARG REQUIRE_SUBPATH`**

**Behaviour:**

1. If `SESSION_ARG` is an absolute path — use it as-is; `BASE_DIR` is not required to exist.
2. If `SESSION_ARG` is a relative path — resolve under `BASE_DIR`; error if `BASE_DIR` does not exist.
3. If `SESSION_ARG` is empty — auto-resolve: find the lexicographically last directory under `BASE_DIR`; error if none found.
4. If `REQUIRE_SUBPATH` is non-empty — verify `<resolved>/<REQUIRE_SUBPATH>` exists; error if not.

**Error messages** must name the path that was tried and, for relative/auto cases, the base directory being searched.

**Auto-resolve for `draft`** is more specific than lexicographic-last — it needs the newest directory containing `session/patches/*.diff`, not just any directory. This is handled in `draft_workflow.sh` by calling `resolve_session_dir` with custom auto-resolve logic layered on top, or by passing the validated path after the caller does its own scan. The resolver handles the common path (absolute, relative, error messaging); the draft-specific scan remains in `draft_workflow.sh`.

### `libs/draft_workflow.sh`

Sources `libs/session.sh`.

Absorbs all functions from the current `libs/draft.sh`. At implementation time, read `libs/draft.sh` and use its actual function list — the list below was accurate at spec-writing time and is provided for orientation only:
- `draft_parse_folder_name`
- `draft_read_export_time`
- `draft_guard_no_collision`
- `draft_write_state`
- `draft_read_state_from_branch`
- `draft_validate_branch`

Public command functions:

**`draft_run PROJECT_DIR SANDBOX_DIR SESSION_ARG BRANCH_FROM_ARG DIFFS_ARG BRANCH_SUMMARY`**

Extracted from the `draft` block in `apply_workspace.sh`. Resolves session, applies patches, creates draft branch with `.draft-state` as first commit. Read the current `draft` block in `apply_workspace.sh` before implementing — verify the parameter list above covers all inputs the block currently uses, and adjust if any have been added or renamed since this spec was written.

**`confirm_run PROJECT_DIR SANDBOX_DIR TARGET_BRANCH`**

Extracted from the `confirm` block. Validates draft branch, drops `.draft-state` commit, rebases onto target, fast-forward merges, deletes draft branch. Read the current `confirm` block before implementing — verify the parameter list covers all inputs the block currently uses.

**`reject_run PROJECT_DIR SANDBOX_DIR`**

Extracted from the `reject` block. Validates draft branch, checks out source branch, deletes draft branch. Read the current `reject` block before implementing — verify the parameter list covers all inputs the block currently uses.

### `libs/diff_workflow.sh`

Sources `libs/session.sh`.

Public command function:

**`apply_run PROJECT_DIR SANDBOX_DIR SESSION_ARG DIFF_ARG APPLY_BRANCH FORCE`**

Extracted from the `apply` block in `apply_workspace.sh`. Resolves session, resolves `changes.diff` via flat → `session/` → `autosave/` fallback, optionally checks out branch, applies diff. Read the current `apply` block before implementing — verify the parameter list covers all inputs the block currently uses, and adjust if any have been added or renamed since this spec was written.

### `agent-sandbox.sh`

Sources `libs/draft_workflow.sh` and `libs/diff_workflow.sh` after the existing `libs/containers.sh` source line. Before editing, grep `agent-sandbox.sh` for all existing `source` calls to confirm insertion point and avoid duplicating any source that may have been added since this spec was written.

Flag parsing is unchanged — all flags are already parsed in `agent-sandbox.sh`. The `apply`, `draft`, `confirm`, `reject` case branches are replaced with direct calls to the `*_run` functions. Before replacing each branch, read the current branch body and confirm that all flags it passes to `apply_workspace.sh` are covered by the corresponding `*_run` parameter list. If any flag is missing from the parameter list, add it — the spec's parameter lists are the intended interface, not a guarantee of completeness.

`validate_project_dir` is called from within each `*_run` function in the workflow libs — no validation logic is needed in `agent-sandbox.sh` itself. Verify this is the case after implementing the workflow libs before removing any validation that may currently exist in the `agent-sandbox.sh` case branches.

---

## Implementation — Atomic Changes

Each change is independently reviewable and leaves the system in a working state. Changes build bottom-up: shared infrastructure first, workflow libs second, entry point switchover third, deletions last.

---

### Change 1 — Extract shared test fixtures

**Files:** `tests/lib/git_fixtures.sh` (new), `tests/lib/session_fixtures.sh` (new), `tests/test_package_branch.sh`, `tests/test_package_diff.sh`

Before writing the fixture files, grep all test files for local repo-setup and session-structure helper definitions to establish the complete set of functions to consolidate. The function names listed in Decision 4 were accurate at spec-writing time — treat them as a starting inventory, not a complete list.

Write `git_fixtures.sh` containing one canonical `make_committed_repo` function that covers the union of what all local variants do. If the local variants differ in behaviour, resolve the difference to the most general form that satisfies all callers, and note any intentional narrowing.

Write `session_fixtures.sh` containing the session-structure helpers. These are only used by workflow tests — `test_package_branch.sh` and `test_package_diff.sh` do not need to source it.

Update `test_package_branch.sh` and `test_package_diff.sh` to source `git_fixtures.sh` and remove their local repo-setup definitions. Run both test files after each edit — they must pass unchanged.

---

### Change 2 — Write `libs/session.sh` with tests

**Files:** `libs/session.sh` (new), `tests/test_session.sh` (new)

Implement `validate_project_dir` and `resolve_session_dir` per the File Specifications section. No changes to any existing lib or script.

`tests/test_session.sh` is a temporary test file — its cases will be absorbed into `test_draft_workflow.sh` and `test_diff_workflow.sh` in Changes 3 and 4. Write it as a self-contained test file that passes on its own. Required cases:

- `validate_project_dir`: directory does not exist; directory exists but is not a git repo; git repo with no commits; git repo with at least one commit.
- `resolve_session_dir`: absolute path used as-is; relative path resolved under base; auto-resolve selects lexicographically last directory; `REQUIRE_SUBPATH` present and satisfied; `REQUIRE_SUBPATH` present and not satisfied; base directory does not exist when SESSION_ARG is relative; base directory does not exist when SESSION_ARG is empty; resolved directory does not exist.

---

### Change 3 — Write `libs/draft_workflow.sh` with tests

**Files:** `libs/draft_workflow.sh` (new), `tests/test_draft_workflow.sh` (new)

Read `libs/draft.sh` and the `draft`, `confirm`, and `reject` blocks in `apply_workspace.sh` before writing any code. Use the actual current content as the source of truth — the spec describes the intended structure, but the implementation must match what the code actually does today, not what the spec assumed it does.

Port all functions from `libs/draft.sh` into `draft_workflow.sh`. Implement `draft_run`, `confirm_run`, and `reject_run` as functions wrapping the extracted block logic. `apply_workspace.sh` and `libs/draft.sh` are not modified in this change.

`tests/test_draft_workflow.sh` sources `tests/lib/git_fixtures.sh` and `tests/lib/session_fixtures.sh`. It covers the full `package_branch → draft_run → confirm_run/reject_run` pipeline. Before finalising, read `test_apply.sh` and the draft/confirm/reject portion of `test_apply_workspace.sh` and produce a coverage map: for each test case in those files, confirm it is covered in `test_draft_workflow.sh` — either directly or by a case that supersedes it. Explicitly note any cases that are deliberately dropped and why. The coverage map does not need to be committed, but the agent must be able to state that no case was accidentally omitted.

This change also absorbs the `resolve_session_dir` and `validate_project_dir` cases from `tests/test_session.sh` that are exercised end-to-end through the draft workflow. Those cases remain in `test_session.sh` until Change 7 — they are not removed here.

---

### Change 4 — Write `libs/diff_workflow.sh` with tests

**Files:** `libs/diff_workflow.sh` (new), `tests/test_diff_workflow.sh` (new)

Read the `apply` block in `apply_workspace.sh` before writing any code. Use the actual current content as the source of truth. `apply_workspace.sh` is not modified in this change.

`tests/test_diff_workflow.sh` sources `tests/lib/git_fixtures.sh` and `tests/lib/session_fixtures.sh`. It covers the full `package_diff → apply_run` pipeline. Before finalising, read the apply portion of `test_apply_workspace.sh` and produce a coverage map using the same standard as Change 3: every case either covered or explicitly noted as deliberately dropped.

This change also absorbs the `resolve_session_dir` and `validate_project_dir` cases from `tests/test_session.sh` that are exercised end-to-end through the apply workflow. Those cases remain in `test_session.sh` until Change 7 — they are not removed here.

---

### Change 5 — Switch `agent-sandbox.sh` to call workflow libs directly

**Files:** `agent-sandbox.sh`

Read the current `agent-sandbox.sh` before editing — specifically the `source` calls at the top and the `apply`, `draft`, `confirm`, `reject` case branches. Confirm that every flag each branch currently passes to `apply_workspace.sh` is present in the corresponding `*_run` parameter list. Resolve any gap before proceeding.

Add source calls for `libs/draft_workflow.sh` and `libs/diff_workflow.sh` after the existing `libs/containers.sh` source. Replace each case branch with a direct call to the corresponding `*_run` function. Do not change flag parsing.

`apply_workspace.sh` still exists at the end of this change and must remain functional — it is the rollback path if the new routing has a defect. Manual end-to-end verification of each subcommand (`draft`, `confirm`, `reject`, `apply`) is required before this change is considered complete. Do not proceed to Change 6 until verification passes.

---

### Change 6 — Patch remaining callers, update Makefile

**Files:** `Makefile`, any other files referencing `apply_workspace.sh`

Run `grep -rn "apply_workspace" .` from the repo root and record every result. For each caller found:

- If it is the Makefile: update the target to call `agent-sandbox` with the equivalent flags. Read the current target body before replacing it — do not assume the flags match what was in `apply_workspace.sh` at spec-writing time.
- If it is a script, runbook, or CI file: update it to call `agent-sandbox` with equivalent flags, or flag it to the operator if the change is non-trivial.
- If it is `apply_workspace.sh` itself (self-references in comments or sourcing): leave it — these will be deleted in Change 7.

After patching, re-run the grep. The only remaining results must be within `apply_workspace.sh` itself. Do not proceed to Change 7 until this condition holds.

---

### Change 7 — Delete old code

**Files:** `scripts/apply_workspace.sh` (deleted), `libs/draft.sh` (deleted), `tests/test_apply.sh` (deleted), `tests/test_apply_workspace.sh` (deleted), `tests/test_session.sh` (deleted)

Before deleting each file, confirm the precondition:

- `scripts/apply_workspace.sh`: grep confirms zero references outside itself (Change 6 postcondition). The full test suite passes without it.
- `libs/draft.sh`: grep confirms it is not sourced by any remaining file. All its functions are present in `libs/draft_workflow.sh`.
- `tests/test_apply.sh` and `tests/test_apply_workspace.sh`: the coverage map from Changes 3 and 4 confirms every case is either covered in the new workflow tests or explicitly noted as deliberately dropped.
- `tests/test_session.sh`: all cases it covered are exercised end-to-end through `test_draft_workflow.sh` and `test_diff_workflow.sh`. Confirm this by reading `test_session.sh` and tracing each case to its equivalent in the workflow tests.

Delete files one at a time. Run the full test suite after each deletion. A deletion that causes a test failure must be investigated before proceeding — do not batch-delete and then debug.
