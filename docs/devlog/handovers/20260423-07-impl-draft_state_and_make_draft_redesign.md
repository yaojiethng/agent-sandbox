# Agent Handover

**Session date:** 2026-04-23
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Implement Unit F1 — complete `make draft` + `.draft-state`. Rewrite the `draft` command in `apply_workspace.sh` to resolve exports from `$CHANGES_DIR/` by lexicographic sort, parse session identity from folder names, create draft branches with the new naming convention, and commit `.draft-state` as the first commit on the branch.

## Scope

Unit F1 from the M2.3 task list. Specifically:

1. Rewrite `make draft` in `scripts/apply_workspace.sh`:
   - Resolve target export folder from `$CHANGES_DIR/` by lexicographic sort (latest `EXPORT_TIME`).
   - Support explicit `--session=<path>` to target any folder (including `$OUTPUT_DIR/bundles/` exports).
   - Parse `EXPORT_TIME`, `SANITIZED_HOST_BRANCH`, `SESSION_TS` from the resolved folder name.
   - Draft branch name: `draft/<EXPORT_TIME>-<SESSION_TS>-<BRANCH_SUMMARY or SANITIZED_HOST_BRANCH>-<sha6>`.
   - First commit on branch is `.draft-state` with required fields.
   - Apply numbered diffs via `git apply` with index lines stripped, staging and committing each.
   - Guard against an existing `draft/` branch with the same computed name — refuse if a collision exists. Other `draft/` branches from different sessions are allowed.
   - Print operator hint on completion.

2. Update `scripts/agent-sandbox.sh` to passthrough `BRANCH_SUMMARY` argument if needed.

3. Update `libs/_templates/Makefile.template` `make draft` target for new argument passthrough.

4. Update `tests/test_apply_workspace.sh` for new folder-name parsing, draft branch naming, and `.draft-state` commit validation.

5. Extract shared draft branch management functions (branch existence guard, `.draft-state` read/write, folder name parsing) into a common location sourced by F2.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Status |
|---|---|---|
| 1 | `make draft` resolves the latest export folder from `$CHANGES_DIR/` by lexicographic sort of folder basenames | ✅ |
| 2 | `make draft --session=<path>` applies diffs from an arbitrary folder path, including `$OUTPUT_DIR/bundles/` exports | ✅ |
| 3 | Draft branch name follows `draft/<EXPORT_TIME>-<SESSION_TS>-<sanitized-host-branch>-<sha6>` when no `BRANCH_SUMMARY` is provided | ✅ |
| 4 | Draft branch name uses `BRANCH_SUMMARY` in place of the sanitized host branch slug when provided | ✅ |
| 5 | The first commit on the draft branch is `.draft-state` containing all required fields: `source_branch`, `from_hash`, `author`, `session_ts`, `host_branch`, `diff_count`, `exported-at`, `drafted-at` | ✅ |
| 6 | Numbered diffs from the export folder are applied as subsequent commits after `.draft-state`, in sort order | ✅ |
| 7 | Same-name collision guard: `make draft` refuses with a clear error if a `draft/` branch with the identical computed name already exists | ✅ |
| 8 | Other `draft/` branches from different sessions do **not** trigger the guard | ✅ |
| 9 | Operator hint printed on completion shows the draft branch name, export source, diff count, and next-step commands | ✅ |
| 10 | `tests/test_apply_workspace.sh` passes all tests | ✅ |
| 11 | Architecture documents in scope describe the system as built | ✅ |

## Hot files

