/**
 * Shared types for the model-refresh extension.
 *
 * The extension is registered through pi's legacy `ProviderConfig` form, whose
 * `refreshModels` returns a list of model definitions. That return value
 * replaces the provider's whole model list, which is the constraint every
 * other module here is shaped around. See README.md, "Why the union exists".
 */

import type { Api } from "@earendil-works/pi-ai";

/** The sources a provider's model catalog may draw on. */
export type SourceKind = "baked" | "pi-dev" | "models-dev" | "endpoint" | "cache";

/**
 * One declared source. A source without `override` is applied in list order,
 * earlier winning; a source with it is applied after the others in reverse
 * list order, so the first-listed override is the strongest.
 */
export interface SourceDecl {
	kind: SourceKind;
	override?: boolean;
	/**
	 * A metadata source supplies fields for ids another source lists and adds
	 * none of its own, so a catalog entry the provider does not serve cannot
	 * enter through it.
	 */
	metadata?: boolean;
}

/** The effort names a provider uses for its disabled state, and the ladder to offer when it names none. */
export interface ThinkingNames {
	/** The effort string that means "off"; the provider here names it `none`. */
	offEffort?: string;
	/** The levels to advertise, and the effort each maps to, when the endpoint names no effort. */
	fallbackEfforts?: Record<string, string>;
}

/** How a provider's compat block is chosen: a default, plus per id-prefix overrides. */
export interface CompatDecl {
	default?: Record<string, unknown>;
	byPrefix?: Record<string, Record<string, unknown>>;
}

/** One provider's declaration: where its secondary catalog lives, and how its sources rank. */
export interface ProviderDecl {
	endpoint?: string;
	baseUrls: Record<string, string>;
	/**
	 * Ids served over a transport the metadata cannot classify. The metadata's
	 * `provider.npm` decides the rest: `@ai-sdk/openai` over the responses
	 * adapter, `@ai-sdk/anthropic` over the messages adapter, and everything
	 * else over completions.
	 */
	transports?: Record<string, readonly string[]>;
	thinking?: ThinkingNames;
	compat?: CompatDecl;
	sources: readonly SourceDecl[];
}

/** The declarations, keyed by provider id. */
export type SourceDeclarations = Record<string, ProviderDecl>;

/** One model definition, as pi's legacy registration form accepts it. */
export interface ModelDefinition {
	id: string;
	/**
	 * The model's kind. Pi reads it through `getModelType`, where an absent type
	 * is `chat`, and keys model identity on `type + id`. A stored entry may carry
	 * an `image` or `classifier` type, so the union keeps the field rather than
	 * dropping it and collapsing a same-id pair pi would keep apart.
	 */
	type?: string;
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
	/** The provider's SDK, which decides the transport for an id the baked catalog lacks. */
	provider?: { npm?: string };
}

/** A fetcher injected into the union so the tests never touch the network. */
export type FetchJson = <T>(url: string, signal: AbortSignal) => Promise<T>;

/**
 * What one refresh changed in the served catalog, and what failed.
 *
 * The report is the catalog transition's before/after state as counts. The
 * message is a function of what the served catalog was before the refresh and
 * what it is after, never of how many entries a source held, so a run that
 * changed nothing carries a zero delta and the emitter stays silent rather than
 * reporting a source count the gate may not have admitted.
 */
export interface CatalogReport {
	/** The provider whose catalog this report describes. */
	providerId: string;
	/** True when the served catalog differs from the state before this refresh. */
	changed: boolean;
	/** Keys the served catalog gained. */
	added: number;
	/** Keys the served catalog lost. */
	removed: number;
	/** Keys on both sides whose fields changed. */
	revised: number;
	/** One line per live source that failed, with the reason. */
	failures: string[];
}
