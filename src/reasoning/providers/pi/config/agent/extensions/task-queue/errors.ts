/**
 * Error codes for the task-queue extension.
 *
 * Every gate in the queue, the task lifecycle, and the bring-back reports
 * a distinct code so a rejected operation tells the primary exactly which
 * contract rule it violated. The bring-back is the operation; the merge is
 * the main-tree write it performs, so the two codes that name the write
 * keep the merge prefix.
 *
 * "join-contended" is the one code the join itself raises: a break point
 * moved under a delivery because another join took it. The join re-scans
 * on that code; a state that keeps contending surfaces it to the caller.
 * "lock-held" is the other: the state directory is owned by a live writer
 * this process is not, so the call reports the contention instead of
 * racing it. "bring-back-unprovable" separates the two bring-back gates:
 * the file set is legal but the record this tool would infer from a gone
 * worktree has no evidence behind it, so the call refuses rather than
 * write a retirement it cannot prove.
 */
export type TaskQueueErrorCode =
	| "run-closed"
	| "run-state-mismatch"
	| "not-a-git-repo"
	| "git"
	| "task-duplicate"
	| "task-unknown"
	| "task-workdir-inside-main"
	| "worktree-occupied"
	| "join-contended"
	| "task-phase"
	| "entry-unknown"
	| "entry-not-requested"
	| "entry-not-scheduled"
	| "entry-already-triggered"
	| "entry-out-of-order"
	| "entry-ref-mismatch"
	| "request-duplicate"
	| "request-pending-task"
	| "request-file-missing"
	| "request-path-mismatch"
	| "request-invalid"
	| "verify-gate"
	| "proposal-gate"
	| "requeue-gate"
	| "bring-back-gate"
	| "bring-back-unprovable"
	| "file-set-invalid"
	| "merge-dirty-main"
	| "merge-apply-failed"
	| "lock-held"
	| "prune-failed"
	| "close-gate"
	| "state-corrupt"
	| "worker-proto";

export class TaskQueueError extends Error {
	readonly code: TaskQueueErrorCode;

	constructor(code: TaskQueueErrorCode, message: string) {
		super(message);
		this.name = "TaskQueueError";
		this.code = code;
	}
}