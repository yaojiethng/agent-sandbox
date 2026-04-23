# Design — Hash-Based Session Identity

**Status:** Active

**Supersedes:** [`story_session_identity_and_harness_versioning.md`](../devlog/discussions/story_session_identity_and_harness_versioning.md)

---

## Context

The harness currently uses timestamps (`SESSION_TS`) for container naming and session-scoped artefacts. Timestamps are long (15 chars), not memorable, and don't encode identity factors. This design replaces timestamp-based naming with a short hash (`run_id`) that encodes the session's primitive identity factors.

---

## Design

### Primitive Set

Three primitives, established once per session at the top of `scripts/start_agent.sh`:

| Primitive | Value | Source |
|---|---|---|
| `SESSION_TS` | `$(date -u +%Y%m%d-%H%M%S)` | Timestamp |
| `REPO_COMMIT` | `git -C "$PROJECT_DIR" rev-parse HEAD` | Full commit SHA |
| `WORKTREE_ID` | `$(echo "$PROJECT_DIR" \| sha256sum \| cut -c1-8)` | 8-char hex hash of PROJECT_DIR absolute path |

### run_id Derivation

```bash
export RUN_ID; RUN_ID=$(echo "${SESSION_TS}:${REPO_COMMIT}:${WORKTREE_ID}" | sha256sum | cut -c1-6)
```

**Properties:**
- 6-character hex hash (16^6 = ~16M combinations)
- Encodes session timestamp, repo state, and worktree path
- Unique per session even with same branch/worktree (timestamp component)
- Same session factors always produce same run_id (deterministic)

### Container Naming

| Container | Format | Example |
|---|---|---|
| Sandbox | `sandbox-<project>-<runid>` | `sandbox-agent-sandbox-a1b2c3` |
| Agent | `<provider>-<project>-<runid>` | `pi-agent-sandbox-a1b2c3` |

**Replaces:**
- Old: `sandbox-<project>-<timestamp>` (e.g., `sandbox-agent-sandbox-20260423-143022`)
- Old: `<provider>-<project>-<timestamp>` (e.g., `pi-agent-sandbox-20260423-143022`)

### Docker Labels

All containers receive these labels for lifecycle management:

```yaml
labels:
  agent-sandbox.project: <project-name>
  agent-sandbox.worktree-id: <worktree-id>
  agent-sandbox.run-id: <run-id>
  agent-sandbox.session-name: <sanitized-branch>-<session-ts>  # retained for backwards compat
```

**Rationale:**
- `project` and `worktree-id` together identify all sessions for a project from a specific worktree
- `run-id` identifies a single session uniquely
- `session-name` retained for backwards compatibility with existing artefact directories

### Session-Scoped Artefacts

| Artefact | Path | Notes |
|---|---|---|
| Diff output | `workspace/session-diffs/<branch-name>/` | Branch-based, not run_id-based |
| Draft branch | `draft/<source-branch>-<session-ts>` | Retains timestamp for readability |
| Session artefacts | `workspace/output/<run-id>/` | New: use run_id instead of session name |

**Rationale:**
- Diff packaging uses branch name (not session identity) for grouping commits by branch
- Draft branches retain timestamp for human readability in `git log`
- Session output directories use run_id for uniqueness and brevity

---

## make stop Redesign

### Current Behaviour

```bash
# Current: stops all containers for project name (all worktrees)
COMPOSE_PROJECT="$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]')"
COMPOSE_PROJECT="${_COMPOSE_PROJECT//[^a-z0-9-]/-}"
docker ps -aq --filter "label=com.docker.compose.project=${COMPOSE_PROJECT}"
```

### New Behaviour

```bash
# New: stops containers for project + worktree combination
WORKTREE_ID=$(echo "$PROJECT_DIR" | sha256sum | cut -c1-8)
CONTAINER_IDS=$(docker ps -aq \
  --filter "label=agent-sandbox.project=${PROJECT_NAME}" \
  --filter "label=agent-sandbox.worktree-id=${WORKTREE_ID}")
```

