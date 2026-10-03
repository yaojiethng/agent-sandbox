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
 * The source kinds the declaration may name, in the order the shipped
 * declaration lists them. The per-source monotonicity cases are derived from
 * this list.
 */
export const UNION_SOURCES = ["baked", "pi-dev", "models-dev", "endpoint"] as const;

/** What each source contributes, for a statement that names it. */
const SOURCE_CONTRIBUTION: Record<(typeof UNION_SOURCES)[number], string> = {
	baked: "pi's baked catalog",
	"pi-dev": "pi's persisted pi.dev catalog, when it is newer than the baked data",
	"models-dev": "the models.dev metadata blob, restricted to the ids another source lists",
	endpoint: "the ids only the provider's own endpoint advertises",
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
			source: `${RECORD} the source model; buildUnion over every source combination`,
		},
		{
			id: "M3",
			name: "provenance",
			statement: "every entry in the union is an entry a declared source supplied, whole or under the documented metadata fill",
			source: `${RECORD} the source model; the union's declared sources`,
		},
		{
			id: "U4",
			name: "metadata silence",
			statement: "a metadata source adds no id and overrides no field: it fills only the fields the served entry leaves undefined, and an id no id source lists is not served",
			source: `${RECORD} the source model; the metadata fill pass in buildUnion, and the mutation row for its restriction`,
		},
		{
			id: "U1",
			name: "first-wins per field",
			statement: "an entry carried by several sources takes each field from the first source in the fold that supplies it, so no later source overwrites a value a source already stated",
			source: `${RECORD} the source model; unionFirstWins and fillMissing`,
		},
		{
			id: "U2",
			name: "the override fold order",
			statement: "the override sources fold in reverse declaration order, so the first-listed override is the strongest and a later-listed one cannot overwrite it",
			source: `${RECORD} the source model; the override pass in buildUnion`,
		},
		{
			id: "U3",
			name: "the served order",
			statement: "the served list keeps the primary catalog's order, an id an override source introduces is appended, and no fold moves an id another source placed",
			source: `${RECORD} the source model; overlayPreservingOrder`,
		},
		{
			id: "M4",
			name: "unique ids",
			statement: "the union carries each model id once, whichever sources supplied it and however often a source repeats it",
			source: `${RECORD} the source model; unionFirstWins`,
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
			source: `${RECORD} storeEntriesFor, and pi's parseCatalog in dist/core/remote-catalog-provider.js`,
		},
		{
			id: "M8",
			name: "the transport follows pi and the metadata",
			statement: "an id pi's baked catalog carries keeps the adapter pi encodes for it, a declared transport entry wins over the metadata, and an id the metadata labels @ai-sdk/openai or @ai-sdk/anthropic gets that adapter",
			source: `${RECORD} the source model; derivedTransport, and pi's baked catalog in pi-ai dist/providers/all.js`,
		},
		{
			id: "M6",
			name: "purity",
			statement: "the union returns a fresh list and mutates none of its inputs",
			source: `${RECORD} the pure-function rule`,
		},
		// --- the store gate -------------------------------------------------
		{
			id: "G1",
			name: "the exact gate",
			statement: "the persisted catalog applies if and only if it is newer than the baked data it would replace",
			source: `${RECORD} the store gate; pi's gate in dist/core/remote-catalog-provider.js`,
		},
		{
			id: "G2",
			name: "the store's fields win",
			statement: "a stored entry supplies the fields it carries, in the baked entry's position, and a field it omits keeps the baked value",
			source: `${RECORD} the store gate; the persisted pi.dev overlay`,
		},
		{
			id: "G2",
			name: "agrees with pi",
			statement: "for the complete entries pi writes, the extension's persisted overlay returns what pi's own merge returns, over replacement, append, cross-provider and stale-gate cases alike",
			source: `${RECORD} Assumption A11; the differential case drives pi's withRemoteCatalog, whose getModels calls pi's mergeModels`,
		},
		{
			id: "G3",
			name: "provider scope",
			statement: "only the extension's own provider's stored entries reach the union",
			source: `${RECORD} storeEntriesFor`,
		},
		// --- failure narrowing ----------------------------------------------
		{
			id: "L1",
			name: "the baked catalog always survives",
			statement: "no combination of source failures removes a model the baked catalog supplied",
			source: `${RECORD} the failure contract; the union over every subset of the optional sources`,
		},
		{
			id: "L2",
			name: "a malformed source removes nothing",
			statement: "a source that returns the wrong shape contributes nothing and takes nothing away",
			source: `${RECORD} the failure contract; the failure paths`,
		},
		// --- the composition contract ---------------------------------------
		{
			id: "C1",
			name: "registration never shrinks the catalog",
			statement: "registering the extension never removes a model pi can serve",
			source: `${RECORD} the registration constraint; pi's composeModelProvider in dist/core/provider-composer.js, and storeEntriesFor`,
		},
		{
			id: "C2",
			name: "no silent fallback",
			statement: "a model id any source knows resolves to that model's own limits, never to pi's fallback clone of another model",
			source: `${RECORD} the registration constraint; pi's buildFallbackModel in dist/core/model-resolver.js`,
		},
		{
			id: "C3",
			name: "user overrides win",
			statement: "a models.json modelOverride still takes precedence over the union",
			source: `${RECORD} the registration constraint; pi's applyModelOverride in dist/core/provider-composer.js`,
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
			statement: "the off level maps to the declared disabled-effort name when the endpoint advertises one, and is marked unsupported when it does not",
			source: `${RECORD} Assumption A7; thinkingLevelMapFromEfforts and the declaration's offEffort`,
		},
		{
			id: "T3",
			name: "the map follows the endpoint",
			statement: "the level map is derived from the endpoint's effort list, so a model that cannot think carries the map its efforts imply and pi narrows what it advertises to off",
			source: `${RECORD} Assumptions A4 and A9; levelMapFor, and getSupportedThinkingLevels in pi-ai dist/models.js`,
		},
		{
			id: "T3",
			name: "the family keeps its compat",
			statement: "an id the declaration's prefix rule names keeps the compat block that rule states, over the declaration's default block",
			source: `${RECORD} the thinking-level defect; compatFor`,
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
			source: `${RECORD} the pure-function rule`,
		},
		{
			id: "C4",
			name: "the registration names the provider",
			statement: "the extension registers one provider per declaration key, and each union is built for the provider whose declaration it reads",
			source: `${RECORD} index.ts; loadDeclarations and the declaration key`,
		},
		// --- the declaration itself -----------------------------------------
		{
			id: "N1",
			name: "the declaration validates",
			statement: "a declaration is read through a validator that drops an unknown provider, an unknown source kind and a malformed field rather than throwing at startup",
			source: `${RECORD} the source model; parseDeclarations`,
		},
		{
			id: "N2",
			name: "the folder owns every input",
			statement: "the declaration sits beside the extension, so no host file has to carry an extension-specific key",
			source: `${RECORD} the source model; DECLARATIONS_PATH`,
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
			source: `${RECORD} the source model; buildUnion with that source grown`,
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
