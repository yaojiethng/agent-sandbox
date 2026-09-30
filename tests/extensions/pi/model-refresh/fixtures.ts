/**
 * Fixture builders for the invariant conformance suite: the source shapes the
 * union reads, the payload capture, and a seeded generator for the property
 * cases. No test logic lives here, so a case reads a fixture and asserts on the
 * product rather than on a helper of its own.
 */

import { ANTHROPIC_BASE, V1_BASE } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import { PROVIDER_ID } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts";
import type { ModelDefinition, ModelsDevModel, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";

const PI_AI_ROOT = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai";

/** pi's request builder per transport, each read through its own `onPayload`. */
const STREAM_MODULES: Record<string, string> = {
	"openai-completions": `${PI_AI_ROOT}/dist/api/openai-completions.js`,
	"openai-responses": `${PI_AI_ROOT}/dist/api/openai-responses.js`,
	"anthropic-messages": `${PI_AI_ROOT}/dist/api/anthropic-messages.js`,
};

/** A persisted pi.dev entry, which carries the provider it belongs to. */
export type StoredEntry = ModelDefinition & { provider: string | undefined };

/** A baked catalog entry: every field pi's Model type needs, plus curated ones. */
export function bakedModel(id: string, overrides: Partial<ModelDefinition> = {}): ModelDefinition {
	return {
		id,
		name: `Baked ${id}`,
		api: "openai-completions",
		baseUrl: V1_BASE,
		reasoning: true,
		input: ["text"],
		cost: { input: 1, output: 2, cacheRead: 0.1, cacheWrite: 1.25 },
		contextWindow: 200_000,
		maxTokens: 32_000,
		compat: { maxTokensField: "max_tokens", supportsStore: false, supportsDeveloperRole: false },
		thinkingLevelMap: { off: null, minimal: null, low: "low", medium: null, high: "high", xhigh: null, max: "max" },
		...overrides,
	};
}

/** A baked entry on the anthropic transport, for the curated-field converse. */
export function anthropicBakedModel(id: string, overrides: Partial<ModelDefinition> = {}): ModelDefinition {
	return bakedModel(id, { api: "anthropic-messages", baseUrl: ANTHROPIC_BASE, compat: { thinkingFormat: "anthropic" }, ...overrides });
}

/** One persisted pi.dev entry, tagged with the provider pi filed it under. */
export function storedEntry(provider: string | undefined, id: string, overrides: Partial<ModelDefinition> = {}): StoredEntry {
	return { ...bakedModel(id, overrides), name: `Stored ${id}`, provider };
}

/** A persisted catalog: the entries, the freshness stamp, and the check time. */
export function storedCatalog(provider: string | undefined, models: readonly ModelDefinition[], lastModified: number | undefined): StoredCatalog {
	return {
		models: models.map((model) => ({ ...model, provider })) as StoredCatalog["models"],
		lastModified,
		checkedAt: lastModified === undefined ? undefined : lastModified + 1,
	};
}

/** One models.dev blob, keyed by the model id the blob is filed under. */
export function modelsDevEntry(id: string, overrides: Partial<ModelsDevModel> = {}): Record<string, ModelsDevModel> {
	return { [id]: { name: `Dev ${id}`, reasoning: true, ...overrides } };
}

/** An effort list carrying every named level, for the thinking-level cases. */
export function effortList(values: readonly string[]): { type: string; values: string[] }[] {
	return [{ type: "effort", values: [...values] }];
}

/**
 * Drive pi's real request builder and return the thinking fields of the payload
 * it built. The request is handed to a `fetch` stub that refuses, so the probe
 * reaches the builder and opens no socket. The level map, the compat block, and
 * the level decide the payload; nothing here reads the answer back.
 */
export async function captureThinkingPayload(model: ModelDefinition, level: string): Promise<Record<string, unknown>> {
	const module = STREAM_MODULES[model.api];
	if (!module) {
		throw new Error(`the suite states no payload expectation for the transport ${model.api}`);
	}
	const { streamSimple } = (await import(module)) as {
		streamSimple: (model: unknown, context: unknown, options: unknown) => { result: () => Promise<unknown> };
	};
	let payload: Record<string, unknown> | undefined;
	const stream = streamSimple({ ...model, provider: PROVIDER_ID }, { messages: [{ role: "user", content: "probe" }] }, {
		apiKey: "placeholder",
		reasoning: level,
		fetch: async () => {
			throw new Error("the invariant probe refuses to send");
		},
		onPayload: (built: unknown) => {
			payload = built as Record<string, unknown>;
			return undefined;
		},
	});
	// The refusal is the expected outcome: only the payload matters here.
	await stream.result().catch(() => undefined);
	if (!payload) {
		throw new Error(`pi built no payload for ${model.id} at level ${level}`);
	}
	return Object.fromEntries(Object.entries(payload).filter(([key]) => /reason|think|budget|effort/i.test(key)));
}
/** A seeded generator, so a failing property case replays the same catalog. */
export function makeRng(seed: number): () => number {
	let state = seed >>> 0;
	return () => {
		state = (state + 0x6d2b79f5) >>> 0;
		let mixed = state;
		mixed = Math.imul(mixed ^ (mixed >>> 15), mixed | 1);
		mixed ^= mixed + Math.imul(mixed ^ (mixed >>> 7), mixed | 61);
		return ((mixed ^ (mixed >>> 14)) >>> 0) / 4294967296;
	};
}

/** One element of a list. */
export function pick<T>(rng: () => number, list: readonly T[]): T {
	return list[Math.min(list.length - 1, Math.floor(rng() * list.length))] as T;
}

/** Generated baked entries: varied transport, limits, costs, and modalities. */
export function someModels(rng: () => number, count: number, prefix: string): ModelDefinition[] {
	return Array.from({ length: count }, (_, index) => {
		const id = `${prefix}-${index}`;
		// The base url follows the transport, as the product's own tables do: an
		// entry on the anthropic adapter with the completions base url is a shape
		// the product never produces.
		const api = pick(rng, ["openai-completions", "openai-completions", "anthropic-messages"] as const);
		return bakedModel(id, {
			name: pick(rng, [`Baked ${id}`, `Curated ${id}`, id]),
			api,
			baseUrl: api === "anthropic-messages" ? ANTHROPIC_BASE : V1_BASE,
			reasoning: rng() < 0.75,
			input: rng() < 0.5 ? ["text", "image"] : ["text"],
			cost: { input: Number((rng() * 3).toFixed(4)), output: Number((rng() * 15).toFixed(4)), cacheRead: 0, cacheWrite: 0 },
			contextWindow: 1_000 + Math.floor(rng() * 2_000_000),
			maxTokens: 1_000 + Math.floor(rng() * 300_000),
		});
	});
}
