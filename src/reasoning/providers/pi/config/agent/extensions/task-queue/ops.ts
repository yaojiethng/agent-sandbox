/**
 * The operations: every state transition the primary can request, with the
 * contract gates. Operations are pure: they take a run state and return the
 * next run state plus journal events. Persistence is applied by the Run
 * facade, so every gate and every invariant is unit-testable without I/O.
 *
 * Gate map:
 *   recordOp   - referential integrity (I3), exactly-once request ids (I1),
 *                one pending break point per task (serialized segments)
 *   scheduleOp - legal transitions (I4)
 *   triggerOp  - legal transitions (I4), single trigger (I5), request order
 *                per task (I2), dequeue-time referential integrity (I3)
 *   verifyOp   - verification only at the worker's terminal request (I8)
 *   mergeOp    - merge only after verification (I9), verdict scope (I7)
 *   retireOp   - only a decided task retires; close then verifies the git
 *                tree is clean (I10)
 *   closeOp    - exactly-once identities over the whole run (I1, I5)
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
	type Proposal,
	type TaskRecord,
	type Verdict,
	assertVerdict,
	canMerge,
	canPropose,
	canRecord,
	canRetire,
	canVerify,
} from "./tasks.ts";
import type { IntegrityCounts, JournalEvent } from "./record.ts";
import type { RunState } from "./state.ts";
import type { WorkerStatus } from "./protocol.ts";

export interface OpResult<D = undefined> {
	state: RunState;
	events: JournalEvent[];
	data: D;
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
		throw new TaskQueueError(
			"task-phase",
			`task ${p.taskId} is ${task.phase}; a task only accepts break points while forked, active, or failed`,
		);
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
	// A repair segment reopens a failed task; the failed state names the
	// last verification, not ongoing work.
	const nextTask: TaskRecord = {
		...task,
		workerDone: p.status === "done",
		phase: task.phase === "forked" || task.phase === "failed" ? "active" : task.phase,
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
	outcome: "passed" | "failed";
	notes: string;
}

export function verifyOp(state: RunState, p: VerifyParams, at: string): OpResult<{ task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	if (!canVerify(task)) {
		throw new TaskQueueError(
			"verify-gate",
			`task ${p.taskId} is ${task.phase}; final verification runs only from the active or failed state`,
		);
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
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError("verify-gate", `task ${p.taskId} has a pending break point; verification never runs mid-segment`);
	}
	const verification = { outcome: p.outcome, notes: p.notes, at };
	const nextTask: TaskRecord = {
		...task,
		phase: p.outcome === "passed" ? "verified" : "failed",
		verification,
	};
	const event: JournalEvent = { type: "verify", at, taskId: p.taskId, outcome: p.outcome, notes: p.notes };
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
		throw new TaskQueueError(
			"proposal-gate",
			`task ${p.taskId} is ${task.phase}; the write-back proposal distills verified state`,
		);
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

export interface MergeParams {
	taskId: string;
	verdict: Verdict;
	/** The paths actually applied by the merge. Filled by the caller. */
	applied: string[];
	archived: boolean;
}

export function mergeOp(state: RunState, p: MergeParams, at: string): OpResult<{ task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, p.taskId);
	if (!canMerge(task)) {
		throw new TaskQueueError("merge-gate", `task ${p.taskId} is ${task.phase}; a merge runs only after its final verification`);
	}
	if (!task.proposal) {
		throw new TaskQueueError("merge-gate", `task ${p.taskId} has no write-back proposal; build one before merging`);
	}
	const pending = pendingForTask(state.entries, p.taskId);
	if (pending.length > 0) {
		throw new TaskQueueError("merge-gate", `task ${p.taskId} has a pending break point; the final verdict is decided only at the terminal hold`);
	}
	const verdict = p.verdict;
	try {
		assertVerdict(verdict, task.proposal);
	} catch (err) {
		throw new TaskQueueError("verdict-invalid", String(err instanceof Error ? err.message : err));
	}
	const nextTask: TaskRecord = {
		...task,
		phase: verdict.scope === "none" ? "discarded" : "merged",
		verdict,
	};
	const event: JournalEvent = {
		type: "merge",
		at,
		taskId: p.taskId,
		scope: verdict.scope,
		applied: p.applied,
		archived: p.archived,
	};
	return { state: { ...state, tasks: { ...state.tasks, [p.taskId]: nextTask } }, events: [event], data: { task: nextTask } };
}

export function retireOp(state: RunState, taskId: string, at: string): OpResult<{ task: TaskRecord }> {
	requireOpen(state);
	const task = requireTask(state, taskId);
	if (!canRetire(task)) {
		throw new TaskQueueError(
			"retire-gate",
			`task ${taskId} is ${task.phase}; only a merged or discarded task retires`,
		);
	}
	const nextTask: TaskRecord = { ...task, phase: "retired" };
	const event: JournalEvent = {
		type: "retire",
		at,
		taskId,
		removedWorktree: task.workdir,
		prunedBranch: task.branch,
	};
	return { state: { ...state, tasks: { ...state.tasks, [taskId]: nextTask } }, events: [event], data: { task: nextTask } };
}

export function closeOp(state: RunState, at: string): OpResult<{ counts: IntegrityCounts }> {
	requireOpen(state);
	const unretired = Object.values(state.tasks).filter((t) => t.phase !== "retired");
	if (unretired.length > 0) {
		throw new TaskQueueError(
			"close-gate",
			`cannot close with ${unretired.length} unretired task(s): ${unretired.map((t) => t.taskId).join(", ")}`,
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