/**
 * The catalog union, as pure functions over arrays.
 *
 * Nothing here performs I/O. `buildUnion` takes the three inputs the extension
 * gathers -- pi's baked catalog, pi's persisted pi.dev catalog, and whatever
 * the provider's live endpoint advertises -- and returns the list the
 * extension serves. Keeping it pure is what lets the tests cover every error
 * case without a network call or an API key.
 */

import type { ModelDefinition, ModelsDevModel, StoredCatalog } from "./types.ts";
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

/** The transport each endpoint speaks. */
export const V1_BASE = "https://opencode.ai/zen/go/v1";
export const ANTHROPIC_BASE = "https://opencode.ai/zen/go";

/**
 * Live-only models that route through the Anthropic Messages adapter.
 *
 * An id appears here only when pi's baked catalog does not carry it, because
 * the live layer builds an entry only for an id the earlier sources do not
 * have. The lists were reconciled against pi's baked catalog on 2026-09-30:
 * four ids this table once claimed (`minimax-m2.7`, `qwen3.6-plus`,
 * `qwen3.7-max`, `qwen3.7-plus`) are carried by pi as `openai-completions`,
 * and the entries were removed rather than kept as a second opinion. The
 * invariant M8 holds the two in step.
 */
export const ANTHROPIC_TRANSPORT = new Set(["minimax-m2.5", "minimax-m3", "qwen3.5-plus"]);

/** Live-only models that route through the OpenAI Responses adapter. */
export const RESPONSES_TRANSPORT = new Set(["gpt-6-luna", "grok-4.5", "grok-4.7"]);

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
 * (`remoteModels`), so the extension applies the store under exactly the
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

/**
 * Overlay one list onto another: an entry with a matching id replaces the
 * earlier one in place, an unknown id is appended.
 *
 * This is pi's own `mergeModels` semantics. Matching them is deliberate: the
 * extension must serve what pi serves when no extension is registered, so a
 * fresher pi.dev entry replaces a stale baked one whole rather than being
 * second-guessed field by field. `models.json` `modelOverrides` remain the top
 * layer for local corrections, applied by pi after this list.
 *
 * The copy is forced on the pi release this extension runs against. On 0.87.1
 * `mergeModels` in pi's `dist/core/remote-catalog-provider.js` was declared
 * without `export`, and the package's `exports` map publishes no subpath under
 * `dist/`, so a bare
 * `@earendil-works/pi-coding-agent/dist/core/remote-catalog-provider` import
 * failed to resolve. By 0.99.1 pi exports it from that module; the package
 * entry still does not re-export it, so a third-party extension still cannot
 * reach it. Re-check this comment on a pi upgrade: if `dist/index.js` gains a
 * re-export, delete the copy and call the real one.
 *
 * The drift that a copy invites is closed rather than documented. pi's
 * `withRemoteCatalog` is exported, and its `getModels` is
 * `mergeModels(provider.getModels(), dynamicModels)` behind the same freshness
 * gate and provider filter this file applies. The G2 case `agrees with pi`
 * drives it and compares entry for entry, so a pi release that changes the
 * merge, the gate or the filter turns this suite red instead of diverging
 * quietly. Assumption A11 records the agreement.
 */
export function mergeCatalogs(base: readonly ModelDefinition[], overlay: readonly ModelDefinition[]): ModelDefinition[] {
	const merged = [...base];
	for (const model of overlay) {
		const index = merged.findIndex((entry) => entry.id === model.id);
		if (index >= 0) {
			merged[index] = model;
		} else {
			merged.push(model);
		}
	}
	return merged;
}

/**
 * Refresh a baked model's variable metadata from models.dev, leaving pi's
 * curated transport, compat, name, reasoning flag, and thinking-level map
 * untouched. Without this the baked entry wins every field and a corrected
 * context window or price never lands.
 */
export function overlayBakedMetadata(model: ModelDefinition, metadata: ModelsDevModel | undefined): ModelDefinition {
	if (!metadata) {
		return model;
	}
	const input = normalizeInput(metadata.modalities?.input);
	return {
		...model,
		contextWindow: metadata.limit?.context ?? model.contextWindow,
		maxTokens: metadata.limit?.output ?? model.maxTokens,
		input,
		cost: metadata.cost
			? {
					input: metadata.cost.input ?? model.cost?.input ?? DEFAULT_COST.input,
					output: metadata.cost.output ?? model.cost?.output ?? DEFAULT_COST.output,
					cacheRead: metadata.cost.cache_read ?? model.cost?.cacheRead ?? DEFAULT_COST.cacheRead,
					cacheWrite: metadata.cost.cache_write ?? model.cost?.cacheWrite ?? DEFAULT_COST.cacheWrite,
				}
			: model.cost,
	};
}

