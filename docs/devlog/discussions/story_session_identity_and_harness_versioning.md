# Story — Session Identity and Harness Versioning

**Status:** Resolved

---

## Context

The harness currently has no concept of its own identity at runtime. It does not know what version of itself it is, whether the running container images match the current source, or how to tie a session's artefacts back to the exact harness and project state that produced them. This gap has produced three concrete problems — stale image regressions, dogfooding breakage with no safe recovery path, and session artefacts that cannot be traced back to their provenance — and a latent one: the model assumed one session per container lifetime, which constrains multi-session workflows unnecessarily.

Change 1 of M2.3 introduced `SESSION_NAME` and `CHECKPOINT_TS` as session identity tokens. This story frames the broader design problem those changes are the beginning of, and defines the full design for completing it.

---

## Pain Points

**Stale image regressions.** The preflight gate checks only whether an image exists. It does not check whether the image was built from the current source. Changes to `libs/` take effect only after a manual `make build` — there is no warning if the operator forgets. This caused a confirmed regression (M1.4 staleness detection feature, confirmed absent from running images).

**Timestamp proliferation and parity drift.** `CHECKPOINT_TS` is captured once in `start_agent.sh` but there is no enforcement that all downstream uses of a timestamp refer to the same value. If any step re-calls `date`, the tokens drift. The checkpoint tag, `SESSION_NAME`, the artefact directory, and any image label must all derive from the same single timestamp value for the same logical session.

**Derived labels stored redundantly.** `SESSION_NAME` is stored and passed around, but it is a pure function of branch name and timestamp — both of which are independently available. Storing derived values creates a maintenance surface. The primitives should be stored; derived values should be computed on demand.

**Branch name as identity primitive.** `SESSION_NAME` includes the branch name, which is mutable and not a stable identifier. In detached HEAD state, `rev-parse --abbrev-ref HEAD` returns the literal string `HEAD`, which is uninformative. The commit hash is the correct identity primitive for the project state; the branch name is useful only for human readability.

**Host-side drift not detected.** `libs/` files run on both the host and inside the container — `compose.sh` and `containers.sh` are host-side orchestration, `snapshot.sh` and `sandbox-entrypoint.sh` are baked in. `container-sig = hash(libs/)` catches all `libs/` drift. The remaining blind spot is `scripts/` — files like `start_agent.sh` that run exclusively on the host and are never baked into the container.

**Container recreation is unnecessarily coupled to session start.** The container is always torn down and recreated at session start. The only operations that actually require a fresh container are: image has changed (`container-sig` mismatch) or explicit operator request. The sandbox is re-initialised from `.snapshot/` by the entrypoint on every run regardless — container recreation is redundant for most sessions.

**Container naming is broken.** The harness assumes container name equals image name, enforcing one container per image. In practice Docker Compose overrides this with generated names, so the harness has no reliable way to address a running container by a predictable name. This breaks `docker stop`, `docker logs`, and any future reuse or multi-session logic.

**Images are named per-project unnecessarily.** Images contain no project-specific content — project content enters via mounts at runtime. The `<project>` suffix in current image names is vestigial, originating when `agents.md` was baked into the image. Images are harness- and provider-level artefacts; per-project naming is namespace pollution and creates unnecessary image proliferation.

---

## Constraints

- A single canonical timestamp must be established at the top of `start_agent.sh` and used for all session identity tokens. No downstream step may re-call `date`.
- Stored primitives must be minimal: only values that cannot be derived on demand should be stored or baked.
- The container-sig and harness-sig must be separate signals covering different scopes with different action semantics.
- Changes to the identity model must not break the existing Change 1 / Change 2 artefact pipeline (checkpoint tag, `SESSION_NAME`, session-scoped artefact directory).
- Container reuse must remain optional and opt-in — the current always-recreate behaviour must remain the safe default.
- `sandbox-entrypoint.sh` must be idempotent: it must wipe and re-initialise `sandbox/` from the current `.snapshot/` on every container start, regardless of prior state.

---

## Design

### Primitive set

Three primitives, established once per session at the top of `start_agent.sh`:

