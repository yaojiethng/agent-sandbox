# Agent Handover

**Session date:** 2026-04-29
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed
**Session end:** 2026-04-29
**Tests:** 237 passed, 0 failed, 1 skipped (Docker-unavailable skip)

## Objective

Execute the A.2 design: restructure `apply` and `draft` CLI contracts around a single `--channel` flag, remove `--session` absolute-path support, consolidate routing, and update tests.

## Scope

Targets the A.2 task group from `roadmap.md`:

- `agent-sandbox.sh`: add `--channel` flag; remove `--session` absolute-path support
- `resolve_session_dir`: remove absolute-path branch; consolidate channel routing
- `draft_run`: take `SOURCE_DIR` directly; apply `patches/*.diff` + optional `uncommitted.diff`
- `apply_run`: take file path directly; always apply `uncommitted.diff`
- `Makefile.template`: add `AUTOSAVE=1` → `--channel=autosave`, `BUNDLE=1` → `--channel=bundles`
- Update tests for CLI and routing changes

## Carried forward

| Item | From handover |
|---|---|
| Interactive confirmation flag (`--interactive` for `make apply` and `make draft`) | 20260429-03-design-command_shape_and_contract.md |

## Acceptance criteria

1. `scripts/run_tests.sh` exits 0. All tests pass including updated assertions for the new `--channel` flag and routing contract.
2. `make draft` (no flags) resolves `--channel=session` (default). Finds latest `session/` export under `$CHANGES_DIR/` and applies `patches/*.diff`.
3. `make draft BUNDLE=1` resolves `--channel=bundles`. Finds latest bundle export under `$OUTPUT_DIR/bundles/` and applies `patches/*.diff`.
4. `make apply` (no flags) resolves `--channel=diffs` (default). Finds latest `uncommitted.diff` under `$OUTPUT_DIR/diffs/` and applies it.
5. `make apply AUTOSAVE=1` resolves `--channel=autosave`. Finds latest `uncommitted.diff` under `$CHANGES_DIR/<session>/autosave/` and applies it.
6. `--diff=<path>` bypasses all channel resolution. Applies the specified file directly regardless of `--channel` or `--session`.
7. `--session=<name>` is name-only. Passing an absolute path produces an error. Names resolve under the selected channel's base directory.
8. `draft_run` applies `patches/*.diff` sequentially. After all patches, applies `uncommitted.diff` if present. No other files processed.
9. `apply_run` applies any file path passed to it. No hardcoded filename — the caller decides which file.
10. Architecture documents in scope describe the system as built. `design_diff_and_branch_packaging_workflow.md` A.2 section updated to match implementation.

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Add `--channel` flag parsing; remove `--session` absolute-path branch |
| [`libs/draft_workflow.sh`](libs/draft_workflow.sh) | `draft_run` and `resolve_session_dir` refactor |
| [`libs/diff_workflow.sh`](libs/diff_workflow.sh) | `apply_run` refactor — file path input, `uncommitted.diff` always |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | `AUTOSAVE=1` and `BUNDLE=1` flag mapping |
| [`tests/test_draft_workflow.sh`](tests/test_draft_workflow.sh) | Update for `SOURCE_DIR` contract and channel routing |
| [`tests/test_diff_workflow.sh`](tests/test_diff_workflow.sh) | Update for file path contract and `uncommitted.diff` |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Router functions live in `agent-sandbox.sh`, not a shared library | Resolution is CLI-specific; workflow functions remain channel-agnostic | `scripts/agent-sandbox.sh`, design doc |
| `draft_run` receives both `SOURCE_DIR` and `SESSION_NAME` | `SOURCE_DIR` is the leaf dir with `patches/`; `SESSION_NAME` provides metadata for branch naming and `.draft-state` | `libs/draft_workflow.sh` |
| `apply_run` has no hardcoded filename | Caller decides which file; `--diff=<path>` can point to any file | `libs/diff_workflow.sh`, design doc |
| `--session` rejects absolute paths with clear error | Name-only contract; `--diff=<path>` is the escape hatch | `scripts/agent-sandbox.sh` |

## Mid-session findings

| Finding | Type | Impact |
|---|---|---|
| `draft_run` cannot derive session metadata from `SOURCE_DIR` alone because `basename(SOURCE_DIR)` is `session` or `autosave`, not the session identity | design | Resolved by passing `SESSION_NAME` as a separate arg |
| `EXPORT-TIME.txt` location changed from `SESSION_DIR/session/EXPORT-TIME.txt` to `SOURCE_DIR/EXPORT-TIME.txt` (since SOURCE_DIR now includes the subfolder) | scope change | Updated `draft_read_export_time` |

## Completed this session

| File | Change |
|---|---|
| `libs/diff_workflow.sh` | Rewrote `apply_run` — takes file path directly (4 args: PROJECT_DIR, DIFF_FILE, BRANCH, FORCE). No hardcoded filename. |
| `libs/draft_workflow.sh` | Rewrote `draft_run` — takes `SOURCE_DIR` + `SESSION_NAME` (6 args). Applies `patches/*.diff` sequentially, then `uncommitted.diff` if present. Updated `draft_read_export_time` for new layout. |
| `scripts/agent-sandbox.sh` | Added `--channel` flag parsing. Added `resolve_source_for_draft` and `resolve_diff_for_apply` router functions. Updated `apply`/`draft` dispatch. `--session` is name-only (rejects absolute paths). |
| `libs/_templates/Makefile.template` | Added `AUTOSAVE=1` → `--channel=autosave`, `BUNDLE=1` → `--channel=bundles` mappings. Updated workflow comments. |
| `tests/test_diff_workflow.sh` | Rewrote 8 tests for new `apply_run` contract (file-path input, no resolution logic). |
| `tests/test_draft_workflow.sh` | Updated 24 test calls for new `draft_run` signature. Added `test_draft_applies_uncommitted_diff`. |
| `tests/libs/session_fixtures.sh` | Renamed `changes.diff` → `uncommitted.diff` in fixtures. Added `all-changes.diff`. |
| `scripts/onboard.sh` | Updated stale `staged.diff` comment. |
| `libs/sandbox-entrypoint.sh` | Updated stale `staged.diff`/`autosave.diff` comments. |
| `libs/dirs.sh` | Updated stale comment about output format. |
| `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Updated A.2 section to reflect actual implementation (router functions in agent-sandbox.sh, apply_run file-path contract). |

## Deferred items

| Item | Reason | Next destination |
|---|---|---|
| A.3 implementation | Now unblocked — documentation and recovery helpers | Next session |
| Session B: `--interactive` | Blocked on A.3 | Session after A.3 closes |
| Router unit tests | `resolve_source_for_draft` and `resolve_diff_for_apply` are tested indirectly via integration; dedicated unit tests deferred | Next session or A.3 |
| `changed-files/` separate operation | Deferred beyond A.3 per design | Roadmap backlog |

## Next session

**A.3 — Documentation and recovery:** Update `design_diff_and_branch_packaging_workflow.md` Contract Amendments with final design, add emergency recovery helper snippets to `docs/development/quickstart.md`, final test pass across all changes.
