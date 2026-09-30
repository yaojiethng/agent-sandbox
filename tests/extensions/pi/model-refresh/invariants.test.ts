/**
 * The invariant conformance suite: one named case per invariant, over the real
 * product surface, plus the index the renderer prints.
 *
 * The suite beside this file holds each invariant with a deep test. This file
 * answers the question a red suite asks: which invariant, and therefore which
 * review-finding class, is the finding about. Every case looks itself up in the
 * catalog by id and name, runs the body, and records the verdict, so a case
 * whose name has drifted fails on the lookup rather than passing silently.
 *
 * The fixtures come from the invariant, not from a list. A property case
 * generates its own catalogs from a seeded generator, so it replays on failure
 * and covers inputs nobody wrote down. The cases that must reach pi drive pi:
 * its composer, its model resolver, and its request builder, each read through
 * the same seam the sibling tests read. No network, no API key, no model
 * runtime, and no clock: the only clock-dependent value in play, the store's
 * freshness stamp, is a constant the cases set themselves.
 *
 * The mutation catalog names the two defects a green suite once missed: a
 * catalog entry with a zero context window, and an empty baked catalog. M5 and
 * M2 are the cases that hold them.
 *
 * Every case states its expectation from the record, never by calling the
 * function it checks. A provenance case that rebuilds its expectation with
 * `overlayBakedMetadata` or `liveOnlyModelConfig` proves only that the two
 * calls agree, so the rules those functions implement are written out here,
 * field by field, and the product is compared with them.
 */

