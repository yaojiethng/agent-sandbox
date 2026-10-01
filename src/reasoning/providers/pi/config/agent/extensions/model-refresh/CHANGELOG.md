# Changelog

Implementation changes to the model-refresh extension, newest first. One heading per change, dated by the day the change landed in the tree.

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