/** The endpoint a live-only id is served over, and the compat that goes with it. */
export function transportFor(id: string): { api: ModelDefinition["api"]; baseUrl: string } {
	if (ANTHROPIC_TRANSPORT.has(id)) {
		return { api: "anthropic-messages", baseUrl: ANTHROPIC_BASE };
	}
	if (RESPONSES_TRANSPORT.has(id)) {
		return { api: "openai-responses", baseUrl: V1_BASE };
	}
	return { api: "openai-completions", baseUrl: V1_BASE };
}

/**
 * Build the definition for a model the baked catalog has never heard of.
 *
 * The compat block omits `supportsReasoningEffort` on purpose: pi auto-detects
 * it from the endpoint, and the baked catalogs show the opencode.ai endpoints
 * are detected as supporting it. Setting the flag suppresses `reasoning_effort`
 * for every level and silently disables thinking-level selection.
 */
export function liveOnlyModelConfig(id: string, metadata: ModelsDevModel | undefined): ModelDefinition {
	const { api, baseUrl } = transportFor(id);
	const efforts = metadata?.reasoning_options?.find((option) => option.type === "effort")?.values;
	const isDeepseekFamily = id.startsWith("deepseek");
	const compat = api === "anthropic-messages" || (efforts?.length && !isDeepseekFamily) ? CHAT_COMPAT : DEEPSEEK_COMPAT;
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
			: DEFAULT_COST,
		contextWindow: metadata?.limit?.context ?? DEFAULT_CONTEXT_WINDOW,
		maxTokens: metadata?.limit?.output ?? DEFAULT_MAX_TOKENS,
		thinkingLevelMap: levelMapFor(efforts, true),
		compat: compat as unknown as Record<string, unknown>,
	};
}

export interface UnionInput {
	/** Pi's baked catalog for the provider. */
	baked: readonly ModelDefinition[];
	/** Pi's persisted pi.dev catalog entry, as handed to `refreshModels`. */
	stored: StoredCatalog | undefined;
	/** The baked data's generation timestamp, from pi's providers module. */
	generatedAt: number | undefined;
	/** Ids the provider's live endpoint advertises, or undefined when the fetch failed. */
	liveIds: readonly string[] | undefined;
	/** The models.dev blob for the provider, or undefined when the fetch failed. */
	modelsDev: Record<string, ModelsDevModel> | undefined;
	providerId: string;
}

/**
 * The list the extension serves.
 *
 * Three sources, in the order pi itself would apply them:
 *
 *  1. the baked catalog, with variable metadata refreshed from models.dev;
 *  2. pi's persisted pi.dev catalog, when it is newer than the baked data --
 *     this is the layer the previous revision of this extension dropped, and
 *     dropping it is why `space-bunny-free` vanished from the catalog;
 *  3. ids only the live endpoint advertises, built from models.dev where it
 *     has them.
 *
 * Every source is optional. A failed or absent source narrows the result; none
 * of them can remove a model another source supplied.
 */
export function buildUnion(input: UnionInput): ModelDefinition[] {
	const { baked, stored, generatedAt, liveIds, modelsDev, providerId } = input;

	const refreshedBaked = baked.map((model) => overlayBakedMetadata(model, modelsDev?.[model.id]));

	const remote = isStoreNewerThanBaked(stored, generatedAt) ? storeEntriesFor(stored, providerId) : [];
	const withRemote = mergeCatalogs(refreshedBaked, remote);

	// The live list is a parsed response body, so it is checked before it is
	// trusted: a shape the parser could not type contributes nothing.
	if (!Array.isArray(liveIds)) {
		return withRemote;
	}

	const known = new Set(withRemote.map((model) => model.id));
	const liveOnly: ModelDefinition[] = [];
	for (const id of liveIds) {
		if (typeof id !== "string" || known.has(id)) {
			continue;
		}
		known.add(id);
		liveOnly.push(liveOnlyModelConfig(id, modelsDev?.[id]));
	}
	return [...withRemote, ...liveOnly];
}
