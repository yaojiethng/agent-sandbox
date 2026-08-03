# Design — Diff Packaging and Export Pipeline

**Purpose:** Consolidated design for the diff packaging pipeline — how agent changes are exported from the container, how the operator applies them to the host, and the path conventions that connect the two. Supersedes `story_diff_pipeline_unification.md` and `design_unified_path_derivation.md`.

**Status:** Open

---

## Architecture

### Two primitives, one format

All diff packaging in agent-sandbox produces the same artefact set using the same primitives in `src/libs/diff.sh`:

| Artefact | Content | How produced |
|---|---|---|
| `patches/*.diff` | One `.diff` per agent commit since `init_sha`, numbered sequentially | `package_commits` |
| `uncommitted.diff` | Working tree delta from HEAD (uncommitted changes) | `write_uncommitted_diff` |
| `all-changes.diff` | Net delta from `init_sha` (committed + uncommitted) | `write_all_changes_diff` |
| `changed-files/` | Full file copies of every changed file with `MANIFEST.txt` | `write_changed_files` |
| `EXPORT-TIME.txt` | Wall-clock timestamp of the export | `diff_export` |
| `.export-status` | SUCCESS/FAIL with timestamp and exit code | `diff_export` |

All diffs are unified format with index lines stripped — consumed by `git apply` in both directions (sandbox→host and host→sandbox). No git metadata is embedded. The format is git-agnostic: the consumer does not need the producer's git history.

### Export mechanisms

There are two export mechanisms, distinguished by trigger:

| Mechanism | Trigger | Path function | Produces |
|---|---|---|---|
| **Session export** | Capability container EXIT trap | `export_path` → `session/<EXPORT_TIME>-<RUN_ID>/` | All artefacts via `diff_export` → `package_branch` |
| **Autosave** | Periodic interval (default 60s) | `export_path` → `autosave/<RUN_ID>/` | All artefacts via `diff_export` → `package_branch` (single dir, overwritten) |

Both use the same `diff_export` → `package_branch` pipeline. The difference is only where and when they write.

### Agent-initiated exports

The agent has one export tool: `/package-branch`. It runs `package_branch.sh` which produces the same artefact set into `OUTPUT_DIR/bundles/<EXPORT_TIME>[-<LABEL>]-<RUN_ID>/`.

| Tool | Trigger | Path |
|---|---|---|
| `/package-branch` | Agent invokes manually | `bundles/<EXPORT_TIME>[-<LABEL>]-<RUN_ID>/` |

There is no `/package-diff`. The agent does not need two tools that produce identical output.

### Path conventions

All export paths use a single function, `export_path PARENT_DIR SUBDIR RUN_ID [LABEL]`:

| Mechanism | Path | EXPORT_TIME | RUN_ID | LABEL |
|---|---|---|---|---|
| Session export | `session/<EXPORT_TIME>-<RUN_ID>/` | `date -u` at stop | mandatory | — |
| Autosave | `autosave/<RUN_ID>/` | inside `EXPORT-TIME.txt` | mandatory | — |
| Package branch | `bundles/<EXPORT_TIME>[-<LABEL>]-<RUN_ID>/` | `date -u` at invocation | mandatory | optional |

`EXPORT-TIME.txt` inside each directory records the exact wall-clock time of the write, regardless of the directory naming convention.

---

## Operator workflow

### `make draft`

The primary review workflow. Resolves a session directory from a channel (`session`, `autosave`, `bundles`), creates a draft branch from the host's current HEAD, applies `patches/*.diff` sequentially, then applies `uncommitted.diff` if present.

```
make draft [SESSION=<name>] [FROM=<channel>]
```

The operator reviews the draft branch, reshapes commits with `git rebase -i`, then:

```
make confirm [TARGET=<branch>]   # rebase + fast-forward merge to target
make reject                      # discard draft branch, return to source
```

Draft branches are named `draft/<EXPORT_TIME>-<slug>-<sha6>`. `.draft-state` metadata on the branch records the source channel, session name, and patch count for audit.

### `make apply`

Direct-apply for recovery and mid-session sync. Applies a single diff file to the host working tree without creating a branch or committing.

```
make apply [CHANNEL=<channel>] [DIFF=<path>]
```

Channel mode resolves a session directory and applies `uncommitted.diff` from it. Direct mode (`DIFF=<path>`) bypasses all channel resolution.

