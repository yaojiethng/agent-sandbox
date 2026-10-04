---
date: 2026-10-04
milestone: M3 - Manual Dispatch, Autonomous Execution, Manual Review
type: Implementation
status: Closed
---

# Handover - Implementation: the `model-refresh` extension keeps its own catalog cache

## Objective

Give the `model-refresh` extension its own catalog cache, so endpoint-sourced ids are present on an offline start, before pi's network refresh, which no extension can reorder.

## Scope

Continues the `model-refresh improvements` parent row from the plan handover [`20261004-02-plan-model_refresh_startup.md`](20261004-02-plan-model_refresh_startup.md), unit C: *the extension keeps its own catalog cache*. Units A ([`20261004-03`](20261004-03-impl-model_refresh_machine_enumeration.md)) and B ([`20261004-07`](20261004-07-impl-model_refresh_announcement.md)) landed the enumeration and the announcement this unit reads.

| In | Out |
|---|---|
| A new declared source `cache`: a file the extension owns, read in the offline phase, additive only | pi's store and `isStoreNewerThanBaked`, which stay untouched |
| One write-back rule: a successful live endpoint fetch rewrites the cache wholesale; a failed or skipped fetch leaves it | A11's agreement case, which the added ids do not touch |
| The source, its admission rule and its write-back in the README enumeration and diagram, the invariant source model and the mutation catalog | The `pi upstream` disclosure decision, which stays on hold |
| A cache reader that treats a missing or malformed file as no source | Any change to pi's network refresh order, which no extension can reorder |

## Acceptance criteria

