/**
 * The fetch orchestration around the union.
 *
 * The fetcher is injected, so every path here runs with no network and no API
 * key. What is under test is the failure contract: a source that fails must
 * narrow the catalog, never remove a model another source supplied. The
 * previous revision returned the bare baked catalog on every failure path,
 * which is how the persisted pi.dev catalog was lost.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { gatherAndBuild } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/refresh.ts";
import type { CatalogReport, FetchJson, ModelDefinition, StoredCatalog } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";
import { PROVIDER_ID, TEST_DECL, V1_BASE } from "./fixtures.ts";

const GENERATED_AT = 1_000_000;

function baked(id: string): ModelDefinition {
	return { id, name: id, api: "openai-completions", baseUrl: V1_BASE, reasoning: true, input: ["text"], cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 }, contextWindow: 100_000, maxTokens: 8_000 };
}

const BAKED = [baked("alpha")];
const STORE: StoredCatalog = {
	models: [{ ...baked("from-store"), provider: "opencode-go" } as never],
	lastModified: GENERATED_AT + 1,
	checkedAt: GENERATED_AT + 2,
};

const LIVE_PAYLOAD = { data: [{ id: "alpha" }, { id: "live-only" }] };
const MODELS_DEV_PAYLOAD = { "opencode-go": { models: { "live-only": { name: "Live Only" } } } };

/** A fetcher serving the two live URLs, recording every call. */
function okFetcher(calls: string[] = []): FetchJson {
	return async <T>(url: string): Promise<T> => {
		calls.push(url);
		if (url.endsWith("/models")) {
			return LIVE_PAYLOAD as T;
		}
		return MODELS_DEV_PAYLOAD as T;
	};
}

const gather = (over: Partial<Parameters<typeof gatherAndBuild>[0]> = {}) =>
	gatherAndBuild({
		providerId: PROVIDER_ID,
		decl: TEST_DECL,
		signal: new AbortController().signal,
		allowNetwork: true,
		stored: STORE,
		generatedAt: GENERATED_AT,
		baked: BAKED,
		fetcher: okFetcher(),
		...over,
	});

const ids = (models: readonly ModelDefinition[]) => models.map((model) => model.id);

describe("the offline phase", () => {
	it("never calls the fetcher", async () => {
		const calls: string[] = [];
		await gatherAndBuild({
			providerId: PROVIDER_ID,
			decl: TEST_DECL,
			signal: new AbortController().signal,
			allowNetwork: false,
			stored: STORE,
			generatedAt: GENERATED_AT,
			baked: BAKED,
			fetcher: okFetcher(calls),
		});
		assert.deepEqual(calls, [], "no network in the offline phase");
	});

	it("still serves the persisted catalog", async () => {
		const models = await gather({ allowNetwork: false });
		assert.deepEqual(ids(models), ["alpha", "from-store"]);
	});
});

describe("the network phase", () => {
	it("calls both live endpoints", async () => {
		const calls: string[] = [];
		await gather({ fetcher: okFetcher(calls) });
		assert.equal(calls.length, 2, "the model list and the models.dev metadata are both read");
		assert.ok(calls[0].endsWith("/models"), `first call is the model list, got ${calls[0]}`);
		assert.ok(calls[1].includes("models.dev"), `second call is models.dev, got ${calls[1]}`);
	});

	it("serves baked, store, and live-only models together", async () => {
		assert.deepEqual(ids(await gather()), ["alpha", "from-store", "live-only"]);
	});

	it("names a live-only model from models.dev", async () => {
		const served = (await gather()).find((model) => model.id === "live-only");
		assert.equal(served?.name, "Live Only");
	});
});

