# Spec — Container Layer Redesign

**Status:** Design complete, awaiting implementation

**Linked artifacts:**
- Story: [`story_container_layer_model.md`](story_container_layer_model.md) — problem analysis, option evaluation, decision record
- Design doc: [`design_settings_permissions_group_bind.md`](design_settings_permissions_group_bind.md) — UID Mapping strategy (consumes this spec)

---

## 1. Proposal

### Selected architecture

Two harness base images (node + python) sitting between the official runtime images and the per-provider base images. The sandbox remains independent on its own `ubuntu:24.04` base.

```
Current:                              Proposed:

node:22-slim → pi-base → pi-agent     node:22.22.3-slim → node-harness → pi-base → pi-agent
node:20-slim → cd-base → cd-agent    node:22.22.3-slim → node-harness → cd-base → cd-agent
ubuntu:24.04 → oc-base → oc-agent    node:22.22.3-slim → node-harness → oc-base → oc-agent
python:3.11 → hermes-base → agent     python:3.11-slim → python-harness → hermes-base → hermes-agent
ubuntu:24.04 → sandbox               ubuntu:24.04 → sandbox (unchanged)
```

### What moves into the harness bases

Only **stable plumbing** — things that change rarely or never:

| Content | Rationale |
|---|---|
| `git`, `curl`, `ca-certificates`, `rsync`, `fd-find`, `ripgrep` (apt install) | Universal dependencies — all providers need these for the harness workflow, regardless of runtime. Installed via apt in both node-harness and python-harness. |
| `ARG HOST_UID=1000` / `ARG HOST_GID=1000` | Stable — needed for UID Mapping |
| `RUN useradd ...` + UID collision handling (`usermod` rename) | Written once, never changes |
| `RUN chown -R ${HOST_UID}:${HOST_GID} ...` | Tied to useradd |
| `ENV WORKSPACE_DIR=/home/agentuser/workspace` | Fixed path |
| `RUN mkdir -p $WORKSPACE_DIR/input $WORKSPACE_DIR/output` | Bootstrap |
| `WORKDIR /home/agentuser/sandbox` | Fixed |
| `HEALTHCHECK ...` | Stable across providers |
| `ENV PATH=/opt/sandbox/bin:$PATH` | Fixed |

### What stays on the provider layer (fast-changing)

| Content | Why it stays |
|---|---|
| `COPY dirs.sh, session.sh, routing.sh, package_diff.sh` | Change with every harness update — would invalidate harness base cache |
| `COPY provider-entrypoint.sh` | Rare changes, but belongs near the other harness libs |
| `COPY agent/skills/, agent/prompts/, agent/config/` | Project-specific workflow files |
| `ENV AGENT_HOME`, `ENV PROVIDER_NAME` | Per-provider identity |

### What stays on the provider layer (`provider.Dockerfile`)

| Content | Why it stays |
|---|---|
| `ENTRYPOINT [...]` | References `provider-entrypoint.sh`, which is a fast-changing harness file. Must be in the same layer as the script. |
| `USER agentuser` | Provider base needs root for apt/npm installs. Setting `USER` at the end of each provider base ensures entrypoint runs as agentuser without burdening base builds with root elevation switches. |
| `COPY dirs.sh, session.sh, routing.sh, package_diff.sh` | Change with every harness update — would invalidate harness base cache |
| `COPY provider-entrypoint.sh` | Rare changes, but belongs near the other harness libs |
| `COPY agent/skills/, agent/prompts/, agent/config/` | Project-specific workflow files |
| `ENV AGENT_HOME`, `ENV PROVIDER_NAME` | Per-provider identity |

Final resolved metadata: `ENTRYPOINT` (from provider layer) + `USER agentuser` (from provider base) = entrypoint runs as agentuser. Docker composes final image metadata from the nearest ancestor for each field independently.

### What happens to each provider

| Provider | Current base | Current runtime | New base | Change |
|---|---|---|---|---|
| Pi | `node:22.22.3-slim` | `npm i @earendil-works/pi` | `node-harness` | Trivial — `FROM node-harness` instead of `FROM node:22.22.3-slim` |
| Claude Code | `node:20-slim` | `npm i @anthropic-ai/claude-code` | `node-harness` | Node version bump 20→22. npm backwards-compat expected. |
| OpenCode | `ubuntu:24.04` + apt npm | `npm i opencode-ai` | `node-harness` | OS swap Ubuntu→Node. Eliminates apt npm dependency. |
| Hermes | `python:3.11-slim` | git clone + uv venv | `python-harness` | Trivial — `FROM python-harness` instead of `FROM python:3.11-slim` |
| Sandbox | `ubuntu:24.04` | none | unchanged | Stays on `ubuntu:24.04`, gets its own UID Mapping edit separately |

### UID Mapping impact

| Before (Track C, Phase 2) | After this redesign |
|---|---|
| 5 Dockerfiles to edit | **3 Dockerfiles to edit** (node-harness, python-harness, sandbox) |

