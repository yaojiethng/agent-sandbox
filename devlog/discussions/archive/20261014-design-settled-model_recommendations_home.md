# The model recommendations home

**Status:** settled

## Context

The role-to-model recommendations for dispatch live in the project `AGENTS.md` table, a committed file that ships inside the project tree. The models change faster than the rest of the agent context: an update edits the project layer, enters a delivery commit, and leaves a tree that describes a model the operator no longer uses. The investigation for this iteration measured the reach of specific model names in the container bundles. The capability bundle (`src/libs/`, `docs/reference/`) names none. The reasoning bundle names models in three classes: the bootstrap default in `settings.json`, transport and measured behaviour in `models.json` and the model-refresh extension documents, and a hardcoded default slug in the eval harness. Only the last is a recommendation leak, and the project `AGENTS.md` table is the committed recommendation that goes stale.

The `/setup-pstack` skill offered the model: it detects the models a session can dispatch, writes an operator-owned rule file outside the repository, and leaves the skill defaults as the fallback. The question was whether this harness can follow that process without breaking the project-scoping and resolvability requirements the existing ADR fixes.

## Options Considered

**Keep the table in the project `AGENTS.md`.** Rejected. It is committed, project content, and it goes stale in the tree. It also puts a model choice in a record that the operator edits for unrelated reasons.

**A committed repository file beside the tree.** Rejected. It moves the staleness, not the ownership. A file in the tree is still delivered as a commit.

**A user-level file outside the project, the pstack shape.** Rejected for the default. A global file would apply one project's choices to every project and desync from the sandbox directory the operator actually runs. It is also outside the reach of the capability layer when the two containers disagree.

**A custom key in `settings.json`.** Rejected. pi owns and rewrites `settings.json`, the harness already merges one key into it, and the bootstrap default is a different concern from a role recommendation.

**An operator-owned file under the provider config home, with a blank skeleton and an initialization skill.** Chosen.

## Decision

The role-to-model recommendations live at `$AGENT_HOME/model-recommendations.md`, outside version control and outside pi's own `agent/` config root.

- The host file is `<SANDBOX_DIR>/.pi/model-recommendations.md`, gitignored, bind-mounted by the pi compose overlay, and pre-created as a slug-free skeleton by the pi setup hook when absent.
- The project `AGENTS.md` no longer carries the table. It states the role vocabulary -- `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR`, `_ORCHESTRATOR` -- the file path (`$AGENT_HOME/model-recommendations.md`), the resolution order, and the initialize-before-dispatch clause. The provider-layer pi `AGENTS.md` carries the same pointer in its own scope.
- A file whose role lines carry no model is uninitialized. A new pi skill, `setup-model-recommendations`, detects the models the session can dispatch and writes the file. It is the harness's adaptation of `/setup-pstack`, and it carries no model slug. The migration writes the current `AGENTS.md` table into the live operator file, with the new `_ORCHESTRATOR` role (`deepseek/deepseek-flash` at high) added to it.
- `settings.json` keeps its `defaultModel` as the bootstrap default pi needs to start, and is the fallback when a role is unset. No committed default table is needed: the existing resolution order already reaches `settings.json`.
- `workflow/coding-agent/skills/eval/scripts/run_case.sh` stops defaulting to a literal slug. It requires `EVAL_MODEL` or resolves the `_ORCHESTRATOR` model from the recommendations file.

## Consequences

- A model change edits one operator-owned file and reaches the containers on the next start, with no commit and no rebuild.
- The recommendations cannot desync between the two containers: only the reasoning container mounts and reads the file, and the mount is a single host source.
- The repository carries no model recommendation, so a checkout cannot describe a model the operator has moved past.
- The system still starts without the file: the blank skeleton is present, and the bootstrap default in `settings.json` answers a role before initialization.
- An uninitialized file is observable and the initialization is a named skill, so the missing step is actionable rather than silent.
- The operator's live recommendations survive the move: the migration writes the current table plus `_ORCHESTRATOR` into the operator file before the `AGENTS.md` section is removed, so nothing is dropped.
