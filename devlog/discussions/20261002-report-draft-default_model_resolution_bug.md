# default model provider resolution bug report

Environment: `@earendil-works/pi-coding-agent` 0.87.1, Linux x64, Node 22.22.3. All measurements below were taken against that build by driving pi's own `findInitialModel` and `resolveModelScopeFromModels` with an injected catalog and an injected auth set, so the numbers come from the shipped resolver and not from a re-implementation of it.

The summary: a user who configures a model scope has their saved default model silently discarded, with no message, on every start. `defaultProvider` and `defaultModel` are not weakened settings in that case. They are never read. The scope list wins because it is consulted first and returns unconditionally, and because the setting that would have overridden the choice is only reached on the branch the scope did not take. The user sees a model they did not ask for, believes their setting is being ignored for some reason they cannot name, and has no output to search for.

The second half of the report is about the scope itself. It is an ordered list whose first entry decides the model, and neither the settings schema nor the `/scoped-models` surface says so. A user reorders that list for readability and silently changes which model every session starts on.

## Finding 1: a non-empty model scope silently outranks the saved default

```js
// dist/core/model-resolver.js:492
// 2. Use first model from scoped models (skip if continuing/resuming)
if (scopedModels.length > 0 && !isContinuing) {
    const scopedModel = scopedModels[0];
    const perModel = modelThinkingLevels?.[`${scopedModel.model.provider}/${scopedModel.model.id}`];
    return {
        model: scopedModel.model,
        thinkingLevel: scopedModel.thinkingLevel ?? perModel ?? defaultThinkingLevel ?? DEFAULT_THINKING_LEVEL,
        fallbackMessage: undefined,
    };
}
// 3. Try saved default from settings if auth is configured.
if (defaultProvider && defaultModelId) {
    ...
```

Two properties of step 2 combine into the defect. It is gated only on the scope being non-empty, and it returns without consulting the saved default. So any configured scope, of any length, however the user came to configure it, permanently removes `defaultProvider` and `defaultModel` from the resolution.

`fallbackMessage: undefined` is the second half. The function's own return type carries a field for telling the user that a preference could not be honoured, and step 2 sets it to `undefined` on a path where a preference was in fact discarded. Every other fall-through in this module fills it in: `restoreModelFromSession` fills it with the reason and the model actually used, and `resolveCliModel` fills it with the reason and the substitute. Step 2 is the one place a user's stated preference is dropped, and it is the one place that says nothing.

Measured, driving the shipped resolver with the settings from the report above and a catalog carrying every model those patterns name:

| Settings | Selected | `fallbackMessage` |
|---|---|---|
| scope set, default present and authenticated | `openrouter/z-ai/glm-4.5` | `null` |
| scope empty, default present and authenticated | `opencode-go/space-bunny-free` | `null` |
| scope set, default provider not authenticated | `openrouter/z-ai/glm-4.5` | `null` |
| scope set, default id absent from the catalog | `openrouter/z-ai/glm-4.5` | `null` |

The first row is the defect. The second row is the control and it is the important one: with the scope emptied and nothing else changed, the saved default is selected. The default was never wrong and never inapplicable. It was simply never consulted.

The last two rows matter for a separate reason. They show the saved default failing for two unrelated reasons, both silently, and the scope still winning, so a user cannot distinguish "my default is being overridden" from "my default is not valid" from the outside, because all three produce the identical silent result.

### The obvious fix does not work, and it fails for exactly the users who hit this

Reordering the two steps, so the saved default is consulted before the scope, is the change a reader reaches for first, and it breaks the feature the scope exists for. The scope's purpose is to bound which models a session may use. If `defaultProvider` and `defaultModel` outrank the scope, a default that falls outside the scope either fails every call or forces the scope open, and in both cases the user gets a session that advertises a bound it does not honour.

The reverse reordering, keeping the scope ahead but making it yield to a default that is *inside* the scope, has the defect that the scope is a set of glob patterns and the default is an exact id. Deciding "is the default inside the scope" needs the scope resolved first, which is what step 2 already does, so this is closer to a reordering than it looks. It is still not free, and the reason is in Finding 3.

### The fix

Keep the scope ahead of the sweep, and make it yield to an explicit default that the scope itself resolved. The scope head is the implicit default today. Promoting an exact, authenticated, in-scope `defaultProvider`/`defaultModel` pair to the head of the resolved list is a reordering of a list the user already built, and it preserves the bound: the default must be in the scope to win, so a session can never start on a model the scope excluded.

Whatever the ordering chosen, the `fallbackMessage` on this path must name what happened. A user who configured a default and got a different model is owed the sentence, and the field already exists to carry it. The cheapest correct change is the message alone: it does not alter any selection, and it converts a silent defect into a visible one that a user can act on without waiting for a fix.

## Finding 2: the saved default is skipped silently for two other reasons

```js
// dist/core/model-resolver.js:502
if (defaultProvider && defaultModelId) {
    const found = modelRuntime.getModel(defaultProvider, defaultModelId);
    if (found && modelRuntime.hasConfiguredAuth(found.provider)) {
        ...
    }
}
// falls through to the defaultModelPerProvider sweep with no message
```

When the scope is empty, this block still fails silently in two cases. The provider has no configured credential, or the id is not in the catalog. Both drop through to the step-4 sweep, which walks `defaultModelPerProvider` in key order and returns the first provider whose baked default id is present, then to `availableModels[0]`. Neither path reports anything.

The step-4 sweep is the behaviour the reporter recognised as "falling back to some sort of default-per-provider". It is worth being precise about what it does, because it is a reasonable design and the defect is only that it is silent. `defaultModelPerProvider` is a table of one preferred model per known provider, and the sweep returns the first match in the table's own key order, which is not the user's provider order, not alphabetical, and not related to anything the user configured. A user with three authenticated providers gets whichever one's preferred id appears earliest in pi's internal table.

