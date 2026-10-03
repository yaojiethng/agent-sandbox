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

## The update and catalog state machine

The refresh path is three roles, not one: a **producer** that consults the declared sources and raises events, a **component** that holds the catalog state and applies them, and an **output** that turns state changes into what the user sees. Keeping the roles separate makes "nothing happened" and "something happened but was not applied" different observations, which is what the reporting defect turned on.

The vocabulary is the statechart one. A **state** is a named condition the component holds while no event is applied. An **event** is an input that can fire a transition. A **transition** is an edge from a source state to a target state. A **guard** is the condition on a transition that decides whether it may fire. An **effect** is what a transition does besides change the state. An **internal transition** fires without leaving its source state. An **ignored event** is an event no transition accepts where it arrives. A guard is not a gate: a guard decides one transition, while a gate is a pass-or-fail check over the test suite.

```text
                          SESSION START   or   /model
                                   |
                                   v
   ===========================================================================
   SYSTEM 1 - THE PRODUCER (THE FETCH DEVICE)                     (effectful)
   ===========================================================================

     the provider's declared sources, consulted in order:

       baked       -> the seed, never an event
       endpoint    -> received | failed | absent
       models.dev  -> received | failed | absent
       store       -> received(payload, lastModified = REMOTE PUBLISH time)
                      | failed | absent

       event :=  absent               (not consulted; an ignored event)
               | failed(reason)       (consulted, no answer)
               | received(payload)    (consulted, answered)

                      (provider-generic: source kind + payload + provenance,
                       no provider-specific fields)
                                   |
                                   v
   ===========================================================================
   SYSTEM 2 - THE COMPONENT (THE CATALOG STATE)                      (pure)
   ===========================================================================

     states:  S0  seeded    the baked seed, no source event applied (initial)
              S1  serving   the served catalog, built so far

     fold one declared source at a time, in order:

        S0,S1 -- X1  received(store payload)
        |            [isStoreNewerThanBaked false]
        |            / none                                     (internal)
        |
        S0   -- X2  received(store payload) [isStoreNewerThanBaked true]
        |            / union, first-wins per field                -->  S1
        |
        S0,S1 -- X3 received(endpoint | pi.dev payload)
        |            / union, first-wins per field; a new id appended  -->  S1
        |
        S1   -- X4  received(models.dev payload)
        |            / fill only the fields the served entry leaves undefined
        |                                                       (internal)
        |
        S1   -- X5  received(override payload)
        |            / fold in reverse declaration order, served order preserved
        |                                                       (internal)
        |
        S0,S1 -- X6  failed(reason)
        |            / none; the source contributes nothing     (internal)
        |
        S0,S1 -- X7  absent
                   / none                                       (ignored event)

        X2 guard: the store's REMOTE PUBLISH time is later than the installed
                  build's baked generatedAt                    <-- THE GATE
                                   |
                                   v
                        S_final = the served catalog
                                   |
   ===========================================================================
   SYSTEM 3 - THE OUTPUT (THE ACTION EMITTER)                        (pure)
   ===========================================================================

     event := (S_before, S_after, outcome)
        |
        +-- X8  unchanged and no failure  -----------> nothing
        |
        +-- X9  changed                    ----------> "updated catalog: +n / -n, m revised"
        |                              (+n/-n = id adds/removes by entry state,
        |                               m = same-id field revisions)
        |
        +-- X10 failed(reason)             ----------> "<source> failed: <reason>"
                                   |
                                   v
                    UI present?  -- yes --> ctx.ui.notify(line)
                                   |          startup refresh: held to session_start
                                   |          later refresh: emitted on completion
                                   |
                                   +-- no  --> console line (print/json/rpc modes)
```

The three lifecycle transitions sit outside the source fold and carry ids of their own. `X11` is the pre-session refresh: pi calls `refreshModels` once per provider before the session and before any UI exists (A14). `X12` is the failing-source narrowing: the live phase fails and the offline union stands rather than an empty catalog, which is X6's effect at the gather layer. `X13` is the pre-UI report hold: a report recorded before a UI exists is held and rendered at `session_start` (A13).

