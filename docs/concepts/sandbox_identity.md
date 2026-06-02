# Sandbox Identity Model

The agent-sandbox harness uses a content-addressed identity model with three scopes: project-level identity, sandbox-instance identity, and session-run identity. This document defines the primitives, derivation rules, and consumption patterns.

## Primitives

| Primitive | Derivation | Scope | Purpose |
|---|---|---|---|
| `PROJECT_NAME` | User-provided at `onboard` | Host | Human-readable project identifier. Used in container names, image names, labels. |
| `PROJECT_DIR` | User-provided at `onboard` | Host | Absolute path to the project directory on the host. Used for git operations and path derivation. |
| `SANDBOX_DIR` | Operator-supplied at `onboard` (defaults to `PROJECT_DIR-sandbox`) | Sandbox instance | Absolute path to the sandbox instance directory on the host. The identity factor that distinguishes parallel worktree sessions. |
| `HOST_HEAD_SHA` | `git -C PROJECT_DIR rev-parse HEAD` | Sandbox instance | Full SHA of the host git HEAD at session start. Records the branch point for provenance tracking. |
| `SESSION_TS` | `date -u +%Y%m%d-%H%M%S` | Session run | Human-readable session timestamp. Retained in Docker labels and environment for operator inspection, not used for identity derivation. |

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
| Sandbox (base) image | `sandbox-<project>-<sandbox_id>` | `sandbox-agent-sandbox-a1b2c3d4` |
| Agent image | `<provider>-agent-<project>-<sandbox_id>` | `pi-agent-sandbox-a1b2c3d4` |
| Sandbox container | `sandbox-<project>-<run_id>` | `sandbox-agent-sandbox-f6e5d4` |
| Agent container | `<provider>-<project>-<run_id>` | `pi-agent-sandbox-f6e5d4` |

Image naming functions accept an optional `sandbox_id` argument. When omitted, the unadorned name (`sandbox-<project>`, `<provider>-agent-<project>`) is returned for backward compatibility.

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

## SESSION_STATE Schema

Written to the sandbox git repository's state file at container init:

```
init_sha=<40-char sandbox baseline commit SHA>
session_ts=<timestamp>
host_head_sha=<40-char host HEAD SHA>
```

`host_head_sha` enables downstream scripts (apply, draft) running on the host to determine the exact host commit the session branched from, without needing the variable passed in from the session runtime.

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
| `SANDBOX_ID` | `SANDBOX_DIR:HOST_HEAD_SHA` hash | Image names, `RUN_ID` derivation |
| `RUN_ID` | `SESSION_TS:SANDBOX_ID` hash | Container names, artefact paths, Docker labels |
