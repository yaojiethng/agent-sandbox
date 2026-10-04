---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - Implementation: the `model-refresh` announcement fires on the catalog transition

## Objective

Make the `model-refresh` refresh announce the catalog transition: one `ctx.ui.notify` carrying the entry-state delta when the served catalog changes, the persistent footer removed, and a saved default the scope discarded announced at `session_start`.

## Scope

Continues the `model-refresh improvements` parent row from the plan handover [`20261004-02-plan-model_refresh_startup.md`](20261004-02-plan-model_refresh_startup.md), unit B: *the announcement fires on the catalog transition*. Unit A ([`20261004-03`](20261004-03-impl-model_refresh_machine_enumeration.md)) landed the enumeration this unit reads.

| In | Out |
|---|---|
| The `CatalogReport` becomes the catalog delta: `changed`, `added`, `removed`, `revised`, `failures`; the source counts go, and the `report.stored` mismatch goes with them by construction | Unit A's enumeration and invariant classification, which landed |
| The startup refresh diffs against pi's baked catalog; a later refresh diffs against the last served union the extension returned | Unit C's own catalog cache, which is its own roadmap row |
| One `ctx.ui.notify` per change carrying `updated catalog: +n / -n, m revised`, plus one per failing source; nothing on no change | The `pi upstream` disclosure decision, which stays on hold |
| The saved-default announcement at `session_start`, gated on a configured scope and an applicable default | Changing pi's picker or its private refresh status line |
| The output transitions `X8`-`X10` and the new `X14` gain invariant cases and mutation rows | The `enabledModels` order rule text, which landed in unit A |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `CatalogReport` is the catalog delta (`changed`, `added`, `removed`, `revised`, `failures`); no source count remains | `grep -A12 "interface CatalogReport" types.ts` | Agent [x] |
| 2 | A diff primitive counts id adds, id removes and same-id field revisions, keyed on `type + id` | `node --test catalog.test.ts` (new cases) | Agent [x] |
| 3 | The startup refresh diffs against the offline union; a later refresh against the last served union | `node --test gather.test.ts load.test.ts` | Agent [x] |
| 4 | One `ctx.ui.notify` calls `updated catalog: +n / -n, m revised` on a change | `node --test report.test.ts` | Agent [x] |
| 5 | Nothing is emitted when the change set is empty and no source failed | `node --test report.test.ts` | Agent [x] |
| 6 | The footer and working-message surfaces are gone | `grep -rn "setStatus\|setWorkingMessage\|WORKING_MESSAGE" report.ts index.ts` is empty | Agent [x] |
| 7 | The saved-default announcement fires only with a non-empty `ctx.scopedModels`, an applicable default (`modelRegistry.find` + `hasConfiguredAuth`), and `ctx.model` differing; it calls no `setModel` | `node --test load.test.ts default-model.test.ts`; `grep -rn setModel index.ts` is empty | Agent [x] |
| 8 | The console stays the sink in print/json/rpc mode and prints the delta when the catalog changed | `node --test load.test.ts` | Agent [x] |
| 9 | `X8`-`X10` and `X14` each gain an invariant case and a `proven` mutation row; the totality check passes | `node --test invariants.test.ts mutation.test.ts`; the gate reports 48 rows, all as expected, only R1 unnamed | Agent [x] |
| 10 | The README describes the built sink, the announcement rule and the applicability guard | read `## Where the output goes`, `## The update and catalog state machine`, `## The default model and the scope order` | Agent [x] |
| 11 | Gates clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | the `CatalogReport` shape |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | the catalog-diff primitive |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts) | the delta computed at build time |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts) | the emitter: the delta line, the failure lines, the removed footer |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts) | the last-served tracking and the saved-default announcement |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the output sink, the announcement rule, the state-machine section |
| [`tests/extensions/pi/model-refresh/report.test.ts`](../../tests/extensions/pi/model-refresh/report.test.ts) | rewritten for the delta emitter |
| [`tests/extensions/pi/model-refresh/gather.test.ts`](../../tests/extensions/pi/model-refresh/gather.test.ts) | the report the delta produces |
| [`tests/extensions/pi/model-refresh/load.test.ts`](../../tests/extensions/pi/model-refresh/load.test.ts) | the `session_start` routing and the saved-default announcement |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the output-transition cases and the new classification entries |
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the output-transition cases |
| [`tests/extensions/pi/model-refresh/mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | re-pointed anchors and the new output-transition rows |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The announcement's before state is the offline union for the first refresh, and the last served union for a later refresh | the event is the served catalog's before/after state. A baked before state would be wrong: the metadata pass enriches a baked entry on every build, so it would report a constant revision on every start and announce a change that did not happen. The offline union already carries the enrichment, so the first report is the live contribution and a later report is the change since the last refresh | this record; the README state-machine section |
| A saved default counts as applicable only when `ctx.modelRegistry.find(defaultProvider, defaultModel)` returns a model and `ctx.modelRegistry.hasConfiguredAuth(model)` is true | this is pi's own step-3 test in `findInitialModel`, so the extension announces a discard only where the resolver would have honoured the default, and stays silent where the default is absent or unauthenticated (Finding 2's two cases) | this record; the README `## The default model and the scope order` |
| The saved-default announcement fires only when `ctx.scopedModels` is non-empty and `ctx.model` is not the saved default | the scope is what discards it: with an empty scope the resolver consults the default, so there is nothing to announce | this record |
| The delta keys on `modelKey`, and a `revised` entry is one present on both sides whose fields differ | the key is the same identity the union uses, and the defect the extension was built to repair is a same-id field revision with no id change | this record |
| The emitter is `notify` only, and a run with no change and no failure emits nothing | the footer is a permanent surface for an event-scoped fact; silence is the correct rendering of a transition that changed nothing | this record; the README state-machine section |
| The output transitions gain their own invariant family `O`, with `X8`-`X10` and the new `X14` each held by one case | unit A left `X8`-`X10` uncased with a reason naming this unit; the invariant-audit rule requires every transition to be held | this record |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `ExtensionContext` carries `scopedModels` and `modelRegistry` (`model-registry.d.ts`: `find(provider, modelId)` and `hasConfiguredAuth(model)`), so the saved default's applicability is observable at `session_start` without re-implementing the resolver | capability | this iteration: the announcement's guard is pi's own step-3 test | Triaged to: this record's Decisions |
| `createReporter`'s `begin`, `end` and `WORKING_MESSAGE` are called only by the suite, never by `index.ts`, and duplicate pi's private `Refreshing model catalogs...` literal; they are dead product code that unit B removes | defect | this iteration | Triaged to: this record's Completed, when the file is edited |
| The mutation rows anchored on `report.ts` and `index.ts` (`report:pre-ui-report-dropped`, `index:attach-never-runs`, `index:baked-catalog-emptied`, the two `C4` rows) point at text this unit rewrites, so their anchors must move with the code | obstacle | this iteration | Triaged to: `mutation/catalog.ts`, re-pointed |
| The metadata pass enriches a baked entry on every build (it adds `thinkingLevelMap` and `compat` when the baked entry lacks them, 11 of pi 1.0.0's 29 `opencode-go` entries), so a before state of raw baked data reports a constant revision on every start and the announcement fires on a no-op. The before state is the offline union instead | design gap | this iteration | Triaged to: `refresh.ts`; this record's Decisions; the README state-machine section |
| `JSON.stringify` is key-order sensitive, and `fillMissing` rebuilds an enriched entry with different key order, so the first diff implementation read a field re-order as a revision. Fixed with a key-sorted serialization, and pinned by a `diffCatalogs` case | defect | this iteration | Triaged to: `catalog.ts` `stableSerialize`; `catalog.test.ts` |
| The extension's own `CHANGELOG.md` records no entry for the `models.json` override fix (handover `20261004-05`), whose `low` level now reaches the wire | record defect | fixed this iteration | Operator direction, 2026-10-04: the `[0.4.0]` entry is added, and this unit's entry moves to `[0.5.0]` so the versions stay chronological |

## Completed

| File | Change |
|---|---|
| [`types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | `CatalogReport` is the delta: `changed`, `added`, `removed`, `revised`, `failures` |
| [`catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | new `diffCatalogs`, with `stableSerialize` so a field re-order is not a revision |
| [`refresh.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts) | `previous` input and the offline-union baseline; the report is built from the diff |
| [`report.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts) | new `deltaLine` and `notices`; `createReporter` renders only notices; the footer and working-message surfaces removed |
| [`default-model.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/default-model.ts) | new: `discardedDefault`, guarded by the resolver's own step-3 test |
| [`index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts) | tracks the last served union; announces the discarded default at `session_start`; the console prints the delta |
| [`default-model.test.ts`](../../tests/extensions/pi/model-refresh/default-model.test.ts) | new: the announcement guard truth table |
| [`report.test.ts`](../../tests/extensions/pi/model-refresh/report.test.ts) | rewritten for the delta emitter |
| [`gather.test.ts`](../../tests/extensions/pi/model-refresh/gather.test.ts) | the report is the catalog transition |
| [`catalog.test.ts`](../../tests/extensions/pi/model-refresh/catalog.test.ts) | the `diffCatalogs` cases |
| [`invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the `O1`-`O4` cases, the `X14` transition, and `X8`-`X10` lose their `noCaseReason` |
| [`invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the `O1`-`O4` cases; `L3` and `L4` follow the new report shape |
| [`load.test.ts`](../../tests/extensions/pi/model-refresh/load.test.ts) | the `session_start` context and the saved-default cases |
| [`mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | the `O1`-`O4` rows; the `C1` anchor re-pointed to `offlineUnion()` |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | registers `default-model.test.ts` |
| [`README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | `## Where the output goes` rewritten; the before-state rule; the default-model guard; the tests table |
| [`CHANGELOG.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/CHANGELOG.md) | the `0.5.0` entry, plus the `0.4.0` entry for the `models.json` override fix at the operator's direction |
