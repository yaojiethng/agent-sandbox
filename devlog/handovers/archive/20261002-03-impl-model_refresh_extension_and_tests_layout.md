# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Implementation
**Status:** Closed

## Objective

Replace the single-file `opencode-go.ts` pi extension with a `model-refresh` extension folder that serves the union of pi's baked catalog, the persisted pi.dev catalog, and live ids, and hold that reconciliation to the standard the task-queue extension holds its own: a named invariant set with a gate that proves the suite notices a break.

## Scope

- `src/reasoning/providers/pi/config/agent/extensions/model-refresh/` - the extension, subsuming `opencode-go.ts`: `types.ts` (types), `catalog.ts` (the pure union), `thinking.ts` (level-map derivation), `refresh.ts` (the fetch orchestration), `index.ts` (registration), `README.md` (findings and the dated assumption table).
- `src/reasoning/providers/pi/config/agent/extensions/opencode-go.ts` - deleted, subsumed.
- `tests/extensions/pi/model-refresh/` - the six behavioural suites, the invariant catalog, the invariant cases, the mutation gate, and `knowledge/` with the live gateway script.
- `tests/extensions/pi/task-queue/` - moved from `tests/taskq/`; `tests/test_taskq.sh` repointed and still wired.
- `devlog/roadmap.md` - the row owning the unwired `tests/extensions/**` layout.
- `devlog/AGENT_FEEDBACK.md` - the bash friction entry for a backgrounded process holding the caller's stdout.

Excluded: wiring `tests/extensions/**` into `make test`, which the roadmap row owns; any change to pi itself; and the upstream bug report, which carries its own handover.

## The defect

The previous revision returned pi's baked catalog from `refreshModels` on every path. Because a legacy `ProviderConfig` registration makes that return value the provider's whole catalog, the extension deleted pi's persisted pi.dev catalog on every start: 30 models served instead of 33, and `space-bunny-free` absent. An unknown model id then resolved through pi's fallback, which clones `kimi-k2.6` and overwrites only id and name, so a subagent asking for `space-bunny-free` ran with a 262144 context window instead of 1048576, a 65536 output limit instead of 524288, `kimi-k2.6` pricing instead of free, and `--thinking xhigh` clamped to `high`.

`catalog.ts` now returns the union of the three sources, and no single source can remove what another supplied.

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| The extension registers no `models` list and the union is built in `refreshModels` | a returned list is the whole catalog either way, so the list has to be the union; keeping the registration bare leaves pi's baked catalog underneath | extension README, "Why the union exists" |
| A fresher persisted entry replaces a stale baked entry whole, matching pi's own `mergeModels` | the extension must serve what pi serves with no extension registered; `models.json` `modelOverrides` stay the top layer for local corrections | `catalog.ts` `mergeCatalogs`, covered by `composition.test.ts` |
| A failed live source yields `undefined`, never an empty list | an empty list is indistinguishable from a successful answer advertising nothing, so a transient outage would look like a provider that dropped every model | `refresh.ts` module comment |
| The store gate mirrors pi's own `remoteModels`, including applying the store when the baked timestamp is unknown | the extension must apply the persisted catalog under exactly the condition pi would | `catalog.ts` `isStoreNewerThanBaked` |
| `supportsReasoningEffort` is never set on a live-only model | the baked flag on `kimi-k2.6` suppresses the effort at every level; pi's auto-detection is right for the opencode.ai endpoints | `catalog.ts` `liveOnlyModelConfig` |
| The orchestrator lives in `refresh.ts` and imports no pi package at runtime | the whole failure contract is then testable with an injected fetcher, with no network and no key | `refresh.ts` |
| The extension copies `mergeModels` rather than importing it | pi does not export it, so an import cannot be written; the copy is pinned against pi's real behaviour by the `agrees with pi` differential | `catalog.ts`, case G2 |
| Extension tests mirror `src/reasoning/providers/<provider>/`, so both are under `pi` | one sense of "provider" in the tree; the model provider an extension serves is recorded in the extension, not in the path | operator confirmation 2026-09-30 |
| `tests/test_taskq.sh` stays at the runner's current depth | the runner globs `tests/test_*.sh` non-recursively, so moving the unit would silently drop the taskq suite from `make test` until the roadmap row lands | operator confirmation 2026-09-30 |
| Closed handover references to `tests/taskq/` were repointed, not rewritten | a link is a pointer and the file moved; the prose around it still describes the iteration accurately | propagation rule, AGENTS.md |

