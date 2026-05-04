# Design — Change A: Unified Output Format and CLI Contract

**Target milestone:** M2.3 — Apply Workflow: Capability Layer Diff Pipeline

**Status:** Design record — describes the system as it will be after Change A
**Supersedes:** The "Contract Amendments" sections in `design_diff_and_branch_packaging_workflow.md`
**Related:** [`design_diff_and_branch_packaging_workflow.md`](design_diff_and_branch_packaging_workflow.md) — core design document (diff format, primitives, invariants unchanged)

---

## 1. Scope

Change A restructures the diff packaging pipeline and CLI contract around a unified output format, a `--channel` routing layer, and a consolidated `SESSION_STATE` identity model. It comprises four sequenced implementation groups (A.0–A.4), each with its own roadmap entry.

**What Change A is:**
- A new output format for all diff packaging (exit, autosave, manual `package_branch`, manual `package_diff`)
- A `--channel` flag that replaces hardcoded path resolution
- A file-path contract for `apply_run` (no hardcoded filename)
- A `SOURCE_DIR` contract for `draft_run` (caller supplies the directory)
- A shared `write_changed_files` helper extracted from inline copy logic
- Sourceability for `agent-sandbox.sh` so it can be sourced in tests
- Sourceability for `package_diff.sh` (add main guard), preserved for `package_branch.sh` (already present) — both are invoked as scripts via agent prompt templates (`agent/prompts/package-diff.md`, `agent/prompts/package-branch.md`) and must remain executable directly, while also being sourceable as libraries

**What Change A is not:**
- Not a redesign of the diff format or git-agnostic principle (those are settled in the core design doc)
- Not interactive mode (that is Change B)
- Not `SESSION_STATE` migration (that is already complete via pre-clean)

---

## 2. Output Format (Unified)

All packaging operations produce the same directory layout under their target base directory.

### Directory structure

```
<base>/
  EXPORT-TIME.txt              — audit trail timestamp
  patches/
    0001-<sha>.diff            — per-commit diffs (index lines stripped)
    0002-<sha>.diff
    ...
  uncommitted.diff             — git diff HEAD (including untracked, via git add -N)
  all-changes.diff             — git diff INIT_SHA (including untracked)
  changed-files/               — working tree copies of all changed files
    MANIFEST.txt
    <path>/<file>
    ...
```

### Per-operation output targets

| Operation | Base directory | Write pattern |
|---|---|---|
| `diff_on_exit` (EXIT trap) | `$CHANGES_DIR/<session>/session/` | Overwritten on each exit |
| `diff_on_autosave` (autosave loop) | `$CHANGES_DIR/<session>/autosave/` | Overwritten on each tick |
| `package_branch` (manual) | `$OUTPUT_DIR/bundles/<tag>/` | New folder per invocation |
| `package_diff` (manual) | `$OUTPUT_DIR/diffs/<tag>/` | New folder per invocation |

### No sweep commit

`diff_on_exit` and `diff_on_autosave` do **not** perform a sweep commit. Uncommitted changes are captured in `uncommitted.diff`. Committed changes are captured via `patches/` and `all-changes.diff`.

### Filename renames

| Old name | New name | Notes |
|---|---|---|
| `changes.diff` | `uncommitted.diff` | Unambiguous intent |
| `staged.diff` | `all-changes.diff` | Net delta from `INIT_SHA` including untracked |
| — | `patches/` | Subfolder for per-commit diffs (was parent-level) |

---

## 3. Pipeline Functions

### `package_branch` dispatcher

`package_branch` orchestrates all packaging output in a single call:

```bash
package_branch SANDBOX_DIR OUTPUT_DIR
```

Sequence:
1. `package_commits(SANDBOX_DIR, OUTPUT_DIR/patches/)` — numbered per-commit diffs since `INIT_SHA`
2. `write_uncommitted_diff(SANDBOX_DIR, OUTPUT_DIR/uncommitted.diff)` — `git diff HEAD` with untracked staging
3. `write_all_changes_diff(SANDBOX_DIR, OUTPUT_DIR/all-changes.diff)` — `git diff INIT_SHA` with untracked staging
4. `write_changed_files(SANDBOX_DIR, INIT_SHA, OUTPUT_DIR/changed-files/)` — working tree copies

All four operations strip index lines from text diffs (retain for binary patches).

### `diff_on_exit` / `diff_on_autosave` (thin dispatchers)

Both become wrappers that:
1. Create the output directory
2. Write `EXPORT-TIME.txt`
3. Call `package_branch "$SANDBOX_DIR" "$OUTPUT_DIR"`

No sweep commit. No `BASELINE_SHA` parameter — session identity is read from `SESSION_STATE`.

### `write_uncommitted_diff`

```bash
write_uncommitted_diff SANDBOX_DIR OUTPUT_FILE
```

- `git diff HEAD` (working tree vs last commit)
- Stages untracked files via `git add -N` before diff, restores staged state after
- Strips index lines

### `write_all_changes_diff`

```bash
write_all_changes_diff SANDBOX_DIR OUTPUT_FILE
```

- `git diff INIT_SHA` (working tree vs initial session commit)
- Stages untracked files via `git add -N` before diff, restores staged state after
- Strips index lines

