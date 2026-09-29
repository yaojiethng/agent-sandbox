/**
 * Error codes for the task-queue extension.
 *
 * Every gate in the queue, the task lifecycle, and the merge reports a
 * distinct code so a rejected operation tells the primary exactly which
 * contract rule it violated.
 */
export type TaskQueueErrorCode =
	| "run-closed"
	| "run-state-mismatch"
	| "not-a-git-repo"
	| "git"
	| "task-duplicate"
	| "task-unknown"
	| "task-workdir-inside-main"
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
	| "merge-gate"
	| "verdict-invalid"
	| "merge-dirty-main"
	| "merge-apply-failed"
	| "retire-gate"
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