/**
 * The invariant report's catalog and renderer: a naming layer over the
 * conformance suite, with no test logic of its own.
 *
 * The suite proves the invariants one deep case at a time. That is the right
 * depth, and it leaves one gap: a failure names a test, not an invariant, so
 * the operator reads a red line and has to remember which invariant that test
 * was written for. This module is the index. Every invariant the extension
 * claims has one named case here, each case names the record that states it,
 * and the renderer prints the index with a verdict per invariant, so a red
 * line reads `M2` and the operator knows which review-finding class to look
 * at.
 *
 * Two things here are derived, never listed, and the reason is the same one
 * the task-queue report gives: a list written here is a second list to drift.
 *
 * The per-source cases are derived from `UNION_SOURCES`. A fourth source added
 * to the union adds a case here, and the M5 provenance case then fails on any
 * entry the new source contributed but the catalog does not name. Provenance
 * is what keeps this list honest: a source that appears in `buildUnion`
 * without appearing here puts entries in the output that no declared source
 * can account for.
 *
 * The thinking cases are derived from `THINKING_LEVELS`, the extension's own
 * vocabulary. A level the extension adds is a level this report asserts.
 *
 * The two mutations that survived a green suite during the investigation are
 * the reason this file exists. Both were unpinned because nobody had written
 * the invariant down: a catalog with a zero context window passed every case,
 * and an empty baked catalog dropped the store's models without a red line.
 * Each is a case below, and each has a row in the mutation catalog.
 *
 * The record that states these invariants is the extension README, which holds
 * the dated finding and assumption table.
 */

import { THINKING_LEVELS } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";

/** One named case of one invariant. */
export interface InvariantCase {
	/** The invariant label a review finding is filed under. */
	id: string;
	/** The case name inside the invariant; a derived case names its own subject. */
	name: string;
	/** One sentence: what holds. The report prints this verbatim. */
	statement: string;
	/** Where the case reads its expectation from. */
	source: string;
}

/**
 * The sources `buildUnion` consults, in application order. The per-source
 * monotonicity cases are derived from this list.
 */
export const UNION_SOURCES = ["baked", "store", "live"] as const;

/** What each source contributes, for a statement that names it. */
const SOURCE_CONTRIBUTION: Record<(typeof UNION_SOURCES)[number], string> = {
	baked: "the baked catalog, with its variable metadata refreshed from models.dev",
	store: "pi's persisted pi.dev catalog, when that catalog is newer than the baked data",
	live: "the ids only the live endpoint advertises, built from models.dev where it has them",
};

/** The record that states the invariants this report indexes. */
const RECORD = "src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md";

