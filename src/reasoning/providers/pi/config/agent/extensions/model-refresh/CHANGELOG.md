# Changelog

Implementation changes to the model-refresh extension, newest first. One heading per change, dated by the day the change landed in the tree.

## [0.6.0] - 2026-10-04

- The extension keeps its own cache file, so endpoint-sourced ids survive an offline start. It is a new declared source, read in the offline phase, and additive: a cached id adds a model and never changes a field the served catalog already states. The file is `{ version, writtenAt, endpoints }`, each endpoint keyed to a `{ retrievedAt, entries }` record.
- A successful endpoint fetch replaces the declared endpoint's record wholesale with the entries for the ids that answer carried, so a model the endpoint dropped disappears and the file never claims an id the endpoint did not return. A failed or absent endpoint leaves the file. The write is atomic, and a failed write is announced.
- The cache device has its own machine (`K0`-`K2`, transitions `Z1`-`Z5`) and its own invariant family (`E1`-`E14`), each held by a case and, for the transitions, a mutation row.

## [0.5.0] - 2026-10-04

- The announcement fires on the catalog transition rather than the source counts. `refreshModels` records what the served catalog gained, lost and revised, and `report.ts` renders one `notify` carrying `updated catalog: +n / -n, m revised` when the catalog changed, one warning per failed source, and nothing when neither happened. The persistent `setStatus` footer and the working-message calls are removed.
- The first refresh diffs against the offline union; a later refresh against the union the last refresh returned. The before state is the served catalog, so a run that changed nothing is silent and the `store 469` mismatch is gone by construction.
- `session_start` announces a saved default the model scope discarded, guarded by the resolver's own test: a non-empty scope, a default that resolves to an authenticated model, and a selected model that is not it. The extension calls no `ctx.setModel`.

## [0.4.0] - 2026-10-04

- The shipped `models.json` overrides name real baked ids. Three override keys named ids pi does not bake (`deepseek-v4-flash` under `deepseek`, and the two unprefixed deepseek ids under `openrouter`), so they never applied and a request for `low` clamped to `high` on the two `openrouter` deepseek models. The `openrouter` keys take the `deepseek/` prefix; the dead `deepseek` key is dropped, because the baked `deepseek-flash` map already names every level the API advertises. The offline check in `config.test.ts` resolves the effective model and asserts each named level reaches the wire.

## [0.3.0] - 2026-10-02

- `mergeCatalogs` stays. The measurement against pi 0.99.2 found `mergeModels` still unreachable from an extension, so the local copy in `catalog.ts` remains the only reachable merge.
- The measurement read the pi-coding-agent package entry and the pi-ai package entry at 0.99.2. The exports map publishes only `.`, `./rpc-entry`, `./client` and `./experimental/plugin`; neither entry re-exports `mergeModels`, and the function is still a module-local in `dist/core/remote-catalog-provider.js` with no `export`. The same holds for the installed 0.87.1.
- README.md row A12 now carries this measurement in place of its 0.99.1 note.

## [0.2.0] - 2026-10-01

- The reconciliation moved out of `console.warn` and into pi's UI. `refreshModels` records the per-source counts as data, and `report.ts` renders them on `session_start`: a `setStatus` footer row plus a completion `notify`. A source that was not reached reads as `skipped` rather than `0`.
- In `print`, `json` and `rpc` mode the console stays the sink, discriminated on `ctx.mode`.
- README.md row A3 is retired as falsified: a live fetch reaches the extension on a normal start.

## [0.1.0] - 2026-10-01

- The extension replaces the single-file `opencode-go.ts`, which returned pi's baked catalog from `refreshModels` on every path and so deleted the persisted catalog on every start. It serves the union of the baked catalog, the persisted store and live ids, and no single source can remove what another supplied.
- Extension tests moved to `tests/extensions/<provider>/<extension-name>/`, with task-queue the first instance of that layout.
- The invariant catalog and its mutation gate landed. Thirteen deliberate breaks were measured: eleven caught, two survived, and both survivors became written contracts.
