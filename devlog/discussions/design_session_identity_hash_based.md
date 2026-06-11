# Design — Hash-Based Session Identity

**Status:** Active

**Supersedes:** [`story_session_identity_and_harness_versioning.md`](../devlog/discussions/story_session_identity_and_harness_versioning.md)

---

## Context

The harness currently uses timestamps (`SESSION_TS`) for container naming and session-scoped artefacts. Timestamps are long (15 chars), not memorable, and don't encode identity factors. This design replaces timestamp-based naming with a short hash (`run_id`) that encodes the session's primitive identity factors.

---


## Design

### Primitive Set

Five primitives, established once per session at the top of `scripts/start_agent.sh`:

| Primitive | Value | Source |
|---|---|---|
| `SESSION_TS` | `$(date -u +%Y%m%d-%H%M%S)` | Timestamp |
| `HOST_HEAD_SHA` | `git -C "$PROJECT_DIR" rev-parse HEAD` | Full SHA of host HEAD at session start |
| `SANDBOX_DIR` | Operator-supplied at onboard | Absolute path to sandbox instance directory |
| `PROJECT_NAME` | User-provided at onboard | Human-readable project identifier |
| `PROJECT_DIR` | User-provided at onboard | Absolute path to project on host |

### Derived Identifiers

#### SANDBOX_ID — Sandbox Instance Identity

```bash
SANDBOX_ID=$(echo "${SANDBOX_DIR}:${HOST_HEAD_SHA}" | sha256sum | cut -c1-8)
```

An 8-character hex hash that identifies a specific sandbox instance at a specific host commit. Used as a component of `RUN_ID` for container naming and session artefact paths. Also recorded as a Docker label on containers for runtime identity.

**NOT** appended to image names — images are versioned by the harness code and build context, not by the project repo state. The project repo state is captured at runtime by the snapshot pipeline, not the image build. Provenance for past sessions is carried by Docker labels (`agent-sandbox.host-head-sha`, `agent-sandbox.sandbox-dir`, `agent-sandbox.run-id`), not by image tags.

**Properties:**
- Two sandboxes at different directories but the same `HOST_HEAD_SHA` produce different `SANDBOX_ID`s.
- Same directory, different `HOST_HEAD_SHA` produces a different `SANDBOX_ID`.
- 32 bits of entropy (8 hex chars), sufficient for sandbox-instance disambiguation.

**Replaces:** `WORKTREE_ID` (was `sha256(PROJECT_DIR)[:8]`). The new formula adds `SANDBOX_DIR` as identity factor, distinguishing sandbox instances at the same host commit.

#### RUN_ID — Session Run Identity

```bash
RUN_ID=$(echo "${SESSION_TS}:${SANDBOX_ID}" | sha256sum | cut -c1-6)
```

A 6-character hex hash that identifies a single session run. Replaces `SESSION_TS` in container names and output artefact paths while `SESSION_TS` is preserved in labels for human readability.

**Properties:**
- 6-character hex hash (16^6 = ~16M combinations)
- Unique per session even with same sandbox instance (timestamp component)
- Deterministic: same inputs produce same `RUN_ID`
- Double-hashing is harmless — SHA-256 is collision-resistant regardless of input structure

### Image Naming

Images are named by project only — no `SANDBOX_ID` suffix. The image tag identifies the harness code and build context, not the project repo state.

| Image | Format | Example |
|---|---|---|
| Sandbox (base) | `sandbox-<project>` | `sandbox-agent-sandbox` |
| Agent | `<provider>-agent-<project>` | `pi-agent-sandbox` |

**Provenance** for past sessions is carried by Docker image labels (`agent-sandbox.host-head-sha`, `agent-sandbox.sandbox-dir`), set at build time. These labels can be used as selectors for `docker images --filter`. Project repo state is independently captured by the snapshot pipeline — the image does not encode it.

### Container Naming

| Container | Format | Example |
|---|---|---|
| Sandbox | `sandbox-<project>-<run_id>` | `sandbox-agent-sandbox-f6e5d4` |
| Agent | `<provider>-<project>-<run_id>` | `pi-agent-sandbox-f6e5d4` |

**Replaces:**
- Old: `sandbox-<project>-<SESSION_TS>` (e.g., `sandbox-agent-sandbox-20260423-143022`)
- Old: `<provider>-<project>-<SESSION_TS>` (e.g., `pi-agent-sandbox-20260423-143022`)

### Docker Labels

All containers receive these labels for lifecycle management:

```yaml
labels:
  agent-sandbox.project-name:     <PROJECT_NAME>
  agent-sandbox.sandbox-dir:      <SANDBOX_DIR>
  agent-sandbox.host-head-sha:    <HOST_HEAD_SHA>
  agent-sandbox.host-branch:      <sanitised branch name>
  agent-sandbox.session-ts:       <SESSION_TS>
  agent-sandbox.run-id:           <RUN_ID>
```

**Rationale:**
- `project-name` and `sandbox-dir` together identify all sessions and images for a project from a specific sandbox instance
- `run-id` identifies a single session uniquely
- `host-head-sha` and `host-branch` provide provenance context for session artefacts
- `session-ts` retained for human readability in `docker inspect`

