/**
 * The invariant suite: the rules this extension must not break, each held by a
 * case, and a report that names the invariant behind every red line.
 *
 * The cases read their expectations from the record (README.md) and from pi's
 * own shipped code, never by calling the function under test to rebuild its own
 * expectation. A provenance case that rebuilt its expectation with the same
 * helper would prove only that two calls agree.
 *
 * `mutation/catalog.ts` then asks the other question: whether a green suite is
 * evidence. It breaks the extension, one named invariant at a time, and fails
 * unless a case names that invariant when it goes red.
 */

import { after, describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";

import {
	buildUnion,
	compatFor,
	derivedTransport,
	fillMissing,
	isStoreNewerThanBaked,
	metadataEntry,
	sourceEntry,
	storeEntriesFor,
	unionFirstWins,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import { DECLARATIONS_PATH, loadDeclarations, parseDeclarations } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/config.ts";
import { gatherAndBuild } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts";
import { THINKING_LEVELS, levelMapFor, offSendsAnEffort, thinkingLevelMapFromEfforts } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import type { ThinkingLevelMap } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import type { ModelDefinition, ModelsDevModel, ProviderDecl, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";
import { UNION_SOURCES, buildCatalog, renderReport, type CaseResult } from "./invariants.ts";
import { PROVIDER_ID, TEST_DECL, V1_BASE as V1, ANTHROPIC_BASE as ANTHROPIC, bakedModel, anthropicBakedModel, captureThinkingPayload, effortList, makeRng, modelsDevEntry, pick, someModels, storedCatalog, storedEntry } from "./fixtures.ts";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;
const PI_AI = `${PI_PACKAGE_GLOBAL}/node_modules/@earendil-works/pi-ai`;
const COMPOSER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/provider-composer.js`;
const RESOLVER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/model-resolver.js`;
const REMOTE_CATALOG_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/remote-catalog-provider.js`;
const BAKED_CATALOG = `${PI_AI}/dist/providers/all.js`;
const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/model-refresh";
const EXTENSION_ENTRY = path.resolve(`${EXTENSION_DIR}/index.ts`);

const suite = fs.existsSync(PI_PACKAGE_ENTRY) ? {} : { skip: "pi installation not present" };

/** The baked data's generation timestamp, a constant so no case reads a clock. */
const GENERATED_AT = 1_000_000;
/** Property cases run this many generated catalogs per source. */
const TRIALS = 25;

/** One row of the source matrix: every declared source in one state. */
interface SourceState {
	baked: readonly ModelDefinition[];
	stored: StoredCatalog | undefined;
	endpointIds: readonly string[] | undefined;
	modelsDev: Record<string, ModelsDevModel> | undefined;
}

const BAKED_A = anthropicBakedModel("baked-a", { name: "Curated A", compat: { thinkingFormat: "anthropic", maxTokensField: "max_tokens" }, thinkingLevelMap: { high: "high" }, contextWindow: 111_000, maxTokens: 11_000 });
const BAKED_B = bakedModel("baked-b", { name: "Curated B", input: ["text", "image"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 222_000, maxTokens: 22_000 });
const BAKED_C = bakedModel("baked-c", { contextWindow: 333_000, maxTokens: 33_000 });
const BAKED = [BAKED_A, BAKED_B, BAKED_C];

/** The models.dev blob: two baked entries described unevenly, and one endpoint-only id. */
const MODELS_DEV: Record<string, ModelsDevModel> = {
	...modelsDevEntry("baked-a", { name: "Refreshed A", limit: { context: 999_000, output: 99_000 }, cost: { input: 3, output: 4, cache_read: 0.5, cache_write: 1.5 }, modalities: { input: ["text", "image"] } }),
	...modelsDevEntry("baked-b", { modalities: { input: ["text", "audio"] } }),
	...modelsDevEntry("baked-c", { cost: { input: 7 } }),
	...modelsDevEntry("live-only", { name: "Live Only", reasoning_options: effortList(["none", "low", "high"]), limit: { context: 500_000, output: 32_000 }, modalities: { input: ["text", "audio"] }, provider: { npm: "@ai-sdk/openai" } }),
};

const STORE_STATES: readonly (StoredCatalog | undefined)[] = [
	undefined,
	storedCatalog(PROVIDER_ID, [], GENERATED_AT + 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-fresh", { contextWindow: 333_000 })], GENERATED_AT + 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-stale", { contextWindow: 7 })], GENERATED_AT - 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-undated")], undefined),
	{ models: [storedEntry(PROVIDER_ID, "store-equal"), storedEntry("opencode", "store-foreign")] as StoredCatalog["models"], lastModified: GENERATED_AT },
	{ models: "not-an-array" } as unknown as StoredCatalog,
];

const ENDPOINT_STATES: readonly (readonly string[] | undefined)[] = [undefined, [], ["live-only", "baked-a"]];

const MODELS_DEV_STATES: readonly (Record<string, ModelsDevModel> | undefined)[] = [undefined, {}, MODELS_DEV];

const MATRIX: SourceState[] = [BAKED, []].flatMap((baked) =>
	STORE_STATES.flatMap((stored) => ENDPOINT_STATES.flatMap((endpointIds) => MODELS_DEV_STATES.map((modelsDev) => ({ baked, stored, endpointIds, modelsDev })))),
);

// --- reading the union ----------------------------------------------------

const ids = (models: readonly ModelDefinition[]): string[] => models.map((model) => model.id);
const union = (row: Partial<SourceState> & { baked?: readonly ModelDefinition[] } = {}): ModelDefinition[] =>
	buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, baked: BAKED, stored: undefined, generatedAt: GENERATED_AT, endpointIds: undefined, modelsDev: undefined, ...row });

/**
 * Whether the store a row carries is one the union applies. The gate is
 * restated here rather than read from the product, so M1 and M3 do not inherit
 * a bug from the function they are checking; G1 pins the product's own gate.
 */
function storeApplies(stored: StoredCatalog | undefined): boolean {
	return Array.isArray(stored?.models) && stored.models.length > 0 && stored.lastModified !== undefined && stored.lastModified > GENERATED_AT;
}

/** Every field pi's Model type carries, so a served entry's whole key set is compared. */
const MODEL_FIELDS: readonly (keyof ModelDefinition)[] = ["id", "name", "api", "baseUrl", "reasoning", "thinkingLevelMap", "input", "cost", "contextWindow", "maxTokens", "compat"];

/** The modalities pi's model type accepts, or text when a source names none. */
function expectedInput(modalities: readonly string[] | undefined): ("text" | "image")[] {
	const kept = (modalities ?? []).filter((modality): modality is "text" | "image" => modality === "text" || modality === "image");
	return kept.length > 0 ? kept : ["text"];
}

// --- pi's own code, read for the differential cases ------------------------

async function loadPiModule<T>(entry: string): Promise<T> {
	return (await import(entry)) as T;
}

async function loadRegistration(): Promise<{ id: string; config: Record<string, unknown> }[]> {
	const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
	const { createJiti } = (await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"))) as {
		createJiti: (entry: string, options: { alias: Record<string, string> }) => { import: (entry: string) => Promise<{ default: (pi: unknown) => void }> };
	};
	const jiti = createJiti(EXTENSION_ENTRY, {
		alias: {
			"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
			"@earendil-works/pi-ai": `${PI_AI}/dist/index.js`,
			"@earendil-works/pi-ai/providers/all": `${PI_AI}/dist/providers/all.js`,
			typebox: requireFromPi.resolve("typebox"),
			"@sinclair/typebox": requireFromPi.resolve("typebox"),
		},
	});
	const registered: { id: string; config: Record<string, unknown> }[] = [];
	const module = await jiti.import(EXTENSION_ENTRY);
	module.default({
		registerProvider: (id: string, config: Record<string, unknown>) => registered.push({ id, config }),
		on: () => () => {},
	});
	return registered;
}

// --- the report ------------------------------------------------------------

const results: CaseResult[] = [];
const catalog = buildCatalog();
const registered: string[] = [];

function errorMessage(e: unknown): string {
	return e instanceof Error ? e.message : String(e);
}

function statementOf(id: string, name: string): string {
	const entry = catalog.find((candidate) => candidate.id === id && candidate.name === name);
	assert.ok(entry, `the catalog carries a case for ${id} ${name}`);
	return entry!.statement;
}

function itCase(id: string, name: string, body: () => Promise<void> | void): void {
	registered.push(`${id} ${name}`);
	it(`INV ${id} -- ${statementOf(id, name)}`, suite, async () => {
		await check(id, name, body);
	});
}

async function check(id: string, name: string, body: () => Promise<void> | void): Promise<void> {
	const entry = catalog.find((candidate) => candidate.id === id && candidate.name === name);
	assert.ok(entry, `the catalog carries a case for ${id} ${name}`);
	try {
		await body();
		results.push({ ...entry!, outcome: "pass" });
	} catch (e) {
		results.push({ ...entry!, outcome: "fail", detail: errorMessage(e).split("\n")[0] });
		throw e;
	}
}

const REQUIRED_STRINGS = ["id", "name", "api", "baseUrl"] as const;
const REQUIRED_NUMBERS = ["contextWindow", "maxTokens"] as const;
const COST_FIELDS = ["input", "output", "cacheRead", "cacheWrite"] as const;

function assertValidModel(model: ModelDefinition): void {
	for (const field of REQUIRED_STRINGS) {
		assert.equal(typeof model[field], "string", `${model.id}: ${field} is a string`);
		assert.ok((model[field] as string).length > 0, `${model.id}: ${field} is not empty`);
	}
	assert.equal(typeof model.reasoning, "boolean", `${model.id}: reasoning is a boolean`);
	assert.ok(Array.isArray(model.input) && model.input.length > 0, `${model.id}: input is a non-empty array`);
	for (const modality of model.input ?? []) {
		assert.ok(modality === "text" || modality === "image", `${model.id}: input carries only text and image, got ${String(modality)}`);
	}
	assert.ok(model.cost !== undefined, `${model.id}: cost is present`);
	for (const field of COST_FIELDS) {
		assert.equal(typeof model.cost?.[field], "number", `${model.id}: cost.${field} is a number`);
		assert.ok(Number.isFinite(model.cost?.[field]), `${model.id}: cost.${field} is finite`);
	}
	for (const field of REQUIRED_NUMBERS) {
		assert.equal(typeof model[field], "number", `${model.id}: ${field} is a number`);
		assert.ok(Number.isFinite(model[field] as number), `${model.id}: ${field} is finite`);
		assert.ok((model[field] as number) > 0, `${model.id}: ${field} is greater than zero, got ${String(model[field])}`);
	}
}

describe("invariant report", () => {
	after(() => {
		process.stdout.write(`\n${renderReport(results)}\n`);
	});

	// --- the union ------------------------------------------------------

	itCase("M1", "non-empty", () => {
		for (const row of MATRIX) {
			const served = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, generatedAt: GENERATED_AT, ...row });
			if (row.baked.length === 0) continue;
			assert.ok(served.length > 0, `baked entries survive every source state, got ${JSON.stringify(ids(served))}`);
		}
	});

	itCase("M3", "provenance", () => {
		for (const row of MATRIX) {
			const served = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, generatedAt: GENERATED_AT, ...row });
			const allowed = new Set<string>([
				...row.baked.map((m) => m.id),
				...(storeApplies(row.stored) ? storeEntriesFor(row.stored, PROVIDER_ID).map((m) => m.id) : []),
				...(Array.isArray(row.endpointIds) ? row.endpointIds : []),
			]);
			for (const id of ids(served)) {
				assert.ok(allowed.has(id), `${id} was supplied by a declared source`);
			}
		}
		// A model the primary sources do not carry takes the metadata's own fields.
		const liveOnly = union({ endpointIds: ["live-only"], modelsDev: MODELS_DEV }).find((m) => m.id === "live-only");
		assert.equal(liveOnly?.name, "Live Only", "the metadata's name is served");
		assert.equal(liveOnly?.contextWindow, 500_000, "the metadata's context window is served");
		assert.equal(liveOnly?.maxTokens, 32_000, "the metadata's output limit is served");
	});

	itCase("U4", "metadata silence", () => {
		// An id only models.dev lists is not served.
		const devOnly = union({ modelsDev: { "dev-only": { name: "Dev Only" } } });
		assert.ok(!ids(devOnly).includes("dev-only"), "models.dev invents no model");
		// A metadata source fills only what the delivered entry leaves undefined.
		const served = union({ modelsDev: MODELS_DEV });
		const a = served.find((m) => m.id === "baked-a");
		assert.equal(a?.name, "Curated A", "the baked name stands: models.dev does not override");
		assert.equal(a?.contextWindow, BAKED_A.contextWindow, "the baked limit stands too: models.dev does not override");
		const b = served.find((m) => m.id === "baked-b");
		assert.deepEqual(b?.cost, BAKED_B.cost, "a field the metadata is silent about keeps the baked value");
	});

	itCase("U1", "first-wins per field", () => {
		const merged = unionFirstWins([{ id: "x", name: "first", reasoning: undefined } as ModelDefinition], [{ id: "x", name: "second", reasoning: false } as ModelDefinition]);
		assert.equal(merged[0].name, "first", "the first source wins the field it supplies");
		assert.equal(merged[0].reasoning, false, "a later source fills only the field left undefined");
		const filled = fillMissing({ id: "y", name: "kept", maxTokens: undefined } as ModelDefinition, { id: "y", name: "ignored", maxTokens: 5 } as ModelDefinition);
		assert.equal(filled.name, "kept");
		assert.equal(filled.maxTokens, 5);
	});

	itCase("U2", "the override fold order", () => {
		const stored = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "messages-only")], GENERATED_AT + 1);
		const endpointFirst: ProviderDecl = { ...TEST_DECL, sources: [{ kind: "baked" }, { kind: "endpoint", override: true }, { kind: "pi-dev", override: true }] };
		const storeFirst: ProviderDecl = { ...TEST_DECL, sources: [{ kind: "baked" }, { kind: "pi-dev", override: true }, { kind: "endpoint", override: true }] };
		const a = union({ decl: endpointFirst, stored, endpointIds: ["messages-only"] }).find((m) => m.id === "messages-only");
		assert.equal(a?.api, "anthropic-messages", "the endpoint is listed first, so it is the strongest");
		const b = union({ decl: storeFirst, stored, endpointIds: ["messages-only"] }).find((m) => m.id === "messages-only");
		assert.equal(b?.api, "openai-completions", "listed first now, so the persisted catalog is the strongest");
	});

	itCase("U3", "the served order", () => {
		const served = ids(union({ endpointIds: ["baked-b", "brand-new"], stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "from-store")], GENERATED_AT + 1) }));
		assert.deepEqual(served.slice(0, 3), ["baked-a", "baked-b", "baked-c"], "the baked order is kept");
		for (const introduced of ["brand-new", "from-store"]) {
			assert.ok(served.indexOf(introduced) >= 3, `${introduced} is appended, not moved to the front`);
		}
	});

	itCase("M4", "unique ids", () => {
		for (const row of MATRIX) {
			const served = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, generatedAt: GENERATED_AT, ...row });
			assert.equal(new Set(ids(served)).size, served.length, `each id once: ${JSON.stringify(ids(served))}`);
		}
		const repeats = union({ endpointIds: ["twice", "twice"] });
		assert.equal(ids(repeats).filter((id) => id === "twice").length, 1, "a repeat inside one source is collapsed");
	});

	itCase("M5", "a valid model", () => {
		for (const row of MATRIX) {
			const served = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, generatedAt: GENERATED_AT, ...row });
			for (const model of served) assertValidModel(model);
		}
	});

	itCase("M7", "a usable entry", () => {
		const malformed = { models: [{ name: "no id", provider: PROVIDER_ID }, { id: "", provider: PROVIDER_ID }, { id: "kept", api: "openai-completions", baseUrl: V1, provider: PROVIDER_ID }], lastModified: GENERATED_AT + 1 } as unknown as StoredCatalog;
		assert.deepEqual(ids(storeEntriesFor(malformed, PROVIDER_ID)), ["kept"], "an entry pi cannot key on is dropped before the union");
		const served = union({ stored: malformed });
		assert.ok(ids(served).includes("kept"), "the usable entry survives");
		// The union's own guard, reached by a source whose entries no provider
		// filter screens: an id pi cannot key on must not be appended either.
		const guarded = unionFirstWins([bakedModel("a")], [{ ...bakedModel("b"), id: "" } as ModelDefinition, { ...bakedModel("c"), id: 42 } as unknown as ModelDefinition]);
		assert.deepEqual(ids(guarded), ["a"], "the union drops an entry with no usable id");
	});

	itCase("M8", "the transport follows pi and the metadata", async () => {
		if (!fs.existsSync(BAKED_CATALOG)) return;
		const { getBuiltinModels } = await loadPiModule<{ getBuiltinModels: (id: string) => ModelDefinition[] }>(BAKED_CATALOG);
		// The provider SDK models.dev labels each id with, measured 2026-10-03. All
		// other ids in the blob carry no label, and an unlabelled id is served over
		// the gateway's completions surface, which is what pi bakes for most of them.
		const labelled: Record<string, string> = {};
		for (const id of ["minimax-m2.7", "minimax-m3", "qwen3.8-flash"]) labelled[id] = "@ai-sdk/anthropic";
		for (const id of ["gpt-5.6-luna", "gpt-6-luna", "grok-4.5", "grok-4.6", "grok-4.7", "muse-spark-1.2-contributor", "muse-spark-1.3-contributor"]) labelled[id] = "@ai-sdk/openai";
		for (const baked of getBuiltinModels(PROVIDER_ID)) {
			assert.equal(derivedTransport(TEST_DECL, baked.id, labelled[baked.id]), baked.api, `${baked.id} keeps the adapter pi encodes`);
		}
		assert.equal(derivedTransport(TEST_DECL, "x", "@ai-sdk/openai"), "openai-responses", "the metadata's OpenAI SDK names the responses adapter");
		assert.equal(derivedTransport(TEST_DECL, "x", "@ai-sdk/anthropic"), "anthropic-messages");
		assert.equal(derivedTransport(TEST_DECL, "messages-only", "@ai-sdk/openai"), "anthropic-messages", "a declared entry wins over the metadata");
	});

	itCase("M6", "purity", () => {
		const baked = [bakedModel("p-a")];
		const snapshot = JSON.stringify(baked);
		const first = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, baked, stored: undefined, generatedAt: GENERATED_AT, endpointIds: ["p-b"], modelsDev: MODELS_DEV });
		assert.equal(JSON.stringify(baked), snapshot, "the input is not mutated");
		first.push(bakedModel("extra"));
		const second = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, baked, stored: undefined, generatedAt: GENERATED_AT, endpointIds: ["p-b"], modelsDev: MODELS_DEV });
		assert.ok(!ids(second).includes("extra"), "each call returns a fresh list");
	});

	// --- the store gate -------------------------------------------------

	itCase("G1", "the exact gate", () => {
		assert.equal(isStoreNewerThanBaked(storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "s")], GENERATED_AT + 1), GENERATED_AT), true);
		assert.equal(isStoreNewerThanBaked(storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "s")], GENERATED_AT), GENERATED_AT), false, "equal is not newer");
		assert.equal(isStoreNewerThanBaked(storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "s")], GENERATED_AT - 1), GENERATED_AT), false);
		assert.equal(isStoreNewerThanBaked(storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "s")], undefined), GENERATED_AT), false, "no stamp, no application");
		assert.equal(isStoreNewerThanBaked(storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "s")], GENERATED_AT + 1), undefined), true, "pi applies it when the baked stamp is unknown");
		for (const stored of STORE_STATES) {
			const served = union({ stored });
			const applies = storeApplies(stored);
			for (const entry of storeEntriesFor(stored, PROVIDER_ID)) {
				assert.equal(ids(served).includes(entry.id), applies, `${entry.id} is served iff the gate opens`);
			}
		}
	});

	itCase("G2", "the store's fields win", () => {
		const stored = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "baked-a", { name: "From Store", maxTokens: undefined })], GENERATED_AT + 1);
		const served = union({ stored }).find((m) => m.id === "baked-a");
		assert.equal(served?.name, "Stored baked-a", "the store supplies the name");
		assert.equal(served?.maxTokens, BAKED_A.maxTokens, "a field the store omits keeps the baked value");
		assert.equal(ids(union({ stored }))[0], "baked-a", "the entry keeps its baked position");
	});

	itCase("G2", "agrees with pi", async () => {
		if (!fs.existsSync(REMOTE_CATALOG_ENTRY)) return;
		const { withRemoteCatalog } = await loadPiModule<{ withRemoteCatalog: (p: unknown, url: string | undefined, at: number | undefined) => { refreshModels: (c: unknown) => Promise<void>; getModels: () => ModelDefinition[] } }>(REMOTE_CATALOG_ENTRY);
		const baseline = [...BAKED];
		const provider = { id: PROVIDER_ID, name: "b", auth: {}, getModels: () => baseline, getAllModels: () => baseline };
		const wrapped = withRemoteCatalog(provider, "http://localhost", GENERATED_AT);
		const stored = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "baked-a", { contextWindow: 999_000, type: "chat" } as never), storedEntry(PROVIDER_ID, "added", { type: "chat" } as never)], GENERATED_AT + 1);
		const publish = async (payload: { update?: () => void }) => {
			payload.update?.();
			return true;
		};
		await wrapped.refreshModels({ stored, publish, allowNetwork: false, signal: new AbortController().signal });
		const piServed = wrapped.getModels();
		const ours = union({ stored });
		assert.deepEqual(ids(ours).sort(), ids(piServed).sort(), "the same id set as pi's own overlay");
		assert.equal(ours.find((m) => m.id === "baked-a")?.contextWindow, piServed.find((m) => m.id === "baked-a")?.contextWindow, "and the same value for the replaced entry");
	});

	itCase("G3", "provider scope", () => {
		const stored: StoredCatalog = { models: [storedEntry(PROVIDER_ID, "mine"), storedEntry("somebody-else", "theirs")] as StoredCatalog["models"], lastModified: GENERATED_AT + 1 };
		assert.deepEqual(ids(storeEntriesFor(stored, PROVIDER_ID)), ["mine"]);
		assert.deepEqual(ids(storeEntriesFor(undefined, PROVIDER_ID)), []);
		assert.ok(!ids(union({ stored })).includes("theirs"));
	});

	// --- failure narrowing ----------------------------------------------

	itCase("L1", "the baked catalog always survives", () => {
		const optional = [STORE_STATES, ENDPOINT_STATES, MODELS_DEV_STATES];
		for (const stored of optional[0]) {
			for (const endpointIds of optional[1]) {
				for (const modelsDev of optional[2]) {
					const baked = someModels(makeRng(1), 4, "keep");
					const served = union({ baked, stored, endpointIds, modelsDev });
					for (const model of baked) assert.ok(ids(served).includes(model.id), `${model.id} survives every source state`);
				}
			}
		}
	});

	itCase("L2", "a malformed source removes nothing", () => {
		const shapes: unknown[] = [
			undefined,
			null,
			{},
			{ models: "no" },
			{ data: "no" },
			{ data: [{}] },
			{ data: [{ id: "" }] },
			["", "a-real-id"],
			42,
			[],
			// A tagged entry whose id is missing or not a string: the provider filter
			// cannot mask the id check here, so the shape is what rejects it.
			{ models: [{ name: "no id", provider: PROVIDER_ID }], lastModified: GENERATED_AT + 1 },
			{ models: [{ id: 42, provider: PROVIDER_ID }], lastModified: GENERATED_AT + 1 },
		];
		for (const shape of shapes) {
			const served = union({ stored: shape as StoredCatalog, endpointIds: shape as string[], modelsDev: shape as Record<string, ModelsDevModel> });
			for (const model of BAKED) assert.ok(ids(served).includes(model.id), `${model.id} survives the shape ${JSON.stringify(shape)}`);
			for (const model of served) assertValidModel(model);
		}
	});

	// --- the composition contract ---------------------------------------

	itCase("C1", "registration never shrinks the catalog", async () => {
		if (!fs.existsSync(COMPOSER_ENTRY)) return;
		const { composeModelProvider } = await loadPiModule<{ composeModelProvider: (id: string, base: unknown, config: unknown, ext: unknown) => { getModels: () => ModelDefinition[]; refreshModels?: (c: unknown) => Promise<void> } }>(COMPOSER_ENTRY);
		const base = { id: PROVIDER_ID, name: "b", auth: { apiKey: {} }, getModels: () => [...BAKED], refreshModels: async () => {} };
		const config = { getProvider: () => undefined, getProviderIds: () => [] };
		const { fetchJson } = await loadPiModule<{ fetchJson: unknown }>(path.resolve(`${EXTENSION_DIR}/refresh.ts`));
		const extension = { refreshModels: (context: { signal: AbortSignal; allowNetwork: boolean; stored?: StoredCatalog }) => gatherAndBuild({ providerId: PROVIDER_ID, decl: TEST_DECL, signal: context.signal, allowNetwork: context.allowNetwork, stored: context.stored, generatedAt: GENERATED_AT, baked: BAKED, fetcher: async () => ({}) as never }) };
		const composed = composeModelProvider(PROVIDER_ID, base, config, extension);
		await composed.refreshModels?.({ stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "from-store")], GENERATED_AT + 1), publish: async (payload: { update?: () => void }) => { payload.update?.(); return true; }, allowNetwork: false, signal: new AbortController().signal });
		const served = composed.getModels();
		for (const model of BAKED) assert.ok(ids(served).includes(model.id), `${model.id} survives registration`);
		assert.ok(ids(served).includes("from-store"), "and the store-only model is served, not dropped by the registration");
		assert.ok(fetchJson !== undefined);
	});

	itCase("C2", "no silent fallback", async () => {
		if (!fs.existsSync(RESOLVER_ENTRY) || !fs.existsSync(BAKED_CATALOG)) return;
		const { getBuiltinModels } = await loadPiModule<{ getBuiltinModels: (id: string) => ModelDefinition[] }>(BAKED_CATALOG);
		const served = union({ baked: getBuiltinModels(PROVIDER_ID) as unknown as ModelDefinition[] });
		for (const model of served) {
			assert.ok((model.contextWindow ?? 0) > 0, `${model.id} carries its own context window, not a fallback clone's`);
		}
	});

	itCase("C3", "user overrides win", async () => {
		if (!fs.existsSync(COMPOSER_ENTRY)) return;
		const { composeModelProvider } = await loadPiModule<{ composeModelProvider: (id: string, base: unknown, config: unknown, ext: unknown) => { getModels: () => ModelDefinition[] } }>(COMPOSER_ENTRY);
		const base = { id: PROVIDER_ID, name: "b", auth: { apiKey: {} }, getModels: () => [...BAKED] };
		const config = { getProvider: () => ({ modelOverrides: { "baked-a": { contextWindow: 42 } } }), getProviderIds: () => [PROVIDER_ID] };
		const composed = composeModelProvider(PROVIDER_ID, base, config, undefined);
		assert.equal(composed.getModels().find((m) => m.id === "baked-a")?.contextWindow, 42, "models.json is the top layer");
	});

	// --- thinking levels ------------------------------------------------

	itCase("T1", "derived levels", () => {
		const map = thinkingLevelMapFromEfforts(["low", "high"]);
		for (const level of THINKING_LEVELS) assert.ok(level in map, `${level} has an explicit entry`);
		assert.equal(map.medium, null, "a level the endpoint does not name is unsupported");
	});

	itCase("T2", "off is the endpoint's disabled state", () => {
		assert.equal(thinkingLevelMapFromEfforts(["none", "low"], { offEffort: "none" }).off, "none", "the declared disabled-effort name maps onto off");
		assert.equal(thinkingLevelMapFromEfforts(["low"], { offEffort: "none" }).off, null, "no disabled effort named, so off is unsupported");
		assert.equal(offSendsAnEffort({ off: "none" }), true);
		assert.equal(offSendsAnEffort({ off: null }), false);
	});

	itCase("T3", "the map follows the endpoint", () => {
		assert.equal(levelMapFor(["low", "high"]).medium, null);
		const fallback = { fallbackEfforts: { low: "low", high: "high" } };
		assert.equal(levelMapFor(undefined, fallback).max, null, "the fallback stops at high");
		assert.equal(levelMapFor(undefined, fallback).low, "low", "the declared fallback ladder is served");
		assert.equal(levelMapFor(undefined, fallback).high, "high");
		assert.equal(levelMapFor([], fallback).off, null);
	});

	itCase("T3", "the family keeps its compat", () => {
		const compat = compatFor(TEST_DECL, "deepseek-v9-flash");
		assert.equal(compat.thinkingFormat, "deepseek");
		assert.equal(compat.maxTokensField, "max_tokens", "the default block is carried under the prefix rule");
		assert.equal(compatFor(TEST_DECL, "glm-5.3").thinkingFormat, undefined);
		assert.equal(metadataEntry(TEST_DECL, "deepseek-v9-flash", undefined).compat?.thinkingFormat, "deepseek");
	});

	itCase("W1", "the wire shape follows the map", async () => {
		if (!fs.existsSync(BAKED_CATALOG)) return;
		const model = bakedModel("wire", { compat: { supportsStore: false, supportsDeveloperRole: false, maxTokensField: "max_tokens" }, thinkingLevelMap: thinkingLevelMapFromEfforts(["low", "high"]) });
		const payload = await captureThinkingPayload(model, "off");
		assert.equal(payload.reasoning_effort, "low", "an unsupported off clamps up to the nearest advertised level, so pi sends low, not an off effort");
		const high = await captureThinkingPayload(model, "high");
		assert.equal(high.reasoning_effort, "high", "an advertised level sends its mapped effort");
	});

	itCase("D1", "determinism", () => {
		for (let trial = 0; trial < TRIALS; trial++) {
			const rng = makeRng(trial);
			const row = { baked: someModels(rng, 4, `d${trial}`), endpointIds: pick(rng, ENDPOINT_STATES), modelsDev: pick(rng, MODELS_DEV_STATES), stored: pick(rng, STORE_STATES) };
			const first = ids(union(row));
			const second = ids(union(row));
			assert.deepEqual(second, first, `trial ${trial} is stable`);
		}
	});

	itCase("C4", "the registration names the provider", async () => {
		const declarations = loadDeclarations();
		const registeredProviders = await loadRegistration();
		assert.deepEqual(registeredProviders.map((entry) => entry.id).sort(), Object.keys(declarations).sort(), "one registration per declaration key");
	});

	itCase("N1", "the declaration validates", () => {
		const parsed = parseDeclarations({
			good: { baseUrls: { "openai-completions": "https://x/v1" }, sources: [{ kind: "baked" }, { kind: "nonsense" }, { kind: "endpoint", override: "yes" }] },
			bad: { sources: "not an array" },
			alsoBad: { sources: [{ kind: "unknown" }] },
			notAnObject: null,
		});
		assert.deepEqual(Object.keys(parsed).sort(), ["good"], "a provider with no readable source is dropped");
		assert.deepEqual(parsed.good.sources, [{ kind: "baked" }, { kind: "endpoint" }], "an unknown source kind is dropped and a non-boolean flag is not a flag");
		assert.deepEqual(parseDeclarations(undefined), {}, "a malformed document yields nothing rather than throwing");
	});

	itCase("N2", "the folder owns every input", () => {
		// The declaration is located through the module's own url, so this holds in
		// the mutation gate's throwaway mirror as well as in the repository.
		assert.ok(DECLARATIONS_PATH.endsWith(path.join("model-refresh", "sources.json")), `the declaration sits beside the extension, got ${DECLARATIONS_PATH}`);
		assert.ok(fs.existsSync(DECLARATIONS_PATH), "the declaration exists");
		const settings = path.resolve(EXTENSION_DIR, "..", "settings.json");
		if (fs.existsSync(settings)) {
			assert.ok(!fs.readFileSync(settings, "utf-8").includes("modelSources"), "no extension-specific key leaks into pi's settings");
		}
	});

	itCase("R1", "one catalog case, one test", () => {
		const declared = catalog.map((entry) => `${entry.id} ${entry.name}`).sort();
		assert.deepEqual([...new Set(registered)].sort(), declared, "every catalog case has a test and every test names a case");
		assert.equal(registered.length, new Set(registered).size, "no case is defined twice");
	});
});

