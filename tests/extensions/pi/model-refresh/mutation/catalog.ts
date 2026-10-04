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
		old: "\treturn [...merged].sort((a, b) => (position.get(modelKey(a)) ?? Number.MAX_SAFE_INTEGER) - (position.get(modelKey(b)) ?? Number.MAX_SAFE_INTEGER));",
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
		old: "\t\tconst models = offlineUnion();",
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

	// --- the invariant-completeness audit: M2, M4, M6, G2, L1, L2, C2, C3,
	// T1, T4, W1 and D1, the twelve invariants that held no row -----------
	{
		id: "catalog:union-caps-and-drops-the-oldest",
		invariant: "M2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tif (position === undefined) {\n\t\t\tindex.set(key, merged.length);\n\t\t\tmerged.push(model);\n\t\t\tcontinue;\n\t\t}",
		next: "\t\tif (position === undefined) {\n\t\t\tindex.set(key, merged.length);\n\t\t\tmerged.push(model);\n\t\t\tif (merged.length > 3) {\n\t\t\t\tmerged.shift();\n\t\t\t}\n\t\t\tcontinue;\n\t\t}",
		breaks: "the union caps itself and drops the oldest entry, so adding a model to a source removes one the union already had",
	},
	{
		id: "catalog:identity-is-not-the-key",
		invariant: "M4",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\tconst key = modelKey(model);",
		next: "\t\tconst key = `\${merged.length}`;",
		breaks: "identity stops being the model's key, so a source that repeats an id the accumulator already holds appends a second entry and the union serves the same model twice",
	},
	{
		id: "catalog:result-written-into-the-input",
		invariant: "M6",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn served;\n}",
		next: "\t(input.baked as ModelDefinition[]).push(...served);\n\treturn served;\n}",
		breaks: "the union writes its result back into the baked input, so a caller's catalog array grows on every call and the pure function is not pure",
	},
	{
		id: "catalog:override-folds-under-the-accumulator",
		invariant: "G2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tconst merged = unionFirstWins(next, acc);",
		next: "\tconst merged = unionFirstWins(acc, next);",
		breaks: "the override source folds under the accumulator rather than over it, so the persisted catalog's fields lose to the baked entry's and a same-id revision is dropped",
	},
	{
		id: "catalog:baked-dropped-when-a-store-is-present",
		invariant: "L1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\treturn [...input.baked];",
		next: "\t\t\treturn input.stored ? [] : [...input.baked];",
		breaks: "the baked seed is dropped whenever a store is present, so an optional source can remove a model only the baked catalog supplied",
	},
	{
		id: "catalog:malformed-metadata-drops-the-baked-catalog",
		invariant: "L2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\t\t\treturn [...input.baked];",
		next: "\t\t\treturn typeof input.modelsDev === \"object\" && input.modelsDev !== null ? [...input.baked] : [];",
		breaks: "a malformed metadata source is allowed to remove the baked catalog, so a source that returns the wrong shape takes models away instead of contributing nothing",
	},
	{
		id: "catalog:zero-context-window-served",
		invariant: "C2",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn served;\n}",
		next: "\tserved = served.map((model) => ({ ...model, contextWindow: 0 }));\n\treturn served;\n}",
		breaks: "every served entry is handed a zero context window, so a model falls back to pi's clone of another model's limits",
	},
	{
		id: "index:baked-catalog-emptied",
		invariant: "C3",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\tconst baked = () => getBuiltinModels(providerId) as unknown as ModelDefinition[];",
		next: "\t\tconst baked = () => [] as ModelDefinition[];",
		breaks: "the extension serves no baked model, so a models.json modelOverride keyed on a pi-served id has no model to apply to",
	},
	{
		id: "thinking:every-level-mapped",
		invariant: "T1",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\t\tmap[level] = null;",
		next: "\t\tmap[level] = level;",
		breaks: "every level is given an effort even when the endpoint never advertises it, so pi offers a level the provider did not name",
	},
	{
		id: "thinking:fallback-overrides-the-endpoint",
		invariant: "T4",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\tif (efforts.length === 0) {\n\t\treturn { ...map, ...fallback };\n\t}",
		next: "\tif (true) {\n\t\treturn { ...map, ...fallback };\n\t}",
		breaks: "the fallback ladder is returned even when the endpoint named its own efforts, so off is null and every level loses the endpoint's mapping",
	},
	{
		id: "thinking:named-level-remapped",
		invariant: "W1",
		subject: `${EXTENSION_DIR}/thinking.ts`,
		old: "\t\t\tmap[level] = effort;",
		next: "\t\t\tmap[level] = level === \"low\" ? \"high\" : effort;",
		breaks: "a named level is mapped to a different effort, so the request carries an effort the endpoint did not name for that level",
	},
	{
		id: "catalog:union-alternates-with-a-counter",
		invariant: "D1",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\treturn merged;",
		next: "\tconst n = ((unionFirstWins as unknown as { n?: number }).n ?? 0) + 1;\n\t(unionFirstWins as unknown as { n?: number }).n = n;\n\tif (n % 2 === 0) {\n\t\tmerged.push({ id: `drift-${n}`, api: \"openai-completions\", baseUrl: \"\" });\n\t}\n\treturn merged;",
		breaks: "the union grows an extra entry on alternate calls, so the same inputs yield different output on alternate calls",
	},
	{
		id: "index:attach-never-runs",
		invariant: "L3",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\tfor (const reporter of reporters.values()) {\n\t\t\treporter.attach(ctx.ui);\n\t\t}",
		next: "\t\tfor (const reporter of reporters.values()) {\n\t\t\tvoid reporter;\n\t\t}",
		breaks: "the session_start handler never attaches the UI, so the reconciliation the refresh recorded before the session is never rendered",
	},
	{
		id: "report:pre-ui-report-dropped",
		invariant: "L4",
		subject: `${EXTENSION_DIR}/report.ts`,
		old: "\t\t\tlatest = report;\n\t\t\tif (ui !== undefined) render();",
		next: "\t\t\tif (ui !== undefined) {\n\t\t\t\tlatest = report;\n\t\t\t\trender();\n\t\t\t}",
		breaks: "a report recorded before a UI exists is dropped instead of held, so the startup reconciliation never renders",
	},
	{
		id: "refresh:failure-empties-the-catalog",
		invariant: "L5",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\tconst models = buildUnion({ ...unionInput, endpointIds, modelsDev });",
		next: "\tconst models = buildUnion({ ...unionInput, baked: failures.length > 0 ? [] : baked, endpointIds, modelsDev });",
		breaks: "a failed live source drops the baked catalog too, so a network failure empties the served catalog instead of narrowing it",
	},

	// --- the output: O1 to O4 ----------------------------------------
	{
		id: "report:notices-always-emits",
		invariant: "O1",
		subject: `${EXTENSION_DIR}/report.ts`,
		old: "\tif (report.changed) {\n\t\tout.push({ message: deltaLine(report), type: \"info\" });\n\t}",
		next: "\t{\n\t\tout.push({ message: deltaLine(report), type: \"info\" });\n\t}",
		breaks: "a report that changed nothing still renders the delta, so a transition that did not move announces itself",
	},
	{
		id: "report:delta-line-loses-the-counts",
		invariant: "O2",
		subject: `${EXTENSION_DIR}/report.ts`,
		old: "\treturn `updated catalog: +${report.added} / -${report.removed}, ${report.revised} revised`;",
		next: "\treturn \"updated catalog: changed\";",
		breaks: "the delta line stops naming what moved, so a reader cannot tell an add from a revision",
	},
	{
		id: "report:failures-not-rendered",
		invariant: "O3",
		subject: `${EXTENSION_DIR}/report.ts`,
		old: "\tfor (const failure of report.failures) {\n\t\tout.push({ message: failure, type: \"warning\" });\n\t}",
		next: "\tvoid report.failures;",
		breaks: "a failed source is recorded but never announced, so a degraded refresh reads as a clean one",
	},
	{
		id: "default-model:selected-is-always-discarded",
		invariant: "O4",
		subject: `${EXTENSION_DIR}/default-model.ts`,
		old: "\tif (selected.provider === defaultProvider && selected.id === defaultModel) {\n\t\treturn undefined;\n\t}",
		next: "\tif (false) {\n\t\treturn undefined;\n\t}",
		breaks: "the guard stops recognising the selected model as the default, so a session that started on its saved default is told the default was discarded",
	},

	// --- the cache device: E4 to E14 --------------------------------------
	{
		id: "cache:unusable-read-is-content",
		invariant: "E4",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\t} catch {\n\t\treturn undefined;\n\t}",
		next: "\t} catch {\n\t\treturn [];\n\t}",
		breaks: "a read that cannot parse the file returns an empty list instead of absent, so an unusable cache reads as a source that answered nothing",
	},
	{
		id: "cache:read-drops-an-entry",
		invariant: "E5",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\treturn entries.filter(isUsableEntry);",
		next: "\treturn entries.filter(isUsableEntry).slice(1);",
		breaks: "a read drops the first entry, so the cache serves fewer models than it stored",
	},
	{
		id: "cache:write-loses-the-entries",
		invariant: "E6",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\treturn { version: CACHE_VERSION, writtenAt: stamp, endpoints: { [endpoint]: { retrievedAt: stamp, entries: [...entries] } } };",
		next: "\treturn { version: CACHE_VERSION, writtenAt: stamp, endpoints: { [endpoint]: { retrievedAt: stamp, entries: [] } } };",
		breaks: "the write stores no entries, so a write-then-read round-trip loses every model",
	},
	{
		id: "cache:write-failure-swallowed",
		invariant: "E7",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\t\treturn { ok: false, reason: (error as Error)?.message ?? String(error) };",
		next: "\t\treturn { ok: true };",
		breaks: "a failed write reports success, so a caller never learns the cache was not updated",
	},
	{
		id: "cache:write-stores-all-served",
		invariant: "E8",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\t\tconst written = writeCache(models.filter((model) => returned.has(model.id) && (model.type ?? \"chat\") === \"chat\"));",
		next: "\t\tconst written = writeCache(models);",
		breaks: "the write-back stores the whole served catalog, so the file claims endpoint provenance for ids the endpoint never returned",
	},
	{
		id: "cache:write-on-endpoint-failure",
		invariant: "E9",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\tif (endpointIds && writeCache) {",
		next: "\tif (writeCache) {",
		breaks: "the write-back runs even when the endpoint did not answer, so a transient outage rewrites the cache with an empty record",
	},
	{
		id: "cache:fold-overrides-fields",
		invariant: "E10",
		subject: `${EXTENSION_DIR}/catalog.ts`,
		old: "\tfor (const source of idSources.filter((source) => source.override !== true)) {",
		next: "\tfor (const source of [...idSources.filter((source) => source.override !== true)].sort((a) => (a.kind === \"cache\" ? -1 : 0))) {",
		breaks: "the cache folds before the baked catalog, so a cached id overwrites the fields the primary already states",
	},
	{
		id: "refresh:offline-drops-the-cache",
		invariant: "E11",
		subject: `${EXTENSION_DIR}/refresh.ts`,
		old: "\tconst offlineUnion = (): ModelDefinition[] => buildUnion({ ...unionInput, endpointIds: undefined, modelsDev: undefined });",
		next: "\tconst offlineUnion = (): ModelDefinition[] => buildUnion({ ...unionInput, cache: undefined, endpointIds: undefined, modelsDev: undefined });",
		breaks: "the offline union drops the cache, so an offline start no longer serves the ids the endpoint returned last time",
	},
	{
		id: "cache:endpoint-ignored",
		invariant: "E12",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\tconst record = (file.endpoints as Record<string, unknown>)[endpoint];",
		next: "\tconst record = Object.values(file.endpoints as Record<string, unknown>)[0];",
		breaks: "the read ignores the declared endpoint and takes the first record, so another endpoint's entries are served under this one",
	},
	{
		id: "cache:record-shape-unchecked",
		invariant: "E13",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\tif (!Array.isArray(entries)) return undefined;",
		next: "\tif (!Array.isArray(entries)) return [];",
		breaks: "a record with no entries array reads as content rather than an unusable file",
	},
	{
		id: "cache:expires-on-age",
		invariant: "E14",
		subject: `${EXTENSION_DIR}/cache.ts`,
		old: "\tconst entries = (record as { entries?: unknown }).entries;",
		next: "\tconst entries = (record as { entries?: unknown }).entries;\n\tif (String((record as { retrievedAt?: unknown }).retrievedAt) < \"2000-01-01T00:00:00.000Z\") return undefined;",
		breaks: "the read gates on the retrieve date, so an old cache is discarded even though nothing said it should expire",
	},
];
