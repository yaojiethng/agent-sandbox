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

1. **`apply_run`**: Before `git apply`, check whether any rename operations in the patch target files that already exist. If so, save existing content, remove target, apply patch, verify.
2. **`package_branch`**: Either refuse to overwrite an existing bundle, or use a higher-resolution timestamp to avoid collisions within the same second.
3. **`make draft`**: Expose `--recount` and `--reject` flags directly so operators can retry failed patches without manually invoking `git apply`.
4. **Bundle generation**: Consider adding a `--no-renames` mode to `package_branch` that produces patches using `git diff --no-renames` instead of `git format-patch` or `git diff` with rename detection. This avoids the "rename target already exists" problem at the cost of slightly larger patch files.
5. **`make draft`**: Add a git apply check that detects the "rename target already exists" pattern and offers to use `--no-renames` patches or a workaround.

## Mid-session Findings

### Finding 1: `Makefile.template` uses `FROM` not `CHANNEL` for draft channel

The Makefile template at `scripts/templates/Makefile.template` defines:

```makefile
DRAFT_CHANNEL := $(if $(FROM),$(FROM),session)
```

The variable is named `FROM`, but operators naturally try `CHANNEL=bundles`. Since `FROM` is unset, `DRAFT_CHANNEL` defaults to `session` and the draft resolves against `$CHANGES_DIR/session/` instead of `$OUTPUT_DIR/bundles/`.

**Status:** Open. The operator can use `FROM=bundles` as a workaround. The template could accept both `FROM` and `CHANNEL`.

### Finding 2: `git diff --no-renames` produces non-applyable patches for rename targets that already exist in index

Even with `--no-renames`, `git diff` produces `new file mode` entries for files that appear only on the "to" side of the diff. `git apply` rejects `new file mode` with "already exists in index" when the target file is already tracked. This is a git limitation: `new file mode` strictly means "create this file" and there is no flag to allow overwriting.

**Workaround:** The cumulative patch approach (`git diff --no-renames <host-state>..<final-state>`) works because it produces `diff` entries (content modifications) for files that exist in both states, `deleted file mode` for files only on the left side, and `new file mode` only for genuinely new files. The `diff` entries apply cleanly to existing tracked files.

### Finding 3: `strip_index_lines` in `diff.sh` does not remove `similarity index` lines

`strip_index_lines` only removes `index <hash>..<hash> <mode>` lines. The `similarity index` lines (used in git's rename detection) pass through unchanged. This is correct behaviour — `similarity index` is not an index line — but means patches with rename detection keep their rename semantics.

### Finding 4: `package_branch` depends on `diff.sh` at runtime but Dockerfile was missing the COPY

Patch 6 in this bundle fixes this: adds `COPY diff.sh /opt/sandbox/lib/diff.sh` to the capability Dockerfile. Without it, `package_branch.sh` fails with:

```
/opt/sandbox/lib/package_branch.sh: line 39: /opt/sandbox/lib/diff.sh: No such file or directory
```

**Status:** Fixed by patch 6.

### Finding 5: `make draft` with `DIFFS=2..7` applies only the last N patches, skipping patch 1

The `DIFFS` range filter in `draft_run` correctly filters by numeric prefix, allowing the operator to skip patches that were already applied manually. Usage:

```bash
make draft FROM=bundles SESSION=<name> DIFFS=2..7
```

This is a viable workaround for the rename problem: manually apply patch 1 (using `git rm` of uppercase originals + `git apply`), then let `make draft` handle patches 2-7.

### Finding 6: Cumulative `git diff --no-renames` patch verified clean

A cumulative patch generated from the "lowercase files present" state (simulating the host) to the fully-patched state was verified to apply cleanly:

```bash
git apply --ignore-whitespace --index cumulative.diff  # exit=0
```

This is the recommended fallback when per-commit patches cannot apply due to rename conflicts or baseline divergence.
