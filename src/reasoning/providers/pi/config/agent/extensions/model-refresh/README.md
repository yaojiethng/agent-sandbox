# model-refresh

Keeps pi's `opencode-go` catalog complete. The extension adds the models OpenCode advertises on its own `/models` endpoint that neither pi's baked catalog nor pi's persisted pi.dev catalog carries yet, and it preserves the pi.dev catalog rather than replacing it. What changed in the extension over time is recorded in [CHANGELOG.md](CHANGELOG.md).

## Why the union exists

Pi composes a provider's model list from three layers: the built-in provider, `models.json`, and an extension registration. The layer order is not the problem. The problem is the shape of the legacy registration form.

When an extension registers through `ProviderConfig` and returns a list from `refreshModels`, that list becomes the provider's entire catalog. Pi's own source is `composeModelProvider` and `applyExtension` in `dist/core/provider-composer.js`: `applyExtension` returns `config.models.map(...)` whenever the registration carries a `models` list, and the composed `refreshModels` sets `refreshedExtensionModels` to whatever the extension returned.

The previous revision of this extension returned pi's baked catalog on every path. Because a returned list replaces the catalog, that deleted the pi.dev overlay on every start. The measured effect, with the same agent directory and the same credentials:

| Run | `opencode-go` models served | `space-bunny-free` present |
|---|---|---|
| extension registered | 30 | no |
| extension disabled (`-ne`) | 33 | yes |
| in process, before registration | 33 | yes |
| in process, after registration | 30 | no |

30 is the size of pi's baked `opencode-go` catalog. 33 is that catalog plus the three models the persisted pi.dev entry adds: `gpt-6-luna`, `longcat-2.5-preview-free`, and `space-bunny-free`.

Because the model vanished from the catalog, pi resolved `--model space-bunny-free` through its unknown-model fallback. That fallback clones a different model and overwrites only the id and the name, so a subagent asking for `space-bunny-free` on `opencode-go` silently ran as `kimi-k2.6`. Measured differences between the requested model and the model actually served:

| Field | `space-bunny-free` | What the fallback served |
|---|---|---|
| context window | 1048576 | 262144 |
| max output tokens | 524288 | 65536 |
| cost per Mtok | 0 (free) | 0.95 in, 4 out |
| thinking levels | off null, low through max, xhigh included | high and max only |

With `--thinking xhigh` the level was clamped to `high` and the run was billed at the fallback model's rate. With the extension disabled the same command kept `xhigh` and cost nothing.

The union in `catalog.ts` is the fix. It takes the three sources and returns one list, in the order pi itself would apply them, and no single source can remove what another supplied.

## Why the live fetch is written but rarely reached

Pi never calls a provider's `refreshModels` with `allowNetwork: true` outside `pi update --models`, and that command builds its own model runtime without loading extensions. `ModelRuntime.create` in `dist/core/model-runtime.js` computes `refreshFromNetwork = this.modelNetworkEnabled && options.allowModelNetwork === true`, and no call site in `dist/` passes `allowModelNetwork: true`; the two `allowNetwork: true` refresh sites in the bundle are `pi update --models` (`refreshModelCatalogs2`) and the llama.cpp `/llama` refresh.

So the live fetch is reached only if that changes. It is kept because it is the sole source for a model OpenCode ships before pi.dev catalogues it, and it is written so that not running it narrows the result instead of damaging it: a failed or absent live source yields `undefined`, which is not the same as an empty list, because an empty list is indistinguishable from a successful answer advertising nothing.

## Thinking levels

Three separate mechanisms decide what a thinking level does. Two are in pi-ai's `dist/models.js`, where pi decides which levels a model advertises and how a requested level is clamped: `getSupportedThinkingLevels` and `clampThinkingLevel`. The third is per transport, in `dist/api/openai-completions.js`, `dist/api/anthropic-messages.js` and `dist/api/openai-responses.js`, where the map becomes a request field. All three are reproduced offline by `wire.test.ts` and by the W1 invariant case.

