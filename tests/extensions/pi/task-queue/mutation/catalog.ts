/**
 * The mutation catalog: one row per deliberate break of the task-queue
 * extension, with the suite that must notice the break.
 *
 * A green suite is only evidence when a broken suite is red. This catalog
 * is the machine form of that question: each row is a defect the design
 * explicitly rejects - a dropped gate, a reordered effect, a weakened
 * identity, a removed heartbeat - and the gate replays the row and asks
 * the named suite to fail.
 *
 * Five verdicts, and only one of them passes the gate:
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
 * Every row names the repaired invariant its break would have caught. The
 * `caught` field is the round-2 lesson made machine-checkable: the bring-
 * back non-atomicity (I7) and the unsound resumed-path inference (I12) both
 * shipped green, and the rows below are the checks that would have caught
 * them before a reviewer did.
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
}

export const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/task-queue";

export const MUTATIONS: readonly Mutation[] = [
	// --- I7: the bring-back writes exactly the file set the primary names ---
	{
		id: "bringback:no-intent",
		invariant: "I7",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\t\t\t\t\twriteBringBackIntent(run.stateDir, params.taskId, { paths: [...params.paths], at: nowIso() });",
		next: "\t\t\t\t\t\tvoid 0;",
		tests: ["invariants.test.ts"],
		breaks: "the bring-back writes no intent record, so a stopped call leaves no evidence and the resumed path has nothing to read",
	},
	{
		id: "bringback:resume-accepts-any-file-set",
		invariant: "I7",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\t\t\t\t\tif (!sameFileSet(intent.paths, params.paths)) {",
		next: "\t\t\t\t\t\tif (false) {",
		tests: ["wired.test.ts"],
		breaks: "a resumed bring-back accepts any file set the proposal holds, not the one the interrupted attempt wrote",
	},
	{
		id: "tasks:file-set-subset-rule-dropped",
		invariant: "I7",
		subject: `${EXTENSION_DIR}/tasks.ts`,
		old: "\t\tif (!proposal.paths.includes(p)) {",
		next: "\t\tif (false) {",
		tests: ["merge.test.ts", "ops.test.ts"],
		breaks: "the file set is no longer a subset of the proposal, so the bring-back writes paths nobody offered",
	},
	{
		id: "merge:write-skips-the-dirty-gate",
		invariant: "I7",
		subject: `${EXTENSION_DIR}/merge.ts`,
		old: "\tconst hit = paths.filter((p) => dirty.has(p));",
		next: "\tconst hit: string[] = []; void dirty;",
		tests: ["merge.test.ts"],
		breaks: "the main-tree write no longer refuses a dirty path the file set names",
	},

	// --- I12: a failed operation spends no resource, and a retry is safe ---
	{
		id: "bringback:prune-refusal-after-the-write",
		invariant: "I12",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: [
			"\t\t\t\t\t\tlive.beat();",
			"\t\t\t\t\t\tassertPrunable(spec);",
			"\t\t\t\t\t\tlive.beat();",
			"\t\t\t\t\t\tif (params.paths.length === 0) {",
			"\t\t\t\t\t\t\tarchiveTrack(run.stateDir, params.taskId, mainRoot, task.baseline, task.branch);",
			"\t\t\t\t\t\t\tarchived = true;",
			"\t\t\t\t\t\t} else {",
			"\t\t\t\t\t\t\tapplied = applyBringBack(mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: params.paths }).applied;",
			"\t\t\t\t\t\t}",
		].join("\n"),
		next: [
			"\t\t\t\t\t\tlive.beat();",
			"\t\t\t\t\t\tif (params.paths.length === 0) {",
			"\t\t\t\t\t\t\tarchiveTrack(run.stateDir, params.taskId, mainRoot, task.baseline, task.branch);",
			"\t\t\t\t\t\t\tarchived = true;",
			"\t\t\t\t\t\t} else {",
			"\t\t\t\t\t\t\tapplied = applyBringBack(mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: params.paths }).applied;",
			"\t\t\t\t\t\t}",
			"\t\t\t\t\t\tassertPrunable(spec);",
		].join("\n"),
		tests: ["wired.test.ts"],
		breaks: "the prune refusal is asked after the write, so a refused bring-back has already changed the main tree",
	},
	{
		id: "bringback:prune-before-the-write",
		invariant: "I12",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: [
			"\t\t\t\t\t\tif (params.paths.length === 0) {",
			"\t\t\t\t\t\t\tarchiveTrack(run.stateDir, params.taskId, mainRoot, task.baseline, task.branch);",
			"\t\t\t\t\t\t\tarchived = true;",
			"\t\t\t\t\t\t} else {",
			"\t\t\t\t\t\t\tapplied = applyBringBack(mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: params.paths }).applied;",
			"\t\t\t\t\t\t}",
			"\t\t\t\t\t\t// The write landed, so the evidence says so; the prune",
			"\t\t\t\t\t\t// that follows is what a later call reads back.",
			"\t\t\t\t\t\tmarkBringBackWritten(run.stateDir, params.taskId, nowIso());",
			"\t\t\t\t\t\tlive.beat();",
			"\t\t\t\t\t\tpruneWorktree(mainRoot, spec);",
		].join("\n"),
		next: [
			"\t\t\t\t\t\tlive.beat();",
			"\t\t\t\t\t\tpruneWorktree(mainRoot, spec);",
			"\t\t\t\t\t\tif (params.paths.length === 0) {",
			"\t\t\t\t\t\t\tarchiveTrack(run.stateDir, params.taskId, mainRoot, task.baseline, task.branch);",
			"\t\t\t\t\t\t\tarchived = true;",
			"\t\t\t\t\t\t} else {",
			"\t\t\t\t\t\t\tapplied = applyBringBack(mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: params.paths }).applied;",
			"\t\t\t\t\t\t}",
			"\t\t\t\t\t\tmarkBringBackWritten(run.stateDir, params.taskId, nowIso());",
		].join("\n"),
		tests: ["wired.test.ts"],
		breaks: "the bring-back prunes the worktree and the branch before it writes the file set, so an interrupted attempt loses the content it never wrote",
	},
	{
		id: "bringback:archive-claimed-without-the-archive",
		invariant: "I12",
		subject: `${EXTENSION_DIR}/index.ts`,
		old: "\t\t\t\t\t\tarchived = params.paths.length === 0 && fs.existsSync(archiveDiffPathOf(run.stateDir, params.taskId));",
		next: "\t\t\t\t\t\tarchived = params.paths.length === 0;",
		tests: ["wired.test.ts"],
		breaks: "a resumed empty file set claims an archive that the interrupted attempt never wrote",
	},
	{
		id: "state:write-not-a-rename",
		invariant: "I11",
		subject: `${EXTENSION_DIR}/state.ts`,
		old: ["\tfs.writeFileSync(tmp, JSON.stringify(state, null, 2), \"utf8\");", "\tfs.renameSync(tmp, file);"].join("\n"),
		next: ["\tfs.writeFileSync(file, JSON.stringify(state, null, 2), \"utf8\");", "\tfs.rmSync(tmp, { force: true });"].join("\n"),
		tests: ["invariants.test.ts"],
		breaks: "the state write truncates the live file in place, so a reader can observe a half-written state",
	},
	{
		id: "join:timeout-not-validated",
		invariant: "J3",
		subject: `${EXTENSION_DIR}/join.ts`,
		old: "\tif (!Number.isFinite(wait.timeoutMs) || wait.timeoutMs < 1) {",
		next: "\tif (false) {",
		tests: ["join.test.ts"],
		breaks: "the join accepts a timeout it cannot honour and blocks past the deadline the caller believes it set",
	},

	// --- I1 and I5: the exactly-once identities ---
	{
		id: "record:request-map-check-dropped",
		invariant: "I1",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tif (Object.prototype.hasOwnProperty.call(state.requests, p.requestId)) {",
		next: "\tif (false) {",
		tests: ["ops.test.ts", "wired.test.ts"],
		breaks: "a recorded request id re-enters the queue, so one break point produces two entries",
	},
	{
		id: "queue:retrigger-allowed",
		invariant: "I5",
		subject: `${EXTENSION_DIR}/queue.ts`,
		old: [
			"\tif (entry.state === \"triggered\") {",
			"\t\tthrow new TaskQueueError(\"entry-already-triggered\", `entry ${entryId} already triggered; a break point triggers at most once`);",
			"\t}",
		].join("\n"),
		next: [
			"\tif (entry.state === \"triggered\" && false) {",
			"\t\tthrow new TaskQueueError(\"entry-already-triggered\", `entry ${entryId} already triggered; a break point triggers at most once`);",
			"\t}",
		].join("\n"),
		tests: ["queue.test.ts", "transitions.test.ts", "join.test.ts"],
		breaks: "a triggered entry triggers again, so one break point reaches the operator twice",
	},
	{
		id: "queue:request-order-dropped",
		invariant: "I2",
		subject: `${EXTENSION_DIR}/queue.ts`,
		old: [
			"\tfor (const e of entries) {",
			"\t\tif (e.taskId === entry.taskId && e.requestSeq < entry.requestSeq && isPending(e)) {",
			"\t\t\tthrow new TaskQueueError(",
			"\t\t\t\t\"entry-out-of-order\",",
			"\t\t\t\t`entry ${entryId} cannot trigger before ${e.entryId}: break points trigger in request order per task`,",
			"\t\t\t);",
			"\t\t}",
			"\t}",
		].join("\n"),
		next: "\t// the per-task request order is not enforced",
		tests: ["queue.test.ts", "join.test.ts"],
		breaks: "a later break point triggers before an earlier pending one of the same task",
	},
	{
		id: "close:triggered-identity-dropped",
		invariant: "I1",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tif (counts.pending !== 0 || counts.triggered !== counts.entries) {",
		next: "\tif (false) {",
		tests: ["invariants.test.ts"],
		breaks: "the close audit no longer requires every entry to have triggered exactly once",
	},

	// --- R13: one primary per state directory ---
	{
		id: "lock:beat-writes-nothing",
		invariant: "R13",
		subject: `${EXTENSION_DIR}/lock.ts`,
		old: "\t\tif (!held || held.pid !== owner.pid || held.startedAt !== owner.startedAt) return;",
		next: "\t\tif (true) return;",
		tests: ["lock.test.ts"],
		breaks: "the owner never refreshes its heartbeat, so a live long section loses its lock to the stale bound",
	},
	{
		id: "lock:dead-owner-never-broken",
		invariant: "R13",
		subject: `${EXTENSION_DIR}/lock.ts`,
		old: "\t\tif (!pidAlive(owner.pid)) return true;",
		next: "\t\tif (!pidAlive(owner.pid)) return false;",
		tests: ["lock.test.ts"],
		breaks: "a lock left by a killed writer is never broken, so an interrupted run deadlocks instead of resuming",
	},
	{
		id: "lock:async-body-accepted",
		invariant: "R13",
		subject: `${EXTENSION_DIR}/lock.ts`,
		old: "\tif (result instanceof Promise) {",
		next: "\tif (false) {",
		tests: ["lock.test.ts", "state.test.ts"],
		breaks: "an asynchronous critical section is accepted, so the lock is released at the body's first await",
	},

	// --- R12, R14, W1, T1, I8: the table, the lifecycle, and the gates ---
	{
		id: "transitions:verify-not-usable-row-dropped",
		invariant: "R12",
		subject: `${EXTENSION_DIR}/transitions.ts`,
		old: "\t{ from: \"active\", action: \"verify-not-usable\", to: \"active\" },",
		next: "\t// the not-usable audit has no row",
		tests: ["transitions.test.ts", "ops.test.ts"],
		breaks: "a not-usable audit is not a legal edge, so the task cannot return to the queue for another segment",
	},
	{
		id: "ops:audit-outcome-does-not-route",
		invariant: "T1",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tconst action = p.outcome === \"usable\" ? \"verify-usable\" : \"verify-not-usable\";",
		next: "\tconst action = \"verify-usable\";",
		tests: ["ops.test.ts", "lifecycle.test.ts"],
		breaks: "the audit's structural finding does not route the task, so a not-usable return terminates it",
	},
	{
		id: "ops:second-audit-of-the-same-break-point-allowed",
		invariant: "I8",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tif (task.verification?.entryId === last.entryId) {",
		next: "\tif (false) {",
		tests: ["ops.test.ts"],
		breaks: "the same terminal break point is audited repeatedly, so a re-queue can be skipped by re-auditing",
	},
	{
		id: "ops:worktree-inside-the-main-tree-allowed",
		invariant: "W1",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tif (workdir === main || workdir.startsWith(main + \"/\")) {",
		next: "\tif (false) {",
		tests: ["ops.test.ts"],
		breaks: "a worker worktree inside the main tree is registered, so a worker write can land in the main tree",
	},
	{
		id: "join:hold-never-reported",
		invariant: "J4",
		subject: `${EXTENSION_DIR}/join.ts`,
		old: [
			"function heldUnits(state: RunState, scan: ReadyScan): Array<{ task: TaskRecord; entry: QueueEntry }> {",
			"\tconst held: Array<{ task: TaskRecord; entry: QueueEntry }> = [];",
			"\tfor (const task of tasksInForkOrder(state)) {",
		].join("\n"),
		next: [
			"function heldUnits(state: RunState, scan: ReadyScan): Array<{ task: TaskRecord; entry: QueueEntry }> {",
			"\treturn [];",
			"\tconst held: Array<{ task: TaskRecord; entry: QueueEntry }> = [];",
			"\tfor (const task of tasksInForkOrder(state)) {",
		].join("\n"),
		tests: ["join.test.ts", "pool-join.test.ts"],
		breaks: "the undecided break point (or the batch) is never reported as a hold, so a second payload is delivered beside one already waiting on the operator",
	},
	{
		id: "bringback:retired-replay-refused",
		invariant: "I13",
		subject: `${EXTENSION_DIR}/ops.ts`,
		old: "\tif (task.phase === \"retired\") {",
		next: "\tif (false) {",
		tests: ["transitions.test.ts", "ops.test.ts"],
		breaks: "a bring-back replay on a retired task is a gate error, so an interrupted close never completes",
	},
];

/** The invariants the catalog covers, in the order the rows name them. */
export function coveredInvariants(): string[] {
	const seen: string[] = [];
	for (const m of MUTATIONS) if (!seen.includes(m.invariant)) seen.push(m.invariant);
	return seen;
}
