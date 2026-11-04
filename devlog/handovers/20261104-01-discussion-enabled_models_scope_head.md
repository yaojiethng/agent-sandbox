---
date: 2026-11-04
milestone: T12 - Pi Dependency and Extension Upkeep
type: Discussion
status: Closed
---

# Handover - the `enabledModels` head and the saved default

## Objective

Establish, by measurement, how pi 1.3.0 chooses the starting model from the shipped `settings.json`, how that file reaches a session and whether its content is faithful to the repository, where the repository states the mechanism wrongly, and whether the knowledge tests can see the failure. No implementation this iteration.

## Scope

The T12 row **The shipped `enabledModels` head no longer names the saved default**. The operator's symptom is a new project with the bundled settings and no DeepSeek key starting on `claude-haiku-5-5`.

The investigation owns five questions. What is selected and when. What each `settings.json` lifecycle step writes. Whether pi writes the file, whether it refreshes, and what causes drift. Which records state the wrong mechanism. Whether the knowledge test covers the failure.

The second line of enquiry is recorded in [`20261104-report-settled-settings_json_fidelity.md`](../discussions/20261104-report-settled-settings_json_fidelity.md). It covers the three copies of the file, pi's write path, the harness seed and preflight, project-level overrides, and the stale-by-default mechanisms. The durable-settings design that report opened is out of scope for this iteration and is filed at [M3.2.3, Durable `settings.json` and the write boundary](../roadmap.md): the target semantics is `.pi` config defined once per repository, seeded at onboard, and managed by the user.

Ruled out of scope for this iteration: changing `settings.json`, changing the knowledge tests, changing the `model-refresh` extension, changing the preflight, and filing the upstream report. The implementation scope and its acceptance criteria were released at `20261104-02`.

## Acceptance criteria

