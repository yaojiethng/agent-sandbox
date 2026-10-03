/**
 * The mutation catalog: one row per deliberate break of the model-refresh
 * extension, with the invariant the break attacks.
 *
 * A green suite is only evidence when a broken suite is red. This catalog is
 * the machine form of that question: each row is a defect the design
 * explicitly rejects - a dropped source layer, a gate that always opens, an
 * overlay that accepts a zero limit - and the gate replays the row and asks
 * the suite to fail.
 *
 * The rows below are not hypothetical. While this invariant set was being
 * written, thirteen deliberate breaks were applied one at a time and the suite
 * of that day was asked whether it noticed. Eleven were caught. Two survived,
 * and both survivors were invariants nobody had written down: an overlay that
 * let models.dev set `contextWindow` to `0`, and an empty baked catalog that
 * dropped the persisted store's models. The suite holds both now, and the two
 * rows that attack them (M5 zero context window, M2 empty baked) are the
 * reason the catalog is a list of rows rather than a note.
 *
 * Six verdicts, and one of them passes a break row:
 *
 *   proven       - the suite failed against the mutant, and a failing test
 *                  that is named after the row's invariant failed on an
 *                  assertion. The suite pins the line the mutation changed.
 *   survived     - the suite passed. The line is unpinned, so the suite is
 *                  green without the invariant it appears to cover. This is a
 *                  finding about the suite, and the gate fails on it. A
 *                  control row requires this verdict: the mirror is
 *                  unmutated, so green is the only answer that means the
 *                  replay harness works.
 *   no-op        - the old text is not in the subject any more, or is
 *                  ambiguous. The row drifted from the code; the gate fails on
 *                  it too, so a stale catalog cannot read as a passing gate.
 *   unloadable   - the mutant does not parse or load. A mutant that only
 *                  fails to compile turns the whole suite red for a reason
 *                  that proves nothing, so the row is rejected rather than
 *                  counted as proven.
 *   timed-out    - the replayed suite hit its deadline. A killed child has no
 *                  exit status, and reading the deadline as a failure would
 *                  prove every break, so the row is neither.
 *   not-run      - the pi installation the suite reads is absent. The row did
 *                  not run, so it has no verdict to report, and the gate fails
 *                  rather than printing a line that reads as green.
 *
 * A proven row is only proven when a failing test names the invariant the row
 * attacks. The invariant cases name themselves `INV <invariant> -- <statement>`
 * in the replayed output, so the gate can tell a break the suite pins from a
 * break that merely made some other test red, and a row whose invariant the
 * suite does not hold is a row whose `invariant:` field is wrong.
 *
 * The `old` text is matched byte-exactly and must be unique in its subject; an
 * ambiguous anchor is a no-op, not a guess. The subject paths are relative to
 * the repository root.
 *
 * There is no `tests` field. Every row replays the whole model-refresh node
 * suite, so the gate cannot drift from a row that names the suites that must
 * turn red.
 */

export interface Mutation {
	/** A stable row id, unique in the catalog. */
	id: string;
	/** The invariant the break attacks, as `invariants.ts` names it. */
	invariant: string;
	/** The subject file, relative to the repository root. */
	subject: string;
	/** The exact text to replace, first occurrence, unique in the subject. */
	old: string;
	/** The replacement that breaks the invariant. */
	next: string;
	/** The defect the mutation stands in for, in one sentence. */
	breaks: string;
	/**
	 * Set on a control row: the mirror is built and replayed unmutated, and the
	 * verdict the gate requires is `survived`. A control row attacks no
	 * product invariant, so its `invariant` names the harness.
	 */
	control?: true;
}

export const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/model-refresh";