| Primitive | Value | Where stored |
|---|---|---|
| `SESSION_TS` | `$(date -u +%Y%m%d-%H%M%S)` — one call, used everywhere | Exported env var; written to `.workspace/session-ts.ref` |
| `REPO_COMMIT` | `git -C "$PROJECT_DIR" rev-parse HEAD` | Exported env var; candidate image label |
| `WORKTREE_ID` | Short hash of `PROJECT_DIR` absolute path | Exported env var; used in checkpoint tag namespace and container name |

Derived values, computed on demand from primitives:

| Derived | Formula | Notes |
|---|---|---|
| `SESSION_NAME` | `<branch-or-short-sha>-<SESSION_TS>` | Branch from `rev-parse --abbrev-ref HEAD`; if detached HEAD, use `git rev-parse --short HEAD` instead |
| Checkpoint tag | `agent-checkpoint/<worktree-id>/<SESSION_TS>` | Namespaced by worktree to avoid cross-session tag interference in shared git object store |
| Container name | `<provider>-agent-<project>-<SESSION_TS>` | Per-session; harness-controlled via explicit `container_name:` in generated compose |
| Artefact directory | `workspace/changes/<SESSION_NAME>/` | Per-session, non-colliding |

### Image naming

**Prerequisite verification required before implementing this section.**

The image naming change assumes images contain no project-specific content. The one known risk is `agents.md` — if it is still `COPY`-ed into the reasoning layer image via `provider.Dockerfile`, the image is project-specific and the naming change is premature. Documentation is contradictory on this point: the older `sandbox_lifecycle.md` states `agents.md` is baked in at build time; the current version states it is injected via `workspace/input/` at runtime.

Before implementing the image rename, verify in each provider's `provider.Dockerfile`:
- No `COPY agents.md` or equivalent instruction is present
- `AGENT_BRIEF` is resolved by `start_agent.sh` and placed into `SANDBOX_DIR/.workspace/input/` before container start
- The reasoning layer reads it exclusively from the `workspace/input/` mount at runtime

If `agents.md` is still baked in, the migration to runtime injection must complete before the image rename proceeds. The rename and the migration may be scoped to the same sub-milestone.

---

Images are harness- and provider-level artefacts. They contain no project-specific content — project content enters exclusively via mounts at runtime. The `<project>` suffix in current image names is vestigial and should be removed.

| Image | Revised name | Scope |
|---|---|---|
| Capability layer | `sandbox` | Harness-level; shared across all projects and worktrees |
| Reasoning layer base | `<provider>-base` | Provider-level; unchanged |
| Reasoning layer | `<provider>-agent` | Provider-level; shared across all projects and worktrees |

Container names carry per-session identity; image names carry per-provider identity. Multiple container instances can be created from the same image without naming conflict.

### Two-sig model

**`container-sig`** — `hash(libs/ + providers/<n>/base.Dockerfile + providers/<n>/provider.Dockerfile)`.

Baked as Docker label `agent-sandbox.container-sig` at image build time. Provider-specific — checked per active provider at preflight by re-hashing on the host and comparing against the label. Mismatch → rebuild required. `libs/` covers both files baked into the container and host-side orchestration files that live in `libs/` but run on the host.

**`harness-sig`** — `hash(scripts/ + providers/<n>/setup.sh + providers/*.yml + providers/<n>/*.yml)`.

Computed at runtime in `start_agent.sh` for the active provider. Compared against `SANDBOX_DIR/.harness-sig.ref`, written at session end after clean exit. First run: no ref file exists, sig computed and written, no comparison. Subsequent runs: sig computed at start, compared against ref, mismatch → warn only, no rebuild required or implied. Writing at end (not start) ensures the comparison is meaningful: current harness vs harness at last successful session.

Provider-aware: `providers/*.yml` covers provider-agnostic base compose files; `providers/<n>/*.yml` covers provider-specific overrides. Depends on a paired refactor moving `libs/docker-compose.yml` and `libs/docker-compose.dry-run.yml` into `providers/` so the hash boundary matches the folder boundary.

