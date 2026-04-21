# Agent Handover

**Session date:** 2026-04-21
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation (bug fix)
**Status:** Closed

## Objective

Fix permission-denied errors in `snapshot_init_git` when the harness runs inside a container where `TMPDIR` resolves to `/opt/provider-config/`. The `mktemp -d` call created an intermediate directory under the restricted path, and `cp -a` then failed trying to copy git objects (which have mode 0555) into that directory.

## Problem

When the agent container runs, `mktemp -d` in `snapshot_init_git` creates an archive extraction directory under `$TMPDIR`. Inside the container, `/opt/provider-config/` (the provider config bind-mount) is writable and can become the default temp directory location. The two-part pattern —

1. `ARCHIVE_TMP=$(mktemp -d)` — creates `/opt/provider-config/tmp.XXX`
2. `tar -x -C "$ARCHIVE_TMP" < baseline.tar && cp -a "$ARCHIVE_TMP/." "$SANDBOX_DIR/"` — copies extracted files with `-a` (archive mode, preserving permissions)

— fails because:
- Git creates loose objects with mode 0555 (read-only). `cp -a` preserves these permissions, and the intermediate directory is under a path where subsequent writes are restricted.
- The `EXCLUDE_TMPFILE=$(mktemp)` in `snapshot_copy_worktree` has the same problem: it lands under the wrong directory.

The visible symptom is a flood of `cp: cannot create regular file '/opt/provider-config/./tmp.XXXX/.../.git/objects/...': Permission denied` errors during `snapshot_init_git`.

## Scope

Single file change to `libs/snapshot.sh`. No other files are in scope.

## Acceptance criteria

- [x] `snapshot_init_git` no longer uses an intermediate `mktemp -d` directory for archive extraction
- [x] `snapshot_copy_worktree` exclude tempfile always uses `/tmp/` regardless of `TMPDIR`
- [x] All existing test suites pass: `test_snapshot_container.sh` (28), `test_snapshot_host.sh` (20), `test_diff.sh` (39)

## Changes

| File | Change |
|---|---|
| `libs/snapshot.sh` | `EXCLUDE_TMPFILE=$(mktemp)` → `mktemp /tmp/snapshot-exclude.XXXXXX` — explicit `/tmp` prefix avoids `TMPDIR` pollution |
| `libs/snapshot.sh` | Replaced `mktemp -d` + `tar -x -C "$ARCHIVE_TMP"` + `cp -a "$ARCHIVE_TMP/." "$SANDBOX_DIR/"` + `rm -rf "$ARCHIVE_TMP"` with `tar -x -C "$SANDBOX_DIR" < baseline.tar` — direct extraction eliminates the intermediate directory and the `cp -a` that preserved read-only permissions. Since `baseline.tar` is produced by `git archive HEAD` and contains only working tree files (no `.git/`), extraction directly into the sandbox is safe and simpler. |

### Why direct extraction is safe

`baseline.tar` is produced by `git archive HEAD`, which outputs only the committed working tree — no `.git/` directory, no loose objects. At extraction time, `git init` has already run in the sandbox, creating an empty `.git/` skeleton. Extracting the tar directly on top of this skeleton is identical in effect to the previous two-step copy: the tar's working tree files land in the sandbox, and the `.git/` directory is untouched because the archive doesn't contain `.git/` entries.

### What the fix does not address

The test scripts also use bare `mktemp -d` for `FIXTURE_DIR` (e.g., `test_snapshot_container.sh` line 34). These can theoretically create temp dirs under `/opt/provider-config/` too, but that is a test-environment concern, not a production code concern. The production fix (explicit `/tmp` prefix in library code) is complete. Test scripts could be hardened independently if needed.

## Carried forward

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Implement Change 6 (baseline advancement / `SYNC=1`).

**Files to upload:**
- This handover
- `scripts/apply_workspace.sh` (updated — draft branch naming, confirm cleanup, session-ts extraction)
- `scripts/start_agent.sh` (updated — SESSION_TS rename, BRANCH_NAME variable)
- `scripts/checkpoint.sh` (sourced by advancement script)
- `docs/discussions/design_apply_workflow_and_baseline_advancement.md` for Change 6 design reference
- Prior impl handover `20260421-04-impl-apply_and_package_diff_fixes.md` for immediate prior context