import { after, describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";
import {
	ANTHROPIC_BASE,
	ANTHROPIC_TRANSPORT,
	RESPONSES_TRANSPORT,
	V1_BASE,
	buildUnion,
	isStoreNewerThanBaked,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import { THINKING_LEVELS, levelMapFor, offSendsAnEffort, thinkingLevelMapFromEfforts } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import { PROVIDER_ID, gatherAndBuild } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts";
import type { ThinkingLevelMap } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import type { ModelDefinition, ModelsDevModel, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";
import { UNION_SOURCES, buildCatalog, renderReport, type CaseResult } from "./invariants.ts";
import { anthropicBakedModel, bakedModel, captureThinkingPayload, effortList, makeRng, modelsDevEntry, pick, someModels, storedCatalog, storedEntry, type StoredEntry } from "./fixtures.ts";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;
const PI_AI = `${PI_PACKAGE_GLOBAL}/node_modules/@earendil-works/pi-ai`;
const COMPOSER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/provider-composer.js`;
const RESOLVER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/model-resolver.js`;
const REMOTE_CATALOG_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/remote-catalog-provider.js`;
const BAKED_CATALOG = `${PI_AI}/dist/providers/all.js`;
const THINKING_MODEL_RULES = `${PI_AI}/dist/models.js`;

const suite = fs.existsSync(PI_PACKAGE_ENTRY) ? {} : { skip: "pi installation not present" };

/** The baked data's generation timestamp, a constant so no case reads a clock. */
const GENERATED_AT = 1_000_000;
/** Property cases run this many generated catalogs per source. */
const TRIALS = 25;

/** One row of the source matrix: every optional source in one state. */
interface SourceState {
	baked: readonly ModelDefinition[];
	stored: StoredCatalog | undefined;
	liveIds: readonly string[] | undefined;
	modelsDev: Record<string, ModelsDevModel> | undefined;
	}

const BAKED_A = anthropicBakedModel("baked-a", {
	name: "Curated A",
	compat: { thinkingFormat: "anthropic", maxTokensField: "max_tokens" },
	thinkingLevelMap: { high: "high" },
	contextWindow: 111_000,
	maxTokens: 11_000,
		});
const BAKED_B = bakedModel("baked-b", {
	name: "Curated B",
	input: ["text", "image"],
	cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
	contextWindow: 222_000,
	maxTokens: 22_000,
		});
/**
 * A third baked entry, for a models.dev record that names one cost field and is
 * silent about the rest. Its costs are the fixture defaults, so a cost field
 * the overlay drops to zero is visible as a change.
 */
const BAKED_C = bakedModel("baked-c", { contextWindow: 333_000, maxTokens: 33_000 });
const BAKED = [BAKED_A, BAKED_B, BAKED_C];

/**
 * The models.dev blob: one baked entry refreshed in full, and two baked entries
 * the blob describes unevenly.
 *
 * The unevenness is deliberate on both halves, and each half has a model that
 * can carry it. `baked-b` names a modality pi's model type does not accept and
 * nothing else, so the overlay has to drop that modality and keep the baked
 * limits. `baked-c` names one cost field out of four, and its baked cost is not
 * zero, so the overlay has to keep the baked field the blob is silent about.
 */
const MODELS_DEV: Record<string, ModelsDevModel> = {
	...modelsDevEntry("baked-a", {
		name: "Refreshed A",
		limit: { context: 999_000, output: 99_000 },
		cost: { input: 3, output: 4, cache_read: 0.5, cache_write: 1.5 },
		modalities: { input: ["text", "image"] },
			}),
	...modelsDevEntry("baked-b", { modalities: { input: ["text", "audio"] } }),
	...modelsDevEntry("baked-c", { cost: { input: 7 } }),
	...modelsDevEntry("live-only", {
		name: "Live Only",
		reasoning_options: effortList(["none", "low", "high"]),
		limit: { context: 500_000, output: 32_000 },
		modalities: { input: ["text", "image"] },
			}),
	};

const FRESH_STORE = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-a", { contextWindow: 333_000, maxTokens: 33_000 })], GENERATED_AT + 1);

/** Every state the persisted catalog reaches: absent, empty, fresh, stale, undated, equal, malformed. */
const STORE_STATES: readonly (StoredCatalog | undefined)[] = [
	undefined,
	storedCatalog(PROVIDER_ID, [], GENERATED_AT + 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-fresh", { contextWindow: 333_000 })], GENERATED_AT + 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-stale", { contextWindow: 7 })], GENERATED_AT - 1),
	storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-undated")], undefined),
	{ models: [storedEntry(PROVIDER_ID, "store-equal"), storedEntry("opencode", "store-foreign")] as StoredCatalog["models"], lastModified: GENERATED_AT },
	{ models: "not-an-array" } as unknown as StoredCatalog,
	];

/** Every state the live source reaches: failed, advertising nothing, advertising two ids. */
const LIVE_STATES: readonly (readonly string[] | undefined)[] = [undefined, [], ["live-only", "baked-a"]];

/** Every state the models.dev source reaches: failed, empty, populated. */
const MODELS_DEV_STATES: readonly (Record<string, ModelsDevModel> | undefined)[] = [undefined, {}, MODELS_DEV];

/**
 * The matrix the union cases range over: baked empty or not, every store state,
 * every live state, models.dev present or absent.
 *
 * The malformed store in the matrix is the state that closes the store gate, so
 * the union drops the catalog before it reads the shape at all. The state that
 * opens the gate on a malformed store is one L2 builds itself over the baked
 * catalog alone, because that is the state in which a shape the parser mistyped
 * reaches the code that reads it.
 */
const MATRIX: SourceState[] = [BAKED, []].flatMap((baked) =>
	STORE_STATES.flatMap((stored) => LIVE_STATES.flatMap((liveIds) => MODELS_DEV_STATES.map((modelsDev) => ({ baked, stored, liveIds, modelsDev })))),
	);

// --- reading the union ----------------------------------------------------

const ids = (models: readonly ModelDefinition[]): string[] => models.map((model) => model.id);
const union = (row: Partial<SourceState> & { baked: readonly ModelDefinition[] }): ModelDefinition[] =>
	buildUnion({ stored: undefined, liveIds: undefined, modelsDev: undefined, generatedAt: GENERATED_AT, providerId: PROVIDER_ID, ...row });

/**
 * Whether the store a row carries is one the union applies. The gate is restated
 * here rather than read from the product, so M1 and M3 do not inherit a bug from
 * the function they are checking; G1 pins the product's own gate.
 */
function storeApplies(stored: StoredCatalog | undefined): boolean {
	return Array.isArray(stored?.models) && stored.models.length > 0 && stored.lastModified !== undefined && stored.lastModified > GENERATED_AT;
	}

/** The fields the metadata overlay is documented to touch. */
const OVERLAY_FIELDS: readonly (keyof ModelDefinition)[] = ["contextWindow", "maxTokens", "input", "cost"];
/** Every field pi's Model type carries, so a served entry's whole key set is compared. */
const MODEL_FIELDS: readonly (keyof ModelDefinition)[] = ["id", "name", "api", "baseUrl", "reasoning", "thinkingLevelMap", "input", "cost", "contextWindow", "maxTokens", "compat"];

/**
 * The modalities a served entry keeps: the two pi's model type accepts, and at
 * least one of them when the source names none.
 */
function expectedInput(modalities: readonly string[] | undefined): ("text" | "image")[] {
	const kept = (modalities ?? []).filter((modality): modality is "text" | "image" => modality === "text" || modality === "image");
	return kept.length > 0 ? kept : ["text"];
	}

/**
 * The cost the overlay writes, field by field: what models.dev states, then the
 * baked field, then zero, which is the documented rate of a model no source
 * has priced.
 */
function expectedOverlayCost(baked: ModelDefinition, metadata: ModelsDevModel | undefined): ModelDefinition["cost"] {
	if (!metadata?.cost) {
		return baked.cost;
		}
	return {
		input: metadata.cost.input ?? baked.cost?.input ?? 0,
		output: metadata.cost.output ?? baked.cost?.output ?? 0,
		cacheRead: metadata.cost.cache_read ?? baked.cost?.cacheRead ?? 0,
		cacheWrite: metadata.cost.cache_write ?? baked.cost?.cacheWrite ?? 0,
		};
	}

/**
 * The baked entry as the overlay must serve it. A model models.dev does not
 * describe is served exactly as pi baked it; one it describes keeps every
 * curated field and takes the four variable fields from the record.
 */
function expectedBakedEntry(baked: ModelDefinition, metadata: ModelsDevModel | undefined): ModelDefinition {
	if (metadata === undefined) {
		return { ...baked };
		}
	return {
		...baked,
		contextWindow: metadata.limit?.context ?? baked.contextWindow,
		maxTokens: metadata.limit?.output ?? baked.maxTokens,
		input: expectedInput(metadata.modalities?.input),
		cost: expectedOverlayCost(baked, metadata),
		};
	}

/** The transport the transport tables state for one id, read from the tables. */
function expectedTransport(id: string): { api: ModelDefinition["api"]; baseUrl: string } {
	if (ANTHROPIC_TRANSPORT.has(id)) {
		return { api: "anthropic-messages", baseUrl: ANTHROPIC_BASE };
		}
	if (RESPONSES_TRANSPORT.has(id)) {
		return { api: "openai-responses", baseUrl: V1_BASE };
		}
	return { api: "openai-completions", baseUrl: V1_BASE };
	}

/**
 * The compat block a live-only entry carries: the chat flags on the Anthropic
 * adapter and on an endpoint that advertises efforts outside the deepseek
 * family, and the deepseek toggle everywhere else. `supportsReasoningEffort` is
 * deliberately absent on both, so pi auto-detects it; the suite asserts the
 * absence through the whole-object comparison.
 */
function expectedLiveCompat(api: ModelDefinition["api"], id: string, efforts: readonly string[] | undefined): Record<string, unknown> {
	const chat = { supportsStore: false, supportsDeveloperRole: false, maxTokensField: "max_tokens" };
	if (api === "anthropic-messages" || (efforts !== undefined && efforts.length > 0 && !id.startsWith("deepseek"))) {
		return chat;
		}
	return { ...chat, thinkingFormat: "deepseek", requiresReasoningContentOnAssistantMessages: true };
	}

/**
 * The level map a live-only entry carries: every level pi knows gets an entry,
 * the endpoint's own "none" maps onto off, a level the endpoint does not
 * advertise is unsupported, and an endpoint that advertises nothing keeps the
 * low/high range, which stops short of `max` on purpose. A ladder that named
 * `max` and not `xhigh` answers a request for `xhigh` with `max`, which is
 * more than the caller asked for (README A5, and the downward half of the
 * search in `clampThinkingLevel`).
 */
function expectedLevelMap(efforts: readonly string[] | undefined): ThinkingLevelMap {
	const map: ThinkingLevelMap = Object.fromEntries(THINKING_LEVELS.map((level) => [level, null]));
	if (!efforts?.length) {
		return { ...map, low: "low", high: "high" };
		}
	for (const effort of efforts) {
		const level = effort === "none" ? "off" : effort;
		if ((THINKING_LEVELS as readonly string[]).includes(level)) {
			map[level] = effort;
			}
		}
	return map;
	}

/** The entry the live layer must build for one id, written out from models.dev. */
function expectedLiveOnlyEntry(id: string, metadata: ModelsDevModel | undefined): ModelDefinition {
	const efforts = metadata?.reasoning_options?.find((option) => option.type === "effort")?.values;
	const { api, baseUrl } = expectedTransport(id);
	return {
		id,
		name: metadata?.name ?? id,
		api,
		baseUrl,
		reasoning: metadata?.reasoning ?? true,
		input: expectedInput(metadata?.modalities?.input),
		cost:
			metadata?.cost === undefined
				? { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }
				: {
						input: metadata.cost.input ?? 0,
						output: metadata.cost.output ?? 0,
						cacheRead: metadata.cost.cache_read ?? 0,
						cacheWrite: metadata.cost.cache_write ?? 0,
			},
		contextWindow: metadata?.limit?.context ?? 1_000_000,
		maxTokens: metadata?.limit?.output ?? 131_072,
		thinkingLevelMap: expectedLevelMap(efforts),
		compat: expectedLiveCompat(api, id, efforts),
		};
	}

/** One entry without the provider stamp pi's own store carries. */
function withoutProvider(model: ModelDefinition): Record<string, unknown> {
	const { provider: _provider, ...rest } = model as StoredEntry;
	return rest;
	}

/**
 * The ids a row's sources legitimately declare: the baseline, plus every id a
 * well-formed part of the row supplies. This is the set a leak check compares
 * against. The set is built from the declared sources, not from the served
 * entry's shape: a served id that is a non-empty string proves nothing about
 * which source supplied it, and a string walked character by character is a
 * list of valid ids.
 */
function declaredIds(row: Partial<SourceState> & { baked: readonly ModelDefinition[] }): string[] {
	const declared = new Set(ids(union({ baked: row.baked })));
	if (storeApplies(row.stored)) {
		for (const model of row.stored?.models as StoredEntry[]) {
			if (typeof model?.id === "string" && model.provider === PROVIDER_ID) {
				declared.add(model.id);
				}
			}
		}
	for (const id of Array.isArray(row.liveIds) ? row.liveIds : []) {
		if (typeof id === "string") {
			declared.add(id);
			}
		}
	return [...declared];
	}

// --- the levels a model advertises ---------------------------------------

/**
 * The levels an entry advertises, read from its own map. A null value is
 * unsupported and an absent key is supported, except for xhigh and max: pi
 * needs an explicit mapping for those two, because most provider maps omit them.
 * `getSupportedThinkingLevels` in pi-ai dist/models.js is the product of this
 * rule, and the W1 case asserts the two agree.
 */
function advertisedLevels(model: ModelDefinition): string[] {
	if (!model.reasoning) {
		return [];
		}
	return THINKING_LEVELS.filter((level) => {
		const mapped = model.thinkingLevelMap?.[level];
		if (mapped === null) {
			return false;
				}
		return level === "xhigh" || level === "max" ? mapped !== undefined : true;
			});
	}

/** What the payload must carry at one advertised level, read from the entry alone. */
function expectedThinkingFields(model: ModelDefinition, level: string): Record<string, unknown> {
	const compat = model.compat ?? {};
	const effort = model.thinkingLevelMap?.[level] ?? level;
	if (model.api === "openai-responses") {
		return level === "off" ? { reasoning: { effort: model.thinkingLevelMap?.off ?? "none" } } : { reasoning: { effort, summary: "auto" } };
		}
	if (compat.supportsReasoningEffort === false) {
		return compat.thinkingFormat === "deepseek" ? { thinking: { type: level === "off" ? "disabled" : "enabled" } } : {};
		}
	if (compat.thinkingFormat === "deepseek") {
		return level === "off" ? { thinking: { type: "disabled" } } : { thinking: { type: "enabled" }, reasoning_effort: effort };
		}
	if (compat.thinkingFormat === "qwen") {
		return level === "off" ? { enable_thinking: false } : { enable_thinking: true, reasoning_effort: effort };
		}
	assert.equal(compat.thinkingFormat, undefined, `the suite states no expectation for the thinking format ${String(compat.thinkingFormat)}`);
	if (level !== "off") {
		return { reasoning_effort: effort };
		}
	return typeof model.thinkingLevelMap?.off === "string" ? { reasoning_effort: model.thinkingLevelMap.off } : {};
	}

// --- driving pi's composer ------------------------------------------------

/** The baked catalog the composition cases serve, including pi's default model. */
const COMPOSED_BAKED: ModelDefinition[] = [
	{ ...bakedModel("kimi-k2.6", { name: "Kimi K2.6", contextWindow: 262_144, maxTokens: 65_536, cost: { input: 0.95, output: 4, cacheRead: 0, cacheWrite: 0 } }), provider: PROVIDER_ID },
	{ ...bakedModel("alpha", { name: "Alpha" }), provider: PROVIDER_ID },
	];

/** A stand-in for pi's built-in provider, with pi's own remote-catalog refresh. */
function baseProvider() {
	let dynamic: StoredEntry[] = [];
	return {
		id: PROVIDER_ID,
		name: "OpenCode Go",
		auth: { apiKey: { name: "key", check: async () => undefined, resolve: async () => undefined, login: async () => ({ type: "api_key", key: "x" }) } },
		// pi's own merge, from dist/core/remote-catalog-provider.js: the overlay
		// replaces a same-id entry in place and appends an unknown one.
		getModels: () => {
			const merged = [...COMPOSED_BAKED];
			for (const model of dynamic) {
				const index = merged.findIndex((entry) => entry.id === model.id);
				if (index >= 0) {
					merged[index] = model;
				} else {
					merged.push(model);
					}
				}
			return merged;
			},
		refreshModels: async (context: { stored?: StoredCatalog; publish: (publication: { update?: () => void }) => Promise<boolean> }) => {
			// pi's own gate, from dist/core/remote-catalog-provider.js: the overlay
			// applies unless the baked data is known to be at least as new.
			const stored = context.stored;
			const applies = stored?.models !== undefined && (stored.lastModified !== undefined && stored.lastModified > GENERATED_AT);
			const restored = applies ? (stored.models as StoredEntry[]).filter((model) => model.provider === PROVIDER_ID) : [];
			if (!(await context.publish({ update: () => { dynamic = restored; } }))) {
				return;
				}
			},
		stream: () => {
			throw new Error("not used");
			},
		streamSimple: () => {
			throw new Error("not used");
			},
		};
	}

/** The registration index.ts makes: the union, gathered with the fetch refused. */
const refreshRegistration = {
	refreshModels: (context: { signal: AbortSignal; allowNetwork: boolean; stored?: StoredCatalog }) =>
		gatherAndBuild({
			signal: context.signal,
			allowNetwork: context.allowNetwork,
			stored: context.stored,
			generatedAt: GENERATED_AT,
			baked: COMPOSED_BAKED,
			fetcher: async () => {
				throw new Error("the invariant suite never reaches the network");
				},
			}),
	};

/** Compose a registration onto the base provider, refresh it once, and return what pi would serve. */
async function composeOnce(extension: unknown, stored: StoredCatalog | undefined, modelConfig?: unknown): Promise<ModelDefinition[]> {
	const { composeModelProvider } = (await import(COMPOSER_ENTRY)) as {
		composeModelProvider: (providerId: string, base: unknown, config: unknown, extension: unknown) => { getModels: () => unknown[]; refreshModels?: (context: never) => Promise<void> };
		};
	const config = modelConfig ?? { getProvider: () => undefined, getProviderIds: () => [] };
	const composed = composeModelProvider(PROVIDER_ID, baseProvider() as never, config as never, extension as never);
	await composed.refreshModels?.({
		signal: new AbortController().signal,
		allowNetwork: false,
		stored,
		publish: async (publication: { update?: () => void }) => {
			publication.update?.();
			return true;
				},
	} as never);
	return composed.getModels() as ModelDefinition[];
	}

/** The model runtime pi's resolver reads: the composed catalog and an auth it has. */
const runtimeOf = (models: readonly ModelDefinition[]) => ({
	getModels: () => [...models],
	getAvailableSnapshot: () => [...models],
	hasConfiguredAuth: () => true,
		});

// --- the extension's own registration ------------------------------------

const EXTENSION_ENTRY = path.resolve(import.meta.dirname, "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts");

/**
 * Load the extension's own factory and return the providers it registers. The
 * module graph is loaded through the same jiti and the same package aliases the
 * runtime uses, so the registration under test is the registration pi gets.
 */
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
			"typebox": requireFromPi.resolve("typebox"),
			"@sinclair/typebox": requireFromPi.resolve("typebox"),
				},
			});
	const registered: { id: string; config: Record<string, unknown> }[] = [];
	const module = await jiti.import(EXTENSION_ENTRY);
	module.default({
		registerProvider: (id: string, config: Record<string, unknown>) => registered.push({ id, config }),
			});
	return registered;
	}

// --- the report ------------------------------------------------------------

const results: CaseResult[] = [];
const catalog = buildCatalog();
/**
 * Every catalog case a test in this file claims, recorded when the test is
 * defined rather than when it runs. The list is therefore complete before the
 * first case runs, which is what lets R1 compare it with the catalog in any
 * order, and a case is in it exactly once however many times it is defined.
 */
const registered: string[] = [];

/** The message of a failed case, for the report line and the rethrow. */
function errorMessage(e: unknown): string {
	return e instanceof Error ? e.message : String(e);
	}

/** The catalog's own statement for one case, which the test name prints. */
function statementOf(id: string, name: string): string {
	const entry = catalog.find((candidate) => candidate.id === id && candidate.name === name);
	assert.ok(entry, `the catalog carries a case for ${id} ${name}`);
	return entry!.statement;
	}

/** Define one catalog case as a test, and record the claim R1 compares. */
function itCase(id: string, name: string, body: () => Promise<void> | void): void {
	registered.push(`${id} ${name}`);
	it(`INV ${id} -- ${statementOf(id, name)}`, suite, async () => {
		await check(id, name, body);
			});
	}

/** Run one case, name it for its invariant, and keep the verdict for the index. */
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

/** The string fields pi's Model type requires, and the ones it types as numbers. */
const REQUIRED_STRINGS = ["id", "name", "api", "baseUrl"] as const;
const REQUIRED_NUMBERS = ["contextWindow", "maxTokens"] as const;
const COST_FIELDS = ["input", "output", "cacheRead", "cacheWrite"] as const;

/**
 * One entry checked against pi's Model type.
 *
 * The four cost fields are checked for presence and finiteness, and nothing
 * else: a rate of zero is a real rate, and the extension deliberately serves an
 * all-zero cost for a live-only model no source has priced. Checking positivity
 * on a rate would reject that shape, and the M5 statement's word "present" is
 * what keeps the two apart.
 *
 * The two limits are checked for presence, finiteness, and positivity, because
 * a limit of zero is not a limit: pi would serve a model it cannot hold the
 * requested context in. This is where the statement's two halves land.
 */
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

	// --- the union --------------------------------------------------------

	itCase("M1", "non-empty", () => {
		for (const row of MATRIX) {
			const declared = declaredIds(row);
			const result = union(row);
			// The union is empty exactly when no source declares a model pi can
			// serve. The catalog states the weaker half of this pair.
			assert.equal(
				declared.length === 0,
				result.length === 0,
				`the union over ${result.length} entries holds ${declared.length} declared ids: ${declared.join(", ") || "none declared"}`,
						);
					}
				});

	for (const source of UNION_SOURCES) {
		itCase("M2", `monotone in ${source}`, () => {
			assert.deepEqual(
				catalog.filter((candidate) => candidate.id === "M2").map((candidate) => candidate.name),
				UNION_SOURCES.map((entry) => `monotone in ${entry}`),
				"the monotonicity cases are derived from the union's own source list, not written here",
						);
			const rng = makeRng(UNION_SOURCES.indexOf(source) + 1);
			const withBaked = someModels(rng, 2 + Math.floor(rng() * 3), "baked-with");
			// Each source grows from two baselines: one with a baked catalog to
			// merge into, and one with none. The bare baseline is the state a
			// provider ships in before pi bakes it, and it is where a source that
			// is dropped whenever another is empty removes a model instead of
			// adding one.
			for (const baked of [withBaked, [] as ModelDefinition[]]) {
				const label = baked.length > 0 ? "over a baked catalog" : "over no baked catalog";
				for (let trial = 0; trial < TRIALS; trial++) {
					const added = `added-${source}-${trial}`;
					const baseline: SourceState = {
						baked,
						stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, `stored-${trial}`, { contextWindow: 10_000 + trial })], GENERATED_AT + 1),
						liveIds: [`live-${trial}`],
						modelsDev: rng() < 0.5 ? MODELS_DEV : undefined,
								};
					const grown: SourceState =
						source === "baked"
							? { ...baseline, baked: [...baseline.baked, bakedModel(added)] }
							: source === "store"
								? { ...baseline, stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, added), ...(baseline.stored?.models ?? [])], GENERATED_AT + 1) }
								: { ...baseline, liveIds: [...(baseline.liveIds ?? []), added] };
					const before = ids(union(baseline));
					const after = ids(union(grown));
					assert.ok(!before.includes(added), `trial ${trial} ${label}: the added id is new before the source grows`);
					for (const id of before) {
						assert.ok(after.includes(id), `trial ${trial} ${label}: growing ${source} removed ${id} (${after.join(", ")})`);
								}
					assert.ok(after.includes(added), `trial ${trial} ${label}: growing ${source} did not serve ${added} (${after.join(", ")})`);
							}
						}
					});
			}

	itCase("M3", "overlay silence", () => {
		// A models.dev entry that names no limit is a real shape: the blob
		// carries cost and modalities for a model whose limits it does not
		// list. The overlay must then leave the baked limits alone, and this
		// case exists because the suite never built that state before and the
		// silent-field fallback passed unmutated.
		const baked = BAKED_A;
		const blank = modelsDevEntry(baked.id)[baked.id];
		for (const metadata of [blank, { ...blank, limit: undefined }, { ...blank, limit: {} }, { ...blank, limit: { input: 8 } }]) {
			const served = buildUnion({
				baked: [baked],
				providerId: PROVIDER_ID,
				generatedAt: GENERATED_AT,
				stored: undefined,
				liveIds: undefined,
				modelsDev: { [baked.id]: metadata },
			})[0];
			assert.equal(served.contextWindow, baked.contextWindow, `${baked.id}: a limit models.dev does not state keeps the baked context window`);
			assert.equal(served.maxTokens, baked.maxTokens, `${baked.id}: a limit models.dev does not state keeps the baked output limit`);
			assert.deepEqual(served.cost, expectedOverlayCost(baked, metadata), `${baked.id}: a cost field models.dev does not state keeps the baked one`);
					}
		// The converse, so the case cannot pass by leaving everything alone: a
		// limit models.dev does state does land.
		const stated = { ...blank, limit: { context: 32_000, output: 4_096 } };
		const overlaid = buildUnion({
			baked: [baked],
			providerId: PROVIDER_ID,
			generatedAt: GENERATED_AT,
			stored: undefined,
			liveIds: undefined,
			modelsDev: { [baked.id]: stated },
		})[0];
		assert.equal(overlaid.contextWindow, 32_000, "a stated context window lands");
		assert.equal(overlaid.maxTokens, 4_096, "a stated output limit lands");
				});

	itCase("M3", "provenance", () => {
		for (const row of MATRIX) {
			for (const entry of union(row)) {
				const storedModels = Array.isArray(row.stored?.models) ? (row.stored?.models as StoredEntry[]) : [];
				const stored = storedModels.find((model) => model.id === entry.id && model.provider === PROVIDER_ID);
				const baked = row.baked.find((model) => model.id === entry.id);
				if (stored && storeApplies(row.stored)) {
					assert.deepEqual(withoutProvider(entry), withoutProvider(stored), `${entry.id}: the union serves the stored entry, not a second one`);
					continue;
							}
				if (baked) {
					// The expectation is the baked entry with four fields rewritten,
					// stated from the record and not from the product's own overlay.
					assert.deepEqual(entry, expectedBakedEntry(baked, row.modelsDev?.[baked.id]), `${entry.id}: the union serves the baked entry under the documented overlay`);
					for (const field of MODEL_FIELDS.filter((name) => !OVERLAY_FIELDS.includes(name))) {
						assert.deepEqual(entry[field], baked[field], `${entry.id}: the overlay leaves the curated ${field} alone`);
								}
					assert.deepEqual(Object.keys(entry).sort(), Object.keys(expectedBakedEntry(baked, row.modelsDev?.[baked.id])).sort(), `${entry.id}: the overlay adds and drops no field`);
					continue;
							}
				if ((row.liveIds ?? []).includes(entry.id)) {
					assert.deepEqual(entry, expectedLiveOnlyEntry(entry.id, row.modelsDev?.[entry.id]), `${entry.id}: the live entry is built as declared`);
					continue;
							}
				assert.fail(`${entry.id}: the union serves an entry no declared source supplied`);
						}
					}
		// The converse, stated over the whole matrix: whatever models.dev says
		// about a baked model, the curated fields the baked catalog carries
		// reach the wire unchanged.
		for (const row of MATRIX) {
			for (const model of row.baked) {
				const served = union(row).find((entry) => entry.id === model.id);
				assert.ok(served, `${model.id}: the baked entry is served`);
				for (const field of MODEL_FIELDS) {
					if (OVERLAY_FIELDS.includes(field)) {
						continue;
								}
					assert.deepEqual(served[field], model[field], `${model.id}: the curated ${field} survives the overlay`);
							}
						}
					}
		// The live layer's own shapes, written out one at a time, because the
		// matrix reaches only one live id. Each shape has its own rule, and a
		// defect in any one of them changes a field the expectation names.
		const liveShapes: { label: string; id: string; modelsDev: Record<string, ModelsDevModel> | undefined }[] = [
			{ label: "a live id models.dev describes", id: "live-only", modelsDev: MODELS_DEV },
			{ label: "a live id models.dev has never heard of", id: "unheard-of", modelsDev: undefined },
			{ label: "a live id with an empty models.dev record", id: "blank-record", modelsDev: modelsDevEntry("blank-record", { name: undefined, reasoning: undefined }) },
			{ label: "a deepseek-family live id that advertises efforts", id: "deepseek-live", modelsDev: modelsDevEntry("deepseek-live", { reasoning_options: effortList(["low", "high"]) }) },
			{ label: "a live id on the Anthropic transport", id: [...ANTHROPIC_TRANSPORT][0], modelsDev: modelsDevEntry([...ANTHROPIC_TRANSPORT][0], { reasoning_options: effortList(["none", "high"]) }) },
			{ label: "a live id on the Responses transport", id: [...RESPONSES_TRANSPORT][0], modelsDev: modelsDevEntry([...RESPONSES_TRANSPORT][0], { reasoning_options: effortList(["low"]) }) },
					];
		for (const shape of liveShapes) {
			const served = union({ baked: [], liveIds: [shape.id], modelsDev: shape.modelsDev })[0];
			assert.deepEqual(served, expectedLiveOnlyEntry(shape.id, shape.modelsDev?.[shape.id]), `${shape.label}: the union builds ${shape.id} from models.dev and the transport rules`);
					}
				});

	itCase("M4", "unique ids", () => {
		for (const row of MATRIX) {
			const result = ids(union(row));
			assert.equal(new Set(result).size, result.length, `the union repeats an id: ${result.join(", ")}`);
					}
		// All three sources naming one id is the case a merge bug shows on.
		const result = union({
			baked: [bakedModel("shared", { contextWindow: 111 }), bakedModel("only-baked")],
			stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "shared", { contextWindow: 222 })], GENERATED_AT + 1),
			liveIds: ["shared", "live-only"],
						});
	assert.deepEqual(ids(result), ["shared", "only-baked", "live-only"], "the shared id appears once, in the baked position");
	assert.equal(result.filter((model) => model.id === "shared").length, 1, "one entry for the shared id");
	assert.equal(result[0].contextWindow, 222, "and it is the fresher stored entry");
	// The state the extension exists for: a model pi has just shipped is in
	// the persisted catalog and on the live endpoint at the same time, so
	// the live layer sees an id the store layer already supplied. The id
	// appears once, and it carries the stored entry rather than a freshly
	// built one.
	const both = union({
		baked: [bakedModel("baked-only")],
		stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "both", { contextWindow: 555_000, name: "Stored Both" })], GENERATED_AT + 1),
		liveIds: ["both", "live-only"],
						});
	assert.deepEqual(ids(both), ["baked-only", "both", "live-only"], "a stored id the live list also names is served once");
	assert.equal(both.filter((model) => model.id === "both").length, 1, "one entry for the id both sources supply");
	assert.equal(both.find((model) => model.id === "both")?.contextWindow, 555_000, "and it carries the stored entry");
				});

	itCase("M5", "a valid model", async () => {
		for (const row of MATRIX) {
			for (const entry of union(row)) {
				assertValidModel(entry);
						}
					}
		// The same check over the catalog pi actually ships, read from pi-ai.
		const { getBuiltinModels } = (await import(BAKED_CATALOG)) as { getBuiltinModels: (providerId: string) => ModelDefinition[] };
		for (const entry of union({ baked: getBuiltinModels(PROVIDER_ID) })) {
			assertValidModel(entry);
					}
		// A live-only model no catalog has described is served on the
		// extension's own defaults, so those defaults are checked too.
		for (const entry of union({ baked: [], liveIds: ["unheard-of"] })) {
			assertValidModel(entry);
					}
		// The all-zero cost, stated as the shape it is rather than left to be
		// read as a defect: a model no source has priced is served free, and a
		// reviewer reading the served entry should see that it is deliberate.
		const unpriced = union({ baked: [], liveIds: ["unpriced"] })[0];
		assert.deepEqual(unpriced.cost, { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, "a model no source has priced is served at zero in every cost field");
		assert.equal(unpriced.reasoning, true, "and it is served as a reasoning model, the default for a model models.dev has not heard of");
		assertValidModel(unpriced);
				});

	itCase("M7", "a usable entry", () => {
		// Pi's own parseCatalog in dist/core/remote-catalog-provider.js keeps any
		// entry that is an object carrying an id key, and the id is never typed,
		// so a persisted file can hand pi `id: 42` or an id that is an object.
		// The extension is the stricter side of that pair: it drops such an
		// entry where pi would keep it, because a model pi cannot key on is a
		// model pi cannot serve.
		const unusable: { label: string; entry: unknown }[] = [
			{ label: "an entry with no id", entry: { provider: PROVIDER_ID, name: "No Id" } },
			{ label: "an entry whose id is a number", entry: { provider: PROVIDER_ID, id: 42 } },
			{ label: "an entry whose id is an object", entry: { provider: PROVIDER_ID, id: { name: "nested" } } },
			{ label: "an entry whose id is null", entry: { provider: PROVIDER_ID, id: null } },
			{ label: "an entry whose id is the empty string", entry: { provider: PROVIDER_ID, id: "" } },
			{ label: "a stored entry that is a number", entry: 7 },
			{ label: "a stored entry that is a string", entry: "stored-entry" },
					];
		for (const shape of unusable) {
			const result = union({
				baked: [bakedModel("baked-a")],
				stored: { models: [shape.entry] as StoredCatalog["models"], lastModified: GENERATED_AT + 1 },
							});
			assert.deepEqual(ids(result), ["baked-a"], `${shape.label} is dropped before the union sees it`);
					}
		// The converse, so the case cannot pass by dropping every stored entry:
		// a stored entry carrying a string id and nothing else is kept whole.
		const kept = union({
			baked: [bakedModel("baked-a")],
			stored: { models: [{ id: "kept", provider: PROVIDER_ID } as StoredEntry], lastModified: GENERATED_AT + 1 },
						});
		assert.deepEqual(ids(kept), ["baked-a", "kept"], "a stored entry with a string id reaches the union");
		assert.deepEqual(kept[1], { id: "kept", provider: PROVIDER_ID }, "and it reaches the union unchanged, fields it lacks included");
				});

	itCase("M8", "the transport does not contradict pi", async () => {
		const { getBuiltinModels } = (await import(BAKED_CATALOG)) as { getBuiltinModels: (providerId: string) => ModelDefinition[] };
		const baked = new Map(getBuiltinModels(PROVIDER_ID).map((model) => [model.id, model]));
		const tableIds = [...new Set([...ANTHROPIC_TRANSPORT, ...RESPONSES_TRANSPORT])];
		assert.ok(tableIds.length > 0, "the transport tables name at least one id");
		for (const id of tableIds) {
			const chosen = expectedTransport(id);
			assert.equal(chosen.api, ANTHROPIC_TRANSPORT.has(id) ? "anthropic-messages" : "openai-responses", `${id}: the id is served on the adapter its own table names`);
			// The union is what pi would serve, not the table read on its own.
			const served = union({ baked: [], liveIds: [id] })[0];
			assert.equal(served.api, chosen.api, `${id}: the union serves the adapter the table names`);
			assert.equal(served.baseUrl, chosen.baseUrl, `${id}: and the base url that goes with it`);
			const own = baked.get(id);
			if (own === undefined) {
				continue;
						}
			// Pi carries the id, so pi's own entry is the transport of record, and
			// a table that disagrees with it is the defect: the live layer would
			// then build a second, differently shaped entry for a model pi
			// already serves.
			assert.equal(chosen.api, own.api, `${id}: pi carries it as ${own.api}, so the table must agree`);
			assert.equal(chosen.baseUrl, own.baseUrl, `${id}: pi carries it at ${own.baseUrl}, so the table must agree`);
					}
		// And the baked entries reach pi on pi's own transport, so no model pi
		// ships is re-homed by this extension.
		for (const model of union({ baked: [...baked.values()] })) {
			assert.equal(model.api, baked.get(model.id)?.api, `${model.id}: the baked transport reaches pi`);
			assert.equal(model.baseUrl, baked.get(model.id)?.baseUrl, `${model.id}: and so does its base url`);
					}
				});

	itCase("M6", "purity", () => {
		for (const row of MATRIX) {
			const before = JSON.stringify({ baked: row.baked, stored: row.stored, liveIds: row.liveIds, modelsDev: row.modelsDev });
			const result = union(row);
			const after = JSON.stringify({ baked: row.baked, stored: row.stored, liveIds: row.liveIds, modelsDev: row.modelsDev });
			assert.equal(after, before, "the union mutates none of its inputs");
			assert.notEqual(result, row.baked as unknown, "the result is not the baked array");
			assert.notEqual(result, row.liveIds as unknown, "the result is not the live list");
			assert.notEqual(result, row.stored?.models as unknown, "the result is not the stored array");
					}
				});

	// --- the store gate ---------------------------------------------------

	itCase("G1", "the exact gate", async () => {
		const rows: { label: string; stored: StoredCatalog | undefined; generatedAt: number | undefined; expected: boolean }[] = [
			{ label: "a fresh store over known baked data", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], GENERATED_AT + 1), generatedAt: GENERATED_AT, expected: true },
			{ label: "a store as new as the baked data", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], GENERATED_AT), generatedAt: GENERATED_AT, expected: false },
			{ label: "a store older than the baked data", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], GENERATED_AT - 1), generatedAt: GENERATED_AT, expected: false },
			{ label: "a store with no freshness stamp", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], undefined), generatedAt: GENERATED_AT, expected: false },
			{ label: "a fresh store over an unknown baked timestamp", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], GENERATED_AT + 1), generatedAt: undefined, expected: true },
			{ label: "an undated store over an unknown baked timestamp", stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "gate-a")], undefined), generatedAt: undefined, expected: true },
			{ label: "a store with no models", stored: storedCatalog(PROVIDER_ID, [], GENERATED_AT + 1), generatedAt: GENERATED_AT, expected: false },
			{ label: "a store carrying no models key", stored: { lastModified: GENERATED_AT + 1 }, generatedAt: GENERATED_AT, expected: false },
			{ label: "an absent store", stored: undefined, generatedAt: GENERATED_AT, expected: false },
					];
		for (const row of rows) {
			assert.equal(isStoreNewerThanBaked(row.stored, row.generatedAt), row.expected, `the gate over ${row.label}`);
			const served = ids(union({ baked: [bakedModel("baked-a")], stored: row.stored, generatedAt: row.generatedAt })).includes("gate-a");
			assert.equal(served, row.expected, `the union applies the store over ${row.label}`);
					}
				});

	itCase("G2", "agrees with pi", async () => {
		// The extension copies pi's merge because pi's is unreachable: it is
		// declared without `export`, and the package publishes no subpath under
		// `dist/`. That makes the copy a standing risk of silent drift, so this
		// case pins the agreement rather than the words.
		//
		// pi's `withRemoteCatalog` is exported, and its `getModels` is
		// `mergeModels(provider.getModels(), dynamicModels)`. Driving it with a
		// stored entry therefore runs pi's real merge, its real freshness gate
		// and its real provider filter, and the result is comparable entry for
		// entry with ours. If pi changes any of the three, this goes red.
		const { withRemoteCatalog } = (await import(REMOTE_CATALOG_ENTRY)) as {
			withRemoteCatalog: (
				provider: { id: string; name: string; getModels: () => ModelDefinition[] },
				baseUrl: string,
				generatedAt: number | undefined,
			) => {
				getModels: () => ModelDefinition[];
				refreshModels: (context: Record<string, unknown>) => Promise<unknown>;
			};
		};
		assert.equal(typeof withRemoteCatalog, "function", "pi still exports withRemoteCatalog");

		const rows: { label: string; baked: string[]; stored: StoredEntry[] }[] = [
			{ label: "a stored entry that replaces a baked one", baked: ["kept", "replaced"], stored: [storedEntry(PROVIDER_ID, "replaced", { name: "Fresh", contextWindow: 222 })] },
			{ label: "a stored entry pi has never seen", baked: ["kept"], stored: [storedEntry(PROVIDER_ID, "novel")] },
			{ label: "both at once", baked: ["kept", "replaced"], stored: [storedEntry(PROVIDER_ID, "replaced"), storedEntry(PROVIDER_ID, "novel")] },
			{ label: "another provider's entry only", baked: ["kept"], stored: [storedEntry("opencode", "novel")] },
			{ label: "nothing persisted", baked: ["kept", "replaced"], stored: [] },
			{ label: "a stale persisted catalog, which the gate should close", baked: ["kept", "replaced"], stored: [storedEntry(PROVIDER_ID, "replaced")] },
		];
		for (const row of rows) {
			// The stale row passes an older stamp, so pi's gate and ours both
			// decline the store and the case compares the two declines too.
			const stamped = row.label.startsWith("a stale") ? GENERATED_AT - 1 : GENERATED_AT + 1;
			const baked = row.baked.map((id) => bakedModel(id));
			const stored = storedCatalog(PROVIDER_ID, row.stored, stamped);

			const wrapped = withRemoteCatalog({ id: PROVIDER_ID, name: PROVIDER_ID, getModels: () => baked.map((model) => ({ ...model })) }, "https://pi.dev", GENERATED_AT);
			await wrapped.refreshModels({
				stored,
				publish: async (publication: { update?: () => void }) => {
					publication.update?.();
					return true;
				},
				allowNetwork: false,
				force: true,
				signal: new AbortController().signal,
			});
			// Ours goes through buildUnion so the comparison covers the gate, the
			// provider filter and the merge, which is what pi's three lines do
			// together. With no models.dev blob and no live ids, the only thing
			// left to differ is the merge.
			const ours = buildUnion({
				baked,
				stored,
				generatedAt: GENERATED_AT,
				liveIds: undefined,
				modelsDev: undefined,
				providerId: PROVIDER_ID,
			});
			assert.deepEqual(ours, wrapped.getModels(), `${row.label}: our merge agrees with pi's, entry for entry`);
		}
	});

	itCase("G2", "whole replacement", async () => {
		// The stored entry is written out rather than derived, so it can leave
		// out every field the baked entry carries.
		const stored: StoredEntry = {
			id: "replaced",
			name: "Fresh",
			api: "openai-completions",
			baseUrl: V1_BASE,
			input: ["text"],
			cost: { input: 1, output: 2, cacheRead: 3, cacheWrite: 4 },
			contextWindow: 222,
			maxTokens: 22,
			provider: PROVIDER_ID,
					};
		const baked = bakedModel("replaced", { name: "Stale", contextWindow: 111, maxTokens: 11, reasoning: false, compat: { thinkingFormat: "deepseek" }, thinkingLevelMap: { high: "high" } });
		const result = union({ baked: [baked, bakedModel("other")], stored: storedCatalog(PROVIDER_ID, [stored], GENERATED_AT + 1) });
		const served = result.find((model) => model.id === "replaced");
		assert.deepEqual(served, stored, "the stored entry replaces the baked entry whole");
		assert.deepEqual(ids(result), ["replaced", "other"], "the replacement is not a second entry");
		for (const field of ["compat", "thinkingLevelMap", "reasoning"] as const) {
			assert.equal(field in (served as object), false, `${field} was baked-only and does not survive on the stored entry`);
					}
		// The other direction: a field the baked entry lacks and the stored one
		// carries reaches the union, so the two are never blended field by field.
		const added = { ...stored, id: "extended", compat: { thinkingFormat: "anthropic" } };
		const extended = union({ baked: [bakedModel("extended")], stored: storedCatalog(PROVIDER_ID, [added], GENERATED_AT + 1) }).find((model) => model.id === "extended");
		assert.deepEqual(extended?.compat, { thinkingFormat: "anthropic" }, "the stored entry's own compat reaches the union");
		assert.equal(extended?.name, "Fresh", "and the stored name, not the baked one");
				});

	itCase("G3", "provider scope", async () => {
		const providerNames: (string | undefined)[] = [PROVIDER_ID, "opencode", "somebody-else", "", undefined];
		for (const provider of providerNames) {
			const result = ids(union({ baked: [bakedModel("baked-a")], stored: storedCatalog(provider, [storedEntry(provider, "scoped")], GENERATED_AT + 1) }));
			const served = result.includes("scoped");
			assert.equal(served, provider === PROVIDER_ID, `an entry stored under ${String(provider)} is ${provider === PROVIDER_ID ? "served" : "not served"}`);
					}
		// A store that mixes both providers serves the extension's own and
		// nothing else.
		const mixed = union({
			baked: [bakedModel("baked-a")],
			stored: { models: [storedEntry(PROVIDER_ID, "mine"), storedEntry("opencode", "theirs")] as StoredCatalog["models"], lastModified: GENERATED_AT + 1 },
						});
		assert.deepEqual(ids(mixed), ["baked-a", "mine"], "the union takes the provider's own entries and leaves the rest");
				});

	// --- failure narrowing ------------------------------------------------

	itCase("L1", "the baked catalog always survives", () => {
		const STORES: (StoredCatalog | undefined)[] = [undefined, FRESH_STORE, storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-stale")], GENERATED_AT - 1)];
		let subsets = 0;
		for (const stored of STORES) {
			for (const liveIds of [undefined, ["live-only", "baked-b"]] as (string[] | undefined)[]) {
				for (const modelsDev of [undefined, MODELS_DEV] as (Record<string, ModelsDevModel> | undefined)[]) {
					subsets++;
					const result = ids(union({ baked: BAKED, stored, liveIds, modelsDev }));
					for (const model of BAKED) {
						assert.ok(result.includes(model.id), `the subset taking away ${describeRow({ stored, liveIds, modelsDev })} removed ${model.id}: ${result.join(", ")}`);
								}
							}
						}
					}
		assert.equal(subsets, 12, "every subset of the three optional sources is covered");
		// The subset that removes all three: the store's own models are gone
		// because the source is, and the baked catalog is untouched.
		const bare = ids(union({ baked: BAKED }));
		assert.deepEqual(bare, ["baked-a", "baked-b", "baked-c"], "no optional source at all serves the baked catalog alone");
				});

	itCase("L2", "a malformed source removes nothing", () => {
		// Every shape carries the well-formed version of the same sources, so
		// each one is judged twice: the well-formed shape names the ids those
		// sources should serve, and the malformed shape is then judged against
		// that same set. A case that only asked whether a malformed source was
		// absorbed would pass against a union that refuses every source,
		// malformed or not.
		const openStore = (models: readonly unknown[]): StoredCatalog => ({ models: models as StoredCatalog["models"], lastModified: GENERATED_AT + 1 });
		const malformed: { label: string; row: Partial<SourceState>; wellFormed: Partial<SourceState> }[] = [
			{
				label: "a store whose models is a string, gate closed",
				row: { stored: { models: "not-an-array" } as unknown as StoredCatalog },
				wellFormed: { stored: undefined },
						},
			{
				label: "a store whose models is a string, gate open",
				row: { stored: { models: "not-an-array", lastModified: GENERATED_AT + 1 } as unknown as StoredCatalog },
				wellFormed: { stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "control-store")], GENERATED_AT + 1) },
						},
			{ label: "a stored array holding null, gate open", row: { stored: openStore([null]) }, wellFormed: { stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "control-store")], GENERATED_AT + 1) } },
			{ label: "a stored array holding a number, gate open", row: { stored: openStore([7]) }, wellFormed: { stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "control-store")], GENERATED_AT + 1) } },
			{
				label: "a stored array holding an object with no id, gate open",
				row: { stored: openStore([{ provider: PROVIDER_ID }]) },
				wellFormed: { stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "control-store")], GENERATED_AT + 1) },
						},
			{
				label: "a stored array holding an entry whose id is a number, gate open",
				row: { stored: openStore([{ provider: PROVIDER_ID, id: 42 }]) },
				wellFormed: { stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "control-store")], GENERATED_AT + 1) },
						},
			{ label: "a live list holding non-strings", row: { liveIds: [42, null, { id: "x" }] as unknown as string[] }, wellFormed: { liveIds: ["control-live"] } },
			{ label: "a live list that is not an array", row: { liveIds: "live-only" as unknown as string[] }, wellFormed: { liveIds: ["control-live"] } },
			{
				label: "a models.dev blob whose entries are not objects",
				row: { modelsDev: { "baked-a": "nope", "live-only": 42 } as unknown as Record<string, ModelsDevModel> },
				wellFormed: { modelsDev: modelsDevEntry("live-only", { limit: { context: 500_000, output: 32_000 } }) },
						},
			{
				label: "a models.dev blob that is not an object",
				row: { modelsDev: "nope" as unknown as Record<string, ModelsDevModel> },
				wellFormed: { modelsDev: modelsDevEntry("baked-a", { limit: { context: 999_000, output: 99_000 } }) },
						},
					];
		// The two halves of the statement are judged apart, because a source the
		// union cannot read and a source the union widens are different defects,
		// and one verdict for both lets either hide the other.
		//
		// The half that reads a shape is judged against the ids the sources
		// legitimately declare, never against the shape of a served entry. The
		// declared set is the baseline plus every id a well-formed part of the
		// row supplies. A served id outside it is a leak; an id inside it that
		// the union dropped is a narrowing. Judging the shape of the entries
		// instead would see nothing on the leak side: a string walked character
		// by character is a list of valid non-empty ids, and that is exactly
		// what a live list which is not an array is.
		const unreadable: string[] = [];
		const overreached: string[] = [];
		for (const shape of malformed) {
			const control = { baked: BAKED, ...shape.wellFormed };
			assert.deepEqual(
				ids(union(control)),
				declaredIds(control),
				`${shape.label}: the well-formed shape of these sources serves exactly the ids those sources declare, so this case cannot pass by refusing them`,
						);
			const row = { baked: BAKED, ...shape.row };
			let served: string[];
			try {
				served = ids(union(row));
			} catch (e) {
				unreadable.push(`${shape.label}: the union threw ${errorMessage(e)}`);
				continue;
						}
			const declared = declaredIds(row);
			const leaked = served.filter((id) => !declared.includes(id));
			const missing = declared.filter((id) => !served.includes(id));
			if (leaked.length > 0) {
				overreached.push(`${shape.label}: served ${leaked.length} id no source declares: ${leaked.join(", ")}`);
						}
			if (missing.length > 0) {
				overreached.push(`${shape.label}: dropped ${missing.length} of ${declared.length} declared ids: ${missing.join(", ")}`);
						}
					}
		assert.deepEqual(overreached, [], "every malformed source the union can read serves the ids its sources declare, and contributes no id of its own");
		if (unreadable.length > 0) {
			// A shape the union cannot read is a crash, not a verdict on the ids,
			// so it is raised rather than asserted. The gate attributes a break
			// to an invariant only when a case failed on an assertion, and a
			// union that throws on every shape breaks far more than this
			// invariant: reading that as proof L2 is pinned would be the
			// catch-all this case is split to avoid.
			throw new Error(`the union could not read a malformed source: ${unreadable.join("; ")}`);
					}
				});

	// --- the composition contract -----------------------------------------

	itCase("C1", "registration never shrinks the catalog", async () => {
		const stores: (StoredCatalog | undefined)[] = [
			undefined,
			storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "space-bunny-free", { name: "Space Bunny Free", contextWindow: 1_048_576, maxTokens: 524_288 })], GENERATED_AT + 1),
			storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "alpha", { contextWindow: 999 }), storedEntry(PROVIDER_ID, "store-only")], GENERATED_AT + 1),
			storedCatalog("opencode", [storedEntry("opencode", "foreign-only")], GENERATED_AT + 1),
			storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "stale-only")], GENERATED_AT - 1),
			storedCatalog(PROVIDER_ID, [], GENERATED_AT + 1),
					];
		for (const stored of stores) {
			const label = stored === undefined ? "an absent store" : `${ids(stored.models as ModelDefinition[]).join(", ") || "an empty store"} at ${String(stored.lastModified)}`;
			const without = await composeOnce(undefined, stored);
			const withExtension = await composeOnce(refreshRegistration, stored);
			const before = ids(without);
			const after = ids(withExtension);
			for (const id of before) {
				assert.ok(after.includes(id), `registering the extension dropped ${id} for ${label}: ${after.join(", ")}`);
				const registered = withExtension.find((model) => model.id === id) as ModelDefinition;
				const bare = without.find((model) => model.id === id) as ModelDefinition;
				for (const field of ["api", "baseUrl", "name", "contextWindow", "maxTokens", "cost"] as const) {
					assert.deepEqual(registered[field], bare[field], `registering the extension changed ${id}.${field} for ${label}`);
							}
						}
			assert.ok(after.length >= before.length, `registering the extension served fewer models for ${label}: ${before.length} then ${after.length}`);
					}
				});

	itCase("C1", "the registration names the provider", async () => {
		// The registration is read from the extension's own entry point, loaded
		// through pi's own loader and package aliases, so what this asserts is
		// the registration pi gets.
		const registrations = await loadRegistration();
		assert.equal(registrations.length, 1, "the extension registers one provider");
		assert.equal(registrations[0].id, PROVIDER_ID, "and it registers the provider the union is built for");
		const { getBuiltinModels } = (await import(BAKED_CATALOG)) as { getBuiltinModels: (providerId: string) => ModelDefinition[] };
		assert.ok(getBuiltinModels(registrations[0].id).length > 0, "the registered provider is one pi carries a baked catalog for");
		assert.deepEqual(registrations[0].config.models, undefined, "and it registers no model list, because that list would become the provider's whole catalog");
				});

	itCase("C2", "no silent fallback", async () => {
		const { resolveCliModel } = (await import(RESOLVER_ENTRY)) as {
			resolveCliModel: (options: { cliProvider?: string; cliModel: string; modelRuntime: unknown }) => Promise<{ model?: ModelDefinition; warning?: string }>;
					};
		const store = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "space-bunny-free", {
			name: "Space Bunny Free",
			contextWindow: 1_048_576,
			maxTokens: 524_288,
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
			input: ["text", "image"],
		})], GENERATED_AT + 1);
		const registered = await composeOnce(refreshRegistration, store);
		const resolved = await resolveCliModel({ cliProvider: PROVIDER_ID, cliModel: "space-bunny-free", modelRuntime: runtimeOf(registered) });
		assert.equal(resolved.warning, undefined, "the id resolves without a fallback warning");
		assert.equal(resolved.model?.contextWindow, 1_048_576, "the model's own context window is served");
		assert.equal(resolved.model?.maxTokens, 524_288, "the model's own output limit is served");
		assert.deepEqual(resolved.model?.cost, { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, "the model's own cost is served, not the fallback model's rate");
		// The control is the registration the previous revision made. pi's
		// unknown-model fallback is buildFallbackModel in dist/core/
		// model-resolver.js: it clones defaultModelPerProvider[provider] and
		// overwrites id and name only, so every other field is the clone's.
		// dist/core/model-runtime.js is the runtime that calls it and holds no
		// fallback builder of its own.
		const withDefect = await composeOnce({ refreshModels: async () => COMPOSED_BAKED }, store);
		const fallback = await resolveCliModel({ cliProvider: PROVIDER_ID, cliModel: "space-bunny-free", modelRuntime: runtimeOf(withDefect) });
		assert.match(fallback.warning ?? "", /not found/, "the control resolves through the fallback, with a warning");
		assert.equal(fallback.model?.contextWindow, 262_144, "the control served the fallback clone's context window");
		assert.equal(fallback.model?.maxTokens, 65_536, "the control served the fallback clone's output limit");
		assert.deepEqual(fallback.model?.cost, { input: 0.95, output: 4, cacheRead: 0, cacheWrite: 0 }, "the control billed the fallback model's rate");
		assert.notDeepEqual(resolved.model?.cost, fallback.model?.cost, "the two paths do not serve the same model");
				});

	itCase("C3", "user overrides win", async () => {
		// The shape a models.json modelOverrides entry takes, applied by pi's
		// own applyModelOverride in dist/core/provider-composer.js: each field
		// the override names wins, and a field it omits keeps the union's.
		const store = storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "space-bunny-free", {
			name: "Space Bunny Free",
			contextWindow: 1_048_576,
			maxTokens: 524_288,
			cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		})], GENERATED_AT + 1);
		const modelConfig = {
			getProvider: () => ({
				modelOverrides: {
					"space-bunny-free": { name: "Local Override", contextWindow: 4_242, maxTokens: 21, cost: { input: 1.5 } },
								},
							}),
			getProviderIds: () => [],
					};
		const plain = await composeOnce(refreshRegistration, store);
		const overridden = await composeOnce(refreshRegistration, store, modelConfig);
		const before = plain.find((model) => model.id === "space-bunny-free") as ModelDefinition;
		const after = overridden.find((model) => model.id === "space-bunny-free") as ModelDefinition;
		assert.equal(after.name, "Local Override", "the override's name survives");
		assert.equal(after.contextWindow, 4_242, "the override's context window replaces the union's");
		assert.equal(after.maxTokens, 21, "the override's output limit replaces the union's");
		// pi's applyModelOverride rebuilds the cost object field by field, so
		// the fields the override names are read one at a time.
		for (const field of COST_FIELDS) {
			assert.equal(after.cost?.[field], field === "input" ? 1.5 : 0, `the override's cost.${field} is the value that survives`);
					}
		assert.equal(after.api, before.api, "a field the override does not name keeps the union's value");
		assert.equal(after.baseUrl, before.baseUrl, "and so does the transport");
		assert.deepEqual(ids(overridden), ids(plain), "the override changes an entry, never the catalog");
				});

	// --- thinking levels --------------------------------------------------

	itCase("T1", "derived levels", async () => {
		const pool = [...THINKING_LEVELS, "none", "ultra-turbo", "minimal", "low", "high"];
		const rng = makeRng(11);
		for (let trial = 0; trial < TRIALS; trial++) {
			const advertised = Array.from({ length: 1 + Math.floor(rng() * 5) }, () => pick(rng, pool));
			const map = levelMapFor(advertised, true);
			for (const key of Object.keys(map)) {
				assert.ok((THINKING_LEVELS as readonly string[]).includes(key), `trial ${trial}: the map carries a level pi does not know, ${key}`);
						}
			const named = new Set(advertised.map((effort) => (effort === "none" ? "off" : effort)).filter((level) => (THINKING_LEVELS as readonly string[]).includes(level)));
			for (const level of THINKING_LEVELS) {
				const value = map[level];
				if (named.has(level)) {
					assert.equal(typeof value, "string", `trial ${trial}: ${advertised.join(", ")} names ${level}, so ${level} is mapped`);
					assert.ok((advertised as string[]).includes(value as string), `trial ${trial}: ${level} maps to ${String(value)}, which the effort list does not name`);
				} else {
					assert.equal(value, null, `trial ${trial}: ${advertised.join(", ")} does not name ${level}, so ${level} is null rather than invented`);
							}
						}
					}
				});

	itCase("T2", "off is the endpoint's disabled state", async () => {
		for (const disabled of ["none", "off"]) {
			const map = thinkingLevelMapFromEfforts([disabled, "low", "high"]);
			assert.equal(map.off, disabled, `an effort list naming ${disabled} maps it onto the off level`);
			assert.equal(offSendsAnEffort(map), true, `the ${disabled} mapping reaches the wire`);
					}
		for (const advertised of [["low", "high"], ["minimal", "medium", "max"], ["low"]]) {
			const map = thinkingLevelMapFromEfforts(advertised);
			assert.equal(map.off, null, `${advertised.join(", ")} names no disabled state, so off is unsupported`);
			assert.equal(offSendsAnEffort(map), false, `${advertised.join(", ")} sends no disable signal`);
					}
		// The agreement, over generated lists: the predicate reads the map and
		// nothing else.
		const rng = makeRng(23);
		const pool = [...THINKING_LEVELS, "none", "ultra-turbo"];
		for (let trial = 0; trial < TRIALS; trial++) {
			const advertised = Array.from({ length: 1 + Math.floor(rng() * 4) }, () => pick(rng, pool));
			const map = thinkingLevelMapFromEfforts(advertised);
			assert.equal(offSendsAnEffort(map), typeof map.off === "string", `trial ${trial}: offSendsAnEffort disagrees with the map for ${advertised.join(", ")}`);
			const { off: _off, ...withoutOff } = map;
			assert.equal(offSendsAnEffort(withoutOff), false, "an absent off key sends no disable signal");
			assert.equal(offSendsAnEffort(undefined), false, "no map sends no disable signal");
					}
				});

	itCase("T3", "the map follows the endpoint", async () => {
		const { getSupportedThinkingLevels } = (await import(THINKING_MODEL_RULES)) as { getSupportedThinkingLevels: (model: unknown) => string[] };
		// A model models.dev says cannot reason, whose entry still advertises an
		// effort list. The two facts are independent, and the case reads the map
		// itself rather than what pi advertises from it, because the advertised
		// set is ["off"] for every model that cannot think whatever the map
		// says: an all-null map and a full one both satisfy that, so the map
		// would go uninspected.
		const efforts = ["none", "low", "high"];
		const quiet = union({ baked: [], liveIds: ["quiet"], modelsDev: modelsDevEntry("quiet", { reasoning: false, reasoning_options: effortList(efforts) }) }).find((model) => model.id === "quiet") as ModelDefinition;
		assert.equal(quiet.reasoning, false, "models.dev says the model cannot reason, and the entry says so");
		assert.deepEqual(
			quiet.thinkingLevelMap,
			expectedLevelMap(efforts),
			`the map is the endpoint's effort list, level for level, and the reasoning flag does not change it: got ${JSON.stringify(quiet.thinkingLevelMap)}`,
					);
		// What the flag buys is that pi advertises no level above off for it, so
		// the level picker stays hidden: getSupportedThinkingLevels in pi-ai
		// dist/models.js is the product of that rule.
		assert.deepEqual(getSupportedThinkingLevels(quiet), ["off"], "a model that cannot think advertises no thinking level above off");
		assert.deepEqual(advertisedLevels(quiet), [], "and the suite's own reading of the entry agrees");
		const loud = union({ baked: [], liveIds: ["loud"], modelsDev: modelsDevEntry("loud", { reasoning: true, reasoning_options: effortList([]) }) }).find((model) => model.id === "loud") as ModelDefinition;
		assert.deepEqual(loud.thinkingLevelMap, expectedLevelMap([]), `a model with no advertised efforts carries the fallback range: got ${JSON.stringify(loud.thinkingLevelMap)}`);
		const usable = Object.values(loud.thinkingLevelMap ?? {}).filter((value) => typeof value === "string");
		assert.ok(usable.length > 0, `a reasoning model with no advertised efforts keeps a usable range, got ${JSON.stringify(loud.thinkingLevelMap)}`);
		assert.deepEqual(getSupportedThinkingLevels(loud), [...THINKING_LEVELS].filter((level) => typeof loud.thinkingLevelMap?.[level] === "string"), "pi advertises exactly the levels the map names");
		assert.ok(Object.values(levelMapFor([], true)).some((value) => typeof value === "string"), "the empty-list fallback is a range, not an all-null map");
		assert.ok(Object.values(levelMapFor(undefined, true)).some((value) => typeof value === "string"), "and so is the absent-list fallback");
				});

	itCase("T3", "the family keeps its transport", () => {
		// The deepseek toggle is a property of the model family, not of what the
		// endpoint advertises: a deepseek model sends `thinking` with the level in
		// `reasoning_effort` (pi-ai dist/api/openai-completions.js), and the
		// family keeps that shape whether or not models.dev lists its efforts.
		const family = "deepseek-live";
		const withEfforts = union({ baked: [], liveIds: [family], modelsDev: modelsDevEntry(family, { reasoning_options: effortList(["low", "high"]) }) })[0];
		assert.equal(withEfforts.compat?.thinkingFormat, "deepseek", "a deepseek-family id advertising efforts keeps the deepseek transport");
		assert.deepEqual(withEfforts.compat, expectedLiveCompat(withEfforts.api, family, ["low", "high"]), "and the whole compat block is the deepseek one");
		const withoutEfforts = union({ baked: [], liveIds: [family] })[0];
		assert.equal(withoutEfforts.compat?.thinkingFormat, "deepseek", "a deepseek-family id models.dev has no efforts for keeps the deepseek transport");
		assert.deepEqual(withoutEfforts.compat, expectedLiveCompat(withoutEfforts.api, family, undefined), "and the whole compat block is the deepseek one");
		// The converse: outside the family, advertised efforts mean the chat
		// transport, so the flag cannot be pinned by advertising anything.
		const other = "some-other-live";
		const chat = union({ baked: [], liveIds: [other], modelsDev: modelsDevEntry(other, { reasoning_options: effortList(["low", "high"]) }) })[0];
		assert.equal(chat.compat?.thinkingFormat, undefined, "an id outside the deepseek family does not get the deepseek transport");
		assert.equal(chat.compat?.requiresReasoningContentOnAssistantMessages, undefined, "nor the deepseek assistant-message flag");
		assert.deepEqual(chat.compat, expectedLiveCompat(chat.api, other, ["low", "high"]), "and the whole compat block is the chat one");
		// A family id that is not on this endpoint is unaffected: the rule is
		// about the family, not about a substring anywhere in the id.
		const named = "not-deepseek-live";
		const namedChat = union({ baked: [], liveIds: [named], modelsDev: modelsDevEntry(named, { reasoning_options: effortList(["low"]) }) })[0];
		assert.equal(namedChat.compat?.thinkingFormat, undefined, "an id that merely contains the family name is not in the family");
				});

	for (const level of THINKING_LEVELS) {
		itCase("T4", `level ${level}`, async () => {
			assert.deepEqual(
				catalog.filter((candidate) => candidate.id === "T4").map((candidate) => candidate.name),
				THINKING_LEVELS.map((entry) => `level ${entry}`),
				"the per-level cases are derived from the extension's own level list, not written here",
						);
			// The endpoint names the level: it is advertised, and the payload
			// carries the effort the map names for it.
			const named = level === "off" ? "none" : level;
			const advertised = [named, ...["none", "low", "high"].filter((effort) => effort !== named)];
			const served = union({ baked: [], liveIds: ["probe"], modelsDev: modelsDevEntry("probe", { reasoning_options: effortList(advertised) }) }).find((model) => model.id === "probe") as ModelDefinition;
			assert.ok(advertisedLevels(served).includes(level), `${advertised.join(", ")} names ${level}, so the union advertises it`);
			assert.equal(served.thinkingLevelMap?.[level], named, `the map names the endpoint's own effort for ${level}`);
			assert.deepEqual(await captureThinkingPayload(served, level), { reasoning_effort: named }, `the payload at ${level} carries the effort the map names`);
			// The endpoint does not name it: the level is unsupported, the
			// payload carries no effort of its own, and thinking stays on.
			//
			// Where the request lands is pi's answer, not the suite's: the
			// expectation is `clampThinkingLevel` from pi-ai dist/models.js, so
			// the case states what pi does with the level rather than what the
			// extension hopes pi does. The suite does not restate the clamp.
			const { clampThinkingLevel } = (await import(THINKING_MODEL_RULES)) as { clampThinkingLevel: (model: unknown, level: string) => string };
			const unadvertised = ["none", "low", "high"].filter((effort) => effort !== named);
			const quiet = union({ baked: [], liveIds: ["probe"], modelsDev: modelsDevEntry("probe", { reasoning_options: effortList(unadvertised) }) }).find((model) => model.id === "probe") as ModelDefinition;
			assert.ok(!advertisedLevels(quiet).includes(level), `${unadvertised.join(", ")} does not name ${level}, so the union does not advertise it`);
			const fields = await captureThinkingPayload(quiet, level);
			const effort = fields.reasoning_effort;
			assert.notEqual(effort, named, `the payload at ${level} carries no effort named for it`);
			assert.notEqual(effort, "none", "and no disabled effort the endpoint never advertised");
			assert.equal(typeof effort, "string", `the payload at ${level} still carries an effort: the level is clamped, not dropped`);
			const clamped = clampThinkingLevel(quiet, level);
			assert.notEqual(clamped, level, `pi does not advertise ${level} here, so the request is clamped`);
			assert.equal(effort, quiet.thinkingLevelMap?.[clamped], `pi clamps ${level} to ${clamped}, and the payload carries the effort that level's mapping names`);
			if (level === "xhigh" || level === "max") {
				// The downward half of the search, on the two levels above the
				// range this ladder carries. A ladder of {none, low, high} names
				// no level above high, so a request for either of them lands on
				// high: pi answers with the nearest level the model advertises,
				// not with the level the caller asked for (README A5). The
				// fallback range below keeps that true for a model that
				// advertises nothing at all, which is the state the downward
				// search was measured on.
				assert.equal(clamped, "high", `${unadvertised.join(", ")} stops at high, so a request for ${level} is clamped down to high`);
				assert.equal(effort, "high", `and the payload at ${level} carries high`);
						}
			if (level === "max") {
				// The same direction on the range the extension falls back to
				// when an endpoint advertises no effort at all. That range stops
				// at high: it names no level between low and high, and none above
				// high either, so a request for `max` is answered with `high` and
				// not with `max`.
				const silent = union({ baked: [], liveIds: ["silent"], modelsDev: modelsDevEntry("silent") })[0];
				assert.equal(silent.thinkingLevelMap?.max, null, "an endpoint that advertises no effort leaves max unsupported");
				assert.equal(silent.thinkingLevelMap?.xhigh, null, "and xhigh with it, so the fallback range names no level above high");
				assert.equal(clampThinkingLevel(silent, "max"), "high", "so a request for max is clamped down to high");
				assert.equal((await captureThinkingPayload(silent, "max")).reasoning_effort, "high", "and high is what reaches the wire");
						}
			if (level === "xhigh") {
				// The upward half of the same search, so the two directions are
				// told apart: a ladder that names `max` and skips `xhigh`
				// answers a request for `xhigh` with the level above it, which is
				// the case that made the fallback range drop `max`.
				const gap = union({ baked: [], liveIds: ["gap"], modelsDev: modelsDevEntry("gap", { reasoning_options: effortList(["none", "low", "high", "max"]) }) })[0];
				assert.equal(clampThinkingLevel(gap, "xhigh"), "max", "a ladder that names max and skips xhigh answers a request for xhigh with max");
				assert.equal((await captureThinkingPayload(gap, "xhigh")).reasoning_effort, "max", "and max is what reaches the wire");
						}
					});
			}

	// --- the wire, and determinism ----------------------------------------

	itCase("W1", "the wire shape follows the map", async () => {
		const { getBuiltinModels } = (await import(BAKED_CATALOG)) as { getBuiltinModels: (providerId: string) => ModelDefinition[] };
		const { getSupportedThinkingLevels } = (await import(THINKING_MODEL_RULES)) as { getSupportedThinkingLevels: (model: unknown) => string[] };
		const catalogEntries = getBuiltinModels(PROVIDER_ID);
		assert.ok(catalogEntries.length > 0, "pi ships a catalog for the provider");
		let builds = 0;
		let budgetOnly = 0;
		for (const model of catalogEntries) {
			const advertised = advertisedLevels(model);
			assert.deepEqual(advertised, getSupportedThinkingLevels(model), `${model.id}: the levels the suite derives from the map are the levels pi advertises`);
			for (const level of advertised) {
				const fields = await captureThinkingPayload(model, level);
				builds++;
				if (model.api === "anthropic-messages") {
					// This transport sends a token budget, not an effort, and the
					// two models pi ships on it carry no level map at all. The
					// observation is pinned rather than derived: pi enables
					// thinking at every level on them, the off level included,
					// and the extension serves the baked entry unchanged.
					budgetOnly++;
					assert.equal((fields.thinking as { type?: string } | undefined)?.type, "enabled", `${model.id} at ${level}: the anthropic-messages transport carries a thinking block`);
					assert.equal(fields.reasoning_effort, undefined, `${model.id} at ${level}: no effort reaches the wire on this transport`);
					continue;
							}
				assert.deepEqual(fields, expectedThinkingFields(model, level), `${model.id} at ${level}: the payload carries the effort the map names`);
						}
					}
		assert.ok(builds <= 400, `the case stays a few hundred payload builds, got ${builds}`);
		const budgetModels = catalogEntries.filter((model) => model.api === "anthropic-messages");
		assert.equal(budgetOnly, budgetModels.reduce((total, model) => total + advertisedLevels(model).length, 0), "every budget-shaped model took the budget branch, so the branch is never vacuous");
				});

	itCase("D1", "determinism", async () => {
		const row: SourceState = {
			baked: BAKED,
			stored: storedCatalog(PROVIDER_ID, [storedEntry(PROVIDER_ID, "store-a"), storedEntry(PROVIDER_ID, "baked-b", { contextWindow: 9 })], GENERATED_AT + 1),
			liveIds: ["live-only", "baked-a", "live-two"],
			modelsDev: { ...MODELS_DEV, ...modelsDevEntry("live-two", { name: "Live Two", limit: { context: 42, output: 4 } }) },
					};
		const first = union(row);
		assert.deepEqual(union(row), first, "two calls with equal inputs yield the same union");
		assert.deepEqual(union({ ...row }), first, "and so does a third call over a fresh copy of the inputs");
		// The order the optional sources are handed over in is not the order
		// the union is built in: the ids and the entries behind them do not move.
		const reordered: SourceState = {
			...row,
			stored: storedCatalog(PROVIDER_ID, [...(row.stored?.models ?? [])].reverse() as StoredEntry[], GENERATED_AT + 1),
			liveIds: [...(row.liveIds ?? [])].reverse(),
			modelsDev: Object.fromEntries(Object.entries(row.modelsDev ?? {}).reverse()),
					};
		const shuffled = union(reordered);
		assert.deepEqual([...ids(shuffled)].sort(), [...ids(first)].sort(), "the served ids do not depend on the order the sources arrive in");
		for (const entry of shuffled) {
			assert.deepEqual(entry, first.find((model) => model.id === entry.id), `${entry.id}: the entry does not depend on the order the sources arrive in`);
					}
				});

	// --- the test layer over itself ----------------------------------------

	itCase("R1", "one catalog case, one test", () => {
		// Both sides are compared, because either side alone leaves a gap: the
		// catalog cannot tell a case that is never run from one that is, and the
		// test list cannot tell a test the report cannot index from one it can.
		// The registered list is complete before the first case runs, so the
		// comparison does not depend on the order the cases run in.
		const catalogCases = buildCatalog()
			.map((entry) => `${entry.id} ${entry.name}`)
			.sort();
		for (const key of catalogCases) {
			assert.ok(registered.includes(key), `the catalog case ${key} has no test, so it is never run`);
					}
		for (const key of registered) {
			assert.ok(catalogCases.includes(key), `the test ${key} names no catalog case, so the report cannot index it`);
					}
		assert.deepEqual([...registered].sort(), catalogCases, "every catalog case is claimed by a test, and every claimed case is in the catalog");
		assert.equal(new Set(registered).size, registered.length, "no case is claimed by two tests");
				});
		});

/** A row's optional sources, named for a failure message. */
function describeRow(row: Partial<SourceState>): string {
	const parts = [row.stored === undefined ? "no store" : "a store", row.liveIds === undefined ? "no live list" : "a live list", row.modelsDev === undefined ? "no models.dev" : "models.dev"];
	return parts.join(", ");
	}
