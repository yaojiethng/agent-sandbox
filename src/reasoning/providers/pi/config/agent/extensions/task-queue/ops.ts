/**
 * The operations: every state transition the primary can request, with the
 * contract gates. Operations are pure: they take a run state and return the
 * next run state plus journal events. Persistence is applied by the Run
 * facade, so every gate and every invariant is unit-testable without I/O.
 *
 * Gate map:
 *   joinOp     - the join: record, schedule, and trigger as one derivation
 *                (I11), so it holds every gate the three ops hold and
 *                adds nothing of its own
 *   joinAllOp  - the same join across a whole pool of tasks, under one
 *                derivation; a fold, not a new action
 *   recordOp   - referential integrity (I3), exactly-once request ids (I1),
 *                one pending break point per task (serialized segments)
 *   scheduleOp - legal transitions (I4)
 *   triggerOp  - legal transitions (I4), single trigger (I5), request order
 *                per task (I2), dequeue-time referential integrity (I3)
 *   verifyOp   - verification only at the worker's terminal request (I8),
 *                one audit per terminal break point
 *   requeueOp  - a re-queue only from active state, on the head the route
 *                actually put the worktree at
 *   proposalOp - the proposal distills terminated state (I9 ordering)
 *   bringBackOp - the bring-back only from terminated state, over a file
 *                set the proposal contains (I7, I9)
 *   closeOp    - exactly-once identities over the whole run (I1, I5)
 *
 * Every phase gate below asks the transition table whether the action is
 * legal from the task's phase, so the gates and the table cannot drift.
 */

import { TaskQueueError } from "./errors.ts";
import {
	type QueueEntry,
	entriesForTask,
	entryIdOf,
	getEntry,
	pendingForTask,
	previousSeq,
	transitionSchedule,
	transitionTrigger,
	validateBirth,
} from "./queue.ts";

import {
	type BringBack,
	type Proposal,
	type TaskRecord,
	type VerificationOutcome,
	assertFileSet,
	canBringBack,
	canClose,
	canPropose,
	canRecord,
	canRequeue,
	canVerify,
	phaseRejection,
	segmentBaseOf,
} from "./tasks.ts";
import { nextPhase, type RequeueRoute } from "./transitions.ts";
import type { IntegrityCounts, JournalEvent } from "./record.ts";
import type { RunState } from "./state.ts";
import type { WorkerStatus } from "./protocol.ts";

export interface OpResult<D = undefined> {
	state: RunState;
	events: JournalEvent[];
	data: D;
	/**
	 * A step that runs under the lock once the state write and the journal
	 * append are done. A transition that leaves evidence behind for its own
	 * recovery drops it here, so the evidence never outlives the record and
	 * never disappears before it.
	 */
	commit?: () => void;
}

export function nowIso(): string {
	return new Date().toISOString();
}

export function integrityCounts(state: RunState): IntegrityCounts {
	return {
		tasks: Object.keys(state.tasks).length,
		entries: state.entries.length,
		triggered: state.entries.filter((e) => e.state === "triggered").length,
		pending: state.entries.filter((e) => e.state !== "triggered").length,
		requests: Object.keys(state.requests).length,
	};
}

function requireOpen(state: RunState): void {
	if (state.closed) {
		throw new TaskQueueError("run-closed", "the run is closed; no further transitions are legal");
	}
}

function requireTask(state: RunState, taskId: string): TaskRecord {
	const task = state.tasks[taskId];
	if (!task) {
		throw new TaskQueueError("task-unknown", `no task with id ${taskId}`);
	}
	return task;
}

export interface ForkParams {
	taskId: string;
	workerId?: string;
	workdir: string;
	branch: string;
	baseline: string;
	mainRoot: string;
}

