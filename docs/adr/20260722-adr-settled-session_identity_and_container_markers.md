# ADR — Session Identity and Container Markers

**Status:** settled

## Summary

Container identity is hash-based, not timestamp-based. Every container carries a fixed set of Docker labels that encode provenance, lifecycle scope, and run identity. These labels are the single mechanism for all lifecycle operations — stop, prune, and inspect — eliminating reliance on name parsing or external state files.

## Context

Before M2.7, containers were named with raw timestamps (`sandbox-<project>-20260423-143022`). Timestamps are human-readable but provide no identity guarantees: they don't encode which sandbox instance or host commit the container belongs to, and they can't be verified against source state. Lifecycle operations (stop, prune) depended on project name plus directory path passed as CLI flags, with no runtime-verifiable identity on the container itself.

As the harness grew to support parallel worktree sessions, multiple providers, and session-resume flows, three requirements emerged:

1. **Unambiguous container identity.** An operator inspecting a running container must be able to determine its project, sandbox instance, host commit, and session run without consulting external state.
2. **Label-based lifecycle management.** Docker labels are the only runtime-verifiable mechanism for filtering containers and volumes at scale. `docker stop --filter label=X` is more reliable than name-prefix matching.
3. **Deterministic session naming.** Container and artefact names must be deterministic from their identity factors — the same session replayed from the same inputs produces the same names, enabling reproducible exports and audits.

## Options Considered

### Option A — Timestamp-based (status quo ante)

Containers named with `SESSION_TS` suffix. Labels optional — lifecycle operations parsed container names.

- **Advantages:** Human-readable ordering (chronological sort). Simple to implement.
- **Disadvantages:** No identity verification. Parallel worktree sessions produce the same name if started at the same second. Lifecycle operations require external state (project name, sandbox dir passed as CLI flags) — no runtime-verifiable filter exists on the containers themselves.

### Option B — Hash-based (adopted)

Container identity derived from two factors: sandbox instance (`SANDBOX_DIR` + `HOST_HEAD_SHA`) and session timestamp (`SESSION_TS`). A short hash encodes each factor into container names and artefact paths. A fixed label schema provides runtime-verifiable identity on every container.

- **Advantages:** Deterministic from inputs. Labels enable label-based lifecycle filtering. Consistent identity across containers, artefacts, and logs.
- **Disadvantages:** Hash is not human-readable chronological — must reference `agent-sandbox.session-ts` label for temporal ordering.

### Option C — UUID-based

Each session generates a random UUID for container naming. Labels carry the same schema as Option B.

- **Advantages:** No collision risk. Simple generation.
- **Disadvantages:** Non-deterministic — replaying a session from the same state produces a different identity. Cannot correlate artefacts back to their generating session without an external registry.

## Decision

Adopt **Option B — Hash-based identity**.

- Identity factors: `SANDBOX_DIR` (instance), `HOST_HEAD_SHA` (branch point), `SESSION_TS` (temporal).
- `SANDBOX_ID` = `sha256(SANDBOX_DIR:HOST_HEAD_SHA)[:8]` — identifies a sandbox instance at a specific host commit.
- `RUN_ID` = `sha256(SESSION_TS:SANDBOX_ID)[:6]` — identifies a single session run.
- Container naming: `<role>-<project>-<RUN_ID>` — e.g. `sandbox-agent-sandbox-f6e5d4`, `pi-agent-sandbox-f6e5d4`.

## Marker Schema

Every container carries these Docker labels, set by the compose template at runtime:

| Label | Value | Purpose |
|---|---|---|
| `agent-sandbox.project-name` | `PROJECT_NAME` | Human-readable project identity. Used as primary label filter for all lifecycle operations. |
| `agent-sandbox.sandbox-dir` | `SANDBOX_DIR` | Absolute path of the sandbox instance on the host. Distinguishes parallel worktree sessions of the same project. |
| `agent-sandbox.host-head-sha` | `HOST_HEAD_SHA` | Full SHA of the host git HEAD at session start. Records the exact branch point for provenance. |
| `agent-sandbox.host-branch` | Sanitised branch name | Human-readable branch context. |
| `agent-sandbox.session-ts` | `SESSION_TS` | Timestamp in `YYYYMMDD-HHMMSS` format. Sole source of chronological ordering — names use `RUN_ID` for identity. |
| `agent-sandbox.run-id` | `RUN_ID` | 6-char hex session identifier. Links containers to artefact paths and logs. |

The label pair `project-name` + `sandbox-dir` is the compound key for all lifecycle operations:
- `docker stop --filter label=agent-sandbox.project-name=<X> --filter label=agent-sandbox.sandbox-dir=<Y>` scopes stop to a specific sandbox instance.
- `make stop` filters by this pair; `make stop RUN_ID=<id>` adds `agent-sandbox.run-id` for single-session targeting.
- `make prune` filters by the same pair for aged-resource cleanup.

## Relationship to Functionality

| Marker | Enables |
|---|---|
| `project-name` + `sandbox-dir` | Lifecycle operations scoped to a single sandbox instance — stop, prune, inspect. No name parsing needed. |
| `run-id` | Single-session targeting (`make stop RUN_ID=abc123`). Links artefacts (diffs, exports) to their generating container. |
| `session-ts` | Human-readable chronological ordering of sessions. Single source of temporal truth — names use `RUN_ID`. |
| `host-head-sha` + `host-branch` | Provenance tracking — which host commit and branch the session branched from. |

Image identity is separate: images are tagged by project name only (`sandbox-<project>`, `<provider>-agent-<project>`). Image tags encode harness code identity, not project repo state — the repo state is captured at runtime by the snapshot pipeline and carried by Docker labels. See `docs/concepts/sandbox_identity.md` for the full label schema and artefact path table.

## Consequences

### Positive

- **Label-based lifecycle works without compose.** `stop.sh` filters by labels using `docker ps --filter`, not `docker compose ps`. This works even if the compose project state is stale or the containers were started by a different compose invocation.
- **Deterministic artefact paths.** `RUN_ID` in artefact directory names means exports can be correlated to their generating container without consulting a registry.
- **Consistent identity across layers.** The same `RUN_ID` appears in container names, Docker labels, artefact paths, and error logs — any one can be used to locate the others.

### Negative

- **Hash naming is not human-readable.** Temporal ordering requires inspecting the `session-ts` label. Mitigated by preserving `SESSION_TS` as a sort key in artefact paths where chronological ordering matters (export directories).
- **`RUN_ID` is 24 bits.** 6 hex chars = ~16M combinations. Collision risk within a single sandbox instance is negligible for practical session counts but not zero.
- **Labels must stay in sync.** If `stop.sh`'s label filter ever diverges from the compose template's label set, lifecycle operations silently miss containers. Enforced by the compose template being the single source of truth for label schema.

## Related Documents

- [`docs/concepts/sandbox_identity.md`](../../docs/concepts/sandbox_identity.md) — stable reference for primitives, derivation formulas, artefact paths, and consumption table
- [`scripts/start_agent.sh`](../../scripts/start_agent.sh) — primitive set implementation
- [`scripts/stop.sh`](../../scripts/stop.sh) — label-based lifecycle filtering implementation
- [`src/build/docker-compose.yml`](../../src/build/docker-compose.yml) — compose template with label schema
