# Investigation — Hermes as Knowledge Store Provider

**Status:** Resolved. Recommendation: viable. `terminal.backend: local` satisfies harness constraints; `serve` via Open WebUI compose service; persistent memory is a differentiating capability for vault workflows.

**Direction:** Direction 1 — Provider replacement  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

## Required Reading

- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
- [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report must answer.

---

## Summary

Hermes (NousResearch/hermes-agent) is a Python agent platform with a full TUI, messaging gateway, persistent memory, and learning loop. It is designed to run entirely inside a Docker container (PR #1841), with tool execution via a configurable terminal backend. When configured with `terminal.backend: local`, Hermes executes all tool calls inside its own container environment — no Docker socket access required, no Docker-in-Docker. The harness manages the container lifecycle externally; Hermes is unaware of this. The sandbox working directory constraint is satisfied by setting `cwd` at container startup. `serve` has a genuine equivalent via Hermes's OpenAI-compatible API server and Open WebUI as a browser front-end. The primary open questions are the two-container model required for `serve` and the Dockerfile complexity relative to other candidates.

---

## Findings Against Investigation Questions

### 1. Execution model

**`start` (interactive terminal):** Supported. `hermes` starts a full TUI. `docker run -it` passes through a TTY correctly. The terminal backend is configured via `config.yaml` (`terminal.backend: local`); with `local`, all tool calls run inside the container using the container's own shell — no Docker socket access required. This is the correct configuration for harness integration: the harness manages the container, Hermes manages its tools within it.

**`dry-run` (liveness check):** Supported. `hermes doctor` runs diagnostics and exits, providing a liveness check. Adaptable to the harness dry-run pattern.

**`serve` (browser UI via Open WebUI):** Supported via a two-component model. Hermes exposes an OpenAI-compatible HTTP API server. Open WebUI (`ghcr.io/open-webui/open-webui:main`) connects to it as a browser front-end over that API. The operator accesses the UI at `localhost:3000` (or configured port). This is a genuine `serve` equivalent: a browser coding interface driven by a Hermes backend. The integration requires Open WebUI as an additional container, managed separately from the Hermes container. Authentication to the API endpoint is via a shared secret key injected as an env var.

This is a first-class supported integration (documented by Nous Research), not a third-party wrapper. However, it is a two-container model: the Hermes provider container plus an Open WebUI container. How the operator manages the Open WebUI container is an open question — it could be a separate `make serve` target or a compose file alongside the harness.

**`headless` (deferred, M2):** Supported via `run_agent.py` (`AIAgent` class) for programmatic invocation. Also via the API server for single-shot requests. Viable for the M2 autonomous task path.

### 2. Authentication

Hermes supports API key configuration via `.env` file and env vars, compatible with the harness secrets model. Key env vars:
- `OPENROUTER_API_KEY` — recommended; gives access to 200+ models via a single key
- `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GOOGLE_API_KEY` — direct provider keys
- `API_SERVER_KEY` — shared secret for the API server (used by Open WebUI in `serve` mode)

All are injectable at runtime via env var, never baked into the image. Maps directly onto the existing `.env` / secrets handling model. Multi-provider is a Hermes strength: the operator selects provider and model via config, with no code changes.

### 3. Dockerfile and image

**Complexity — the main differentiator from other candidates.** Hermes is Python with two required git submodules (`mini-swe-agent` for the terminal backend, `tinker-atropos` for RL). The full install involves: Python 3.11, uv, git submodule init, `uv pip install -e ".[all]"`, `uv pip install -e "./mini-swe-agent"`, optional Node.js for browser tools. The resulting image is substantially larger than the Pi or Claude Code provider images.

Mitigations: `mini-swe-agent` can be excluded if only `terminal.backend: local` is used (the local backend does not use `mini-swe-agent`). `tinker-atropos` (RL training) is optional and not relevant to this use case. A minimal Hermes image for harness use would include: Python 3.11, uv, core Hermes install, `mini-swe-agent` excluded. Still larger than Pi/Claude Code, but manageable.

Submodule supply-chain note: two additional git repositories enter the trust boundary at build time. Both are NousResearch-controlled, which reduces but does not eliminate the concern. Pinned submodule commits (as in the repo) are the correct posture.

### 4. Harness reuse

- **`libs/snapshot.sh`, `libs/diff.sh`, `libs/image.sh`** — fully reusable unchanged.
- **`scripts/apply_workspace.sh`** — fully reusable unchanged.
- **`providers/opencode/build.sh`** — reusable pattern; `providers/hermes/build.sh` follows the same shape with a different Dockerfile.
- **`scripts/start_agent.sh`** — fully reused. Provider-specific section dispatches to `providers/hermes/run.sh`.
- **`container-entrypoint.sh`** — shared sections fully reused. Provider-specific `exec` step invokes `hermes` (interactive) or API server mode per mode.

### 5. Sandbox constraint compatibility

When `terminal.backend: local`, Hermes executes tool calls in its working directory. Setting `cwd: "."` in `config.yaml` (relative to the container's `WORKDIR`, set to `sandbox/` by the entrypoint) confines terminal tool execution to the sandbox. 

Important nuance: Hermes's file read/write tools operate on the filesystem directly and are not explicitly bounded to `cwd`. This is the same posture as Pi and Claude Code — working directory is the de facto boundary, not a hard sandbox enforcement. The security model is equivalent to other candidates.

No Docker socket access is required. The harness security invariant ("The container must not have access to the Docker socket") is satisfied with `terminal.backend: local`.

### 6. Context file injection

Hermes loads `AGENTS.md` from the project working directory at session start, identical to Pi. Placing the agent brief as `AGENTS.md` in `sandbox/` via the entrypoint is the correct mechanism. `SOUL.md` (persona/personality) is loaded from `~/.hermes/SOUL.md`; the entrypoint can seed this file to inject system-level instructions. Both are straightforward and require no code changes.

### 7. Document repository suitability

Not yet validated. Requires a live test against an initialised vault. Deferred to M2.5 (Vault Capability Layer Prototype). Hermes's persistent memory and skill-creation features may be an advantage for long-running vault workflows, but this is speculative.

---

## Open Questions

- **`serve` — Open WebUI container management:** The two-container model is confirmed viable, but the operator workflow is not yet defined. Options: a separate `make serve` target that also starts Open WebUI; a compose file alongside the harness; or declaring `serve` mode operator-managed with documentation only. The harness manages the Hermes container; Open WebUI is an additional concern.

- **Dockerfile complexity:** Is the larger image size and submodule dependency acceptable, given that Pi and Claude Code offer simpler builds? This is a tradeoff decision, not a technical blocker.

- **Document repository suitability** — unvalidated pending live test (M2.5).

---

## Constraints

- The operator's ability to review and reject changes before they reach the repository is a system invariant.
- Secrets and gitignored files must not be visible to the agent. Gitignored files must be excluded via the snapshot pipeline.
- No Docker socket access inside the container.
- `terminal.backend` must be set to `local` (not `docker`) in the provider image — the harness manages isolation, not Hermes.

---

## Resolution

**Recommendation: viable. Supported modes: `start`, `dry-run`, `serve` (via Open WebUI compose service).**

All harness invariants are preserved. The snapshot pipeline, diff mechanism, `make apply`, and sandbox isolation carry over without structural changes. `terminal.backend: local` means Hermes executes tool calls inside the harness-managed container — no Docker socket access required. The harness owns the container lifecycle; Hermes is unaware of this and behaves correctly.

**`serve` model:** The `providers/hermes/` compose template defines the Open WebUI service (`ghcr.io/open-webui/open-webui:main`) alongside the Hermes container. The operator runs `make serve`; the harness compose composition pattern handles both. The Open WebUI container connects to Hermes's API endpoint via `host.docker.internal` or a shared compose network. `API_SERVER_KEY` is injected as an env var to both containers.

**Dockerfile complexity:** Acceptable given the capability tradeoff. Persistent cross-session memory and skill creation are genuinely additive for vault workflows — Hermes can build and recall navigation patterns across sessions in a way Pi and Claude Code cannot. The heavier image is the cost of this capability.

**Compose template scope:** Current compose templates are scoped to OpenCode only. Provider-specific templates need refactoring to be provider-agnostic before any second provider's `serve` mode works correctly. This is an M2.2 implementation task, not a blocker for this recommendation. Recorded in the handover for roadmap placement.

**Remaining unknown:** Document repository suitability — deferred to M2.5. Not a blocker for the integration recommendation.

No codebase changes arise from this investigation. Implementation proceeds under M2.2: create `providers/hermes/` with `Dockerfile`, `build.sh`, `run.sh`, and a compose template that includes the Open WebUI service. This decision is recorded in the parent story [story_provider_knowledge_store.md](story_provider_knowledge_store.md).