export function forkOp(state: RunState, p: ForkParams, at: string): OpResult<TaskRecord> {
	requireOpen(state);
	if (state.tasks[p.taskId]) {
		throw new TaskQueueError("task-duplicate", `task ${p.taskId} is already forked`);
	}
	const main = pathNormalize(p.mainRoot);
	const workdir = pathNormalize(p.workdir);
	if (workdir === main || workdir.startsWith(main + "/")) {
		throw new TaskQueueError(
			"task-workdir-inside-main",
			`task workdir ${workdir} must not be the main tree or inside it: a worker never writes in the main tree`,
		);
	}
	const task: TaskRecord = {
		taskId: p.taskId,
		workerId: p.workerId ?? p.taskId,
		workdir,
		branch: p.branch,
		baseline: p.baseline,
		phase: "forked",
		workerDone: false,
		lastSegmentHead: p.baseline,
		forkedAt: at,
	};
	const tasks = { ...state.tasks, [p.taskId]: task };
	const event: JournalEvent = {
		type: "task:fork",
		at,
		taskId: task.taskId,
		workerId: task.workerId,
		workdir: task.workdir,
		branch: task.branch,
		baseline: task.baseline,
	};
	return { state: { ...state, tasks }, events: [event], data: task };
}

export interface RecordParams {
	taskId: string;
	requestId: string;
	status: WorkerStatus;
	/** The workdir the request document came from; must equal the task's. */
	workdir: string;
}

export function recordOp(state: RunState, p: RecordParams, at: string): OpResult<{ entry: QueueEntry; task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	if (!canRecord(task)) {
		throw new TaskQueueError("task-phase", phaseRejection(task, "join", "a join"));
	}
	if (pathNormalize(p.workdir) !== task.workdir) {
		throw new TaskQueueError(
			"request-path-mismatch",
			`the request document must come from the task's own worktree ${task.workdir}, not ${p.workdir}`,
		);
	}
	if (Object.prototype.hasOwnProperty.call(state.requests, p.requestId)) {
		throw new TaskQueueError(
			"request-duplicate",
			`request ${p.requestId} is already recorded as ${state.requests[p.requestId]}; a break point re-enters exactly once`,
		);
	}
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError(
			"request-pending-task",
			`task ${p.taskId} already has a pending break point (${pending[0].entryId}); clear it before the next segment`,
		);
	}
	const seq = previousSeq(state.entries, p.taskId) + 1;
	const entry: QueueEntry = {
		entryId: entryIdOf(p.taskId, seq),
		taskId: p.taskId,
		workerId: task.workerId,
		workdir: task.workdir,
		requestId: p.requestId,
		requestSeq: seq,
		state: "requested",
	};
	validateBirth(state.entries, entry);
	// A re-queue reopens the worker after a not-usable audit: the task is
	// active again, and its next break point is a new entry.
	const nextTask: TaskRecord = {
		...task,
		workerDone: p.status === "done",
		phase: nextPhase(task.phase, "join"),
	};
	const next: RunState = {
		...state,
		tasks: { ...state.tasks, [p.taskId]: nextTask },
		entries: [...state.entries, entry],
		requests: { ...state.requests, [p.requestId]: entry.entryId },
	};
	const event: JournalEvent = {
		type: "request:record",
		at,
		entryId: entry.entryId,
		taskId: p.taskId,
		requestId: p.requestId,
		status: p.status,
	};
	return { state: next, events: [event], data: { entry, task: nextTask } };
}

export function scheduleOp(state: RunState, entryId: string, at: string): OpResult<{ entry: QueueEntry }> {
	requireOpen(state);
	const t = transitionSchedule(state.entries, entryId);
	const event: JournalEvent = { type: "entry:schedule", at, entryId, taskId: t.entry.taskId };
	return { state: { ...state, entries: t.entries }, events: [event], data: { entry: t.entry } };
}

export interface TriggerParams {
	entryId: string;
	/** The worker branch head at trigger time, for the segment record. */
	head: string;
	changed: number;
}

