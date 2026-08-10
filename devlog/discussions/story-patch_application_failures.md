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

### Case 6: Case-insensitive filesystem produces case mismatch in snapshot pipeline

**Scenario:** A file renamed on the host with only casing differences (e.g. `base.Dockerfile` → `base.dockerfile`) is committed. `git status` reports clean on a case-insensitive filesystem (Windows NTFS, macOS APFS). But the container runs on a case-sensitive Linux ext4 overlay. The snapshot pipeline produces a dirty working tree because the two layers disagree on the filename case.

**Cause:** `git archive HEAD` on the host reads the EXACT filename from the git tree object, which retains the ORIGINAL case (`base.Dockerfile`, uppercase). The git tree object was never updated because `git mv` is a no-op on case-insensitive filesystems — the OS treats both names as the same file. The commit's tree object still references the old case, even though `git log --stat` and `git show` may display the new case (git resolves the display name from the filesystem, not the tree object).

The snapshot pipeline produces:
- **Layer 1** (`baseline.tar` → `git add -A` → commit): captures `base.Dockerfile` from the tree object. The sandbox HEAD tree has uppercase.
- **Layer 2** (rsync overlay from host working tree): copies `base.dockerfile` (lowercase, what the filesystem actually has).

Inside the container on case-sensitive ext4:
```
HEAD tree:    base.Dockerfile  (from git archive HEAD)
Working tree:  base.dockerfile  (from rsync overlay)
Index:         base.Dockerfile  (from git add -A at baseline creation)
git status:    R  base.Dockerfile → base.dockerfile  (rename detected)
```

The same blob hash confirms content is identical. Only the filename casing differs.

**Diagnosis confirmation (2026-05-28):** `baseline.tar` consistently contained `base.Dockerfile` (uppercase) across multiple `make start` restarts. The host's `git status` reported "working tree clean" at commit `7517dff` on a case-insensitive Windows NTFS filesystem. The container's `git status` consistently showed the rename as unstaged. `git config core.ignorecase` not set (not available in the container to check host value). The two layers of the snapshot pipeline faithfully reproduce a case mismatch that exists in the host's git repository but is invisible on case-insensitive filesystems.

**The snapshot pipeline is working correctly.** This is not a stale snapshot, a bad cache, a Docker layer issue, a container restart issue, or a pipeline bug.

**Permanent fix on host:** Force git to update the tree object with the correct case by renaming through an intermediate, distinctly-named path:

```bash
git mv base.Dockerfile base.Dockerfile.tmp
git mv base.Dockerfile.tmp base.dockerfile
git commit -m "fix: force lowercase base.dockerfile in tree object"
```

After this, `git archive HEAD` will produce `base.dockerfile` and all future container sessions will have a clean working tree.

**Detection implemented:** `snapshot_check_case_mismatch()` (session 20260528-11) runs in both `snapshot_archive_head` (host-side, before `git archive`) and `snapshot_init_git` (container-side, after rsync overlay). It compares `git ls-tree HEAD` filenames against the filesystem using `find -iname` and warns on case mismatches with the same blob hash. Non-blocking — snapshot proceeds with the warning visible on stderr.

**Applicability:** This affects any filename case change on a case-insensitive host that packages content for a case-sensitive Linux container. The fix (intermediate rename) is a one-time host-side action per case-changed file.

### Case 7: Trailing whitespace stripped from context lines by diff pipeline

**Scenario:** A source file has trailing whitespace on lines that serve as patch context (e.g. Markdown hard line breaks: `  ` at end of line). The diff pipeline strips trailing whitespace from ALL lines — including context (` `-prefixed) lines — via `sed 's/[[:space:]]*$//'`. `git apply` rejects the patch because the context lines no longer match the target file.

**Error:**
```
error: patch failed: devlog/discussions/security_delta_worktree_model.md:1
error: devlog/discussions/security_delta_worktree_model.md: patch does not apply
```

**Root cause chain:**
1. Source file has trailing whitespace on context lines (lines 5–6 in the real case: Markdown companion/baseline references with hard breaks).
2. `package_commits()`, `write_uncommitted_diff()`, and `write_all_changes_diff()` all run `sed 's/[[:space:]]*$//'` on the entire diff output — stripping trailing whitespace from `+` (addition), `-` (removal), AND ` ` (context) lines.
3. `git apply --ignore-whitespace` still requires exact matching of context lines to locate where the hunk belongs. The flag only relaxes whitespace on `+`/`-` lines, not on context lines.
4. The context lines in the patch (now without trailing spaces) don't match the file (which still has them). `git apply` rejects the hunk.

**Why existing recovery modes don't help:**
- `--recount` recalculates line counts but doesn't relax context string matching.
- `--ignore-space-change` (advertised as "ignore changes in whitespace when finding context") still fails on trailing whitespace in git 2.x for this case.
- `-C1` reduces required context to 1 line and can work as a fallback **if** at least one other context line in the hunk matches. It fails when ALL nearby context lines have trailing whitespace.

**Fix applied (2026-07-01):** The `sed` was changed from stripping ALL lines to stripping only `+`/`-` lines in `package_commits()`, `write_uncommitted_diff()`, and `write_all_changes_diff()`:

```bash
# Before (strips context lines — breaks git apply):
| sed 's/[[:space:]]*$//'

# After (strips only change lines — preserves context fidelity):
| sed -e '/^[+]/ s/[[:space:]]*$//' -e '/^[-]/ s/[[:space:]]*$//'
```

This preserves context line fidelity (required for `git apply` matching) while still cleaning trailing whitespace from changed lines (preventing cosmetic whitespace-only diffs).

**Knowledge test:** `tests/knowledge/knowledge_trailing_whitespace_context_mismatch.sh` documents the git apply behaviour and validates the fix across three scenarios.

**Status:** Fixed.

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
| F1 — Makefile.template FROM/CHANNEL mismatch | **Resolved** | Echo messages in `agent-sandbox.sh` changed from `CHANNEL=` to `FROM=`; Makefile.template now errors on `CHANNEL=` with `FROM=` hint; convention documented in `cli-conventions.md` |
| F2 — `git diff --no-renames` index conflict | **Closed** | Git limitation. Workaround (cumulative diff) documented in Case 5. |
| F3 — `strip_index_lines` and `similarity index` | **Closed** | Correct behaviour — not a bug. |
| F4 — `package_branch` missing `diff.sh` COPY | **Closed** | Already fixed by original patch 6. |
| F5 — `DIFFS` range filter skips patch 1 | **Closed** | Correct behaviour — feature, not a bug. |
| F6 — Cumulative patch verified clean | **Closed** | Workaround confirmed functional. |

This is the recommended fallback when per-commit patches cannot apply due to rename conflicts or baseline divergence.
---
[CORRECTION -- 2026-08-10]: CLI interaction standards document renamed from `cli-standards.md` to `cli-conventions.md` (ste-framing: conventions, not standards). All in-body `cli-standards` references in this record updated to the new filename to keep the historical link resolvable. The rename and new framing are recorded in handover `20260810-09`.
