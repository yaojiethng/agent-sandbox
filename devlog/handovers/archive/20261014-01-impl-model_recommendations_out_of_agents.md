---
date: 2026-10-14
milestone: M3.3.1 - The prompt, skill and AGENTS.md interaction contract
type: Implementation
status: Closed
---

# Handover - the model recommendations leave the project AGENTS.md

## Objective

Move the role-to-model recommendations out of the project `AGENTS.md` into an operator-owned file at `$AGENT_HOME/model-recommendations.md`, initialized on demand by a pi skill, so the recommendations stop shipping in version control and stop going stale inside `AGENTS.md`.

## Scope

One operator-directed change, mapped to no roadmap task. It continues the single-source principle in [`single_source_model_recommendations.md`](../../../docs/adr/single_source_model_recommendations.md) and replaces its 2026-09-29 home decision: the recommendations no longer live in the project `AGENTS.md`, they live in the operator file, and the project layer explains how to initialize them. The design record is [`20261014-design-settled-model_recommendations_home.md`](../../discussions/20261014-design-settled-model_recommendations_home.md).

The change covers: the new operator file and its blank skeleton; the migration of the current `AGENTS.md` table plus the new `_ORCHESTRATOR` row into the live operator file; the host setup that creates the skeleton; the pi compose overlay that mounts it; `.gitignore`; the project `AGENTS.md` section, whose role vocabulary gains `_ORCHESTRATOR`; the provider-layer pi `AGENTS.md` pointer; the new pi initialization skill, which carries no model slug; the ADR entry; the reference documents that describe the transport; and the one bundled harness consumer that hardcodes a model slug, `workflow/coding-agent/skills/eval/scripts/run_case.sh`, which takes its default from the `_ORCHESTRATOR` role. No capability-layer file is in scope: the scan of the capability bundle found no model reference.

Two items stay out of scope. `src/reasoning/providers/pi/config/agent/settings.json` keeps its `defaultModel`, because it is the bootstrap default pi needs to start, not a role recommendation. The technical model ids in `models.json` and the model-refresh extension documentation stay, because they are transport configuration and measured model behaviour, not dispatch recommendations; they are recorded under Findings rather than repaired.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The project `AGENTS.md` names no model slug and no provider/model token | `grep -nE 'opencode-go/\|space-bunny\|deepseek-v4\|glm-5' AGENTS.md` returns nothing | Agent [x] (empty) |
| The project `AGENTS.md` names `$AGENT_HOME/model-recommendations.md` and the initialize-before-dispatch clause | `grep -n 'model-recommendations' AGENTS.md` returns the section and the clause | Agent [x] (3 lines) |
| The provider-layer pi `AGENTS.md` names `$AGENT_HOME/model-recommendations.md` and reads the recommendation there | `grep -n 'model-recommendations' src/reasoning/providers/pi/config/agent/AGENTS.md` returns the pointer | Agent [x] (4 lines) |
| The host setup creates `$SANDBOX_DIR/.pi/model-recommendations.md` as a slug-free skeleton only when absent | write the skeleton to a temp sandbox, run the setup hook twice, confirm the file exists and the second run leaves it unchanged | Agent [x] (`test_setup_creates_skeleton_when_absent`, `test_setup_leaves_existing_file`) |
| The host recommendations file is outside version control | `git check-ignore -v .pi/model-recommendations.md` names the `.gitignore` rule | Agent [x] (rc 0) |
| The pi compose overlay mounts the host file at `$AGENT_HOME/model-recommendations.md` | `grep -n 'model-recommendations' src/reasoning/providers/pi/docker-compose.pi.yml` returns the source and target | Agent [x] (both lines) |
| The initialization skill exists under the pi config skills and carries no model slug | `test -f src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md`; `grep -nE 'opencode-go/\|step-5\|deepseek\|glm-5\|space-bunny' <skill>` returns nothing | Agent [x] (`test_skeleton_and_skill_carry_no_slug`) |
| The migration carries the current table into the live operator file, with `_ORCHESTRATOR` added and no row dropped | the live file holds `_IMPLEMENTER`, `_REVIEWER`, `_ADVISOR` and `_ORCHESTRATOR`, and each pre-existing value is unchanged | Agent [x] (4 role lines, values verbatim from the removed table) |
| The eval harness resolves its default model from the `_ORCHESTRATOR` role, not a literal slug | `grep -n 'step-5-preview-free' workflow/coding-agent/skills/eval/scripts/run_case.sh` returns nothing, and the file names `_ORCHESTRATOR` | Agent [x] (`test_run_case_uses_the_orchestrator_role`) |
| The ADR carries the new home decision and demotes the 2026-09-29 entry | head of `docs/adr/single_source_model_recommendations.md` shows the new current entry and the demotion line | Agent [x] (new `Current:` 2026-10-14; supersede line) |
| The architecture documents describe the operator-file contract | `provider_lifecycle.md`, `execution_model.md` and `agent_workflow.md` name the file and its mount | Agent [x] (all three) |
| A regression test covers the skeleton creation and the gitignore rule | the new test passes under `bash scripts/run_tests.sh` | Agent [x] (8 passed, `test_pi_model_recommendations.sh`) |