export function triggerOp(state: RunState, p: TriggerParams, at: string): OpResult<{ entry: QueueEntry; task: TaskRecord }> {
	requireOpen(state);
	const t = transitionTrigger(state.entries, p.entryId);
	const task = requireTask(state, t.entry.taskId);
	if (t.entry.workerId !== task.workerId || t.entry.workdir !== task.workdir) {
		throw new TaskQueueError(
			"entry-ref-mismatch",
			`entry ${t.entry.entryId} references ${t.entry.workerId}/${t.entry.workdir}, but task ${task.taskId} is ${task.workerId}/${task.workdir}`,
		);
	}
	const nextTask: TaskRecord = { ...task, lastSegmentHead: p.head };
	const event: JournalEvent = {
		type: "entry:trigger",
		at,
		entryId: t.entry.entryId,
		taskId: t.entry.taskId,
		head: p.head,
		changed: p.changed,
	};
	return {
		state: { ...state, entries: t.entries, tasks: { ...state.tasks, [t.entry.taskId]: nextTask } },
		events: [event],
		data: { entry: t.entry, task: nextTask },
	};
}

export interface VerifyParams {
	taskId: string;
	/** The audit's structural finding about the worker's return. */
	outcome: VerificationOutcome;
	notes: string;
}

/**
 * The termination audit, recorded on the task. The audit is the primary's
 * own run - read the diff, run the brief's checks, confirm the report
 * landed - and this op records its finding (I8). Usable terminates the
 * task; not-usable leaves it in the queue, because the only thing left to
 * decide is another segment. One audit per terminal break point: a second
 * recording of the same entry is refused, so a re-queue cannot be skipped
 * by re-auditing what was already judged.
 */
export function verifyOp(state: RunState, p: VerifyParams, at: string): OpResult<{ task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	const action = p.outcome === "usable" ? "verify-usable" : "verify-not-usable";
	if (!canVerify(task)) {
		throw new TaskQueueError("verify-gate", phaseRejection(task, "verify-usable", "the final verification"));
	}
	const entries = entriesForTask(state.entries, p.taskId);
	if (entries.length === 0) {
		throw new TaskQueueError("verify-gate", `task ${p.taskId} has no break point; a task verifies only at its terminal break point`);
	}
	if (!task.workerDone) {
		throw new TaskQueueError(
			"verify-gate",
			`task ${p.taskId} has not requested its terminal break point; final verification runs only after the worker requests it`,
		);
	}
	const last = entries[entries.length - 1];
	if (last.state !== "triggered") {
		throw new TaskQueueError(
			"verify-gate",
			`task ${p.taskId} is mid-segment: its latest break point ${last.entryId} is ${last.state}, not triggered`,
		);
	}
	if (task.verification?.entryId === last.entryId) {
		throw new TaskQueueError(
			"verify-gate",
			`task ${p.taskId} already has a ${task.verification.outcome} audit of break point ${last.entryId}; a not-usable audit is answered by a re-queue and a new segment, not by a second audit`,
		);
	}
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError("verify-gate", `task ${p.taskId} has a pending break point; verification never runs mid-segment`);
	}
	const verification = { outcome: p.outcome, notes: p.notes, at, entryId: last.entryId };
	const nextTask: TaskRecord = {
		...task,
		phase: nextPhase(task.phase, action),
		verification,
	};
	const event: JournalEvent = { type: "verify", at, taskId: p.taskId, outcome: p.outcome, entryId: last.entryId, notes: p.notes };
	return { state: { ...state, tasks: { ...state.tasks, [p.taskId]: nextTask } }, events: [event], data: { task: nextTask } };
}

export interface ProposalParams {
	taskId: string;
	description: string;
	paths: string[];
}

export function proposalOp(state: RunState, p: ProposalParams, at: string): OpResult<{ task: TaskRecord; proposal: Proposal }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	if (!canPropose(task)) {
		throw new TaskQueueError("proposal-gate", phaseRejection(task, "propose", "the write-back proposal"));
	}
	const proposal: Proposal = { paths: [...p.paths], description: p.description, at };
	const nextTask: TaskRecord = { ...task, proposal };
	const event: JournalEvent = {
		type: "proposal",
		at,
		taskId: p.taskId,
		paths: proposal.paths,
		description: proposal.description,
	};
	return { state: { ...state, tasks: { ...state.tasks, [p.taskId]: nextTask } }, events: [event], data: { task: nextTask, proposal } };
}