---

## 2. Problems Found During Evaluation

### Cross-distro binary extraction is fragile

Option 3 (single Ubuntu base + `COPY --from` from official Node/Python images) was evaluated and rejected. The Debian-compiled runtimes embed hardcoded `sysconfig` paths and link against Debian's `glibc` version. When the host system calls native C extensions (cryptography, ML libraries), `.so` path mismatches cause silent runtime failures that are difficult to debug.

### `libs/` is a grab bag with no clean seam

The current `libs/` directory mixes host-side scripts, reasoning layer files, capability layer files, compose templates, and shared libs. Each Dockerfile or build context selects a subset of files via `COPY`. This means:

- A new file added to `libs/` implicitly enters every build context unless explicitly excluded
- A file's destination is determined by how `build_context_*()` copies it, not by where it lives
- Adding a new harness variant (e.g. a deno-harness) means duplicating the selection logic

**Resolution:** A structural cleanup (chore session) is required before the harness Dockerfiles land. Proposed target structure: `harness/reasoning/nodes/`, `harness/reasoning/lib/`, `harness/capability/`, `harness/workflow/`, `harness/compose/`, `harness/host/`. The migration is mechanical path substitution.

### Shared script for UID logic adds traceability cost

Extracting the UID collision handling into a shared script (`libs/create-agentuser.sh`) would reduplicate the `RUN` block. However, the collision pattern is stable enough that the additional file adds traceability cost (4 files to trace instead of 3) with no maintenance benefit. **Decision: keep inline.**

### Resolved audit findings

These gaps were identified during a design audit and resolved before implementation:

| # | Finding | Resolution |
|---|---|---|
| 1 | `USER agentuser` not in harness base — entrypoint runs as root | `USER` stays at end of each provider base (needs root for apt/npm installs). `ENTRYPOINT` stays in provider layer (references the entrypoint script). Docker resolves metadata from nearest ancestor. |
| 2 | OpenCode loses `ubuntu:24.04` packages on swap to `node:22.22.3-slim` | `git`, `curl`, `ca-certificates`, `rsync`, `fd-find`, `ripgrep` moved into both harness bases as universal deps. OpenCode does not need python3 (stale dep). |
| 3 | `PATH` composition — harness base PATH overridden by provider base `ENV PATH` | Docker's `ENV $PATH` build-time interpolation appends, not replaces. Harness base PATH is preserved. No change needed. |
| 4 | Hermes multi-stage: `WORKDIR` triple override | Remove `WORKDIR /opt/hermes` from `hermes-base`. `COPY --from=builder` uses absolute paths. Multi-stage stays (strips build tools from runtime). |
| 5 | No harness build context function | `build_context_harness()` as a peer of `build_context_agent()` and `build_context_sandbox()`. See §5 Open Question #4. |
| 6 | `node-harness` missing system packages | Same as #2 — `git`, `curl`, `ca-certificates`, `rsync`, `fd-find`, `ripgrep` installed in both harness bases. |
| 7 | `package_branch.sh` in agent context but not consumed | Pre-existing; document in chore session scope for cleanup. |
| 8 | No `harness_image_name()` function | Add to `containers.sh` alongside existing naming functions. |
| 9 | Session A/B ordering ambiguity | Session A (chore) must come before Session B (Dockerfiles). Harness Dockerfiles land in their final location directly. |
| 10 | Provider compose overlays `user:` conflict | No current overlay sets `user:`. Document convention in spec: "Only the base compose template sets `user:`." |

---

## 3. Existing Design (What We Start From)

### Current Dockerfile tree

```
providers/<n>/
├── base.Dockerfile          ← FROM node:22-slim (or python:3.11-slim, ubuntu:24.04)
│   - apt packages (git, curl, rsync, fd-find, ripgrep)
│   - runtime install (npm install -g agent, git clone + uv venv, etc.)
│   - ends as root
│
├── provider.Dockerfile      ← FROM <n>-base
│   - COPY harness libs (dirs.sh, session.sh, routing.sh, package_diff.sh)
│   - COPY provider-entrypoint.sh
│   - COPY provider-preflight.sh (if any)
│   - RUN useradd -m -u 1001 agentuser
│   - USER agentuser
│   - mkdir -p $AGENT_HOME $WORKSPACE_DIR
│   - chown -R agentuser:agentuser ...
│   - WORKDIR, HEALTHCHECK, ENV PATH, ENTRYPOINT
│
libs/sandbox.Dockerfile      ← ubuntu:24.04
│   - useradd -m -u 1001 agentuser
│   - sandbox-specific libs + entrypoint
```

### Current build pipeline

`libs/containers.sh` → `build_agent()`:
1. Build `base.Dockerfile` → tag `<provider>-base` (skipped if exists)
2. Build `provider.Dockerfile` → tag `<provider>-agent-<project>` (always rebuilt)