### Channels

Channels are named directories under `CHANGES_DIR` or `OUTPUT_DIR` that contain session export directories:

| Channel | Directory | Used by |
|---|---|---|
| `session` | `CHANGES_DIR/session/` | `make draft` (default), `make apply` |
| `autosave` | `CHANGES_DIR/autosave/` | `make draft`, `make apply` |
| `bundles` | `OUTPUT_DIR/bundles/` | `make draft` |

Channel resolution is provided by `resolve_channel_base_dir` in `routing.sh`. The `diffs` channel (formerly `OUTPUT_DIR/diffs/`) was removed — it existed only for `package-diff` output and is redundant with `bundles/`.

### Interactive mode

`make draft INTERACTIVE=1` and `make apply INTERACTIVE=1` provide numbered menus for channel and session selection instead of requiring explicit flags. The picker displays session directories with availability indicators (patches present, uncommitted present).

**Future:** After channel-mode removal from `make apply`, the interactive picker could let the operator drill into a session directory and pick a specific file (`uncommitted.diff`, `all-changes.diff`, or an individual patch).

---

## Host→container (amendment workflow)

The operator can push amendments into a running container without restart:

1. Operator packages host changes: `make package-branch SESSION_SUMMARY=<label>`
2. Artefacts land in `INPUT_DIR/bundles/<EXPORT_TIME>-<label>-<RUN_ID>/`
3. Agent reviews and applies inside container
4. Next `package-branch` includes the amendment in the commit series

This is the symmetric counterpart to `make draft` — same artefact format, same `git apply` consumer, opposite direction.

---

## Design decisions

### Why package-branch instead of package-diff

`package-branch` is a strict superset of `package-diff`. Both produce `uncommitted.diff`, `all-changes.diff`, and `changed-files/`. `package-branch` additionally produces per-commit `patches/*.diff` — the primary artefact for the review workflow.

Maintaining two scripts that produce overlapping output from the same underlying primitives (`diff.sh`) is pure duplication cost: two code paths to test, two prompt templates to maintain, two concepts for the agent and operator to learn.

Removing `package-diff` simplifies the system with no capability loss. The agent has one export tool (`/package-branch`). The operator has one host-side export (`make package-branch`).

### Why per-commit patches instead of a single diff

Individual per-commit patches enable the operator to review, reorder, squash, and drop agent commits — the standard `git rebase -i` workflow. A single monolithic diff would lose the agent's intentionally-shaped commit history.

### Why index lines are stripped

Index lines (`index abc..def 100644`) are git-internal metadata tied to the producer's object store. They are meaningless to the consumer and cause `git apply` failures when the consumer's index doesn't match. Stripping them makes diffs portable across repositories.

### Why no sweep commit

The export pipeline does not create a sweep commit — uncommitted changes are captured via `git diff HEAD` and remain in the working tree. This preserves the agent's workspace state across exports. The operator's `make draft` applies them as unstaged changes on the draft branch.

---

## File map

| File | Role |
|---|---|
| `src/libs/diff.sh` | Diff primitives: `package_commits`, `write_uncommitted_diff`, `write_all_changes_diff`, `write_changed_files` |
| `src/libs/diff_export.sh` | Orchestrator: calls `package_branch`, writes `EXPORT-TIME.txt` and `.export-status` |
| `src/libs/package_branch.sh` | Entry point: resolves paths, calls diff primitives, writes artefacts |
| `src/libs/routing.sh` | Path construction (`export_path`), channel resolution, session resolution |
| `src/capability/entrypoint.sh` | Session export (EXIT trap), autosave loop |
| `scripts/workflows/draft.sh` | Host-side draft branch workflow |
| `scripts/workflows/apply.sh` | Host-side direct-apply workflow |

---

## Acceptance criteria

1. `package_diff.sh`, `package-diff.md`, and `test_package_diff.sh` are deleted
2. No remaining `package-diff` or `package_diff` references in code or docs (grep confirms)
3. `diffs` channel removed from `resolve_channel_base_dir`
4. All shell scripts pass `bash -n`
5. Existing tests pass: `test_routing.sh`, `test_dispatch.sh`, `test_package_branch.sh`, `test_diff_dispatch.sh`
6. `make draft` and `make apply` continue to work with `session`, `autosave`, `bundles` channels
