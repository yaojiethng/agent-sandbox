/**
 * The task record: the primary's bookkeeping for one fork/join/re-queue
 * track. The queue entries never reference this record, and the record
 * never marks a queue entry's kind. The record carries what the queue must
 * not: the worker's disposition (running or done), the verification
 * outcome, the write-back proposal, and the final verdict.
 */

export type TaskPhase =
	| "forked" // worktree cut, no break point recorded yet
	| "active" // at least one break point recorded
	| "verified" // final verification passed, merge eligible
	| "failed" // final verification failed, repair segment eligible
	| "merged" // verdict all or partial applied
	| "discarded" // verdict none applied (track archived)
	| "retired"; // worktree removed and branch pruned

export type WorkerStatus = "running" | "done";

export type VerdictScope = "all" | "partial" | "none";

export type Verdict = { scope: "all" } | { scope: "partial"; paths: string[] } | { scope: "none" };

export interface Proposal {
	/** Changed paths of the worker branch offered for write-back. */
	paths: string[];
	/** The primary's distillation, the unit the operator judges. */
	description: string;
	at: string;
}

export interface Verification {
	outcome: "passed" | "failed";
	notes: string;
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
	proposal?: Proposal;
	verification?: Verification;
	verdict?: Verdict;
	forkedAt: string;
}

/**
 * A task accepts a new break point request while it is forked, active, or
 * failed. A verified, merged, discarded, or retired task is closed to new
 * segments; verification failure is the one door back into the queue.
 */
export function canRecord(task: TaskRecord): boolean {
	return task.phase === "forked" || task.phase === "active" || task.phase === "failed";
}

/**
 * Final verification may run only after the worker requested the terminal
 * break point, so only from the active or failed state (I8).
 */
export function canVerify(task: TaskRecord): boolean {
	return task.phase === "active" || task.phase === "failed";
}

/** The write-back proposal distills verified state (I9 ordering). */
export function canPropose(task: TaskRecord): boolean {
	return task.phase === "verified";
}

/** The merge applies only after final verification confirms the return (I9). */
export function canMerge(task: TaskRecord): boolean {
	return task.phase === "verified";
}

/** Only a decided track is retired; a decided track is merged or discarded. */
export function canRetire(task: TaskRecord): boolean {
	return task.phase === "merged" || task.phase === "discarded";
}

/** A partial verdict must name a non-empty subset of the proposal. */
export function assertVerdict(verdict: Verdict, proposal: Proposal): void {
	if (verdict.scope === "partial") {
		if (verdict.paths.length === 0) {
			throw new Error("a partial verdict must name at least one path");
		}
		const seen = new Set<string>();
		for (const p of verdict.paths) {
			if (seen.has(p)) {
				throw new Error(`a partial verdict names ${p} twice`);
			}
			seen.add(p);
			if (!proposal.paths.includes(p)) {
				throw new Error(`a partial verdict names ${p}, which the proposal does not contain`);
			}
		}
	}
}