export interface BringBackParams {
	taskId: string;
	/** The file set the primary named: a subset of the proposal, possibly empty. */
	paths: string[];
	/** The paths the apply actually wrote. Filled by the caller. */
	applied: string[];
	/** True when the branch diff was archived because nothing was written back. */
	archived: boolean;
	/** The worktree the bring-back removed and the branch it pruned. */
	removedWorktree: string;
	prunedBranch: string;
	/**
	 * True when this record infers the write instead of performing it: the
	 * worktree was already gone, so the write demonstrably happened in an
	 * earlier attempt. A reader tells an inferred record from a performed
	 * one by this flag.
	 */
	resumed: boolean;
}

/**
 * The bring-back: one transition that writes a file set into the main tree
 * and ends the task. The file set is the verdict (I7): a named path the
 * proposal does not contain is refused, and the empty set is legal - it
 * writes nothing and still removes the worktree and the branch. The
 * caller asks whether the prune will be refused before it writes anything,
 * then applies, then prunes, then calls this op, so a refused apply or
 * prune leaves the state and the journal untouched and a re-run completes
 * the bring-back (I12).
 */
export function bringBackOp(state: RunState, p: BringBackParams, at: string): OpResult<{ task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	if (task.phase === "retired") {
		// Already brought back: the call reports the recorded result and
		// changes nothing, so a re-run after a committed bring-back is a
		// success rather than a gate error (I13). The caller has already
		// finished any work the record is missing, such as the removal of
		// a worktree a record-first state still holds.
		return { state, events: [], data: { task } };
	}
	if (!canBringBack(task)) {
		throw new TaskQueueError("bring-back-gate", phaseRejection(task, "bring-back", "the bring-back"));
	}
	if (!task.proposal) {
		throw new TaskQueueError("bring-back-gate", `task ${p.taskId} has no write-back proposal; build one before the bring-back`);
	}
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError("bring-back-gate", `task ${p.taskId} has a pending break point; the file set is decided only at the terminal hold`);
	}
	try {
		assertFileSet(p.paths, task.proposal);
	} catch (err) {
		throw new TaskQueueError("file-set-invalid", String(err instanceof Error ? err.message : err));
	}
	const bringBack: BringBack = { paths: [...p.paths], archived: p.archived, at };
	const nextTask: TaskRecord = { ...task, phase: "retired", bringBack };
	const event: JournalEvent = {
		type: "bringback",
		at,
		taskId: p.taskId,
		paths: bringBack.paths,
		applied: p.applied,
		archived: p.archived,
		removedWorktree: p.removedWorktree,
		prunedBranch: p.prunedBranch,
		resumed: p.resumed,
	};
	return { state: { ...state, tasks: { ...state.tasks, [p.taskId]: nextTask } }, events: [event], data: { task: nextTask } };
}

export interface RequeueParams {
	taskId: string;
	route: RequeueRoute;
	/** The head the route put the worktree at: lastSegmentHead or the baseline. */
	head: string;
}

/**
 * The re-queue: the answer to a not-usable audit. The two routes differ in
 * what they do to the worktree, and the git work happens before this op,
 * so the head the caller reports is the head the worktree is actually at -
 * a rollback target the state does not name is refused rather than
 * recorded. The queue entries stay: a re-queue is another segment, not a
 * second run, so the exactly-once identities of the entries hold (I1).
 */