## Verified findings that changed the plan

`reasoning_effort: "none"` is accepted per model, not per product. `space-bunny-free` returns HTTP 400 for it on both opencode and opencode-go; `longcat-2.5-preview-free`, `deepseek-v4-flash` and `glm-5.3-flash` accept it on opencode-go. So the existing override set is safe where it stands and must not be copied to a model that has not been probed.

A `null` off mapping does not send nothing. Pi clamps an unsupported level to the nearest supported one, so a request for `off` is silently raised to the lowest level the model does advertise, which switches thinking on. Measured: `reasoning_effort: "minimal"` on the default format, `thinking: {type: "enabled"}` with `reasoning_effort: "low"` on the deepseek format, and `off` becoming `low` with reasoning tokens counted on both products.

The Zen free tier answers 403 to any client that is not the OpenCode client, so a Zen free model cannot be probed from pi at all. `kimi-k2.6` answers 403 on both products, so its defect class rests on the wire capture against its exact baked compat block rather than a live response.

## What was measured before the invariant set was written

Thirteen deliberate breaks were applied one at a time to the extension and the then-current 85-test suite was asked whether it noticed. Eleven were caught. Two survived:

- an overlay that set `contextWindow` to `0` passed every case, because no case asserted that a served model carries positive limits;
- an overlay that made an empty baked catalog drop the persisted store passed every case, because no case held the union monotone across sources.

Both survivors were invariants nobody had written down. That measurement is what the invariant set and the gate exist to prevent recurring.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | `opencode-go.ts` is gone; the `model-refresh` folder carries the extension and its documentation | `ls src/reasoning/providers/pi/config/agent/extensions/` | Met |
| 2 | The union serves the persisted pi.dev catalog in the offline phase, after a live-fetch failure, and after a models.dev failure | `node --test tests/extensions/pi/model-refresh/catalog.test.ts tests/extensions/pi/model-refresh/gather.test.ts` | Met |
| 3 | The defect is proven through pi's own composer, with the old registration as the control case | `node --test tests/extensions/pi/model-refresh/composition.test.ts` | Met |
| 4 | No behavioural test reaches the network or needs a key | every node test runs with an injected fetcher or an injected `fetch`; `gather.test.ts` asserts the offline phase calls the fetcher zero times, and `wire.test.ts` hands the request to a stub that refuses | Met |
| 5 | The endpoint-shape probes are knowledge tests, excluded from `make test`, and pass when run | `wire.test.ts` 9/9 and `knowledge_opencode_gateway_matrix.sh` 6/6 | Met |
| 6 | `tests/extensions/pi/task-queue/` holds the suite and `make test` still runs it | `bash scripts/run_tests.sh tests/test_taskq.sh`; 264/264 node, 2/2 harness | Met |
| 7 | No reference to the old path survives | `grep -rn "tests/taskq" .` returns nothing | Met |
| 8 | Every assumption carries a date, a method, and the code that would falsify it | the assumption table in the extension README | Met |
| 9 | A roadmap row owns wiring `tests/extensions/**` into `make test` | the row in `devlog/roadmap.md` | Met |
| 10 | The invariant set is named, and every case maps to one | 35 cases across 23 invariants, one line per case in the report | Met |
| 11 | The suite fails when the design breaks | 24 mutation rows, 24 as expected, 1 of them a control | Met |
| 12 | The gate cannot pass vacuously | the control row; attribution by invariant id; attribution requires an assertion, not a crash | Met |
| 13 | The full suite and the lint gate are clean | `bash scripts/run_tests.sh` 1004/1004 across 67 files; `bash scripts/lint.sh` clean across 3 gates | Met |

## Completed

