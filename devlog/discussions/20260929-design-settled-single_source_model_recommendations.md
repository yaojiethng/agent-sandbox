# Single-source agent model recommendations

**Type:** design
**Status:** settled
**Date:** 2026-09-29
**Milestone:** M3.2.1 - Loops as Workflows

## Context

Prompts, skills, and the provider-layer `AGENTS.md` each hardcode which provider, model, and thinking level an agent uses. `review-pass-run.md`, `review-loop-run.md`, the thermo-nuclear skill, and the provider layer all name `deepseek-v4-flash` and `glm-5.3-flash`; `auto.md` names `deepseek-v4-flash`. Changing the effective model for cost or availability means editing every prompt. The roadmap row `Prompt/AGENTS.md convention: single-source agent recommendations per role` names the fix: recommend provider / model / thinking level per role in one place, and have prompts read it by role.

The project-level `AGENTS.md` also carries a stale paragraph naming Claude Chat and `/mnt/user-data`, an interface removed as a provider and a directory absent here. The provider-layer `AGENTS.md` states an incorrect rule about model-resolution warnings.

## Options Considered

### Single-source location

- **Provider-layer `~/.pi/agent/AGENTS.md`.** This file loads for every project. A model recommendation there is a global dictate, and a per-role table does not fit a small generic file that must stay project-agnostic. Rejected.
- **Project-level `AGENTS.md`.** Loaded by this project's agents and subagents. It is the single writable home for a per-project model table. **Adopted.**

### Role tag convention

- **`@ROLE`.** Pi reserves `@` for file links. A tag that reads as a link is ambiguous in prose. Rejected.
- **`#ROLE`.** Collides with Markdown heading syntax and anchor fragments (`[text](#anchor)`). A reader can mistake it for a heading. Rejected.
- **`_ROLE`.** No tool or markup collision: not a pi shortcut, not Markdown emphasis (emphasis needs a wrapping pair). It reads as a machine key and greps cleanly. **Adopted.**

### Default-model resolution

- **Hardcode the default.** Goes stale, and the single-source rule forbids it. Rejected.
- **Instruct reading it with `jq`.** `~/.pi/agent/settings.json` carries `defaultProvider` and `defaultModel`. `jq` reads JSON reliably, where `grep` does not. The agent resolves the effective default itself. **Adopted.**

## Decision

The project-level `AGENTS.md` carries a tagged role-recommendation table, and prompts and skills reference the tag instead of a hardcoded model.

| Tag | Recommendation, in order |
|---|---|
| `_IMPLEMENTER` | space-bunny-free at high; deepseek-v4-flash at medium |
| `_REVIEWER` | space-bunny-free at xhigh; deepseek-v4-flash at medium |
| `_ADVISOR` | glm-5.3-flash at high for documentation and language reviews; deepseek-v4-flash at xhigh for code reviews |

Each recommendation carries its model and thinking level. When one model is required but several are suggested, take the first in listed order; a routing clause on a row (the `_ADVISOR` review-shape split) takes precedence over first-in-listed-order.

The fallback chain, reviewed by a fresh advisor subagent (glm-5.3-flash, high), is defined so a missing tag is never a dangling reference: a prompt names a role tag; if the project-level `AGENTS.md` has no such tag, the agent resolves the startup default `defaultProvider` / `defaultModel` from `~/.pi/agent/settings.json` with `jq`, and a project-level `.pi/settings.json` override takes precedence if present. When a recommendation names no thinking level, use `defaultThinkingLevel` from the same settings file. A prompt template writes `_ROLE` to stand for the assigned tag, for example `_REVIEWER`.

The provider-layer `AGENTS.md` drops the hardcoded pair and example and instructs resolving the startup default with `jq`. Its warning-rule sentence is corrected: a `No models match pattern` warning means pi did not keep the requested model and fell back to the startup default, which the agent verifies from the session header model line; the warning is not benign noise.

The project-level `AGENTS.md` gains the rule that editing pi's own `AGENTS.md` always updates both the repo source and the installed copy.

## Consequences

- Ten files change: the two `AGENTS.md` layers, six prompts/skills that hardcode models, `parallel-auto.md` (pointer only), and `docs/concepts/sandbox_host_interface.md`.
- A future prompt that dispatches an agent reads its model by role tag from the project-level `AGENTS.md`, not from its own text.
- Changing the effective model for a role edits one table instead of every prompt.
- The provider defaults (`settings.json`) remain the truth the agent reads, never restated in prose.
