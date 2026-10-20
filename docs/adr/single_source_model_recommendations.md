# Single-Source Model Recommendations

**Current:** 2026-10-20
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
| R7 | Provider travels | A recommendation names the provider, not the model alone, because two providers can serve the same-named model with different capability |
| R8 | Operator-owned | The live recommendation values are not committed; the repository carries the mechanism and a slug-free skeleton, never a model choice |
| R9 | Initializable | A file with no values is observable as uninitialized, and one skill populates it from the models the session can dispatch |

## 2026-10-20 -- Resolution binds to the role table

**Decision:** A subagent dispatch names a role, and the pair comes from the role table in this order: the role's line, then the startup default from `settings.json`, then a stop. A dispatch that fits no role uses the `_IMPLEMENTER` line. A dispatch that needs a property one line cannot express, such as two model families, is a designed exception whose pair is pinned where its seats are defined, with the reason stated there. The table wins over a preference. Initialisation of the file happens after the dispatch, never before it. The resolver is `dispatch_role_model <role>`; a hand read of the file is not a resolution.

**Rationale:** The 2026-10-14 entry left two openings. An untagged dispatch resolved to the startup default, which read as permission to compose a pair instead. And a missing file routed to initialise-before-dispatch, which turned one wrong path into a blocked resolution, because its only exit is an operator confirmation an unattended run cannot get. On 2026-10-20 a census dispatch reached three pairs outside the table through that second opening and reported them as the enabled families. Resolution now runs first and stops, so an absent file cannot block the fallback and a composed pair has no rung to hide in.

**Rejected alternatives:**

- Restrict the capability, so that only the resolver can reach a model: the operator ruled it out and kept the free `pi -p` invocation (2026-10-20).
- Keep the startup-default rung for an untagged dispatch: it is the exemption that licensed the composition.
- Confirm a fallback with the operator at dispatch time: unexecutable in an unattended run, and the block is what produced the improvised fourth rung.
- Give the reviewer pair a role line: one line names one pair, and the reviewer contract needs two families.

**Edge cases / drivers:** the role table is operator-owned and gitignored, so a wrong path is indistinguishable from a change of model unless `test -f` decides it. The startup default names one pair, not a family, and cannot satisfy a multi-seat requirement. `dispatch_role_model` reads only the first entry of a repeated line, which is a known seam defect, so a fallback inside a line is a record rather than a route on that path.

## 2026-10-14 -- The recommendations leave the project AGENTS.md

**Decision:** The role-to-model recommendations live in an operator-owned file at `$AGENT_HOME/model-recommendations.md`, outside version control and outside pi's own `agent/` config root. The host file is `<SANDBOX_DIR>/.pi/model-recommendations.md`, gitignored, mounted by the pi compose overlay and pre-created as a slug-free skeleton when absent. The project `AGENTS.md` carries the role vocabulary (`_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`, `_ORCHESTRATOR`) and an initialize-before-dispatch clause instead of the table. A new pi skill, `setup-model-recommendations`, detects the models the session can dispatch and writes the values. An unset role resolves to the pi startup default in `settings.json`, which stays the bootstrap default pi needs to start. `workflow/coding-agent/skills/eval/scripts/run_case.sh` takes its default from the `_ORCHESTRATOR` role instead of a literal slug.

**Rationale:** The table is a committed project file, and the models change faster than the rest of the agent context, so an update edits the project layer and leaves a tree that describes a model the operator no longer uses. Moving the values to an operator-owned file edits one place, reaches the container on the next start, and keeps the repository free of a model choice. The file is outside pi's `agent/` config root, so pi never rewrites it. Only the reasoning container mounts it, so the two containers cannot desync. The requirements hold: one home (R1), resolved per sandbox directory rather than globally (R2), readable by any agent in the session (R3), ordered as before (R4), the default left to `settings.json` (R5), the level and provider carried in each token (R6, R7). The skeleton is slug-free, so an uninitialized file is decidable (R8, R9).

**Rejected alternatives:**

- Keep the table in the project `AGENTS.md`: it is committed project content and it goes stale in the tree (intent).
- A committed repository file beside the tree: it moves the staleness, not the ownership (intent).
- A user-level global file, the pstack shape: it applies one project's choices to every project and desyncs from the sandbox directory (intent).
- A custom `settings.json` key: pi owns and rewrites the file, and the bootstrap default is a different concern from a role recommendation (intent).
- A committed default table in the skill: `settings.json` already provides the fallback, so a committed table reintroduces staleness for no gain (intent).

**Edge cases / drivers:** `_ORCHESTRATOR` is the eval harness's role, distinct from the implementer, reviewer and advisor; its recommended value is `deepseek/deepseek-flash` at high. A single-file bind mount breaks when a writer replaces the file with `mv`, and the existing config-file transport rejects one for that reason; this file is the exception, and the skill writes it in place. The migration preserves the operator's live table rather than dropping it: the current rows plus `_ORCHESTRATOR` are written into the operator file before the `AGENTS.md` table is removed.

## 2026-09-29 -- Role tags in the project-level AGENTS.md

**Decision:** The project-level `AGENTS.md` carries a tagged role table whose rows name the provider, the model, and the thinking level (`opencode/space-bunny-free at high`). Prompts, skills, and the provider-layer `AGENTS.md` read a recommendation by role tag (`_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`) instead of hardcoding a provider/model/thinking level. The startup default is resolved from `~/.pi/agent/settings.json` with `jq` (`defaultProvider`, `defaultModel`, `defaultThinkingLevel`), never restated; a project-level `.pi/settings.json` override takes precedence if present. The provider layer states the resolution order (project table, then the pi default with operator confirmation, then the current chat's model with operator confirmation) and warns that a `No models match pattern` message means pi fell back to that startup default, so the agent must verify the effective model from the session header.

**Rationale:** Changing the effective model for cost or availability edits one table instead of every prompt. The provider layer loads for every project and must not dictate models; the project layer is the single writable home. A model identifier without its provider is ambiguous: the opencode and opencode-go lines disagree on capability, so the same model can silently resolve to a variant that fails dispatch; naming the provider closes that. The fallback rungs confirm with the operator so a fallback never guesses silently. A warning about a model id that did not resolve is not benign noise: the run uses the fallback default, which may not be the intended model.

**Rejected alternatives:**

- `@ROLE` tags: pi reserves `@` for file links; ambiguous in prose (intent).
- `#ROLE` tags: collides with Markdown heading and anchor-fragment syntax (intent).
- Provider-layer single source: a global rule that forces a model choice on every project (intent).
- Hardcode the default in prose: goes stale and duplicates `settings.json` (intent).
- A separate provider column: splits each model from its routing clause awkwardly on the conditional `_ADVISOR` row; embedding `provider/model` in each token keeps the recommendation one-cell-meaning and matches the invocation form (intent).

**Edge cases / drivers:** The `_ADVISOR` recommendation is conditional on review shape (documentation and language reviews use `glm-5.3-flash` at high, code reviews `deepseek-v4-flash` at xhigh), not an ordered fallback; the table records the split, and a routing clause takes precedence over first-in-listed-order. Editing pi's own `AGENTS.md` must update both the repo source and the installed copy, or the running agent context and the shipped config diverge.

**Reason superseded by 2026-10-14:** the committed table goes stale in the tree, and the values are operator-owned and change faster than the project layer; the home moves to the operator file, and the token shape and resolution order carry forward.
