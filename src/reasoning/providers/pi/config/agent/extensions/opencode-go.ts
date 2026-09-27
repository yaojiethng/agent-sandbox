/**
 * opencode-go live model refresh overlay.
 *
 * pi ships a frozen opencode-go catalog (built from models.dev at release
 * time). OpenCode publishes newer models first on its own `/models` endpoint.
 * This extension leaves pi's baked catalog untouched and adds only a
 * `refreshModels` hook: the returned union is the baked catalog plus the
 * live-only models, enriched from models.dev.
 *
 * The overlay does NOT set `compat.supportsReasoningEffort: false`. That flag
 * suppresses `reasoning_effort` for every level and breaks thinking-level
 * selection on deepseek-family models. The compat below inherits pi's
 * auto-detection (`true` for opencode.ai) by omitting the field, so "off"
 * sends `thinking: {"type":"disabled"}` and low/medium/high/max send a
 * `reasoning_effort`.
 */

import type { ExtensionAPI, ProviderConfig, ProviderModelConfig } from "@earendil-works/pi-coding-agent";
import type { Api, RefreshModelsContext } from "@earendil-works/pi-ai";
import { getBuiltinModels } from "@earendil-works/pi-ai/providers/all";

const GO_PROVIDER = "opencode-go";
const GO_V1_BASE = "https://opencode.ai/zen/go/v1";
const GO_ANTHROPIC_BASE = "https://opencode.ai/zen/go";
const LIVE_MODELS_URL = `${GO_V1_BASE}/models`;
const MODELS_DEV_URL = "https://models.dev/api.json";
const FETCH_TIMEOUT_MS = 15_000;

/** Context/cost fallbacks for models that models.dev has not catalogued yet. */
const DEFAULT_CONTEXT_WINDOW = 1_000_000;
const DEFAULT_MAX_TOKENS = 131_072;
const DEFAULT_COST = { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 };

/** Compat for openai-completions / openai-responses live-only models. */
const CHAT_COMPAT = {
	supportsStore: false,
	supportsDeveloperRole: false,
	maxTokensField: "max_tokens" as const,
};

/** Compat for deepseek-family chat-completions live-only models. */
const DEEPSEEK_COMPAT = {
	...CHAT_COMPAT,
	thinkingFormat: "deepseek" as const,
	requiresReasoningContentOnAssistantMessages: true,
};

/**
 * Live-only models that route through the Anthropic Messages adapter.
 * Maintain this set as OpenCode re-advertises a model over a different
 * adapter; pi's baked catalog already encodes the baked models' transport.
 */
const ANTHROPIC_TRANSPORT = new Set([
	"minimax-m2.5",
	"minimax-m2.7",
	"minimax-m3",
	"qwen3.5-plus",
	"qwen3.6-plus",
	"qwen3.7-max",
	"qwen3.7-plus",
]);

/** Live-only models that route through the OpenAI Responses adapter. */
const RESPONSES_TRANSPORT = new Set(["gpt-6-luna", "grok-4.5", "grok-4.7"]);

/** Keep only the input modalities pi's model type accepts. */
function normalizeInput(modalities: readonly string[] | undefined): ("text" | "image")[] {
	const filtered = (modalities ?? []).filter(
		(modality): modality is "text" | "image" => modality === "text" || modality === "image",
	);
	return filtered.length > 0 ? filtered : ["text"];
}

/** Map a models.dev effort list onto pi thinking levels. */
function thinkingLevelMapFromEffort(levels: readonly string[]): Record<string, string> {
	const map: Record<string, string> = {};
	for (const level of levels) {
		// The endpoint names "off" as "none" for some models (for example gpt-6-luna).
		map[level === "none" ? "off" : level] = level;
	}
	return Object.keys(map).length > 0 ? map : { low: "low", high: "high", max: "max" };
}

/**
 * Build a config for one live-only model. Metadata comes from the models.dev
 * opencode-go blob when present; missing models get conservative defaults but
 * always keep `reasoning: true` and a thinking-capable config.
 */
function liveOnlyModelConfig(id: string, metadata: ModelsDevModel | undefined): ProviderModelConfig {
	const api: Api = ANTHROPIC_TRANSPORT.has(id)
		? "anthropic-messages"
		: RESPONSES_TRANSPORT.has(id)
			? "openai-responses"
			: "openai-completions";
	const baseUrl = api === "anthropic-messages" ? GO_ANTHROPIC_BASE : GO_V1_BASE;
	const effortLevels = metadata?.reasoning_options?.find((opt) => opt.type === "effort")?.values;
	const isDeepseekFamily = id.startsWith("deepseek");
	const compat =
		api === "anthropic-messages" || (effortLevels?.length && !isDeepseekFamily)
			? CHAT_COMPAT
			: DEEPSEEK_COMPAT;

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
		thinkingLevelMap: effortLevels?.length
			? thinkingLevelMapFromEffort(effortLevels)
			: { low: "low", high: "high", max: "max" },
		compat,
	};
}

