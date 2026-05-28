# Story: Patch Application Failure Modes

**Date:** 2026-05-26
**Status:** Active

## Problem

When applying a bundle of numbered patches via `make draft`, patches can fail to apply for reasons that aren't obvious from the error message. This story catalogues failure cases as they are encountered, so the `apply_run` workflow can be hardened against them.

## Failure Case Registry

### Case 1: Rename target already exists

**Scenario:** Patch contains `rename A -> B`, but `B` already exists in the working tree.

**Cause:** Container was snapshotted with uncommitted working tree changes. `init_sha` pointed to the baseline commit (where `A` exists), but the working tree already had `B` created by a prior session's uncommitted changes. `git apply` refuses to apply a rename when the target path already exists, even if `--ignore-whitespace` is used.

**Error:**
```
error: src/reasoning/providers/opencode/base.Dockerfile: No such file or directory
```

(The error is misleading — it says `A` doesn't exist, but actually `B` exists and git won't overwrite it.)

**Workaround:** Save the content of `B` to temp, `mv B A`, apply patch, then verify `A -> B` rename succeeded. Patch `git apply --reject` does not help here since this is a file-level rename, not a hunk conflict.

**Status:** Encountered. Not yet fixed in `apply_run`.

### Case 2: Hunk context drift from line reorders

Not yet encountered — see the `--recount` fallback in `apply_run` which handles this.

### Case 3: Bundle overwrites itself

**Scenario:** Running `package_branch` a second time to the same bundle directory overwrites the original per-commit patches with a single squashed patch.

**Cause:** `package_branch` writes to `--to=<dir>/bundles/<EXPORT_TIME>-<SESSION_SUMMARY>-<SESSION_TS>/`. If the bundle directory already exists (same EXPORT_TIME and SESSION_SUMMARY and SESSION_TS), it gets overwritten. Per-commit patches (0001-0005) are replaced by a single squashed commit.

**Status:** Encountered. The per-patch structure of the original bundle was lost.

## Case 4: Rename source missing (after manual rm)

**Scenario:** Operator runs `git rm` on the rename source files (uppercase `Dockerfile`) to clear the rename conflict, then applies the same patch. Now `git apply` fails with `does not exist in index` because it expects the source file to be present as the rename origin.

**Error:**
```
error: src/capability/Dockerfile: does not exist in index
error: src/reasoning/Dockerfile.node: does not exist in index
...
```

**Cause:** A git rename operation (`rename from A → rename to B`) is atomic: git expects `A` to exist in the index and `B` to be absent. If `A` is removed first, the rename can't proceed. If `B` already exists, the rename can't proceed. There is no `git apply` flag (`--reject`, `--force`, `--ignore-whitespace`) that bypasses this — it is a fundamental constraint of git's rename mechanics.

**Workaround:** Do not remove the source or target files. Instead, generate patches without rename operations:

```bash
git diff --no-renames <from> <to> > patch.diff
```

This produces `deleted file mode` for the old name and `new file mode` for the new name separately, which `git apply` handles without the "already exists" constraint (as long as the target directory exists).

**Status:** Encountered and resolved via `git diff --no-renames` in the previous session.

## Case 5: Host baseline diverged from container baseline

**Scenario:** The container's `INIT_SHA` (baseline commit for `package_branch`) is `8af5407` which has uppercase `Dockerfile` paths. The host repository at the time of drafting already has lowercase `.dockerfile` files committed. The bundle produced against the container's baseline contains rename operations that conflict with the host's existing lowercase files.

**Cause:** The container is a snapshot of the repository at a specific point. If the host repository has advanced beyond that snapshot (e.g. partial manual application of some changes, or a prior session's work), the bundle's patch content references file paths and context lines that no longer match the host's working tree.

**Error:**
```
error: src/reasoning/providers/hermes/base.dockerfile: already exists in working directory
error: src/reasoning/Dockerfile.python: patch does not apply
```

**Diagnosis:** The first error indicates a rename target already exists. The second indicates content mismatch in a file that should have been deleted (but may have different content on the host).

**Workaround:** Produce a cumulative patch from the container's baseline to the host's HEAD, using `git diff --no-renames`, and apply that as a single squashed commit instead of per-commit patches:

```bash
# Inside container:
git diff --no-renames <host-baseline>..<patched-state> > /sandbox-path/cumulative.diff
# On host:
git apply --ignore-whitespace --index cumulative.diff
```

**Status:** Encountered. Workaround successful.

## Proposed Fixes

Status after triage session `20260528-02-workflow-patch_application_findings_triage.md`:

1. **`apply_run`** — rename conflict detection. **Open.** No change from original.
2. **`package_branch`** — bundle overwrite protection. **Open.** No change from original.
3. **`make draft`** — expose `--recount`/`--reject`. **Open.** No change from original.
4. **Bundle generation** — `--no-renames` mode. **Open.** No change from original.
5. **`make draft`** — rename conflict detection. **Open.** No change from original.

**Closed findings** (moved to handover `20260528-02`):

| Finding | Status | Resolution |
|---|---|---|
| F1 — Makefile.template FROM/CHANNEL mismatch | **Resolved** | Echo messages in `agent-sandbox.sh` changed from `CHANNEL=` to `FROM=`; Makefile.template now errors on `CHANNEL=` with `FROM=` hint; convention documented in `cli-standards.md` |
| F2 — `git diff --no-renames` index conflict | **Closed** | Git limitation. Workaround (cumulative diff) documented in Case 5. |
| F3 — `strip_index_lines` and `similarity index` | **Closed** | Correct behaviour — not a bug. |
| F4 — `package_branch` missing `diff.sh` COPY | **Closed** | Already fixed by original patch 6. |
| F5 — `DIFFS` range filter skips patch 1 | **Closed** | Correct behaviour — feature, not a bug. |
| F6 — Cumulative patch verified clean | **Closed** | Workaround confirmed functional. |

This is the recommended fallback when per-commit patches cannot apply due to rename conflicts or baseline divergence.
