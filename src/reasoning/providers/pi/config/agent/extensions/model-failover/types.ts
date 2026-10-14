/**
 * The shared shapes of the model-failover extension.
 *
 * The design record is README.md beside this module: the measured behaviour the
 * design rests on, the configuration surface, the state machine (states
 * `eligible` and `cooling`, transitions T1-T6), the dispatch walk, and the
 * invariants. This module is the type half of that record in code form.
 */

/**
 * One failure class. The class decides the cooldown lifetime: a transient
 * failure self-heals on a minutes timescale, a quota-class failure persists
 * until the account's window resets.
 */
export type FailureClass = "transient" | "limited";

/** The thinking-level names a route may declare; pi clamps them to the physical model. */
export type ThinkingLevelName = "off" | "minimal" | "low" | "medium" | "high" | "max";

/** One route: a physical provider and model the chain can dispatch. */
export interface Route {
	readonly provider: string;
	readonly model: string;
	/** Overrides the selected level for this route; pi clamps it to the model. */
	readonly thinkingLevel?: ThinkingLevelName;
}

/** One chain: the declaration that protects one model. */
export interface Chain {
	readonly id: string;
	readonly routes: readonly Route[];
	/** Consecutive transient failures that demote a route. At least 1. */
	readonly transientFailuresBeforeCooldown: number;
	readonly cooldownMs: Readonly<Record<FailureClass, number>>;
}

/** The parsed declarations file. */
export interface Declarations {
	readonly chains: readonly Chain[];
	readonly selection: SelectionConfig;
}

/**
 * The state one route rests in. Two states, per README.md: `eligible` carries
 * the consecutive-failure streak, `cooling` carries the deadline and the class
 * that set it. Eligibility past the deadline is derived at read time, so a
 * stored cooling state with a past deadline is never wrong, only unreaped.
 */
export type RouteState =
	| { readonly state: "eligible"; readonly streak: number }
	| { readonly state: "cooling"; readonly until: number; readonly class: FailureClass };

/** One classified assistant outcome: the input the machine applies. */
export type Outcome =
	| { readonly ok: true }
	| { readonly ok: false; readonly class: FailureClass };

/** The ledger file's shape on disk. Version 1. */
export interface LedgerFile {
	readonly version: 1;
	readonly routes: Record<string, RouteState>;
}

/** The stable key of a route: provider and model, the pair pi dispatches. */
export function routeKey(provider: string, model: string): string {
	return `${provider}/${model}`;
}

/** One classified outcome in an edge's window record. */
export interface EdgeOutcomeRecord {
	readonly ok: boolean;
	readonly at: number;
}

/**
 * The health of one edge address for one model. `eligible` carries the window
 * record; `cooling` carries the window record and the deadline. The streak and
 * the success rate are derived from the window, so neither is stored.
 */
export type EdgeHealth =
	| { readonly state: "eligible"; readonly window: readonly EdgeOutcomeRecord[] }
	| { readonly state: "cooling"; readonly window: readonly EdgeOutcomeRecord[]; readonly until: number };

/** The address set resolved for one provider host. `resolvedAt` is 0 when unresolved. */
export interface AddressSet {
	readonly addresses: readonly string[];
	readonly resolvedAt: number;
}

/** The edge ledger file's shape on disk. Version 1. */
export interface EdgeLedgerFile {
	readonly version: 1;
	readonly edges: Record<string, EdgeHealth>;
}

/** The selection policy that reselects an edge after a failure. */
export type SelectionPolicy = "rate" | "epsilon";

/** The selection configuration: which policy, and its exploration rate. */
export interface SelectionConfig {
	readonly policy: SelectionPolicy;
	readonly epsilon: number;
}
