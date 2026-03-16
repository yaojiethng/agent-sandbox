# Investigation — Claude Code as Knowledge Store Provider

**Status:** In progress. Open questions remain on integration model and wrapper evaluation.

**Direction:** Direction 1 — Provider replacement  
**Parent story:** [story_provider_knowledge_store.md](story_provider_knowledge_store.md)

---

> **Required reading before this document:**
> - [`docs/architecture/execution_model.md`](../architecture/execution_model.md) — container lifecycle, mount shape, and entrypoint sequence.
> - [`docs/architecture/security.md`](../architecture/security.md) — trust boundaries and security invariants.
> - [story_provider_knowledge_store.md](story_provider_knowledge_store.md) — investigation questions this report answers.

---

## Summary

Claude Code (`claude`) is a terminal-interactive CLI agent with no native serve/web mode. It satisfies `start` and `dry-run` cleanly, and has a viable headless invocation path (`claude -p`) for future M2 work. `serve` has no native equivalent — two options exist: a third-party web wrapper inside the container, or accepting that this provider does not support `serve`. This is the primary open question blocking a recommendation.

---

## Findings Against Investigation Questions

### 1. Execution model

**`start` (interactive terminal):** Supported. `docker run -it` allocates a pseudo-TTY passed through to the container process. Claude Code's terminal UI resizes with the window, responds to clicks where the app supports it, and Ctrl-C propagates correctly. No special configuration required.

**`dry-run` (liveness check):** Supported. Claude Code initialises cleanly and can be exited after startup confirmation.

**`serve` (interactive terminal wrapped in webapp):** No native equivalent. Claude Code has no built-in HTTP server. Third-party community wrappers exist (`claude-code-webui` by sugyan, `claude-code-web` by vultuk) that spawn `claude` as a child process and proxy it through a browser UI. These are not part of Claude Code itself. Two options:

- Install a wrapper inside the container image — preserves the current operator browser experience but introduces an unaudited third-party dependency inside the trusted container boundary
- Declare `serve` unsupported for this provider — operator uses `start` (direct terminal) instead

**`headless` (deferred, M2):** Supported via `claude -p "<task>"`. Processes a prompt, outputs to stdout, exits. Tool permissions declared via `--allowedTools`; `--dangerously-skip-permissions` is appropriate for isolated containers. Output format configurable (`text`, `json`, `stream-json`). See Deferred section below.

### 2. Authentication

Two paths work cleanly in a container without interactive OAuth (which requires a browser and is not viable headlessly):

- **`ANTHROPIC_API_KEY` environment variable** — pay-as-you-go API access. Same pattern as OpenCode. Injected at runtime via `-e`, never baked into the image. Maps directly onto the existing `.env` / secrets handling model.
- **`CLAUDE_CODE_OAUTH_TOKEN` environment variable** — long-lived OAuth token generated once on the host via `claude setup-token`, then injected as an env var. Correct path for Claude.ai subscription users. Long-lived, unlike `~/.claude/.credentials.json` files which expire in ~6 hours.

Both are operator configuration choices, not harness constraints. The harness injects whichever is present via env var with no code changes needed to support either.

### 3. Dockerfile and image

Claude Code is an npm package (`@anthropic-ai/claude-code`), installed globally via `npm install -g @anthropic-ai/claude-code`. Node.js is already present in the current OpenCode image (OpenCode is also Node-based). The Dockerfile for a Claude Code provider is expected to be minimal — replace the OpenCode install step with the npm global install. No additional system dependencies anticipated.

### 4. Harness reuse

- **`libs/snapshot.sh`, `libs/diff.sh`, `libs/image.sh`** — fully reusable unchanged.
- **`scripts/apply_workspace.sh`** — fully reusable unchanged.
- **`build_agent.sh`** — reusable with a different Dockerfile path.
- **`start_agent.sh`** — shared sections (snapshot construction, mount building, env loading) are M2.3 extraction targets. Provider-specific section is the `docker run` invocation args and mode dispatch.
- **`container-entrypoint.sh`** — shared sections (snapshot init, diff trap, autosave) are M2.3 extraction targets. Provider-specific section is the final `exec` step — replace `opencode serve ...` with the chosen Claude Code invocation per mode.

Provider interface definition is M2.3 (Reasoning Layer Modularisation) scope. M1.7 was superseded by M2.3.

### 5. Sandbox constraint compatibility

Claude Code's file operations scope to the working directory by default. Setting the container `WORKDIR` to `sandbox/` at entrypoint startup should confine file operations correctly, consistent with how OpenCode is currently constrained. The security model is preserved.

### 6. Document repository suitability

Not yet validated. This is the core assumption motivating the investigation and requires a live test against an initialised vault. Cannot be confirmed until the provider is integrated and KV5 validation tasks are run.

---

## Open Questions

- **Integration model for `serve`** — third-party web wrapper vs declaring `serve` unsupported. This must be decided before Dockerfile and entrypoint design can proceed. If wrapper: evaluate candidates (see below).

- **Third-party wrapper evaluation** — if the wrapper path is chosen, candidates to evaluate: `claude-code-webui` (sugyan) and `claude-code-web` (vultuk). Evaluation criteria: active maintenance, licence, security posture, whether it runs cleanly in a minimal Ubuntu container, and whether it handles authentication without requiring interactive setup.

- **Agent brief surfacing in `start` mode** — `CLAUDE.md` placed in `sandbox/` by the entrypoint is the natural mechanism; Claude Code reads it automatically at startup. Needs confirming. In wrapper mode, depends on the wrapper's behaviour.

- **Document repository suitability** — unvalidated. Requires live test.

---

## Deferred — Headless Mode (`claude -p`)

Claude Code's headless non-interactive mode is a viable M2 execution path but is out of scope for the current integration target, which matches the existing serve/start interactive model.

Relevant findings for when M2 is reached:

- Invoked via `claude -p "<task>"` — processes prompt, outputs to stdout, exits
- `--allowedTools` declares permitted tools explicitly; `--dangerously-skip-permissions` appropriate for isolated containers
- `--system-prompt-file` passes the agent brief in non-interactive mode
- Session resumption via `--resume <session-id>` or `--continue`; sessions stored as JSONL in `~/.claude/` (~200K token context)
- Output format: `text`, `json`, or `stream-json`

---

## Next Steps

1. Decide integration model for `serve` — wrapper or unsupported (M2.3 prerequisite decision)
2. If wrapper: complete evaluation of candidates
3. M2.3 — define reasoning layer interface; build `providers/claude-code/` against it
4. Validate document repository suitability (capability layer live test, M2.1+)
