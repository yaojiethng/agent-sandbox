/**
 * The join: the primary's blocking wait for a worker's break point.
 *
 * One call is one delivery. The join scans the task worktrees for request
 * documents the queue has not admitted, records the first one, schedules
 * it, triggers it, and returns the join payload - all as one pure state
 * derivation, so the passage through the requested and scheduled states
 * is invisible outside the transition (I11). The queue rests only in
 * triggered: a delivered break point sits with the operator until the
 * primary acts on it.
 *
 * The call blocks until a break point is ready or the timeout expires. The
 * scan interval lives here, so the caller never sleeps and re-polls; a
 * timeout is a timed wait, and it changes nothing (I12). The timeout and
 * the named task are validated before the block, so a call that cannot
 * deliver anything fails at once rather than at the end of the timeout.
 *
 * Two rules keep a delivery exactly-once and a hold singular:
 *
 *   - A break point the operator has not decided holds the join. The call
 *     reports the hold and what clears it; it never delivers a second
 *     payload beside an undecided one.
 *   - A break point another join took mid-call is not a delivery. The
 *     transition reports the contention and the wait re-scans.
 *
 * Selection is the primary's choice across tasks and the queue's choice
 * within one: the named task when the caller names it, the earliest
 * forked ready task otherwise, and inside a task the lowest request
 * sequence (I2).
 */

import { TaskQueueError } from "./errors.ts";
import { entriesForTask, isPending, type QueueEntry } from "./queue.ts";
import { canRecord, segmentBaseOf, type TaskPhase, type TaskRecord } from "./tasks.ts";
import { joinOp, type JoinParams, type Joined } from "./ops.ts";
import { archiveRequest, readArchivedRequest } from "./record.ts";
import { listWorkerRequests, parseWorkerRequest, requestSeqOf, PROTOCOL_DIR, type WorkerRequest, type WorkerStatus } from "./protocol.ts";
import type { RunState } from "./state.ts";
import { segmentInfo, statusPorcelain, worktreeHead } from "./worktree.ts";

/** The persisted face the join drives: read the state, apply one transition. */
export interface JoinRun {
	/** The run's state directory: the request archive lives here. */
	stateDir: string;
	/** The state as it is now. */
	current(): RunState;
	/**
	 * Apply the join transition as one serialized read-modify-write. The
	 * caller owns the serialization; the join owns nothing else.
	 */
	join(p: JoinParams): Promise<{ data: Joined; journalError?: string }>;
}

/** One break point the join can deliver now. */
export interface ReadyCandidate {
	taskId: string;
	requestId: string;
	/** The validated bytes of the request document; empty on the heal path. */
	content: string;
	/** The parsed document; undefined on the heal path, which reads the archive. */
	request: WorkerRequest | undefined;
	/** True when the queue already holds the entry and the join only heals it forward. */
	queued: boolean;
}
export interface ReadyScan {
	/** Candidates in delivery order: fork order, then request order per task. */
	candidates: ReadyCandidate[];
	/** The tasks that have a candidate; a re-request disarms their hold. */
	readyTasks: Set<string>;
	/** The tasks that can still request a break point. */
	joinable: string[];
	/** Protocol notices the operator should see with the next result. */
	notices: string[];
}

/** A delivered break point the operator has not decided yet. */
export interface HeldBreakPoint {
	taskId: string;
	entryId: string;
	requestStatus: WorkerStatus;
	phase: TaskPhase;
	/** What the worker asked when it requested the break point. */
	message: string;
	/** The action that disarms the hold. */
	clearsBy: string;
}

export interface JoinPayload {
	outcome: "joined";
	entryId: string;
	taskId: string;
	workerId: string;
	workdir: string;
	branch: string;
	baseline: string;
	requestStatus: WorkerStatus;
	message: string;
	segmentStat: string;
	segmentChanged: string[];
	/** Uncommitted paths outside the protocol directory: the segment misses them. */
	uncommitted: string[];
	waitedMs: number;
	notices: string[];
}