/** The catalog: one case per invariant, plus the derived per-source and per-level cases. */
export function buildCatalog(): InvariantCase[] {
	const cases: InvariantCase[] = [
		// --- the union ------------------------------------------------------
		{
			id: "M1",
			name: "non-empty",
			statement: "the union is never empty while the baked catalog has a model, and no optional source can empty a union the baked catalog fills",
			source: `${RECORD} Findings; buildUnion over every source combination`,
		},
		{
			id: "M3",
			name: "provenance",
			statement: "every entry in the union is an entry a declared source supplied, whole or under the documented metadata overlay",
			source: `${RECORD} Findings; the union's three sources`,
		},
		{
			id: "M3",
			name: "overlay silence",
			statement: "the overlay changes only the fields models.dev states, and a field it is silent about keeps the baked value",
			source: `${RECORD} Findings; overlayBakedMetadata, and the mutation row for its silent-field fallback`,
		},
		{
			id: "M4",
			name: "unique ids",
			statement: "the union carries each model id once, whichever sources supplied it",
			source: `${RECORD} Findings; mergeCatalogs`,
		},
		{
			id: "M5",
			name: "a valid model",
			statement: "every entry carries the fields pi's Model type requires, its costs are present and finite, and its limits are present and positive",
			source: "pi-ai dist/models.d.ts; the union's output",
		},
		{
			id: "M7",
			name: "a usable entry",
			statement: "every entry the union serves carries an id pi can key on, and a stored entry that cannot is dropped before it reaches the union",
			source: `${RECORD} Findings; storeEntriesFor, and pi's parseCatalog in dist/core/remote-catalog-provider.js`,
		},
		{
			id: "M8",
			name: "the transport does not contradict pi",
			statement: "an id in a transport table that pi's baked catalog also carries keeps the adapter pi encodes for it, so the table can never override what pi serves",
			source: `${RECORD} Findings; transportFor, and the baked catalog in pi-ai dist/providers/data/opencode-go.json`,
		},
		{
			id: "M6",
			name: "purity",
			statement: "the union returns a fresh list and mutates none of its inputs",
			source: `${RECORD} Findings; the pure-function rule`,
		},
		// --- the store gate -------------------------------------------------
		{
			id: "G1",
			name: "the exact gate",
			statement: "the persisted catalog applies if and only if it is newer than the baked data it would replace",
			source: `${RECORD} Finding 2; pi's gate in dist/core/remote-catalog-provider.js`,
		},
		{
			id: "G2",
			name: "whole replacement",
			statement: "a stored entry replaces the same-id baked entry whole, as pi's own mergeModels does, and the two are not blended field by field",
			source: `${RECORD} Finding 1; pi's mergeModels in dist/core/remote-catalog-provider.js`,
		},
		{
			id: "G2",
			name: "agrees with pi",
			statement: "the extension's merge returns what pi's own merge returns for the same two lists, over replacement, append, cross-provider and stale-gate cases alike",
			source: `${RECORD} Assumption A11; the differential case drives pi's withRemoteCatalog, whose getModels calls pi's mergeModels`,
		},
		{
			id: "G3",
			name: "provider scope",
			statement: "only the extension's own provider's stored entries reach the union",
			source: `${RECORD} Findings; storeEntriesFor`,
		},
		// --- failure narrowing ----------------------------------------------
		{
			id: "L1",
			name: "the baked catalog always survives",
			statement: "no combination of source failures removes a model the baked catalog supplied",
			source: `${RECORD} Finding 2; the union over every subset of the optional sources`,
		},
		{
			id: "L2",
			name: "a malformed source removes nothing",
			statement: "a source that returns the wrong shape contributes nothing and takes nothing away",
			source: `${RECORD} Findings; the failure paths`,
		},
		// --- the composition contract ---------------------------------------
		{
			id: "C1",
			name: "registration never shrinks the catalog",
			statement: "registering the extension never removes a model pi can serve",
			source: `${RECORD} Finding 1; pi's composeModelProvider in dist/core/provider-composer.js, and storeEntriesFor`,
		},
		{
			id: "C2",
			name: "no silent fallback",
			statement: "a model id any source knows resolves to that model's own limits, never to pi's fallback clone of another model",
			source: `${RECORD} Finding 3; pi's buildFallbackModel in dist/core/model-resolver.js`,
		},
		{
			id: "C3",
			name: "user overrides win",
			statement: "a models.json modelOverride still takes precedence over the union",
			source: `${RECORD} Finding 5; pi's applyModelOverride in dist/core/provider-composer.js`,
		},
		// --- thinking levels ------------------------------------------------
		{
			id: "T1",
			name: "derived levels",
			statement: "the advertised thinking levels come from the endpoint's own effort list, never from a list written here",
			source: `${RECORD} Assumption A4; levelMapFor`,
		},
		{
			id: "T2",
			name: "off is the endpoint's disabled state",
			statement: "the off level maps to the endpoint's disabled effort when it names one, and is marked unsupported when it does not",
			source: `${RECORD} Assumption A7; thinkingLevelMapFromEfforts`,
		},
		{
			id: "T3",
			name: "the map follows the endpoint",
			statement: "the level map is derived from the endpoint's effort list, so a model that cannot think carries the map its efforts imply and pi narrows what it advertises to off",
			source: `${RECORD} Assumptions A4 and A9; levelMapFor, and getSupportedThinkingLevels in pi-ai dist/models.js`,
		},
		{
			id: "T3",
			name: "the family keeps its transport",
			statement: "a deepseek-family id keeps the deepseek transport whether or not the endpoint advertises efforts",
			source: `${RECORD} Assumption A8; liveOnlyModelConfig, and pi-ai dist/api/openai-completions.js`,
		},
		// --- the wire, and determinism --------------------------------------
		{
			id: "W1",
			name: "the wire shape follows the map",
			statement: "for every model pi ships and every level the union advertises, the request payload carries the effort the map names, and a level the map does not name is absent or reached through pi's clamp",
			source: `${RECORD} Assumptions A4 to A6; pi-ai dist/api/openai-completions.js, dist/api/anthropic-messages.js, dist/api/openai-responses.js`,
		},
		{
			id: "D1",
			name: "determinism",
			statement: "the same inputs yield the same union, on every call and in any order",
			source: `${RECORD} Findings; the pure-function rule`,
		},
		{
			id: "C1",
			name: "the registration names the provider",
			statement: "the provider id the extension registers is the provider the union is built for",
			source: `${RECORD} Findings; index.ts, and PROVIDER_ID in refresh.ts`,
		},
		// --- the test layer over itself --------------------------------------
		{
			id: "R1",
			name: "one catalog case, one test",
			statement: "every case the catalog names has a test, and every test names a case, so an added case cannot go unrun and a stale case cannot read as covered",
			source: "the check helper's lookup, over buildCatalog()",
		},
	];
	// One monotonicity case per source, derived from the union's own list.
	for (const source of UNION_SOURCES) {
		cases.push({
			id: "M2",
			name: `monotone in ${source}`,
			statement: `adding a model to ${SOURCE_CONTRIBUTION[source]} removes no model from the union`,
			source: `${RECORD} Finding 1; buildUnion with that source grown`,
		});
	}
	// One sendability case per thinking level, derived from the extension's vocabulary.
	for (const level of THINKING_LEVELS) {
		cases.push({
			id: "T4",
			name: `level ${level}`,
			statement: `the union advertises ${level} only when the endpoint's effort list names it, and a request for a level the map does not name is clamped by pi rather than sent as asked`,
			source: `${RECORD} Assumption A4; levelMapFor, and pi-ai dist/api/openai-completions.js`,
		});
	}
	return cases;
}