`build_context_agent()` assembles a temp directory with:
- Harness libs from `libs/` (dirs.sh, provider-entrypoint.sh, package_diff.sh, package_branch.sh, session.sh, routing.sh)
- Workflow files from `agent/skills/`, `agent/prompts/`
- Provider config from `providers/<n>/config/`
- Provider preflight from `providers/<n>/preflight.sh`

### Current libs/ contents

| File | Used by | Category |
|---|---|---|
| `containers.sh` | `scripts/run_agent.sh`, `scripts/start_agent.sh` | Host-side |
| `compose.sh` | `scripts/run_agent.sh` | Host-side |
| `draft_workflow.sh` | `scripts/agent-sandbox.sh` | Host-side |
| `diff_workflow.sh` | `scripts/agent-sandbox.sh` | Host-side |
| `interactive_session_select.sh` | `scripts/agent-sandbox.sh` | Host-side |
| `provider-entrypoint.sh` | `build_context_agent()` → reasoning layer | Reasoning |
| `dirs.sh` | Both build contexts → both layers | Shared lib |
| `session.sh` | Both build contexts → both layers | Shared lib |
| `routing.sh` | Both build contexts → both layers | Shared lib |
| `sandbox-entrypoint.sh` | `build_context_sandbox()` → capability | Capability |
| `snapshot.sh` | `build_context_sandbox()` → capability | Capability |
| `diff.sh` | `build_context_sandbox()` → capability | Capability |
| `package_branch.sh` | Both build contexts | Capability |
| `docker-compose.yml` | `compose.sh` (template) | Compose |
| `docker-compose.dry-run.yml` | `compose.sh` (template) | Compose |
| `sandbox.Dockerfile` | `build_sandbox()` | Capability |
| `_templates/` | `scripts/onboard.sh` | Host-side |

---

## 4. Unresolved Issues

| Issue | Impact | Blocking? |
|---|---|---|
| `libs/` structural cleanup | The harness Dockerfiles need a clean home. If they land in `libs/`, they inherit the grab bag. If they land in a new `harness/` dir, existing files are split across two conventions until the chore session. | **Not blocking design** — chore session resolves this. |
| `scripts/` vs `libs/` conflation | Some files in `scripts/` are end-to-end entrypoints, some in `libs/` are also entrypoints (`compose.sh`). Line between them is blurry. | Not blocking — separate cleanup concern. |

---

## 5. Design Decisions

These decisions were reached during the design audit and are ready for implementation:

| # | Decision | Rationale |
|---|---|---|
| 1 | **Build pipeline:** `build_agent()` explicitly builds `harness-node` then `harness-python` before each provider's base, via a `build_harness()` helper function. Uses same cache-on-exists pattern as existing base/provider split. | Simpler than `FROM`-based on-missing resolution. Build pipeline already has the infrastructure for caching checks. |
| 2 | **Provider base vs single file:** keep `base.Dockerfile` separate from `provider.Dockerfile`. | Changing this is mechanical and orthogonal to the layer redesign. Defer to a later cleanup if warranted. |
| 3 | **Image tagging:** provider-agnostic (`harness-node`, `harness-python`). | Matches current pattern where `pi-base` is project-agnostic. Provider-agnostic means a `--refresh` on one project rebuilds the harness for all. |
| 4 | **Build context:** new `build_context_harness()` function as a peer of `build_context_agent()` and `build_context_sandbox()`. | Harness base has no provider files, so it gets a minimal context. A flag on `build_context_agent()` would add complexity to a shared function for no benefit. |

### Deferred to chore session

| Item | Concern |
|---|---|
| Directory structure (`harness/` vs `libs/` vs `scripts/`) | The harness Dockerfiles need a clean home. Resolved by the structural chore session — see §4 Unresolved Issues. |

---

## 6. Implementation Sequence

```
Session A: Chore (structural cleanup)
  - Move files from libs/ → harness/ tree
  - Update all source/COPY/path references
  - Tests pass, no logic changes

Session B: Dockerfile refactoring
  - Create harness/reasoning/nodes/node.Dockerfile
  - Create harness/reasoning/nodes/python.Dockerfile
  - Trim 4 provider base.Dockerfile files
  - Trim 4 provider provider.Dockerfile files
  - Update build_context_agent() for harness base
  - Update build_agent() for three-tier build
  - Tests pass, UID Mapping not yet active

Session C: UID Mapping Phase 1 (build pipeline threading)
  - libs/build.sh: build_sandbox/agent accept --uid/--gid
  - scripts/start_agent.sh: export HOST_UID/HOST_GID
  - No behaviour change

Session D: UID Mapping Phase 2 (Dockerfiles + compose)
  - Edit node-harness, python-harness, sandbox Dockerfile with ARGs, collision, chown
  - Add user: to compose template
  - Both UID Mapping and ACL paths functional

Session E: UID Mapping Phase 3 (ACL removal, after verification)
  - Remove setfacl from onboard.sh
  - Remove ACL test guards
  - Documentation updates
```
