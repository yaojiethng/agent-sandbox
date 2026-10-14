/**
 * The declarations loader: `routes.json` beside this module becomes the chains
 * the router walks.
 *
 * The loader is strict on shape and silent on extras. A malformed file refuses
 * the whole load with a named error (R8), because a chain that half-parsed
 * would route to nothing and read as healthy. An unknown field is ignored, so
 * a later version of this file can add a key this version does not read.
 *
 * The file is config rather than code, so a second chain is a row, not an edit
 * to the router.
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { Chain, Declarations, Route, SelectionConfig, ThinkingLevelName } from "./types.ts";
import { routeKey } from "./types.ts";

/** The declarations path, resolved beside this module so it travels with the extension. */
export const DECLARATIONS_PATH = fileURLToPath(new URL("./routes.json", import.meta.url));

/** The thinking-level names a route may declare. */
export const THINKING_LEVEL_NAMES: readonly ThinkingLevelName[] = ["off", "minimal", "low", "medium", "high", "max"];

/** The default consecutive transient failures that demote a route. */
export const DEFAULT_THRESHOLD = 3;

/** The edge threshold: consecutive transient failures that cool one edge. */
export const EDGE_THRESHOLD = 3;

/** The edge window: the cooling duration and the age-out of an edge's window record. */
export const EDGE_WINDOW_MS = 180_000;

/** The default selection policy and its exploration rate. */
export const DEFAULT_SELECTION: SelectionConfig = { policy: "epsilon", epsilon: 0.1 };

/** The default cooldown per class, in milliseconds. */
export const DEFAULT_COOLDOWN_MS = { transient: 120000, limited: 3600000 } as const;

/** The named refusal: the load stops and the extension does not register. */
export class DeclarationsError extends Error {
	constructor(message: string) {
		super(message);
		this.name = "DeclarationsError";
	}
}

/** Read and validate the declarations file beside this module. */
export function loadDeclarations(path: string = DECLARATIONS_PATH): Declarations {
	return parseDeclarations(readFileSync(path, "utf8"));
}

/** Parse and validate the declarations text. Throws DeclarationsError on any defect. */
export function parseDeclarations(text: string): Declarations {
	let raw: unknown;
	try {
		raw = JSON.parse(text);
	} catch (error) {
		throw new DeclarationsError(`the declarations file is not JSON: ${(error as Error).message}`);
	}
	const chains = parseChains(raw);
	const ids = new Set<string>();
	// One physical route belongs to exactly one chain across the whole file: the
	// ledger holds one entry per route key, so two declarations of one route
	// would contend over one key and make the threshold and the cooldowns
	// order-dependent. The ambiguity is refused, not resolved.
	const owners = new Map<string, string>();
	for (const chain of chains) {
		if (ids.has(chain.id)) {
			throw new DeclarationsError(`two chains share the id '${chain.id}'; a chain id names one protected model`);
		}
		ids.add(chain.id);
		const keys = new Set<string>();
		for (const route of chain.routes) {
			const key = routeKey(route.provider, route.model);
			if (keys.has(key)) {
				throw new DeclarationsError(`chain '${chain.id}' lists the route '${key}' twice; one route entry per provider and model`);
			}
			keys.add(key);
			const owner = owners.get(key);
			if (owner !== undefined) {
				throw new DeclarationsError(`the route '${key}' is declared by two chains, '${owner}' and '${chain.id}'; one physical route belongs to one chain, because the ledger holds one entry per route`);
			}
			owners.set(key, chain.id);
		}
	}
	return { chains, selection: parseSelection(raw) };
}

function parseSelection(raw: unknown): SelectionConfig {
	const declared = (raw as { selection?: unknown }).selection;
	if (declared === undefined) {
		return { ...DEFAULT_SELECTION };
	}
	if (typeof declared !== "object" || declared === null) {
		throw new DeclarationsError("'selection' is not an object");
	}
	const { policy, epsilon } = declared as { policy?: unknown; epsilon?: unknown };
	const resolvedPolicy = policy ?? DEFAULT_SELECTION.policy;
	if (resolvedPolicy !== "rate" && resolvedPolicy !== "epsilon") {
		throw new DeclarationsError(`'selection.policy' is '${String(policy)}', not 'rate' or 'epsilon'`);
	}
	const resolvedEpsilon = epsilon ?? DEFAULT_SELECTION.epsilon;
	if (typeof resolvedEpsilon !== "number" || !Number.isFinite(resolvedEpsilon) || resolvedEpsilon < 0 || resolvedEpsilon >= 1) {
		throw new DeclarationsError("'selection.epsilon' is not a number at least 0 and below 1");
	}
	return { policy: resolvedPolicy, epsilon: resolvedEpsilon };
}

