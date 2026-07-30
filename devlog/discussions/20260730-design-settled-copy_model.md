# Design — Copy Model (Volume-backed Sandbox)

**Status:** active

**Direction + Parent:** M2.6.5 — Copy Model: Volume-backed Sandbox. Defines the volume-based persistence and concurrency model that is the current default and the actively-implemented path. Companion to [`20260730-design-settled-mount_model.md`](20260730-design-settled-mount_model.md) (M2.6.6 — Mount Model).

## Context

The copy model is the current default: the host snapshot is unpacked into a named Docker volume, the agent works inside the volume, and changes are exported through the diff pipeline. M2.6.2 established volume-based persistence — the volume survives `make stop` / `make start` cycles, preserving the agent's git history and working tree.

Two extensions are in progress:

1. **Container persistence.** Containers persist in stopped state alongside volumes, sharing a unified lifecycle in `prune.sh`.
2. **Multi-volume concurrency.** Volume-per-session via `RUN_ID`-scoped compose projects with locking and an interactive selector.

## Current state

| Component | Current behavior |
|---|---|
| Volume naming | `<compose-project>_sandbox-data` — one volume per compose project |
| Compose project name | `agent-sandbox-<sha256(SANDBOX_DIR)[:6]>` — stable per sandbox dir |
| Session identity | `RUN_ID` (6-char hex), `SESSION_TS` — computed fresh or read from `.run-identity` |
| Container lifecycle | `compose_stop` → `docker compose stop` (preserves containers); `stop.sh` → `docker stop` (no `rm`) |
| Container labels | `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.run-id`, `agent-sandbox.host-branch`, `agent-sandbox.session-ts` |
| Volume labels | `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.host-head-sha`, `agent-sandbox.host-branch` |

Container labels are already sufficient to disambiguate sessions. Volume labels exist but are not currently used for selection.

## Proposed extension

### Volume-per-session

Instead of one volume named `<project>_sandbox-data`, each session gets its own volume: `<project>-<run-id>_sandbox-data`. The `RUN_ID` is the natural differentiator — it's unique per session invocation.

The compose project name incorporates `RUN_ID` instead of the `SANDBOX_DIR` hash. This gives each session its own compose namespace (volume, network, containers) without collision.

### Volume locking

A volume can only be attached to one running session at a time. Two containers can mount the same named volume simultaneously, but concurrent access would corrupt git state. The lock is enforced at `make start`: before starting, query running containers with the target volume's labels; if any are running, refuse to start.

### Interactive volume selector

When `make start` is invoked with no explicit session identifier, and more than one volume exists under the sandbox directory, present a numbered picker:

```
Available sessions:
  1) 20260730-130000 (RUN_ID: a1b2c3) — branch: feat-m2.6, host SHA: 2d69a4d
  2) 20260730-090000 (RUN_ID: d4e5f6) — branch: master, host SHA: dfed41d [STALE]
  3) [start new session]
Select (1-3):
```

The selector reads volume labels to populate the list. The `[start new session]` option always appears. Volumes whose `host-head-sha` doesn't match current HEAD are flagged as `[STALE]`. Volume identity is derived from labels (`agent-sandbox.session-ts`, `agent-sandbox.run-id`, `agent-sandbox.host-branch`, `agent-sandbox.host-head-sha`).

### Volume lifecycle

| Action | Volume behavior |
|---|---|
| `make start` (new) | Create new volume `<project>-<run-id>_sandbox-data` |
| `make start` (resume selected) | Reattach existing volume |
| `make stop` | Compose stop, volume + containers preserved |
| `make start REFRESH=1` | Pre-start: destroy selected volume. Create fresh volume |
| `make prune` | Remove aged volumes with no associated containers (stopped or running) |

## Integration points

### Compose template

The volume declaration moves from a static `sandbox-data` to a `RUN_ID`-scoped name. `RUN_ID` is already substituted for container names; adding it to the volume declaration is a single-line change.

### compose_args

The compose project name derivation changes:

```
Current:  agent-sandbox-<sha256(SANDBOX_DIR)[:6]>
Proposed: agent-sandbox-<RUN_ID>
```

`RUN_ID` is simpler and already guaranteed unique per session invocation.

### Volume discovery

```bash
docker volume ls --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" --format '{{.Name}}'
```

Volume labels are set in the compose template at creation time, survive `compose down`, and are the same labels already applied to the current volume.

### start_agent.sh flow

```
1. compute/read session identity (RUN_ID, SESSION_TS) — unchanged
2. if --session flag: use that volume directly, skip selector
3. else: query volumes by sandbox-dir label
   a. zero volumes: new session (fresh snapshot)
   b. one volume: resume that volume (current behavior)
   c. multiple volumes: interactive picker
4. derive compose project name from selected/resumed RUN_ID
5. snapshot pipeline (new) or skip (resume)
6. dispatch to run_agent.sh with compose project name + volume identity
```

### stop.sh behavior

`stop.sh` already filters by `agent-sandbox.project-name` and `agent-sandbox.sandbox-dir` labels. With per-session compose projects, the default behavior — stop all containers for the sandbox dir by `sandbox-dir` label — is correct for the multi-volume model. No change needed. `--run-id` targets a specific session.

## Decisions

All decisions resolved during design review (session 20260730-03).

### Decision: Show all volumes, flag stale ones

All volumes for the sandbox dir are shown. Mismatched `host-head-sha` entries are flagged `[STALE]`. Operator decides whether to recover or start fresh.

### Decision: Volume pruning via prune.sh

`prune.sh` includes volumes — label-filtered by `agent-sandbox.sandbox-dir`, aged by `PRUNE_AGE_DAYS`. Only prunes volumes with no associated containers. Container persistence prevents premature pruning: a stopped container keeps its volume "in use."

### Decision: Volume name stability via .run-identity

`.run-identity` persists `RUN_ID` across restarts. `RUN_ID` only changes on `--refresh`/`--rebuild`. Volume names derived from `RUN_ID` are stable across normal stop/start cycles.

### Decision: Cross-dir concurrency already works

Different sandbox dirs produce different compose project names today. No change needed.

## References

| Document | Purpose |
|---|---|
| [`devlog/discussions/20260730-design-settled-mount_model.md`](20260730-design-settled-mount_model.md) | Mount model (M2.6.6) — companion design doc |
| [`devlog/roadmap.md`](../roadmap.md) | M2.6.5 task list |
| [`docs/architecture/security.md`](../architecture/security.md) | Security posture — Copy + fresh baseline configuration |
| [`docs/architecture/sandbox_lifecycle.md`](../architecture/sandbox_lifecycle.md) | Snapshot pipeline, resume path |