export type Outcome = "pass" | "fail" | "skip";

export interface CaseResult {
	id: string;
	name: string;
	statement: string;
	source: string;
	outcome: Outcome;
	/** The assertion message of a failed case. */
	detail?: string;
}

/** The index: one line per case, then the failing invariants. */
export function renderReport(results: readonly CaseResult[]): string {
	const width = Math.max(0, ...results.map((r) => r.id.length));
	const lines = results.map((r) => `  ${r.id.padEnd(width)}  ${r.outcome.toUpperCase().padEnd(4)}  ${r.statement}${r.detail ? ` -- ${r.detail}` : ""}`);
	const failed = [...new Set(results.filter((r) => r.outcome === "fail").map((r) => r.id))];
	const skipped = [...new Set(results.filter((r) => r.outcome === "skip").map((r) => r.id))];
	const passed = results.filter((r) => r.outcome === "pass").length;
	const head = `invariant report: ${results.length} cases across ${new Set(results.map((r) => r.id)).size} invariants, ${passed} pass, ${failed.length} fail, ${skipped.length} skip`;
	const tail = [
		failed.length > 0 ? `failing invariants (the review-finding classes to read): ${failed.join(", ")}` : "",
		skipped.length > 0 ? `skipped invariants: ${skipped.join(", ")}` : "",
	].filter((l) => l !== "");
	return [head, ...lines, ...tail].join("\n");
}
