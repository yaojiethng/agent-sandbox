# Investigation — Claude Code as Knowledge Store Provider

**Status:** Resolved. Recommendation: viable. `serve` equivalent is Remote Control (`claude --remote-control`), a first-party Anthropic feature exposing the session via `claude.ai/code`; requires claude.ai subscription auth (no API key support).

**Direction:** Direction 1 — Provider replacement  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

## Required Reading

- [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
- [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
- [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report answers.

---

## Summary

Claude Code (`claude`) is a terminal-interactive CLI agent with a first-party remote browser/mobile interface via Remote Control. It satisfies `start` and `dry-run` cleanly. The `serve` analogue is Remote Control (`claude --remote-control`), which registers the local session with the Anthropic API and exposes it through `claude.ai/code` and the Claude mobile app — no third-party wrapper required. Remote Control requires claude.ai subscription auth; API key auth is not supported for this mode. A viable headless invocation path (`claude -p`) exists for future M2 work. All harness invariants are preserved without codebase changes.

---

## Findings Against Investigation Questions

### 1. Execution model

**`start` (interactive terminal):** Supported. `docker run -it` allocates a pseudo-TTY passed through to the container process. Claude Code's terminal UI resizes with the window, responds to clicks where the app supports it, and Ctrl-C propagates correctly. No special configuration required.

**`dry-run` (liveness check):** Supported. Claude Code initialises cleanly and can be exited after startup confirmation.

**`serve` (browser UI) — Remote Control:** Claude Code has a first-party remote control feature that serves as the `serve` equivalent. Running `claude --remote-control` (or starting an interactive session with remote control enabled) registers the local process with the Anthropic API via outbound HTTPS. The operator connects from any browser via `claude.ai/code`, the Claude iOS app, or Claude Android app. The session executes locally; the web/mobile interface is a viewport into that local session. Conversation history is synchronised across all connected devices.

Key properties:
- **Local execution:** files, MCP servers, tools, and project configuration stay on the machine running Claude Code. Nothing moves to Anthropic's cloud.
- **Outbound only:** Claude Code makes outbound HTTPS connections to the Anthropic API. No inbound ports are opened. Works behind NAT and firewalls without configuration.
- **Short-lived credentials:** multiple credentials, each scoped to a single purpose, expiring independently.
- **One session per process:** each Claude Code instance supports one remote connection at a time.
- **Auth constraint:** Remote Control requires claude.ai subscription auth (Pro or Max plan). API key authentication is explicitly not supported for Remote Control. This is a constraint on the operator's subscription, not a harness constraint.

In a containerised deployment, the container requires outbound HTTPS access to the Anthropic API — the same requirement as standard Claude Code operation. Remote Control should work inside a container with network access enabled (standard mode).

**`headless` (deferred, M2):** Supported via `claude -p "<task>"`. Processes a prompt, outputs to stdout, exits. Tool permissions declared via `--allowedTools`; `--dangerously-skip-permissions` is appropriate for isolated containers. Output format configurable (`text`, `json`, `stream-json`). See Deferred section below.

### 2. Authentication

**For `start`, `dry-run`, and `headless`:**
- **`ANTHROPIC_API_KEY` environment variable** — pay-as-you-go API access. Injected at runtime via `-e`, never baked into the image. Maps directly onto the existing `.env` / secrets handling model.
- **`CLAUDE_CODE_OAUTH_TOKEN` environment variable** — long-lived OAuth token generated once on the host via `claude setup-token`, then injected as an env var. Correct path for Claude.ai subscription users.

**For Remote Control (`serve` equivalent):**
- API key auth is not supported. The operator must authenticate via claude.ai (`CLAUDE_CODE_OAUTH_TOKEN` or interactive `/login`). This means Remote Control is only available to Pro/Max plan subscribers.
- This is an operator constraint, not a harness constraint. The harness injects `CLAUDE_CODE_OAUTH_TOKEN` via env var; the token is provisioned by the operator outside the container.

### 3. Dockerfile and image

Claude Code is an npm package (`@anthropic-ai/claude-code`), installed globally via `npm install -g @anthropic-ai/claude-code`. Node.js is already present in the current OpenCode image. The Claude Code provider Dockerfile is expected to be minimal — replace the OpenCode install step with the npm global install. No additional system dependencies anticipated.

### 4. Harness reuse

- **`libs/snapshot.sh`, `libs/diff.sh`, `libs/image.sh`** — fully reusable unchanged.
- **`scripts/apply_workspace.sh`** — fully reusable unchanged.
- **`providers/opencode/build.sh`** — reusable pattern; `providers/claude-code/build.sh` follows the same shape with a different Dockerfile path.
- **`scripts/start_agent.sh`** — shared sections (snapshot construction, mount building, env loading) are fully reused. Provider-specific section is the dispatch to `providers/claude-code/run.sh`.
- **`container-entrypoint.sh`** — shared sections (snapshot init, diff trap, autosave) are fully reused. Provider-specific section is the final `exec` step — replace `opencode serve ...` with the Claude Code invocation per mode.

### 5. Sandbox constraint compatibility

Claude Code's file operations scope to the working directory by default. Setting the container `WORKDIR` to `sandbox/` at entrypoint startup confines file operations correctly for `start`, `dry-run`, and Remote Control modes, consistent with how OpenCode is currently constrained. The security model is preserved.

Note: a known directory restriction issue (GitHub #3139) affects `claude mcp serve` mode specifically. Remote Control is a different code path and does not share this issue.

### 6. Agent brief surfacing

`CLAUDE.md` placed in `sandbox/` by the entrypoint is the correct mechanism. Claude Code reads `CLAUDE.md` automatically at startup from the working directory. No additional configuration or entrypoint logic is required. This applies to all modes including Remote Control — the brief is loaded at process start before any remote connection is established.

### 7. Document repository suitability

Not yet validated. Requires a live test against an initialised vault. Deferred to M2.5 (Vault Capability Layer Prototype) — this is the same deferred item as in `investigation_claude_desktop.md` and is not a blocker for the provider integration recommendation.

---

## Constraints

- The operator's ability to review and reject changes before they reach the repository is a system invariant. Any path that does not preserve `staged.diff` and the apply workflow is non-conforming.
- Secrets and gitignored files must not be visible to the agent. Gitignored files must be excluded via the snapshot pipeline.
- No unaudited third-party dependencies may be introduced inside the container trust boundary.
- Remote Control requires claude.ai subscription auth (Pro/Max). Operators using API key auth cannot use Remote Control mode; they fall back to `start`.

---

## Deferred — Headless Mode (`claude -p`)

Claude Code's headless non-interactive mode is a viable M2 execution path but is out of scope for the current integration target.

Relevant findings for when M2 autonomous task work is reached:

- Invoked via `claude -p "<task>"` — processes prompt, outputs to stdout, exits
- `--allowedTools` declares permitted tools explicitly; `--dangerously-skip-permissions` appropriate for isolated containers
- `--system-prompt-file` passes the agent brief in non-interactive mode
- Session resumption via `--resume <session-id>` or `--continue`; sessions stored as JSONL in `~/.claude/` (~200K token context)
- Output format: `text`, `json`, or `stream-json`

---

## Resolution

**Recommendation: viable. Supported modes: `start`, `dry-run`, `serve` (via Remote Control, requires claude.ai subscription auth).**

All harness invariants are preserved. The snapshot pipeline, diff mechanism, `make apply`, and sandbox isolation all carry over without structural changes. The provider interface established in M2.2 (`build.sh` + `run.sh` under `providers/claude-code/`) is the correct integration point.

Remote Control is the first-party `serve` equivalent: the operator runs `claude --remote-control` inside the container, which registers the session with the Anthropic API and exposes it via `claude.ai/code` and the Claude mobile app. No third-party wrapper is needed. The container requires outbound HTTPS to the Anthropic API, which is already the case in standard mode. The auth constraint (claude.ai subscription required; API key not supported for Remote Control) is an operator-level constraint, not a harness constraint. `providers/claude-code/run.sh` should handle `start`, `dry-run`, and `serve` (Remote Control) as named modes.

The one remaining unknown — document repository suitability — is deferred to M2.5 and does not affect the integration recommendation.

No codebase changes arise from this investigation. Implementation proceeds under M2.2: create `providers/claude-code/` with `Dockerfile`, `build.sh`, and `run.sh`. This decision is recorded in the parent story [story_provider_knowledge_store.md](story_provider_knowledge_store.md).