**Rationale:**
- Same project from same worktree → same containers stopped
- Same project from different worktree (parallel sessions) → different containers
- Prevents stopping containers from parallel worktrees

---

## make prune Design

### Targeted Cleanup

```bash
# Clean up old containers/images/volumes for project + worktree
WORKTREE_ID=$(echo "$PROJECT_DIR" | sha256sum | cut -c1-8)

# Stop and remove old containers
docker ps -aq --filter "label=agent-sandbox.project=${PROJECT_NAME}" \
  --filter "label=agent-sandbox.worktree-id=${WORKTREE_ID}" \
  --filter "until=$(date -d '3 days ago' -u +%Y-%m-%dT%H:%M:%SZ)" | \
  xargs -r docker rm

# Remove old images (dangling or unused)
docker image prune -f

# Remove old volumes
docker volume prune -f
```

### Time-Based Cleanup

```bash
# Clean up containers older than 3 days for project (ignores worktree)
docker ps -aq --filter "label=agent-sandbox.project=${PROJECT_NAME}" \
  --filter "until=$(date -d '3 days ago' -u +%Y-%m-%dT%H:%M:%SZ)" | \
  xargs -r docker rm

# Clean up old images
docker image prune -f --filter "until=3d"

# Clean up old volumes
docker volume prune -f --filter "until=3d"
```

**Rationale:**
- Targeted cleanup respects worktree boundaries (parallel sessions)
- Time-based cleanup prevents indefinite accumulation of old artefacts
- 3-day threshold balances disk usage with debugging capability

---

## Implementation Tasks

### Phase 1: run_id Derivation

- [ ] Add `RUN_ID` derivation to `scripts/start_agent.sh` (after primitive set)
- [ ] Export `RUN_ID` for downstream use
- [ ] Update `libs/compose.sh` to substitute `{{RUN_ID}}` placeholder

### Phase 2: Container Naming

- [ ] Update `scripts/start_agent.sh` container name derivation to use `RUN_ID`
- [ ] Update `libs/docker-compose.yml` to use `{{RUN_ID}}` in container_name
- [ ] Update `libs/compose.sh` documentation

### Phase 3: Docker Labels

- [ ] Add `agent-sandbox.project`, `agent-sandbox.worktree-id`, `agent-sandbox.run-id` labels to `libs/docker-compose.yml`
- [ ] Retain `agent-sandbox.session-name` for backwards compatibility

### Phase 4: make stop Redesign

- [ ] Update `scripts/stop.sh` to filter by `project + worktree-id` labels
- [ ] Update `libs/_templates/Makefile.template` stop target documentation

### Phase 5: make prune Implementation

- [ ] Add `prune` target to `libs/_templates/Makefile.template`
- [ ] Create `scripts/prune.sh` with targeted and time-based cleanup logic
- [ ] Add `agent-sandbox prune` CLI command

### Phase 6: Session Artefacts

- [ ] Update session output directory naming to use `RUN_ID`
- [ ] Update `libs/diff.sh` documentation for new artefact paths

---

## Backwards Compatibility

| Component | Migration Path |
|---|---|
| Existing containers | Continue to work; new sessions use run_id naming |
| Existing artefact directories | Retain session-name-based paths; new sessions may use run_id |
| `SESSION_NAME` | Retained for backwards compatibility in Docker labels |
| Draft branches | Retain timestamp-based naming for human readability |

---

## Open Questions

1. **Hash collision handling:** 6-char hex has ~16M combinations. Should we add collision detection (check if run_id already exists, regenerate if so)?

2. **Prune threshold:** Is 3 days appropriate, or should it be configurable (e.g., via `.env`)?

3. **Image cleanup:** Should `make prune` also remove old provider images, or only dangling/unused images?

---

## References

- [`story_session_identity_and_harness_versioning.md`](../devlog/discussions/story_session_identity_and_harness_versioning.md) — superseded design
- [`scripts/start_agent.sh`](../../scripts/start_agent.sh) — primitive set implementation
- [`scripts/checkpoint.sh`](../../scripts/checkpoint.sh) — WORKTREE_ID derivation
- [`scripts/stop.sh`](../../scripts/stop.sh) — current stop implementation
