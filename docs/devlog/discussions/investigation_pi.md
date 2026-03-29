# Investigation — Pi as Knowledge Store Provider

**Status:** Resolved. Recommendation: viable. `serve` unsupported natively; RPC bridge or open-source web UI over RPC is a viable future path if needed.

**Direction:** Direction 1 — Provider replacement  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

## Required Reading

- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
- [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report must answer.

---

## Summary

Pi (`@mariozechner/pi-coding-agent`, github: badlogic/pi-mono) is a TypeScript terminal coding agent with four execution modes: interactive TUI, print/JSON (`pi -p`), RPC (JSON over stdio), and SDK. It supports multiple LLM providers — Anthropic, OpenAI, Google, OpenRouter, AWS Bedrock, and more — authenticated via API key or OAuth. It has no native web UI or serve equivalent. Context files (`AGENTS.md`, `CLAUDE.md`, `SYSTEM.md`, `APPEND_SYSTEM.md`) are discovered from the working directory and global config at startup. The harness integration path is straightforward: npm install, minimal Dockerfile, API key injection. The primary open question — whether the absence of a `serve` mode is acceptable — is confirmed: `serve` is declared unsupported for this provider.

**Current version as of March 2026:** 0.63.1. The project releases at a very high cadence (~33 minor versions in three months). Pin the version in `base.Dockerfile`.

---

## Findings Against Investigation Questions

### 1. Execution model

**`start` (interactive terminal):** Supported. Pi runs as an interactive TUI via `pi` with no arguments (or with an initial prompt). `docker run -it` allocates a TTY that Pi's terminal UI works correctly within.

**`dry-run` (liveness check):** Supported. Pi initialises cleanly and can be exited after startup.

**`serve` (browser UI):** Not supported. Confirmed by the Pi developer — no native web UI or remote control equivalent exists. Two future paths exist if `serve` becomes a requirement: (1) manually constructing an RPC bridge using Pi's `--mode rpc` (JSON over stdio); (2) integrating an open-source web UI that speaks to the RPC bridge. Neither is recommended without a specific use case; operators wanting a browser interface should use the Hermes or OpenCode provider.

**`headless` (deferred, M2):** Supported via `pi -p "<task>"`. Outputs to stdout and exits. Tool set can be restricted via `--tools`. Model and provider selectable via `--model` and `--provider` flags. Compatible with the headless invocation pattern for the M2 autonomous task path.

### 2. Authentication

API keys are set via per-provider environment variables. The confirmed variable names:

| Variable | Provider |
|---|---|
| `ANTHROPIC_API_KEY` | Anthropic |
| `OPENAI_API_KEY` | OpenAI |
| `GOOGLE_API_KEY` | Google Gemini |
| `GOOGLE_CLOUD_API_KEY` | Google Vertex AI |
| `OPENROUTER_API_KEY` | OpenRouter |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Amazon Bedrock |
| `AZURE_OPENAI_API_KEY` / `AZURE_OPENAI_BASE_URL` | Azure OpenAI |

Auth priority order: CLI `--api-key` flag > `~/.pi/agent/auth.json` > environment variables. For containers, environment variables are the correct path. OAuth login is also available for subscription-based access but is not viable for automated/containerised sessions.

Pi-specific env vars relevant to container integration:
- `PI_SKIP_VERSION_CHECK=1` — suppresses update checks on startup (set via provider overlay)
- `PI_CODING_AGENT_DIR` — overrides the `~/.pi/agent` config directory
- `PI_CACHE_RETENTION=long` — extended prompt caching

### 3. Context files

Pi discovers and concatenates context files from multiple locations in order:

**`AGENTS.md`** (and its alias **`CLAUDE.md`**): Loaded from (1) `~/.pi/agent/AGENTS.md` (global), (2) parent directories walking up from the working directory, (3) the working directory itself. All matching files are concatenated. Optional — not mandatory.

**`SYSTEM.md`**: Placed at `.pi/SYSTEM.md` (project-level) or `~/.pi/agent/SYSTEM.md` (global). Replaces the default system prompt entirely. Optional.

**`APPEND_SYSTEM.md`**: Appends to the default system prompt without replacing it. Optional.

For harness integration, two mechanisms work in combination:
1. **Project-level `AGENTS.md`**: The operator commits an `AGENTS.md` to the project repository. It enters the snapshot and lands in `sandbox/` (the working directory), where Pi finds it naturally.
2. **Global fallback `AGENTS.md`**: A stub `AGENTS.md` is seeded into `AGENT_HOME` (`~/.pi/agent/`) via `providers/pi/config/AGENTS.md`. Pi loads this as the global context before the project-level file. Content is concatenated, so the stub prepends harness-specific instructions to the operator's project brief.

The global stub is seeded only if absent (seed-if-missing logic in `provider-entrypoint.sh`) — operators who customise the global brief will not have their changes overwritten.

### 4. Dockerfile and image

Pi is an npm package (`@mariozechner/pi-coding-agent`), installed globally via `npm install -g @mariozechner/pi-coding-agent`. Node.js ≥20.6.0 is required. The `node:20-slim` base image satisfies this. The Pi provider Dockerfile is minimal — the base image handles the npm global install. No additional system dependencies are required.

**Version pinning:** Given the rapid release cadence, the version must be pinned in `base.Dockerfile`. The base image is rebuilt only on explicit `--rebuild-base`, so the pinned version persists until the operator decides to upgrade.

### 5. Harness reuse

All current harness infrastructure (`scripts/`, `libs/`, diff pipeline, snapshot pipeline) is fully reused without modification. The Pi provider integrates via the standard provider interface:

- `providers/pi/base.Dockerfile` — Node 20 slim + pinned npm global install
- `providers/pi/provider.Dockerfile` — standard pattern; `AGENT_HOME=/home/agentuser/.pi/agent`, `PROVIDER_NAME=pi`
- `providers/pi/docker-compose.serve.yml` — required stub; documents serve as unsupported
- `providers/pi/.env.example` — API key stubs for all supported LLM providers
- `providers/pi/docker-compose.pi.yml` — sets `PI_SKIP_VERSION_CHECK=1`, injects API key env vars
- `providers/pi/setup.sh` — pre-creates `$SANDBOX_DIR/.pi/` for copy-out landing
- `providers/pi/config/AGENTS.md` — global fallback brief stub; seeded into `AGENT_HOME` if absent

No changes to `scripts/` or `libs/` were required to add Pi. This confirms the provider interface is fully decoupled from the harness core.

### 6. Sandbox constraint compatibility

Pi's working directory defaults to the current directory. `WORKDIR /home/agentuser/sandbox` in the Dockerfile confines all file operations to the sandbox. Pi's built-in tool set (read, write, edit, bash, grep, find, ls) operates relative to the working directory. No additional restriction mechanism is needed.

Note: Pi's security warning about "full system access" refers to third-party Pi packages, not the built-in tool set. No third-party Pi packages should be installed in the provider image.

### 7. Document repository suitability

Not yet validated. Requires a live test against an initialised vault. Deferred to M2.5 (Vault Capability Layer Prototype). Pi's multi-provider flexibility is a potential advantage here — the operator can select a model optimised for large-context text tasks without changing the harness or provider.

---

## Open Questions

- **Document repository suitability** — unvalidated pending live test (M2.5).

---

## Constraints

- The operator's ability to review and reject changes before they reach the repository is a system invariant.
- Secrets and gitignored files must not be visible to the agent.
- No unaudited third-party dependencies (Pi packages) inside the container trust boundary.
- Pi version must be pinned in `base.Dockerfile` due to rapid release cadence.

---

## Resolution

**Recommendation: viable. Implemented. Supported modes: `start`, `dry-run`. `serve` unsupported.**

All harness invariants are preserved. The snapshot pipeline, diff mechanism, `make apply`, and sandbox isolation carry over without structural changes. Pi was added as `providers/pi/` with no changes to `scripts/` or `libs/`, confirming the provider interface is fully decoupled.

`serve` is confirmed unsupported — no native web UI or remote control equivalent exists. Two future paths exist if `serve` becomes a requirement: (1) RPC bridge using Pi's `--mode rpc`; (2) open-source web UI over the RPC bridge. Neither is recommended without a specific use case.

The one remaining unknown — document repository suitability — is deferred to M2.5.

Implementation is recorded in session handover `20260329-03-impl-pi_provider.md`. Provider files are under `providers/pi/`.