// --- the derived per-source and per-level cases ----------------------------

describe("derived cases", () => {
	for (const source of UNION_SOURCES) {
		itCase("M2", `monotone in ${source}`, () => {
			for (let trial = 0; trial < TRIALS; trial++) {
				const rng = makeRng(trial + 100);
				const before: Partial<SourceState> & { baked?: readonly ModelDefinition[] } = { baked: someModels(rng, 3, `m${trial}`), stored: pick(rng, STORE_STATES), endpointIds: pick(rng, ENDPOINT_STATES), modelsDev: pick(rng, MODELS_DEV_STATES) };
				const grown = grow(before, source, rng);
				const small = ids(union(before));
				const large = ids(union(grown));
				for (const id of small) assert.ok(large.includes(id), `${id} survives adding a model to ${source}`);
			}
		});
	}

	for (const level of THINKING_LEVELS) {
		itCase("T4", `level ${level}`, () => {
			const named = level === "off" ? ["none", "low", "high"] : [level];
			const namedMap = thinkingLevelMapFromEfforts(named, { offEffort: "none" });
			assert.equal(namedMap[level], level === "off" ? "none" : level, `${level} maps to the effort the endpoint names`);
			const silent = thinkingLevelMapFromEfforts(["low", "high"], { offEffort: "none" });
			if (level !== "low" && level !== "high") {
				assert.equal(silent[level], null, `${level} is explicitly unsupported when the endpoint does not name it`);
			}
		});
	}
});

/** A source state with one more model in the named source. */
function grow(row: Partial<SourceState> & { baked?: readonly ModelDefinition[] }, source: (typeof UNION_SOURCES)[number], rng: () => number): Partial<SourceState> & { baked?: readonly ModelDefinition[] } {
	const extra = `grown-${source}-${Math.floor(rng() * 1e6)}`;
	switch (source) {
		case "baked":
			return { ...row, baked: [...(row.baked ?? BAKED), bakedModel(extra)] };
		case "pi-dev":
			return { ...row, stored: { models: [...(row.stored?.models ?? []), storedEntry(PROVIDER_ID, extra)] as StoredCatalog["models"], lastModified: GENERATED_AT + 1 } };
		case "endpoint":
			return { ...row, endpointIds: [...(row.endpointIds ?? []), extra] };
		case "models-dev":
			return { ...row, modelsDev: { ...(row.modelsDev ?? {}), [extra]: { name: extra } } };
	}
}
