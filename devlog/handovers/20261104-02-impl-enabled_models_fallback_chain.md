---
date: 2026-11-04
milestone: T12 - Pi Dependency and Extension Upkeep
type: Implementation
status: Closed
---

# Handover - the `enabledModels` fallback chain and its behavior test

## Objective

Replace the shipped scope head with the approved fallback chain, remove the inert `failover/*` pattern, and replace the string guard with a behavior test that proves which model pi selects under each auth configuration.

## Scope

The T12 row **The shipped `enabledModels` chain survives a missing provider key**. The operator's symptom is a new project with the bundled settings and no DeepSeek key starting on `claude-haiku-5-5`.

The unit carries the chain in `settings.json`, the retired scope-head assertion, the new RPC behavior test, the two `model-refresh` records that state the selection rule, and the `pi-bump` verify checklist that runs the test. The operator released the scope at `20261104-02`. The change reaches a project only after `make build` or `make start REFRESH=1`; `make refresh` does not rebuild the provider image.

Ruled out of scope: the durable-settings design, filed at M3.2.3; the lifecycle records in `provider_lifecycle.md`, `agent_workflow.md` and `provider_onboarding_guide.md`, and the ADR line on `No models match pattern`, which are a separate documentation unit; the project `.pi/settings.json` override and the preflight invalid-JSON fallback, which are recorded under the durable-settings row; the no-auth placeholder, filed as its own T12 row; the upstream default-model report, held by the T12 `pi upstream` row; removing the `model-failover` extension, because only its pattern leaves the scope; and any change to `model-refresh` behavior.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| `enabledModels` is exactly the seven-entry chain and carries no `failover` pattern | `jq -e` against the literal array | Agent [x] |
| All keys configured selects `deepseek/deepseek-flash` | behavior test, scenario `all-providers` | Agent [x] |
| No DeepSeek key selects `opencode-go/deepseek-v4.1-flash` | behavior test, scenario `no-deepseek` | Agent [x] |
| No OpenCode key selects `deepseek/deepseek-flash` | behavior test, scenario `no-opencode` | Agent [x] |
| OpenRouter only selects `openrouter/~deepseek/deepseek-flash-latest` | behavior test, scenario `openrouter-only` | Agent [x] |
| The test sends no prompt and makes no model call | the helper sends only `get_state`; no `prompt` command exists | Agent [x] |
| The knowledge test carries no explanatory comments | `grep -n '^#'` prints only the shebang and shell directives | Agent [x] |
| The selection docs no longer claim the head decides the start | read the `model-refresh` README and `default-model.ts` diff | Agent [x] |
| The suite and the full lint pass | `bash scripts/run_tests.sh` and `bash scripts/lint.sh` | Agent [x] |
| The roadmap row names the chain and the behavior test, and is marked `[x]` | read the T12 row | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Use the seven-entry ordered chain and remove `failover/*` | The first entry that resolves to an authenticated model wins, so a missing OpenCode key reaches the OpenRouter entry instead of the broad `opencode-go` family. The failover extension is inert unless `MODEL_FAILOVER_ENABLED` is set | `20261104-report-settled-enabled_models_scope_head.md` `## Candidate changes and measured effects` |
| Retire the head-equals-default assertion | It passes when the selected model is wrong and fails by design under the chain. The behavior test asserts the selected model instead of a string relationship | this record; `tests/knowledge/knowledge_pi_model_selection.sh` |
| Put the behavior test in `tests/knowledge/` | pi is the external seam. The test starts a real pi process and reads session state, which the unit harness cannot call | `.agents/skills/testing/references/test-homes.md` |
| Isolate the global settings layer with a temporary cwd and a temporary `PI_CODING_AGENT_DIR` | The test must read the shipped template, not the active file, a project override, or a preflight-rewritten copy | `tests/libs/pi_model_selection.mjs` |
| Send no prompt | The selected model is session state before any request. A prompt would contact `claude-haiku-5-5`, the model the operator asked to avoid | `20261104-report-settled-enabled_models_scope_head.md` `## Method` |
| Keep the saved default selected when it is authenticated and in scope | The CLI already does this in 1.3.0. The chain governs the no-key case | `20261104-report-settled-enabled_models_scope_head.md` `## The mechanisms, in order` |
| Name the image rebuild step | The settings change reaches a project only after `make build` or `make start REFRESH=1`; `make refresh` does not rebuild | this record; `20261104-report-settled-settings_json_fidelity.md` `## Consequences for the chain and the behavior test` |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| The reasoning container has no `make` binary; the suite runs through `scripts/run_tests.sh`, which also runs the liveness check | environment | the acceptance command is the script, not `make test` | this record |
| The `pi-bump` verify checklist said the config-cycle knowledge test carries intentional version fixtures; it carries none, and its scope assertion is now gone | defect (record) | a bump read a stale reason to run a test that no longer covers model selection | corrected in this iteration; the checklist now runs both knowledge tests |
| The delivery commit carries the investigation record and the implementation record, two work-unit records in one delivery | deliberate deviation | the investigation is the evidence for the fix, and the operator released both records in the same unit; the one-iteration split is not applied | this record |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/settings.json` | the seven-entry chain replaces `failover/*` |
| `tests/knowledge/knowledge_pi_config_cycle.sh` | the scope-head assertion and its comments are removed; the harness-roots case remains |
| `tests/knowledge/knowledge_pi_model_selection.sh` | the comment-free behavior test over four auth configurations |
| `tests/libs/pi_model_selection.mjs` | the RPC fixture runner, promoted from the session probe |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` | the CLI preference, the chain and the behavior test replace the scope-head rule |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/default-model.ts` | the comment states the CLI preference and the discard the guard reports |
| `.agents/skills/pi-bump/SKILL.md` | the verify checklist runs the config test and the selection test, and drops the stale version-fixtures clause |
| `devlog/roadmap.md` | the chain row is rewritten and the no-auth placeholder is filed as its own row |
| `devlog/discussions/20261104-report-settled-enabled_models_scope_head.md` | renamed from `draft` to `settled`; the outcome names the chain, the test and the deferred items |
| `devlog/discussions/20261104-report-settled-settings_json_fidelity.md` | renamed from `draft` to `settled`; the durable-settings questions are scoped to the M3.2.3 row |
| `devlog/handovers/20261104-01-discussion-enabled_models_scope_head.md` | closed; the decided questions moved to Decisions and the no-auth and upstream items routed |
| `devlog/handovers/20261104-02-impl-enabled_models_fallback_chain.md` | this work-unit record |