An absent `thinkingLevelMap` key counts as supported, with one exception: `xhigh` and `max` are advertised only when the map names them, because `getSupportedThinkingLevels` in `pi-ai/dist/models.js` tests those two for `mapped !== undefined` and every other level only for `mapped !== null`. Only an explicit `null` marks a level unsupported. A model whose provider advertises no "off" effort must therefore carry `off: null`, or pi offers a disabled level it cannot deliver.

An unsupported level is clamped to the nearest supported one rather than dropped, and the search runs upward before it runs downward. A `null` off mapping therefore does not send nothing: it raises the requested level to the next one the model does advertise, which switches thinking on. Measured with a null off mapping and a requested off: the default format sent `reasoning_effort: "minimal"`, and the deepseek format sent `thinking: {type: "enabled"}` with `reasoning_effort: "low"`. The same shape appears live: `space-bunny-free --thinking off` on both products ran at `low` with reasoning tokens counted. The downward half of the search matters the same way: a ladder that advertises `max` without `xhigh` answers a request for `xhigh` with `max`, which is why the fallback range this extension uses stops at `high`.

`compat.thinkingFormat: "deepseek"` sends `thinking: {type: ...}` for the enabled state and `thinking: {type: "disabled"}` for the disabled one, putting the level itself in `reasoning_effort`. The default format sends only `reasoning_effort`, and the disabled case sends the map's off value. `compat.supportsReasoningEffort: false` discards `reasoning_effort` at every level while leaving the deepseek toggle in place, so a map that still names high and max advertises two levels the provider never receives.

Which of these bite depends on the model's baked entry, and the two products differ:

| Model | Product | Defect present |
|---|---|---|
| `deepseek-v4-flash`, `-v4-flash-vision-exp`, `-v4-pro`, `-v4.1-flash` | opencode-go | deepseek toggle at the disabled level, and no off key in the map |
| `kimi-k2.6` | opencode-go and opencode | deepseek toggle at off, and `supportsReasoningEffort: false` discarding every mapped level |
| `deepseek-v4-flash`, `-v4-pro`, `-v4.1-flash` | opencode | no deepseek toggle in the baked entry; `off: null` instead, so the disabled level is unavailable rather than ignored |
| `grok-build-0.1` | opencode | none: `supportsReasoningEffort: false` with no level above off is inert |

`liveOnlyModelConfig` therefore omits `supportsReasoningEffort` entirely, which lets pi auto-detect it from the endpoint, and marks every level the provider does not advertise as `null`.

## Verified assumptions

Every row was checked on the date given. Each names the method that produced it and the code that would falsify it, so a reader can tell when a row has gone stale. The operator's expectation is that some of these stop being true when pi fixes the underlying behaviour; the point of the table is to make that visible rather than silent. The rows were last walked against pi 1.0.0 on 2026-10-03; a row that moved is marked `MOVED` with its original claim struck through.

