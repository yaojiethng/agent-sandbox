# Story — Container Layer Architecture: Consolidation vs. Isolation

**Status:** Resolved — partially implemented; python harness deferred to W1

> Framing the problem: should the harness's shared plumbing live in one Docker layer shared by all providers, or stay per-provider as it is today? The answer affects build speed, maintenance burden, security surface, and the trajectory of the UID Mapping implementation in M2.7 Track C.

---

## Context

Every provider image is built from two Dockerfiles:

```
base.Dockerfile       ← slow-changing layers (OS, runtimes, agent npm/pip install)
       ↓
provider.Dockerfile   ← fast-changing layers (harness libs, workflow files, config)
```

This split exists to maximise Docker layer cache hits. The base builds once and is reused across projects, unless forced with `--no-cache-base`. The provider layer rebuilds every session (its input files change with every harness update).

The same pattern exists across all 4 providers, and each provider's `provider.Dockerfile` duplicates roughly 20 lines of harness plumbing:

```dockerfile
COPY dirs.sh /opt/sandbox/lib/dirs.sh
COPY provider-entrypoint.sh /opt/sandbox/bin/provider-entrypoint.sh
COPY session.sh /opt/sandbox/lib/session.sh
COPY routing.sh /opt/sandbox/lib/routing.sh
COPY package_diff.sh /opt/sandbox/lib/package_diff.sh
RUN useradd -m -u 1001 -s /bin/bash agentuser
USER agentuser
...
```

× 4 = 80 lines of duplicated code, and more critically: **5 places** where the UID Mapping changes (`ARG HOST_UID`, collision handling, numeric `chown`) must be applied.

### Problem Statement

The current per-provider Dockerfile model creates two pain points:

1. **UID Mapping (Track C, Phase 2) requires 5 parallel edits.** Every provider's `provider.Dockerfile` and the sandbox `Dockerfile` need the same `ARG HOST_UID`/`ARG HOST_GID` + collision handling + numeric `chown` logic. Five nearly-identical changes in five files — a propagation risk.

2. **The harness plumbing drifts across providers.** Adding a new shared tool (e.g. `fd-find` to the reasoning layer) requires touching all 4 `base.Dockerfile` files. A bug fix in the entrypoint must be verified against 4 combinations of runtime and base image. There's no single "harness version" — each provider image is a unique combination of harness libs + provider runtime.

---

## Evaluation Criteria

| Criterion | What it measures |
|---|---|
| **Build speed** | Docker layer cache behaviour. How many layers are invalidated by a typical harness change? A typical provider change? A typical runtime version bump? |
| **Maintenance burden** | How many files to edit for a cross-cutting change (new tool, new ARG, entrypoint fix). Also: how long does it take a new provider author to understand where to put things? |
| **Security surface** | Does sharing a base layer increase the attack surface? A vulnerability in a shared tool affects all providers simultaneously. Isolation limits blast radius. |
| **Traceability** | Can you tell which harness version a given provider image was built from? Is it easy to bisect a regression across providers? |
| **Portability** | Does the model work across WSL, macOS Docker Desktop, Windows Docker Desktop, and CI? |
| **Debuggability** | If a harness change breaks Pi but not Hermes, can you easily tell where the divergence is? |

---

## Options Considered

### Option 1 — Do nothing

No change to the current 4-provider Dockerfile tree. UID Mapping edits: 5.

### Option 2 — Two harness bases (node + python)

Introduce a `node-harness` and `python-harness` base layer. Providers with Node runtimes (Pi, Claude Code, OpenCode) inherit from `node-harness`. Hermes inherits from `python-harness`. The sandbox stays on its own `ubuntu:24.04` base.

Cache: Node providers share the same `node-harness` cache boundary for the first time. Python-harness is a single-provider layer (Hermes alone) but establishes the pattern for future Python providers.

UID Mapping edits: **3** (node-harness, python-harness, sandbox).

### Option 3 — Single Ubuntu base with cross-distro binary extraction

A single `harness-base` from `ubuntu:24.04`. Runtimes extracted from official `node:*` and `python:*` images via multi-stage `COPY --from`.

**Rejected.** Cross-distro `COPY --from` works for pure-JS and pure-Python apps but breaks on native C extension dependencies (`cryptography`, `numpy`, ML libraries). These failures manifest as `.so` path mismatches and hardcoded `sysconfig` paths from the Debian-compiled runtime against Ubuntu's `glibc` layout. Hard to debug, hits exactly when running ML workloads. Not worth the risk.

UID Mapping edits: **1** — but at the cost of fragile runtime extraction.

---

## Decision

**Selected: Option 2 — Two harness bases, sandbox independent.**

| Layer | FROM | Location | Contains |
|---|---|---|---|
| `node-harness` | `node:22.22.3-slim` | `libs/Dockerfile.harness-node` | `ARG HOST_UID`/`ARG HOST_GID`, `useradd` with UID collision, numeric `chown`, `WORKSPACE_DIR`, `HEALTHCHECK`, `ENTRYPOINT`, `ENV PATH` |
| `python-harness` | `python:3.11-slim` | `libs/Dockerfile.harness-python` | Same harness plumbing |
| `sandbox` | `ubuntu:24.04` | `libs/sandbox.Dockerfile` (unchanged) | Own `useradd`, own entrypoint, sandbox libs |
| provider base | `FROM <harness>` | `providers/<n>/base.Dockerfile` | Provider-specific runtime + agent install only |
| provider | `FROM <provider>-base` | `providers/<n>/provider.Dockerfile` | Workflow files, provider config, `AGENT_HOME`, `PROVIDER_NAME` |

