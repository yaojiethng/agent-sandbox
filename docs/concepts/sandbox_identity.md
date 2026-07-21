# Sandbox Identity Model

The agent-sandbox harness uses a content-addressed identity model with three scopes: project-level identity, sandbox-instance identity, and session-run identity. This document defines the primitives, derivation rules, and consumption patterns.

## Primitives

| Primitive | Derivation | Scope | Purpose |
|---|---|---|---|
| `PROJECT_NAME` | User-provided at `onboard` | Host | Human-readable project identifier. Used in container names, image names, labels. |
| `PROJECT_DIR` | User-provided at `onboard` | Host | Absolute path to the project directory on the host. Used for git operations and path derivation. |
| `SANDBOX_DIR` | Operator-supplied at `onboard` (defaults to `PROJECT_DIR-sandbox`) | Sandbox instance | Absolute path to the sandbox instance directory on the host. The identity factor that distinguishes parallel worktree sessions. |
| `HOST_HEAD_SHA` | `git -C PROJECT_DIR rev-parse HEAD` at first start; persisted in `.run-identity` | Sandbox instance | Full SHA of the host git HEAD at session start. Records the branch point for provenance tracking. On resume, read from `.run-identity`, not recomputed. |
| `SESSION_TS` | `date -u +%Y%m%d-%H%M%S` at first start; persisted in `.run-identity` | Session run | Human-readable session timestamp. On resume, read from `.run-identity` to ensure consistency with the volume's SESSION_STATE. |

## Derived Identifiers

### SANDBOX_ID — Sandbox Instance Identity

```
SANDBOX_ID = sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]
```

An 8-character hex hash that identifies a specific sandbox instance at a specific host commit. Appended to Docker image names to prevent image collision when multiple sandboxes of the same project exist at different host commits.

**Properties:**
- Two sandboxes at different directories but the same `HOST_HEAD_SHA` produce different `SANDBOX_ID`s.
- Same directory, different `HOST_HEAD_SHA` produces a different `SANDBOX_ID` — a new sandbox state.
- 32 bits of entropy (8 hex chars), sufficient for sandbox-instance disambiguation. Collision risk is 32:1 preimage-to-tag ratio before expected collision.

### RUN_ID — Session Run Identity

```
RUN_ID = sha256(SESSION_TS:SANDBOX_ID)[:6]
```

A 6-character hex hash that identifies a single session run. Replaces `SESSION_TS` in container names and output artefact paths while `SESSION_TS` is preserved in labels for human readability.

**Properties:**
- Unique per session even with the same sandbox instance and branch (timestamp component).
- Deterministic: same inputs produce same `RUN_ID`.
- 24 bits of entropy (6 hex chars), sufficient for session disambiguation within a sandbox instance.

## Container and Image Naming

| Entity | Format | Example |
|---|---|---|
| Sandbox (base) image | `sandbox-<project>` | `sandbox-agent-sandbox` |
| Agent image | `<provider>-agent-<project>` | `pi-agent-sandbox` |
| Sandbox container | `sandbox-<project>-<run_id>` | `sandbox-agent-sandbox-f6e5d4` |
| Agent container | `<provider>-<project>-<run_id>` | `pi-agent-sandbox-f6e5d4` |

Images are tagged by harness code identity, not project repo state. Project repo state is captured at runtime by the snapshot pipeline. Provenance for past sessions is carried by Docker labels (`agent-sandbox.host-head-sha`, `agent-sandbox.sandbox-dir`, `agent-sandbox.run-id`), not by image tags.

## Docker Label Schema

The compose template exports the following labels on all containers:

```
agent-sandbox.project-name:     <PROJECT_NAME>
agent-sandbox.project-dir:      <PROJECT_DIR>
agent-sandbox.sandbox-dir:      <SANDBOX_DIR>
agent-sandbox.host-head-sha:    <HOST_HEAD_SHA>
agent-sandbox.host-branch:      <sanitised branch name>
agent-sandbox.session-ts:       <SESSION_TS>
agent-sandbox.run-id:           <RUN_ID>
```

These labels serve two purposes:
- **Provenance:** Operators can inspect any container to determine which project, worktree, host commit, and session run it belongs to.
- **Lifecycle management:** `make stop` and `make prune` filter by `project-name` + `sandbox-dir` labels to scope operations to a specific worktree.

## Container-sig (Image Staleness Detection)

Images carry an `agent-sandbox.container-sig` Docker label that records a SHA-256 hash of the source files that populate the image's `/opt/sandbox/` and `/opt/workflow/` directories at build time. This hash is computed in `scripts/build.sh` by the `container_sig()` function and injected as a `--label` at build time.

### Derivation