export interface HeldResult {
	outcome: "held";
	hold: HeldBreakPoint;
	/** The tasks that can still request a break point. */
	waiting: string[];
	/** The tasks whose break point waits behind this hold. */
	ready: string[];
	waitedMs: number;
	notices: string[];
}

export interface TimeoutResult {
	outcome: "timeout";
	timeoutMs: number;
	waitedMs: number;
	waiting: string[];
	notices: string[];
}

export interface AbortedResult {
	outcome: "aborted";
	waitedMs: number;
	notices: string[];
}

export type JoinResult = JoinPayload | HeldResult | TimeoutResult | AbortedResult;

export interface JoinWait {
	/** Required. The call blocks at most this long. */
	timeoutMs: number;
	/** Deliver this task's break point only; the earliest ready task otherwise. */
	taskId?: string;
	/** The caller's abort signal; an abort returns without delivering. */
	signal?: AbortSignal;
	/** Scan interval. Internal detail, not the caller's wait strategy. */
	pollMs?: number;
	/** Test seams for the clock and the wait. */
	sleep?: (ms: number) => Promise<void>;
	now?: () => number;
	/** Called once, with the payload, after a delivery lands. */
	onJoin?: (payload: JoinPayload) => void;
}

/** The default scan interval between two looks at the worktrees. */
export const DEFAULT_POLL_MS = 250;

/** The uncommitted paths a payload names before the list is capped. */
const UNCOMMITTED_CAP = 20;

/**
 * Consecutive re-scans after a contention before the join surfaces the
 * error. Contention resolves in one re-scan; a state that keeps
 * contending is a state the operator must see, not a wait to spin in.
 */
const CONTENTION_ROUNDS = 3;

function tasksInForkOrder(state: RunState): TaskRecord[] {
	return Object.values(state.tasks).sort((a, b) => a.forkedAt.localeCompare(b.forkedAt) || a.taskId.localeCompare(b.taskId));
}

function isRecorded(state: RunState, requestId: string): boolean {
	return Object.prototype.hasOwnProperty.call(state.requests, requestId);
}

/**
 * Read every task worktree once and report what the join can deliver.
 * The scan is the only place a request document is validated, so the
 * bytes the archive keeps are the bytes the queue admits.
 */
