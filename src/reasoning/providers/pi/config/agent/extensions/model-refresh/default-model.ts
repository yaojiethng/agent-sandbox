/**
 * The saved default the model scope discarded.
 *
 * pi's `findInitialModel` consults the resolved scope before the saved
 * `defaultProvider`/`defaultModel` pair and returns the scope head without
 * reading the default, so a configured default is dropped with no message. The
 * extension supplies the catalog the resolver reads; it does not re-implement
 * the ladder and does not call `ctx.setModel`. What it can do is say that the
 * preference was discarded.
 *
 * The applicability guard mirrors pi's own step-3 test: the default counts only
 * when it resolves to a model and that model's provider has configured auth.
 * With an empty scope the resolver consults the default, so there is nothing to
 * announce; with an absent or unauthenticated default there is nothing pi would
 * have honoured either.
 *
 * The settings arrive from `pi.getSettings()`, not from the event context: pi's
 * `ExtensionContext` has no settings accessor, and `getSettings` lives on the
 * `ExtensionAPI` the factory receives. The caller reads them once and passes
 * them in, so this module stays a pure function of its argument.
 */

/** The part of pi's `ExtensionContext` this module reads. */
export interface DefaultModelContext {
	model: { provider: string; id: string } | undefined;
	scopedModels: readonly unknown[];
	/** The effective settings, from `pi.getSettings()`; the context carries no settings accessor. */
	settings: { defaultProvider?: string; defaultModel?: string };
	modelRegistry: {
		find(provider: string, modelId: string): unknown;
		hasConfiguredAuth(model: unknown): boolean;
	};
}

/**
 * The notice for a saved default the scope discarded, or `undefined`.
 *
 * `undefined` covers every case where no discard happened: no saved default, an
 * empty scope, the default already selected, or a default that does not resolve
 * to an authenticated model.
 */
export function discardedDefault(ctx: DefaultModelContext): string | undefined {
	const { defaultProvider, defaultModel } = ctx.settings;
	if (!defaultProvider || !defaultModel) {
		return undefined;
	}
	if (ctx.scopedModels.length === 0) {
		return undefined;
	}
	const selected = ctx.model;
	if (selected === undefined) {
		return undefined;
	}
	if (selected.provider === defaultProvider && selected.id === defaultModel) {
		return undefined;
	}
	const saved = ctx.modelRegistry.find(defaultProvider, defaultModel);
	if (saved === undefined || !ctx.modelRegistry.hasConfiguredAuth(saved)) {
		return undefined;
	}
	return `saved default ${defaultProvider}/${defaultModel} is outside the model scope; started on ${selected.provider}/${selected.id}`;
}