### Constraints

- **UID logic stays inline** in each harness Dockerfile — not extracted to a shared script. The collision pattern is stable; a 4th file adds traceability cost with no maintenance benefit.
- **Fast-changing harness libs stay on the provider layer** — `dirs.sh`, `session.sh`, `routing.sh`, `provider-entrypoint.sh` are NOT moved into the harness base. Only the stable plumbing moves: `useradd`, `ARGs`, `WORKSPACE_DIR`, `HEALTHCHECK`, `ENTRYPOINT`, `PATH`.
- **Claude Code** moves from `node:20-slim` to `node:22.22.3-slim` (shared via `node-harness`). This is expected to work — `@anthropic-ai/claude-code` is an npm package compatible with Node 22. If it breaks, the fix is a version bump or pinning Claude Code to `node-harness` at the risk of diverging from the shared cache.
- **OpenCode** moves from `ubuntu:24.04` + npm via apt to `node:22.22.3-slim`. This is expected to work — OpenCode is also an npm package. Node 22 ships npm, so the apt npm dependency is eliminated.

### Result

UID Mapping impact: **3 Dockerfiles to edit** instead of 5 (node-harness, python-harness, sandbox).

---

## Open Questions — Resolved

All open questions from the initial design were resolved during the design audit (see `spec_container_layer_redesign.md` rule 5 Design Decisions):

| # | Question | Decision |
|---|---|---|
| 1 | Build pipeline: harness-build step or build-on-missing? | Explicit build step via `build_harness()` helper, same cache-on-exists pattern as provider bases. |
| 2 | Provider base files: keep separate or inline? | Keep `base.Dockerfile` separate. Mechanically separable later if warranted. |
| 3 | Image tagging: project-scoped or provider-agnostic? | Provider-agnostic (`harness-node`, `harness-python`). Matches current `pi-base` pattern. |
| 4 | Build context: new mode for harness builds? | New `build_context_harness()` function, peer of `build_context_agent()` and `build_context_sandbox()`. |
| 5 | Directory structure (`harness/` vs `libs/`)? | Deferred to chore session — structural cleanup is a prerequisite for landing the harness Dockerfiles. The proposed target structure (`harness/reasoning/nodes/`, `harness/capability/`, etc.) remains the design target. |

---

## References

| Document | Relevance |
|---|---|
| `tool_interface.md` — Provider Interface | Documents the current base.Dockerfile + provider.Dockerfile contract |
| `execution_model.md` — Build Context | Describes how build contexts are assembled |
| `provider_lifecycle.md` | Reasoning layer session arc |
| `containers.sh` — `build_agent()` | The build pipeline that assembles and caches the two-tier images |
| `design_settings_permissions_group_bind.md` rule 3 | UID Mapping surface area table — the 5 Dockerfiles that need changes |
| `roadmap.md` — Track C Phase 2 | The implementation phase that would benefit from consolidation |

## Resolution

**Status:** Resolved — partially implemented; python harness deferred to W1.

### What was implemented

Option 2 (two harness bases) was partially implemented:

| Component | Location | Status |
|---|---|---|
| `node-harness` (Tier 1) | `src/reasoning/node.dockerfile` | ✅ `FROM node:22.22.3-slim` with common system packages |
| Pi base (Tier 2) | `src/reasoning/providers/pi/base.dockerfile` | ✅ `FROM agent-node-base`, installs pi agent |
| OpenCode base (Tier 2) | `src/reasoning/providers/opencode/base.dockerfile` | ✅ `FROM agent-node-base`, installs opencode |
| Hermes base (Tier 2) | `src/reasoning/providers/hermes/base.dockerfile` | ❌ Independent `FROM python:3.11-slim` — does not inherit from any harness base |
| Python harness (Tier 1) | `src/reasoning/python.dockerfile` | ❌ Never built |

### Why Hermes diverges

Hermes requires both Python (ML dependencies, Hermes runtime) and Node.js (WhatsApp bridge, MCP servers). The planned `python-harness` base was never created. Instead, Hermes builds entirely independently via a multi-stage `FROM python:3.11-slim` with Node.js installed on top via NodeSource.

### UID Mapping

UID Mapping (`ARG HOST_UID`/`ARG HOST_GID` with collision handling) was implemented in all 4 provider Dockerfiles (`pi`, `opencode`, `hermes`, `claude-ai` where applicable) plus the sandbox Dockerfile — matching the planned 3-edit target in spirit, though the actual mechanism forked per provider rather than centralising in harness bases.

### Deferred

- **Python harness base** (`src/reasoning/python.dockerfile`) — not built. Hermes builds independently. See `devlog/roadmap.md` W1.
- **HERMES removal question** — if W1 is made to work without Hermes, consider removing Hermes support entirely rather than maintaining a dormant provider with a divergent build.

### References

- Node harness: `src/reasoning/node.dockerfile`
- Hermes base: `src/reasoning/providers/hermes/base.dockerfile`
- Roadmap: `devlog/roadmap.md` W1 — Hermes python base refactor deferred
- UID Mapping: provider Dockerfiles (`pi`, `opencode`, `hermes`), sandbox Dockerfile
