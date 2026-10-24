/**
 * The mutation catalog: one row per deliberate break of the model-failover
 * extension, with the suite that must notice the break.
 *
 * A green suite is only evidence when a broken suite is red. Each row is a
 * defect the design explicitly rejects - an off-by-one threshold, a cooldown
 * that ignores the failure's class, a success that does not clear a cooldown,
 * a sticky guard that never matches, a degrade tier that picks the wrong
 * route, a duplicate route the loader accepts, and a classification that
 * cannot see a quota error - and the gate replays the row and asks the named
 * suite to fail.
 *
 * Five verdicts, and only one of them passes the gate on a break row:
 *
 *   proven       - the named suite failed against the mutant. The suite pins
 *                  the line the mutation changed.
 *   survived     - the named suite passed. The line is unpinned, so the suite
 *                  is green without the invariant it appears to cover. This
 *                  is a finding about the suite, and the gate fails on it.
 *   no-op        - the old text is not in the subject any more, or is
 *                  ambiguous. The row drifted from the code; the gate fails
 *                  on it too, so a stale catalog cannot read as a passing
 *                  gate.
 *   unloadable   - the mutant does not parse or load. A mutant that only
 *                  fails to compile turns every suite red for a reason that
 *                  proves nothing, so the row is rejected rather than
 *                  counted as proven.
 *   timed-out    - the replayed suite hit its deadline. A killed child has
 *                  no exit status, and reading the deadline as a failure
 *                  would prove every break, so the row is neither.
 *
 * The control row replays an unmutated mirror and must reach `survived`.
 * Without it a mirror the suite cannot run green in turns every break green,
 * because a replay that is red for any reason reads as proof.
 *
 * The `old` text is matched byte-exactly and must be unique in its subject;
 * an ambiguous anchor is a no-op, not a guess.
 */

export interface Mutation {
	/** A stable row id, unique in the catalog. */
	id: string;
	/** The invariant the break attacks. */
	invariant: string;
	/** The subject file, relative to the repository root. */
	subject: string;
	/** The exact text to replace, first occurrence, unique in the subject. */
	old: string;
	/** The replacement that breaks the invariant. */
	next: string;
	/**
	 * The node suites that must turn red. Each row names the suites that
	 * own the invariant, not the whole suite: the gate replays the row many
	 * times, and the cost of a row is the suites it must actually run.
	 */
	tests: string[];
	/** The defect the mutation stands in for, in one sentence. */
	breaks: string;
	/** A control row: proven by the suite staying green, never by a red line. */
	control?: true;
}

export const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/model-failover";