The credential case is the sharper one. A user who has authenticated through an environment variable rather than a stored credential, or who has authenticated a provider that pi does not know about, reaches this block and fails it. There is a defensible argument that a provider without a resolvable credential should not be selectable at startup, and that argument is not written down anywhere.

### The fix

Fill `fallbackMessage` on the way past, naming which of the two conditions failed. The credential case and the unknown-id case have different remedies, and a single "could not use your default" message sends the user looking in the wrong place. Step 4 should also say which of its two sub-rules answered, because "the first preferred model in pi's table" and "the first model in the catalog" are very different surprises.

## Finding 3: the scope's order is load-bearing and nothing says so

`enabledModels` in `settings.json` is a list of glob patterns. `resolveModelScopeFromModels` walks them in order and appends matches, deduplicating as it goes. The first entry therefore becomes `scopedModels[0]`, which is the model the session starts on when Finding 1 applies, and the first entry the model-cycle key moves to.

Measured against the shipped 0.87.1 baked catalog of 1495 ids across all providers:

| `enabledModels` | Scoped | Head | Diagnostics |
|---|---|---|---|
| `openrouter/z-ai/*`, `openrouter/qwen/*`, `opencode/*`, `opencode-go/*`, `openrouter/deepseek/*`, `deepseek/*` | 199 | `openrouter/z-ai/glm-4.5` | none |
| the same list with `opencode-go/space-bunny-free` prepended | 132 | `opencode-go/minimax-m3` | `space-bunny-free` matches nothing in the baked catalog |

Two things fall out of the second row, and both are worth a maintainer's attention.

**Reordering the list changes the starting model.** Moving one entry from position four to position one is a natural thing to do when a user is tidying a list of model families, and it silently repoints every session. Nothing in the settings schema, and nothing on the `/scoped-models` surface, states that the list is ordered by selection priority rather than by category.

**The head of the list must name a model the catalog carries.** A user pinning a specific model to the head is the obvious way to express "start on this one", and it is exactly what breaks when that model is absent from the baked catalog. In the measurement above the head fell through to the next matching pattern, and the only signal was a `no-match` diagnostic for a pattern the user believed had matched. A default model that is absent from the baked catalog but present in a persisted per-provider overlay is a real configuration, because that is where pi puts models it learns about after a release, and it fails this path while working at runtime.

### The fix

State the ordering where the setting is defined, and make the head's absence loud. If the first pattern resolves to nothing, that is a misconfiguration the user wrote, and the diagnostics list already carries it, so the work is to surface it in the same place the scope is displayed rather than only in the resolver's return value. Separately, an exact provider/id entry at the head that fails to resolve should say so by name, because "your pinned model is not in the catalog" and "your pinned model is not in the catalog yet, but a persisted overlay supplies it" need different actions from the user.

## The docstring describes a five-step ladder the function does not implement

```js
// dist/core/model-resolver.js:466
 * Find the initial model to use based on priority:
 * 1. CLI args (provider + model)
 * 2. First model from scoped models (if not continuing/resuming)
 * 3. Restored from session (if continuing/resuming)
 * 4. Saved default from settings
 * 5. First available model with valid API key
 */
```

The function implements four steps. The missing one is the session restore, which lives in the separately exported `restoreModelFromSession` and is composed by the caller. So the comment describes the caller's assembly, not this function, and a reader who trusts it reads the saved default as step 4 of 5, which reads as a weak preference that is merely outranked. It is step 3 of 4, and it is outranked by a branch that returns without a guard.

This is listed as its own section rather than folded into Finding 1 because it is the difference between a reader diagnosing this in minutes and a reader believing the saved default is a low-priority tiebreak. The comment should either describe the four steps the function takes or name the function that owns the fifth.

## Version drift

Measured on 0.87.1. Not re-measured on any later build, so treat the line numbers and the code excerpts as pinned to that version. The three findings are behavioural rather than structural: each depends on the order of the branches in `findInitialModel` and on `enabledModels` being resolved in order. A release that reorders the ladder, or that changes `enabledModels` to a set, would change the results without changing the shape of the code quoted here.

The catalog measurement depends on the baked data and moves with every pi release that ships new models. The 1495 and 199 counts are a property of 0.87.1's baked set. The `space-bunny-free` row is a property of any configuration where the head names a model absent from the baked set, which is a stable class rather than a stable number.

## Verifying a fix

The measurement here has no proxy problem, so it can be stated directly. Drive the shipped `findInitialModel` with an injected catalog and an injected auth set, and assert on the selected pair and on `fallbackMessage`. Both are observable from outside the function, and both are what a user experiences. Do not re-implement the resolver in the test; that would test the re-implementation.

Three cases are the minimum, and the second is the one that matters:

1. A scope is configured and the default is present, authenticated and inside the scope. The default is selected.
2. A scope is configured and the default is present and authenticated. The result is recorded in `fallbackMessage` when the default is not the selection. An empty `fallbackMessage` on a path where a preference was dropped is the defect, and it is assertable without knowing which model the scope picked.
3. A scope is configured, the default is absent from the catalog, and a persisted overlay supplies it. The selection is the default, and the reason the baked catalog could not supply it is not reported as a failure.

Two guards on the check itself. Run it with an auth set that does not include the default's provider, and confirm the behaviour changes; if the result is identical, the case is not reaching the branch it claims to cover. And assert the `fallbackMessage` content, not merely that it is non-null, because "some message appeared" is satisfied by a message that names the wrong reason, which is the Finding 2 defect reappearing inside the Finding 1 fix.