export function requeueOp(state: RunState, p: RequeueParams, at: string): OpResult<{ task: TaskRecord; requestSeq: number }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	const action = p.route === "in-place" ? "requeue-in-place" : "requeue-fresh";
	if (!canRequeue(task)) {
		throw new TaskQueueError("requeue-gate", phaseRejection(task, action, "a re-queue"));
	}
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError("requeue-gate", `task ${p.taskId} has a pending break point; a re-queue runs between segments`);
	}
	const expected = p.route === "in-place" ? task.lastSegmentHead : task.baseline;
	if (p.head !== expected) {
		throw new TaskQueueError(
			"requeue-gate",
			`the ${p.route} re-queue of task ${p.taskId} must leave the worktree at ${expected}, not ${p.head}`,
		);
	}
	// The worker is no longer done: it has another segment to run, and the
	// next request clears the hold the audit left behind. The entry this
	// re-queue answers is recorded with it, so the join's hold stops
	// naming the re-queue the primary has already made. A re-queue runs
	// only from `active`, and `active` is entered by a join, so the task
	// holds that entry.
	const taskEntries = entriesForTask(state.entries, p.taskId);
	const lastEntryId = taskEntries[taskEntries.length - 1].entryId;
	const nextTask: TaskRecord = { ...task, phase: nextPhase(task.phase, action), workerDone: false, lastSegmentHead: p.head, requeuedFromEntryId: lastEntryId };
	const event: JournalEvent = {
		type: "task:requeue",
		at,
		taskId: p.taskId,
		route: p.route,
		workdir: task.workdir,
		branch: task.branch,
		from: task.lastSegmentHead,
		to: p.head,
		entryId: lastEntryId,
	};
	return {
		state: { ...state, tasks: { ...state.tasks, [p.taskId]: nextTask } },
		events: [event],
		data: { task: nextTask, requestSeq: previousSeq(state.entries, p.taskId) },
	};
}

export function closeOp(state: RunState, at: string): OpResult<{ counts: IntegrityCounts }> {
	requireOpen(state);
	const unclosed = Object.values(state.tasks).filter((t) => !canClose(t));
	if (unclosed.length > 0) {
		throw new TaskQueueError(
			"close-gate",
			`cannot close with ${unclosed.length} unclosed task(s): ${unclosed.map((t) => t.taskId).join(", ")}`,
		);
	}
	const counts = integrityCounts(state);
	// Exactly-once identities: every recorded request produced exactly one
	// entry, and every entry triggered exactly once. Structural by
	// construction; checked again here as the close audit.
	if (counts.requests !== counts.entries) {
		throw new TaskQueueError("close-gate", `close audit failed: ${counts.requests} requests but ${counts.entries} entries`);
	}
	if (counts.pending !== 0 || counts.triggered !== counts.entries) {
		throw new TaskQueueError("close-gate", `close audit failed: ${counts.pending} pending, ${counts.triggered}/${counts.entries} triggered`);
	}
	const event: JournalEvent = { type: "run:close", at, ...counts };
	return { state: { ...state, closed: true }, events: [event], data: { counts } };
}

function pathNormalize(p: string): string {
	return p.replace(/\/+$/, "");
}

// ---------------------------------------------------------------------------
// The join
// ---------------------------------------------------------------------------

export interface JoinParams {
	taskId: string;
	requestId: string;
	status: WorkerStatus;
	/** The worker branch head at delivery time, for the segment record. */
	head: string;
	changed: number;
	/**
	 * The head the payload's segment was measured from, read by the caller
	 * before it applied the lock. The op compares it against the state it
	 * loads, so a state that moved between the two is a contention and the
	 * join re-scans; a direct operation call measures no segment and leaves
	 * it out.
	 */
	baseHead?: string;
}

export interface Joined {
	entry: QueueEntry;
	task: TaskRecord;
	/** True when this call enqueued the request; false when it healed a queued entry. */
	recorded: boolean;
}

/**
 * A break point that moved under a delivery. The state the caller scanned
 * is the state another join advanced while the caller was reading git, so
 * the transition is a no-op for this call: it reports the contention and
 * the join re-scans. The gate error it wraps stays the diagnosis.
 */
const CONTENDED = new Set([
	"request-duplicate",
	"request-pending-task",
	"entry-unknown",
	"entry-not-requested",
	"entry-not-scheduled",
	"entry-already-triggered",
	"entry-out-of-order",
]);

function asContention<T>(fn: () => T): T {
	try {
		return fn();
	} catch (err) {
		if (err instanceof TaskQueueError && CONTENDED.has(err.code)) {
			throw new TaskQueueError("join-contended", `the break point moved under this join: ${err.message}`);
		}
		throw err;
	}
}

