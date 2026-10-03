---
date: 2026-10-03
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - Implementation: `model-refresh` becomes a source-driven fallback

## Objective

Decide the fate of the `model-refresh` extension: delete it, narrow it, or keep it. The T12 row `U3 of the pi bump` owns the question, and the 1.0.0 walk moved A8, A9 and A10, which changes the evidence the question rests on.

## Scope

| In | Out |
|---|---|
| The design analysis and its record: a discussion doc, an ADR if the decision is an implementation decision, and the roadmap update | The removal or narrowing itself, if the decision is to change the extension |
| The question of where the surviving knowledge lives, if the extension goes | The default-model report and the upstream report (their own T12 rows) |
| | The `task-queue` bump-semantics record (its own T12 row) |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | The extension folder is self-contained: its README carries the decision and its `sources.json` carries the declaration | read `extensions/model-refresh/README.md` and `sources.json` | `Agent [x]` |
| 2 | The README states the layered-source model, the first-wins per-field union, the reverse override fold, and the diagnosis of the thinking-level defect | read the README's `## Thinking levels` and its source-model section | `Agent [x]` |
| 3 | The per-provider sources are declared in `sources.json`, not in code and not in pi's `settings.json` | `grep` finds no hardcoded provider id, base URL or transport table; the `N2` case holds the settings check | `Agent [x]` |
| 4 | One union primitive, first-wins per field; the override sources fold in reverse | `unionFirstWins`, `overlayPreservingOrder`, and the `U1` to `U3` cases | `Agent [x]` |
| 5 | With the live list unreachable, the served catalog equals pi's own | the `G2 agrees with pi` case | `Agent [x]` |
| 6 | An id-only override source wins existence and leaves the base entry's fields | the `U1` and `U2` cases | `Agent [x]` |
| 7 | An id the primary carries and no override source lists stays served | the `U3` and `L1` cases | `Agent [x]` |
| 8 | No baked entry's metadata is rewritten from models.dev | the `U4 metadata silence` case | `Agent [x]` |
| 9 | The README's live-fetch section matches the measured path | read `## Where this defect lives, and how to re-validate it` | `Agent [x]` |
| 10 | The extension's suite passes, lint is clean, the repo suite is green | extension suite 174 of 174, including the 30-case invariant report and the 29-row mutation gate; `bash scripts/lint.sh`; `bash scripts/run_tests.sh` 1048 of 1048 | `Agent [x]` |
| 11 | The T12 rows the decision closes or retargets are updated | read `devlog/roadmap.md` T12 | `Agent [x]` |

## Hot files

`src/reasoning/providers/pi/config/agent/extensions/model-refresh/` (README, `index.ts`, `catalog.ts`, `refresh.ts`, `thinking.ts`, `report.ts`, `types.ts`), `tests/extensions/pi/model-refresh/`, `src/reasoning/providers/pi/config/agent/models.json`, `devlog/roadmap.md`.

## Decisions

1. **The decision row is a design, not an implementation.** The U3 row says "decide the fate", so its outcome is the decision and its record. A removal is a separable unit with its own outcome.
2. **The union is a no-op only on the offline path.** `pi --list-models` and `pi -ne --list-models` return byte-identical lists because that command runs no network refresh. On a TUI start, `interactive-mode.js` fires `refreshModelCatalogs` after mount, and `ModelRuntime.refresh` defaults `allowNetwork` to `modelNetworkEnabled`, so the extension's live fetch runs and its union replaces the catalog.
3. **The decision is narrow, and the role is a fallback** (operator, 2026-10-03). pi's baked catalog and its pi.dev overlay are pi's primary sources. The extension adds secondary sources: the provider's own `/models` endpoint, which is the better authority for that provider's catalog, and models.dev, which is metadata only.
4. **Precedence: the provider endpoint overrides, models.dev does not** (operator, 2026-10-03).
5. **The extension is genericized, and the per-provider source declaration is config, not code** (operator, 2026-10-03). The `opencode-go` constants become a declaration row, so a second provider is data rather than a code change.
6. **A `settings.json` key can carry the declaration.** Measured: pi's settings loader `JSON.parse`s the file, applies `migrateSettings`, and stores it back, so an unknown key round-trips; but `Settings` is a closed typed interface, so the key is not a typed extension point.
7. **One union primitive, first-wins** (operator, 2026-10-03). The non-override sources fold in list order, earlier winning; the override sources fold in reverse order, so the first-listed override source is the strongest. There is no second behaviour, and the pass direction is the only difference.
8. **The extension's records are self-contained** (operator, 2026-10-03). The decision lives in the extension's own README, not in `docs/adr/` or `devlog/discussions/`; a version-specific API state is of no use to a future agent on a later pi. The design doc and the ADR drafted earlier were deleted, and the declaration moves to `sources.json` beside the extension so the folder owns every input.
9. **models.dev is metadata only** (operator, 2026-10-03). A source declared `metadata` supplies fields for ids another source lists and adds none of its own. Implemented by restricting its entries to the ids the non-metadata sources supply, wherever those sit in the declared order. Measured: models.dev lists 33 `opencode-go` ids, of which exactly one, `grok-4.5`, is on neither the baked catalog nor the endpoint, so the ruling costs one id.
10. **The transport derives from the metadata, not from a hand list** (operator, 2026-10-03). `provider.npm` decides: `@ai-sdk/openai` over the responses adapter, `@ai-sdk/anthropic` over the messages adapter, anything else over completions. The declaration keeps `transports` for the ids the metadata cannot classify; today that is `minimax-m2.5`. pi's own baked catalog settles the mapping: its responses set is exactly models.dev's `@ai-sdk/openai` set, minus `grok-4.5`, which pi does not bake.
11. **Three provider-specific constants moved into the declaration** (operator, 2026-10-03): the effort string that means off (`none`), the ladder to offer when the endpoint names none, and the id-prefix compat rule. The compat rule keeps the deepseek block, which is the fix the extension was first written for: that gateway needs its reasoning content on assistant turns and a `thinking` object rather than a bare `reasoning_effort`. `levelMapFor`'s unused `supportsReasoningEffort` parameter is dropped.
12. **`minimax-m2.7` is pinned to pi's baked value** (operator, 2026-10-03). The derivation and pi disagree and the difference could not be tested, so the declaration names the id in `transports` as `openai-completions`, with the README's point-in-time note giving the comparison that removes the pin.
13. **The thinking-level defect is per model, with a per-provider requirement.** pi's baked catalog carries `compat` and `thinkingLevelMap` per entry and duplicates the shape under both providers, so there is no provider-level block to fix; the gateway is the provider's and it is what decides whether the disable signal is `reasoning_effort: "none"` or the `deepseek` toggle. The diagnosis and its validation procedure are recorded in the extension's README.

