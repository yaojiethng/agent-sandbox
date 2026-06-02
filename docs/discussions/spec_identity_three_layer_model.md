# Design Spec — Three-Layer Identity Model

**Status:** Approved (per session 11 of the original conversation)
**Associated commit:** `849a08e` (branch-only, not on mainline baseline)
**Date:** 2026-05-28

## Problem Statement

The agent-sandbox harness had a flat identity model: container names used `SESSION_TS` (a human-readable timestamp), while image names used `PROJECT_NAME` only. This caused:

1. **Image collision** — two sandboxes of the same project at different host commits rebuilt Docker images with the same tag, overwriting each other. This is a real risk when dogfooding agent-sandbox (harness repo == project repo) and working across host commits.

2. **No sandbox-instance identity** — the `WORKTREE_ID` was derived from `PROJECT_DIR` alone, so two sandboxes of the same project (`make onboard` to different `SANDBOX_DIR`s) were indistinguishable in terms of hashed identity.

3. **Verbose container names** — `sandbox-my-project-20260528-143000` is ~40 chars. A 6-char hash suffix is more readable in `docker ps`.

4. **Missing provenance** — `init_sha` (sandbox baseline commit) was written to `SESSION_STATE`, but the host HEAD commit at session start was not recorded there. Downstream scripts (apply, draft) had no way to determine the host commit the session branched from.

## Design — Three-Layer Model

The system has three distinct identity layers, each with its own primitives and derived identifiers:

### Layer 1: Host

| Primitive | Source | Purpose |
|---|---|---|
| `PROJECT_NAME` | User-provided at onboard | Human-readable project identifier |
| `PROJECT_DIR` | User-provided at onboard | Absolute path to project on host |

These are used as raw (unhashed) labels in Docker compose. No hash needed — they're human-readable identifiers consumed by operators and by `make stop`/`make prune` label filters.

### Layer 2: Sandbox

| Variable | Derivation | Purpose |
|---|---|---|
| `SANDBOX_DIR` | Operator-supplied at onboard | Absolute path to sandbox instance directory |
| `HOST_HEAD_SHA` | `git -C PROJECT_DIR rev-parse HEAD` | Host git HEAD at session start |
| **`SANDBOX_ID`** | `sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]` | 8-char hex hash identifying the sandbox instance at its branch point |

`SANDBOX_ID` is a derived identity. It is appended to Docker image names to prevent image collision when multiple sandboxes of the same project exist at different host commits.

**Why two inputs?** The sandbox is uniquely identified by *where* it lives (`SANDBOX_DIR`) and *where* it branched off (`HOST_HEAD_SHA`). Two sandboxes at different directories but the same HEAD are distinct. Same directory, different HEAD — that's a new sandbox state.

**Why 8 hex chars?** 32 bits of entropy with a 32:1 preimage-to-tag ratio before expected collision. Sufficient for sandbox-instance disambiguation. Can be bumped to 12 if needed.

### Layer 3: Container (Session Run)

| Variable | Derivation | Purpose |
|---|---|---|
| `SESSION_TS` | `date -u +%Y%m%d-%H%M%S` | Human-readable session timestamp (preserved in labels) |
| `SANDBOX_ID` | (from Layer 2) | Sandbox instance identity |
| **`RUN_ID`** | `sha256(SESSION_TS:SANDBOX_ID)[:6]` | 6-char hex hash for container names and output filenames |

`RUN_ID` replaces `SESSION_TS` in container names and artefact directory paths. `SESSION_TS` is retained in Docker labels for human readability and time-ordering.

Container names become:
- `sandbox-${PROJECT_NAME}-${RUN_ID}` (was `sandbox-${PROJECT_NAME}-${SESSION_TS}`)
- `${PROVIDER_NAME}-${PROJECT_NAME}-${RUN_ID}` (was `${PROVIDER_NAME}-${PROJECT_NAME}-${SESSION_TS}`)

Image names become:
- `sandbox-${PROJECT_NAME}-${SANDBOX_ID}` (was `sandbox-${PROJECT_NAME}`)
- `${PROVIDER_NAME}-agent-${PROJECT_NAME}-${SANDBOX_ID}` (was `${PROVIDER_NAME}-agent-${PROJECT_NAME}`)

Both functions accept an optional third `sandbox_id` argument for backward compatibility — if omitted, the old (unadorned) name is returned.

## Removed

- **`WORKTREE_ID`** — previously `sha256(PROJECT_DIR)[:8]`. Now superseded by `SANDBOX_ID` (derived from `SANDBOX_DIR` + `HOST_HEAD_SHA`). Checkpoint tag feature that used `WORKTREE_ID` was already removed in an earlier session.
- **`worktree_id_derive()`** — function removed from `image.sh`.
- **`REPO_COMMIT`** — renamed to `HOST_HEAD_SHA`.

## Preserved

