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

Pi (`@mariozechner/pi-coding-agent`, github: badlogic/pi-mono) is a TypeScript terminal coding agent with four execution modes: interactive TTY, print/JSON (`pi -p`), RPC (JSON over stdio), and SDK. It supports multiple LLM providers — Anthropic, OpenAI, Google, OpenRouter, Ollama, and more — authenticated via API key or OAuth. It has no native web UI or serve equivalent. Context files (`AGENTS.md`, `SYSTEM.md`) are loaded from the working directory at startup. The harness integration path is straightforward: npm install, minimal Dockerfile, API key injection. The primary open question is whether the absence of a `serve` mode is acceptable or needs resolution.

---

## Findings Against Investigation Questions

### 1. Execution model

**`start` (interactive terminal):** Supported. Pi runs as an interactive TUI via `pi` with no arguments (or with an initial prompt). `docker run -it` allocates a TTY that Pi's terminal UI works correctly within. Ctrl-C propagates. No special configuration required.

**`dry-run` (liveness check):** Supported. Pi initialises cleanly and can be exited after startup.

**`serve` (browser UI):** Not supported. Pi has no built-in HTTP server and no first-party remote control equivalent analogous to Claude Code's Remote Control. The four Pi modes (interactive, print, RPC, SDK) are all local or programmatic — none expose a browser interface. Third-party wrappers are not known to exist for Pi specifically. Options: accept `serve` as unsupported for this provider, or evaluate whether the RPC mode can serve as a foundation for a thin operator-built bridge. Neither is recommended without further scoping; the simplest position is to declare `serve` unsupported and use `start`.

**`headless` (deferred, M2):** Supported via `pi -p "<task>"`. Outputs to stdout and exits. Tool set can be restricted via `--tools`. Model and provider selectable via `--model` and `--provider` flags, or using the `provider/model` shorthand. Compatible with the headless invocation pattern used for the M2 autonomous task path.

### 2. Authentication

Pi supports both API key and OAuth authentication:

- **API key:** Set via environment variable per provider (e.g. `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`). Injected at runtime, never baked into the image. Fully compatible with the existing `.env` / secrets handling model.
- **OAuth:** `/login` in interactive mode. Not viable for automated or containerised sessions; API key is the correct path for harness integration.

Multi-provider support is a Pi differentiator: the operator selects model and provider via env var or CLI flag, with no code changes required to switch between Anthropic, OpenAI, Google, or OpenRouter. This makes Pi provider-agnostic in a way that OpenCode and Claude Code are not.

### 3. Dockerfile and image

Pi is an npm package (`@mariozechner/pi-coding-agent`), installed globally via `npm install -g @mariozechner/pi-coding-agent`. Node.js is already present in the current OpenCode image. The Pi provider Dockerfile is expected to be minimal — replace the OpenCode install step with the npm global install. No additional system dependencies anticipated. Pi is MIT licensed with no commercial restrictions.

### 4. Harness reuse

- **`libs/snapshot.sh`, `libs/diff.sh`, `libs/image.sh`** — fully reusable unchanged.
- **`scripts/apply_workspace.sh`** — fully reusable unchanged.
- **`providers/opencode/build.sh`** — reusable pattern; `providers/pi/build.sh` follows the same shape with a different Dockerfile path.
- **`scripts/start_agent.sh`** — fully reused. Provider-specific section dispatches to `providers/pi/run.sh`.
- **`container-entrypoint.sh`** — shared sections fully reused. Provider-specific `exec` step invokes `pi` (interactive) or `pi -p` (headless) per mode.

Context file injection: Pi reads `AGENTS.md` and `SYSTEM.md` from the working directory at startup. Placing the agent brief as `AGENTS.md` in `sandbox/` via the entrypoint is the correct mechanism — no code changes needed.

### 5. Sandbox constraint compatibility

Pi's built-in tools (read, write, edit, bash, grep, find, ls) operate relative to the working directory by default. Setting `WORKDIR` to `sandbox/` at entrypoint startup confines file operations correctly. No additional restriction mechanism is documented; this is the same model as OpenCode and Claude Code. The security model is preserved.

Note: Pi's security warning in its own documentation is about third-party Pi packages ("run with full system access"). The built-in tool set does not have this issue. No third-party Pi packages should be installed in the provider image.

### 6. Document repository suitability

Not yet validated. Requires a live test against an initialised vault. Deferred to M2.5 (Vault Capability Layer Prototype). Pi's multi-provider flexibility is potentially an advantage here — the operator could select a model optimised for large-context text tasks without changing the harness or provider.

---

## Open Questions

- **`serve` mode** — no native equivalent; no first-party remote control. Declare unsupported, or investigate RPC mode as a bridge foundation. The simplest position is to declare `serve` unsupported for this provider.
- **Document repository suitability** — unvalidated pending live test (M2.5).

---

## Constraints

- The operator's ability to review and reject changes before they reach the repository is a system invariant.
- Secrets and gitignored files must not be visible to the agent.
- No unaudited third-party dependencies (Pi packages) inside the container trust boundary.

---

## Resolution

**Recommendation: viable. Supported modes: `start`, `dry-run`. `serve` unsupported.**

All harness invariants are preserved. The snapshot pipeline, diff mechanism, `make apply`, and sandbox isolation carry over without structural changes. The provider interface (`build.sh` + `run.sh` under `providers/pi/`) is the correct integration point.

`serve` is confirmed unsupported by the Pi developer — no native web UI or remote control equivalent exists. Two future paths exist if `serve` becomes a requirement for this provider: (1) manually constructing an RPC bridge using Pi's built-in RPC mode (JSON over stdio); (2) integrating an open-source web UI that speaks to the RPC bridge. Neither is recommended without a specific use case driving it; operators wanting a browser interface should use the Hermes or Claude Code provider instead.

`providers/pi/run.sh` should handle `start` and `dry-run`; error clearly on `serve`.

The one remaining unknown — document repository suitability — is deferred to M2.5 and does not affect the integration recommendation.

No codebase changes arise from this investigation. Implementation proceeds under M2.2: create `providers/pi/` with `Dockerfile`, `build.sh`, and `run.sh`. This decision is recorded in the parent story [story_provider_knowledge_store.md](story_provider_knowledge_store.md).
