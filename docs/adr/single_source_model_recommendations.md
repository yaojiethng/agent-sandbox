# Single-Source Model Recommendations

**Current:** 2026-09-29
**Status:** active

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One home | The role-to-model mapping lives in one place, not restated across prompts |
| R2 | Project-scoped | Recommendations are a project concern; the global pi file does not dictate to every project |
| R3 | Resolvable by agent | Any agent or subagent for this project can read the recommendation for its role at dispatch time |
| R4 | Ordered | When one model is required but several are suggested, the first in listed order wins; a routing clause on a row takes precedence |
| R5 | Default stays truth | Prompts do not restate the effective default; the agent reads it from `settings.json` |
| R6 | Level travels | A recommendation carries its thinking level, not model alone |

## 2026-09-29 -- Role tags in the project-level AGENTS.md

**Decision:** The project-level `AGENTS.md` carries a tagged role-to-model table that includes each model's thinking level. Prompts, skills, and the provider-layer `AGENTS.md` read a recommendation by role tag (`_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`) instead of hardcoding a provider/model/thinking level. The startup default is resolved from `~/.pi/agent/settings.json` with `jq` (`.defaultProvider`, `.defaultModel`, `defaultThinkingLevel`), never restated; a project-level `.pi/settings.json` override takes precedence if present. The provider layer states this resolution and warns that a `No models match pattern` message means pi fell back to that startup default, so the agent must verify the effective model from the session header.

**Rationale:** Changing the effective model for cost or availability edits one table instead of every prompt. The provider layer loads for every project and must not dictate models; the project layer is the single writable home. A warning about a model id that did not resolve is not benign noise: the run uses the fallback default, which may not be the intended model.

**Rejected alternatives:**

- `@ROLE` tags: pi reserves `@` for file links; ambiguous in prose (intent).
- `#ROLE` tags: collides with Markdown heading and anchor-fragment syntax (intent).
- Provider-layer single source: a global rule that forces a model choice on every project (intent).
- Hardcode the default in prose: goes stale and duplicates `settings.json` (intent).

**Edge cases / drivers:** The `_ADVISOR` recommendation is conditional on review shape (documentation and language reviews use `glm-5.3-flash` at high, code reviews `deepseek-v4-flash` at xhigh), not an ordered fallback; the table records the split, and a routing clause takes precedence over first-in-listed-order. Editing pi's own `AGENTS.md` must update both the repo source and the installed copy, or the running agent context and the shipped config diverge.