- **`WORKTREE_ID` was NOT split** — there is no separate project-level hash kept alongside `SANDBOX_ID`. The checkpoint-tag feature that used `WORKTREE_ID` was already removed. `SANDBOX_ID` fully replaces it.
- **`SESSION_TS`** — remains in Docker labels and environment for human readability. Not removed from compose.
- **`init_sha`** — unchanged. Still written to `SESSION_STATE` as the sandbox baseline commit SHA.

## Key Design Decisions

### Why hash at all for image names?

The `SANDBOX_DIR` and `HOST_HEAD_SHA` values are long and messy for use in image tags. A short hash is machine-addressable and keeps `docker image ls` output readable. The hash is content-addressed: same inputs → same image tag, avoiding redundant rebuilds across restarts of the same sandbox session.

### Why double-hashing in RUN_ID is harmless

`RUN_ID = sha256(SESSION_TS:SANDBOX_ID)[:6]`. `SANDBOX_ID` is itself a hash, so this is a hash-of-a-hash. Sha256 is collision-resistant regardless of input structure — no information is lost. The alternative (hashing raw inputs directly) produces identical entropy per bit of output. No benefit to either approach; the current formulation is concise.

### Why SANDBOX_DIR is not renamed to WORKTREE_DIR

~296 references across production code. The cost of renaming doesn't justify the conceptual clarity gain when `SANDBOX_DIR` is well-understood throughout the codebase. The name "sandbox" aligns with the project domain (container names, image names, labels).

## Implementation Surface

### Production files

| File | Change |
|---|---|
| `scripts/start_agent.sh` | Rename `REPO_COMMIT` → `HOST_HEAD_SHA`. Add `SANDBOX_ID` and `RUN_ID` derivation. Container names use `RUN_ID`. Remove `WORKTREE_ID`. |
| `src/build/image.sh` | `sandbox_image_name(project[, sandbox_id])` returns `sandbox-<project>-<sandbox_id>`. `agent_image_name(provider, project[, sandbox_id])` returns `<provider>-agent-<project>-<sandbox_id>`. Remove `worktree_id_derive`. |
| `scripts/build.sh` | `build_agent`, `build_sandbox`, `preflight` accept optional `sandbox_id` arg; propagated to image name calls. |
| `src/build/compose.sh` | Add `{{RUN_ID}}` and `{{HOST_HEAD_SHA}}` sed substitutions alongside existing `{{SESSION_TS}}`. |
| `src/build/docker-compose.yml` | Add labels: `agent-sandbox.run-id`, `agent-sandbox.host-head-sha`, `agent-sandbox.sandbox-dir`. Add env vars: `RUN_ID`, `HOST_HEAD_SHA`, `SANDBOX_DIR`. |
| `src/capability/snapshot.sh` | Write `host_head_sha` to SESSION_STATE alongside `init_sha` and `session_ts`. |

### Test files

| File | Change |
|---|---|
| `tests/test_start_agent.sh` | Rewrite — 20 tests covering SANDBOX_ID derivation, RUN_ID derivation, image names with/without sandbox_id, compose labels, HOST_HEAD_SHA export. Remove all git-dependent fixtures (no git config needed). |
| `tests/test_checkpoint.sh` | **Removed** — tested deleted `worktree_id_derive` and checkpoint feature. |

### Documentation

| File | Change |
|---|---|
| `docs/concepts/sandbox_host_correspondence_model.md` | Identity table: `SANDBOX_ID`, `RUN_ID` replace `WORKTREE_ID`. Artefact paths: `<SESSION_TS>` → `<RUN_ID>`. Container labels: add `project-name`, `project-dir`, `sandbox-dir`, `host-head-sha`, `run-id`. |
| `docs/architecture/tool_interface.md` | `SESSION_TS` references in output paths → `RUN_ID`. Draft branch naming. |
| `docs/architecture/execution_model.md` | Session-diffs directory naming in diagrams. |
| `docs/architecture/sandbox_lifecycle.md` | Session-diffs paths and draft branch naming. |
| `docs/architecture/system_overview.md` | Diff pipeline output path. |
| `devlog/roadmap.md` | Track A item 1 updated with full spec. |

## Upstream Implications

### Docker label schema (for `make stop` and `make prune`)

The compose template now exports these labels on all containers:

```
agent-sandbox.project-dir: <raw path>
agent-sandbox.project-name: <name>
agent-sandbox.sandbox-dir: <raw path>
agent-sandbox.host-head-sha: <40-char hex>
agent-sandbox.host-branch: <sanitised branch>
agent-sandbox.session-ts: <timestamp>
agent-sandbox.run-id: <6-char hex>
```

`make stop` and `make prune` can filter by `project-name` + `sandbox-dir` labels using Docker's label filter mechanism rather than relying on container name patterns.

### SESSION_STATE schema

Added key to the SESSION_STATE file:

```
init_sha=<40-char sandbox baseline SHA>
session_ts=<timestamp>
host_head_sha=<40-char host HEAD SHA>
```

This enables downstream scripts (apply, draft) running on the host to determine the exact host commit the session branched from, without needing the variable passed in from the session runtime.