## Decisions pending

None. The operator ruled on 2026-10-03: narrow, with the extension's role the addition of secondary sources; the provider endpoint overrides and models.dev does not; one union primitive, first-wins per field; the declaration is config.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| pi refreshes the pi.dev catalog automatically: `interactive-mode.js` fires `refreshModelCatalogs` after mount, and `ModelRuntime.refresh` defaults `allowNetwork` to `modelNetworkEnabled`, so the same pass calls the extension's `refreshModels` with `allowNetwork: true` | measurement | the README's `## Why the live fetch is written but rarely reached` says the opposite; A3 was falsified on 2026-10-02 for the same reason | this iteration (README refresh) |
| The store overlay is gated out at 1.0.0: the `opencode-go` store entry's `lastModified` is 2026-10-01T12:51Z against a baked `generatedAt` of 2026-10-01T18:57Z | measurement | pi serves its baked catalog and the store adds nothing | this iteration |
| The live endpoint advertises 36 ids against 29 baked; 7 are live-only (`deepseek-flash`, `glm-5.1`, `kimi-k2.6`, `minimax-m2.5`, `omen-alpha`, `qwen3.6-plus`, `qwen3.7-max`) | measurement | the extension is the only path to those ids at 1.0.0, so it is not a no-op in a TUI session | this iteration |
| The thinking-level corrections for baked models live in `models.json` `modelOverrides`, not in the extension | measurement | deleting the extension does not lose them; the README's `## Local overrides` states it | this iteration |
| The `models-dev` source contributes its ids, not only its metadata, so a models.dev entry the provider does not serve would enter the catalog | risk | resolved: the source is declared `metadata`, so it adds no id | this iteration |
| `grok-4.5` sits in the declared `openai-responses` transport list, but no source lists that id now, so the entry is dead; the endpoint lists `grok-4.6`, which the transport list omits and which therefore falls to `openai-completions` | record | resolved by the derivation: the responses set is derived from `provider.npm`, and the stale ids are gone from the declaration | this iteration |
| pi bakes `minimax-m2.7` over `openai-completions`, while models.dev names `@ai-sdk/anthropic` for it, so the endpoint override derives the messages adapter where pi curated completions | record | resolved for now: the declaration pins the id to pi's baked value, untested | this iteration |
| The workspace's Go monthly quota is exhausted: every Go model answers `429 GoUsageLimitError` on both surfaces before the body is read, while the free tier answers | obstacle | no Go model can be completed, and `knowledge_opencode_gateway_matrix.sh` will fail its Go rows until the limit resets | pending |
| The extension suite is not yet updated for the new API and fails to load | obstacle | the suite must be rewritten before the iteration can close | this iteration |

## Completed

Roadmap maintenance check: not required. The roadmap matches handover `20261003-15`.

Orient: latest handover `20261003-15` (Housekeeping, Closed) and the roadmap read. The directive is the T12 row `U3 of the pi bump`.

Measured: `pi --list-models` with the extension and `pi -ne --list-models` without it return identical lists, because that command runs no network refresh. Read pi 1.0.0's catalog path: `interactive-mode.js` fires `refreshModelCatalogs` after mount, `ModelRuntime.refresh` defaults `allowNetwork` to `modelNetworkEnabled`, and the composed provider calls the extension's `refreshModels` with `allowNetwork: true`. Read the extension's modules: `buildUnion` returns pi's baked catalog unchanged when `modelsDev` is absent and the store is gated out.

The narrowing landed. The extension is declaration-driven: `sources.json` names the provider, its endpoint, its base urls, its explicit transport entries, its thinking names, its compat blocks and the ordered source list; `buildUnion` is one primitive, first-wins per field, with the override sources folded in reverse and a metadata source run as a fill pass after the id order is settled. `pi-dev` is declared an override source, because with it as a plain source first-wins let the baked entry beat the fresher store overlay and the extension stopped reproducing pi. The transport derives from the metadata's `provider.npm`, with `minimax-m2.7` pinned to pi's baked adapter because the workspace's Go quota blocks the comparison that would settle it.

The suite was rewritten: seven behavioural suites, a 30-case invariant report, and a 29-row mutation gate whose anchors follow the new code. Extension suite 174 of 174; repo suite 1048 of 1048; lint clean across 6 gates.

Separately, the test runner's default deadline moved from 5s to 10s, the timeout summary now names the file's own deadline rather than the default, and `test_runner_contract.sh` states a 30s budget: it already declared 10s and exceeded it under load, which the default-shaped summary had hidden.