The two sigs are independent with clean action semantics: `container-sig` mismatch → rebuild needed; `harness-sig` mismatch → harness behaviour for this provider setup has drifted since last successful session, operator should be aware.

### Container lifecycle

Container start always produces a fresh fork from the current `.snapshot/`, regardless of prior `sandbox/` state. `sandbox-entrypoint.sh` wipes and re-initialises `sandbox/` on every start — making restart semantically equivalent to recreation for sandbox state. A stopped container whose EXIT trap fired has captured all agent work as a diff; its `sandbox/` state is not a useful continuation point.

Triggers for full container recreation (image rebuild + new container): `container-sig` mismatch, or explicit `--rebuild` flag. Triggers for container restart without recreation: all other cases. Container reuse is opt-in — the default remains always-recreate until the reuse path is validated.

### Detached HEAD handling

When `rev-parse --abbrev-ref HEAD` returns the literal string `HEAD`, substitute `git rev-parse --short HEAD` (short commit SHA) as the branch component of `SESSION_NAME`. Produces a stable, readable identifier rather than the uninformative `HEAD-<timestamp>`.

---

## Deferred

**Harness packaging and install versioning** — meaningful installed-vs-local isolation requires `make install` to snapshot the full harness source, not just drop a dispatcher binary. `HARNESS_DIR` override becomes viable only once the installed copy is genuinely self-contained. Extracted as a separate future task: [`story_harness_packaging_and_install_versioning.md`](story_harness_packaging_and_install_versioning.md). The sig model is useful immediately without this — `harness-sig` warns about drift against the last successful session regardless of install isolation.

**`harness-sig.ref` storage location** — current resolution is `SANDBOX_DIR/.harness-sig.ref`, per-project rather than global. Detects drift relative to the last successful session for this project. Revisit when the packaging story is resolved.

**Parallel sessions via git worktree** — extracted as sub-story: [`story_parallel_sessions_worktree.md`](story_parallel_sessions_worktree.md). The `WORKTREE_ID` primitive and revised checkpoint tag namespace defined above are the harness-level prerequisites for that story.

**Advancing the baseline within a running container** — if the operator applies a draft, commits to the host repo, and wants to continue in the same container without restart, the container needs a mechanism to advance its own `BASELINE_SHA`. Flagged for Change 3 design.

**VERSION file** — not needed. Content-addressed sigs are self-maintaining and cannot drift from reality. If a human-readable version string is wanted for operator communication, derive from the short hash of `libs/` on demand.

---

## Resolution

**Decision:** Adopt the primitive set and two-sig model as specified in the Design section above.

**Where the work goes:** A new sub-milestone (proposed M2.7) covering: primitive set implementation in `start_agent.sh` (single timestamp, `REPO_COMMIT`, `WORKTREE_ID`); `container-sig` baked as Docker label at build time, checked at preflight; `harness-sig` computed at runtime, compared against `SANDBOX_DIR/.harness-sig.ref`; container naming redesign (explicit `container_name:` in generated compose, derived from session identity); image rename prerequisite verification (`agents.md` code review); paired refactor moving base compose files from `libs/` to `providers/`. Detached HEAD handling and tag namespace update (`agent-checkpoint/<worktree-id>/<timestamp>`) can be folded into the next Change 1 implementation pass as low-risk additions.

**Rewritten investigations:**
Following investigations are rewritten into the current story file: 
- `investigation_staleness_and_interactivity_regression.md` — staleness detection proposal adopted and extended; `INTERACTIVE` flag concern superseded by prior bug fix
- `investigation_versioning_and_governance.md` — runtime concerns fully absorbed; governance concerns addressed in separate chore session; `VERSION` file not adopted

**Sub-stories extracted:**
- [`story_parallel_sessions_worktree.md`](story_parallel_sessions_worktree.md) — parallel sessions via git worktree; `WORKTREE_ID` primitive and checkpoint tag namespace are the harness-level prerequisites
- [`story_harness_packaging_and_install_versioning.md`](story_harness_packaging_and_install_versioning.md) — install workflow rewrite; deferred as large future task; does not block the sig model
