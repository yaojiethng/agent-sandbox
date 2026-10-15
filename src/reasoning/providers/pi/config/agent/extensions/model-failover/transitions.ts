/**
 * The state machine of README.md in data form: the states, the transitions
 * T1-T6 with their guards and effects, and the guards that are not
 * transitions.
 *
 * The machine is hand-written in ledger.ts and router.ts, and this table is
 * its record: the invariant report names its cases after these ids, and the
 * mapping check in the suite asserts that every id here has a case there and
 * that the invariant cases carry their ids. A transition added to the code
 * without a row here is a row the mapping check fails on.
 */

/** The two states a route rests in. */
export const ROUTE_STATES = ["eligible", "cooling"] as const;
export type RouteStateId = (typeof ROUTE_STATES)[number];

/** One transition of the machine. */
export interface Transition {
	/** The id the invariant report and the mapping check name. */
	readonly id: string;
	readonly from: RouteStateId;
	readonly event: "outcome.received" | "outcome.failed";
	/** The condition that decides whether the transition fires. */
	readonly guard: string;
	/** What the transition does besides change the state. */
	readonly effect: string;
	readonly to: RouteStateId;
}

export const TRANSITIONS: readonly Transition[] = [
	{
		id: "T1",
		from: "eligible",
		event: "outcome.received",
		guard: "always",
		effect: "success count; streak := 0; append entry; persist",
		to: "eligible",
	},
	{
		id: "T2",
		from: "eligible",
		event: "outcome.failed",
		guard: "class = transient AND streak + 1 < N",
		effect: "streak++; failure count; append entry; persist",
		to: "eligible",
	},
	{
		id: "T3",
		from: "eligible",
		event: "outcome.failed",
		guard: "class = transient AND streak + 1 >= N",
		effect: "until := now + cooldown(transient); append entry; persist",
		to: "cooling",
	},
	{
		id: "T4",
		from: "eligible",
		event: "outcome.failed",
		guard: "class = limited",
		effect: "until := now + cooldown(limited); append entry; persist",
		to: "cooling",
	},
	{
		id: "T5",
		from: "cooling",
		event: "outcome.received",
		guard: "always",
		effect: "success count; clear until and class; streak := 0; append entry; persist",
		to: "eligible",
	},
	{
		id: "T6",
		from: "cooling",
		event: "outcome.failed",
		guard: "always",
		effect: "until := now + cooldown(class of the current failure); append entry; persist",
		to: "cooling",
	},
];

/** The guards that read state without changing it. */
export const GUARDS: readonly { readonly id: string; readonly statement: string }[] = [
	{ id: "eligibleAt", statement: "a route is dispatchable when it is eligible, or cooling with until <= now" },
	{ id: "G1", statement: "the sticky guard chooses the previous route only when that route is healthy" },
	{ id: "G2", statement: "the streak resets only on outcome.received, never on a cooldown lapse" },
];

/** The dispatch tiers, in the order the walk consults them. */
export const DISPATCH_TIERS = ["sticky", "healthy", "degraded"] as const;

/** The invariant families the suite holds, by id prefix. */
export const INVARIANT_FAMILIES: readonly { readonly prefix: string; readonly kind: string }[] = [
	{ prefix: "S", kind: "state invariant" },
	{ prefix: "TI", kind: "transition invariant" },
	{ prefix: "G", kind: "guard invariant" },
];
