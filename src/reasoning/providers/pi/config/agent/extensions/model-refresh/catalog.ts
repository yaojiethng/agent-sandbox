/**
 * The source union, as pure functions over arrays.
 *
 * Nothing here performs I/O. `buildUnion` takes the sources a declared provider
 * names and returns the list the extension serves. Keeping it pure is what lets
 * the tests cover every error case without a network call or an API key.
 *
 * The model: pi's baked catalog and pi's persisted pi.dev overlay are pi's
 * primary sources. A provider's own `/models` endpoint is a secondary source
 * with override authority for that provider, and models.dev is a secondary
 * metadata source without it. Sources are declared in `sources.json`, in one
 * ordered list per provider, and the union is one primitive applied to them.
 */

import type { ModelDefinition, ModelsDevModel, ProviderDecl, StoredCatalog } from "./types.ts";
import { levelMapFor } from "./thinking.ts";

/** Fallbacks for a model no catalog has described yet. */
export const DEFAULT_CONTEXT_WINDOW = 1_000_000;
export const DEFAULT_MAX_TOKENS = 131_072;
export const DEFAULT_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

/** The openai-completions transport, with the flags the gateway needs. */
export const CHAT_COMPAT = {
	supportsStore: false,
	supportsDeveloperRole: false,
	maxTokensField: "max_tokens",
} as const;

/** The deepseek-family chat transport: reasoning content on assistant turns. */
export const DEEPSEEK_COMPAT = {
	...CHAT_COMPAT,
	thinkingFormat: "deepseek",
	requiresReasoningContentOnAssistantMessages: true,
} as const;

/** Keep only the input modalities pi's model type accepts. */
export function normalizeInput(modalities: readonly string[] | undefined): ("text" | "image")[] {
	const filtered = (modalities ?? []).filter(
		(modality): modality is "text" | "image" => modality === "text" || modality === "image",
	);
	return filtered.length > 0 ? filtered : ["text"];
}

/**
 * Whether pi's persisted catalog is newer than the baked data it would replace.
 *
 * This mirrors pi's own gate in `dist/core/remote-catalog-provider.js`
 * (`remoteModels`), so the extension reproduces the primary under exactly the
 * condition pi would. When the baked generation timestamp is unknown, pi
 * applies the store; this matches that rather than guessing the other way.
 */
export function isStoreNewerThanBaked(stored: StoredCatalog | undefined, generatedAt: number | undefined): boolean {
	if (!stored?.models?.length) {
		return false;
	}
	if (generatedAt === undefined) {
		return true;
	}
	return stored.lastModified !== undefined && stored.lastModified > generatedAt;
}

/**
 * The stored entries belonging to one provider.
 *
 * A persisted file is data on disk, not a typed argument, so the shape is
 * checked before the entry is trusted: a corrupt store contributes nothing
 * rather than throwing at startup or seeding an entry with no id.
 */
export function storeEntriesFor(stored: StoredCatalog | undefined, providerId: string): ModelDefinition[] {
	if (!Array.isArray(stored?.models)) {
		return [];
	}
	return stored.models.filter(
		(model): model is ModelDefinition =>
			typeof model?.id === "string" && model.id.length > 0 && (model as { provider?: string }).provider === providerId,
	);
}

/** An entry with every field `entry` leaves undefined taken from `fallback`. */
export function fillMissing(entry: ModelDefinition, fallback: ModelDefinition): ModelDefinition {
	const filled: Record<string, unknown> = { ...fallback };
	for (const [key, value] of Object.entries(entry)) {
		if (value !== undefined) {
			filled[key] = value;
		}
	}
	return filled as unknown as ModelDefinition;
}

/**
 * The identity pi keys a model on: its type and its id.
 *
 * `getModelType` in pi-ai treats a missing type as `chat`, and pi's
 * `mergeModels` in `dist/core/remote-catalog-provider.js` keys on `type + id`,
 * so a same-id pair of different types is two models to pi and stays two here.
 * Every site that decides identity uses this key, or a source would collapse a
 * pair at one fold and keep it at the next.
 */
