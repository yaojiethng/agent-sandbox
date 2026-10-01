/**
 * Shared types for the model-refresh extension.
 *
 * The extension is registered through pi's legacy `ProviderConfig` form, whose
 * `refreshModels` returns a list of model definitions. That return value
 * replaces the provider's whole model list, which is the constraint every
 * other module here is shaped around. See README.md, "Why the union exists".
 */

import type { Api } from "@earendil-works/pi-ai";

/** One model definition, as pi's legacy registration form accepts it. */
export interface ModelDefinition {
	id: string;
	name?: string;
	api: Api;
	baseUrl: string;
	reasoning?: boolean;
	thinkingLevelMap?: Record<string, string | null>;
	input?: ("text" | "image")[];
	cost?: {
		input: number;
		output: number;
		cacheRead: number;
		cacheWrite: number;
	};
	contextWindow?: number;
	maxTokens?: number;
	compat?: Record<string, unknown>;
}

/**
 * The persisted catalog entry pi hands to a provider's `refreshModels` as
 * `context.stored`. Pi's own remote-catalog provider writes it from the pi.dev
 * catalog and reads it back on the next start, offline.
 */
export interface StoredCatalog {
	models?: readonly ModelDefinition[];
	lastModified?: number;
	checkedAt?: number;
	etag?: string;
}

/** The models.dev per-provider blob fields this extension consumes. */
export interface ModelsDevModel {
	name?: string;
	reasoning?: boolean;
	reasoning_options?: { type: string; values?: string[] }[];
	modalities?: { input?: string[] };
	limit?: { context?: number; output?: number };
	cost?: {
		input?: number;
		output?: number;
		cache_read?: number;
		cache_write?: number;
	};
}

/** A fetcher injected into the union so the tests never touch the network. */
export type FetchJson = <T>(url: string, signal: AbortSignal) => Promise<T>;

/**
 * What each source contributed to the served catalog, and what failed.
 *
 * The extension used to log this as prose on the console. Prose is unreadable
 * without a parse, so the counts travel as data and `report.ts` renders them.
 */
export interface CatalogReport {
	/** Ids the live endpoint advertised, or undefined when it was not reached. */
	liveIds: number | undefined;
	/** Entries models.dev held for the provider, or undefined when unreachable. */
	modelsDev: number | undefined;
	/** Ids in pi's baked catalog. */
	baked: number;
	/** Ids in pi's persisted pi.dev catalog, or 0 when there was none. */
	stored: number;
	/** Ids in the catalog the extension actually served. */
	served: number;
	/** One line per live source that failed, with the reason. */
	failures: string[];
}
