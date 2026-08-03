# Design — Diff Packaging and Apply/Draft Workflow

**Purpose:** Describes how agent changes are exported from the container and how the operator reviews and merges them into the host repository.

**Status:** Open

---

## Export pipeline

All diff packaging uses a single pipeline: `diff_export` → `package_branch`. The artefact set is identical regardless of trigger:

| Artefact | Content |
|---|---|
| `patches/*.diff` | One numbered `.diff` per agent commit since `init_sha` |
| `uncommitted.diff` | Working tree delta from HEAD (uncommitted changes) |
| `all-changes.diff` | Net delta from `init_sha` (committed + uncommitted) |
| `changed-files/` | Full file copies of every changed file with `MANIFEST.txt` |
| `EXPORT-TIME.txt` | Wall-clock timestamp of the export |
| `.export-status` | SUCCESS/FAIL with timestamp and exit code |

All diffs are unified format with index lines stripped — consumed by `git apply` in both directions (sandbox→host and host→sandbox).

### Export triggers

| Mechanism | Trigger | Path |
|---|---|---|
| Session export | Capability container stop (EXIT trap) | `session/<EXPORT_TIME>-<RUN_ID>/` |
| Autosave | Periodic interval (default 60s) | `autosave/<RUN_ID>/` (single dir, overwritten) |
| Agent-initiated | Agent runs `/package-branch` | `bundles/<EXPORT_TIME>[-<LABEL>]-<RUN_ID>/` |
| Operator-initiated | `make package-branch` | `bundles/<EXPORT_TIME>[-<SUMMARY>]-<RUN_ID>/` |

All path construction uses `export_path PARENT_DIR SUBDIR RUN_ID [LABEL]` in `routing.sh`. EXPORT_TIME is `date -u` at invocation.

### Output channels

Channels are named directories under `CHANGES_DIR` or `OUTPUT_DIR`:

| Channel | Directory | Used by |
|---|---|---|
| `session` | `CHANGES_DIR/session/` | `make draft` (default), `make apply` |
| `autosave` | `CHANGES_DIR/autosave/` | `make draft`, `make apply` |
| `bundles` | `OUTPUT_DIR/bundles/` | `make draft` |

---

## Operator workflow

### `make draft`

Creates a review branch from the host's current HEAD, applies `patches/*.diff` sequentially, then applies `uncommitted.diff` if present.

```
make draft [SESSION=<name>] [FROM=<channel>]
```

The draft branch is named `draft/<EXPORT_TIME>-<slug>-<sha6>`. A `.draft-state` file is committed as the first commit on the branch, recording source branch, from_hash, session identity, and diff count. The operator reviews the branch and reshapes commits with `git rebase -i`.

If any patch fails mid-series, a local savepoint tag (`draft-savepoint`) rolls the branch back to its pre-patch state. The savepoint is deleted on success or after rollback.

### `make confirm`

Rebases the draft branch onto the target (default: source branch recorded in `.draft-state`), drops the `.draft-state` commit, fast-forward merges, and deletes the draft branch.

```
make confirm [TARGET=<branch>]
```

A local savepoint tag (`confirm-savepoint`) protects against mid-rebase failure. On failure, the branch resets to the savepoint; on success, the tag is deleted.

### `make reject`

Discards the draft branch and returns to the source branch. Checkout and branch delete are chained atomically — if checkout fails, the draft branch is preserved and the operator can retry.

```
make reject
```

### `make apply`

Direct-apply of a diff file to the working tree without branch or commit overhead. Used for recovery and mid-session sync.

```
make apply [CHANNEL=<channel>] [DIFF=<path>]
```

Channel mode resolves a session directory and applies `uncommitted.diff` from it. Direct mode (`DIFF=<path>`) bypasses channel resolution entirely.

### Interactive mode

`make draft INTERACTIVE=1` and `make apply INTERACTIVE=1` provide numbered menus for channel and session selection.

---

## Host→container amendment

The operator can push amendments into a running container without restart:

1. `make package-branch SESSION_SUMMARY=<label>` — packages host changes
2. Artefacts land in `INPUT_DIR/bundles/<EXPORT_TIME>-<label>-<RUN_ID>/`
3. Agent reviews and applies inside container
4. Next `package-branch` includes the amendment in the commit series

---

## File map

| File | Role |
|---|---|
| `src/libs/diff.sh` | Diff primitives: `package_commits`, `write_uncommitted_diff`, `write_all_changes_diff`, `write_changed_files` |
| `src/libs/diff_export.sh` | Orchestrator: calls `package_branch`, writes `EXPORT-TIME.txt` and `.export-status` |
| `src/libs/package_branch.sh` | Entry point: resolves paths, calls diff primitives, writes artefacts |
| `src/libs/routing.sh` | Path construction (`export_path`), channel resolution, session resolution |
| `src/libs/draft_state.sh` | Draft branch metadata: read, write, validate `.draft-state` |
| `src/capability/entrypoint.sh` | Session export (EXIT trap), autosave loop |
| `scripts/workflows/draft.sh` | Host-side draft branch workflow |
| `scripts/workflows/confirm.sh` | Host-side confirm (rebase + merge) |
| `scripts/workflows/reject.sh` | Host-side reject (discard draft) |
| `scripts/workflows/apply.sh` | Host-side direct-apply workflow |