**The event is provider-generic.** It carries a source kind, a payload and provenance; no field is specific to `opencode-go`. The order sources are consulted in is the declaration's, not a constant here.

**The gate is a guard.** `isStoreNewerThanBaked` is the guard on X2 and nothing else. Its timestamp is the publish time pi.dev serves in `Last-Modified`, compared against the installed build's baked `generatedAt`, so it opens and closes on two clocks neither party controls jointly. It mirrors pi's own gate in `dist/core/remote-catalog-provider.js`, and the `agrees with pi` case holds that agreement.

**The announcement is a function of the served catalog's before/after state, never of the guard.** A refresh that changes the catalog announces while the guard is closed; a guard that moves without a catalog change announces nothing. Emitting the line from a source-count report instead is the defect this section exists to make unrepresentable.

**An event the component declines is not a failure.** X1 and X2 are both ordinary transitions, and the guard alone decides between them. Only a `failed` event announces as a failure, because a payload that was received and then declined is a guard decision, and a source that never answered is not.

**`catalog-change` is the full entry-state delta.** `+n` and `-n` count ids added and removed, and same-id field revisions are reported separately, because the defect this extension was built to repair - `space-bunny-free` served with `kimi-k2.6`'s context window, output limit and pricing - is a same-id revision with no id change at all.

**Nothing here is displayed permanently.** The reconciliation is relevant at catalog-update time, so the emitter is a one-shot `notify` and there is no persistent footer row. In `print`, `json` and `rpc` mode the console is the sink.

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

### Where this defect lives, and how to re-validate it

**Point-in-time finding, pi 1.0.0, 2026-10-03.** The defect sits at two levels at once, and neither is the family. pi's baked catalog carries `compat` and `thinkingLevelMap` per model entry, and the same model shape is duplicated under `opencode-go` and under `deepseek`; there is no provider-level compat block to fix. What differs between those two providers is the gateway, and the gateway is a property of the provider. `opencode-go` needs the disabled state as `reasoning_effort: "none"`, the default format's off value. The `deepseek` provider's own API needs the `deepseek` toggle. So the broken data is per model, the requirement that makes it broken is per provider, and the correction is a per-model override under the provider whose gateway needs it.

Two shapes break the disabled state on `opencode-go`, both in the baked map:

| Baked entry | pi builds, at `off` | Why it is wrong |
|---|---|---|
| no `off` key (`deepseek-v4-flash`, `-v4-flash-vision-exp`, `-v4-pro`) | `thinking: {type: "disabled"}` | an absent key counts as supported, so `off` survives and the deepseek toggle carries a disable signal this gateway ignores |
| `off: null` (`deepseek-v4.1-flash`) | `thinking: {type: "enabled"}` and `reasoning_effort: "low"` | `null` marks the level unsupported, so `off` clamps upward to `low` and turns thinking on |

The correction in force is the `opencode-go` `modelOverrides` block in `models.json`: it sets `compat.thinkingFormat: "openai"` and an explicit `off: "none"`, so pi sends `reasoning_effort: "none"`. `models.json` applies after any extension list, so it stays the top layer.

**To re-validate against a new pi**, build the payload locally; no network and no key are required. Drive the completions adapter with a stub `fetch` that refuses, and read the payload through `onPayload` at `reasoning: "off"`:

```js
const fields = ["thinking", "reasoning_effort", "reasoning", "enable_thinking"];
// A corrected model carries reasoning_effort: "none" and no thinking: {type: "enabled"}.
```

A fresh contributor validates in three steps: list the `opencode-go` ids whose baked `compat.thinkingFormat` is `deepseek`; build each at `off` and record which field carries the disable signal; then confirm each is covered by a `models.json` override that yields `reasoning_effort: "none"`. A model that yields `thinking: {type: "enabled"}` at `off` is a live defect, and the same probe says whether a new pi fixed the baked entry and the override can be dropped.

