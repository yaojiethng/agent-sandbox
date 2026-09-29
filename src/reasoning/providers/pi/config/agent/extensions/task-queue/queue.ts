/**
 * The task-queue: a queue of requested break points with an exactly-once
 * state machine.
 *
 * Data structure
 * --------------
 * The queue is a flat, append-only list of entries. An entry is one break
 * point the worker requested. An entry never changes except for its state
 * field; its references (task, worker, workdir, requestId, requestSeq) are
 * fixed at birth. This makes referential integrity checkable: the entry the
 * primary dequeues carries the same references as the entry it enqueued.
 *
 * State machine
 * -------------
 * Every entry transitions request -> scheduled -> triggered, in that order,
 * and stops at triggered. Only the primary performs transitions: it records
 * a worker's request (birth, state "requested"), schedules the entry, and
 * triggers it. The triggered state is the dequeue: the primary handles the
 * break point exactly when the entry triggers.
 *
 * The queue does not mark a break point's kind. A final break point and a
 * regular break point are the same kind of entry. The primary reads the
 * worker's request document when it handles the triggered entry.
 *
 * Re-queue
 * --------
 * Re-queue means the next segment's break point enters the queue as a new
 * entry. Each worker request carries a request id; the queue records every
 * request id exactly once, so a re-enqueued break point re-enters exactly
 * once.
 *
 * Ordering
 * --------
 * Entries trigger in request order per task: the queue rejects a trigger
 * when an earlier entry of the same task is still pending. Cross-task order
 * is the primary's choice and the queue does not constrain it.
 */

import { TaskQueueError } from "./errors.ts";

export type EntryState = "requested" | "scheduled" | "triggered";

export interface QueueEntry {
	/** Unique entry id: "<taskId>#<requestSeq>". */
	entryId: string;
	taskId: string;
	workerId: string;
	/** Absolute path of the worker's worktree. Fixed at birth. */
	workdir: string;
	/** The worker's request document id. Recorded exactly once. */
	requestId: string;
	/** Per-task request order, 1-based. Fixed at birth. */
	requestSeq: number;
	state: EntryState;
}

export function entryIdOf(taskId: string, requestSeq: number): string {
	return `${taskId}#${requestSeq}`;
}

export function getEntry(entries: readonly QueueEntry[], entryId: string): QueueEntry | undefined {
	return entries.find((e) => e.entryId === entryId);
}

export function entriesForTask(entries: readonly QueueEntry[], taskId: string): QueueEntry[] {
	return entries.filter((e) => e.taskId === taskId);
}

/** Entries of one task that have not reached the terminal state. */
export function pendingForTask(entries: readonly QueueEntry[], taskId: string): QueueEntry[] {
	return entries.filter((e) => e.taskId === taskId && e.state !== "triggered");
}

export function isPending(entry: QueueEntry): boolean {
	return entry.state !== "triggered";
}

export function previousSeq(entries: readonly QueueEntry[], taskId: string): number {
	return entriesForTask(entries, taskId).reduce((m, e) => Math.max(m, e.requestSeq), 0);
}

/**
 * Birth validation: the entry must be unique, its request id must be
 * unrecorded, and its request sequence must continue the task's sequence.
 * This is the exactly-once gate for enqueue and re-enqueue (I1).
 */
export function validateBirth(entries: readonly QueueEntry[], entry: QueueEntry): void {
	if (!entry.entryId || !entry.taskId || !entry.workerId || !entry.workdir || !entry.requestId) {
		throw new TaskQueueError("request-invalid", `entry ${entry.entryId} has an empty field`);
	}
	if (!Number.isInteger(entry.requestSeq) || entry.requestSeq < 1) {
		throw new TaskQueueError("request-invalid", `entry ${entry.entryId} has an invalid requestSeq`);
	}
	if (getEntry(entries, entry.entryId)) {
		throw new TaskQueueError("request-duplicate", `entry ${entry.entryId} already exists`);
	}
	for (const e of entries) {
		if (e.requestId === entry.requestId) {
			throw new TaskQueueError(
				"request-duplicate",
				`request ${entry.requestId} is already recorded as ${e.entryId}`,
			);
		}
	}
	const prev = previousSeq(entries, entry.taskId);
	if (entry.requestSeq !== prev + 1) {
		throw new TaskQueueError(
			"request-invalid",
			`entry ${entry.entryId} breaks the request sequence for task ${entry.taskId}: expected ${prev + 1}`,
		);
	}
}

export interface Transition {
	entries: QueueEntry[];
	entry: QueueEntry;
}

/**
 * Transition request -> scheduled. The entry must be in the "requested"
 * state: an already scheduled (but not yet triggered) entry cannot be
 * re-scheduled (I4), and an already triggered entry cannot move backward
 * (I4).
 */
export function transitionSchedule(entries: readonly QueueEntry[], entryId: string): Transition {
	const entry = getEntry(entries, entryId);
	if (!entry) {
		throw new TaskQueueError("entry-unknown", `no entry with id ${entryId}`);
	}
	if (entry.state !== "requested") {
		throw new TaskQueueError(
			"entry-not-requested",
			`entry ${entryId} is ${entry.state}, not requested; only a requested entry can be scheduled`,
		);
	}
	return replace(entries, entry, { ...entry, state: "scheduled" });
}

/**
 * Transition scheduled -> triggered. This is the dequeue-for-trigger: the
 * entry leaves the pending set exactly here, and only here. The entry must
 * have been scheduled first: triggering a break point the primary never
 * scheduled is an error (I4). An already triggered entry cannot trigger
 * again (I5).
 *
 * Ordering: an entry may trigger only when no earlier request of the same
 * task is still pending (I2).
 */
export function transitionTrigger(entries: readonly QueueEntry[], entryId: string): Transition {
	const entry = getEntry(entries, entryId);
	if (!entry) {
		throw new TaskQueueError("entry-unknown", `no entry with id ${entryId}`);
	}
	if (entry.state === "triggered") {
		throw new TaskQueueError("entry-already-triggered", `entry ${entryId} already triggered; a break point triggers at most once`);
	}
	if (entry.state !== "scheduled") {
		throw new TaskQueueError(
			"entry-not-scheduled",
			`entry ${entryId} is ${entry.state}, not scheduled; only a scheduled break point can trigger`,
		);
	}
	for (const e of entries) {
		if (e.taskId === entry.taskId && e.requestSeq < entry.requestSeq && isPending(e)) {
			throw new TaskQueueError(
				"entry-out-of-order",
				`entry ${entryId} cannot trigger before ${e.entryId}: break points trigger in request order per task`,
			);
		}
	}
	return replace(entries, entry, { ...entry, state: "triggered" });
}

/** Replace one entry, returning a new immutable list with the entry replaced. */
function replace(entries: readonly QueueEntry[], entry: QueueEntry, next: QueueEntry): Transition {
	return { entries: entries.map((e) => (e.entryId === entry.entryId ? next : e)), entry: next };
}