describe("a failing live source narrows the catalog, it does not empty it", () => {
	it("keeps the baked and store models when the model list fails", async () => {
		const failing: FetchJson = async <T>(url: string): Promise<T> => {
			if (url.endsWith("/models")) {
				throw new Error("HTTP 503 from the model list");
			}
			return MODELS_DEV_PAYLOAD as T;
		};
		assert.deepEqual(ids(await gather({ fetcher: failing })), ["alpha", "from-store"]);
	});

	it("keeps the baked and store models when models.dev fails", async () => {
		const failing: FetchJson = async <T>(url: string): Promise<T> => {
			if (url.endsWith("/models")) {
				return LIVE_PAYLOAD as T;
			}
			throw new Error("models.dev unreachable");
		};
		const models = await gather({ fetcher: failing });
		assert.deepEqual(ids(models), ["alpha", "from-store", "live-only"], "the live-only model is still built, on defaults");
		assert.equal(models.find((model) => model.id === "live-only")?.name, "live-only");
	});

	it("keeps the baked and store models when both live sources fail", async () => {
		const failing: FetchJson = async (): Promise<never> => {
			throw new Error("network down");
		};
		assert.deepEqual(ids(await gather({ fetcher: failing })), ["alpha", "from-store"]);
	});

	it("survives a payload that is not the shape it expects", async () => {
		const wrong: FetchJson = async <T>(): Promise<T> => ({ nothing: true }) as T;
		assert.deepEqual(ids(await gather({ fetcher: wrong })), ["alpha", "from-store"], "the live entry with no id is not built, and the earlier sources are untouched");
	});

	it("survives a models.dev blob with no entry for the provider", async () => {
		const other: FetchJson = async <T>(url: string): Promise<T> =>
			(url.endsWith("/models") ? LIVE_PAYLOAD : { "somebody-else": { models: {} } }) as T;
		const models = await gather({ fetcher: other });
		assert.equal(models.find((model) => model.id === "live-only")?.name, "live-only", "defaults, not a crash");
	});

	it("survives a live list whose entries carry no id", async () => {
		const idless: FetchJson = async <T>(url: string): Promise<T> =>
			(url.endsWith("/models") ? { data: [{}, { id: "" }, { id: "kept" }] } : MODELS_DEV_PAYLOAD) as T;
		assert.deepEqual(ids(await gather({ fetcher: idless })), ["alpha", "from-store", "kept"]);
	});

	it("reports the failure and keeps serving, rather than throwing into startup", async () => {
		const logged: string[] = [];
		const failing: FetchJson = async (): Promise<never> => {
			throw new Error("network down");
		};
		const models = await gather({ fetcher: failing, log: (message) => logged.push(message) });
		assert.equal(models.length, 2, "the catalog is still served");
		assert.ok(logged.some((message) => message.includes("network down")), `the failure is logged, got ${JSON.stringify(logged)}`);
	});
});

describe("the report is the catalog transition, not the source counts", () => {
	const reportOf = async (over: Partial<Parameters<typeof gatherAndBuild>[0]> = {}): Promise<CatalogReport> => {
		let report: CatalogReport | undefined;
		await gather({ ...over, onReport: (next) => { report = next; } });
		assert.ok(report, "the report is emitted");
		return report;
	};

	it("reports no change when only the offline catalog is served", async () => {
		const report = await reportOf({ allowNetwork: false });
		assert.deepEqual(report, { providerId: PROVIDER_ID, changed: false, added: 0, removed: 0, revised: 0, failures: [] });
	});

	it("reports what the live sources added on the first refresh", async () => {
		const report = await reportOf();
		assert.deepEqual(report, { providerId: PROVIDER_ID, changed: true, added: 1, removed: 0, revised: 0, failures: [] });
	});

	it("is a zero delta when a later refresh serves the same catalog", async () => {
		const first = await gather();
		const report = await reportOf({ previous: first });
		assert.deepEqual(report, { providerId: PROVIDER_ID, changed: false, added: 0, removed: 0, revised: 0, failures: [] });
	});

	it("carries the failure even when the catalog did not change", async () => {
		const failing: FetchJson = async (): Promise<never> => {
			throw new Error("network down");
		};
		const report = await reportOf({ fetcher: failing });
		assert.equal(report.changed, false, "the failed live phase falls back to the offline union, so the catalog did not move");
		assert.equal(report.failures.length, 2, "one line per failed live source");
	});
});
