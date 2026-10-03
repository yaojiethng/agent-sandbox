/**
 * Gathering the secondary sources and building the union.
 *
 * This module performs the network work and nothing else. It imports no pi
 * package at runtime -- pi's baked catalog and its data timestamp arrive as
 * parameters -- so the whole failure contract is testable with an injected
 * fetcher, no network and no API key. `index.ts` is the thin registration that
 * supplies them.
 *
 * A source that fails yields `undefined`, never an empty list. An empty list is
 * indistinguishable from a successful answer that advertises nothing, and
 * treating it as one would let a transient outage look like a provider that
 * dropped every model.
 */

import { buildUnion } from "./catalog.ts";
import type { CatalogReport, FetchJson, ModelDefinition, ModelsDevModel, ProviderDecl, StoredCatalog } from "./types.ts";

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
	providerId: string;
	decl: ProviderDecl;
	signal: AbortSignal;
	allowNetwork: boolean;
	/** Pi's persisted catalog entry, as handed to `refreshModels`. */
	stored: StoredCatalog | undefined;
	/** The baked data's generation timestamp, from pi's providers module. */
	generatedAt: number | undefined;
	/** Pi's baked catalog for the provider. */
	baked: readonly ModelDefinition[];
	fetcher: FetchJson;
	log?: (message: string) => void;
	/**
	 * Receives the per-source counts once the union is built. Additive, so a
	 * caller that only wants the list passes nothing and is unaffected.
	 */
	onReport?: (report: CatalogReport) => void;
}

/** The list the extension serves, from whatever sources are declared and available. */
export async function gatherAndBuild(input: GatherInput): Promise<ModelDefinition[]> {
	const { providerId, decl, signal, allowNetwork, stored, generatedAt, baked, fetcher, log, onReport } = input;
	const note = log ?? (() => {});
	const failures: string[] = [];
	const unionInput = { providerId, decl, baked, stored, generatedAt };

	if (!allowNetwork) {
		const models = buildUnion({ ...unionInput, endpointIds: undefined, modelsDev: undefined });
		onReport?.({
			providerId,
			endpoint: undefined,
			modelsDev: undefined,
			baked: baked.length,
			stored: stored?.models?.length ?? 0,
			served: models.length,
			failures: [...failures],
		});
		return models;
	}

	let endpointIds: string[] | undefined;
	if (decl.endpoint) {
		try {
			const payload = await fetcher<{ data?: { id?: string }[] }>(decl.endpoint, signal);
			endpointIds = (payload?.data ?? []).map((entry) => entry?.id).filter((id): id is string => !!id);
			note(`endpoint model list: ${endpointIds.length} models from ${decl.endpoint}`);
		} catch (error) {
			const reason = `endpoint fetch failed (${(error as Error)?.message}); serving the sources that answered`;
			failures.push(reason);
			note(reason);
		}
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

	const models = buildUnion({ ...unionInput, endpointIds, modelsDev });
	if (onReport) {
		onReport({
			providerId,
			endpoint: endpointIds?.length,
			modelsDev: modelsDev ? Object.keys(modelsDev).length : undefined,
			baked: baked.length,
			stored: stored?.models?.length ?? 0,
			served: models.length,
			failures: [...failures],
		});
	}
	return models;
}