function parseChains(raw: unknown): readonly Chain[] {
	if (typeof raw !== "object" || raw === null || !("chains" in raw)) {
		throw new DeclarationsError("the declarations file has no 'chains' object member");
	}
	const chains = (raw as { chains?: unknown }).chains;
	if (!Array.isArray(chains) || chains.length === 0) {
		throw new DeclarationsError("'chains' is not a non-empty array");
	}
	return chains.map(parseChain);
}

function parseChain(value: unknown): Chain {
	if (typeof value !== "object" || value === null) {
		throw new DeclarationsError("a chain is not an object");
	}
	const raw = value as { id?: unknown; routes?: unknown; transientFailuresBeforeCooldown?: unknown; cooldownMs?: unknown };
	if (typeof raw.id !== "string" || raw.id === "") {
		throw new DeclarationsError("a chain has no non-empty 'id'");
	}
	const routes = parseRoutes(raw.routes);
	if (raw.transientFailuresBeforeCooldown !== undefined && (!Number.isInteger(raw.transientFailuresBeforeCooldown) || (raw.transientFailuresBeforeCooldown as number) < 1)) {
		throw new DeclarationsError(`chain '${raw.id}' has a 'transientFailuresBeforeCooldown' that is not an integer of at least 1`);
	}
	return {
		id: raw.id,
		routes,
		transientFailuresBeforeCooldown: (raw.transientFailuresBeforeCooldown as number | undefined) ?? DEFAULT_THRESHOLD,
		cooldownMs: parseCooldowns(raw.id, raw.cooldownMs),
	};
}

function parseRoutes(value: unknown): readonly Route[] {
	if (!Array.isArray(value) || value.length === 0) {
		throw new DeclarationsError("a chain has no non-empty 'routes' array");
	}
	return value.map(parseRoute);
}

function parseRoute(value: unknown): Route {
	if (typeof value !== "object" || value === null) {
		throw new DeclarationsError("a route is not an object");
	}
	const raw = value as { provider?: unknown; model?: unknown; thinkingLevel?: unknown };
	if (typeof raw.provider !== "string" || raw.provider === "") {
		throw new DeclarationsError("a route has no non-empty 'provider'");
	}
	if (typeof raw.model !== "string" || raw.model === "") {
		throw new DeclarationsError(`the route '${raw.provider}' has no non-empty 'model'`);
	}
	if (raw.thinkingLevel !== undefined && (typeof raw.thinkingLevel !== "string" || !THINKING_LEVEL_NAMES.includes(raw.thinkingLevel as ThinkingLevelName))) {
		throw new DeclarationsError(`the route '${raw.provider}/${raw.model}' has a 'thinkingLevel' that is not one of ${THINKING_LEVEL_NAMES.join(", ")}`);
	}
	return {
		provider: raw.provider,
		model: raw.model,
		...(raw.thinkingLevel !== undefined ? { thinkingLevel: raw.thinkingLevel as ThinkingLevelName } : {}),
	};
}

function parseCooldowns(chainId: string, value: unknown): Readonly<Record<"transient" | "limited", number>> {
	if (value === undefined) {
		// A fresh copy per chain: the default is a shared constant, and returning
		// it directly would alias one object into every chain that omits the
		// block, so one accidental write would touch all of them.
		return { ...DEFAULT_COOLDOWN_MS };
	}
	if (typeof value !== "object" || value === null) {
		throw new DeclarationsError(`chain '${chainId}' has a 'cooldownMs' that is not an object`);
	}
	const raw = value as { transient?: unknown; limited?: unknown };
	const cooldownMs = { ...DEFAULT_COOLDOWN_MS };
	for (const failureClass of ["transient", "limited"] as const) {
		const declared = raw[failureClass];
		if (declared === undefined) {
			continue;
		}
		if (!Number.isInteger(declared) || (declared as number) <= 0) {
			throw new DeclarationsError(`chain '${chainId}' has a 'cooldownMs.${failureClass}' that is not a positive integer`);
		}
		cooldownMs[failureClass] = declared as number;
	}
	return cooldownMs;
}
