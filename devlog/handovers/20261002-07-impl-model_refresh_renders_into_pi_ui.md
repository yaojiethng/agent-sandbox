# Agent Handover

**Date:** 2026-10-02
**Milestone:** M3.2.1 - Loops as Workflows
**Type:** Implementation
**Status:** Closed

## Objective

Stop the model-refresh extension from writing to the terminal behind the TUI's back, and put the catalog reconciliation on a surface the TUI owns.

## Scope

The roadmap row "model-refresh renders into pi's UI instead of the terminal". The operator reported that the extension's two startup lines corrupted the TUI and asked for them to be routed to the welcome message and to a refreshing/refreshed pair instead.

## Carried forward

None.

## Acceptance criteria

| # | Criterion | Verifiable by | Status |
|---|---|---|---|
| 1 | The reporter writes nothing to the terminal in TUI mode | `report.test.ts`, the console-capture case; a `console.warn` reintroduced turns it red | accepted |
| 2 | The reconciliation reads as one line naming every source, with a source that was not reached named `skipped` rather than `0` | `report.test.ts`, 12 cases against literal strings | accepted |
| 3 | TUI mode routes to the UI and every other mode keeps the console, discriminated on `ctx.mode` | `load.test.ts`, the per-mode routing cases | accepted |
| 4 | A report recorded before any UI exists is held and rendered on attach, not dropped | `report.test.ts`, the pre-UI case | accepted |
| 5 | The whole extension suite is green | `node --test` over the tree, 157 of 157 | accepted |
| 6 | The mutation gate still holds every row including its control | 24 of 24 as expected | accepted |
| 7 | The bash suite is unaffected | `bash scripts/run_tests.sh`, 1012 of 1012 | accepted |

## Hot files

| File | Why in scope |
|---|---|
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts) | held both `console.warn` calls |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts) | new, the rendering and the summary wording |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts) | the structured per-source counts |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts) | the `CatalogReport` type |
| [`src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md`](../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md) | the assumption table, one row of which this work falsified |
| [`tests/extensions/pi/model-refresh/`](../../tests/extensions/pi/model-refresh/) | the extension's suite |

## Decisions

| Decision | Rationale | Where recorded |
|---|---|---|
| Carry the per-source counts as data through an additive `onReport` sink, rather than parsing the log lines | the counts were only available as prose, and a caller reading a number out of a sentence is a representation leak. The sink is additive, so the eleven existing call sites across three test files are untouched | `refresh.ts`, `GatherInput.onReport` |
| Render on `session_start`, not inside `refreshModels` | the TUI does not exist while the model runtime is being built, so there is no surface to render into at that moment. `session_start` is the first event that carries one | `report.ts` module comment; assumptions A13 and A14 |
| A source that was not reached reads as `skipped`, not `0` | `live 0` is indistinguishable from a source that answered with nothing, which is the exact confusion the two failure messages exist to prevent | `summarize` in `report.ts` |
| Keep the console for `print`, `json` and `rpc` mode | there is no frame to corrupt in those modes, and discarding a working sink would lose the reconciliation where a headless run is the only place it is read | `index.ts`, discriminated on `ctx.mode` |
| Delete the `!latest` guard rather than add a case for it | a deliberate break of that guard survived, because no call path reaches it. A case that pins unreachable code is worse than no case | `report.ts`, `render` is internal and unguarded |

## Decisions pending

| Question | Blocks | Options |
|---|---|---|
| Is the reconciliation wanted on the welcome line? | nothing in this repository. That line is a `console.log` inside `InteractiveMode.init`, built from `session.scopedModels` before extensions hold a UI, and no extension API reaches it | leave it on the footer status row, which is the nearest surface that exists; or change pi, which is outside this repository and is its own task |
| Should a terminal invariant be added to `invariants.ts` so the regression gets a mutation-gate row? | nothing today. The regression is held by a direct assertion in `report.test.ts`, which was proved sensitive | add the invariant and a catalog row, which widens the invariant set for one defect; or keep the direct assertion, which is already sensitive and is the smaller record |

## Findings