| File | Change | Status |
|---|---|---|
| `.../extensions/model-refresh/types.ts` | `ModelDefinition`, `StoredCatalog`, `ModelsDevModel`, and the injectable `FetchJson` type | done |
| `.../extensions/model-refresh/catalog.ts` | the pure union: store gating, merge order, models.dev metadata overlay, live-only construction, transport sets | done |
| `.../extensions/model-refresh/thinking.ts` | level-map derivation from an advertised effort list | done |
| `.../extensions/model-refresh/refresh.ts` | the fetch orchestration with no pi runtime import, so the failure contract is testable | done |
| `.../extensions/model-refresh/index.ts` | registration only; supplies pi's baked catalog and data timestamp to `refresh.ts` | done |
| `.../extensions/model-refresh/README.md` | the union rationale, the thinking-level mechanisms, the dated assumption table, and what is still open | done |
| `.../extensions/opencode-go.ts` | deleted, subsumed by the folder | done |
| `tests/extensions/pi/model-refresh/catalog.test.ts` | cases over the union: every store-gate branch, merge order, per-source failure, duplicates | done |
| `tests/extensions/pi/model-refresh/thinking.test.ts` | cases for explicit levels, null versus absent, the none effort | done |
| `tests/extensions/pi/model-refresh/gather.test.ts` | the offline phase never fetches, a failed source narrows, wrong-shaped payloads survive | done |
| `tests/extensions/pi/model-refresh/composition.test.ts` | cases through pi's real `composeModelProvider`, with the old registration as the control | done |
| `tests/extensions/pi/model-refresh/load.test.ts` | the module graph and the registration shape under jiti, skipping without pi | done |
| `tests/extensions/pi/model-refresh/wire.test.ts` | the built request payload per level and compat block, read through `onPayload` with a refusing `fetch` stub | done |
| `tests/extensions/pi/model-refresh/invariants.ts` | the invariant catalog, 23 invariants, per-source and per-level cases derived from the product's own tables | done |
| `tests/extensions/pi/model-refresh/invariants.test.ts` | one case per catalog entry, including the `agrees with pi` differential against `withRemoteCatalog` | done |
| `tests/extensions/pi/model-refresh/fixtures.ts` | shared builders and a seeded generator | done |
| `tests/extensions/pi/model-refresh/mutation/catalog.ts` | 24 rows, 1 control | done |
| `tests/extensions/pi/model-refresh/mutation/runner.ts` | the temp-mirror replay engine, six verdicts | done |
| `tests/extensions/pi/model-refresh/mutation.test.ts` | the gate: control row, attribution, sorted report | done |
| `tests/extensions/pi/model-refresh/knowledge/knowledge_opencode_gateway_matrix.sh` | 6 cases: live per-model acceptance of the disabled effort, needs `OPENCODE_API_KEY` | done |
| `tests/extensions/pi/task-queue/` (moved) | 24 files; import depth and the two path constants updated, registration guard intact | done |
| `tests/test_taskq.sh` | repointed at the moved suite; stays at the runner's glob depth | done |
| `devlog/handovers/20260930-02..07` | `tests/taskq` references repointed so no link dangles | done |
| `devlog/roadmap.md` | the row owning the unwired extension-test layout and the `bash -n` sweep | done |
| `devlog/AGENT_FEEDBACK.md` | bash friction: a backgrounded process holding the caller's stdout, with the two adjacent traps | done |

## Findings

| # | Finding | Where it landed | Status |
|---|---|---|---|
| 1 | `storeEntriesFor` threw on a persisted array holding `null`, and accepted an entry with no `id` | `catalog.ts`, invariant M7, L2 | Fixed |
| 2 | `buildUnion` walked a non-array `liveIds` character by character | `catalog.ts`, invariant L2 | Fixed |
| 3 | M1, C1, M5, M8, T3 stated contracts the product does not hold | restated, and each now has a case that can fail against it | Fixed |
| 4 | M3 computed its expectation by calling the functions under test | restated field by field | Fixed |
| 5 | The gate had no control row, so a mirror that could not run green proved every row | control row added | Fixed |
| 6 | Six of fifteen rows named an invariant that did not actually fail | attribution by invariant id; four rows re-anchored, four gained coverage | Fixed |
| 7 | A mutant that threw on everything was accepted as proof of L2 | the throw and leak verdicts split, with a well-formed control inside the case | Fixed |
| 8 | Four transport ids contradicted pi's baked catalog | the ids were removed, and the residual risk is recorded in the README | Fixed |
| 9 | The fallback ladder advertised `max` but not `xhigh`, so a request for `xhigh` was answered with `max` | the ladder is now `{ low, high }` | Fixed |
| 10 | `unsendableLevels` was dead product code whose comment claimed it caught a real defect | removed with its three cases | Fixed |
| 11 | A `null` off mapping is not a safe way to say "no off effort" | the level map marks the level unsupported and the caller accepts the level is unavailable | Fixed |
| 12 | `reasoning_effort: "none"` is a per-model value, not a gateway-wide one | recorded as an assumption with its probe; the extension does not rely on it | Recorded |
| 13 | A test that needs a request body should use pi's `onPayload` hook plus an injected `fetch`, not a loopback capture server | `wire.test.ts` rewritten; the 47-minute stall is in `devlog/AGENT_FEEDBACK.md` | Fixed |
| 14 | The task-queue mutation gate has the vacuity hole finding 5 named | outside this iteration's scope | Open, operator's call |