/** Fetch JSON with a timeout bounded by the caller's signal. */
async function fetchJson<T>(url: string, signal: AbortSignal): Promise<T | undefined> {
	const merged = AbortSignal.any([signal, AbortSignal.timeout(FETCH_TIMEOUT_MS)]);
	const response = await fetch(url, { signal: merged });
	if (!response.ok) {
		throw new Error(`HTTP ${response.status} from ${url}`);
	}
	return (await response.json()) as T;
}

/** The union pi serves after a refresh: baked catalog plus live-only models. */
export async function buildOpenCodeGoModels(options: {
	signal: AbortSignal;
	allowNetwork: boolean;
}): Promise<ProviderModelConfig[]> {
	// Pi's startup refresh runs two phases: an offline/cache init (allowNetwork
	// false) then a network phase. Never fetch in the offline phase; return the
	// baked catalog so no spurious aborted-fetch is surfaced.
	if (!options.allowNetwork) {
		return getBuiltinModels(GO_PROVIDER);
	}
	const signal = options.signal;
	const baked = getBuiltinModels(GO_PROVIDER);
	const bakedIds = new Set(baked.map((model) => model.id));

	let liveIds: string[] | undefined;
	try {
		const payload = await fetchJson<{ data?: { id?: string }[] }>(LIVE_MODELS_URL, signal);
		liveIds = (payload?.data ?? [])
			.map((entry) => entry.id)
			.filter((id): id is string => !!id);
		console.warn(`[opencode-go] live model list: ${liveIds.length} models from ${LIVE_MODELS_URL}`);
	} catch (error) {
		console.warn(`[opencode-go] live /models fetch failed (${(error as Error)?.message}); serving the baked catalog`);
	}
	if (!liveIds) {
		return baked;
	}

	let modelsDev: Record<string, ModelsDevModel> | undefined;
	try {
		const payload = await fetchJson<Record<string, { models?: Record<string, ModelsDevModel> }>>(
			MODELS_DEV_URL,
			signal,
		);
		modelsDev = payload?.[GO_PROVIDER]?.models;
		console.warn(`[opencode-go] models.dev metadata: ${Object.keys(modelsDev ?? {}).length} opencode-go entries`);
	} catch (error) {
		console.warn(`[opencode-go] models.dev metadata unavailable (${(error as Error)?.message}); using defaults`);
	}

	const models: ProviderModelConfig[] = baked.map((model) => overlayBakedModelMetadata(model, modelsDev?.[model.id]));
	let liveOnlyCount = 0;
	for (const id of liveIds) {
		if (bakedIds.has(id)) {
			continue;
		}
		liveOnlyCount++;
		models.push(liveOnlyModelConfig(id, modelsDev?.[id]));
	}
	console.warn(`[opencode-go] refreshed catalog from opencode.ai /models + models.dev: ${models.length} models (${models.length - liveOnlyCount} baked + ${liveOnlyCount} live-only)`);
	return models;
}

/**
 * Overlay variable metadata from models.dev onto a baked model. Only context,
 * max tokens, cost, and input are refreshed; pi's curated transport, compat,
 * thinking-level map, name, and reasoning survive untouched.
 */
function overlayBakedModelMetadata(model: ProviderModelConfig, metadata: ModelsDevModel | undefined): ProviderModelConfig {
	if (!metadata) {
		return model;
	}
	const input = normalizeInput(metadata.modalities?.input);
	return {
		...model,
		contextWindow: metadata.limit?.context ?? model.contextWindow,
		maxTokens: metadata.limit?.output ?? model.maxTokens,
		input: input.length > 0 ? input : model.input,
		cost: metadata.cost
			? {
					input: metadata.cost.input ?? model.cost.input,
					output: metadata.cost.output ?? model.cost.output,
					cacheRead: metadata.cost.cache_read ?? model.cost.cacheRead,
					cacheWrite: metadata.cost.cache_write ?? model.cost.cacheWrite,
				}
			: model.cost,
	};
}

/** Models.dev opencode-go blob fields this overlay consumes. */
interface ModelsDevModel {
	name?: string;
	reasoning?: boolean;
	reasoning_options?: { type: string; values?: string[] }[];
	modalities?: { input?: string[] };
	limit?: { context?: number; output?: number };
	cost?: {
		input?: number;
		output?: number;
		cache_read?: number;
		cache_write?: number;
	};
}

export default function (pi: ExtensionAPI) {
	// The config has no `models`, so applyExtension keeps pi's baked catalog;
	// only `refreshModels` is added on top of the built-in opencode-go provider.
	const config: ProviderConfig = {
		async refreshModels(context: RefreshModelsContext) {
			return buildOpenCodeGoModels({ signal: context.signal, allowNetwork: context.allowNetwork });
		},
	};
	pi.registerProvider(GO_PROVIDER, config);
	console.warn(`[opencode-go] overlay loaded; provider registered with refreshModels (baked base: ${getBuiltinModels(GO_PROVIDER).length} models)`);
}