## Hot files

| File | Why in scope |
|---|---|
| [`AGENTS.md`](../../../AGENTS.md) | carries the role table this iteration removes |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the provider-layer pointer to the recommendations file |
| [`src/reasoning/providers/pi/setup.sh`](../../../src/reasoning/providers/pi/setup.sh) | creates the host skeleton before the mount |
| [`src/reasoning/providers/pi/docker-compose.pi.yml`](../../../src/reasoning/providers/pi/docker-compose.pi.yml) | mounts the operator file into `$AGENT_HOME` |
| `.gitignore` | keeps `.pi/` out of the delivery commit |
| [`src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md) | the initialization skill |
| [`docs/adr/single_source_model_recommendations.md`](../../../docs/adr/single_source_model_recommendations.md) | the standing principle this iteration amends |
| [`workflow/coding-agent/skills/eval/scripts/run_case.sh`](../../../workflow/coding-agent/skills/eval/scripts/run_case.sh) | the bundled harness consumer with a hardcoded model slug |
| [`devlog/discussions/20261014-design-settled-model_recommendations_home.md`](../../discussions/20261014-design-settled-model_recommendations_home.md) | the settled design record |
| [`docs/reference/provider_lifecycle.md`](../../../docs/reference/provider_lifecycle.md), [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md), [`docs/reference/agent_workflow.md`](../../../docs/reference/agent_workflow.md) | describe the config transport and the agent context model |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The recommendations live at `$AGENT_HOME/model-recommendations.md` | one provider-scoped contract, no provider path in the project layer, outside pi's own `agent/` config root so pi never rewrites it | ADR and design record |
| The file is operator-owned and never committed | the model choices change faster than the project layer, and a committed table goes stale in the tree | ADR and design record |
| `settings.json` keeps its `defaultModel` | it is the bootstrap default pi needs to start, not a role recommendation | ADR and design record |
| A blank slug-free skeleton ships instead of a populated default | committing model slugs recreates staleness; a slug-free file is decidable as uninitialized | design record |
| The initialization skill is pi-specific and lives under the pi provider config | only pi ships the prompt and skill payload, so only pi dispatches roles | design record |
| `_ORCHESTRATOR` is a new role, `deepseek/deepseek-flash` at high | the eval harness drives one run and needs a role of its own, distinct from the implementer, reviewer and advisor | root `AGENTS.md` and the operator file |
| The skill carries no model slug; an unset role resolves to `settings.json`'s default model | settings.json is the bootstrap default the existing resolution order already reaches, so a committed skill default is redundant and reintroduces staleness | design record |
| The migration preserves the `AGENTS.md` table in the operator file rather than dropping it | the operator's live choices must survive the move; the role vocabulary and the table shape are unchanged, with `_ORCHESTRATOR` added | design record |
| `run_case.sh` takes its default from the `_ORCHESTRATOR` role in the recommendations file | the eval run should nominate a model deliberately, and the role is the canonical source when it does not | design record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact |
|---|---|---|
| The capability bundle (`src/libs/`, `docs/reference/`) and the shared intersection with the reasoning bundle name no specific model. Triaged to: Completed (reference; no action). | reference | current iteration |
| `workflow/coding-agent/skills/eval/scripts/run_case.sh` defaults `MODEL` to `step-5-preview-free`, a role-model slug in bundled harness code. Triaged to: Completed (reads `_ORCHESTRATOR` now). | contradiction | current iteration |
| `models.json`, the model-refresh extension documents and `settings.json` name specific models for transport and measured behaviour, not dispatch. Triaged to: Out of scope -- transport and measured behaviour, not role recommendations (Scope). | contradiction | next iteration |
| `src/reasoning/providers/pi/config/agent/AGENTS.md` already refuses to recommend models but routes the read to the project `AGENTS.md`, the home this iteration moves. Triaged to: Completed (reads the file now). | contradiction | current iteration |
| The skill default table is a committed model value, in tension with the goal of no committed recommendation. Resolved: the skill carries no model slug; `settings.json` is the fallback and the operator file is the runtime source. Triaged to: Completed (no committed default). | contradiction | current iteration |
| `tests/test_model_refresh.sh` node suite fails at HEAD, before this change: invariant M8 expects `anthropic-messages` and gets `openai-completions`. Reproduced in a clean worktree at HEAD, so it is pre-existing and outside the surface this iteration changed. Triaged to: Out of scope -- reproduced at HEAD; new work if pursued. | obstacle | current iteration |
| The migrated operator file is untracked (`.pi/` is gitignored), so it does not appear in the delivery diff; the mechanism ships, the values stay on the operator's host. Triaged to: Completed (by design). | scope change | current iteration |

## Completed

| File | Change |
|---|---|
| [`AGENTS.md`](../../../AGENTS.md) | the role table is removed; the section names `$AGENT_HOME/model-recommendations.md`, the four roles, the resolution order, and the initialize-before-dispatch clause |
| [`src/reasoning/providers/pi/config/agent/AGENTS.md`](../../../src/reasoning/providers/pi/config/agent/AGENTS.md) | the review-subagent read points at the recommendations file and names the initialization skill |
| [`src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md`](../../../src/reasoning/providers/pi/config/agent/skills/setup-model-recommendations/SKILL.md) | new skill: detect models, confirm per role, write the file in place |
| [`src/reasoning/providers/pi/model-recommendations.skeleton.md`](../../../src/reasoning/providers/pi/model-recommendations.skeleton.md) | new slug-free skeleton, the one home for the file shape |
| [`src/reasoning/providers/pi/setup.sh`](../../../src/reasoning/providers/pi/setup.sh) | creates the skeleton when absent, inside a function so a failure aborts before compose |
| [`src/reasoning/providers/pi/onboard.sh`](../../../src/reasoning/providers/pi/onboard.sh) | creates the skeleton when absent on onboard |
| [`src/reasoning/providers/pi/docker-compose.pi.yml`](../../../src/reasoning/providers/pi/docker-compose.pi.yml) | bind-mounts the host file to `$AGENT_HOME/model-recommendations.md` |
| [`.gitignore`](../../../.gitignore) | ignores `.pi/` |
| [`.markdownlint-cli2.mjs`](../../../.markdownlint-cli2.mjs) | excludes `.pi/` from Markdown lint, as operator state |
| [`workflow/coding-agent/skills/eval/scripts/run_case.sh`](../../../workflow/coding-agent/skills/eval/scripts/run_case.sh) | resolves model and thinking from `_ORCHESTRATOR`, falls back to `settings.json`, refuses when neither is set |
| [`workflow/coding-agent/skills/eval/SKILL.md`](../../../workflow/coding-agent/skills/eval/SKILL.md) | names the `_ORCHESTRATOR` role and the recommendations file |
| [`workflow/coding-agent/prompts/document.md`](../../../workflow/coding-agent/prompts/document.md), [`src/reasoning/agent/prompts/advisor.md`](../../../src/reasoning/agent/prompts/advisor.md), [`src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md`](../../../src/reasoning/agent/skills/thermo-nuclear-code-quality-review/SKILL.md) | role-tag reads retarget to the recommendations file |
| [`workflow/coding-agent/drafts/review-loop-run.md`](../../workflow/coding-agent/drafts/review-loop-run.md), [`parallel-work.md`](../../workflow/coding-agent/drafts/parallel-work.md), [`maintenance.md`](../../workflow/coding-agent/drafts/maintenance.md), [`review-pass-run.md`](../../workflow/coding-agent/drafts/review-pass-run.md), [`adversarial-review-run.md`](../../workflow/coding-agent/drafts/adversarial-review-run.md), [`sequential-work.md`](../../workflow/coding-agent/drafts/sequential-work.md) | role-tag reads retarget to the recommendations file |
| [`docs/adr/single_source_model_recommendations.md`](../../../docs/adr/single_source_model_recommendations.md) | new current entry (operator file) and the 2026-09-29 entry demoted; R8 and R9 added |
| [`docs/reference/provider_lifecycle.md`](../../../docs/reference/provider_lifecycle.md) | the transport split and the single-file-mount exception; onboard seeds the skeleton; a fragility row for an uninitialized file |
| [`docs/reference/execution_model.md`](../../../docs/reference/execution_model.md) | the host tree and the survival table name the mounted file |
| [`docs/reference/agent_workflow.md`](../../../docs/reference/agent_workflow.md) | the agent context model gains a model-recommendations subsection |
| [`tests/test_pi_model_recommendations.sh`](../../../tests/test_pi_model_recommendations.sh) | new regression test: skeleton, idempotence, gitignore, mount, layer pointers, skill, run_case |
| [`tests/test_eval_harness.sh`](../../../tests/test_eval_harness.sh) | the stub run pins `EVAL_MODEL` and an isolated config so the eval test is hermetic |
| [`devlog/discussions/20261014-design-settled-model_recommendations_home.md`](../../discussions/20261014-design-settled-model_recommendations_home.md) | the settled design record |