export const MUTATIONS: readonly Mutation[] = [
	// --- the control: the mirror the suite must run green in ---------------
	{
		id: "control:unmutated-mirror",
		invariant: "gate",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		// The anchor text of a control row names the subject and is never used.
		old: "export function derivedTransport",
		next: "export function derivedTransport",
		control: true,
		breaks: "nothing is broken: this row replays the mirror as it stands, so a mirror the suite cannot run green in turns every break below red",
	},

	// --- the store layer, its gate, and the provider filter ---------------
	{
		id: "catalog:freshness-gate-always-passes",
		invariant: "G1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn stored.lastModified !== undefined && stored.lastModified > generatedAt;",
		next: "\treturn stored.lastModified !== undefined;",
		breaks: "the freshness gate opens on any timestamped store, so a store older than the baked data replaces it",
	},
	{
		id: "catalog:store-entries-unfiltered-by-provider",
		invariant: "G3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\ttypeof model?.id === \"string\" && model.id.length > 0 && (model as { provider?: string }).provider === providerId,",
		next: "\t\t\ttypeof model?.id === \"string\" && model.id.length > 0,",
		breaks: "another provider's persisted entries reach the union, so a model this provider does not serve is served under it",
	},

	// --- M1, L2, M7: what a source may contribute, and what a shape check does ---
	{
		id: "catalog:baked-layer-dropped",
		invariant: "M1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\treturn [...input.baked];",
		next: "\t\t\treturn [];",
		breaks: "the baked layer is dropped, so the union serves nothing whenever the optional sources are silent",
	},
	{
		id: "catalog:idless-store-entry-trusted",
		invariant: "M7",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\ttypeof model?.id === \"string\" && model.id.length > 0 &&",
		next: "\t\t\tmodel !== null &&",
		breaks: "a stored entry with no id is trusted, so a corrupt store contributes an entry the union can neither serve nor name",
	},
	{
		id: "catalog:empty-id-trusted",
		invariant: "M7",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "model.id.length > 0 &&",
		next: "model.id.length >= 0 &&",
		breaks: "the id check stops rejecting the empty string, so a persisted entry with an empty id reaches pi as a model pi cannot key on",
	},
	{
		id: "catalog:base-url-dropped",
		invariant: "M5",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn { api, baseUrl: decl.baseUrls[api] ?? \"\" };",
		next: "\treturn { api, baseUrl: \"\" };",
		breaks: "a served entry loses its base url, so pi builds a request against no gateway",
	},
	{
		id: "catalog:unrecognised-modality-kept",
		invariant: "M5",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t(modality): modality is \"text\" | \"image\" => modality === \"text\" || modality === \"image\",",
		next: "\t\t(modality): modality is \"text\" | \"image\" => true,",
		breaks: "normalizeInput keeps a modality pi's model type does not accept, so a served model claims an input shape the runtime cannot use",
	},

	// --- U1 to U4: the union's own rules ---
	{
		id: "catalog:first-wins-becomes-last-wins",
		invariant: "U1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tif (value !== undefined) {",
		next: "\t\tif (true) {",
		breaks: "an undefined field in the earlier entry overwrites the later source's value, so first-wins stops filling the fields the first source leaves blank",
	},
	{
		id: "catalog:fill-arguments-swapped",
		invariant: "U1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tmerged[position] = fillMissing(merged[position] as ModelDefinition, model);",
		next: "\t\tmerged[position] = fillMissing(model, merged[position] as ModelDefinition);",
		breaks: "the later source fills first, so it overwrites the value the earlier source supplied",
	},
	{
		id: "catalog:override-order-not-reversed",
		invariant: "U2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tfor (const source of idSources.filter((source) => source.override === true).reverse()) {",
		next: "\tfor (const source of idSources.filter((source) => source.override === true)) {",
		breaks: "the override sources fold in declaration order, so the last-listed override is the strongest and the documented precedence is inverted",
	},
	{
		id: "catalog:introduced-id-prepended",
		invariant: "U3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn [...merged].sort((a, b) => (position.get(a.id) ?? Number.MAX_SAFE_INTEGER) - (position.get(b.id) ?? Number.MAX_SAFE_INTEGER));",
		next: "\treturn merged;",
		breaks: "the accumulator's order is not restored, so an id an override source introduces is served ahead of the primary catalog's own entries",
	},
	{
		id: "catalog:metadata-overrides",
		invariant: "U4",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\treturn metadata ? fillMissing(model, metadata) : model;",
		next: "\t\t\treturn metadata ? fillMissing(metadata, model) : model;",
		breaks: "the metadata source overwrites the value an id source supplied, so models.dev becomes an authority it is declared not to be",
	},

	// --- M3: what the union builds for a model the sources only half describe ---
	{
		id: "catalog:models-dev-name-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tname: metadata?.name ?? id,",
		next: "\t\tname: id,",
		breaks: "the name models.dev gives a model is dropped, so pi serves the raw id where the catalog names the model",
	},
	{
		id: "catalog:models-dev-context-window-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tcontextWindow: metadata?.limit?.context ?? DEFAULT_CONTEXT_WINDOW,",
		next: "\t\tcontextWindow: DEFAULT_CONTEXT_WINDOW,",
		breaks: "the context window models.dev states for an id is dropped, so the model is served with the fallback limit",
	},
	{
		id: "catalog:models-dev-output-limit-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tmaxTokens: metadata?.limit?.output ?? DEFAULT_MAX_TOKENS,",
		next: "\t\tmaxTokens: DEFAULT_MAX_TOKENS,",
		breaks: "the output limit models.dev states for an id is dropped, so the model is served with the fallback limit",
	},

	// --- M8: the transport derivation ---
	{
		id: "catalog:openai-label-ignored",
		invariant: "M8",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tif (npm === \"@ai-sdk/openai\") {\n\t\treturn \"openai-responses\";\n\t}",
		next: "\tif (false) {\n\t\treturn \"openai-responses\";\n\t}",
		breaks: "an id models.dev labels @ai-sdk/openai falls to the completions surface, where pi's own catalog serves it over the responses adapter",
	},
	{
		id: "catalog:anthropic-label-ignored",
		invariant: "M8",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tif (npm === \"@ai-sdk/anthropic\") {\n\t\treturn \"anthropic-messages\";\n\t}",
		next: "\tif (false) {\n\t\treturn \"anthropic-messages\";\n\t}",
		breaks: "an id models.dev labels @ai-sdk/anthropic falls to the completions surface, where pi's own catalog serves it over the messages adapter",
	},
	{
		id: "catalog:declared-transport-ignored",
		invariant: "M8",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tif (ids.includes(id)) {\n\t\t\treturn api as ModelDefinition[\"api\"];\n\t\t}",
		next: "\t\tif (false) {\n\t\t\treturn api as ModelDefinition[\"api\"];\n\t\t}",
		breaks: "a declared transport entry is ignored, so an id no metadata classifies is served on the wrong adapter",
	},

	// --- T2, T3: the disabled state, and the map an entry carries ---
	{
		id: "thinking:none-effort-not-off",
		invariant: "T2",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\t\tconst level = effort === offEffort ? \"off\" : effort;",
		next: "\t\tconst level = effort;",
		breaks: "the declared disabled-effort name is not recognised as the off level, so off is marked unsupported and pi raises the level instead of disabling thinking",
	},
	{
		id: "thinking:silent-endpoint-loses-the-fallback",
		invariant: "T3",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\t\t...(names.fallbackEfforts ?? DEFAULT_FALLBACK_EFFORTS),",
		next: "\t\t...{},",
		breaks: "an endpoint that names no effort is served an all-null map, so the model advertises no usable level at all",
	},
	{
		id: "catalog:prefix-rule-ignored",
		invariant: "T3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tfor (const [prefix, override] of Object.entries(decl.compat?.byPrefix ?? {})) {",
		next: "\tfor (const [prefix, override] of Object.entries({})) {",
		breaks: "the id-prefix compat rule is ignored, so a family that needs the deepseek toggle loses it and its disabled level stops reaching the gateway",
	},

	// --- C1, C4, L2: the registration, the offline path, and the fetch contract ---
	{
		id: "refresh:offline-startup-drops-the-store",
		invariant: "C1",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\t\tconst models = buildUnion({ ...unionInput, endpointIds: undefined, modelsDev: undefined });",
		next: "\t\tconst models = buildUnion({ ...unionInput, stored: undefined, endpointIds: undefined, modelsDev: undefined });",
		breaks: "the offline startup path drops the persisted store, which is the original defect on the path pi actually takes: the registration then serves fewer models than pi would serve with no extension at all",
	},
	{
		id: "catalog:empty-id-entry-served",
		invariant: "M7",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tif (typeof model?.id !== \"string\" || model.id.length === 0) {",
		next: "\t\tif (typeof model?.id !== \"string\") {",
		breaks: "an entry with an empty id is appended rather than dropped, so the union serves a model pi cannot key on",
	},
	{
		id: "index:declaration-ignored",
		invariant: "C4",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\tconst declarations = loadDeclarations();",
		next: "\tconst declarations = {};",
		breaks: "the declaration is ignored, so the extension registers no provider at all",
	},
	{
		id: "index:wrong-provider-id",
		invariant: "C4",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\tpi.registerProvider(providerId, config);",
		next: "\t\tpi.registerProvider(\"opencode\", config);",
		breaks: "the extension registers the wrong provider id, so the union is never composed onto the provider it belongs to",
	},

	// --- N1, N2: the declaration's validation and its home ---
	{
		id: "config:unknown-source-kind-accepted",
		invariant: "N1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\tif (typeof raw.kind !== \"string\" || !SOURCE_KINDS.includes(raw.kind as SourceKind)) {",
		next: "\tif (typeof raw.kind !== \"string\") {",
		breaks: "an unknown source kind is accepted, so a declaration naming a source the union cannot read reaches the union as one",
	},
	{
		id: "config:empty-source-list-accepted",
		invariant: "N1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\tif (sources.length === 0) {\n\t\treturn undefined;\n\t}",
		next: "\tif (false) {\n\t\treturn undefined;\n\t}",
		breaks: "a provider with no readable source is accepted, so the declaration yields a provider whose union can only ever be empty",
	},
	{
		id: "config:declaration-path-moved",
		invariant: "N2",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "export const DECLARATIONS_PATH = fileURLToPath(new URL(\"./sources.json\", import.meta.url));",
		next: "export const DECLARATIONS_PATH = fileURLToPath(new URL(\"../../sources.json\", import.meta.url));",
		breaks: "the declaration is read from outside the extension folder, so the extension no longer owns every input it reads",
	},
];
