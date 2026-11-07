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

import { buildUnion, diffCatalogs } from "./catalog.ts";
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
	/** The extension's own cache entries, read in the offline phase. */
	cache?: readonly ModelDefinition[];
	/** Replaces the declared endpoint's cache record after a successful answer. */
	writeCache?: (entries: readonly ModelDefinition[]) => { ok: true } | { ok: false; reason: string };
	/**
	 * The served catalog before this refresh. The first refresh passes nothing,
	 * so the before state is the offline union - the catalog the extension serves
	 * with no live source - which makes the first report the live contribution and
	 * a later report the change since the last refresh.
	 */
	previous?: readonly ModelDefinition[];
	fetcher: FetchJson;
	log?: (message: string) => void;
	/**
	 * Receives the catalog delta once the union is built. Additive, so a caller
	 * that only wants the list passes nothing and is unaffected.
	 */
	onReport?: (report: CatalogReport) => void;
}

/** The list the extension serves, from whatever sources are declared and available. */
export async function gatherAndBuild(input: GatherInput): Promise<ModelDefinition[]> {
	const { providerId, decl, signal, allowNetwork, stored, generatedAt, baked, previous, cache, writeCache, fetcher, log, onReport } = input;
	const note = log ?? (() => {});
	const failures: string[] = [];
	const unionInput = { providerId, decl, baked, stored, generatedAt, cache };

	/** The catalog the extension serves with no live source: the baseline for a first refresh. */
	const offlineUnion = (): ModelDefinition[] => buildUnion({ ...unionInput, endpointIds: undefined, modelsDev: undefined });
	const before = previous ?? offlineUnion();

	/** The catalog transition this refresh produced, as a report. */
	const reportFor = (models: readonly ModelDefinition[]): CatalogReport => {
		const delta = diffCatalogs(before, models);
		return { providerId, changed: delta.added + delta.removed + delta.revised > 0, ...delta, failures: [...failures] };
	};

	if (!allowNetwork) {
		const models = offlineUnion();
		onReport?.(reportFor(models));
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
	if (endpointIds && writeCache) {
		// The write-back mirrors the endpoint's own answer: the entries the served
		// catalog holds for the ids that answer carried, and no other id, so the
		// file never claims provenance the endpoint did not supply.
		const returned = new Set(endpointIds);
		const written = writeCache(models.filter((model) => returned.has(model.id) && (model.type ?? "chat") === "chat"));
		if (!written.ok) {
			const reason = `cache write failed (${written.reason})`;
			failures.push(reason);
			note(reason);
		}
	}
	if (onReport) {
		onReport(reportFor(models));
	}
	return models;
}