/**
 * The join transition: record, schedule, and trigger as one derivation
 * from one state to the next. The join tool applies it as one serialized
 * read-modify-write, so one call is one atomic write (I11), the queue
 * never rests in the requested or scheduled state, and a break point
 * enters and leaves the pending set once (I1, I5).
 *
 * A request another join already recorded is not a delivery: the call
 * reports the contention instead of triggering the entry twice. A request
 * the queue already holds - a state written before the join existed - is
 * healed forward, which is the same transition with the record step
 * already done.
 */
export function joinOp(state: RunState, p: JoinParams, at: string): OpResult<Joined> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	// The segment the operator judges, the uncommitted paths the payload
	// names, and the head this transition records must be one read. The
	// caller measured the segment from the head the state named before it
	// took the lock; a state that moved in between makes all three stale,
	// so the delivery is refused and the join re-scans.
	if (p.baseHead !== undefined && p.baseHead !== segmentBaseOf(task)) {
		throw new TaskQueueError(
			"join-contended",
			`task ${p.taskId} is at segment base ${segmentBaseOf(task)}, not ${p.baseHead}; another writer delivered a segment under this join`,
		);
	}
	const events: JournalEvent[] = [];
	const queuedId = state.requests[p.requestId];
	let next = state;
	let recorded = false;
	let entry: QueueEntry;
	if (queuedId === undefined) {
		const r = asContention(() =>
			recordOp(next, { taskId: p.taskId, requestId: p.requestId, status: p.status, workdir: task.workdir }, at),
		);
		next = r.state;
		events.push(...r.events);
		entry = r.data.entry;
		recorded = true;
	} else {
		if (!canRecord(task)) {
			throw new TaskQueueError("task-phase", phaseRejection(task, "join", "a join"));
		}
		const found = getEntry(next.entries, queuedId);
		if (!found || found.taskId !== p.taskId) {
			throw new TaskQueueError(
				"state-corrupt",
				`request ${p.requestId} is recorded as ${queuedId}, which is not an entry of task ${p.taskId}`,
			);
		}
		if (found.state === "triggered") {
			throw new TaskQueueError(
				"join-contended",
				`entry ${found.entryId} already triggered; another join delivered this break point`,
			);
		}
		entry = found;
	}
	const s = asContention(() => scheduleOp(next, entry.entryId, at));
	next = s.state;
	events.push(...s.events);
	const t = asContention(() => triggerOp(next, { entryId: entry.entryId, head: p.head, changed: p.changed }, at));
	next = t.state;
	events.push(...t.events);
	return { state: next, events, data: { entry: t.data.entry, task: t.data.task, recorded } };
}

export interface JoinedBatch {
	/** One delivery per task of the pool, in the order the pool named them. */
	joins: Joined[];
}

/**
 * The pool join: the join transition applied to every task of the pool in
 * one derivation, so the whole batch records, schedules, and triggers in
 * the one load-derive-save the caller holds the lock for (I11).
 *
 * A pool is N joins of the one action, not a new action: the table
 * carries no pool row, and every gate a single join holds is the gate
 * this fold holds, task by task. A task of the pool that the fold refuses
 * stops the whole fold, and a derivation that throws is never saved, so a
 * pool is delivered whole or not at all - never partly delivered with a
 * task's break point left unaccounted for (I1).
 *
 * The refusal is the one the single join raises, contention included, so
 * the caller re-scans the whole pool on a contention rather than the
 * tasks that happened to be applied.
 */
export function joinAllOp(state: RunState, ps: JoinParams[], at: string): OpResult<JoinedBatch> {
	if (ps.length === 0) {
		throw new TaskQueueError("request-invalid", "a pool join names no task; name the tasks to join");
	}
	const events: JournalEvent[] = [];
	const joins: Joined[] = [];
	let next = state;
	for (const p of ps) {
		const r = joinOp(next, p, at);
		next = r.state;
		events.push(...r.events);
		joins.push(r.data);
	}
	return { state: next, events, data: { joins } };
}