export function modelKey(model: Pick<ModelDefinition, "id" | "type">): string {
	return `${model.type ?? "chat"}\u0000${model.id}`;
}

/**
 * Union two entry lists by `modelKey`, first-wins per field.
 *
 * An entry the accumulator already holds keeps every field it supplies and
 * takes only the fields it leaves undefined from the incoming list; an entry
 * with a new key is appended. A union removes nothing, so an entry one source
 * supplies stays served even when no later source lists it. The key is the
 * type and the id together, not the id alone, because an image entry and a
 * chat entry may share an id.
 */
export function unionFirstWins(acc: readonly ModelDefinition[], next: readonly ModelDefinition[]): ModelDefinition[] {
	const merged: ModelDefinition[] = [];
	const index = new Map<string, number>();
	for (const model of [...acc, ...next]) {
		if (typeof model?.id !== "string" || model.id.length === 0) {
			continue;
		}
		const key = modelKey(model);
		const position = index.get(key);
		if (position === undefined) {
			index.set(key, merged.length);
			merged.push(model);
			continue;
		}
		merged[position] = fillMissing(merged[position] as ModelDefinition, model);
	}
	return merged;
}

/**
 * The transport an id is served over.
 *
 * A declaration entry wins, then the metadata's provider SDK: models.dev names
 * `@ai-sdk/openai` for the same ids pi bakes with the responses adapter, and
 * `@ai-sdk/anthropic` for the ids pi bakes with the messages adapter. An id no
 * source classifies falls to the gateway's completions surface.
 */
export function derivedTransport(decl: ProviderDecl, id: string, npm?: string): ModelDefinition["api"] {
	for (const [api, ids] of Object.entries(decl.transports ?? {})) {
		if (ids.includes(id)) {
			return api as ModelDefinition["api"];
		}
	}
	if (npm === "@ai-sdk/openai") {
		return "openai-responses";
	}
	if (npm === "@ai-sdk/anthropic") {
		return "anthropic-messages";
	}
	return "openai-completions";
}

/** The transport a declared provider serves an id over, and the base url that goes with it. */
export function transportFor(decl: ProviderDecl, id: string, npm?: string): { api: ModelDefinition["api"]; baseUrl: string } {
	const api = derivedTransport(decl, id, npm);
	return { api, baseUrl: decl.baseUrls[api] ?? "" };
}

/**
 * The entry a provider endpoint contributes for one id.
 *
 * The endpoint advertises ids and no model fields, so this supplies only the
 * transport facts the provider's declaration states. Metadata arrives from
 * models.dev through the union, and pi's curated `compat` and thinking map, for
 * an id the primary already carries, arrive the same way: an override source
 * wins the fields it carries, not the ones it does not.
 */
export function sourceEntry(decl: ProviderDecl, id: string, npm?: string): ModelDefinition {
	const { api, baseUrl } = transportFor(decl, id, npm);
	return { id, api, baseUrl };
}

/**
 * The compat block a secondary source builds for an id.
 *
 * The declaration's default block applies, and an id-prefix rule overrides it.
 * The prefix rule exists for the deepseek family, whose gateway needs its
 * reasoning content on assistant turns and a `thinking` object rather than a
 * bare `reasoning_effort`; getting that key wrong is what the extension was
 * first written to fix.
 */
export function compatFor(decl: ProviderDecl, id: string): Record<string, unknown> {
	const base = { ...(decl.compat?.default ?? CHAT_COMPAT) };
	for (const [prefix, override] of Object.entries(decl.compat?.byPrefix ?? {})) {
		if (id.startsWith(prefix)) {
			return { ...base, ...override };
		}
	}
	return base;
}

