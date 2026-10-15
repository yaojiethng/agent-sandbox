# scoped model list is stale after a catalog refresh

**Status:** draft

Environment: `@earendil-works/pi-coding-agent` 1.1.0, Linux x64, Node 22.x. The measurement below was taken by driving the shipped `resolveModelScopeFromModels` with an injected catalog. The interactive sites were read from the shipped `dist/`, and the same sites were cross-checked against the published 1.2.0 package; the two builds are identical at every line cited here. The 1.2.0 section of [Version drift](#version-drift) gives the comparison.

The summary: pi resolves the session's model scope once, from `enabledModels`, before the interactive catalog refresh runs. A scope is a list of concrete model objects, and nothing re-expands the patterns after the refresh. A model the refresh adds is therefore selectable in the "all" view but absent from the "scoped" view, absent from the model cycle, and absent from `ctx.scopedModels`, until the next start. The same gap exists in the `/scoped-models` selector, which keeps the startup expansion rather than the patterns.

## Finding 1: the scope is resolved before the only interactive refresh

The scope is resolved during runtime creation, inside `createRuntime`:

```js
// dist/main.js:659
const modelPatterns = parsed.models ?? settingsManager.getEnabledModels();
const scopedModels = modelPatterns && modelPatterns.length > 0
    ? await resolveModelScope(modelPatterns, modelRuntime, { signal: AbortSignal.timeout(15_000) })
    : [];
```

The interactive live refresh runs later and is not awaited:

```js
// dist/modes/interactive/interactive-mode.js:828
async run() {
    await this.init();
    if (!process.env.PI_OFFLINE) {
        const controller = new AbortController();
        const timeout = setTimeout(() => controller.abort(), 15_000);
        void refreshModelCatalogs(this.session.modelRuntime, controller.signal)
```

`run()` is entered after the TUI mounts, and `init()` is the first thing that owns a UI. `refreshModelCatalogs` triggers `modelRuntime.refresh`, which is the pass that reaches the network and calls an extension's `refreshModels`. So the order on a normal interactive start is: resolve scope, then mount TUI, then refresh the catalog.

One earlier refresh does precede the scope, and it is why this is not a startup bug:

```js
// dist/core/agent-session-services.js:111
await modelRuntime.refresh({ allowNetwork: false });
```

`createAgentSessionServices` awaits that offline pass before it returns, and `main.js` calls it at line 599, before the `resolveModelScope` above. The offline pass calls `refreshModels` too, with `allowNetwork: false`. A source the extension can read without the network - a local cache - is therefore in the catalog when the scope is resolved. Our shipped extension reads a cache in exactly that phase, so its cache-backed ids are in scope at startup. The gap is an id that only the live pass returns.

The consequence is that a model first seen on the live pass is served in the catalog but is not the session's scope:

- `session.scopedModels` (and `ctx.scopedModels`) does not list it.
- The model cycle uses `this._scopedModels` (`dist/core/agent-session.js:1990`, `_cycleScopedModel`), so the cycle key does not reach it.
- The `/model` selector's "scoped" view is built from `session.scopedModels` (`dist/modes/interactive/interactive-mode.js:4461`, which constructs the selector with `this.session.scopedModels`), so it does not list it.
- The `/scoped-models` selector does not show it as an enabled row, so the user cannot enable it there either.

The user experiences this as "a new model is missing from the scoped list", with no message, until the next start. If the extension wrote the id to its cache on the live pass, the next start includes it, which makes the defect look intermittent.

## Finding 2: neither scoped surface re-expands the configured patterns

The `/model` selector re-points the existing scope entries to refreshed definitions but never matches them against the refreshed catalog:

```js
// dist/modes/interactive/components/model-selector.js:103
loadModelsFromSnapshot() {
    const models = this.modelRuntime.getAvailableSnapshot().map((model) => ({ ... }));
    this.allModels = this.sortModels(models);
    this.scopedModels = this.scopedModels.map((scoped) => {
        const refreshed = this.modelRuntime.getModel(scoped.model.provider, scoped.model.id);
        return refreshed ? { ...scoped, model: refreshed } : scoped;
    });
    this.scopedModelItems = this.scopedModels.map((scoped) => ({ ... }));
    this.activeModels = this.scope === "scoped" ? this.scopedModelItems : this.allModels;
```

The `map` can only update an entry that is already in `this.scopedModels`. A new id cannot enter, so the "scoped" view is a subset of the startup scope plus whatever survives the refresh.

The `/scoped-models` selector has the same gap behind a different branch. After the refresh it re-resolves the settings patterns only when the session scope is empty:

```js
// dist/modes/interactive/interactive-mode.js:4535
void refreshModelCatalogs(this.session.modelRuntime, controller.signal)
    .then((result) => {
        ...
        availableModels = [...this.session.modelRuntime.getAvailableSnapshot()];
        availableModelIds = new Set(availableModels.map((model) => `${model.provider}/${model.id}`));
        if (!selectionChanged && sessionScopedModels.length === 0) {
            currentEnabledIds = configuredEnabledIds(availableModels);
            selector.updateModels(availableModels, currentEnabledIds);
        }
        else {
            selector.updateModels(availableModels);
        }
        if (currentEnabledIds !== null)
            updateSessionModels(currentEnabledIds);
```

When `enabledModels` is configured - the state the branch exists to serve - `sessionScopedModels.length > 0`, so the code takes the `else` branch and keeps `currentEnabledIds`, which was computed at the top of the function:

```js
// dist/modes/interactive/interactive-mode.js:4484
let currentEnabledIds = sessionScopedModels.length > 0
    ? sessionScopedModels.map((scoped) => `${scoped.model.provider}/${scoped.model.id}`)
    : configuredEnabledIds(availableModels);
```

Those are concrete ids, the expansion of the patterns at startup. `updateSessionModels` then calls `resolveModelScopeFromModels(enabledIds, availableModels)` over concrete ids, which cannot match a new id. The condition `sessionScopedModels.length === 0` conflates "no scope configured" with "scope is settings-derived and should track the catalog".

The sequence is measurable with the shipped resolver alone. Given a catalog with two `opencode-go` ids, a later catalog that adds a third, and the pattern `opencode-go/*`:

```text
catalog before: [glm-5.2, glm-5.3]
catalog after:  [glm-5.2, glm-5.3, brand-new-model]
patterns:       ["opencode-go/*"]

1. scope from patterns, before the refresh:
   opencode-go/glm-5.2, opencode-go/glm-5.3
2. same patterns resolved against the refreshed catalog:
   opencode-go/glm-5.2, opencode-go/glm-5.3, opencode-go/brand-new-model
3. the startup ids resolved against the refreshed catalog (the selector path):
   opencode-go/glm-5.2, opencode-go/glm-5.3
```

Row 2 is what the pattern means. Row 3 is what both scoped surfaces do. The difference is the new id, and it is present only in row 2.

## Finding 3: an extension cannot supply the missing re-resolution

The extension that discovers the model is the obvious place to re-expand the scope, and the extension API does not permit it. `ExtensionContext` exposes the scope read-only:

```ts
// dist/core/extensions/types.d.ts:1639
getScopedModels: () => readonly ScopedModel[];
```

There is no `setScopedModels` in `ExtensionContext`, `ExtensionContextActions`, or `ExtensionActions`. `AgentSession.setScopedModels` (`dist/core/agent-session.js:1239`) is internal, reachable from the interactive surfaces only through `showModelsSelector`. `ctx.setModel(model, { persist: true })` does add a model to a non-empty scope through `_addPersistedDefaultToNonEmptyScope`, but it also switches the session's model and rewrites `enabledModels`, so it is not a re-expansion and is not a fit for a background refresh. An extension therefore cannot close the gap, and this report does not propose that it should.

## The fix

The scope has two provenances and they need different refresh behaviour:

- A settings-derived scope, from `enabledModels`, is a set of patterns and should track the catalog. After a successful refresh, re-expand those patterns and replace the session scope.
- An explicit session scope, from `--models` or from a manual `/scoped-models` edit, is a set of model choices and should stand until the user changes it.

`/scoped-models` already contains the first half: `configuredEnabledIds(availableModels)` re-expands the patterns. The defect is the `sessionScopedModels.length === 0` guard, which applies it only when no scope exists. The smallest correct change is to apply it after every refresh when the session scope is settings-derived, and to keep the current behaviour for an explicit scope. That needs the session or the selector to record which provenance produced the scope, because `sessionScopedModels` itself does not distinguish the two.

`/model` needs the same treatment on the same provenance rule: when the scope is settings-derived, re-expand it against the refreshed snapshot rather than re-pointing the startup list. A session scope left unchanged is correct only for the explicit case.

Two details are worth deciding explicitly rather than by accident:

- **Which settings source.** The selector reads `this.settingsManager.getEnabledModels()` at the top of `showModelsSelector`. A re-expansion after refresh must read the settings again, or carry the patterns captured at open, so an edit saved during the refresh is not undone.
- **What `--list-models` shows.** That surface reads the available snapshot, not the scope, so it already lists a newly discovered id. The report does not propose changing it; the inconsistency between the picker's two views is the narrower defect.

## Version drift

Measured on 1.1.0. Re-read against the published 1.2.0 package on the same date. `dist/core/model-resolver.js` is byte-identical between the two, and `dist/modes/interactive/components/model-selector.js` is byte-identical. `dist/modes/interactive/interactive-mode.js` differs between the two versions only in status-indicator colouring; the scope branches quoted above are identical, and the resolver measurement reproduces on 1.2.0's resolver. The 1.2.0 line numbers are `main.js:662`, `interactive-mode.js:833`, `:4467`, `:4490`, `:4541`, `:4547` and `:4552`, `model-selector.js:103`, and `types.d.ts:1663`. The 1.1.0 numbers for the same sites are `main.js:660`, `interactive-mode.js:833`, `:4461`, `:4484`, `:4535`, `:4541` and `:4546`, `model-selector.js:103`, and `types.d.ts:1639`.

The defect is a sequence property rather than a code shape: it holds for any build that resolves the scope before the interactive refresh and keeps a resolved scope. A release that awaits the interactive refresh before resolving the scope, or that re-expands a settings-derived scope after the refresh, resolves it without changing the shape of the code quoted here.

## Verifying a fix

The sequence is the test, not the resolver alone. A check has three cases, and the last one is the guard that keeps the fix from clobbering a user's explicit choice.

1. Configure `enabledModels` with a pattern, start a session whose catalog gains an id during the interactive refresh, and assert the new id is in `session.scopedModels` and in the `/model` "scoped" view and appears as an enabled row in `/scoped-models`. This is the defect case, and it must be driven through the interactive path or through the same resolve-then-refresh sequence the session uses; a resolver unit test cannot reach it.
2. Repeat with the scope emptied. The current code already passes this case, so it is the control that the fix does not regress.
3. Start with an explicit scope that is not the settings expansion - a `--models` list, or a `/scoped-models` edit - and assert the refresh does not replace it. A fix that re-expands unconditionally turns a user's explicit scope into the settings scope, and this is the case that detects it.

Do not assert only that the new id is present. Assert that it is present for a settings-derived scope and absent-and-unchanged for an explicit one, because "the scope grew" is satisfied by the clobbering fix as well.