For the sandbox image, the hash covers all files under these repo-relative paths:
- `src/libs/` (→ `/opt/sandbox/lib/`)
- `src/capability/entrypoint.sh` (→ `/opt/sandbox/bin/sandbox-entrypoint.sh`)
- `src/capability/snapshot.sh` (→ `/opt/sandbox/lib/snapshot.sh`)
- `docs/architecture/` (→ `/opt/sandbox/docs/architecture/`)
- `docs/concepts/` (→ `/opt/sandbox/docs/concepts/`)

For an agent image, the hash covers:
- `src/libs/` (→ `/opt/sandbox/lib/`)
- `src/reasoning/entrypoint.sh` (→ `/opt/sandbox/bin/provider-entrypoint.sh`)
- `src/reasoning/providers/<n>/preflight.sh` (if exists → `/opt/sandbox/bin/provider-preflight.sh`)
- `src/reasoning/agent/skills/` (→ `/opt/workflow/agent/skills/`)
- `src/reasoning/agent/prompts/` (→ `/opt/workflow/agent/prompts/`)
- `src/reasoning/providers/<n>/config/` (if exists → `/opt/workflow/agent/config/`)
- `docs/architecture/` (→ `/opt/sandbox/docs/architecture/`)
- `docs/concepts/` (→ `/opt/sandbox/docs/concepts/`)

### Preflight check

The `preflight()` function in `scripts/build.sh` reads the baked `agent-sandbox.container-sig` label from existing images, re-computes it from current source files, and warns on mismatch. The check is non-blocking (warning only) — stale images are not an error to avoid blocking development workflows.

### Scope

Container-sig covers only the sandbox image and tier-3 agent images (the final provider image in the three-tier build). Tier 1 (shared node base) and tier 2 (provider base) images do not carry `/opt/sandbox/` or `/opt/workflow/` content and therefore have no container-sig label.

Harness-sig (runtime drift detection for the harness binary itself) is deferred to a future milestone.


## `.run-identity` (persistence file)

Written to `$SANDBOX_DIR/.run-identity` at first start. Read on resume to ensure host-side env vars match the volume's SESSION_STATE. Deleted on `REFRESH=1`.

```
SESSION_TS=20260622-104203
RUN_ID=abc123
HOST_HEAD_SHA=deadbeef0123456789abcdef0123456789abcdef
SANDBOX_ID=12345678
```

On resume, `start_agent.sh` reads this file and exports the values as env vars instead of recomputing them. This guarantees that `diff_export` (reads env vars at teardown) and `package_branch` (reads SESSION_STATE from the volume) use the same identity values.

## SESSION_STATE Schema

Written to the sandbox git repository's state file at container init (first start only):

```
init_sha=<40-char sandbox baseline commit SHA>
session_ts=<timestamp>
host_head_sha=<40-char host HEAD SHA>
run_id=<6-char session run ID>
```

`host_head_sha` enables downstream scripts (apply, draft) running on the host to determine the exact host commit the session branched from, without needing the variable passed in from the session runtime. `run_id` is read by `package_branch` and `package_diff` to construct output paths consistent with the session's diff exports.

## Artefact Paths

| Artefact | Path | Notes |
|---|---|---|
| Session diff export | `session-diffs/session/<RUN_ID>-<BRANCH>/` | Written on container exit |
| Autosave diffs | `session-diffs/autosave/<RUN_ID>-<BRANCH>/` | Written on autosave ticks |
| Package-diff output | `output/diffs/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | On explicit diff packaging |
| Package-branch output | `output/bundles/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | On explicit branch packaging |

`RUN_ID` replaces `SESSION_TS` in artefact directory names. The branch name component (when present) provides human-readable context; `RUN_ID` provides unique addressing.

## Where Primitives Are Consumed

| Primitive | Derived from | Consumed by |
|---|---|---|
| `PROJECT_NAME` | User input | Image names, container names, Docker labels, compose project name |
| `PROJECT_DIR` | User input | git operations, `HOST_HEAD_SHA` derivation, Docker labels |
| `SANDBOX_DIR` | Operator-supplied | `SANDBOX_ID` derivation, Docker labels, workspace path derivation |
| `HOST_HEAD_SHA` | `git rev-parse HEAD` | `SANDBOX_ID` derivation, SESSION_STATE, Docker labels |
| `SESSION_TS` | `date -u` | `RUN_ID` derivation, Docker labels |
| `SANDBOX_ID` | `SANDBOX_DIR:HOST_HEAD_SHA` hash | `RUN_ID` derivation |
| `RUN_ID` | `SESSION_TS:SANDBOX_ID` hash | Container names, artefact paths, Docker labels |
