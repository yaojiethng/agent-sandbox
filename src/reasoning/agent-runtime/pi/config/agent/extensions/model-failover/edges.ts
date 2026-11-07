/**
 * The edge layer: address resolution, the edge health machine, and the
 * selection guard.
 *
 * The design record is README.md beside this module, under "The edge state
 * model". Two submachines: the address set for one provider host, and the
 * health of one edge for one model. The selection is a pure guard over both,
 * not a state.
 *
 * The edge machine is the route machine's exclusion rule with the recent
 * evidence kept: `eligible` carries the window record, and the streak and the
 * success rate are derived from it. The streak drives the cooling transition;
 * the rate drives the reselection policy. A success never erases the recent
 * failures, so a flapping edge keeps a non-zero chance of being tried.
 */

import { lookup } from "node:dns/promises";
import type { AddressSet, EdgeHealth, EdgeOutcomeRecord, Outcome, SelectionConfig } from "./types.ts";

/** The window, stripped of records older than the window length. */
function prune(window: readonly EdgeOutcomeRecord[], now: number, windowMs: number): readonly EdgeOutcomeRecord[] {
	const cutoff = now - windowMs;
	return window.filter((record) => record.at > cutoff);
}

/** The trailing run of failures in a window record. */
function streakOf(window: readonly EdgeOutcomeRecord[]): number {
	let streak = 0;
	for (let i = window.length - 1; i >= 0; i--) {
		if (window[i].ok) {
			break;
		}
		streak++;
	}
	return streak;
}

/** The initial health of an edge: eligible, no evidence. */
export function initialEdgeHealth(): EdgeHealth {
	return { state: "eligible", window: [] };
}

/** The admissibility guard: eligible, or cooling with a lapsed deadline. */
export function eligibleEdgeAt(health: EdgeHealth, now: number): boolean {
	return health.state === "eligible" || health.until <= now;
}

/** The trailing run of failures, derived from the window. */
export function edgeStreak(health: EdgeHealth): number {
	return streakOf(health.window);
}

/** The Laplace-smoothed success rate over the window. Empty is 0.5. */
export function edgeRate(health: EdgeHealth): number {
	let successes = 0;
	for (const record of health.window) {
		if (record.ok) {
			successes++;
		}
	}
	return (successes + 1) / (health.window.length + 2);
}

/** The most recent success time, or undefined. */
export function lastOkAt(health: EdgeHealth): number | undefined {
	return lastMatchingAt(health.window, true);
}

/** The most recent failure time, or undefined. */
export function lastFailAt(health: EdgeHealth): number | undefined {
	return lastMatchingAt(health.window, false);
}

function lastMatchingAt(window: readonly EdgeOutcomeRecord[], ok: boolean): number | undefined {
	let at: number | undefined;
	for (const record of window) {
		if (record.ok === ok && (at === undefined || record.at > at)) {
			at = record.at;
		}
	}
	return at;
}

/**
 * The edge machine, transitions B1 to B5 of the README.
 *
 * A success records the success and clears any cooldown. A transient failure
 * records the failure; while cooling it refreshes the deadline, and while
 * eligible it cools once the trailing run reaches the threshold. A limited
 * outcome is an ignored event: it is an account fact, not an edge fact.
 */
export function applyEdgeOutcome(health: EdgeHealth, outcome: Outcome, now: number, threshold: number, windowMs: number): EdgeHealth {
	if (!outcome.ok && outcome.class === "limited") {
		return health;
	}
	const window = [...prune(health.window, now, windowMs), { ok: outcome.ok, at: now }];
	if (outcome.ok) {
		return { state: "eligible", window };
	}
	if (health.state === "cooling") {
		return { state: "cooling", window, until: now + windowMs };
	}
	if (streakOf(window) >= threshold) {
		return { state: "cooling", window, until: now + windowMs };
	}
	return { state: "eligible", window };
}

/** The edge used most recently, computed from the evidence rather than tracked. */
function lastUsed(edges: readonly string[], healthOf: (address: string) => EdgeHealth): string | undefined {
	let chosen: string | undefined;
	let newest = -Infinity;
	for (const edge of edges) {
		const health = healthOf(edge);
		const at = Math.max(lastOkAt(health) ?? -Infinity, lastFailAt(health) ?? -Infinity);
		if (at > newest) {
			newest = at;
			chosen = edge;
		}
	}
	return newest === -Infinity ? undefined : chosen;
}