export function scanReady(state: RunState): ReadyScan {
	const candidates: ReadyCandidate[] = [];
	const readyTasks = new Set<string>();
	const joinable: string[] = [];
	const notices: string[] = [];
	for (const task of tasksInForkOrder(state)) {
		if (!canRecord(task)) {
			// A task the table has no join row from is closed to requests. A
			// worker that wrote one anyway is not heard anywhere else, so the
			// scan names what it left behind and the phase that closed the
			// task: a document on disk that the queue can never admit is the
			// one outcome the payload would otherwise report as a bare wait.
			notices.push(...unadmittedNotices(task, state));
			continue;
		}
		joinable.push(task.taskId);
		const documents = listWorkerRequests(task.workdir);
		// A queued entry is healed forward before any document the worker
		// wrote behind it: request order per task outranks arrival (I2).
		let pending: QueueEntry | undefined;
		for (const entry of entriesForTask(state.entries, task.taskId)) {
			if (isPending(entry) && (!pending || entry.requestSeq < pending.requestSeq)) pending = entry;
		}
		for (const doc of documents) {
			if (isRecorded(state, doc.requestId)) continue;
			if (doc.invalid) {
				notices.push(`${task.taskId}: request document ${doc.requestId} is not a valid worker request and is skipped`);
				continue;
			}
			if (doc.request && doc.request.taskId !== task.taskId) {
				notices.push(`${task.taskId}: request document ${doc.requestId} names task ${doc.request.taskId} and is skipped`);
				continue;
			}
			// The queue keys the request and its archive by the same id, so a
			// document whose name and content disagree is not admitted.
			if (doc.request && doc.request.requestId !== doc.requestId) {
				notices.push(`${task.taskId}: request document ${doc.requestId} carries id ${doc.request.requestId} and is skipped`);
			}
		}
		if (pending) {
			candidates.push({ taskId: task.taskId, requestId: pending.requestId, content: "", request: undefined, queued: true });
			readyTasks.add(task.taskId);
			const raced = documents.filter((d) => !isRecorded(state, d.requestId) && requestSeqOf(d.requestId) > pending.requestSeq);
			if (raced.length > 0) {
				notices.push(`${task.taskId}: request ${raced.map((d) => d.requestId).join(", ")} advanced past the queued break point ${pending.entryId}; the queued one is delivered first`);
			}
			continue;
		}
		const unrecorded = documents.filter(
			(d) => !d.invalid && !isRecorded(state, d.requestId) && d.request?.taskId === task.taskId && d.request.requestId === d.requestId,
		);
		// A worker that requested again before its break point was cleared
		// raced its own hold. The order is unaffected; the operator hears it.
		if (unrecorded.length > 1) {
			notices.push(`${task.taskId}: requests ${unrecorded.map((d) => d.requestId).join(", ")} all wait; the worker requested again before the earlier break point cleared. They are delivered in request order`);
		}
		const next = unrecorded[0];
		if (next?.request) {
			candidates.push({
				taskId: task.taskId,
				requestId: next.requestId,
				// The bytes the scan validated, not a second read of the file:
				// a document rewritten between the two reads would otherwise
				// be archived under content the queue never admitted.
				content: next.raw,
				request: next.request,
				queued: false,
			});
			readyTasks.add(task.taskId);
		}
	}
	return { candidates, readyTasks, joinable, notices };
}

/**
 * The request documents a task the queue can no longer admit holds: the
 * task's phase has no join row, so the documents sit in its worktree
 * forever. A worker that ran past its terminal request, or past its
 * bring-back, lands here. The notice names each document and the phase
 * that closed the task, because nothing else in the payload can.
 */
function unadmittedNotices(task: TaskRecord, state: RunState): string[] {
	const documents = listWorkerRequests(task.workdir).filter((d) => !isRecorded(state, d.requestId));
	if (documents.length === 0) return [];
	return [
		`${task.taskId}: request document${documents.length === 1 ? "" : "s"} ${documents.map((d) => d.requestId).join(", ")} cannot be admitted; the task is ${task.phase}, which no join runs from. The worker wrote it after the task was closed; read it in its worktree`,
	];
}

/**
 * The break point waiting on the operator, if any. A task holds a hold
 * while its latest break point is delivered and nothing has decided it.
 * What clears it depends on which of the three decisions is outstanding,
 * and the verification record names which: a terminal break point whose
 * audit is not recorded yet waits for the audit; a not-usable audit of
 * that break point waits for the re-queue the primary chooses; a regular
 * break point, and every segment after a re-queue, waits for the worker's
 * next request, which the primary produces by re-dispatching the worker.
 * A task that re-requested already decided.
 *
 * The re-queue is the one step the record shows as already taken: a
 * re-queue records the entry it answered, so a not-usable audit whose
 * re-queue is done no longer names that re-queue. The audit stays on the
 * record - a not-usable audit of a re-queued break point is history, not
 * a decision the primary still owes - and only the branch the hold selects
 * moves on to the next segment.
 *
 * The hold carries the worker's message, so a primary that resumes into a
 * hold an earlier session left behind can still tell the operator what the
 * worker asked.
 */
