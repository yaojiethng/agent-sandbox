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
export const UNION_SOURCES = ["baked", "pi-dev", "models-dev", "endpoint", "cache"] as const;

/** What each source contributes, for a statement that names it. */
const SOURCE_CONTRIBUTION: Record<(typeof UNION_SOURCES)[number], string> = {
	baked: "pi's baked catalog",
	"pi-dev": "pi's persisted pi.dev catalog, when it is newer than the baked data",
	"models-dev": "the models.dev metadata blob, restricted to the ids another source lists",
	endpoint: "the ids only the provider's own endpoint advertises",
	cache: "the extension's own cache file, read in the offline phase",
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
			id: "G2",
			name: "keeps a same-id pair of different types apart",
			statement: "a chat entry and an image entry that share an id stay two entries, as pi's own merge keeps them",
			source: `${RECORD} the source model; pi's mergeModels in dist/core/remote-catalog-provider.js`,
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
		{
			id: "L3",
			name: "the refresh precedes the session",
			statement: "the provider refresh runs and returns the catalog before any UI exists, so nothing it does can render yet",
			source: `${RECORD} the output sink and Assumption A14; the registration's refreshModels and session_start handlers`,
		},
		{
			id: "L4",
			name: "the report holds until a UI exists",
			statement: "a report recorded before a UI is attached is held and rendered on attach, and nothing renders while no UI exists",
			source: `${RECORD} the output sink and Assumption A13; report.ts`,
		},
		{
			id: "L5",
			name: "a failed live source narrows rather than empties",
			statement: "a live source that fails contributes nothing and takes nothing away, so the served catalog stays the offline union rather than an empty list",
			source: `${RECORD} the failure contract; gatherAndBuild with a failing fetcher`,
		},
		// --- the output -----------------------------------------------------
		{
			id: "O1",
			name: "silence on no change",
			statement: "a refresh that changed no entry and failed no source announces nothing",
			source: `${RECORD} the output sink; report.ts`,
		},
		{
			id: "O2",
			name: "the delta on change",
			statement: "a refresh whose served catalog changed renders one line naming the ids added, the ids removed and the field revisions",
			source: `${RECORD} the output sink; report.ts`,
		},
		{
			id: "O3",
			name: "the failure line",
			statement: "a source that failed renders one warning naming the source and the reason, whether or not the catalog changed",
			source: `${RECORD} the output sink; report.ts`,
		},
		{
			id: "O4",
			name: "the discarded default is announced",
			statement: "a saved default the scope discarded is announced once at session_start, and nothing is announced when the default is selected, the scope is empty, or the default is absent or unauthenticated",
			source: `${RECORD} the default-model rule in ## The default model and the scope order; default-model.ts`,
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
		// --- the cache device ------------------------------------------------
		{
			id: "E1",
			name: "empty predicts absent",
			statement: "in K0 the device holds no content, and the next seedRead emits absent",
			source: `${RECORD} the cache device; cache.ts readCache`,
		},
		{
			id: "E2",
			name: "loaded predicts content",
			statement: "in K1 the device holds servable entries, and the next seedRead emits received(cache payload)",
			source: `${RECORD} the cache device; cache.ts readCache`,
		},
		{
			id: "E3",
			name: "invalid predicts absent",
			statement: "in K2 the file is unusable, and the next seedRead emits absent without throwing",
			source: `${RECORD} the cache device; cache.ts parseCache`,
		},
		{
			id: "E4",
			name: "nothing usable reads absent",
			statement: "a read that finds nothing usable emits absent and never throws",
			source: `${RECORD} the cache device; cache.ts readCache`,
		},
		{
			id: "E5",
			name: "content reads the stored entries",
			statement: "a read that finds content emits received(cache payload) carrying exactly the stored entries",
			source: `${RECORD} the cache device; cache.ts parseCache`,
		},
		{
			id: "E6",
			name: "a write round-trips",
			statement: "a successful write lands in K1, so the next read returns exactly what was written",
			source: `${RECORD} the cache device; cache.ts writeCache and readCache`,
		},
		{
			id: "E7",
			name: "a failed write leaves the file",
			statement: "a failed write emits write-failed(reason) and leaves the file and the state unchanged",
			source: `${RECORD} the cache device; cache.ts writeCache`,
		},
		{
			id: "E8",
			name: "the write mirrors the endpoint",
			statement: "the write stores the entries for the endpoint's returned ids, and nothing else",
			source: `${RECORD} the cache device; the write-back in refresh.ts`,
		},
		{
			id: "E9",
			name: "the write needs the endpoint",
			statement: "the write runs only when the endpoint answered; a failed or absent endpoint writes nothing",
			source: `${RECORD} the cache device; the write-back in refresh.ts`,
		},
		{
			id: "E10",
			name: "the cache is additive",
			statement: "a served key keeps its fields, and a cached id adds only a key no earlier source supplied",
			source: `${RECORD} the source model; buildUnion's cache case`,
		},
		{
			id: "E11",
			name: "the read precedes the endpoint",
			statement: "the seed read runs before the endpoint is consulted, so an offline start serves the cache",
			source: `${RECORD} the cache device; the offline path in refresh.ts`,
		},
		{
			id: "E12",
			name: "the file decides",
			statement: "the read's outcome is decided by the file's content, version and endpoint map, not by the source state",
			source: `${RECORD} the cache device; cache.ts parseCache`,
		},
		{
			id: "E13",
			name: "an unusable file is K2",
			statement: "a file that does not parse, carries an unknown version, or lacks the declared endpoint key is K2, never content",
			source: `${RECORD} the cache device; cache.ts parseCache`,
		},
		{
			id: "E14",
			name: "age does not matter",
			statement: "the read never gates on writtenAt or retrievedAt",
			source: `${RECORD} the cache device; cache.ts parseCache`,
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

/** What an invariant constrains, per the statechart classification. */
export type InvariantKind = "state" | "transition" | "guard";

/** The states of the catalog component, from the enumeration in the record. */
export const STATES = ["S0", "S1"] as const;

/** The states of the cache device: a separate machine, nested below the catalog machine. */
export const CACHE_STATES = ["K0", "K1", "K2"] as const;

/** Edges outside the catalog machine, named so a case can point at them. */
export const EXTERNAL_EDGES = ["WIRE", "DECL", "HARNESS"] as const;

/**
 * One transition of the machine, as the record draws it.
 *
 * `event` and `from` are what the skill's rule 6 needs: no state has two
 * transitions on one event whose guards both hold. `guard` is the guard that
 * admits this firing, and it is required exactly when another transition shares
 * this one's event and source state, because then the guards must be distinct.
 *
 * `noCaseReason` is the required note for a transition no invariant case names;
 * the skill's rule 1 allows a transition with no invariant only when the record
 * says why.
 */
export interface Transition {
	id: string;
	label: string;
	event: string;
	from: readonly string[];
	guard?: string;
	ignored?: true;
	noCaseReason?: string;
}

export const TRANSITIONS: readonly Transition[] = [
	{ id: "X1", label: "received(store payload), guard closed / none (internal)", event: "received(store)", from: ["S0", "S1"], guard: "the store is not newer than the baked data" },
	{ id: "X2", label: "received(store payload), guard open / union", event: "received(store)", from: ["S0"], guard: "the store is newer than the baked data" },
	{ id: "X3", label: "received(endpoint or pi.dev payload) / union", event: "received(id-source)", from: ["S0", "S1"] },
	{ id: "X4", label: "received(models.dev payload) / fill missing (internal)", event: "received(metadata)", from: ["S1"] },
	{ id: "X5", label: "received(override payload) / fold reverse (internal)", event: "received(override)", from: ["S1"] },
	{ id: "X6", label: "failed(reason) / none (internal)", event: "failed", from: ["S0", "S1"] },
	{ id: "X7", label: "absent", event: "absent", from: ["S0", "S1"], ignored: true, noCaseReason: "an ignored event: no transition accepts it, so no case holds it" },
	{ id: "X8", label: "unchanged and no failure / nothing", event: "outcome", from: ["S1"], guard: "unchanged and no failure" },
	{ id: "X9", label: "changed / notify the delta", event: "outcome", from: ["S1"], guard: "changed" },
	{ id: "X10", label: "failed / notify the failure", event: "outcome", from: ["S1"], guard: "failed" },
	{ id: "X11", label: "pre-session refresh", event: "session", from: ["S0"], guard: "the session has not started" },
	{ id: "X12", label: "failing-source narrowing", event: "live failure", from: ["S0", "S1"] },
	{ id: "X13", label: "pre-UI report hold", event: "report", from: ["S0"], guard: "no UI exists yet" },
	{ id: "X14", label: "saved default discarded by the scope / notify", event: "session", from: ["S0"], guard: "the scope is non-empty, the default is applicable, and it is not selected" },
	{ id: "X15", label: "endpoint answered / write the cache wholesale", event: "received(endpoint)", from: ["S1"], guard: "the endpoint answered" },
];

/** The cache machine's transitions, nested below the catalog machine. */
export const CACHE_TRANSITIONS: readonly Transition[] = [
	{ id: "Z1", label: "seedRead [absent or empty] / emit absent", event: "seedRead", from: ["K0", "K1", "K2"], guard: "the file is absent or empty" },
	{ id: "Z2", label: "seedRead [content] / emit received(cache)", event: "seedRead", from: ["K0", "K1", "K2"], guard: "the file parses and names the declared endpoint" },
	{ id: "Z3", label: "seedRead [unusable] / emit absent", event: "seedRead", from: ["K0", "K1", "K2"], guard: "the file does not parse, carries another version, or lacks the endpoint key" },
	{ id: "Z4", label: "writeBack [write ok] / emit ok", event: "writeBack", from: ["K0", "K1", "K2"], guard: "the write lands" },
	{ id: "Z5", label: "writeBack [write fails] / emit write-failed", event: "writeBack", from: ["K0", "K1", "K2"], guard: "the write fails" },
];

/** One catalog case's class and the state, transition or external edge it belongs to. */
export interface Classification {
	id: string;
	name: string;
	kind: InvariantKind;
	edges: readonly string[];
}

export const CLASSIFICATION: readonly Classification[] = [
	{ id: "M1", name: "non-empty", kind: "state", edges: ["S0"] },
	{ id: "M3", name: "provenance", kind: "state", edges: ["S1"] },
	{ id: "U4", name: "metadata silence", kind: "transition", edges: ["X4"] },
	{ id: "U1", name: "first-wins per field", kind: "transition", edges: ["X3"] },
	{ id: "U2", name: "the override fold order", kind: "transition", edges: ["X5"] },
	{ id: "U3", name: "the served order", kind: "transition", edges: ["X5"] },
	{ id: "M4", name: "unique ids", kind: "state", edges: ["S1"] },
	{ id: "M5", name: "a valid model", kind: "state", edges: ["S1"] },
	{ id: "M7", name: "a usable entry", kind: "state", edges: ["S1"] },
	{ id: "M8", name: "the transport follows pi and the metadata", kind: "state", edges: ["S1"] },
	{ id: "M6", name: "purity", kind: "transition", edges: ["X3"] },
	{ id: "G1", name: "the exact gate", kind: "guard", edges: ["X1", "X2"] },
	{ id: "G2", name: "the store's fields win", kind: "transition", edges: ["X2"] },
	{ id: "G2", name: "agrees with pi", kind: "transition", edges: ["X2"] },
	{ id: "G2", name: "keeps a same-id pair of different types apart", kind: "transition", edges: ["X3"] },
	{ id: "G3", name: "provider scope", kind: "guard", edges: ["X2"] },
	{ id: "L1", name: "the baked catalog always survives", kind: "state", edges: ["S1"] },
	{ id: "L2", name: "a malformed source removes nothing", kind: "transition", edges: ["X6"] },
	{ id: "L3", name: "the refresh precedes the session", kind: "transition", edges: ["X11"] },
	{ id: "L4", name: "the report holds until a UI exists", kind: "transition", edges: ["X13"] },
	{ id: "L5", name: "a failed live source narrows rather than empties", kind: "transition", edges: ["X12"] },
	{ id: "O1", name: "silence on no change", kind: "transition", edges: ["X8"] },
	{ id: "O2", name: "the delta on change", kind: "transition", edges: ["X9"] },
	{ id: "O3", name: "the failure line", kind: "transition", edges: ["X10"] },
	{ id: "O4", name: "the discarded default is announced", kind: "transition", edges: ["X14"] },
	{ id: "C1", name: "registration never shrinks the catalog", kind: "state", edges: ["S1"] },
	{ id: "C2", name: "no silent fallback", kind: "state", edges: ["S1"] },
	{ id: "C3", name: "user overrides win", kind: "guard", edges: ["X5"] },
	{ id: "T1", name: "derived levels", kind: "state", edges: ["S1"] },
	{ id: "T2", name: "off is the endpoint's disabled state", kind: "state", edges: ["S1"] },
	{ id: "T3", name: "the map follows the endpoint", kind: "state", edges: ["S1"] },
	{ id: "T3", name: "the family keeps its compat", kind: "state", edges: ["S1"] },
	{ id: "W1", name: "the wire shape follows the map", kind: "transition", edges: ["WIRE"] },
	{ id: "D1", name: "determinism", kind: "transition", edges: ["X3"] },
	{ id: "C4", name: "the registration names the provider", kind: "state", edges: ["S0"] },
	{ id: "N1", name: "the declaration validates", kind: "state", edges: ["DECL"] },
	{ id: "N2", name: "the folder owns every input", kind: "state", edges: ["DECL"] },
	{ id: "R1", name: "one catalog case, one test", kind: "state", edges: ["HARNESS"] },
	{ id: "E1", name: "empty predicts absent", kind: "state", edges: ["K0"] },
	{ id: "E2", name: "loaded predicts content", kind: "state", edges: ["K1"] },
	{ id: "E3", name: "invalid predicts absent", kind: "state", edges: ["K2"] },
	{ id: "E4", name: "nothing usable reads absent", kind: "transition", edges: ["Z1", "Z3"] },
	{ id: "E5", name: "content reads the stored entries", kind: "transition", edges: ["Z2"] },
	{ id: "E6", name: "a write round-trips", kind: "transition", edges: ["Z4"] },
	{ id: "E7", name: "a failed write leaves the file", kind: "transition", edges: ["Z5"] },
	{ id: "E8", name: "the write mirrors the endpoint", kind: "transition", edges: ["X15"] },
	{ id: "E9", name: "the write needs the endpoint", kind: "transition", edges: ["X15"] },
	{ id: "E10", name: "the cache is additive", kind: "transition", edges: ["X3"] },
	{ id: "E11", name: "the read precedes the endpoint", kind: "transition", edges: ["X3"] },
	{ id: "E12", name: "the file decides", kind: "guard", edges: ["Z1", "Z2", "Z3"] },
	{ id: "E13", name: "an unusable file is K2", kind: "guard", edges: ["Z3"] },
	{ id: "E14", name: "age does not matter", kind: "transition", edges: ["Z1", "Z2", "Z3"] },
];

/** The derived cases, whose class and edge do not vary with the subject. */
const DERIVED_CLASSIFICATION: readonly Classification[] = [
	{ id: "M2", name: "monotone in ", kind: "transition", edges: ["X2", "X3", "X4", "X5"] },
	{ id: "T4", name: "level ", kind: "transition", edges: ["WIRE"] },
];

const key = (c: { id: string; name: string }): string => `${c.id}\u0000${c.name}`;

/**
 * The machine-run totality check. Returns the findings; an empty list is a pass.
 *
 * It asserts the four things the enumeration's completeness rests on: every
 * catalog case is classified, no classification is stale, every state and
 * transition the record names is held by a case or carries a reason, and every
 * edge a case names exists. It then applies the skill's rule 6: no state has two
 * transitions on one event whose guards both hold, which here means the guards
 * on a shared event are distinct.
 */
export function checkTotality(cases: readonly InvariantCase[]): string[] {
	const findings: string[] = [];
	const declared = CLASSIFICATION;

	const classificationFor = (c: InvariantCase): Classification | undefined =>
		declared.find((entry) => entry.id === c.id && c.name === entry.name) ??
		DERIVED_CLASSIFICATION.find((entry) => entry.id === c.id && c.name.startsWith(entry.name));

	for (const c of cases) {
		if (!classificationFor(c)) findings.push(`no classification for ${c.id} ${c.name}`);
	}
	for (const entry of declared) {
		if (cases.some((c) => c.id === entry.id && c.name === entry.name)) continue;
		findings.push(`classification for a case that does not exist: ${entry.id} ${entry.name}`);
	}

	const allTransitions: readonly Transition[] = [...TRANSITIONS, ...CACHE_TRANSITIONS];
	const validEdges = new Set<string>([...STATES, ...CACHE_STATES, ...allTransitions.map((t) => t.id), ...EXTERNAL_EDGES]);
	for (const c of cases) {
		const entry = classificationFor(c);
		if (!entry) continue;
		if (entry.edges.length === 0) findings.push(`${c.id} ${c.name} names no edge`);
		for (const edge of entry.edges) {
			if (!validEdges.has(edge)) findings.push(`${c.id} ${c.name} names an unknown edge ${edge}`);
		}
	}
	for (const state of [...STATES, ...CACHE_STATES]) {
		if (!cases.some((c) => classificationFor(c)?.edges.includes(state))) findings.push(`no case names state ${state}`);
	}

	const fired = (id: string): boolean => cases.some((c) => classificationFor(c)?.edges.includes(id));
	for (const t of allTransitions) {
		if (!fired(t.id) && !t.noCaseReason) findings.push(`transition ${t.id} has no case and no reason`);
	}

	for (const a of allTransitions) {
		for (const b of allTransitions) {
			if (a.id >= b.id) continue;
			const shared = a.event === b.event && a.from.some((s) => b.from.includes(s));
			if (!shared) continue;
			if (!a.guard || !b.guard) {
				findings.push(`${a.id} and ${b.id} share event ${a.event} from a shared state with no distinguishing guard`);
			} else if (a.guard === b.guard) {
				findings.push(`${a.id} and ${b.id} share event ${a.event} with the same guard`);
			}
		}
	}

	return findings;
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