| # | Criterion | Verification | Result |
|---|---|---|---|
| 1 | `SourceKind` and `sources.json` name a `cache` source; `UnionInput.cache` feeds it; it is a non-override id source | `grep -n cache sources.json types.ts catalog.ts` | Agent [x] |
| 2 | The file is `{ version, writtenAt, endpoints }`, each endpoint keyed to `{ retrievedAt, entries }`; a missing, malformed, unknown-version or foreign-endpoint file is no source | `node --test cache.test.ts` | Agent [x] |
| 3 | A cached entry is served with `allowNetwork:false`, so an endpoint-only id survives an offline start | `node --test gather.test.ts` | Agent [x] |
| 4 | A successful endpoint fetch replaces the declared endpoint's record wholesale, with the entries for the ids the endpoint returned and no other id | `node --test gather.test.ts` | Agent [x] |
| 5 | A failed or unreached endpoint leaves the file unchanged | `node --test gather.test.ts` | Agent [x] |
| 6 | A failed write emits `write-failed(reason)`; the write is atomic, so a failure leaves the old content | `node --test invariants.test.ts` (`E7`) | Agent [x] |
| 7 | The cache is additive: a cached id changes no field an earlier source served, and A11's case still passes | `node --test invariants.test.ts` (`E10`) and `composition.test.ts` | Agent [x] |
| 8 | The cache machine `K0`-`K2` / `Z1`-`Z5` and invariants `E1`-`E14` hold, each with a case | `node --test invariants.test.ts` | Agent [x] |
| 9 | `X3` covers the cache fold, `X15` the write-back; the totality check classifies all `E` invariants and holds all `Z` transitions | `node --test invariants.test.ts` | Agent [x] |
| 10 | Each cache transition invariant gains a `proven` mutation row; the control row stays green | `node --test mutation.test.ts` | Agent [x] |
| 11 | The README de-plans the cache device and describes the built source, and `CHANGELOG.md` carries the entry | read the three README sections and `CHANGELOG.md`; `grep -rn planned README.md` is empty | Agent [x] |
| 12 | Gates clean | `bash scripts/lint.sh`; `bash scripts/run_tests.sh` | Agent [x] |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/sources.json`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/sources.json) | the new declared source row |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | the `SourceKind` and the cache shape |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | the `cache` source case and the `UnionInput` field |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts) | the read in the offline phase and the write-back after a successful fetch |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/cache.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/cache.ts) | the file reader and writer |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts) | the cache path and the write-back wiring |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the source model, the diagram and the write-back rule |
| [`tests/extensions/pi/model-refresh/invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the cache source, the `E1`-`E14` cases, the `Z1`-`Z5` machine and the extended totality check |
| [`tests/extensions/pi/model-refresh/invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the cache cases and the `cache` source state |
| [`tests/extensions/pi/model-refresh/mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | the cache mutation rows and the re-pointed `D1` row |
| [`tests/extensions/pi/model-refresh/mutation/runner.ts`](../../tests/extensions/pi/model-refresh/mutation/runner.ts) | the replayed children drop the cache-path override |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | the temp cache path for the node suite |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The cache is a non-override id source | "Additive only" is the decided shape: a cached id may add a model and never changes a field a served entry already states, so the union's field wins and A11's persisted-overlay agreement are untouched | this record; the README source model |
| A successful live endpoint fetch rewrites the cache wholesale | the union removes nothing, so a model the endpoint dropped would otherwise be served forever; a wholesale rewrite is the one rule that lets it disappear | this record; the README write-back rule |
| A failed or skipped fetch leaves the cache as it is | the cache's whole purpose is the offline start, so a transient outage must not empty it; only an answer from the endpoint is evidence about the endpoint's catalog | this record |
| A missing or malformed cache file contributes nothing and does not throw | it is data on disk, like the declaration, so the same rule applies: a corrupt file is no source rather than a startup failure | this record |
| The cache is an event-emitting device, not a submachine: `seedRead()` and `writeBack()`, each with an outcome | the serving machine reads only the call's outcome, so the read reuses the id-source event (`X3`) and the write-back is one effect (`X15`) whose failure joins `X6` | this record; the README `## The update and catalog state machine` |
| The cache has a separate internal machine (`K0 empty`, `K1 loaded`, `K2 invalid`; transitions `Z1`-`Z5`) for cache unit tests | the outer model reads only the call's outcome, but the cache needs its own states so a missing file, a corrupt file and a populated file stay distinguishable in a unit test; the machine is nested and never flattened into the serving states. `C1`-`C4` are taken by existing invariant ids, hence the `Z` prefix | this record; the README cache-device block |
| The cache file sits beside the extension, next to `sources.json` | the folder already owns every input the extension reads, and `refreshModels` is free to name any file, so a second owned file needs no new host location | this record |
| The cache stores a complete entry, and only for the ids the endpoint's valid response carried | a bare id served offline would take default limits, which is the wrong-context-window defect in a new place; restricting to the endpoint's own ids keeps the file from claiming endpoint provenance for an id the endpoint never returned, and avoids a second source-set computation | this record; the README cache-device block |
| The file is `{ version, writtenAt, endpoints }`, each endpoint keyed to a `{ retrievedAt, entries }` record | `writtenAt` is the one write date; `retrievedAt` is one per endpoint; `entries` holds that endpoint's entries. The reader needs the declared endpoint key present, and the version makes a future format change read as `K2` rather than a partial parse that looks like `K1` | this record |
| The cache has no TTL | the machine has no expiry transition; the cache is last-known-good until the next successful fetch, and a declaration change applies on the next online run | this record |
| The write is atomic: a temporary file, then a rename | it makes `Z5` leave the old content and the state, so a failed write cannot land a half-file in `K2` | this record; the README cache-device block |

## Decisions pending

None.

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| `refreshModels` writes the cache beside the extension, so the suite wrote `cache.json` into the repository and the `L3` case became order-dependent on a previous write. Fixed with a `MODEL_REFRESH_CACHE` override, a wrapper temp file, and the mutation runner dropping the override so each mirror uses its own path | defect | this iteration | Triaged to: `cache.ts` `cachePath`, `tests/test_model_refresh.sh`, `mutation/runner.ts` |
| The `D1` row `catalog:union-alternates-with-a-counter` was a per-call parity mutation; the cache added a fourth fold, so the parity pattern repeated and the mutation no longer made the union non-deterministic for the suite's declaration. Replaced with a non-cancelling drift-id mutation | defect | this iteration | Triaged to: `mutation/catalog.ts` |
| `C1`-`C4` are existing invariant ids, so the cache machine's transitions took the `Z` prefix rather than the `C` the design first used | obstacle | this iteration | Triaged to: the README cache block and this record's Decisions |
| The extension's `CHANGELOG.md` scope is the extension, and the cache is a new extension source, so it takes a `0.6.0` entry | record | this iteration | Triaged to: `CHANGELOG.md` |

## Completed

| File | Change |
|---|---|
| [`sources.json`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/sources.json) | the `cache` source row, declared after `baked` |
| [`types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | `SourceKind` gains `cache` |
| [`config.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/config.ts) | the validator accepts the `cache` kind |
| [`catalog.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts) | `UnionInput.cache` and the `cache` case |
| [`cache.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/cache.ts) | new: `parseCache`, `readCache`, `writeCache`, `cachePath` |
| [`refresh.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts) | the cache input and the write-back after a successful fetch |
| [`index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts) | the cache read and write wiring |
| [`README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the built cache device, the `E1`-`E14` family and the de-planning |
| [`CHANGELOG.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/CHANGELOG.md) | the `0.6.0` entry |
| [`fixtures.ts`](../../tests/extensions/pi/model-refresh/fixtures.ts) | the test declaration gains the `cache` source |
| [`invariants.ts`](../../tests/extensions/pi/model-refresh/invariants.ts) | the cache source, `E1`-`E14`, `K0`-`K2` / `Z1`-`Z5`, `X15`, the extended totality check |
| [`invariants.test.ts`](../../tests/extensions/pi/model-refresh/invariants.test.ts) | the `E1`-`E14` cases and `SourceState.cache` |
| [`mutation/catalog.ts`](../../tests/extensions/pi/model-refresh/mutation/catalog.ts) | the cache mutation rows and the `D1` row |
| [`mutation/runner.ts`](../../tests/extensions/pi/model-refresh/mutation/runner.ts) | the children drop `MODEL_REFRESH_CACHE` |
| [`tests/test_model_refresh.sh`](../../tests/test_model_refresh.sh) | the node suite runs with a temp cache path |