export function heldBreakPoint(run: Pick<JoinRun, "stateDir">, state: RunState, scan: ReadyScan): HeldBreakPoint | undefined {
	for (const task of tasksInForkOrder(state)) {
		if (task.phase !== "active") continue;
		const entries = entriesForTask(state.entries, task.taskId);
		const last = entries[entries.length - 1];
		if (!last || last.state !== "triggered") continue;
		// A worker that requested again already decided its previous break
		// point, terminal or not: its next request is the live one.
		if (scan.readyTasks.has(task.taskId)) continue;
		const audited = task.verification?.entryId === last.entryId;
		const requeued = task.requeuedFromEntryId === last.entryId;
		if (task.workerDone && !audited) {
			return {
				taskId: task.taskId,
				entryId: last.entryId,
				requestStatus: "done",
				phase: task.phase,
				message: heldMessage(run.stateDir, last.requestId),
				clearsBy: "taskq_verify: the terminal break point is decided by the final verification audit",
			};
		}
		if (audited && task.verification?.outcome === "not-usable" && !requeued) {
			return {
				taskId: task.taskId,
				entryId: last.entryId,
				requestStatus: "done",
				phase: task.phase,
				message: heldMessage(run.stateDir, last.requestId),
				clearsBy:
					"the re-queue: taskq_requeue with route in-place when the defect is in the segment, or route fresh when the worktree or its state is poisoned. Then dispatch the worker again and join",
			};
		}
		return {
			taskId: task.taskId,
			entryId: last.entryId,
			requestStatus: "running",
			phase: task.phase,
			message: heldMessage(run.stateDir, last.requestId),
			clearsBy: "the worker's next request: re-dispatch the worker into the same worktree, then join again",
		};
	}
	return undefined;
}

/** The archived request message behind a hold. */
function heldMessage(stateDir: string, requestId: string): string {
	try {
		return readArchivedRequest(stateDir, requestId).message;
	} catch {
		// A held break point with no readable archive is state corruption.
		// The close audit names it; the hold still names the entry.
		return "";
	}
}

/** The paths a worker changed, minus its own protocol files. */
function changedPaths(paths: readonly string[]): string[] {
	return paths.filter((p) => p !== "" && !p.startsWith(`${PROTOCOL_DIR}/`));
}

/** Uncommitted paths outside the protocol directory, which the segment misses. */
function uncommittedPaths(workdir: string): string[] {
	return changedPaths(
		statusPorcelain(workdir)
			.split("\n")
			.filter((line) => line !== "")
			.map((line) => line.slice(3)),
	).slice(0, UNCOMMITTED_CAP);
}

/**
 * Deliver one candidate: archive the request, read the segment, and apply
 * the transition. Everything the payload reports is read before the
 * write, so the transition itself is the only mutation.
 */
async function deliver(
	run: JoinRun,
	state: RunState,
	candidate: ReadyCandidate,
	waitedMs: number,
	notices: string[],
	wait: JoinWait,
): Promise<JoinPayload> {
	const task = state.tasks[candidate.taskId];
	if (!task) throw new TaskQueueError("task-unknown", `no task with id ${candidate.taskId}`);
	let status: WorkerStatus;
	let message: string;
	if (candidate.queued) {
		const archived = readArchivedRequest(run.stateDir, candidate.requestId);
		status = archived.status;
		message = archived.message;
	} else {
		const request = candidate.request ?? parseWorkerRequest(candidate.content, candidate.requestId);
		if (request.taskId !== candidate.taskId) {
			throw new TaskQueueError("request-invalid", `request ${request.requestId} names task ${request.taskId}, not ${candidate.taskId}`);
		}
		// Archived before the record, so a recorded entry has its document by
		// construction and a contended delivery re-archives the same bytes.
		archiveRequest(run.stateDir, request.requestId, candidate.content);
		status = request.status;
		message = request.message;
	}
	const head = worktreeHead(task.workdir);
	// The segment the operator judges is the worker's deliverable; its
	// protocol files are bookkeeping and never reach a write-back proposal.
	const from = segmentBaseOf(task);
	const raw = segmentInfo(task.workdir, from, head);
	const segmentChanged = changedPaths(raw.changed);
	// A segment whose only change is the protocol directory has no
	// deliverable, so it reports no stat at all: narrowing an empty path
	// list would ask git for the whole diff and leak the protocol files
	// back into the segment the operator judges.
	const stat =
		segmentChanged.length === 0
			? ""
			: segmentChanged.length !== raw.changed.length
				? segmentInfo(task.workdir, from, head, segmentChanged).stat
				: raw.stat;
	const uncommitted = uncommittedPaths(task.workdir);
	if (uncommitted.length > 0) {
		notices.push(`${task.taskId}: the worktree holds ${uncommitted.length} uncommitted path(s) outside ${PROTOCOL_DIR}/; the segment below does not carry them`);
	}
	const result = await run.join({ taskId: candidate.taskId, requestId: candidate.requestId, status, head, changed: segmentChanged.length, baseHead: from });
	const payload: JoinPayload = {
		outcome: "joined",
		entryId: result.data.entry.entryId,
		taskId: result.data.entry.taskId,
		workerId: result.data.entry.workerId,
		workdir: result.data.entry.workdir,
		branch: result.data.task.branch,
		baseline: result.data.task.baseline,
		requestStatus: status,
		message,
		segmentStat: stat || "(no deliverable change since the last break point)",
		segmentChanged,
		uncommitted,
		waitedMs,
		notices,
	};
	wait.onJoin?.(payload);
	return payload;
}

function defaultSleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Block until a break point is ready, the hold is reported, the timeout
 * expires, or the caller aborts. Exactly one of the four results comes
 * back, and only "joined" changed the queue.
 *
 * The wait validates its own arguments before it blocks. A missing or
 * unbounded timeout would spin past the deadline the caller believes it
 * set, and a task id no task holds would never be delivered, so both are
 * refused immediately instead of at the end of a full timeout.
 */
export async function waitForBreakPoint(run: JoinRun, wait: JoinWait): Promise<JoinResult> {
	const now = wait.now ?? Date.now;
	const sleep = wait.sleep ?? defaultSleep;
	if (!Number.isFinite(wait.timeoutMs) || wait.timeoutMs < 1) {
		throw new TaskQueueError("request-invalid", `timeoutMs must be a finite number of at least 1 ms, not ${String(wait.timeoutMs)}`);
	}
	const state0 = run.current();
	if (wait.taskId !== undefined && !state0.tasks[wait.taskId]) {
		throw new TaskQueueError("task-unknown", `no task with id ${wait.taskId}; the run holds ${Object.keys(state0.tasks).join(", ") || "no task"}`);
	}
	const started = now();
	const deadline = started + wait.timeoutMs;
	const pollMs = Math.max(10, wait.pollMs ?? DEFAULT_POLL_MS);
	let contended = 0;
	for (;;) {
		if (wait.signal?.aborted) return { outcome: "aborted", waitedMs: now() - started, notices: [] };
		const state = run.current();
		if (state.closed) {
			throw new TaskQueueError("run-closed", "the run is closed; no further transitions are legal");
		}
		const scan = scanReady(state);
		const hold = heldBreakPoint(run, state, scan);
		if (hold) {
			return {
				outcome: "held",
				hold,
				waiting: scan.joinable,
				ready: scan.candidates.map((c) => c.taskId),
				waitedMs: now() - started,
				notices: scan.notices,
			};
		}
		const candidate = scan.candidates.find((c) => !wait.taskId || c.taskId === wait.taskId);
		if (candidate) {
			try {
				return await deliver(run, state, candidate, now() - started, scan.notices, wait);
			} catch (err) {
				if (err instanceof TaskQueueError && err.code === "join-contended" && contended < CONTENTION_ROUNDS) {
					contended += 1;
					continue;
				}
				throw err;
			}
		}
		const elapsed = now();
		if (elapsed >= deadline) {
			return { outcome: "timeout", timeoutMs: wait.timeoutMs, waitedMs: elapsed - started, waiting: scan.joinable, notices: scan.notices };
		}
		await sleep(Math.min(pollMs, deadline - elapsed));
	}
}
