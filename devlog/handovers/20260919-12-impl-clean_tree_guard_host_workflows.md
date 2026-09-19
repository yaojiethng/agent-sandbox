# 20260919-12-impl-clean_tree_guard_host_workflows

- **Handover:** 20260919-12
- **Type:** Implementation
- **Milestone:** M2.6 / M2.6.7 (Interface Contract Compatibility)
- **Dates:** 2026-09-19
- **Status:** Closed

## What this iteration does

Fixes a draft/reject state leak at the fork point by guarding the host workflow
commands (`draft`, `apply`, `reject`) on a clean working tree.

## Root cause

`make draft` did not hard-fail on an unclean tree. Unstaged changes were carried
onto the draft branch by `checkout -b`, and `apply_and_commit`'s `git add -A`
swept operator untracked or staged files into the first draft commit. After
reject, `git checkout "$source_branch"` failed on a dirty/conflicting tree,
leaving the draft branch behind. A dirty-started draft could also destroy the
operator's pre-existing work via `draft_rollback`'s `git reset --hard`.

## Fix

- `make draft` requires a clean working tree. The guard is NEVER bypassed by
  `--force` (`--force` only tolerates apply conflicts, never an unclean fork
  base). On failure it prints a stash-or-commit hint.
- `make apply` requires a clean tree by default; `--force` tolerates a dirty
  tree (one form of apply conflict) with a loud warning about possible hunk
  failure and `.rej` files.
- `make reject` discards uncommitted draft residue: on checkout failure it
  warns, then `git checkout -f` + `git clean -fd` return to the source branch
  and delete the draft branch.

## Files in scope

- `scripts/guards.sh` -- new `require_clean_working_tree PROJECT_DIR [LABEL]`.
- `scripts/workflows/apply.sh` -- clean-tree guard; `--force` bypass with
  warning.
- `scripts/workflows/draft.sh` -- clean-tree guard, never bypassed; stash hint.
- `scripts/workflows/reject.sh` -- `checkout -f` + `clean -fd` on refusal.
- `tests/test_apply_count.sh`, `tests/test_draft_workflow.sh` -- guards and
  discard-path coverage.
- `tests/test_diff_workflow.sh` -- fixed pre-existing tests that left a staged
  index; the new guard exposed the latent dirt.
- `docs/architecture/sandbox_lifecycle.md`, `docs/adr/diff_packaging.md` --
  document the guards and the reject-discard behavior.

## Acceptance criteria

| # | Criterion |
|---|---|
| AC1 | `make draft` fails on a dirty working tree and never folds WIP into a draft commit |
| AC2 | `make apply` fails on a dirty tree; `--force` proceeds with a warning |
| AC3 | `make reject` returns to the source branch and deletes the draft branch even when residue blocks a plain checkout |
| AC4 | The clean-tree guard is not bypassed by draft `--force` |
| AC5 | Suite green (908/908 across 52 files) |

## Notes

`git apply` never emits conflict markers (`<<<<<<<`/`=======` are `git merge`);
`--force` (`git apply --reject`) is lossy, producing `.rej` files. `--3way`
cannot work because `strip_index_lines` removes the index-line blob hashes.