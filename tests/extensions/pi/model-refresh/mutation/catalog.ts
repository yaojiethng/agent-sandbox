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
		old: "export const V1_BASE",
		next: "export const V1_BASE",
		control: true,
		breaks: "nothing is broken: this row replays the mirror as it stands, so a mirror the suite cannot run green in turns every break below red",
	},

	// --- M2, G1, G2: the store layer, its gate, and its merge ---
	{
		id: "catalog:store-layer-dropped",
		invariant: "M2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tconst remote = isStoreNewerThanBaked(stored, generatedAt) ? storeEntriesFor(stored, providerId) : [];",
		next: "\tconst remote: ModelDefinition[] = [];",
		breaks: "the persisted store layer is dropped, which is the original defect: a model only pi.dev carries never reaches the catalog",
	},
	{
		id: "catalog:freshness-gate-always-passes",
		invariant: "G1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn stored.lastModified !== undefined && stored.lastModified > generatedAt;",
		next: "\treturn stored.lastModified !== undefined;",
		breaks: "the freshness gate opens on any timestamped store, so a store older than the baked data replaces it",
	},
	{
		id: "catalog:same-id-appended",
		invariant: "G2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: [
			"\t\tif (index >= 0) {",
			"\t\t\tmerged[index] = model;",
			"\t\t} else {",
			"\t\t\tmerged.push(model);",
			"\t\t}",
		].join("\n"),
		next: "\t\tmerged.push(model);",
		breaks: "a same-id entry is appended instead of replacing, so the union carries the model twice and the stale entry still wins the resolver",
	},

	// --- M5, M4, M3: the metadata overlay and the shape of what it writes ---
	{
		id: "catalog:overlay-limits-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tcontextWindow: metadata.limit?.context ?? model.contextWindow,\n\t\tmaxTokens: metadata.limit?.output ?? model.maxTokens,",
		next: "\t\tcontextWindow: model.contextWindow,\n\t\tmaxTokens: model.maxTokens,",
		breaks: "the corrected limits never land, so a models.dev context window or output limit is ignored and the stale baked value is served instead",
	},
	{
		id: "catalog:zero-context-window-accepted",
		invariant: "M5",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tcontextWindow: metadata.limit?.context ?? model.contextWindow,",
		next: "\t\tcontextWindow: metadata.limit?.context ?? 0,",
		breaks: "the overlay accepts a zero context window, so a model that sources describe with no limit is served with a limit of zero",
	},
	{
		id: "catalog:unrecognised-modality-kept",
		invariant: "M5",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t(modality): modality is \"text\" | \"image\" => modality === \"text\" || modality === \"image\",",
		next: "\t\t(modality): modality is \"text\" | \"image\" => true,",
		breaks: "normalizeInput keeps a modality pi's model type does not accept, so a served model claims an input shape the runtime cannot use",
	},

	// --- M4 and the shape checks: what a malformed source may do ---
	{
		id: "catalog:idless-store-entry-trusted",
		invariant: "L2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "typeof model?.id === \"string\" && model.id.length > 0 &&",
		next: "model !== null &&",
		breaks: "a stored entry with no id is trusted, so a corrupt store contributes an entry the union can neither serve nor name",
	},
	{
		id: "catalog:unvalidated-id-trusted",
		invariant: "M7",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "typeof model?.id === \"string\" && model.id.length > 0 &&",
		next: "model?.id !== undefined &&",
		breaks: "the store's id check stops being a check at all, so a persisted entry with a numeric or object id reaches pi as a model pi cannot key on",
	},
	{
		id: "catalog:empty-id-trusted",
		invariant: "M7",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "model.id.length > 0 &&",
		next: "model.id.length >= 0 &&",
		breaks: "the store's id check stops rejecting the empty string, so a persisted entry with an empty id reaches pi as a model pi cannot key on",
	},
	{
		id: "catalog:live-list-trusted-unshaped",
		invariant: "L2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tif (!Array.isArray(liveIds)) {",
		// The anchor keeps the two nullish guards, so the mutant walks a live
		// list that is not an array and nothing else. A row that dropped the
		// guard outright would throw on every row whose live list is absent,
		// which turns the whole suite red for a reason of its own: a crash is
		// not evidence that the leak half holds (L2, and the gate's attribution
		// rule).
		next: "\tif (liveIds === undefined || liveIds === null) {",
		breaks: "the live list is trusted without a shape check, so a response body the parser mistyped is walked as a list of ids",
	},
	{
		id: "catalog:live-layer-duplicates-a-known-id",
		invariant: "M4",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tif (typeof id !== \"string\" || known.has(id)) {",
		next: "\t\tif (typeof id !== \"string\") {",
		breaks: "the live layer duplicates a model the earlier sources know, so the union carries one id twice",
	},

	// --- L1, C1, C2: the offline path, the registration, the transport ---
	{
		id: "refresh:offline-startup-drops-the-store",
		invariant: "C1",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\t\treturn buildUnion({ baked, stored, generatedAt, liveIds: undefined, modelsDev: undefined, providerId });",
		next: "\t\treturn baked.slice();",
		breaks: "the offline startup path drops the persisted store, which is the original defect on the path pi actually takes: the registration then serves fewer models than pi would serve with no extension at all",
	},
	{
		id: "index:wrong-provider-id",
		invariant: "C1",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\tpi.registerProvider(PROVIDER_ID, config);",
		next: "\tpi.registerProvider(\"opencode\", config);",
		breaks: "the extension registers the wrong provider id, so the union is never composed onto the provider it belongs to",
	},
	{
		id: "catalog:live-only-wrong-transport",
		invariant: "M8",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tif (ANTHROPIC_TRANSPORT.has(id)) {",
		next: "\tif (false) {",
		breaks: "a live-only model is served over the default transport instead of the Anthropic Messages adapter, so pi builds a request shape the endpoint rejects",
	},
	{
		id: "catalog:transport-table-bypassed",
		invariant: "M8",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tif (ANTHROPIC_TRANSPORT.has(id)) {",
		next: "\tif (true) {",
		breaks: "the transport table is bypassed, so every live-only model is served on the Anthropic adapter, including the ids pi carries on another one",
	},

	// --- M3: what the union builds for a model the sources only half describe ---
	{
		id: "catalog:models-dev-name-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tname: metadata?.name ?? id,",
		next: "\t\tname: id,",
		breaks: "the name models.dev gives a live-only model is dropped, so pi serves the raw id where the catalog names the model",
	},
	{
		id: "catalog:models-dev-context-window-dropped",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tcontextWindow: metadata?.limit?.context ?? DEFAULT_CONTEXT_WINDOW,",
		next: "\t\tcontextWindow: DEFAULT_CONTEXT_WINDOW,",
		breaks: "the context window models.dev states for a live-only model is dropped, so the model is served with the fallback limit",
	},
	{
		id: "catalog:silent-cost-field-zeroed",
		invariant: "M3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\t\t\toutput: metadata.cost.output ?? model.cost?.output ?? DEFAULT_COST.output,",
		next: "\t\t\t\t\toutput: metadata.cost.output ?? 0,",
		breaks: "a cost field models.dev is silent about is zeroed instead of falling back to the baked one, so a priced model is served as free",
	},
	// --- T2: the disabled state the endpoint names ---
	{
		id: "thinking:none-effort-not-off",
		invariant: "T2",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\t\tconst level = effort === OFF_EFFORT ? \"off\" : effort;",
		next: "\t\tconst level = effort;",
		breaks: "the endpoint's none effort is not recognised as the off level, so off is marked unsupported and pi raises the level instead of disabling thinking",
	},
	{
		id: "thinking:off-maps-to-disabled",
		invariant: "T2",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "const OFF_EFFORT = \"none\";",
		next: "const OFF_EFFORT = \"disabled\";",
		breaks: "the off level maps to an effort the endpoint never advertises, so the map claims a disable signal that is not the endpoint's",
	},

	// --- T3: the level map an entry carries, and the family that carries it ---
	{
		id: "catalog:chat-compat-forced",
		invariant: "T3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tconst compat = api === \"anthropic-messages\" || (efforts?.length && !isDeepseekFamily) ? CHAT_COMPAT : DEEPSEEK_COMPAT;",
		next: "\tconst compat = CHAT_COMPAT;",
		breaks: "every live-only model is served on the chat compat block, so a deepseek-family model loses the thinking toggle the family needs",
	},
	{
		id: "catalog:non-reasoning-model-served-an-empty-map",
		invariant: "T3",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tthinkingLevelMap: levelMapFor(efforts, true),",
		next: "\t\tthinkingLevelMap: metadata?.reasoning === false ? { off: null, minimal: null, low: null, medium: null, high: null, xhigh: null, max: null } : levelMapFor(efforts, true),",
		breaks: "a model models.dev says cannot reason is served an all-null map, so the entry no longer carries the levels its endpoint advertises, and only pi's narrowing to off conceals that",
	},

	// --- M2 with an empty baked catalog: the second former survivor ---
	{
		id: "catalog:empty-baked-drops-the-store",
		invariant: "M2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tconst { baked, stored, generatedAt, liveIds, modelsDev, providerId } = input;",
		next: [
			"\tconst { baked: bakedIn, stored: storedIn, generatedAt, liveIds, modelsDev, providerId } = input;",
			"\tconst baked = bakedIn.length ? bakedIn : [];",
			"\tconst stored = bakedIn.length ? storedIn : undefined;",
		].join("\n"),
		breaks: "an empty baked catalog also drops the store's models, so the union is not monotone in the store: growing the baked layer to nothing removes a model",
	},
];
