/**
 * The catalog union, as pure functions over arrays.
 *
 * Every case here is an error case found in the previous revision of this
 * extension, which returned the baked catalog on every path and so deleted
 * pi's persisted pi.dev catalog. The tests are behavioural against
 * `buildUnion`: no network, no API key, no model runtime.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
	buildUnion,
	isStoreNewerThanBaked,
	liveOnlyModelConfig,
	mergeCatalogs,
	normalizeInput,
	overlayBakedMetadata,
	storeEntriesFor,
	transportFor,
	ANTHROPIC_BASE,
	V1_BASE,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import type { ModelDefinition, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";

const GENERATED_AT = 1_000_000;

function baked(id: string, extra: Partial<ModelDefinition> = {}): ModelDefinition {
	return {
		id,
		name: id,
		api: "openai-completions",
		baseUrl: V1_BASE,
		reasoning: true,
		input: ["text"],
		cost: { input: 1, output: 2, cacheRead: 0, cacheWrite: 0 },
		contextWindow: 100_000,
		maxTokens: 8_000,
		...extra,
	};
}

function storeEntry(models: ModelDefinition[]): StoredCatalog["models"] {
	return models.map((model) => ({ ...model, provider: "opencode-go" })) as StoredCatalog["models"];
}

/** A store pi would apply: its lastModified is newer than the baked data. */
function stored(models: ModelDefinition[], lastModified: number): StoredCatalog {
	return { models: storeEntry(models), lastModified, checkedAt: lastModified + 1 };
}

/** A store carrying no freshness timestamp at all. */
function undatedStore(models: ModelDefinition[]): StoredCatalog {
	return { models: storeEntry(models), checkedAt: GENERATED_AT + 1 };
}

const union = (over: Partial<Parameters<typeof buildUnion>[0]> = {}) =>
	buildUnion({
		baked: [baked("alpha"), baked("beta")],
		stored: undefined,
		generatedAt: GENERATED_AT,
		liveIds: undefined,
		modelsDev: undefined,
		providerId: "opencode-go",
		...over,
	});

const ids = (models: readonly ModelDefinition[]) => models.map((model) => model.id);

describe("isStoreNewerThanBaked", () => {
	it("applies a store newer than the baked data", () => {
		assert.equal(isStoreNewerThanBaked(stored([baked("x")], GENERATED_AT + 1), GENERATED_AT), true);
	});

	it("drops a store that is not newer than the baked data", () => {
		assert.equal(isStoreNewerThanBaked(stored([baked("x")], GENERATED_AT), GENERATED_AT), false, "equal is not newer");
		assert.equal(isStoreNewerThanBaked(stored([baked("x")], GENERATED_AT - 1), GENERATED_AT), false, "older is not newer");
	});

	it("drops a store with no timestamp, because freshness cannot be shown", () => {
		assert.equal(isStoreNewerThanBaked(undatedStore([baked("x")]), GENERATED_AT), false);
	});

	it("applies the store when the baked generation timestamp is unknown", () => {
		assert.equal(isStoreNewerThanBaked(stored([baked("x")], GENERATED_AT + 1), undefined), true, "pi applies it in this case, and so does the extension");
	});

	it("treats an absent or empty store as nothing to apply", () => {
		assert.equal(isStoreNewerThanBaked(undefined, GENERATED_AT), false);
		assert.equal(isStoreNewerThanBaked({ models: [] }, GENERATED_AT), false);
		assert.equal(isStoreNewerThanBaked({}, GENERATED_AT), false);
	});
});

describe("storeEntriesFor", () => {
	it("keeps only the entries belonging to the provider", () => {
		const entry = stored([baked("mine"), baked("theirs")], GENERATED_AT + 1);
		(entry.models as { provider?: string }[])[1].provider = "somebody-else";
		assert.deepEqual(ids(storeEntriesFor(entry, "opencode-go")), ["mine"]);
	});

	it("returns nothing for an absent store rather than throwing", () => {
		assert.deepEqual(storeEntriesFor(undefined, "opencode-go"), []);
		assert.deepEqual(storeEntriesFor({}, "opencode-go"), []);
	});
});

describe("mergeCatalogs", () => {
	it("replaces a matching id in place, keeping the base order", () => {
		const merged = mergeCatalogs([baked("a"), baked("b"), baked("c")], [baked("b", { name: "new-b" })]);
		assert.deepEqual(ids(merged), ["a", "b", "c"]);
		assert.equal(merged[1].name, "new-b");
	});

	it("appends an unknown id at the end", () => {
		assert.deepEqual(ids(mergeCatalogs([baked("a")], [baked("z")])), ["a", "z"]);
	});

	it("returns the base untouched for an empty overlay", () => {
		assert.deepEqual(ids(mergeCatalogs([baked("a")], [])), ["a"]);
	});
});