| File | Why in scope |
|---|---|
| [`scripts/apply_workspace.sh`](scripts/apply_workspace.sh) | `make draft` command rewrite — folder resolution, branch naming, `.draft-state` commit, diff application |
| [`scripts/agent-sandbox.sh`](scripts/agent-sandbox.sh) | Argument passthrough for `BRANCH_SUMMARY` |
| [`libs/_templates/Makefile.template`](libs/_templates/Makefile.template) | `make draft` target update — new arguments |
| [`tests/test_apply_workspace.sh`](tests/test_apply_workspace.sh) | Test fixtures for new draft branch naming and `.draft-state` commit |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Same-name collision guard (not prefix-based) | Operator amendment: allows concurrent drafts from different sessions while preventing accidental duplicate creation | This handover + design doc |
| `$WORKSPACE_DIR/draft-state` kept for backward compat | Existing `confirm`/`reject` commands still read the file; F2 will migrate them to read from branch | This handover |
| `libs/draft.sh` as shared library name | Descriptive, scoped to draft workflow; consumed by F2's confirm/reject rewrite | This handover |

## Completed this session

| File | Change |
|---|---|
| `libs/draft.sh` | New shared library: `draft_resolve_latest_export`, `draft_parse_folder_name`, `draft_guard_no_collision`, `draft_write_state`, `draft_read_state_from_branch` |
| `scripts/apply_workspace.sh` | Rewrote `draft` command: lexicographic export resolution, folder-name parsing, `.draft-state` commit, sequential diff application, operator hint, same-name collision guard |
| `scripts/agent-sandbox.sh` | Added `BRANCH_SUMMARY` flag parsing and passthrough |
| `libs/_templates/Makefile.template` | Added `BRANCH_SUMMARY` to `make draft` target |
| `tests/test_apply_workspace.sh` | Updated fixtures to new folder format; added tests for `.draft-state`, branch naming, collision guard, explicit `--session`; 43/43 pass |
| `docs/devlog/discussions/design_diff_and_branch_packaging_workflow.md` | Updated collision guard text and `.draft-state` locating instructions |

## Deferred items

| Item | Reason | Destination |
|---|---|---|
| F2 — `make confirm` rewrite | Depends on F1 `.draft-state` commit model; confirm must read `.draft-state` from branch instead of file | Next session (F2) |
| F2 — `make reject` update | Depends on F1; reject must read `source_branch` from `.draft-state` on branch | Next session (F2) |
| F2 — `make sync` removal | Part of F2 scope; `SYNC=1` handling and `make sync` target removal | Next session (F2) |
| Remove `$WORKSPACE_DIR/draft-state` backward-compat file | Kept only so existing confirm/reject pass this session; obsolete once F2 reads from branch | Next session (F2) |
| G — `.skills/package-diff.md` update | Depends on F2 completion | F2 close or follow-up |

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline.
**Session type:** Implementation — Unit F2 (`make confirm` rewrite + `make reject` update + `make sync` removal).

### Orientation

Unit F2 depends on F1 (now complete). It rewrites the `confirm` and `reject` commands to read `.draft-state` from the draft branch instead of the `$WORKSPACE_DIR/draft-state` file.

**`make confirm`:**
1. Read `.draft-state` from draft branch — fail with "not on a draft branch" if absent.
2. Drop `.draft-state` commit via `git rebase --onto`.
3. Rebase draft onto target — on conflict print exact recovery commands and exit.
4. `git merge --ff-only`.
5. Delete draft branch.

**`make reject`:**
1. Read `source_branch` from `.draft-state` on the draft branch.
2. Check out source branch.
3. Delete draft branch.

**`make sync` removal:** Remove `SYNC=1` handling and `make sync` target entirely.

Files to change:
- `scripts/apply_workspace.sh` — `confirm` and `reject` command rewrites, `sync` removal
- `libs/_templates/Makefile.template` — remove `make sync` target
- `tests/test_apply_workspace.sh` — update confirm/reject tests for branch-based `.draft-state` reading; remove sync tests
- `libs/draft.sh` — may need `draft_read_state_from_branch` usage pattern

### Blocking design questions
None.

### Known watch-out items
1. Existing tests rely on `$WORKSPACE_DIR/draft-state` — they will break when confirm/reject stop reading the file. Update tests in the same session.
2. `confirm` rebase conflict recovery messages must be tested.
3. `make sync` removal may have references in Makefile.template comments — grep for `sync` before closing.
