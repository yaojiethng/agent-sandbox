/**
 * The composition contract, exercised through pi's own composer.
 *
 * This is the regression test for the defect the previous revision of this
 * extension caused. The defect is not visible in the union functions: it
 * appears only after pi composes the extension onto the provider, because
 * pi's legacy registration form makes the `refreshModels` return value the
 * provider's whole catalog. So the test drives pi's real
 * `composeModelProvider`, with no model runtime, no network, and no API key,
 * and asserts what `getModels()` returns afterwards.
 *
 * Each case builds the same provider twice: once with the registration this
 * extension used to make, and once with the one it makes now. The pair is the
 * proof that the test would have caught the defect rather than merely passing
 * on the fixed code.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import { createRequire } from "node:module";

import { gatherAndBuild } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts";
import { buildUnion } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";
import type { ModelDefinition, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";
import { PROVIDER_ID, TEST_DECL } from "./fixtures.ts";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const COMPOSER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/provider-composer.js`;

const piAvailable = () => fs.existsSync(COMPOSER_ENTRY);
const skip = () => (piAvailable() ? false : "pi installation not present");

const V1_BASE = "https://opencode.ai/zen/go/v1";
const GENERATED_AT = 1_000_000;

function baked(id: string): ModelDefinition {
	return { id, name: id, api: "openai-completions", baseUrl: V1_BASE, reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 100_000, maxTokens: 8_000 };
}

const BAKED = [baked("alpha"), baked("beta")];

/** The extension's own gather, bound to the declaration the suite drives. */
const gatherFrom = (context: { signal: AbortSignal; allowNetwork: boolean; stored?: StoredCatalog }) =>
	gatherAndBuild({ providerId: PROVIDER_ID, decl: TEST_DECL, signal: context.signal, allowNetwork: context.allowNetwork, stored: context.stored, generatedAt: GENERATED_AT, baked: BAKED, fetcher: async () => ({}) as never });

const STORE_ONLY = baked("space-bunny-free");

const STORE: StoredCatalog = {
	models: [{ ...STORE_ONLY, name: "Space Bunny Free", contextWindow: 1_048_576, maxTokens: 524_288, provider: "opencode-go" } as never],
	lastModified: GENERATED_AT + 1,
	checkedAt: GENERATED_AT + 2,
};

/** A stand-in for pi's built-in provider: baked models plus its own refresh hook. */
function baseProvider() {
	let dynamic: ModelDefinition[] = [];
	return {
		id: "opencode-go",
		name: "OpenCode Go",
		auth: { apiKey: { name: "key", check: async () => undefined, resolve: async () => undefined, login: async () => ({ type: "api_key", key: "x" }) } },
		getModels: () => [...BAKED, ...dynamic.filter((m) => !BAKED.some((b) => b.id === m.id))],
		refreshModels: async (context: { stored?: StoredCatalog; publish: (p: { update?: () => void }) => Promise<boolean> }) => {
			const restored = (context.stored?.models ?? []).filter((m) => (m as { provider?: string }).provider === "opencode-go") as ModelDefinition[];
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

/** A context shaped like the one pi passes to `refreshModels`. */
function refreshContext(stored: StoredCatalog | undefined) {
	const publications: { update?: () => void }[] = [];
	return {
		context: {
			signal: new AbortController().signal,
			allowNetwork: false,
			stored,
			publish: async (publication: { update?: () => void }) => {
				publications.push(publication);
				publication.update?.();
				return true;
			},
		},
		publications,
	};
}

/** Compose an extension registration onto a base provider and refresh it once. */
async function composeAndRefresh(registration: { refreshModels: (context: never) => Promise<ModelDefinition[]> }, stored: StoredCatalog | undefined) {
	const { composeModelProvider } = await import(COMPOSER_ENTRY);
	const modelConfig = { getProvider: () => undefined, getProviderIds: () => [] };
	const composed = composeModelProvider("opencode-go", baseProvider() as never, modelConfig as never, registration as never);
	await composed.refreshModels?.(refreshContext(stored).context as never);
	return composed.getModels();
}

const ids = (models: readonly { id: string }[]) => models.map((model) => model.id);

describe("the persisted pi.dev catalog survives composition", { skip: skip() }, () => {
	it("keeps a model only the store carries", async () => {
		const models = await composeAndRefresh(
			{ refreshModels: (context) => gatherFrom(context) },
			STORE,
		);
		assert.ok(ids(models).includes("space-bunny-free"), `the store model is served, got ${ids(models).join(", ")}`);
	});

	it("serves the store's metadata, not the baked catalog's", async () => {
		const models = await composeAndRefresh(
			{ refreshModels: (context) => gatherFrom(context) },
			STORE,
		);
		const served = models.find((model) => model.id === "space-bunny-free");
		assert.equal(served?.contextWindow, 1_048_576);
		assert.equal(served?.maxTokens, 524_288);
		assert.equal(served?.name, "Space Bunny Free");
	});

	it("does not duplicate a model the store and the baked catalog share", async () => {
		const shared = { ...baked("alpha"), provider: "opencode-go", contextWindow: 999 };
		const models = await composeAndRefresh(
			{ refreshModels: (context) => gatherFrom(context) },
			{ models: [shared] as never, lastModified: GENERATED_AT + 1 },
		);
		assert.equal(ids(models).filter((id) => id === "alpha").length, 1, `no duplicate, got ${ids(models).join(", ")}`);
		assert.equal(models.find((model) => model.id === "alpha")?.contextWindow, 999, "the fresher entry wins");
	});
});

describe("the defect this extension used to cause", { skip: skip() }, () => {
	it("loses the store model when the registration returns only the baked catalog", async () => {
		const models = await composeAndRefresh({ refreshModels: async () => BAKED }, STORE);
		assert.ok(!ids(models).includes("space-bunny-free"), "the old registration drops the store model, which is the defect");
	});

	it("is not reproduced by the registration this extension makes", async () => {
		const withDefect = await composeAndRefresh({ refreshModels: async () => BAKED }, STORE);
		const asFixed = await composeAndRefresh(
			{ refreshModels: (context) => gatherFrom(context) },
			STORE,
		);
		assert.ok(ids(withDefect).length < ids(asFixed).length, `the fix serves strictly more models: ${ids(withDefect).length} then ${ids(asFixed).length}`);
	});
});

describe("buildUnion is what the composition sees", () => {
	it("returns the baked catalog when every optional source is absent", () => {
		const models = buildUnion({ providerId: PROVIDER_ID, decl: TEST_DECL, baked: BAKED, stored: undefined, generatedAt: GENERATED_AT, endpointIds: undefined, modelsDev: undefined });
		assert.deepEqual(ids(models), ["alpha", "beta"]);
	});
});