### Session-Scoped Artefacts

| Artefact | Path | Notes |
|---|---|---|
| Session diff export | `session-diffs/session/<SESSION_TS>-<BRANCH>-<RUN_ID>/` | `SESSION_TS` as sort key, `RUN_ID` for identity |
| Autosave diffs | `session-diffs/autosave/<SESSION_TS>-<BRANCH>-<RUN_ID>/` | Same scheme as session export |
| Package-diff output | `output/diffs/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | `EXPORT_TIME` is the sort key |
| Package-branch output | `output/bundles/<EXPORT_TIME>-<LABEL>-<RUN_ID>/` | Same scheme as package-diff |
| Draft branch | `draft/<RUN_ID>-<BRANCH_SLUG>-<FROM_SHA:0:6>` | `RUN_ID` uniquely identifies session; `FROM_SHA` for operator `--branch-from` override disambiguation |

**Rationale:**
- `RUN_ID` preferred for brevity and unique addressing
- `SESSION_TS` retained as sort key only when no alternative sort key exists (export paths)
- `EXPORT_TIME` serves as sort key for package-diff/package-branch output, so `RUN_ID` replaces the optional `SESSION_TS` suffix

## make stop Redesign

**Status: Decided.**

**Filter mechanism:**
- **Default** (`make stop`): filters by `agent-sandbox.project-name` + `agent-sandbox.sandbox-dir` labels. Stops all containers belonging to this sandbox instance, including parallel Compose projects from the same sandbox dir.
- **With `--run-id=<ID>`** (`make stop RUN_ID=abc123`): adds `agent-sandbox.run-id` filter. Stops only the specific run's containers.
- **With `PRUNE=1`** (`make stop PRUNE=1`): after stopping containers, runs prune on orphaned containers, images, and volumes for this project+sandbox instance. Semantics parallel to `REFRESH=1` / `REBUILD=1` for `make start`.

Behavioural requirements:
- Must stop only containers belonging to the specified sandbox instance (parallel sessions from different worktrees must not be affected)
- Must not require a running Docker Compose project (containers may have been started manually or by a different compose invocation)
- Must clean up anonymous volumes associated with stopped containers

## make prune Design

**Status: Decided.**

Prune is invoked as `make stop PRUNE=1` (not a standalone script). See make stop redesign above for filter semantics.

Age threshold: `PRUNE_AGE_DAYS=3` hardcoded at top of `stop.sh`. Covers containers, images, and volumes uniformly (age-based, no per-type differentiation). Targeted cleanup scoped to one project + sandbox instance. Time-based cleanup as fallback for orphaned artefacts (project-scoped, ignoring sandbox).

## Implementation Tasks

Removed — moved to `devlog/roadmap.md` M2.7 Track A task list.

## Backwards Compatibility

| Component | Migration Path |
|---|---|
| Existing containers | Continue to work; new sessions use run_id naming |
| Existing artefact directories | Retain existing paths; new sessions use new path format |
| `SESSION_NAME` | Retained as `session-ts` in Docker labels for backwards compatibility |
| Draft branches | Old format (`draft/<SESSION_TS>-...`) continues to work; new sessions use `draft/<RUN_ID>-...` |

## Container-sig (Image Staleness Detection)

**Status: UNDECIDED.** Independent design colocated from earlier session (see handover 20260513-12). Requires separate investigation before Track B implementation. See `devlog/roadmap.md` M2.7 Track B for scope.

Behavioural requirements established from prior investigation:
- Must warn but not block (a hard gate is too aggressive for development workflows)
- Hashes `/opt/sandbox/` + `/opt/workflow/` at build time (excludes base image layers and bind-mounted directories)
- Baked as Docker label, checked at preflight
- Preflight source paths need updating to match current repository layout — the original design referenced `$REPO_ROOT/libs` and `$REPO_ROOT/agent` which are stale paths
## Harness-sig (Runtime Drift Detection)

**Deferred.** See [`investigation_harness_sig_requirements.md`](../discussions/investigation_harness_sig_requirements.md) and [`roadmap_future.md`](../devlog/roadmap_future.md) §Harness Packaging and Versioning.

Harness-sig requires two preconditions: (1) self-contained binary, (2) semantic versioning. These are scoped as a standalone future milestone, not part of M2.7.

---


## Open Questions

- *(None — all M2.7 Track A design questions resolved)*

---

## References

- [`story_session_identity_and_harness_versioning.md`](../devlog/discussions/story_session_identity_and_harness_versioning.md) — superseded design
- [`docs/concepts/sandbox_identity.md`](../../docs/concepts/sandbox_identity.md) — stable reference for primitives, derivation, labels, and paths
- [`scripts/start_agent.sh`](../../scripts/start_agent.sh) — primitive set implementation
- [`scripts/stop.sh`](../../scripts/stop.sh) — current stop implementation
- [`docs/devlog/handovers/20260513-12-study-grill_harness_sig_investigation.md`](../../devlog/handovers/20260513-12-study-grill_harness_sig_investigation.md) — container-sig settlement and harness-sig investigation scope
