# Agent Handover

**Session date:** 2026-04-27
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Redesign the diff pipeline output structure: eliminate the autosave proliferation bug (new timestamped folder every tick), restructure `diff_on_exit` and `diff_on_autosave` output into `session/` and `autosave/` subfolders, and unify `make draft` / `make apply` path resolution. Also fix the earlier `SESSION=` path resolution bug for absolute/relative handling.

## Scope

This session redesigns the diff pipeline output directory structure and updates all consumers. Specifically:

1. **Fix autosave proliferation**: Replace per-tick `EXPORT_TIME`-stamped folders with a stable directory name containing `session/` and `autosave/` subfolders, avoiding the race condition between autosave and exit writers.

2. **Restructure directory layout**: Move from 3-field `<EXPORT_TIME>-<SANITIZED_HOST_BRANCH>-<SESSION_TS>/` with flat files to 2-field `<SESSION_TS>-<SANITIZED_HOST_BRANCH>/` with `session/` and `autosave/` subfolders. Each subfolder contains `EXPORT-TIME.txt`, `changes.diff`, `staged.diff` (session only), and `patches/0001-*.diff`.

3. **Unify path resolution**: Both `make draft` and `make apply` now use consistent path resolution — absolute paths used as-is, relative paths resolved from `$CHANGES_DIR`, no argument triggers auto-resolution. (resolve against `$CHANGES_DIR/` for `make draft` and resolve against `$DIFFS_DIR=$OUTPUT_DIR/diffs/` for `make apply` [AMENDED from priorhandover])

4. **Fix `SESSION=` path resolution bug**: Absolute paths were being treated as relative; corrected.

5. **Update all tests and documentation** to reflect the new structure.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `diff_on_exit` writes to `$CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/session/` with `EXPORT-TIME.txt`, `changes.diff`, `staged.diff`, and `patches/*.diff` | ✅ |
| 2 | `diff_on_autosave` writes to `$CHANGES_DIR/<SESSION_TS>-<SANITIZED_HOST_BRANCH>/autosave/` with `EXPORT-TIME.txt`, `changes.diff`, and `patches/*.diff`; overwritten each tick, no proliferation | ✅ |
| 3 | Directory names use 2-field format `<SESSION_TS>-<SANITIZED_HOST_BRANCH>` (EXPORT_TIME removed from folder name) | ✅ |
| 4 | `EXPORT-TIME.txt` inside each subfolder replaces the `EXPORT_TIME` field in folder names | ✅ |
| 5 | `make draft` resolves numbered diffs from `session/patches/` inside the session directory | ✅ |
| 6 | `make draft` auto-resolves by finding the latest session with a valid `session/patches/` subdirectory under `$CHANGES_DIR/` | ✅ |
| 7 | `make draft` branch naming: `draft/<SESSION_TS>-<BRANCH>-<SHA6>` (EXPORT_TIME dropped) | ✅ |
| 8 | `make apply` resolves `changes.diff` from `session/changes.diff` then `autosave/changes.diff` | ✅ |
| 9 | `make apply` with `--session=<absolute-path>` works even when `$CHANGES_DIR/` does not exist | ✅ |
| 10 | `.draft-state` `exported-at` field reads from `session/EXPORT-TIME.txt` | ✅ |
| 11 | All test suites pass (excluding 2 pre-existing `package_branch` test bugs) | ✅ |
| 12 | Architecture docs, correspondence model, and quickstarts describe the new structure | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| [`libs/diff.sh`](libs/diff.sh) | Core diff pipeline: `diff_on_exit` and `diff_on_autosave` rewrite; new `diff_write_changes_diff` helper |
| [`libs/draft.sh`](libs/draft.sh) | `draft_parse_folder_name` updated for 2-field format; new `draft_read_export_time` helper |
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | `draft` and `apply` commands rewritten for new path resolution and directory structure |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | `make draft` and `make apply` argument comments updated |
| [`tests/test_diff.sh`](tests/test_diff.sh) | Full rewrite for new directory structure (43 pass, 2 pre-existing failures) |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Full rewrite: fixture helpers, folder names, branch names, path resolution (44 pass, 0 fail) |
| [`docs/architecture/sandbox_lifecycle.md`](docs/architecture/sandbox_lifecycle.md) | Phase 3 diffs artefact listing updated |
| [`docs/architecture/execution_model.md`](docs/architecture/execution_model.md) | Directory tree updated |
| [`docs/architecture/system_overview.md`](docs/architecture/system_overview.md) | Diff and apply description updated |
| [`docs/architecture/tool_interface.md`](docs/architecture/tool_interface.md) | `staged.diff` references updated to new paths |
| [`docs/concepts/sandbox_host_correspondence_model.md`](docs/concepts/sandbox_host_correspondence_model.md) | Folder structure, correspondence cycle, and table entries updated |
| [`docs/development/project_index.md`](docs/development/project_index.md) | `apply_workspace.sh` description updated |
| [`providers/hermes/quickstart.md`](providers/hermes/quickstart.md) | Path examples updated |
| [`providers/opencode/quickstart.md`](providers/opencode/quickstart.md) | Path examples updated |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| 2-field directory name `<SESSION_TS>-<SANITIZED_HOST_BRANCH>` | EXPORT_TIME removed from folder name to avoid proliferation; timestamp stored in `EXPORT-TIME.txt` inside each subfolder | This handover |
| `session/` and `autosave/` subfolders | Avoids race condition between exit and autosave writers; each has its own namespace and can be overwritten independently | This handover |
| `staged.diff` retained in `session/` | Human-readable net delta `INIT_SHA..HEAD`; requested by operator | This handover |
| `changes.diff` written before sweep (uncommitted vs HEAD) | Captures the working tree delta; `staged.diff` captures the post-sweep authoritative state | This handover |
| `diff_format_patch` output removed from exit pipeline | `.patch` files are redundant with numbered `.diff` files from `package_branch`; callers pass output dir explicitly | This handover |
| `make draft` auto-resolution checks for `session/patches/*.diff` | Prevents resolving a session that has no numbered diffs to apply; provides a hint about `autosave/` existence | This handover |
| `make apply` uses `$OUTPUT_DIR/diffs/` | Changes from the diff pipeline live under `OUTPUT_DIR/diffs/`; `apply` is the consumer of those changes | This handover |
| `make apply` with `--session=<absolute-path>` does not require `$OUTPUT_DIR/diffs/` to exist | When the user provides an explicit path, there's no need to check auto-resolution directories | This handover |
| `.draft-state` `exported-at` field reads from `session/EXPORT-TIME.txt` | The timestamp is no longer in the folder name; it's read from the file at draft creation time | This handover |
| Draft branch naming `draft/<SESSION_TS>-<BRANCH>-<SHA6>` | 3-field `EXPORT_TIME` prefix dropped; the branch name uses the stable session identity | This handover |
| Relative `SESSION=` resolves from `$CHANGES_DIR` (not CWD) | Consistent with the design principle that session-diffs is the authority for changes | This handover |