| Criterion | Verification | Result |
|---|---|---|
| The reports answer the investigation questions with measured evidence | Read the selection report's `## The selection matrix`, `## The lifecycle of settings.json`, `## Where the records are wrong`, and `## What the knowledge tests cover`, and the fidelity report's `## The copies`, `## What writes the active file`, `## What causes drift`, and `## Does pi refresh?` | Operator |
| The durable-settings design is filed as a roadmap row and excluded from this iteration | Read the fidelity report's deferred note and the M3.2.3 row `Durable settings.json and the write boundary` | Agent [x] |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Observe selection through `pi --mode rpc` and `get_state`, not by sending a prompt | The selected model is session state before any request. A prompt would contact `claude-haiku-5-5`, the model the operator asked to avoid | [`20261104-report-settled-enabled_models_scope_head.md`](../discussions/20261104-report-settled-enabled_models_scope_head.md) `## Method` |
| Use fixture settings and a fixture auth map, with the `deepseek` entry removed for the no-key scenario | The symptom depends on the key being absent. The fixture changes only that variable and leaves the rest of the catalog and extensions in place | same report, `## Method` |
| Record the investigation as a discussion report plus this handover | The report is the evidence and the recommendation. The handover is the work-unit record. The operator reviews both before an implementation unit is scoped | this table |
| Type the handover `Discussion` | The `work-log` type vocabulary retires `Study`; the `/iter` directive table still maps Investigation to `study`. The record type follows the authority, the directive word does not | this table |
| Treat the settings source as the image template, not the host copy | The entrypoint seeds the config files at every start and the host copy is not mounted | same report, `## The lifecycle of settings.json` |
| Use an ordered chain of literal fallbacks in `enabledModels`, not a single fallback head | The operator approved the chain. The first entry that resolves to an authenticated model wins, so a missing OpenCode key falls to the OpenRouter entry instead of the broad `opencode-go/*` family | same report, `## Candidate changes and measured effects` |
| Stop the chain at the paid OpenRouter entry and fall through to the normal scoped-model wildcards | The operator declined zero-cost literals. A free fallback would add a catalog dependency without resolving the no-auth case | same report, `## Candidate changes and measured effects` |
| Keep the saved default selected when it is authenticated and in scope | The CLI already does this in 1.3.0. The chain only governs the no-key case | same report, `## The mechanisms, in order` |
| Retire the head-names-default assertion for the behavior matrix | The assertion passes when the selected model is still wrong and fails by design under the chain. The behavior test asserts the selected model | implementation handover `20261104-02` |
| Place the behavior test in `tests/knowledge/` | pi is the external seam. The test starts a real pi process and reads session state | implementation handover `20261104-02` |
| Isolate the global settings layer with a temporary cwd and a temporary `PI_CODING_AGENT_DIR` | The test must read the shipped template, not the active file, a project override, or a preflight-rewritten copy | implementation handover `20261104-02` |
| Leave the no-auth placeholder to its own T12 row and the upstream report to the T12 `pi upstream` row | The settings chain cannot make the no-auth case fail closed, and the upstream report is already held by that row | `devlog/roadmap.md` T12 |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| pi 1.3.0's CLI selects the saved default when it is inside the resolved scope, before `findInitialModel` runs. With the DeepSeek key present the shipped settings start on `deepseek/deepseek-flash`, so the row's premise is false for that case | defect (record) | the row explains the wrong mechanism | report `## The mechanisms, in order` and `## Where the records are wrong`; roadmap row rewritten with the implementation unit |
| With the DeepSeek key absent, the resolved scope excludes `deepseek/*`; `failover/*` matches nothing and the first `opencode-go` match is `claude-haiku-5-5`. Reproduced through RPC with no model call | defect (reproduced) | this is the operator's symptom | report `## The selection matrix` |
| A literal `deepseek/deepseek-flash` head does not restore the default when the key is absent. The resolver's fuzzy match selects `openrouter/~deepseek/deepseek-flash-latest` and prints no warning | defect (reproduced) | the row's original fix changes the fallback but does not pin the default | report `## Candidate changes and measured effects` option A |
| An empty scope is not fail-closed. It falls to the provider-default sweep and selected `openrouter/moonshotai/kimi-k2.6` in the probe | defect (record) | removing providers from `enabledModels` does not make the missing key loud | report `## The mechanisms, in order` |
| With no provider authenticated at all, pi selects an `unknown/unknown` placeholder with an empty `baseUrl` and zero context, and the first request fails | defect (reproduced) | the settings chain cannot make the no-auth case fail closed | report `## The mechanisms, in order` |
| `settings.json` reaches a session only from the image template at start. Onboard writes no config file, `make refresh` does not re-provision, and a session edit is lost at the next start | record | a settings fix needs an image rebuild, and the host copy is not the source | report `## The lifecycle of settings.json` |
| The config-cycle knowledge test compares two strings and never starts pi. Its comments carry the false causal claim | defect (record) | the test cannot see the haiku failure | report `## What the knowledge tests cover` |
| Several documents name the wrong lifecycle or selection rule, including the roadmap row, the `model-refresh` README and `default-model.ts`, the ADR line on `No models match pattern`, and two onboarding documents | defect (record) | a reader following them edits the wrong file or expects the wrong fallback | report `## Where the records are wrong`; the roadmap, the `model-refresh` README and `default-model.ts` are corrected in `20261104-02`; the lifecycle records and the ADR line are a separate documentation unit |
| pi writes the active `settings.json` and persists `defaultProvider`, `defaultModel`, `enabledModels`, `defaultThinkingLevel`, and `lastChangelogVersion`, but the entrypoint seed overwrites the file at every start. The file is not a durable preference store | defect (record) | a model set as default is lost at the next session, and the session reverts to the image copy | fidelity report `## What writes the active file` and `## What causes drift` |
| The active file is semantically identical to the repository today, but the preflight re-serializes it and expands `defaultTools`, so it is not byte-identical. The image template is byte-identical and current | record | byte-comparison tests would fail; semantic comparison passes | fidelity report `## Current sync` |
| A project `.pi/settings.json` overrides the global file. Arrays replace, so a project can replace `enabledModels` and `packages`. Measured with a project file that started the session on haiku and one that dropped the harness package roots | defect (record) | the chain and the harness roots can be bypassed by a project file | fidelity report `## What causes drift` |
| The preflight replaces an invalid settings file with `{"packages":[...]}` and continues, dropping every other key. pi itself preserves a corrupt file and runs on defaults | defect (reproduced) | a malformed image template silently falls back to pi defaults | fidelity report `## What writes the active file` |
| A host-mounted settings file is the wrong scope for parallel worktrees. One `SANDBOX_DIR` can host several worktrees, so a file under `.pi/agent/config` is shared by all tracks, outside every branch. A track's change bypasses review and a later write clobbers it. The target semantics is `.pi` config defined once per repository, seeded at onboard, and managed by the user; the durable design waits on that | design constraint (deferred) | the symlink and copy-out shapes are rejected for parallel runs, and the durable-settings TODO is filed at M3.2.3 | fidelity report `## Durable settings: the options`; roadmap row `Durable settings.json and the write boundary` |

## Completed

| File | Change |
|---|---|
| [`devlog/discussions/20261104-report-settled-enabled_models_scope_head.md`](../discussions/20261104-report-settled-enabled_models_scope_head.md) | the selection investigation report, status `settled`, with the matrix, lifecycle, doc audit, test audit, approved chain and outcome |
| [`devlog/discussions/20261104-report-settled-settings_json_fidelity.md`](../discussions/20261104-report-settled-settings_json_fidelity.md) | the settings fidelity report, status `settled`, with the three copies, pi's write path, the seed and preflight, the sync measurement, the drift causes, the deferred durable design and the open questions for that row |
| [`devlog/handovers/20261104-01-discussion-enabled_models_scope_head.md`](20261104-01-discussion-enabled_models_scope_head.md) | this work-unit record |
| [`devlog/roadmap.md`](../roadmap.md) | the durable-settings deferral under M3.2.3, the rewritten chain row, and the no-auth placeholder row |
