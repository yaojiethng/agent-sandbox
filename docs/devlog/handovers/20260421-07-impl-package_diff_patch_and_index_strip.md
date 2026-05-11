# Agent Handover

**Session date:** 2026-04-21
**Milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Session type:** Implementation
**Status:** Closed

## Objective

Replace `git apply` with `patch -p1` in the `make apply` path, and strip `index <sha>..<sha>` lines from generated diffs, to eliminate blob SHA mismatch failures when applying diffs sequentially or against a drifted index.

## Scope

Three files: `libs/package-diff.sh`, `scripts/apply_workspace.sh`, `.skills/package-diff.md`. No other files in scope.

## Carried forward

None.

## Acceptance criteria

- [x] `make apply` succeeds for diffs containing new files without pre-staging
- [x] `make apply` succeeds when applied sequentially against an advanced index state
- [x] `make apply --force` creates `.rej` files for conflicting hunks
- [x] Generated `changes.diff` contains no `index <sha>..<sha>` lines
- [x] `changed-files/` directory is no longer produced by `package-diff.sh`
- [x] `patch -p1 < changes.diff` is the documented apply method in `package-diff.md`

## Hot files

| File | Why in scope | Status |
|---|---|---|
| `libs/package-diff.sh` | Strip index lines; remove changed-files generation | ✓ Complete |
| `scripts/apply_workspace.sh` | Replace git apply with patch -p1 in apply command | ✓ Complete |
| `.skills/package-diff.md` | Update output description and apply instructions | ✓ Complete |

## Decisions made this session

| Decision | Rationale | Where recorded |
|---|---|---|
| Strip `index <sha>..<sha>` lines from diff output | These lines encode blob SHAs that `git apply` validates against the index; stripping them makes the diff purely context-line based so `patch` can apply it regardless of index state | `package-diff.sh` comment |
| Use `patch -p1` instead of `git apply` | `patch` matches hunks by context lines only — no index SHA validation, no new-file index requirement, tolerant of sequential application and index drift | `apply_workspace.sh` |
| Remove `changed-files/` entirely | `patch -p1` applies new files natively from `--- /dev/null` headers; the directory was only needed as a fallback when `git apply` failed, which is no longer possible | `package-diff.sh` |
| Force path uses `patch --force` | Consistent with non-force path; `.rej` files land next to originals for manual resolution | `apply_workspace.sh` |

## Completed this session

| File | Change summary |
|---|---|
| `libs/package-diff.sh` | Removed `changed-files/` dir creation, enumerate, and copy sections; added `grep -v '^index '` to diff pipeline; updated header comment and summary output |
| `scripts/apply_workspace.sh` | Removed new-file pre-staging block; replaced `git apply --index --3way` with `patch -p1 -d "$PROJECT_DIR"`; replaced force `git apply --reject` with `patch -p1 --force -d "$PROJECT_DIR"`; updated header comment |
| `.skills/package-diff.md` | Output description updated to single `changes.diff` entry; How to apply updated to `patch -p1 < changes.diff`; fallback instructions simplified |

## Deferred items

None.

## Next session

**Sub-milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline
**Next task:** Change 6 — baseline advancement (`make confirm SYNC=1`, `make sync`).

**Files to upload:**
- Most recent handover for immediate prior context (this file, or `20260421-06`)
- `scripts/apply_workspace.sh`
- `scripts/checkpoint.sh`
- `docs/discussions/design_apply_workflow_and_baseline_advancement.md`
- `roadmap.md`