## Findings summary

23 invariants, 35 cases, 24 mutation rows of which 1 is a control. The gate prints the 11 invariant ids no row holds, so the suite's blind spots are visible rather than assumed. 142 tests across 8 files in the model-refresh folder, green on three consecutive full-glob runs. The repository suite is 1004 tests across 67 files. Lint is clean across three gates.

## Mid-run adjustments

- The first mutation harness mutated `src/` in place and restored with `git checkout`, which silently discarded uncommitted work in the same files mid-run. Rewritten to copy before mutating and copy back, then rewritten again to build a temp mirror and never touch the repository at all.
- The gate was first written to run inside the folder glob. `node --test` runs files concurrently, so it read `catalog.ts` while holding it broken, and the full-glob run went red intermittently. The mirror design removed the class of problem.

## Resolution methods

Two lanes. The invariant statements, the product decisions and every document are the operator's, and they were written directly. The cases, the gate and the fixture builders went to a subagent against a written brief that named the invariant each case had to fail against, which is what surfaced findings 1, 2, 4 and 6. A second subagent pass closed the test-side findings from the first review, and a third closed the second review's. Each pass reported what it could not close rather than adjusting a row until it passed.

## Post-review learnings

Three reviews were needed and the first two were not converged. The recurring defect was not a missing case; it was a stated invariant that no case could fail against, written because the implementation did something rather than because the design required it. Three reviews found six such statements. The mutation gate now requires a row's failure to name the row's invariant, which is what turns "the suite is green" into "the suite holds this invariant".

The other recurring lesson is about the agent's own instrumentation: the first harness destroyed uncommitted work, the second corrupted the suite it was measuring, and both looked like passing tests at the time.

## Final output artifacts

| Artifact | Home |
|---|---|
| the extension | `src/reasoning/providers/pi/config/agent/extensions/model-refresh/` |
| the invariant catalog and its renderer | `tests/extensions/pi/model-refresh/invariants.ts` |
| the invariant cases | `tests/extensions/pi/model-refresh/invariants.test.ts` |
| the mutation rows, engine and gate | `tests/extensions/pi/model-refresh/mutation/` and `mutation.test.ts` |
| the dated finding and assumption table | `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` |
| the bash friction entry | `devlog/AGENT_FEEDBACK.md` |

## Resolution status

Closed. Every invariant holds, and the gate is honest about the invariants it does not hold.

Open, and the operator's to decide:

1. Whether the control row, the attribution check and the `not-run` verdict propagate to `tests/extensions/pi/task-queue/mutation/`, which has the same vacuity hole. That is a change to a reviewed suite outside this iteration's scope.
2. Whether the eleven invariants no mutation row holds should gain rows. The gate prints them.
3. When the model-refresh folder is wired into `make test`. It is not wired now, so these tests run only by hand.
4. Whether an accepted `reasoning_effort: "none"` stops reasoning. Unproven: the gateway's reasoning-token counts are too noisy to decide it. The extension does not rely on it, and the README records it as open.

## Records this supersedes

None. The `model-refresh` README replaces nothing; it records the union rationale and the dated assumptions in place. Two superseded handovers, `20260930-04` and `20260930-05`, were folded into this one at the wrap of 2026-10-02, because they were two sessions of one unit: the extension, its test layout, and the invariant layer that holds both to the task-queue standard.
