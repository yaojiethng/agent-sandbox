/**
 * The task record: the primary's bookkeeping for one fork/join/re-queue
 * track. The queue entries never reference this record, and the record
 * never marks a queue entry's kind. The record carries what the queue must
 * not: the worker's disposition (running or done), the verification
 * record, the write-back proposal, and the file set a bring-back wrote.
 *
 * The four phases carry no value. A task is forked, it is active, it is
 * terminated, and it is retired; nothing here says whether the work was
 * good. Usable and not-usable are the verification audit's structural
 * finding about the return, and the file set a bring-back writes is the
 * primary's decision, not a grade.
 */

import { canTask, legalFrom, type TaskAction } from "./transitions.ts";

/**
 * forked: the worktree is cut and no break point is recorded.
 * active: at least one break point is delivered and none is pending.
 * terminated: the terminal break point is delivered, the verification
 *   audit is recorded, and the audit judged the return usable.
 * retired: the bring-back wrote its file set and the worktree and branch
 *   are gone.
 */
export type TaskPhase = "forked" | "active" | "terminated" | "retired";

export type WorkerStatus = "running" | "done";

/** What the termination audit found about the worker's return. */
export type VerificationOutcome = "usable" | "not-usable";

export interface Proposal {
	/** Changed paths of the worker branch offered for write-back. */
	paths: string[];
	/** The primary's distillation, the unit the operator judges. */
	description: string;
	at: string;
}

/**
 * The termination audit, recorded on the task. `entryId` is the terminal
 * break point the audit decided, so a second audit of the same break point
 * is refused and an audit left over from an earlier segment does not
 * describe the live one.
 */
export interface Verification {
	outcome: VerificationOutcome;
	notes: string;
	at: string;
	entryId: string;
}

/** What a bring-back wrote back, and what it left in the run record. */
export interface BringBack {
	/** The file set the primary named; possibly empty. */
	paths: string[];
	/** True when the branch diff was archived because nothing was written back. */
	archived: boolean;
	at: string;
}

export interface TaskRecord {
	taskId: string;
	workerId: string;
	/** Absolute path of the worker's worktree. Fixed at fork. */
	workdir: string;
	branch: string;
	baseline: string;
	phase: TaskPhase;
	/** True when the worker's latest request declared the terminal break point. */
	workerDone: boolean;
	/** Branch head the worker reached at the last trigger (else the baseline). */
	lastSegmentHead: string;
	/**
	 * The break point the last re-queue answered. The audit of that break
	 * point stays on the record, and the join reads this to stop naming
	 * the re-queue the primary has already made. A later entry has a
	 * different id, so the value goes inert on its own.
	 */
	requeuedFromEntryId?: string;
	proposal?: Proposal;
	verification?: Verification;
	bringBack?: BringBack;
	forkedAt: string;
}

/**
 * Every gate in the extension asks the transition table whether the action
 * is legal from the task's phase. One source, so a gate and the table can
 * never disagree about which edges exist.
 */
function admits(task: TaskRecord, action: TaskAction): boolean {
	return canTask(task.phase, action);
}

/** A task accepts a break point while the table has a join row from its phase. */
export function canRecord(task: TaskRecord): boolean {
	return admits(task, "join");
}

/** The termination audit runs only from a phase the table admits it in (I8). */
export function canVerify(task: TaskRecord): boolean {
	return admits(task, "verify-usable");
}

/** The write-back proposal distills terminated state (I9 ordering). */
export function canPropose(task: TaskRecord): boolean {
	return admits(task, "propose");
}

/** The bring-back runs only from terminated state (I9 ordering). */
export function canBringBack(task: TaskRecord): boolean {
	return admits(task, "bring-back");
}

/** A re-queue runs only from a phase the table has a re-queue row from. */
export function canRequeue(task: TaskRecord): boolean {
	return admits(task, "requeue-in-place");
}

/** A task closes only from the phase the table admits the close in. */
export function canClose(task: TaskRecord): boolean {
	return admits(task, "close");
}

/**
 * The head a task's next segment is measured from: the head its last
 * delivered break point reached, or the baseline before any. The delivery
 * and the transition it applies both read it here, so the segment an
 * operator judges, the head the record writes, and the head a re-queue
 * rolls back to are one read of the task record.
 */
export function segmentBaseOf(task: TaskRecord): string {
	return task.lastSegmentHead || task.baseline;
}

/** The rejection message for an action the table does not admit here. */
export function phaseRejection(task: TaskRecord, action: TaskAction, what: string): string {
	return `task ${task.taskId} is ${task.phase}; ${what} runs only from ${legalFrom(action)}`;
}

/**
 * The file set a bring-back writes is a subset of the proposal: a named
 * path the proposal does not contain is a scope violation (I7). The empty
 * set is legal and means "write nothing back, still prune".
 */
export function assertFileSet(paths: readonly string[], proposal: Proposal): void {
	const seen = new Set<string>();
	for (const p of paths) {
		if (seen.has(p)) {
			throw new Error(`the file set names ${p} twice`);
		}
		seen.add(p);
		if (!proposal.paths.includes(p)) {
			throw new Error(`the file set names ${p}, which the proposal does not contain`);
		}
	}
}