/**
 * The entry models.dev contributes for one id.
 *
 * models.dev is a metadata source: it carries names, limits, prices, the
 * advertised thinking efforts and the provider SDK, and no transport of its own.
 * An id the primary already carries takes its curated compat and thinking map
 * from the primary instead, since `models-dev` is declared after `baked`.
 */
export function metadataEntry(decl: ProviderDecl, id: string, metadata: ModelsDevModel | undefined): ModelDefinition {
	const { api, baseUrl } = transportFor(decl, id, metadata?.provider?.npm);
	const efforts = metadata?.reasoning_options?.find((option) => option.type === "effort")?.values;
	return {
		id,
		name: metadata?.name ?? id,
		api,
		baseUrl,
		reasoning: metadata?.reasoning ?? true,
		input: normalizeInput(metadata?.modalities?.input),
		cost: metadata?.cost
			? {
					input: metadata.cost.input ?? 0,
					output: metadata.cost.output ?? 0,
					cacheRead: metadata.cost.cache_read ?? 0,
					cacheWrite: metadata.cost.cache_write ?? 0,
				}
			: { ...DEFAULT_COST },
		contextWindow: metadata?.limit?.context ?? DEFAULT_CONTEXT_WINDOW,
		maxTokens: metadata?.limit?.output ?? DEFAULT_MAX_TOKENS,
		thinkingLevelMap: levelMapFor(efforts, decl.thinking),
		compat: compatFor(decl, id),
	};
}

export interface UnionInput {
	providerId: string;
	decl: ProviderDecl;
	/** Pi's baked catalog for the provider. */
	baked: readonly ModelDefinition[];
	/** Pi's persisted pi.dev catalog entry, as handed to `refreshModels`. */
	stored: StoredCatalog | undefined;
	/** The baked data's generation timestamp, from pi's providers module. */
	generatedAt: number | undefined;
	/** Ids the provider's endpoint advertises, or undefined when it was not reached. */
	endpointIds: readonly string[] | undefined;
	/** The models.dev blob for the provider, or undefined when it was not reached. */
	modelsDev: Record<string, ModelsDevModel> | undefined;
}

/** The entry-state delta between two served catalogs. */
export interface CatalogDelta {
	/** Keys the after catalog holds that the before catalog did not. */
	added: number;
	/** Keys the before catalog held that the after catalog does not. */
	removed: number;
	/** Keys on both sides whose fields differ. */
	revised: number;
}

/** The entries one declared source contributes. A source that was not reached contributes none. */
function entriesFor(kind: UnionInput["decl"]["sources"][number]["kind"], input: UnionInput, ids?: readonly string[]): ModelDefinition[] {
	switch (kind) {
		case "baked":
			return [...input.baked];
		case "pi-dev":
			return isStoreNewerThanBaked(input.stored, input.generatedAt) ? storeEntriesFor(input.stored, input.providerId) : [];
		case "models-dev": {
			// A metadata source adds no id of its own, so it is enumerated over the
			// ids the id sources settled rather than over its own blob. An id it does
			// not describe still gets an entry, so that id receives its transport and
			// defaults rather than staying a bare client-supplied id.
			const wanted = ids ?? Object.keys(input.modelsDev ?? {});
			return [...wanted].map((id) => metadataEntry(input.decl, id, input.modelsDev?.[id]));
		}
		case "endpoint":
			return Array.isArray(input.endpointIds)
				? input.endpointIds
						.filter((id): id is string => typeof id === "string" && id.length > 0)
						.map((id) => sourceEntry(input.decl, id, input.modelsDev?.[id]?.provider?.npm))
				: [];
	}
}

/**
 * Apply an override source: its fields win where it carries them, and the
 * accumulator's order stands.
 *
 * `unionFirstWins` puts its first argument's ids first, so passing the override
 * source first would also move every id it lists to the front of the served
 * list and push the accumulator's own ids behind them. The served order is the
 * primary catalog's, and the model picker reads it, so the order is restored
 * after the fields are merged; an id only the override lists is appended.
 */