/** The cooling deadline, or 0 for an eligible edge. */
function untilOf(health: EdgeHealth): number {
	return health.state === "cooling" ? health.until : 0;
}

/** The clean edge with the highest rate; ties keep the declared order. */
function bestRate(clean: readonly string[], healthOf: (address: string) => EdgeHealth): string {
	let chosen = clean[0];
	let best = edgeRate(healthOf(chosen));
	for (const edge of clean.slice(1)) {
		const rate = edgeRate(healthOf(edge));
		if (rate > best) {
			best = rate;
			chosen = edge;
		}
	}
	return chosen;
}

/** A weighted pick over the clean edges, consuming one sample in [0, 1). */
function weightedPick(clean: readonly string[], healthOf: (address: string) => EdgeHealth, rand: number): string {
	const weights = clean.map((edge) => edgeRate(healthOf(edge)));
	const total = weights.reduce((sum, weight) => sum + weight, 0);
	let target = rand * total;
	for (let i = 0; i < clean.length; i++) {
		target -= weights[i];
		if (target < 0) {
			return clean[i];
		}
	}
	return clean[clean.length - 1];
}

/** The reselection policy over the clean edges: the one place the two shapes differ. */
function pick(clean: readonly string[], healthOf: (address: string) => EdgeHealth, rand: number, config: SelectionConfig): string {
	if (config.policy === "epsilon" && config.epsilon > 0 && rand < config.epsilon) {
		const index = Math.min(clean.length - 1, Math.floor((rand / config.epsilon) * clean.length));
		return clean[index];
	}
	if (config.policy === "epsilon") {
		return bestRate(clean, healthOf);
	}
	return weightedPick(clean, healthOf, rand);
}

/**
 * The selection guard. Sticky on success, reselect through the policy after a
 * failure, and the soonest-to-recover edge when every edge is cooling.
 *
 * Pure in `(edges, healthOf, now, rand)`: a fixed `rand` gives a fixed answer.
 */
export function nextEdge(
	edges: readonly string[],
	healthOf: (address: string) => EdgeHealth,
	now: number,
	rand: number,
	config: SelectionConfig,
): string | undefined {
	if (edges.length === 0) {
		return undefined;
	}
	const last = lastUsed(edges, healthOf);
	if (last !== undefined) {
		const health = healthOf(last);
		if ((lastOkAt(health) ?? -Infinity) > (lastFailAt(health) ?? -Infinity) && eligibleEdgeAt(health, now)) {
			return last;
		}
	}
	const clean = edges.filter((edge) => eligibleEdgeAt(healthOf(edge), now));
	if (clean.length === 0) {
		let chosen = edges[0];
		let until = untilOf(healthOf(chosen));
		for (const edge of edges.slice(1)) {
			const candidate = untilOf(healthOf(edge));
			if (candidate < until) {
				chosen = edge;
				until = candidate;
			}
		}
		return chosen;
	}
	return pick(clean, healthOf, rand, config);
}

/** The resolver a host is looked up with. Injected so tests never touch DNS. */
export type ResolveFn = (hostname: string) => Promise<readonly string[]>;

/** The default resolver: IPv4 addresses for the host, in the resolver's order. */
async function defaultResolve(hostname: string): Promise<readonly string[]> {
	const results = await lookup(hostname, { all: true, family: 4 });
	return results.map((entry) => entry.address);
}

/** Resolve a host to its deduplicated addresses; a resolver failure propagates. */
export async function resolveAddresses(hostname: string, resolve: ResolveFn = defaultResolve): Promise<readonly string[]> {
	return [...new Set(await resolve(hostname))];
}

/** The address set before any resolution. */
export function unresolvedAddressSet(): AddressSet {
	return { addresses: [], resolvedAt: 0 };
}

/** Apply a resolution event: a non-empty answer resolves the set, anything else is ignored. */
export function applyResolution(set: AddressSet, addresses: readonly string[], now: number): AddressSet {
	if (addresses.length === 0) {
		return set;
	}
	return { addresses: [...addresses], resolvedAt: now };
}

/** Whether the set is past its refresh deadline, or never resolved. */
export function needsRefresh(set: AddressSet, now: number, ttl: number): boolean {
	return set.resolvedAt === 0 || now > set.resolvedAt + ttl;
}

/** Whether the set holds any address. */
export function usable(set: AddressSet): boolean {
	return set.addresses.length > 0;
}
