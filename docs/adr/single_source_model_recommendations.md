# Single-Source Model Recommendations

**Current:** 2026-10-22

**Status:** active

## Requirements

| # | Requirement | Meaning |
|---|---|---|
| R1 | One home | The role-to-model mapping lives in one place, not restated across prompts |
| R2 | Project-scoped | Recommendations are a project concern; the global pi file does not dictate to every project |
| R3 | Resolvable by agent | Any agent or subagent for this project can read the recommendation for its role at dispatch time |
| R4 | Ordered | When one model is required but several are suggested, the first in listed order wins. A set that depends on which kinds of work a role does is two roles, never a clause on one row |
| R5 | No silent default | A role with no line stops the dispatch; nothing resolves it to a startup default, and no prompt restates a model |
| R6 | Level travels | A recommendation carries its thinking level, not model alone |
| R7 | Provider travels | A recommendation names the provider, not the model alone, because two providers can serve the same-named model with different capability |
| R8 | Committed | The live values are committed with the project at `.agents/model-recommendations.md`; a container's copy is derived from them at every start |
| R9 | Operator-authored | The values are the operator's, and the agent is an interface to the file: it writes what the operator states, validates no model, and runs no command that would list one |

## 2026-10-22 -- The values are the operator's, and the agent validates none of them

**Decision:** The role table is operator-authored. The initialisation skill reads the file, asks which role and which value, writes exactly that, and reports what the file now says. It runs no model, reads no catalogue, and asserts nothing about whether an id exists or is served. Whether a model exists is the operator's fact, and a wrong id is corrected in the table.

**Rationale:** The skill's earlier step told the agent to detect the models the session can dispatch, and that detection was wrong twice in one session: a catalogue listing is not a service claim, since pi prints every model it knows and serves only the providers its own settings enable, and a name read from a list was reported as available when the provider refused it. A check that reads a catalogue therefore either duplicates the table's contents, which makes it a tautology, or contradicts them, and neither is a validation. Resolution needs the table and nothing else, so the cheapest correct skill is the one that moves the operator's text into the file.

**Rejected alternatives:**

- Validate each id against the runtime's catalogue: it is text the same operator wrote, so a mismatch is a typo the operator fixes, and the check cannot tell a listed id from a served one (execution).
- Probe each id with a request: it spends the quota the ladder is built to conserve, and it answers for the moment it ran (execution).

## 2026-10-22 -- The values are committed, and the container copy is derived

**Decision:** The role table is committed with the project at `.agents/model-recommendations.md`, so a change to which model a role names is a reviewable edit. The container's copy at `$AGENT_HOME/model-recommendations.md` is written from it at every start when the project has one, and is seeded from the slug-free skeleton only when it does not. A role with no line is refused by its own name. A model named at a call site is a pin, and a pinned run neither reads nor writes the route memory.

**Rationale:** Moving the values out of the repository in the 2026-10-14 entry moved them where nothing reviews them. Measured on 2026-10-22, the container copy named `opencode/deepseek-v4.1-flash-free`, dead since 2026-10-18, two entries past the last correction to the project copy, left `_ADVISOR` and `_ORCHESTRATOR` empty, and promised a startup default for an unset role. Both hooks seeded it once and never touched it again, so every later correction stopped at the repository. A session whose library predates the project copy still reads that path, because the copy is a single-file bind mount the container cannot remove, which makes parity there the condition for an old session to be correct. Naming a model at a call site stays allowed as a pin: a fixed run is reproducible because no route decision is available to it, and a changed pin is an edit to the run, not to the table.

**Rejected alternatives:**

- Keep the values out of the repository: the staleness the 2026-10-14 entry avoided in the tree reappeared in a file nothing reviews, and a dead model survived every review (execution).
- Make the container copy the authority and derive nothing: the same unreviewed file decides what every dispatch runs, and a model change cannot be reviewed (intent).
- Delete the container copy: it is a single-file bind mount, and a library that predates the project copy still reads it, so deleting it changes nothing for the sessions that are wrong (execution).

## 2026-10-20 -- Resolution binds to the role table

**Reason superseded by 2026-10-22:** the table is committed now, so a wrong path is a review defect rather than an operator edit nobody sees, and the startup-default rung is gone. The resolution order, the pinned exception and the rule that a hand read is not a resolution carry forward.

**Decision:** A subagent dispatch names a role, and the assignment comes from the role table in this order: the role's line, then the startup default from `settings.json`, then a stop. A dispatch that fits no role uses the `_IMPLEMENTER` line. A dispatch that needs a property one line cannot express, such as two model families, is a designed exception whose assignment is pinned where its seats are defined, with the reason stated there. The table wins over a preference. Initialisation of the file happens after the dispatch, never before it. The resolver is `dispatch_role_model <role>`; a hand read of the file is not a resolution.

**Rationale:** The 2026-10-14 entry left two openings. An untagged dispatch resolved to the startup default, which read as permission to compose an assignment instead. And a missing file routed to initialise-before-dispatch, which turned one wrong path into a blocked resolution, because its only exit is an operator confirmation an unattended run cannot get. On 2026-10-20 a census dispatch reached three assignments outside the table through that second opening and reported them as the enabled families. Resolution now runs first and stops, so an absent file cannot block the fallback and a composed assignment has no rung to hide in.

**Rejected alternatives:**

- Restrict the capability, so that only the resolver can reach a model: the operator ruled it out and kept the free `pi -p` invocation (2026-10-20).
- Keep the startup-default rung for an untagged dispatch: it is the exemption that licensed the composition.
- Confirm a fallback with the operator at dispatch time: unexecutable in an unattended run, and the block is what produced the improvised fourth rung.
- Give the reviewer seats a role line: one line names one assignment, and the reviewer contract needs two families.

**Edge cases / drivers:** the role table is operator-owned and gitignored, so a wrong path is indistinguishable from a change of model unless `test -f` decides it. The startup default names one assignment, not a family, and cannot satisfy a multi-seat requirement. `dispatch_role_model` reads only the first entry of a repeated line, which is a known seam defect, so a fallback inside a line is a record rather than a route on that path.

## 2026-10-14 -- The recommendations leave the project AGENTS.md

**Decision:** The role-to-model recommendations live in an operator-owned file at [model-recommendations.md](../../.agents/model-recommendations.md), outside version control and outside pi's own `agent/` config root. The host file is `<SANDBOX_DIR>/.pi/model-recommendations.md`, gitignored, mounted by the pi compose overlay and pre-created as a slug-free skeleton when absent. The project `AGENTS.md` carries the role vocabulary (`_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`, `_ORCHESTRATOR`) and an initialize-before-dispatch clause instead of the table. A new pi skill, `setup-model-recommendations`, detects the models the session can dispatch and writes the values. An unset role resolves to the pi startup default in `settings.json`, which stays the bootstrap default pi needs to start. `workflow/coding-agent/skills/eval/scripts/run_case.sh` takes its default from the `_ORCHESTRATOR` role instead of a literal slug.

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
