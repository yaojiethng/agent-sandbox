/**
 * The invariant index: the ids and statements the invariant report names its
 * cases after. The ids are the ids of README.md's invariant tables and of the
 * diagram's transitions, so a review finding is filed under the same label
 * everywhere.
 *
 * The statements here are the source the report prints; each case in
 * invariants.test.ts reads its statement from this index rather than
 * restating it, so a statement edited here cannot drift from a case.
 */

import { TRANSITIONS, GUARDS } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/transitions.ts";

/** One invariant family, with the id prefix that names it. */
export interface InvariantFamily {
	readonly prefix: string;
	readonly kind: string;
}

export const FAMILIES: readonly InvariantFamily[] = [
	{ prefix: "S", kind: "state invariant" },
	{ prefix: "TI", kind: "transition invariant" },
	{ prefix: "G", kind: "guard invariant" },
	{ prefix: "C", kind: "classification invariant" },
];

/** One invariant: its id, its statement, and its family. */
export interface Invariant {
	readonly id: string;
	readonly statement: string;
	readonly family: InvariantFamily;
}

const STATE_INVARIANTS: readonly Omit<Invariant, "family">[] = [
	{ id: "S1", statement: "every ledger key is a declared route of a declared chain, and the ledger holds no other key" },
	{ id: "S2", statement: "a cooling entry carries an until and a class; an eligible entry carries a streak" },
	{ id: "S3", statement: "eligibleAt is the only admissibility test a dispatch performs" },
];

const TRANSITION_INVARIANTS: readonly Omit<Invariant, "family">[] = [
	{ id: "TI1", statement: "T3 fires only when the incremented streak reaches N, and T4 fires on the first quota-class failure whatever the streak" },
	{ id: "TI2", statement: "until is written only by T3, T4 and T6, and only as now plus the cooldown of the class that fired" },
	{ id: "TI3", statement: "outcome.received clears until and the class wherever it arrives" },
	{ id: "TI4", statement: "every transition appends exactly one tracking entry" },
];

const GUARD_INVARIANTS: readonly Omit<Invariant, "family">[] = GUARDS.filter((guard) => guard.id.startsWith("G")).map((guard) => ({ id: guard.id, statement: guard.statement }));

const CLASSIFICATION_INVARIANTS: readonly Omit<Invariant, "family">[] = [
	{ id: "C1", statement: "a measured quota text classifies as limited, a measured transient text as transient, and an unmatched text as transient" },
];

function withFamily(rows: readonly Omit<Invariant, "family">[], family: InvariantFamily): readonly Invariant[] {
	return rows.map((row) => ({ ...row, family }));
}

/** The full index, in family order. */
export const INVARIANTS: readonly Invariant[] = [
	...withFamily(STATE_INVARIANTS, FAMILIES[0]),
	...withFamily(TRANSITION_INVARIANTS, FAMILIES[1]),
	...withFamily(GUARD_INVARIANTS, FAMILIES[2]),
	...withFamily(CLASSIFICATION_INVARIANTS, FAMILIES[3]),
];

/** The transition ids the machine declares, for the mapping check. */
export const TRANSITION_IDS: readonly string[] = TRANSITIONS.map((transition) => transition.id);

/** Every id a test name may carry: transitions, invariants, guards, states, tiers. */
export const ALL_IDS: readonly string[] = [
	...TRANSITIONS.map((transition) => transition.id),
	...GUARDS.map((guard) => guard.id),
	...INVARIANTS.map((invariant) => invariant.id),
	"eligible",
	"cooling",
	"sticky",
	"healthy",
	"degraded",
];