describe("buildUnion: the persisted pi.dev catalog survives", () => {
	it("serves a model only the store knows", () => {
		const result = union({ stored: stored([baked("alpha"), baked("space-bunny-free")], GENERATED_AT + 1) });
		assert.ok(ids(result).includes("space-bunny-free"), "the store-only model is served");
	});

	it("carries the store's metadata, not the baked fallback's", () => {
		const entry = baked("space-bunny-free", {
			name: "Space Bunny Free",
			contextWindow: 1_048_576,
			maxTokens: 524_288,
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
			input: ["text", "image"],
		});
		const served = union({ stored: stored([entry], GENERATED_AT + 1) }).find((model) => model.id === "space-bunny-free");
		assert.equal(served?.name, "Space Bunny Free");
		assert.equal(served?.contextWindow, 1_048_576);
		assert.equal(served?.maxTokens, 524_288);
		assert.equal(served?.cost?.input, 0, "a free model is not billed at the fallback model's rate");
		assert.deepEqual(served?.input, ["text", "image"]);
	});

	it("keeps the store's thinking-level map, so a level the store advertises is offered", () => {
		const entry = baked("space-bunny-free", {
			thinkingLevelMap: { off: null, minimal: null, low: "low", medium: "medium", high: "high", xhigh: "xhigh", max: "max" },
		});
		const served = union({ stored: stored([entry], GENERATED_AT + 1) }).find((model) => model.id === "space-bunny-free");
		assert.equal(served?.thinkingLevelMap?.xhigh, "xhigh");
		assert.equal(served?.thinkingLevelMap?.off, null);
	});

	it("serves the store in the offline phase, with no live ids at all", () => {
		const result = union({ stored: stored([baked("space-bunny-free")], GENERATED_AT + 1), liveIds: undefined });
		assert.ok(ids(result).includes("space-bunny-free"), "an absent live source cannot remove a store model");
	});

	it("serves the store when the live fetch failed", () => {
		const result = union({ stored: stored([baked("space-bunny-free")], GENERATED_AT + 1), liveIds: undefined, modelsDev: undefined });
		assert.deepEqual(ids(result), ["alpha", "beta", "space-bunny-free"]);
	});

	it("lets a fresher store entry replace a stale baked entry whole", () => {
		const result = union({
			baked: [baked("alpha", { name: "stale", contextWindow: 1 })],
			stored: stored([baked("alpha", { name: "fresh", contextWindow: 2 })], GENERATED_AT + 1),
		});
		const served = result.find((model) => model.id === "alpha");
		assert.equal(served?.name, "fresh", "the persisted catalog wins, as it does with no extension registered");
		assert.deepEqual(ids(result), ["alpha"], "a replacement is not a second entry");
	});
});

describe("buildUnion: an absent or stale source narrows, it never removes", () => {
	it("serves the baked catalog alone when there is no store and no live source", () => {
		assert.deepEqual(ids(union()), ["alpha", "beta"]);
	});

	it("ignores a store that is not newer than the baked data", () => {
		const result = union({ stored: stored([baked("stale-only")], GENERATED_AT - 1) });
		assert.deepEqual(ids(result), ["alpha", "beta"]);
	});

	it("ignores a store with no timestamp", () => {
		const result = union({ stored: undatedStore([baked("undated")]) });
		assert.deepEqual(ids(result), ["alpha", "beta"]);
	});

	it("ignores store entries belonging to another provider", () => {
		const entry = stored([baked("foreign")], GENERATED_AT + 1);
		(entry.models as { provider?: string }[])[0].provider = "opencode";
		assert.deepEqual(ids(union({ stored: entry })), ["alpha", "beta"]);
	});

	// The store here carries no freshness stamp, so the gate closes and the union
	// never reads the shape: this case states that a store the gate rejects
	// changes nothing, not that the union survives a corrupt one. The shape
	// check is held by the L2 and M7 invariant cases.
	it("keeps every baked model when the store carries no freshness stamp", () => {
		const result = union({ stored: { models: "not-an-array" } as unknown as StoredCatalog });
		assert.deepEqual(ids(result), ["alpha", "beta"]);
	});
});