| Finding | Type | Impact | Triaged to |
|---|---|---|---|
| Assumption A3 claimed the live fetch is never reached, and the operator's own startup output carries a 43-model live list | contradiction | the extension README asserted something false about the runtime it depends on | A3 retired as falsified in the extension README, with the evidence quoted |
| The `!latest` guard in `render` was unreachable from every call path | bug | a deliberate mutation of it survived, which would have been read as a weak test | `report.ts`, guard deleted |
| Two test stubs built a `pi` object with only `registerProvider`, so adding `pi.on` broke the load and the invariant report rather than the extension | bug | a test failure that pointed away from the cause | both stubs updated; `invariants.test.ts` needs no rendering, `load.test.ts` asserts it |
| The offline-path mutation row anchored on a line this change rewrote, so the row read `no-op` and the gate's control went red | bug | the gate's control failing means the mirror cannot run green, which makes every other row meaningless | `mutation/catalog.ts`, row re-anchored on the offline `buildUnion` call |
| There is no extension API that reaches the welcome line, so the operator's first routing target does not exist | blocker | the reconciliation went to the footer status row instead | decisions-pending row above |
| The startup refresh completes before the TUI mounts, so the working message cannot be shown for it | bug | the requested "Refreshing model catalogs..." pair is half-deliverable, and the half that is not needed saying | assumption A14 in the extension README |
| `tests/extensions/**` is not wired into `make test`, so these 157 assertions do not run under the suite | scope change | the work is verified but not gated; a future editor does not get it for free | `devlog/roadmap.md`, the pre-existing row that owns the wiring |

## Completed

| File | Change |
|---|---|
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts` | new, the summary wording, the completion notice, and the UI render |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts` | both `console.warn` calls replaced by a `session_start` handler that branches on `ctx.mode` |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts` | an additive `onReport` sink emitting `CatalogReport` on both the offline and the network path |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts` | the `CatalogReport` type |
| `src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md` | a "Where the output goes" section, A3 retired, A13 and A14 added, the test table extended |
| `tests/extensions/pi/model-refresh/report.test.ts` | new, 12 cases including the console-capture regression guard |
| `tests/extensions/pi/model-refresh/load.test.ts` | the jiti stub answers `pi.on`, plus four routing cases |
| `tests/extensions/pi/model-refresh/invariants.test.ts` | the jiti stub answers `pi.on` |
| `tests/extensions/pi/model-refresh/mutation/catalog.ts` | the offline-path row re-anchored |
| `devlog/roadmap.md` | the row, with the welcome-line limit and the two follow-ons |

## Propagation replay

| File | Change planned | Status |
|---|---|---|
| `index.ts` | remove both `console.warn` calls | completed |
| `index.ts` | add the `session_start` handler | completed |
| `report.ts` | new module | completed |
| `refresh.ts` | add the structured sink | completed |
| `types.ts` | add the type | completed |
| `README.md` | record the routing, falsify A3, add A13 and A14 | completed |
| `report.test.ts` | new, covering wording, hold, per-source attribution, and the console guard | completed |
| `load.test.ts` | stub `pi.on`, add per-mode routing cases | completed |
| `invariants.test.ts` | stub `pi.on` so the invariant report survives the load | completed |
| `mutation/catalog.ts` | re-anchor the offline-path row | completed |
| `mutation.test.ts` | unchanged; the gate is what proved the other three rows | completed, no change needed |
| `devlog/roadmap.md` | the row | completed |
| an invariant row in `invariants.ts` for the terminal | a mutation-gate row for the console regression | not started, decisions-pending row |
| `tests/extensions/**` wiring into `make test` | run these 157 assertions under the suite | not started, the pre-existing roadmap row owns it |

## Deferred items

The mutation-gate row for the console regression and the `tests/extensions/**` wiring. Both are named in the records above; the first has a decisions-pending home and the second a roadmap home, so neither is re-listed here.

## What's Next

M3.2.1 - Loops as Workflows, and it stays in progress.

**Conclusions from this iteration.** The corruption was never about the message text. It was a sink chosen without asking who owns the terminal, and the fix is the sink. Separately, the extension's own assumption table had already gone stale against the runtime it depends on, which is a standing cost of writing a table that nothing re-checks.

**Watch out.** `refreshModels` runs before the TUI exists, so anything that wants to show progress for the startup refresh has to wait for a surface pi does not currently offer. Do not add a `console.log` in that window to work around it. The extension's 157 assertions are not in `make test`; run them with `node --test --experimental-strip-types tests/extensions/pi/model-refresh/*.test.ts`.
