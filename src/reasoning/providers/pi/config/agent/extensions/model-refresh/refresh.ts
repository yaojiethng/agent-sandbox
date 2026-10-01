/**
 * Gathering the live sources and building the union.
 *
 * This module performs the network work and nothing else. It imports no pi
 * package at runtime -- pi's baked catalog and its data timestamp arrive as
 * parameters -- so the whole failure contract is testable with an injected
 * fetcher, no network and no API key. `index.ts` is the thin registration that
 * supplies them.
 *
 * A live source that fails yields `undefined`, never an empty list. An empty
 * list is indistinguishable from a successful answer that advertises nothing,
 * and treating it as one would let a transient outage look like a provider
 * that dropped every model.
 */

import { buildUnion, V1_BASE } from "./catalog.ts";
import type { CatalogReport, FetchJson, ModelDefinition, ModelsDevModel, StoredCatalog } from "./types.ts";

export const PROVIDER_ID = "opencode-go";
export const LIVE_MODELS_URL = `${V1_BASE}/models`;
export const MODELS_DEV_URL = "https://models.dev/api.json";
export const FETCH_TIMEOUT_MS = 15_000;

/** Fetch JSON, bounded by both the caller's signal and a timeout. */
export const fetchJson: FetchJson = async <T>(url: string, signal: AbortSignal): Promise<T> => {
	const merged = AbortSignal.any([signal, AbortSignal.timeout(FETCH_TIMEOUT_MS)]);
	const response = await fetch(url, { signal: merged });
	if (!response.ok) {
		throw new Error(`HTTP ${response.status} from ${url}`);
	}
	return (await response.json()) as T;
};

export interface GatherInput {
	signal: AbortSignal;
	allowNetwork: boolean;
	/** Pi's persisted catalog entry, as handed to `refreshModels`. */
	stored: StoredCatalog | undefined;
	/** The baked data's generation timestamp, from pi's providers module. */
	generatedAt: number | undefined;
	/** Pi's baked catalog for the provider. */
	baked: readonly ModelDefinition[];
	fetcher: FetchJson;
	providerId?: string;
	log?: (message: string) => void;
	/**
	 * Receives the per-source counts once the union is built. Additive, so a
	 * caller that only wants the list passes nothing and is unaffected.
	 */
	onReport?: (report: CatalogReport) => void;
}

/** The list the extension serves, from whatever sources are available. */
export async function gatherAndBuild(input: GatherInput): Promise<ModelDefinition[]> {
	const { signal, allowNetwork, stored, generatedAt, baked, fetcher, log, onReport } = input;
	const providerId = input.providerId ?? PROVIDER_ID;
	const note = log ?? (() => {});
	const failures: string[] = [];

	if (!allowNetwork) {
		const models = buildUnion({ baked, stored, generatedAt, liveIds: undefined, modelsDev: undefined, providerId });
		onReport?.({
			liveIds: undefined,
			modelsDev: undefined,
			baked: baked.length,
			stored: stored?.models?.length ?? 0,
			served: models.length,
			failures: [...failures],
		});
		return models;
	}

	let liveIds: string[] | undefined;
	try {
		const payload = await fetcher<{ data?: { id?: string }[] }>(LIVE_MODELS_URL, signal);
		liveIds = (payload?.data ?? [])
			.map((entry) => entry?.id)
			.filter((id): id is string => !!id);
		note(`live model list: ${liveIds.length} models from ${LIVE_MODELS_URL}`);
	} catch (error) {
		const reason = `live /models fetch failed (${(error as Error)?.message}); serving the baked and persisted catalogs`;
		failures.push(reason);
		note(reason);
	}

	let modelsDev: Record<string, ModelsDevModel> | undefined;
	try {
		const payload = await fetcher<Record<string, { models?: Record<string, ModelsDevModel> }>>(MODELS_DEV_URL, signal);
		modelsDev = payload?.[providerId]?.models;
		note(`models.dev metadata: ${Object.keys(modelsDev ?? {}).length} ${providerId} entries`);
	} catch (error) {
		const reason = `models.dev metadata unavailable (${(error as Error)?.message}); using baked metadata`;
		failures.push(reason);
		note(reason);
	}

	const models = buildUnion({ baked, stored, generatedAt, liveIds, modelsDev, providerId });
	if (onReport) {
		onReport({
			liveIds: liveIds?.length,
			modelsDev: modelsDev ? Object.keys(modelsDev).length : undefined,
			baked: baked.length,
			stored: stored?.models?.length ?? 0,
			served: models.length,
			failures: [...failures],
		});
	}
	return models;
}