| # | Assumption | Verified | Method | Falsified by |
|---|---|---|---|---|
| A1 | A legacy `ProviderConfig` whose `refreshModels` returns a list replaces the provider's whole catalog | 2026-10-03 | `applyExtension` in pi's `dist/core/provider-composer.js`, plus the in-process measurement above and `composition.test.ts` | `applyExtension` gaining a merge path, or pi adding a non-replacing registration form |
| A2 | A model missing from the catalog resolves to a clone of `defaultModelPerProvider[provider]` with only id and name replaced | 2026-10-03 | `buildFallbackModel` in pi's bundle; confirmed by the served cost of 0.95/4 per Mtok, which is the table default and nothing else. Re-checked against 1.0.0, where `model-resolver.js` is byte-identical to 0.99.2's | the fallback builder, or the table `defaultModelPerProvider` |
| A3 | ~~No pi call site passes `allowModelNetwork: true`, so an extension's `refreshModels` never sees `allowNetwork: true`~~ **FALSIFIED 2026-10-02.** The extension's own startup output carried `[model-refresh] live model list: 43 models from https://opencode.ai/zen/go/v1/models`, which is only reachable when `context.allowNetwork` is true. The call site has not been located, so the row is retired rather than rewritten; what is now established is that a network refresh reaches the extension on a normal start, which is the opposite of what the row asserted | 2026-09-30 | every `ModelRuntime.create` call site in `dist/`, and the two `allowNetwork: !0` sites in the bundle; no `[model-refresh] live model list` line ever appears at startup | **already false.** Superseded by A13 |
| A4 | An absent map key is supported; only `null` is unsupported, except that `xhigh` and `max` need an explicit mapping | 2026-10-03 | `getSupportedThinkingLevels` in `pi-ai/dist/models.js`, read from the installed package; the level map handed to pi's request builder, read back off the built payload; `thinking.test.ts` and `wire.test.ts` | the level-selection code in pi's bundle |
| A5 | An unsupported level is clamped to the nearest supported one, searching upward first and then downward | 2026-10-03 | `clampThinkingLevel` in `pi-ai/dist/models.js`; the built payload for a null off mapping, which carries `reasoning_effort: "minimal"`; reproduced live as `off` becoming `low`. Re-checked against 1.0.0, where the function is byte-identical to 0.99.2's | the same level-selection code |
| A6 | `supportsReasoningEffort: false` drops `reasoning_effort` at every level but keeps the deepseek toggle | 2026-10-03 | the built payload for a baked compat block, which carries `thinking: {type: "enabled"}` and no effort; re-checked against 1.0.0 across every `thinkingFormat` | the request builder in `pi-ai/dist/api/openai-completions.js` |
| A7 | `reasoning_effort: "none"` is accepted by some models and rejected by others, on both products | 2026-10-03 | live probes; `knowledge_opencode_gateway_matrix.sh`. `space-bunny-free` returns 400 on both, `longcat-2.5-preview-free` accepts it on opencode-go; the 1.0.0 run split the same way, and the split is a gateway property, not a pi one | the gateway, or the probe test turning red |
| A8 | ~~The Zen free tier answers 403 to any client that is not the OpenCode client, so a Zen free model cannot be probed from pi~~ **MOVED 2026-10-03.** The gateway no longer enforces the client check. pi still sends `x-opencode-client: pi` (`provider-attribution.js`, byte-identical to 0.99.2's), and a Zen free model answers 200 and completes a request. | 2026-10-03 | live probe of `space-bunny-free` on `opencode.ai/zen/v1`: 200 with the key, with pi's own client header, and with `x-opencode-client: opencode`; pi 1.0.0 answered `PONG` on the same model, and a bogus key still returns 401 | the gateway re-tightening the check |
| A9 | ~~The persisted pi.dev entry is newer than the baked data, so the store gate opens~~ **MOVED 2026-10-03.** Under 1.0.0 the comparison inverts, so `remoteModels` returns `[]` and the store overlay is dropped for all four providers. | 2026-10-03 | the 1.0.0 baked manifest `generatedAt` is `2026-10-01T18:57:11.882Z`, later than every store `lastModified`; a live probe of `ModelRuntime` takes 20 overlay entries on 0.99.2 and 0 on 1.0.0, and a `lastModified` of `2026-12-01` restores them | a pi release whose baked data predates the store again, which reopens the gate by design |
| A10 | ~~`space-bunny-free` is absent from pi's baked `opencode-go` catalog and present in the persisted pi.dev entry~~ **MOVED 2026-10-03.** Both halves were already stale: the baked `opencode_go_default` in 0.99.2 and 1.0.0 both carry the model, and under 1.0.0 the persisted entry no longer overlays it (A9). The store copy is redundant rather than wrong. | 2026-10-03 | the baked catalog holds 29 chat ids including `chat:space-bunny-free`; an offline `--list-models` with an empty agent dir lists it, and a mutated store `maxTokens` changes nothing under the real timestamps | a pi release that drops the model from the baked catalog |
| A11 | pi's `mergeModels` overlays by whole-entry replacement, which is the semantics `mergeCatalogs` copies | 2026-10-03 | the G2 case `agrees with pi` drives pi's own `withRemoteCatalog`, whose `getModels` calls `mergeModels`, and compares its output entry for entry with ours over replacement, append, cross-provider and stale-gate rows. Re-checked against 1.0.0, where `remote-catalog-provider.js` is byte-identical to 0.99.2's | a pi release changing the merge, the gate or the provider filter, which that case turns red |
| A12 | `mergeModels` is unreachable from an extension on 0.87.1, 0.99.2 and 1.0.0, so the copy is forced | 2026-10-03 | the installed 0.87.1 bundle and the 0.99.2 install under `/tmp/picheck/probe99`, and the 1.0.0 install under `/tmp/pi-1.0.0`: in all three the function is a module-local in `dist/core/remote-catalog-provider.js` with no `export` keyword, the 1.0.0 package entry names 156 exports with no `mergeModels`, and `package.json` publishes no subpath that reaches it | a pi release that exports `mergeModels` from a published subpath or from a package entry |
| A13 | A TUI session reaches an extension's `session_start` handler with a usable `ctx.ui`, and `ctx.mode` reads `tui` there | 2026-10-03 | `ExtensionHandler` and the `session_start` overload in pi's `dist/core/extensions/types.d.ts`, which type the handler's second argument as `ExtensionContext` carrying `ui: ExtensionUIContext` and `mode: ExtensionMode`; re-checked against a live 1.0.0 TUI under a pty, where the handler saw `mode: "tui"`, `hasUI: true`, and mounted a dialog | pi dropping `ui` from `ExtensionContext`, or `session_start` firing before the interactive TUI mounts |
| A14 | `refreshModels` runs before any extension UI exists, so its output cannot be rendered as it happens | 2026-10-03 | `ModelRuntime.registerProvider` calls `void this.refresh(...)` without awaiting, and `ModelRuntime.create` awaits its refresh before the session is built; both complete before `InteractiveMode.init` mounts the TUI, which is the first thing that owns a UI. Re-checked against 1.0.0, where the ordering is unchanged | pi awaiting a provider refresh after the TUI mounts, which would make the working message observable on the first refresh and retire this row |

## Where the output goes

The extension writes nothing to the console in TUI mode. The TUI owns the terminal, and a line written behind its back lands inside the rendered frame; the operator reported exactly that, with every line after the extension's own output drawn against the wrong frame.

`refreshModels` records the per-source counts as data (`CatalogReport`) and `report.ts` renders them into pi's UI: a persistent `setStatus` footer row carrying the one-line reconciliation, and a `notify` on completion that carries the same line plus any source failure. A source that was not reached is named `skipped` rather than `0`, so a line never reads as a source that answered with nothing.

The rendering happens on `session_start`, because that is the first event carrying a UI. A consequence worth stating: the "Refreshing model catalogs..." working message cannot be shown for the startup refresh, which completes before the TUI mounts (A14). It is shown for a refresh that happens later, such as a `/model` change or a reload. Closing that gap needs pi to surface a pre-TUI notification, not an extension change.

In `print`, `json` and `rpc` mode there is no frame to corrupt, so the console stays the sink there. `ctx.mode` is the discriminator, not a guess.

## Open, not established

Whether an accepted `reasoning_effort: "none"` actually stops reasoning. The gateway's reasoning-token counts are too noisy to decide it: `longcat-2.5-preview-free` reported 307 tokens at the baked off setting and 166 at `none`, and `glm-5.3-flash` reported 45 at `none` against 44 at `low`. A null `none` reading is as good a guess as a positive one, so the extension does not rely on `none` doing anything, and neither should an override that has not been measured on its own model.

`kimi-k2.6` is unreachable with this key on both products, answering 403 `Model access is disabled`. Its defect class therefore rests on the built payload for its exact baked compat block, not on a live response. The same limit applies to every other model the account cannot reach, which is most of the Zen catalog: only `space-bunny-free` was reachable there.

## Tests

`tests/extensions/pi/model-refresh/` holds the suite. The node tests need no network, no API key, and no model runtime: they take an injected fetcher, and where a request shape matters they read pi's built payload through the `onPayload` hook and hand the request to a `fetch` stub that refuses.

Two of the files are knowledge tests under the Test Placement rule, because the seam is external. `wire.test.ts` probes pi-ai's request builder, a library this repository does not maintain. `knowledge/knowledge_opencode_gateway_matrix.sh` probes the gateway, and needs a key and spends requests.

| File | Covers |
|---|---|
| `catalog.test.ts` | the union: store gating, merge order, per-source failure, duplicates |
| `thinking.test.ts` | level-map derivation, null versus absent, unsendable levels |
| `gather.test.ts` | the fetch paths: the offline phase never calls the fetcher, a failed source narrows |
| `composition.test.ts` | the defect itself, driven through pi's composer, with the old registration as the control |
| `load.test.ts` | the module graph, the registration shape under jiti, and the `session_start` routing per run mode |
| `report.test.ts` | the reconciliation wording, the pre-UI hold, and the assertion that the reporter writes nothing to the terminal |
| `wire.test.ts` | knowledge: the built request payload per thinking level and compat block |
| `fixtures.ts` | the shared model, store and models.dev builders the invariant cases draw on |
| `invariants.ts` | the invariant catalog: one named statement per invariant, with the per-source and per-level cases derived rather than listed |
| `invariants.test.ts` | one case per catalog entry, over the real product surface, printing the invariant report |
| `mutation/catalog.ts` | one row per deliberate break of the extension, each naming the invariant it attacks |
| `mutation/runner.ts` | the replay engine: a temp mirror per row, one child process, the six verdicts |
| `mutation.test.ts` | the gate: a control row, an attribution check, and a `proven` verdict per row |
| `knowledge/knowledge_opencode_gateway_matrix.sh` | knowledge, live: per-model acceptance of the disabled effort; needs a key |

## Invariants

`invariants.ts` names what must hold, and `invariants.test.ts` holds each one with a case; the report prints one line per case and a red line reads as an invariant id. `mutation/catalog.ts` then asks the other question, whether a green suite is evidence: each row is a defect the design rejects, and the gate fails unless the suite turns red against it. The gate is what turned up the two survivors a green suite once hid, a served entry with a zero context window and an empty baked catalog that dropped the persisted store.

Two properties of the gate matter when reading its verdicts. A mirror the suite cannot run green in would make every row `proven`, so a control row replays an unmutated mirror and must return `survived`. A row that passes because something other than its invariant failed proves nothing, so the gate requires a failing case to name the row's invariant, and rejects a row whose only failure is a crash.

The transport tables in `catalog.ts` are held to pi's baked catalog by invariant M8. Reconciling them on 2026-09-30 removed four ids the tables claimed (`minimax-m2.7`, `qwen3.6-plus`, `qwen3.7-max`, `qwen3.7-plus`), which pi carries as `openai-completions`. The tables only decide anything for an id pi does not carry, and where pi carries the id pi's entry wins.

That reconciliation leaves one risk open, stated here because no case can watch it. Of the four removed ids, only `qwen3.6-plus` is carried by pi's `opencode` catalog at all, and it is carried there as `anthropic-messages`; `minimax-m2.7` is `openai-completions` on that product and `qwen3.7-max` and `qwen3.7-plus` appear on neither. So if a future pi release drops `qwen3.6-plus` from `opencode-go` and no fresher persisted entry supplies it, the extension would serve it on `openai-completions` against the adapter the other product uses. Nothing in the suite notices, because the live layer only builds an entry for an id the earlier sources do not have, and pi has the id. The fix is a live probe of that id against both adapters, which needs a key and is not yet done.

The folder is not wired into `make test` yet. The roadmap row owns that, and it also owns adding the knowledge script to the `bash -n` smoke check, which currently covers only `tests/knowledge/`, `tests/integration/`, and `tests/eval/`.

## Local overrides

Nothing in this extension corrects a baked catalog's thinking behaviour, because a correction has to be per model and per product, and `none` is only safe where it has been measured. `models.json` `modelOverrides` is the layer for that, and it stays the top layer: pi applies it after this extension's list, so an override here still wins.