### `write_changed_files`

```bash
write_changed_files SANDBOX_DIR SINCE_SHA OUTPUT_DIR
```

- Two-source file list: `git diff --name-only SINCE_SHA` (committed + staged + unstaged) and `git ls-files --others --exclude-standard` (untracked)
- Deduplication via `sort -u`
- Copies each file preserving directory structure; skips deleted files
- Writes `MANIFEST.txt` listing all files

---

## 4. CLI Contract

### `--channel` flag

A single `--channel` flag replaces hardcoded path resolution in both `apply` and `draft`.

| Command | Channel values | Resolves under |
|---|---|---|
| `draft` | `session` (default), `autosave`, `bundles` | `session-diffs/` (`session`, `autosave`), `output/bundles/` (`bundles`) |
| `apply` | `diffs` (default), `autosave`, `session` | `output/diffs/` (`diffs`), `session-diffs/<session>/autosave/` (`autosave`), `session-diffs/<session>/session/` (`session`) |

### `--session` name-only

- `--session=<name>` accepts names only, resolved under the selected channel's base directory
- Absolute paths produce a clear error: `--session is name-only; use --diff=<path> for explicit file paths`
- The `--diff=<path>` flag is the escape hatch for explicit file application

### Router functions

Two router functions in `agent-sandbox.sh` resolve channel + session into concrete paths. Workflow functions remain path-agnostic.

```bash
resolve_source_for_draft SANDBOX_DIR CHANNEL SESSION_ARG
  → tab-separated SOURCE_DIR and SESSION_NAME

resolve_diff_for_apply SANDBOX_DIR CHANNEL SESSION_ARG
  → path to uncommitted.diff file
```

### `draft_run` contract

```bash
draft_run PROJECT_DIR SOURCE_DIR SESSION_NAME BRANCH_FROM DIFFS BRANCH_SUMMARY
```

- `SOURCE_DIR` is an absolute path containing `patches/` subfolder and optionally `uncommitted.diff`
- `SESSION_NAME` provides metadata for branch naming (since `basename(SOURCE_DIR)` loses session identity)
- Resolution of which directory to use is the caller's (router's) responsibility

### `apply_run` contract

```bash
apply_run PROJECT_DIR DIFF_FILE APPLY_BRANCH FORCE
```

- `DIFF_FILE` is a file path directly — no internal routing, no hardcoded filename
- 4 positional arguments (was 6)

### Makefile flag mappings

| Makefile flag | CLI flag |
|---|---|
| `AUTOSAVE=1` | `--channel=autosave` |
| `BUNDLE=1` | `--channel=bundles` |

### `resolve_session_dir` removed from `session.sh`

The generic `resolve_session_dir` helper in `session.sh` is replaced by the two channel-specific router functions. Callers (`draft_run`, `apply_run`) receive resolved paths; they do not call `resolve_session_dir`.

---

## 5. Session Identity

`SESSION_STATE` (`.git/SESSION_STATE`) is the single source of truth for `init_sha` and `session_ts`. Already implemented via pre-clean Group 1.

- `diff_on_exit` and `diff_on_autosave` read `init_sha` via `session_state_read`
- `package_branch` reads `init_sha` via `session_state_read`
- `package_diff.sh` reads `init_sha` via `session_state_read`
- `BASELINE_SHA` environment variable is eliminated from `sandbox-entrypoint.sh`
- `BASELINE_SHA` parameter is eliminated from `diff_on_exit` and `diff_on_autosave`

---

## 6. `diff_on_exit` repair

The current `diff_on_exit` produces empty output because it runs the old code path (sweep commit, `BASELINE_SHA` param, inline operations) in a context where the pipeline is partially restructured. The fix **folds into A.1**: when A.1 rewrites `diff_on_exit` as a thin dispatcher calling `package_branch`, the empty-output bug is resolved by construction.

**Test gap closure:** A.1 must include a test that validates `diff_on_exit` produces non-empty output for a session with changes. The current tests validate internal function behaviour but not the end-to-end `diff_on_exit` call. A black-box test that runs the entrypoint sequence, makes changes, and asserts the output files are non-empty is the recommended approach.

---

## 7. Dependency Ordering

```
A.0 (sourceability)
  │
  ▼
A.1 (data model: unified format, dispatcher, diff_on_exit repair)
  │
  ├──► A.2 (CLI contract: --channel, routers, new signatures)
  │        │
  │        ▼
  │     A.4 (changed-files extraction — depends on A.1's helper
  │        infrastructure, but not on A.2's CLI changes)
  │
  └──► A.3 (documentation alignment — depends on A.1 + A.2 + A.4)
```

A.4 can run in parallel with A.2 (both depend on A.1, but not on each other).

---

## 8. References

| Document | Purpose |
|---|---|
| `design_diff_and_branch_packaging_workflow.md` | Core design: diff format, primitives, invariants |
| `roadmap.md` (§ A.0–A.4) | Executable task entries |
| `execution_model.md` | Architecture — diff pipeline |
| `sandbox_lifecycle.md` | Container lifecycle — SESSION_STATE initialisation |
| `tool_interface.md` | Operator-facing command reference |