function overlayPreservingOrder(acc: readonly ModelDefinition[], next: readonly ModelDefinition[]): ModelDefinition[] {
	const merged = unionFirstWins(next, acc);
	const position = new Map(acc.map((model, index) => [modelKey(model), index]));
	return [...merged].sort((a, b) => (position.get(modelKey(a)) ?? Number.MAX_SAFE_INTEGER) - (position.get(modelKey(b)) ?? Number.MAX_SAFE_INTEGER));
}

/**
 * The list the extension serves, built from the declared sources.
 *
 * One union primitive, first-wins per field. The non-override id sources fold
 * in list order, earlier winning. The override id sources fold in reverse list
 * order, so the first-listed override is the strongest; reverse is what makes
 * first-wins produce override semantics without a second rule, and each one
 * restores the accumulator's order.
 *
 * A source declared `metadata` contributes no id of its own, so it runs after
 * the ids and the order are settled, as a fill pass over the served list. That
 * placement is what keeps an id an override source introduces from entering the
 * catalog ahead of the source that introduced it, and it is what keeps a
 * metadata source from overriding a value another source already supplied.
 */
export function buildUnion(input: UnionInput): ModelDefinition[] {
	const declared = input.decl.sources;
	const idSources = declared.filter((source) => source.metadata !== true);
	const metadataSources = declared.filter((source) => source.metadata === true);

	let served: ModelDefinition[] = [];
	for (const source of idSources.filter((source) => source.override !== true)) {
		served = unionFirstWins(served, entriesFor(source.kind, input));
	}
	for (const source of idSources.filter((source) => source.override === true).reverse()) {
		served = overlayPreservingOrder(served, entriesFor(source.kind, input));
	}
	for (const source of metadataSources) {
		const supplied = new Map(entriesFor(source.kind, input, served.map((model) => model.id)).map((entry) => [modelKey(entry), entry]));
		served = served.map((model) => {
			const metadata = supplied.get(modelKey(model));
			return metadata ? fillMissing(model, metadata) : model;
		});
	}
	return served;
}

/**
 * The entry-state delta between two served catalogs, keyed on `modelKey`.
 *
 * A `revised` entry is one present on both sides whose fields differ, so a
 * same-id field change - the class this extension was built to repair - counts
 * even though no id moved. The comparison covers the whole entry, so a change
 * to any field counts once. The key is the type and the id together, so a
 * same-id pair of different types is two entries on both sides and is never a
 * revision of itself.
 */
export function diffCatalogs(before: readonly ModelDefinition[], after: readonly ModelDefinition[]): CatalogDelta {
	const beforeByKey = new Map(before.map((model) => [modelKey(model), model]));
	const afterByKey = new Map(after.map((model) => [modelKey(model), model]));
	let added = 0;
	let removed = 0;
	let revised = 0;
	for (const [key, entry] of afterByKey) {
		const previous = beforeByKey.get(key);
		if (previous === undefined) {
			added += 1;
		} else if (stableSerialize(previous) !== stableSerialize(entry)) {
			revised += 1;
		}
	}
	for (const key of beforeByKey.keys()) {
		if (!afterByKey.has(key)) {
			removed += 1;
		}
	}
	return { added, removed, revised };
}

/**
 * A stable serialization for the revision test.
 *
 * `JSON.stringify` is key-order sensitive, and the union builds a fresh entry
 * through `fillMissing` when a metadata source runs, so two entries with the
 * same fields can serialize differently. A field re-order is not a revision, so
 * the keys are sorted before comparison.
 */
function stableSerialize(value: unknown): string {
	return JSON.stringify(value, (_key, entry) =>
		entry && typeof entry === "object" && !Array.isArray(entry)
			? Object.fromEntries(Object.entries(entry as Record<string, unknown>).sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0)))
			: entry,
	);
}
