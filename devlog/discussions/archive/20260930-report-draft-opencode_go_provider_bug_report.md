# opencode-go provider bug report

Environment: `@earendil-works/pi-coding-agent` 0.99.1, Linux x64, Node 22.22.3. Measurements in findings 1 to 3 were taken against that build. Findings 4 and the [Version drift](#version-drift) section were first taken against 0.87.1 and have moved; they are labelled.

The summary: pi ships a frozen catalog for the OpenCode Zen gateway and never refreshes it during normal use, so the catalog falls behind the endpoint. For `opencode-go` it is currently 14 of 43 models behind. When a user names one of the 14, pi does not say the catalog is stale -- it answers confidently, either with the requested id carrying another model's limits, reasoning levels and price, or with a different model entirely and no warning at all.

## Finding 1: model catalogs are never refreshed on a normal path

```js
// dist/core/model-runtime.js:95
const refreshFromNetwork = runtime.modelNetworkEnabled && options.allowModelNetwork === true;
```

No call site in `dist/` passes `allowModelNetwork: true`. There are five `ModelRuntime.create` call sites, and they split in two:

```text
dist/core/sdk.js:74                     ModelRuntime.create({ authPath, modelsPath })
dist/core/agent-session-services.js:57  ModelRuntime.create({ authPath, modelsPath, signal })
dist/main.js:130                        ModelRuntime.create({ allowModelNetwork: false, signal })
dist/package-manager-cli.js:515         ModelRuntime.create({ allowModelNetwork: false, ... })
dist/cli/auth-check.js:43               ModelRuntime.create({ allowModelNetwork: false, ... })
```

The three that pass `false` are credential commands: `pi auth print-api-key`, the package manager, and `pi auth check`. **The two that build a session pass nothing at all**, and they are the ones that matter. With `allowModelNetwork` undefined, `options.allowModelNetwork === true` is false and no session refreshes a catalog.

The only two `allowNetwork: true` refresh sites in the bundle are `pi update --models` and the llama.cpp catalog sync, and `pi update --models` builds its own model runtime without loading extensions. So a built-in provider's catalog is as current as the last time someone ran `pi update --models`, and it cannot be brought forward from within a session. Everything below is a consequence.

**This is an unwired default, not a policy.** `docs/cli.md:239` documents `--offline` as "Disables automatic network activity, including model catalog refreshes", and `docs/environment-variables.md:84` says the same of `PI_OFFLINE`. A user reading either believes catalog refreshes happen normally and that offline mode is the switch. The flag exists, is evaluated on every session, and has no setter anywhere.

### The obvious fix does not work, and it fails for exactly the users who hit this

Wiring the session paths to `allowModelNetwork: true` is necessary and not sufficient. `pi-ai`'s `Models.refresh` returns before the network phase unless a provider credential resolves:

```js
// pi-ai dist/models.js
const credential = await this.resolveRefreshCredential(provider, storedCredential, signal);
if (!credential) return;
await this.runProviderRefreshPhase(provider, credential, true, options.force, generation, signal);
```

So the refresh runs only for providers whose credential is already available. A user with no `OPENCODE_API_KEY` configured -- who is precisely the user whose catalog is stale, and who is looking at `--list-models` to work out which models they can call -- gets no refresh at all.

This has a consequence for how the fix must be verified, and it is the easiest way to ship a broken fix: a patch that defaults the flag to true will appear to work on any machine where a provider key happens to be present, and will do nothing on a machine without one. **Every check of this fix must run with the provider credentials absent from the environment.** See [Verifying a fix](#verifying-a-fix).

Whether the credential gate itself is the right gate is a design question worth settling explicitly rather than by accident: it is reasonable that pi should not make authenticated requests for a provider the user has not configured, and it is also reasonable that a user with no key should be able to see which models a provider offers. Either answer is defensible; the current one is unstated.

### The fix

The gate is in pi-ai, so the fix is an **anonymous read of the endpoint's id list**, plus the flag flip. Flipping the flag alone does nothing, because the network phase is unreachable without a credential.

New file, `dist/core/anonymous-model-catalog.js`. The whole surface is four exports:

```js
export const ANONYMOUS_MODEL_LIST_URLS = { "opencode-go": "https://opencode.ai/zen/go/v1/models" };
export function hasAnonymousModelList(providerId) { /* is this provider mapped above */ }
export async function fetchAnonymousModelIds(providerId, options = {}) { /* GET, ids only, cached, bounded */ }
export function clearAnonymousModelIdCache() { /* cache eviction */ }
```

**Hand-editing the shipped binary is a second copy, not a second entry point.** `dist/core/` and `dist/bundle/` are independent copies of the same code. The `pi` binary reads only `dist/bundle/`, so a fix applied to `dist/core/` alone passes every test written against `dist/` and still ships a binary without the fix.

There is no module registry to update. `dist/bundle/index.js` is a barrel that re-exports symbol names from `./chunks/chunk-*.js`; it never names a module file, and core module names such as `model-runtime` and `model-resolver` appear nowhere in it or in any chunk filename. There is no `dist/bundle/index.d.ts`. Adding one would be a new file that nothing reads.

So the second copy is made the only way it can be: mirror the changed code into the chunk that already contains the code calling it, and declare the module in `dist/core/<name>.d.ts` plus `dist/index.d.ts` for the SDK entry. Confirm the result by running the binary, not by reading `dist/`:

```bash
node dist/bundle/cli.js --version   # must print the version, not throw
grep -rl '<the marker your fix introduces>' dist/bundle/chunks/
```

An earlier revision of this report told readers to name the new module in `dist/bundle/index.js` and to declare it in `dist/bundle/index.d.ts`. Both instructions are impossible on this build, and four independent attempts and five independent implementations disagreed with them in the same way.

Three properties are not optional, and each was learned the hard way:

- **No credential is sent.** The request is anonymous and returns ids only. It is what lets a user with no key see the gap.
- **It never changes the model list.** It reports a gap; it does not synthesise models. The gateway publishes only `id`, `object`, `created` and `owned_by` -- no price, no context window, no reasoning map -- so there is nothing to build an entry from, and any attempt to invent one is fabrication.
- **It is bounded and it does not block the UI on a dead endpoint.** `fetchAnonymousModelIds` carries a per-attempt timeout with retries; `ModelRuntime.create` supplies a session-level `AbortSignal` when the caller passed none.

`dist/core/model-runtime.js`, inside the static `ModelRuntime.create` (line 116 in 0.99.1):

```diff
-        const refreshFromNetwork = runtime.modelNetworkEnabled && options.allowModelNetwork === true;
+        const refreshFromNetwork = runtime.modelNetworkEnabled && options.allowModelNetwork !== false;
+        runtime.catalogRefreshEnabled = refreshFromNetwork;
```

The two session call sites -- `dist/core/sdk.js:74` and `dist/core/agent-session-services.js:57` -- pass no flag and now inherit the default. `dist/main.js:130`, `dist/package-manager-cli.js:515` and `dist/cli/auth-check.js:43` already pass `false`; leave them, and pass `false` to the anonymous fetch at the credential commands too, so `pi auth` never touches the network.

### Traps

- **`readonly` in a `.d.ts` may only be assigned in the declaring constructor.** `ModelRuntime.create` is static, so `runtime.catalogRefreshEnabled = ...` above is `TS2540` on a rebuild from source. Either declare the fields without `readonly`, or set them through a setter.
- **Do not read `modelRuntime.modelNetworkEnabled` from new code.** It is declared `private` in `dist/core/model-runtime.d.ts`. It works at runtime, so nothing fails, and a rebuild rejects the line.
- **Widen the `PI_OFFLINE` gate everywhere, or nowhere.** It was `process.env.PI_OFFLINE === undefined`. If you widen `isOfflineModeEnabled` in `model-runtime.js` to accept `0`/`false`/`no`, then these five also test truthiness and must widen with it, or `PI_OFFLINE=false` means "catalog refresh on, everything else off":
  - `dist/utils/version-check.js`
  - `dist/modes/interactive/interactive-mode.js`
  - `dist/modes/interactive/bug-report.js`
  - `dist/extensions/llama/index.js`

  Widening all five plus the helper is the coherent change. Widening the helper alone is worse than either alternative. If you will not widen them all, leave the helper as `=== undefined` and delete the `0`/`false`/`no` claim from `docs/environment-variables.md:84`. Do not leave the doc claiming a value the code does not honour.
- **A command that documents itself as doing no network will now do network.** `--list-models` builds its runtime through a path that passed no flag. Once the flag defaults on, an unauthenticated pi.dev response can override `contextWindow` and `maxTokens` on entries it did not previously touch, so the command's output changes between invocations. Either keep the listing path on `false`, or accept it, bound it, and say so.
- **Do not let start-up block for the whole budget.** Bounded is not the same as fast: with the endpoint hanging, `pi --help` measured 15.2 s against 227 ms before the change, all of it before the UI appears. If that is unacceptable, do the anonymous read after the session is up.

## Finding 2: the opencode-go catalog is behind the endpoint

The gateway publishes its model list without a credential. Pi's built-in catalog does not have it.

```bash
node --input-type=module -e '
import { getBuiltinModels } from "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/all.js";
const live = (await (await fetch("https://opencode.ai/zen/go/v1/models")).json()).data.map((m) => m.id).sort();
const baked = new Set(getBuiltinModels("opencode-go").map((m) => m.id));
console.log("gateway:", live.length, "pi:", baked.size);
console.log("on the gateway, absent from pi:", live.filter((id) => !baked.has(id)).join(", ") || "none");
'
```

```text
gateway: 43 pi: 29
on the gateway, absent from pi: deepseek-flash, glm-5, glm-5.1, grok-4.5,
hy3-preview, kimi-k2.5, kimi-k2.6, mimo-v2-omni, mimo-v2-pro, minimax-m2.5,
omen-alpha, qwen3.5-plus, qwen3.6-plus, qwen3.7-max
```

Nothing in pi surfaces this. `pi --list-models opencode-go` lists 29 models and does not say the endpoint has 43.

The persisted pi.dev catalog does not close the gap either. On this installation the stored `opencode-go` entry and the built-in catalog carry the same 29 ids, and `remoteModels` only applies the stored entry when its `lastModified` is newer than the built-in data's generation timestamp:

```js
// dist/core/remote-catalog-provider.js
function remoteModels(entry, localGeneratedAt) {
    if (!entry) return [];
    if (localGeneratedAt !== undefined && (entry.lastModified === undefined || entry.lastModified <= localGeneratedAt)) return [];
    return entry.models;
}
```

So the two mechanisms that are supposed to keep a catalog current -- the built-in data and the pi.dev overlay -- are both behind the endpoint. **Note that `pi update --models` does not close this gap.** It refreshes from pi.dev, and pi.dev currently serves the same 29 ids for `opencode-go` that the built-in catalog carries, while the endpoint serves 43. It also refreshes a provider only when that provider's credential resolves. Neither the built-in data nor the user-facing command reaches the 14.

## Finding 3: an id the catalog lacks is answered with another model's metadata

`buildFallbackModel` clones the provider's default model and overwrites only `id` and `name`:

```js
// dist/core/model-resolver.js
function buildFallbackModel(provider, modelId, availableModels) {
    const providerModels = availableModels.filter((m) => m.provider === provider);
    if (providerModels.length === 0) return undefined;
    const defaultId = defaultModelPerProvider[provider];
    const baseModel = defaultId
        ? (providerModels.find((m) => m.id === defaultId) ?? providerModels[0])
        : providerModels[0];
    return { ...baseModel, id: modelId, name: modelId };
}
```

### The fallback itself is reasonable, and this report does not propose removing it

If a user addresses a custom id that pi has never heard of, building a model from the provider's default is a sensible convenience, and pi does warn. The defect is not the existence of a fallback. It is that **pi cannot distinguish a custom id from a real model it has not catalogued**, and the two are not remotely equal in volume: 14 of this gateway's 43 models are in the second class.

Three behaviours, all reachable from vanilla pi with no extension and no `models.json`:

```js
import { getBuiltinModels } from "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai/dist/providers/all.js";
import { resolveCliModel } from "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/model-resolver.js";

const baked = getBuiltinModels("opencode-go");
const modelRuntime = { getModels: () => baked.map((m) => ({ ...m })) };
for (const id of ["glm-5", "glm-5.1", "deepseek-flash"]) {
  const r = resolveCliModel({ cliProvider: "opencode-go", cliModel: id, modelRuntime });
  console.log(id, "->", r.model?.id, r.model?.cost, r.warning ?? "(no warning)");
}
```

```text
glm-5           -> glm-5.3-flash   undefined        (no warning)
glm-5.1         -> glm-5.1         {"input":3,"output":15,"cacheRead":0.3,"cacheWrite":0}
                                Model "glm-5.1" not found for provider "opencode-go". Using custom model id.
deepseek-flash  -> deepseek-flash  {"input":3,"output":15,"cacheRead":0.3,"cacheWrite":0}
                                Model "deepseek-flash" not found for provider "opencode-go". Using custom model id.
```

**3a. Partial match with no warning.** `glm-5` is a real model on the gateway. `parseModelPattern` resolves it to `glm-5.3-flash`, a different model, and returns no warning at all. The user asked for one model and silently received another. This is not the fallback path and no part of finding 1's warning covers it.

**3b. The donor's price and reasoning levels.** For the other 13, the returned entry carries the requested id and `kimi-k3`'s everything else: `contextWindow` 1048576, `maxTokens` 131072, `cost {input: 3, output: 15, cacheRead: 0.3}`, `thinkingLevelMap {off: null, minimal: null, low: null, medium: null, high: null, xhigh: null, max: "max"}`. Three consequences:

- pi's own token accounting is wrong for the session. `$15` per million output tokens is `kimi-k3`'s price, reported for `deepseek-flash`.
- `--thinking xhigh` clamps to the highest level `kimi-k3` advertises, which is `max`, not the requested model's ceiling.
- If the real model's context window is smaller than 1048576, pi will build a request the endpoint rejects, and the resulting error will name the gateway rather than the stale catalog.

**3c. The warning describes the wrong thing.** "Using custom model id" reads as pi inventing an identifier the user chose. What happened is pi finding its catalog short and substituting another model's metadata and price. A user reading it has no reason to suspect the numbers.

### The fix

Three pieces, in this order. The second carries finding 3a and is the one with the load-bearing line.

**1. Report the gap instead of guessing from it.** With the anonymous read from finding 1, pi can ask the endpoint whether an id is real before it invents anything. `dist/core/model-resolver.js`, after `resolveModelScopeFromDiagnostics` returns:

```js
function nameCatalogGaps(diagnostics, modelRuntime) {
    if (typeof modelRuntime?.getKnownModelIds !== "function" || typeof modelRuntime?.getCatalogGaps !== "function")
        return diagnostics;
    const isListed = (providerId, modelId) =>
        modelRuntime.getKnownModelIds(providerId)?.some((id) => id.toLowerCase() === modelId.toLowerCase()) === true;
    const kept = [];
    for (const diagnostic of diagnostics) {
        if (diagnostic.code === "partial-match") {
            if (!isListed(diagnostic.provider, diagnostic.pattern)) {
                // A prefix the endpoint does not list: the substitution is the answer.
                continue;
            }
            kept.push({ ...diagnostic, code: "stale-catalog", message: /* name the model and provider, say the catalog is behind */ });
        } else kept.push(diagnostic);
    }
    return kept;
}
```

That `!isListed(...)` polarity is the whole rule, and getting it backwards is invisible: the warning then fires on every ordinary prefix and stays silent on the real defect. One attempt shipped exactly that inversion into the bundled binary, where `node --check` cannot see it. Assert both directions -- a prefix the endpoint does not list produces no diagnostic, an id it does list produces `stale-catalog` -- or it will ship.

**2. Make the substitution honest.** `dist/core/model-resolver.js:130`, the return of `buildFallbackModel`:

```diff
     return {
-        ...baseModel,
-        id: modelId,
-        name: modelId,
+        model: {
+            ...baseModel,
+            id: modelId,
+            name: modelId,
+            // A price is a fact about the donor, not about the model the user asked for.
+            // The donor's thinking level map is kept: an absent map reads as "every level
+            // supported", which offers efforts the donor's family rejects.
+            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
+            thinkingLevelMap: { ...baseModel.thinkingLevelMap },
+        },
+        substituted: true,
     };
```

The `thinkingLevelMap` line is why this finding has been fixed twice and regressed once. `getSupportedThinkingLevels` filters a level out only when the map says `null`, so **deleting the map makes every level supported**:

```text
                       donor map (kimi-k3)   map deleted
getSupportedLevels     ["max"]               ["off","minimal","low","medium","high"]
clamp("minimal")       max                   minimal
clamp("xhigh")         max                   high
```

The request builder sends `model.thinkingLevelMap?.[effort] ?? effort`, so with the map gone pi stops sending the one effort the family accepts and starts sending efforts it rejects. Inherit the donor's map; never remove it. Assert it directly rather than by eye:

```js
import { getSupportedThinkingLevels, clampThinkingLevel } from "@earendil-works/pi-ai";
const m = substituted.model;
assert.ok(m.thinkingLevelMap, "an absent map makes every level look supported");
assert.deepEqual(getSupportedThinkingLevels(m), ["max"]);
assert.equal(clampThinkingLevel(m, "xhigh"), "max");
```

**3. Carry the signal as a flag, not a string.** `buildFallbackModel` returns `substituted: true` above. `dist/cli/credential-print.js` selects on the literal text `resolved.warning?.includes("Using custom model id")`, so rewording the warning -- which this report asks for -- makes that branch *accept* substituted models, reintroducing through the recommended route the very problem the change fixes. Replace the string test with the flag, and apply it in **both** branches: one refuses a substituted model, the other currently accepts it.

Deleting `buildFallbackModel` entirely is also defensible: no shipped doc, changelog entry or code path depends on the custom-id convenience. It is listed last because it removes a capability rather than correcting one.

### Traps

- **The resolver must become awaitable to verify anything, and `resolveCliModel` is exported and synchronous.** Making it `async` is a public API break, and returning a promise from it makes every third-party caller read `resolved.model` as `undefined`. Add a new async function beside it, move the in-tree callers over, export both, and leave the synchronous primitive with the corrected metadata and the flag.
- **There is a second call path.** `resolveModelScopeFromDiagnostics` backs `--models` and the settings-driven `enabledModels`, and it does not go through the CLI resolver. Fixing only `--model` leaves a settings-driven session substituting silently. Fix both, or say which one is fixed.
- **A substitution warning must not swallow a `:level` suffix.** `parseModelPattern` drops the suffix whenever the inner recursion produced any warning, so a naive "make 3a warn" turns `--model glm-5:high` into a silent loss of `high`. Carry the substitution on a separate field and let only an invalid-level warning suppress the level.
- **`--model kimi` is not an incident.** A prefix that legitimately matches is an answer. Reuse the same `isListed` test in the CLI resolver so `--model` and `--models` agree; otherwise one path warns on every start-up and the other never does, and the real defect class is still not distinguished in either.
- **Every call site needs a `signal`.** One in-tree site passes none, so its new network call is bounded only by the helper's own timeout.
- **Give the id-list cache a bound.** An unbounded `Map` keyed by provider is harmless in a CLI and a slow leak in a long-lived SDK host.
- **A required `substitution: boolean` in the `.d.ts` is a lie.** The no-model return path omits the field, so declare it optional.

### Behaviour this fix will change, whether or not it should

Listing these in advance is cheaper than being surprised by them in review. Each was a genuine surprise the first time this was attempted.

- `--model <fragment>` starts printing a warning.
- A substituted model reports a price of zero rather than the donor's, so cost displays change.
- `pi auth check --model <id-not-in-catalog>` returns `invalid` and exits non-zero.
- A session start reaches the network unless `PI_OFFLINE` is set, which changes start-up timing for SDK callers.
- An extension can no longer narrow a built-in provider's catalog: a legacy `ProviderConfig` that published one model over `opencode-go` used to hide the other 28 and will now show all of them. There is no narrowing mechanism left on that path. This is a real break for any extension that relied on the documented replacement, and it is the price of the fix below.

## Finding 4: an extension's `refreshModels` replaces the catalog rather than extending it

This one needs a registered extension and does **not** occur in vanilla pi: `dist/core/model-runtime.js:155` returns the built-in untouched when there is no extension and no `models.json` entry. It is included because the composition path has the same character of defect, and because `docs/custom-provider.md` documents the behaviour as intended.

`applyExtension` maps over the extension's list and returns only what it contains, so the persisted pi.dev catalog is discarded:

```js
// dist/core/provider-composer.js
function applyExtension(providerId, models, config) {
    if (!config) return [...models];
    if (!config.models) {
        return config.baseUrl ? models.map((model) => ({ ...model, baseUrl: config.baseUrl })) : [...models];
    }
    return config.models.map((definition) => extensionModelFromDefinition(providerId, models, config, definition));
}
```

The fix is to merge onto the already-composed list with pi's own `mergeModels`, inside `applyExtension` and after the `models.json` layer:

```js
// dist/core/provider-composer.js, applyExtension
    // baseUrl and models are independent, so the models branch keeps each composed
    // model's own endpoint and only repoints what the extension defines.
    return mergeExtensionModels(models, config.models.map((definition) => extensionModelFromDefinition(providerId, models, config, definition)));
```

`mergeExtensionModels` should overlay each extension entry onto the base entry with the same id and model type, rather than replacing it, so an extension redefining a built-in model with a partial entry keeps the fields it omits. `mergeModels` already implements the id-plus-type key; if you reuse it directly, the replacement is total and a colliding id silently loses `name`, `cost`, `maxTokens` and `input`, which the documented contract ("an entry whose id matches an existing model replaces it") does not say.

Three traps, each of which was hit while fixing this on 0.99.1:

- **Do not merge in the refresh block.** `currentExtension()` substitutes `refreshedExtensionModels` back in as `extension.models` on the next `getModels()`, so `applyExtension` returns exactly that list and the merge is discarded.
- **Do not hoist the `baseUrl` rewrite above the `models` branch.** `baseUrl` and `models` are independent optional fields, so `{baseUrl, models}` is legal; hoisting repoints the entire retained catalog to the extension's endpoint. The rewrite belongs where it already is, in the no-`models` branch.

The first prerequisite is that `mergeModels` is not exported. On 0.99.1 `dist/core/remote-catalog-provider.js:19` is `function mergeModels(baseline, dynamic) {` with no `export`, and `remote-catalog-provider.d.ts` declares only `REMOTE_CATALOG_REFRESH_INTERVAL_MS`, `REMOTE_CATALOG_MODEL_TYPES` and `withRemoteCatalog`. Add the export and the declaration before the patch applies. Separately, the package `exports` map publishes no subpath under `dist/` and `dist/index.js` does not re-export it, so a third-party extension still cannot import it either way; re-exporting from `dist/index.js` would let extensions compose against the real thing instead of copying it.

Separately, `docs/custom-provider.md` says "Pi replaces that registration's live models with the returned list" and `ProviderConfig.models` says "If provided, replaces all existing models for this provider." The behaviour was written down as intended, which is why an author reading the docs would correctly conclude that omitting `models` is what makes an extension safe.

## Version drift

Findings 1 to 3 were re-measured on 0.99.1 and are current. Finding 4 and the notes below were first measured on 0.87.1:

| Claim | Status on 0.99.1 |
|---|---|
| `opencode-go` is 14 of 43 behind | **Current.** Re-measure with the command in finding 2; the numbers move as the gateway moves. |
| `defaultModelPerProvider["opencode-go"] = "kimi-k2.6"`, with 262144 / 65536 / cost 0.6-2.5 | **Stale.** The default is now `kimi-k3`, with `contextWindow` 1048576, `maxTokens` 131072, `cost {input: 3, output: 15, cacheRead: 0.3}`. Read the donor from the code. |
| `opencode-go` 30 served, 33 without the extension, 3 store-only ids | **Stale.** Built-in and stored catalogs now carry the same 29 ids. |
| `opencode` 77 stored against 73 built-in | **Stale.** Now 78 against 77. |
| `openrouter` 398 stored against 386 built-in | **Stale.** Now 398 against 398. |
| `mergeModels` is not exported | **Unchanged, and still true on 0.99.1.** `remote-catalog-provider.js:19` has no `export` and the `.d.ts` does not declare it. A patch that calls it from another module must add the export first. |
| Built-in data is keyed `api -> id` | **Stale.** Now `chat:<id>`, `image:<id>`, `classifier:<id>`. Use `getBuiltinModels(providerId)` rather than reading `dist/providers/data/*.json`. |
| `applyExtension` quoted in full | **Essentially unchanged.** It is at `provider-composer.js:171` with the body quoted here; only the per-definition builder it calls was extracted to `extensionModelFromDefinition`. The patch above applies against it. |
| `mergeModels` matches on `entry.id === model.id` | **Changed** to match on model type as well, and `withRemoteCatalog` additionally filters `dynamicModels` to chat before merging. |
| `allowModelNetwork` never true | **Unchanged**, and worse than it looks: pi-ai gates the network phase on a resolvable provider credential, so the flag alone fixes nothing for a keyless user. See finding 1. |

## Verifying a fix

**Run every check below with the provider credentials absent from the environment.** This is not a formality. `pi-ai` returns before the network phase unless a provider credential resolves, so a fix for finding 1 that is verified only with a key present will appear to work and will do nothing for the users this report is about. Strip them and re-run:

```bash
env -u OPENCODE_API_KEY -u OPENROUTER_API_KEY -u DEEPSEEK_API_KEY \
    -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u GOOGLE_API_KEY \
    -u ANTHROPIC_TOKEN -u OPENROUTER_API_KEY_BASE \
    node repro1.mjs
```

If a script needs a network, it should reach the endpoint anonymously; none of these checks should require a key.

For finding 1 and 2:

1. With credentials absent, a session start still refreshes at least one catalog. If it does not, the fix has only been verified on a machine with a key.
2. The id set from `https://opencode.ai/zen/go/v1/models` and the id set from `getBuiltinModels("opencode-go")` agree, or pi names the gap at the point where a user acts on it.
3. `pi --list-models opencode-go` produces identical output on two consecutive invocations, and its behaviour with and without `--offline` is the documented one.
4. `pi update --models` is not relied on to close the gap for `opencode-go`; on this provider it cannot.
5. `pi-ai`'s built-in catalog still serves unchanged when the network is unreachable: the fix degrades to the existing behaviour rather than to an error or an empty list.

For finding 3:

6. The script in finding 3 reports an error naming the stale catalog for `glm-5.1` and `deepseek-flash`, rather than a price. It must be run through an **async** entry point; see the traps under finding 3.
7. `glm-5` resolves to `glm-5` with a warning, or to `glm-5.3-flash` with one that says so, on **both** the `--model` path and the `--models` scope path.
8. A substituted model does not inherit the donor's `cost`, and its `thinkingLevelMap` is either the donor's or an explicit narrow one -- **never absent**. Assert the served levels directly:

   ```js
   const m = substitutedModel;
   assert.notEqual(m.thinkingLevelMap, undefined, "an absent map makes every level look supported");
   ```

   With the map absent, `getSupportedThinkingLevels` returns every level and the request builder sends efforts the model rejects. This was the one regression this report's earlier advice caused, so it is worth an explicit assertion rather than an eyeball.

For finding 4:

9. An extension returning one model leaves the other 29 served; returning an empty list leaves all 29; a `models.json` override still wins; a stale stored entry stays gated out; and `pi --list-models` over every provider is unchanged.
10. An extension redefining a built-in model with a partial entry either keeps the built-in fields it omits, or the documentation says the replacement is total.

Before calling it done:

11. `node --check` passes on every edited file, including the minified chunk.
12. Every edited `.js` has a sourcemap consistent with it, **by content and not by mtime**, and every new file has one. These maps carry `sourcesContent`, so an edited `.js` with an untouched `.map` resolves stack traces to pre-change source. This tree ships no `src/`, so a self-referencing identity map is the honest rebuild; a mapping into a `.ts` that no longer matches the `.js` is worse than none.
13. No file reads a field its own `.d.ts` declares `private`, and no field declared `readonly` is assigned outside its declaring constructor. `ModelRuntime.create` is static, so the second is a rebuild-time `TS2540` that nothing in a `dist`-only patch will catch.
14. `CHANGELOG.md` carries an entry, and it names every behaviour change listed under finding 3.
15. The whole diff has been read end to end, and nothing in it is unrelated to these findings.
16. **The fix reached the binary, not only `dist/`.** `dist/core/` and `dist/bundle/` are separate copies and the binary reads only the second. Confirm the change is in the chunks, and that the binary still starts:

    ```bash
    grep -rl '<the marker your fix introduces>' dist/bundle/chunks/
    node dist/bundle/cli.js --version
    ```

    A first hit and a version line are both required. `node --check` on the chunk is not a substitute; see the next item.

### The bundle is a second copy, and `node --check` cannot see a mistake in it

`dist/bundle/` inlines these modules rather than importing them from `dist/core/`, so a change under `dist/core/` alone leaves the `pi` binary unchanged, and a change to the bundle alone diverges the two entry points. Three consequences, all of them learned the hard way:

- **Rebuild the bundle from source. If you cannot, derive the chunk edit mechanically from the verified `dist/core/` source and then run the binary.** One attempt hand-wrote the bundle edit and used `||` where the verified source had `!isListed(...) && ...`. The result was a shipped binary that warned on every ordinary prefix pattern, said nothing about the model the report is about, and left `dist/core/` and `dist/bundle/` disagreeing about the same function. `node --check` passed. Only running `dist/bundle/cli.js` found it.
- **A new export needs adding to `dist/bundle/index.js`'s import and export lists as well as the chunk's.** A name added to the chunk's `export{}` and not to those lists fails at load with `Export 'x' is not defined in module`.
- **Two entry points, two export sets.** `dist/index.js` (the SDK entry) and `dist/bundle/index.js` (what the binary uses) had 156 exports each before the change. Adding a new public name to one and not the other is not a crash, but it is an asymmetry, and claiming parity you have not checked is worse than not claiming it.
