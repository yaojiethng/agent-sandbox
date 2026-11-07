/**
 * The dispatch walk: which route of a chain serves this request.
 *
 * A pure function over the chain, the ledger's eligibility answer and the
 * request's previous provider and model. It holds no state of its own, so every
 * branch is a unit-test case without a pi process.
 *
 * Three tiers, in order (README.md, "The dispatch walk"):
 *
 *   1. sticky   - the last successful route is healthy, so it serves. This
 *                 holds at every request reason, across turns: a turn boundary
 *                 is a non-event and a switchover fires on a health
 *                 transition only.
 *   2. healthy  - the served route is gone (a failure cooled it, or the
 *                 session just started): the first healthy route in declared
 *                 order serves.
 *   3. degraded - every route is cooling: the chain head serves anyway. The
 *                 turn is never refused, and the degraded dispatch is the
 *                 probe that detects the pool's recovery.
 */

import type { Chain, Route } from "./types.ts";
import { routeKey } from "./types.ts";

/** Which tier chose the route, for the caller's report and the tests. */
export type ChoiceTier = "sticky" | "healthy" | "degraded";

export interface RouteChoice {
	readonly route: Route;
	readonly tier: ChoiceTier;
}

/** A previous provider and model, as pi reports them on the route request. */
export interface RouteRef {
	readonly provider: string;
	readonly model: string;
}

export interface WalkInput {
	readonly chain: Chain;
	/** True when the registry resolves the route to a credentialed model. */
	readonly resolvable: (route: Route) => boolean;
	/** The eligibility guard's answer for one route. */
	readonly eligible: (route: Route) => boolean;
	/** The last successful provider and model, when the transcript has one. */
	readonly previous?: RouteRef;
}

export function chooseRoute(input: WalkInput): RouteChoice {
	const { chain, resolvable, eligible } = input;
	const healthy = chain.routes.filter((route) => resolvable(route) && eligible(route));
	const previous =
		input.previous === undefined
			? undefined
			: healthy.find((route) => route.provider === input.previous?.provider && route.model === input.previous?.model);
	if (previous !== undefined) {
		return { route: previous, tier: "sticky" };
	}
	if (healthy.length > 0) {
		return { route: healthy[0], tier: "healthy" };
	}
	// Degrade: dispatch the head even when it is cooling or unresolvable. A
	// broken chain must surface as pi's own loud error, not as a refused turn.
	return { route: chain.routes[0], tier: "degraded" };
}