### `minimax-m2.7`: pinned to pi's baked value, untested

**Point-in-time note, 2026-10-03.** pi bakes `minimax-m2.7` over `openai-completions`, and models.dev names `@ai-sdk/anthropic` for it, so the transport derivation would move it to `anthropic-messages`. The difference could not be tested: the workspace's Go monthly quota is exhausted, every Go model answers `429 GoUsageLimitError` on both surfaces before the request body is read, and the free tier does not carry this model. Both surfaces route it, so neither is ruled out.

`transports` therefore pins the id to pi's baked value, `openai-completions`. Remove the pin once the quota resets and the surfaces can be compared: send one request to `/zen/go/v1/chat/completions` and one to `/zen/go/v1/messages`, each with the `x-opencode-session` header, and keep the surface that answers.

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
| A7 | `reasoning_effort: "none"` is accepted by some models and rejected by others, on both products, for a request format that emits an effort at all | 2026-10-03 | live probes; `knowledge_opencode_gateway_matrix.sh`. `space-bunny-free` returns 400 on both, `longcat-2.5-preview-free` accepts it on opencode-go; the 1.0.0 run split the same way, and the split is a gateway property, not a pi one. A format that emits no effort, such as the `deepseek` toggle, is outside this assumption's domain rather than a gap in it | the gateway, or the probe test turning red |
| A8 | ~~The Zen free tier answers 403 to any client that is not the OpenCode client, so a Zen free model cannot be probed from pi~~ **MOVED 2026-10-03.** The gateway no longer enforces the client check. pi still sends `x-opencode-client: pi` (`provider-attribution.js`, byte-identical to 0.99.2's), and a Zen free model answers 200 and completes a request. | 2026-10-03 | live probe of `space-bunny-free` on `opencode.ai/zen/v1`: 200 with the key, with pi's own client header, and with `x-opencode-client: opencode`; pi 1.0.0 answered `PONG` on the same model, and a bogus key still returns 401 | the gateway re-tightening the check |
| A9 | ~~The persisted pi.dev entry is newer than the baked data, so the store gate opens~~ **MOVED 2026-10-03, RE-MEASURED 2026-10-04.** The gate compares two clocks neither party controls jointly: `remoteModels` admits the persisted catalog only while its `lastModified` - the `Last-Modified` header pi.dev serves - is later than the installed build's baked `generatedAt`. It opens and closes as either side moves, so it is not a property of a pi version. | 2026-10-04 | the 1.0.0 baked manifest `generatedAt` is `2026-10-01T18:57:11.882Z`; on 2026-10-03 every store `lastModified` was older, so the probe took 0 overlay entries; on 2026-10-04 `~/.pi/agent/models-store.json` carries `lastModified` of `2026-10-03T16:16:56Z` to `2026-10-03T16:17:46Z` over openrouter, opencode-go, opencode and deepseek, all later than the build, so the gate is open for all four; a `lastModified` of `2026-12-01` restores them while it is closed | pi.dev republishing its catalog after the installed build reopens the gate, and a build newer than pi.dev's last publish closes it; the trigger is either party's clock, not a pi release |
| A10 | ~~`space-bunny-free` is absent from pi's baked `opencode-go` catalog and present in the persisted pi.dev entry~~ **MOVED 2026-10-03.** Both halves were already stale: the baked `opencode_go_default` in 0.99.2 and 1.0.0 both carry the model, and the store copy overlays it only while A9's gate is open. The store copy is redundant rather than wrong. | 2026-10-03 | the baked catalog holds 29 chat ids including `chat:space-bunny-free`; an offline `--list-models` with an empty agent dir lists it, and a mutated store `maxTokens` changes nothing under the real timestamps | a pi release that drops the model from the baked catalog |
| A11 | pi's `mergeModels` overlays by whole-entry replacement, which is the semantics `mergeCatalogs` copies | 2026-10-03 | the G2 case `agrees with pi` drives pi's own `withRemoteCatalog`, whose `getModels` calls `mergeModels`, and compares its output entry for entry with ours over replacement, append, cross-provider and stale-gate rows. Re-checked against 1.0.0, where `remote-catalog-provider.js` is byte-identical to 0.99.2's | a pi release changing the merge, the gate or the provider filter, which that case turns red |
| A12 | `mergeModels` is unreachable from an extension on 0.87.1, 0.99.2 and 1.0.0, so the copy is forced | 2026-10-03 | the installed 0.87.1 bundle and the 0.99.2 install under `/tmp/picheck/probe99`, and the 1.0.0 install under `/tmp/pi-1.0.0`: in all three the function is a module-local in `dist/core/remote-catalog-provider.js` with no `export` keyword, the 1.0.0 package entry names 156 exports with no `mergeModels`, and `package.json` publishes no subpath that reaches it | a pi release that exports `mergeModels` from a published subpath or from a package entry |
| A13 | A TUI session reaches an extension's `session_start` handler with a usable `ctx.ui`, and `ctx.mode` reads `tui` there | 2026-10-03 | `ExtensionHandler` and the `session_start` overload in pi's `dist/core/extensions/types.d.ts`, which type the handler's second argument as `ExtensionContext` carrying `ui: ExtensionUIContext` and `mode: ExtensionMode`; re-checked against a live 1.0.0 TUI under a pty, where the handler saw `mode: "tui"`, `hasUI: true`, and mounted a dialog | pi dropping `ui` from `ExtensionContext`, or `session_start` firing before the interactive TUI mounts |
| A14 | `refreshModels` runs before any extension UI exists, so its output cannot be rendered as it happens | 2026-10-03 | `ModelRuntime.registerProvider` calls `void this.refresh(...)` without awaiting, and `ModelRuntime.create` awaits its refresh before the session is built; both complete before `InteractiveMode.init` mounts the TUI, which is the first thing that owns a UI. Re-checked against 1.0.0, where the ordering is unchanged | pi awaiting a provider refresh after the TUI mounts, which would make the working message observable on the first refresh and retire this row |

## Where the output goes

The extension writes nothing to the console in TUI mode. The TUI owns the terminal, and a line written behind its back lands inside the rendered frame; the operator reported exactly that, with every line after the extension's own output drawn against the wrong frame.

`refreshModels` records the per-source counts as data (`CatalogReport`) and `report.ts` renders them into pi's UI: a persistent `setStatus` footer row carrying the one-line reconciliation, and a `notify` on completion that carries the same line plus any source failure. A source that was not reached is named `skipped` rather than `0`, so a line never reads as a source that answered with nothing.

The rendering happens on `session_start`, because that is the first event carrying a UI. A consequence worth stating: the "Refreshing model catalogs..." working message cannot be shown for the startup refresh, which completes before the TUI mounts (A14). It is shown for a refresh that happens later, such as a `/model` change or a reload. Closing that gap needs pi to surface a pre-TUI notification, not an extension change.

In `print`, `json` and `rpc` mode there is no frame to corrupt, so the console stays the sink there. `ctx.mode` is the discriminator, not a guess.

## The default model and the scope order

`enabledModels` in `settings.json` is a list of glob patterns, and `resolveModelScopeFromModels` walks it in order, appending matches and deduplicating as it goes. The first entry therefore becomes `scopedModels[0]`, which is the model a session starts on when the scope outranks the saved default, and the first model the cycle key moves to. The order is load-bearing, and neither pi's settings schema nor `/scoped-models` says so.

A non-empty scope also outranks the saved default. `findInitialModel` in `dist/core/model-resolver.js` returns `scopedModels[0]` on any non-empty scope without consulting `defaultProvider` or `defaultModel`, and sets `fallbackMessage: undefined` on that path, so the field that exists to report a discarded preference is silent exactly where a preference is discarded. The shipped `settings.json` therefore puts the configured default's provider and id at the head of `enabledModels`; that is a mitigation, and `tests/knowledge/knowledge_pi_config_cycle.sh` fails when the head stops naming it. The defect is reported upstream in [`20261002-report-draft-default_model_resolution_bug.md`](../../../../../../../../devlog/discussions/20261002-report-draft-default_model_resolution_bug.md).

The extension does not correct the selection. It supplies the catalog the resolver reads, and at `session_start` it can compare `ctx.model` against the saved default the scope resolved and announce a discard; it does not call `ctx.setModel`, because that would put pi's resolution ladder inside an extension and would disturb a resumed session's model, a `--model` override and the cycle key alike.

## Wanted from pi

Two surfaces would let this extension put its state where the operator looks, and neither is reachable from an extension today. Both are pi feature requests, recorded here so they are not re-derived.

- **A provider-supplied refresh status line.** `ModelSelectorComponent` renders `Refreshing model catalogs...`, `Model catalogs refreshed.` and `Could not refresh model catalogs: <error>` from private literals. `RefreshModelsContext` carries `credential`, `stored`, `publish`, `allowNetwork`, `force` and `signal` with no status channel, and `ModelsRefreshResult` carries only `aborted` and `errors`, so a provider can influence that line only by throwing, which would turn a reconciliation detail into a refresh failure.
- **A per-model display badge.** A picker row renders the model `id`, a `[provider]` badge and an optional `default` badge. A model's `name` appears only in the `Model name:` detail line, and neither `Model` nor `ProviderModelConfig` carries a badge, tag or suffix field, so a provider cannot mark one of its own models in the list. Decorating the `name` reaches the detail line only, and decorating the `id` changes identity, which search, resolution, scoping, `enabledModels` and `defaultModelPerProvider` all match on.

## Open, not established

Three probes need a key or a quota the workspace does not have. Each is a deferred knowledge test: it is resolved by the next reader who can run it, and none of them blocks a decision here.

- **`kimi-k2.6` is unreachable with this key on both products**, answering 403 `Model access is disabled`. Its defect class therefore rests on the built payload for its exact baked compat block, not on a live response. The same limit applies to every other model the account cannot reach, which is most of the Zen catalog: only `space-bunny-free` was reachable there.
- **A7's `glm-5.3-flash` case is quota-blocked.** A7 claims some models accept `reasoning_effort: "none"` and others reject it; `space-bunny-free` returns 400 on both products and `longcat-2.5-preview-free` accepts it on `opencode-go`, so the split is real but its second data point is unmeasured. A format that emits no effort at all, such as the deepseek toggle, is outside A7's domain rather than a gap in it.
- **`qwen3.6-plus` needs a live probe against both adapters.** If a future pi release drops it from `opencode-go` and no fresher persisted entry supplies it, the extension would serve it on `openai-completions` against the adapter the other product uses, and nothing in the suite notices. The probe is one request to each surface; see `## Invariants`.

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
| `invariants.ts` | the invariant catalog: one named statement per invariant, the state/transition/guard classification, the transition table, the totality check, and the per-source and per-level cases derived rather than listed |
| `invariants.test.ts` | one case per catalog entry, over the real product surface, plus the machine-run totality check, printing the invariant report |
| `mutation/catalog.ts` | one row per deliberate break of the extension, each naming the invariant it attacks |
| `mutation/runner.ts` | the replay engine: a temp mirror per row, one child process, the six verdicts |
| `mutation.test.ts` | the gate: a control row, an attribution check, and a `proven` verdict per row |
| `knowledge/knowledge_opencode_gateway_matrix.sh` | knowledge, live: per-model acceptance of the disabled effort; needs a key |

## Invariants

`invariants.ts` names what must hold, and `invariants.test.ts` holds each one with a case; the report prints one line per case and a red line reads as an invariant id. `mutation/catalog.ts` then asks the other question, whether a green suite is evidence: each row is a defect the design rejects, and the gate fails unless the suite turns red against it. The gate is what turned up the two survivors a green suite once hid, a served entry with a zero context window and an empty baked catalog that dropped the persisted store.

Every invariant is one of three classes, and the class states what the invariant constrains. A **state invariant** holds whenever the component is at rest. A **transition invariant** holds of one firing of a transition. A **guard invariant** holds of one guard. An invariant that fits none of the three is not an invariant, and is rewritten or dropped.

| Class | Invariants |
|---|---|
| state | M1, M3, M4, M5, M7, M8, L1, C1, C2, C4, T1, T2, T3 (both cases), N1, N2, R1 |
| transition | U1, U2, U3, U4, G2 (all three cases), M2, M6, L2, L3, L4, L5, T4, W1, D1 |
| guard | G1, G3, C3 |

`invariants.ts` carries that classification as data, in `CLASSIFICATION`, and carries the machine itself in `STATES` and `TRANSITIONS`, one entry per named transition with its event, its source states and its guard. A machine-run totality check then asserts what the enumeration's completeness rests on: every catalog case is classified, no classification is stale, every state and transition the record names is held by a case or carries a reason, and every edge a case names exists. It also applies the sixth rule, that no state has two transitions on one event whose guards both hold, which for a shared event means the guards are distinct. A case may point outside the catalog machine, at the declaration parser (`DECL`), the built request payload (`WIRE`) or the suite's own bijection (`HARNESS`); those edges are named in `EXTERNAL_EDGES`.

Two properties of the gate matter when reading its verdicts. A mirror the suite cannot run green in would make every row `proven`, so a control row replays an unmutated mirror and must return `survived`. A row that passes because something other than its invariant failed proves nothing, so the gate requires a failing case to name the row's invariant, and rejects a row whose only failure is a crash.

Every invariant holds a row in that catalog except R1. R1 is the bijection between the catalog and the test file, so a mutation of it mutates the gate: the row would change the structure that decides the verdict rather than a product line the suite could catch. The exemption is recorded here rather than paid for with a row that would prove nothing.

The transport tables in `catalog.ts` are held to pi's baked catalog by invariant M8. Reconciling them on 2026-09-30 removed four ids the tables claimed (`minimax-m2.7`, `qwen3.6-plus`, `qwen3.7-max`, `qwen3.7-plus`), which pi carries as `openai-completions`. The tables only decide anything for an id pi does not carry, and where pi carries the id pi's entry wins.

That reconciliation leaves one risk open, stated here because no case can watch it. Of the four removed ids, only `qwen3.6-plus` is carried by pi's `opencode` catalog at all, and it is carried there as `anthropic-messages`; `minimax-m2.7` is `openai-completions` on that product and `qwen3.7-max` and `qwen3.7-plus` appear on neither. So if a future pi release drops `qwen3.6-plus` from `opencode-go` and no fresher persisted entry supplies it, the extension would serve it on `openai-completions` against the adapter the other product uses. Nothing in the suite notices, because the live layer only builds an entry for an id the earlier sources do not have, and pi has the id. The fix is a live probe of that id against both adapters, which needs a key and is not yet done.

The folder is wired into `make test` through `tests/test_model_refresh.sh`, which runs the node suite in one process and guards the file list: a new node test file that the wrapper does not name fails the guard. The extension's knowledge script is syntax-checked by `scripts/check_test_smoke.sh`, which now reaches `tests/extensions/**/knowledge/` in addition to `tests/knowledge/`, `tests/integration/` and `tests/eval/`.

## Local overrides

Nothing in this extension corrects a baked catalog's thinking behaviour, because a correction has to be per model and per product, and `none` is only safe where it has been measured. `models.json` `modelOverrides` is the layer for that, and it stays the top layer: pi applies it after this extension's list, so an override here still wins.
