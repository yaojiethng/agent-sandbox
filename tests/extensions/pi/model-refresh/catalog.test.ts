/**
 * The source union, as pure functions over arrays.
 *
 * Every case here is an error case the extension has hit or a rule the
 * declaration depends on. The tests are behavioural against `buildUnion`: no
 * network, no API key, no model runtime.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
	buildUnion,
	compatFor,
	derivedTransport,
	fillMissing,
	isStoreNewerThanBaked,
	metadataEntry,
	normalizeInput,
	sourceEntry,
	storeEntriesFor,
	transportFor,
	unionFirstWins,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import type { ModelDefinition, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";
import { PROVIDER_ID, TEST_DECL } from "./fixtures.ts";

const GENERATED_AT = 1_000_000;
const V1 = TEST_DECL.baseUrls["openai-completions"] as string;
const ANTHROPIC = TEST_DECL.baseUrls["anthropic-messages"] as string;

function baked(id: string, extra: Partial<ModelDefinition> = {}): ModelDefinition {
	return {
		id,
		name: id,
		api: "openai-completions",
		baseUrl: V1,
		reasoning: true,
		input: ["text"],
		cost: { input: 1, output: 2, cacheRead: 0, cacheWrite: 0 },
		contextWindow: 100_000,
		maxTokens: 8_000,
		...extra,
	};
}

function stored(models: ModelDefinition[], lastModified: number | undefined): StoredCatalog {
	return {
		models: models.map((model) => ({ ...model, provider: PROVIDER_ID })) as StoredCatalog["models"],
		lastModified,
		checkedAt: lastModified === undefined ? undefined : lastModified + 1,
	};
}

const undatedStore = (models: ModelDefinition[]): StoredCatalog => stored(models, undefined);

const union = (over: Partial<Parameters<typeof buildUnion>[0]> = {}) =>
	buildUnion({
		providerId: PROVIDER_ID,
		decl: TEST_DECL,
		baked: [baked("alpha"), baked("beta")],
		stored: undefined,
		generatedAt: GENERATED_AT,
		endpointIds: undefined,
		modelsDev: undefined,
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
		assert.deepEqual(ids(storeEntriesFor(entry, PROVIDER_ID)), ["mine"]);
	});

	it("returns nothing for an absent store rather than throwing", () => {
		assert.deepEqual(storeEntriesFor(undefined, PROVIDER_ID), []);
		assert.deepEqual(storeEntriesFor({}, PROVIDER_ID), []);
	});
});

describe("unionFirstWins: one rule, first-wins per field", () => {
	it("keeps the accumulator's field and takes only the ones it leaves undefined", () => {
		const merged = unionFirstWins([baked("a", { name: "earlier", reasoning: undefined })], [baked("a", { name: "later", reasoning: false })]);
		assert.equal(merged[0].name, "earlier", "the earlier source wins the field it supplies");
		assert.equal(merged[0].reasoning, false, "the later source fills the field the earlier one leaves undefined");
	});

	it("replaces in place, keeping the order", () => {
		const merged = unionFirstWins([baked("a"), baked("b"), baked("c")], [baked("b", { name: "filled" })]);
		assert.deepEqual(ids(merged), ["a", "b", "c"]);
	});

	it("appends an unknown id", () => {
		assert.deepEqual(ids(unionFirstWins([baked("a")], [baked("z")])), ["a", "z"]);
	});

	it("removes nothing: an id one list supplies stays", () => {
		assert.deepEqual(ids(unionFirstWins([baked("a")], [])), ["a"]);
	});

	it("ignores an entry with no usable id", () => {
		assert.deepEqual(ids(unionFirstWins([baked("a")], [{ ...baked("x"), id: "" } as ModelDefinition])), ["a"]);
	});

	it("fillMissing is the field rule on its own", () => {
		const filled = fillMissing({ ...baked("a", { name: "kept", maxTokens: undefined }) }, baked("a", { name: "ignored", maxTokens: 5 }));
		assert.equal(filled.name, "kept");
		assert.equal(filled.maxTokens, 5);
	});
});

describe("derivedTransport: the metadata names the adapter", () => {
	it("routes an @ai-sdk/openai id over the responses adapter, as pi bakes it", () => {
		assert.equal(derivedTransport(TEST_DECL, "gpt-6-luna", "@ai-sdk/openai"), "openai-responses");
	});

	it("routes an @ai-sdk/anthropic id over the messages adapter", () => {
		assert.equal(derivedTransport(TEST_DECL, "minimax-m3", "@ai-sdk/anthropic"), "anthropic-messages");
	});

	it("falls back to the gateway's completions surface", () => {
		assert.equal(derivedTransport(TEST_DECL, "anything-else", undefined), "openai-completions");
	});

	it("lets a declared id win over the metadata", () => {
		assert.equal(derivedTransport(TEST_DECL, "messages-only", "@ai-sdk/openai"), "anthropic-messages");
	});

	it("pairs the api with its base url, and an unclassified api with an empty one", () => {
		assert.deepEqual(transportFor(TEST_DECL, "minimax-m3", "@ai-sdk/anthropic"), { api: "anthropic-messages", baseUrl: ANTHROPIC });
		assert.deepEqual(transportFor(TEST_DECL, "anything-else", undefined), { api: "openai-completions", baseUrl: V1 });
	});
});

describe("compatFor: a default block plus id-prefix rules", () => {
	it("applies the default to an id no rule names", () => {
		assert.deepEqual(compatFor(TEST_DECL, "glm-5.3"), { supportsStore: false, supportsDeveloperRole: false, maxTokensField: "max_tokens" });
	});

	it("adds the prefix rule's fields for an id it names", () => {
		const compat = compatFor(TEST_DECL, "deepseek-v9-flash");
		assert.equal(compat.thinkingFormat, "deepseek");
		assert.equal(compat.requiresReasoningContentOnAssistantMessages, true);
		assert.equal(compat.maxTokensField, "max_tokens", "the default is carried under the rule, not replaced");
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

describe("buildUnion: the persisted pi.dev catalog survives", () => {
	it("serves a model only the store knows", () => {
		const result = union({ stored: stored([baked("alpha"), baked("space-bunny-free")], GENERATED_AT + 1) });
		assert.ok(ids(result).includes("space-bunny-free"), "the store-only model is served");
	});

	it("lets a fresher store entry fill a baked entry rather than vanish", () => {
		const result = union({ baked: [baked("alpha", { name: undefined })], stored: stored([baked("alpha", { name: "from-store" })], GENERATED_AT + 1) });
		assert.equal(result.find((model) => model.id === "alpha")?.name, "from-store");
		assert.deepEqual(ids(result), ["alpha"], "a fill is not a second entry");
	});

	it("keeps a baked field the store does not supply", () => {
		const result = union({ baked: [baked("alpha", { contextWindow: 7 })], stored: stored([baked("alpha", { contextWindow: undefined })], GENERATED_AT + 1) });
		assert.equal(result.find((model) => model.id === "alpha")?.contextWindow, 7, "first-wins leaves the baked value in place");
	});

	it("serves the store when no live source answered", () => {
		const result = union({ stored: stored([baked("space-bunny-free")], GENERATED_AT + 1), endpointIds: undefined, modelsDev: undefined });
		assert.deepEqual(ids(result), ["alpha", "beta", "space-bunny-free"]);
	});
});

describe("buildUnion: an absent or stale source narrows, it never removes", () => {
	it("serves the baked catalog alone when nothing else answered", () => {
		assert.deepEqual(ids(union()), ["alpha", "beta"]);
	});

	it("ignores a store that is not newer than the baked data", () => {
		assert.deepEqual(ids(union({ stored: stored([baked("stale-only")], GENERATED_AT - 1) })), ["alpha", "beta"]);
	});

	it("ignores a store with no timestamp", () => {
		assert.deepEqual(ids(union({ stored: undatedStore([baked("undated")]) })), ["alpha", "beta"]);
	});

	it("ignores store entries belonging to another provider", () => {
		const entry = stored([baked("foreign")], GENERATED_AT + 1);
		(entry.models as { provider?: string }[])[0].provider = "opencode";
		assert.deepEqual(ids(union({ stored: entry })), ["alpha", "beta"]);
	});

	it("keeps every baked model when the store carries no freshness stamp", () => {
		assert.deepEqual(ids(union({ stored: { models: "not-an-array" } as unknown as StoredCatalog })), ["alpha", "beta"]);
	});
});

describe("buildUnion: the endpoint adds ids and overrides the fields it carries", () => {
	it("adds an endpoint-only id", () => {
		assert.deepEqual(ids(union({ endpointIds: ["alpha", "brand-new"] })), ["alpha", "beta", "brand-new"]);
	});

	it("does not duplicate an id another source carries", () => {
		assert.deepEqual(ids(union({ endpointIds: ["alpha", "beta"] })), ["alpha", "beta"]);
	});

	it("de-duplicates repeats inside the endpoint list itself", () => {
		assert.deepEqual(ids(union({ endpointIds: ["twice", "twice"] })), ["alpha", "beta", "twice"]);
	});

	it("lets the endpoint's derived transport win over the baked entry's", () => {
		const served = union({ endpointIds: ["messages-only"] }).find((model) => model.id === "messages-only");
		assert.equal(served?.api, "anthropic-messages");
		assert.equal(served?.baseUrl, ANTHROPIC);
	});

	it("leaves a field the endpoint does not carry to the baked entry", () => {
		const served = union({ baked: [baked("alpha", { compat: { thinkingFormat: "curated" } })], endpointIds: ["alpha"] }).find((model) => model.id === "alpha");
		assert.deepEqual(served?.compat, { thinkingFormat: "curated" }, "the endpoint carries no compat, so it cannot override one");
	});

	it("reads an empty endpoint list as the provider advertising nothing new", () => {
		assert.deepEqual(ids(union({ endpointIds: [] })), ["alpha", "beta"]);
	});
});

describe("buildUnion: models.dev supplies fields and no ids", () => {
	it("does not serve an id only models.dev carries", () => {
		const result = union({ modelsDev: { "dev-only": { name: "Dev Only", limit: { context: 500_000 } } } });
		assert.deepEqual(ids(result), ["alpha", "beta"], "a metadata source invents no model");
	});

	it("fills an endpoint-only id's fields from models.dev", () => {
		const result = union({
			endpointIds: ["live-only"],
			modelsDev: { "live-only": { name: "Live Only", limit: { context: 500_000, output: 32_000 }, reasoning_options: [{ type: "effort", values: ["low", "high"] }] } },
		});
		const served = result.find((model) => model.id === "live-only");
		assert.equal(served?.name, "Live Only");
		assert.equal(served?.contextWindow, 500_000);
		assert.equal(served?.maxTokens, 32_000);
		assert.equal(served?.thinkingLevelMap?.low, "low");
		assert.equal(served?.thinkingLevelMap?.off, null);
	});

	it("leaves a baked field alone even when models.dev carries a value", () => {
		const result = union({
			baked: [baked("alpha", { name: "curated", contextWindow: 7 })],
			modelsDev: { alpha: { name: "dev", limit: { context: 999 } } },
		});
		const served = result.find((model) => model.id === "alpha");
		assert.equal(served?.name, "curated", "models.dev does not override");
		assert.equal(served?.contextWindow, 7);
	});
});

describe("metadataEntry and sourceEntry build the fallback entries", () => {
	it("names a model after its id when no catalog has a name", () => {
		assert.equal(metadataEntry(TEST_DECL, "x", undefined).name, "x");
		assert.deepEqual(sourceEntry(TEST_DECL, "x"), { id: "x", api: "openai-completions", baseUrl: V1 });
	});

	it("carries the declared thinking names into the level map", () => {
		const entry = metadataEntry(TEST_DECL, "x", { reasoning_options: [{ type: "effort", values: ["none", "low"] }] });
		assert.equal(entry.thinkingLevelMap?.off, "none", "the provider's name for off maps onto off");
		assert.equal(entry.thinkingLevelMap?.low, "low");
		assert.equal(entry.thinkingLevelMap?.high, null);
	});
});
