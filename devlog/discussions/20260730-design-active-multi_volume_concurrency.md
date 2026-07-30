# Design — Multi-Volume Session Concurrency

**Status:** active

**Direction + Parent:** M2.6.2 — Volume and Container Persistence. Extend the named-volume persistence model to support multiple concurrent sessions from the same sandbox directory, with volume-per-session locking, container persistence, and an interactive volume selector.

## Context

M2.6.2 established volume-based session persistence using a single named Docker volume (`sandbox-data`) scoped to a compose project. The volume survives `make stop` / `make start` cycles, preserving the agent's git history and working tree. However, the model has two limitations:

1. **Single-session constraint.** Only one session can run per sandbox directory. The compose project name is derived from `SANDBOX_DIR`, so a second `make start` from the same directory would target the same compose project and collide on container names.

2. **No concurrent sessions.** Even with distinct compose project names, the model has no mechanism to select which volume to attach to — there is only one volume per sandbox directory.

## Current state

| Component | Current behavior |
|---|---|
| Volume naming | `<compose-project>_sandbox-data` — one volume per compose project |
| Compose project name | `agent-sandbox-<sha256(SANDBOX_DIR)[:6]>` — stable per sandbox dir |
| Session identity | `RUN_ID` (6-char hex), `SESSION_TS` — computed fresh or read from `.run-identity` |
| Container labels | `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.run-id`, `agent-sandbox.host-branch`, `agent-sandbox.session-ts` |
| Volume labels | `agent-sandbox.project-name`, `agent-sandbox.sandbox-dir`, `agent-sandbox.host-head-sha`, `agent-sandbox.host-branch` |

Container labels are already sufficient to disambiguate sessions. Volume labels exist but are not currently used for selection.

## Proposed extension

### Volume-per-session

Instead of one volume named `<project>_sandbox-data`, each session gets its own volume: `<project>-<run-id>_sandbox-data`. The `RUN_ID` is the natural differentiator — it's unique per session invocation.

The compose project name would incorporate `RUN_ID` instead of (or in addition to) `SANDBOX_DIR` hash. This gives each session its own compose namespace (volume, network, containers) without collision.

### Volume locking

A volume can only be attached to one running session at a time. Docker enforces this implicitly — two containers can mount the same named volume simultaneously, but the sandbox container writes to the volume and concurrent access would corrupt git state. The lock is enforced at the `make start` level: before starting, query running containers with the target volume's labels; if any are running, refuse to start.

### Interactive volume selector

When `make start` is invoked with no explicit session identifier, and more than one volume exists under the sandbox directory, present a numbered picker:

```
Available sessions:
  1) 20260730-130000 (RUN_ID: a1b2c3) — branch: feat-m2.6, host SHA: 2d69a4d
  2) 20260730-090000 (RUN_ID: d4e5f6) — branch: master, host SHA: dfed41d
  3) [start new session]
Select (1-3):
```

The selector reads volume labels to populate the list. The `[start new session]` option always appears. Volume identity is derived from the volume's labels (`agent-sandbox.session-ts`, `agent-sandbox.run-id`, `agent-sandbox.host-branch`, `agent-sandbox.host-head-sha`).

### Volume lifecycle

| Action | Volume behavior |
|---|---|
| `make start` (new) | Create new volume `<project>-<run-id>_sandbox-data` |
| `make start` (resume selected) | Reattach existing volume |
| `make stop` | Compose down, volume preserved |
| `make start REFRESH=1` | Pre-start: destroy selected volume. Create fresh volume. |
| `make prune` | Remove aged volumes with no running containers (same age threshold as other prune targets) |

## Integration points

### Compose template

The volume declaration moves from a static `sandbox-data` to a `RUN_ID`-scoped name. This requires the compose template to accept `RUN_ID` as a substitution variable for the volume name. Currently `RUN_ID` is already substituted for container names; adding it to the volume declaration is a single-line change.

### compose_args

The compose project name derivation changes from `sha256(SANDBOX_DIR)` to incorporate `RUN_ID`:

```
Current:  agent-sandbox-<sha256(SANDBOX_DIR)[:6]>
Proposed: agent-sandbox-<RUN_ID>
```

Using `RUN_ID` directly is simpler and already guaranteed unique per session invocation.

### Volume discovery

A new function in `compose.sh` (or a new script) queries Docker for volumes matching the sandbox directory label:

```bash
docker volume ls --filter "label=agent-sandbox.sandbox-dir=${SANDBOX_DIR}" --format '{{.Name}}'
```

Volume labels are set in the compose template at volume creation time. Labels are stable — they survive `compose down` — and are the same labels already applied to the current volume.

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

`stop.sh` already filters by `agent-sandbox.project-name` and `agent-sandbox.sandbox-dir` labels. With per-session compose projects, the project name changes per session. `stop.sh` would need to either:

- Accept `--run-id` to target a specific session (already supported), or
- Stop ALL sessions for the sandbox dir by filtering on `sandbox-dir` label only (current default)

The current default behavior — stop all containers for the sandbox dir — is correct for the multi-volume model. No change needed.

## Container persistence

`compose_stop` uses `docker compose stop` instead of `docker compose down`. Stopped containers persist in Docker's state, keeping their associated volumes marked as in-use. `stop.sh` drops its `docker rm` call. Containers age out naturally via `prune.sh` — volumes follow the same lifecycle.

## Decisions

These decisions were reached during the design review (session 20260730-03).

### Decision: Show all volumes in selector, flag stale ones

All volumes for the sandbox dir are shown in the interactive picker. Volumes whose `host-head-sha` doesn't match current HEAD are flagged as `[STALE]`. The operator decides whether to recover stale sessions or start fresh.

### Decision: Volume pruning via prune.sh

`prune.sh` includes volumes — label-filtered by `agent-sandbox.sandbox-dir`, aged by `PRUNE_AGE_DAYS`. Only prunes volumes with no associated containers (stopped or running). Container persistence makes this safe: a stopped container keeps its volume "in use" from Docker's perspective, preventing premature pruning.

### Decision: Volume name stability via .run-identity

`.run-identity` persists `RUN_ID` across restarts. `RUN_ID` only changes on `--refresh`/`--rebuild` (which deletes `.run-identity`). Volume names derived from `RUN_ID` are therefore stable across normal stop/start cycles. No additional mechanism needed.

### Decision: Cross-dir concurrency already works

Different sandbox dirs produce different compose project names today. No change needed for cross-directory concurrent sessions.