## Completed this session

| File | Change |
|---|---|
| `libs/diff.sh` | Rewrote `diff_on_exit` to create `session/` subfolder with `EXPORT-TIME.txt`, `changes.diff`, `staged.diff`, `patches/`. Rewrote `diff_on_autosave` to create `autosave/` subfolder (no `staged.diff`). Added `diff_write_changes_diff` helper with untracked file support via `git add -N`. Fixed `source /libs/package_branch.sh` to use `BASH_SOURCE`-relative path. |
| `libs/draft.sh` | Updated `draft_parse_folder_name` for 2-field `<SESSION_TS>-<SANITIZED_HOST_BRANCH>` format. Added `draft_read_export_time()` to read `EXPORT-TIME.txt` from a session or autosave subfolder. |
| `scripts/apply_workspace.sh` | Rewrote `draft` command: auto-resolution in `$CHANGES_DIR/` checking for `session/patches/*.diff`; `--session` absolute/relative/auto path handling; branch name `draft/<SESSION_TS>-<BRANCH>-<SHA6>`; `.draft-state` includes `exported-at` from `EXPORT-TIME.txt`; `DIFFS` range support. Rewrote `apply` command: resolves `session/changes.diff` with `autosave/changes.diff` fallback; `--session` absolute/relative/auto; `--diff` direct path; `--branch`; `--force`; `--reject` flag; shasum-based index line stripping. Fixed `$CHANGES_DIR` check to skip when `--session` is an absolute path. |
| `libs/_templates/Makefile.template` | Updated `make draft` and `make apply` target comments. |
| `tests/test_diff.sh` | Full rewrite: `find_session_dir` for 2-field names, `session/` and `autosave/` subfolder assertions, `EXPORT-TIME.txt`, `changes.diff`, `staged.diff`, `patches/*.diff` checks. 43 pass / 2 pre-existing `package_branch` failures. |
| `tests/test_apply_workspace.sh` | Full rewrite: `make_export_with_diffs` creates `session/patches/*.diff`, `session/EXPORT-TIME.txt`, `session/changes.diff`. `make_session_with_changes_diff` creates `session/changes.diff`. All folder names use 2-field format. Draft branch names `draft/<SESSION_TS>-<BRANCH>-<SHA6>`. Apply resolves `$CHANGES_DIR/` with `autosave/` fallback. 44 pass / 0 fail. |
| `docs/architecture/sandbox_lifecycle.md` | Phase 3 description rewritten: artefact listing shows `session/` and `autosave/` subfolder structure. Apply workflow updated for new path resolution. |
| `docs/architecture/execution_model.md` | Directory tree updated to show `session/` and `autosave/` subfolders with their contents. `diff_on_exit` label updated. |
| `docs/architecture/system_overview.md` | Diff and apply description updated for new artefact structure. |
| `docs/architecture/tool_interface.md` | `staged.diff` references updated to new paths; path descriptions updated. |
| `docs/concepts/sandbox_host_correspondence_model.md` | Folder structure updated from 3-field to 2-field. Correspondence cycle diagram updated. Table entries for `package-branch output` and `session artefact directory` updated. |
| `docs/development/project_index.md` | `apply_workspace.sh` description updated from "staged.diff" to "changes.diff". |
| `providers/hermes/quickstart.md` | Path examples updated to `<SESSION_TS>-<BRANCH>/session/staged.diff` and `autosave/changes.diff`. |
| `providers/opencode/quickstart.md` | Same path updates. |

## Next session

Not yet defined.