export const MUTATIONS: readonly Mutation[] = [
	// --- TI1: the threshold fires at N, not at N+1 ---
	{
		id: "T3:threshold-off-by-one",
		invariant: "TI1",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "\tif (streak >= threshold) {",
		next: "\tif (streak > threshold) {",
		tests: ["ledger.test.ts", "router.test.ts"],
		breaks: "the route cools on the failure after the threshold, so a burst costs one request more before the switchover",
	},
	// --- TI2: the cooldown window comes from the class that fired ---
	{
		id: "T4:cooldown-ignores-class",
		invariant: "TI2",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "\tconst cooling = (failureClass: FailureClass): RouteState => ({ state: \"cooling\", until: now + cooldownMs[failureClass], class: failureClass, ...(outcome.scope === \"none\" ? {} : { scope: outcome.scope }) });",
		next: "\tconst cooling = (_failureClass: FailureClass): RouteState => ({ state: \"cooling\", until: now + cooldownMs.transient, class: \"transient\" });",
		tests: ["ledger.test.ts"],
		breaks: "a quota-class failure gets the short transient window, so an exhausted route returns while the account is still limited",
	},
	// --- TI3: a success clears the cooldown wherever it arrives ---
	{
		id: "T5:success-keeps-cooldown",
		invariant: "TI3",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "\tif (outcome.ok) {\n\t\treturn initialRouteState();\n\t}",
		next: "\tif (outcome.ok) {\n\t\treturn entry;\n\t}",
		tests: ["ledger.test.ts", "router.test.ts"],
		breaks: "a successful dispatch during a cooldown changes nothing, so a recovered route never re-enters rotation",
	},
	// --- G1: the sticky guard matches the previous route ---
	{
		id: "G1:sticky-never-matches",
		invariant: "G1",
		subject: `${EXTENSION_DIR}/router.ts`,
		old: "\t\t\t: healthy.find((route) => route.provider === input.previous?.provider && route.model === input.previous?.model);",
		next: "\t\t\t: healthy.find((route) => route.provider === input.previous?.provider && route.model === \"__never_matches__\");",
		tests: ["router.test.ts"],
		breaks: "the served route never sticks, so every dispatch re-walks the declared order and the session thrashes across healthy routes",
	},
	// --- R5: the degrade tier dispatches the chain head ---
	{
		id: "degrade:picks-last-route",
		invariant: "R5",
		subject: `${EXTENSION_DIR}/router.ts`,
		old: "\treturn { route: chain.routes[0], tier: \"degraded\" };",
		next: "\treturn { route: chain.routes[chain.routes.length - 1], tier: \"degraded\" };",
		tests: ["router.test.ts"],
		breaks: "a fully cooled chain dispatches its least-preferred route first, inverting the declared order exactly when the operator's preference matters most",
	},
	// --- S1: the loader refuses one route listed twice ---
	{
		id: "S1:duplicate-route-accepted",
		invariant: "S1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\t\t\t\tthrow new DeclarationsError(`chain '${chain.id}' lists the route '${key}' twice; one route entry per provider and model`);",
		next: "\t\t\t\tvoid 0;",
		tests: ["config.test.ts"],
		breaks: "one chain may list a route twice, and two ledger entries collide on one key, so the route's state is the last writer's guess",
	},
	// --- S1: the loader refuses one route declared by two chains ---
	{
		id: "S1:cross-chain-route-accepted",
		invariant: "S1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\t\t\t\tthrow new DeclarationsError(`the route '${key}' is declared by two chains, '${owner}' and '${chain.id}'; one physical route belongs to one chain, because the ledger holds one entry per route`);",
		next: "\t\t\t\tvoid 0;",
		tests: ["config.test.ts"],
		breaks: "two chains declare one route and contend over one ledger key, so the threshold and the cooldowns that apply become declaration-order-dependent",
	},
	// --- C1: the classification sees a quota error ---
	{
		id: "C1:limited-classification-dead",
		invariant: "C1",
		subject: `${EXTENSION_DIR}/classify.ts`,
		old: "\tfor (const { scope, pattern } of UNRECOVERABLE) {",
		next: "\tfor (const { scope, pattern } of [] as readonly { readonly scope: FailureScope; readonly pattern: RegExp }[]) {",
		tests: ["classify.test.ts"],
		breaks: "no error text classifies as limited, so a quota-class failure gets the short transient window and the route returns while the account is still limited",
	},
	// --- The declarations contract: a route-level thinking level is one of six names ---
	{
		id: "T-level-names-unchecked",
		invariant: "S1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\tif (raw.thinkingLevel !== undefined && (typeof raw.thinkingLevel !== \"string\" || !THINKING_LEVEL_NAMES.includes(raw.thinkingLevel as ThinkingLevelName))) {",
		next: "\tif (raw.thinkingLevel !== undefined && typeof raw.thinkingLevel !== \"string\") {",
		tests: ["config.test.ts"],
		breaks: "a route declares a level pi does not know, and the router forwards a string the dispatch boundary must then trust",
	},
	// --- S2: the ledger file carries its version, and another version reads empty ---
	{
		id: "ledger-version-unchecked",
		invariant: "S2",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "\tif ((raw as { version?: unknown }).version !== 1) {",
		next: "\tif (false) {",
		tests: ["ledger.test.ts"],
		breaks: "a file another version wrote is read as version 1, so state this version cannot interpret drives its cooldowns",
	},
	// --- The declarations contract: every chain owns its cooldown object ---
	{
		id: "cooldown-defaults-aliased",
		invariant: "S1",
		subject: `${EXTENSION_DIR}/config.ts`,
		old: "\t\treturn { ...DEFAULT_COOLDOWN_MS };",
		next: "\t\treturn DEFAULT_COOLDOWN_MS;",
		tests: ["config.test.ts"],
		breaks: "every chain that omits the block shares one cooldown object, so one accidental write aliases all declarations at once",
	},
	// --- TI7: a failure that is not the route's does not cool it ---
	{
		id: "A1:request-scope-cools",
		invariant: "TI7",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "\tif (outcome.scope === \"request\" || outcome.scope === \"unclassified\") {",
		next: "\tif (false) {",
		tests: ["ledger.test.ts"],
		breaks: "a malformed request, or an unreadable failure, cools the route for the long window and counts a strike, so a caller's mistake demotes a healthy model",
	},
	// --- The control: an unmutated mirror must stay green ---
	{
		id: "control:comment-words",
		invariant: "CONTROL",
		subject: `${EXTENSION_DIR}/ledger.ts`,
		old: "/** The initial state: eligible, no consecutive failures. */",
		next: "/** The initial state: eligible, no consecutive failures. The control row appends these words and nothing else. */",
		tests: ["ledger.test.ts"],
		breaks: "the control row edits no behaviour; a red line here names a harness that cannot be trusted",
		control: true,
	},
];