describe("buildUnion: the live source", () => {
	it("adds a live-only id the other sources do not carry", () => {
		const result = union({ liveIds: ["alpha", "brand-new"] });
		assert.deepEqual(ids(result), ["alpha", "beta", "brand-new"]);
	});

	it("does not duplicate an id the baked catalog already carries", () => {
		const result = union({ liveIds: ["alpha", "beta"] });
		assert.deepEqual(ids(result), ["alpha", "beta"]);
	});

	it("does not duplicate an id the store already carries", () => {
		const result = union({ stored: stored([baked("alpha"), baked("from-store")], GENERATED_AT + 1), liveIds: ["from-store", "live-only"] });
		assert.deepEqual(ids(result), ["alpha", "beta", "from-store", "live-only"]);
	});

	it("de-duplicates repeats inside the live list itself", () => {
		assert.deepEqual(ids(union({ liveIds: ["twice", "twice"] })), ["alpha", "beta", "twice"]);
	});

	it("builds a live-only model from models.dev metadata when it has some", () => {
		const result = union({
			liveIds: ["live-only"],
			modelsDev: { "live-only": { name: "Live Only", limit: { context: 500_000, output: 32_000 }, reasoning_options: [{ type: "effort", values: ["low", "high"] }] } },
		});
		const served = result.find((model) => model.id === "live-only");
		assert.equal(served?.name, "Live Only");
		assert.equal(served?.contextWindow, 500_000);
		assert.equal(served?.maxTokens, 32_000);
		assert.equal(served?.thinkingLevelMap?.low, "low");
		assert.equal(served?.thinkingLevelMap?.off, null);
	});

	it("keeps the baked metadata when models.dev is unavailable", () => {
		const result = union({ baked: [baked("alpha", { contextWindow: 123_456 })], liveIds: ["live-only"], modelsDev: undefined });
		assert.equal(result.find((model) => model.id === "alpha")?.contextWindow, 123_456);
		assert.equal(result.find((model) => model.id === "live-only")?.name, "live-only", "defaults, not a crash");
	});

	it("reads an empty live list as the provider advertising nothing new", () => {
		assert.deepEqual(ids(union({ liveIds: [] })), ["alpha", "beta"]);
	});
});

describe("overlayBakedMetadata", () => {
	it("refreshes context, output limit, cost, and input from models.dev", () => {
		const model = overlayBakedMetadata(baked("m", { name: "keep-me" }), {
			limit: { context: 9, output: 8 },
			cost: { input: 1, output: 2, cache_read: 3, cache_write: 4 },
			modalities: { input: ["text", "image"] },
		});
		assert.equal(model.contextWindow, 9);
		assert.equal(model.maxTokens, 8);
		assert.deepEqual(model.cost, { input: 1, output: 2, cacheRead: 3, cacheWrite: 4 });
		assert.deepEqual(model.input, ["text", "image"]);
	});

	it("leaves the curated fields alone", () => {
		const original = baked("m", {
			name: "curated",
			api: "anthropic-messages",
			baseUrl: ANTHROPIC_BASE,
			reasoning: true,
			thinkingLevelMap: { high: "high" },
			compat: { thinkingFormat: "anthropic" },
		});
		const model = overlayBakedMetadata(original, { limit: { context: 9 } });
		assert.equal(model.name, "curated");
		assert.equal(model.api, "anthropic-messages");
		assert.equal(model.baseUrl, ANTHROPIC_BASE);
		assert.deepEqual(model.thinkingLevelMap, { high: "high" });
		assert.deepEqual(model.compat, { thinkingFormat: "anthropic" });
	});

	it("returns the model untouched when models.dev has no entry", () => {
		const original = baked("m");
		assert.equal(overlayBakedMetadata(original, undefined), original);
	});

	it("fills a missing cost field from the baked cost rather than zeroing it", () => {
		const model = overlayBakedMetadata(baked("m", { cost: { input: 7, output: 8, cacheRead: 9, cacheWrite: 10 } }), { cost: { output: 2 } });
		assert.deepEqual(model.cost, { input: 7, output: 2, cacheRead: 9, cacheWrite: 10 });
	});
});

describe("transportFor", () => {
	it("routes the anthropic-transport ids at the anthropic base url", () => {
		assert.deepEqual(transportFor("minimax-m3"), { api: "anthropic-messages", baseUrl: ANTHROPIC_BASE });
	});

	it("routes the responses-transport ids at the v1 base url", () => {
		assert.deepEqual(transportFor("gpt-6-luna"), { api: "openai-responses", baseUrl: V1_BASE });
	});

	it("routes everything else over chat completions", () => {
		assert.deepEqual(transportFor("anything-else"), { api: "openai-completions", baseUrl: V1_BASE });
	});
});

describe("normalizeInput", () => {
	it("keeps only the modalities pi accepts", () => {
		assert.deepEqual(normalizeInput(["text", "image", "audio"]), ["text", "image"]);
	});

	it("falls back to text when nothing survives", () => {
		assert.deepEqual(normalizeInput(["audio"]), ["text"]);
		assert.deepEqual(normalizeInput(undefined), ["text"]);
		assert.deepEqual(normalizeInput([]), ["text"]);
	});
});

describe("liveOnlyModelConfig", () => {
	it("names a model after its id when no catalog has a name", () => {
		assert.equal(liveOnlyModelConfig("x", undefined).name, "x");
	});
});
