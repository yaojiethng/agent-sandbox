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
 *
 * The selector picks the mode, and the three modes share one contract:
 *
 *   - Default: join_any. The earliest-forked ready task.
 *   - `taskId`: join_single. The named task, and only that one.
 *   - `taskIds`: join_all, a pool. The call blocks until every task of the
 *     pool has a break point ready, then records, schedules, and triggers
 *     the whole set in one transaction and returns one payload per task.
 *
 * A pool batch is the join transition run once per task under one lock,
 * not a second state machine: the whole set moves or none of it does, and
 * a contention anywhere in the batch re-scans the whole pool as a unit, so
 * no task of a pool is ever left half delivered (I1, I11). A pool timeout
 * is a timed wait like any other: it triggers nothing and names the tasks
 * of the pool that did have a break point, so the caller can join any of
 * them, or the whole pool again, after it.
 *
 * One join-unit waits on the operator at a time. A join-unit is a single
 * break point or one pool batch: while any break point of the unit is
 * undecided, the call reports the hold and delivers nothing beside it.
 */

import { TaskQueueError } from "./errors.ts";
import { entriesForTask, isPending, type QueueEntry } from "./queue.ts";
import { canRecord, phaseRejection, segmentBaseOf, type TaskPhase, type TaskRecord } from "./tasks.ts";
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
	/**
	 * Apply the join transition to every task of a pool as one serialized
	 * read-modify-write, so the whole batch records, schedules, and
	 * triggers in one write and no task of the pool is delivered beside a
	 * task that was not (I11). A refusal is a refusal of the whole batch.
	 */
	joinAll(ps: JoinParams[]): Promise<{ data: Joined[]; journalError?: string }>;
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
	/**
	 * The notices about this delivery. A single delivery carries the scan's
	 * notices too; a payload of a pool carries only what concerns its own
	 * task, and the batch carries the scan's notices.
	 */
	notices: string[];
}

/** A pool delivered whole: one payload per task, in the order the pool named them. */
export interface PoolJoinedResult {
	outcome: "joined";
	mode: "pool";
	payloads: JoinPayload[];
	/** The scan's notices: the ones no single task's payload owns. */
	notices: string[];
	waitedMs: number;
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
	/** Pool mode: the pool tasks that had a break point ready. */
	ready?: string[];
	/** Pool mode: the pool tasks that had none, and so kept the pool open. */
	missing?: string[];
	notices: string[];
}

export interface AbortedResult {
	outcome: "aborted";
	waitedMs: number;
	notices: string[];
}

export type JoinResult = JoinPayload | PoolJoinedResult | HeldResult | TimeoutResult | AbortedResult;

export interface JoinWait {
	/** Required. The call blocks at most this long. */
	timeoutMs: number;
	/** Deliver this task's break point only; the earliest ready task otherwise. */
	taskId?: string;
	/**
	 * Pool mode: deliver the break point of every task named here as one
	 * batch. The call blocks until all of them are ready, and the batch is
	 * one transition. Mutually exclusive with `taskId`.
	 */
	taskIds?: string[];
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
 *
 * A pool batch delivers every break point of the batch at once, so the
 * unit the operator holds is the whole batch. This names the first one;
 * `heldUnit` names the whole set.
 */
export function heldBreakPoint(run: Pick<JoinRun, "stateDir">, state: RunState, scan: ReadyScan): HeldBreakPoint | undefined {
	const first = heldUnits(state, scan)[0];
	if (!first) return undefined;
	const task = first.task;
	const last = first.entry;
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

/**
 * Every task whose latest break point is delivered and undecided, in
 * fork order. One task per held break point; a pool batch holds one per
 * task, so the hold is a set and not a single break point.
 */
function heldUnits(state: RunState, scan: ReadyScan): Array<{ task: TaskRecord; entry: QueueEntry }> {
	const held: Array<{ task: TaskRecord; entry: QueueEntry }> = [];
	for (const task of tasksInForkOrder(state)) {
		if (task.phase !== "active") continue;
		const entries = entriesForTask(state.entries, task.taskId);
		const last = entries[entries.length - 1];
		if (!last || last.state !== "triggered") continue;
		// A worker that requested again already decided its previous break
		// point, terminal or not: its next request is the live one.
		if (scan.readyTasks.has(task.taskId)) continue;
		held.push({ task, entry: last });
	}
	return held;
}

/**
 * The tasks of the held join-unit, in fork order: the one break point a
 * single join delivered, or the whole batch a pool join delivered. A
 * reader that knows the set knows what the operator still has to decide.
 */
export function heldUnit(state: RunState, scan: ReadyScan): string[] {
	return heldUnits(state, scan).map((h) => h.task.taskId);
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

/** One candidate read and prepared for the transition, before any state write. */
interface Prepared {
	/** The transition parameters, measured against the state this scan read. */
	params: JoinParams;
	/** What the candidate itself contributes to the payload. */
	read: { requestStatus: WorkerStatus; message: string; segmentStat: string; segmentChanged: string[]; uncommitted: string[] };
	/** The notices this candidate owns; the scan's notices stay with the scan. */
	notices: string[];
}

/**
 * Read one candidate: archive the request, read the segment, and measure
 * the transition. Nothing the payload reports is written before the call
 * applies the transition, so the transition is the only mutation of the
 * queue, and the archive holds the bytes the scan validated whether this
 * delivery or a re-scan of it is the one that records.
 */
function prepare(run: JoinRun, state: RunState, candidate: ReadyCandidate): Prepared {
	const task = state.tasks[candidate.taskId];
	if (!task) throw new TaskQueueError("task-unknown", `no task with id ${candidate.taskId}`);
	const notices: string[] = [];
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
	return {
		params: { taskId: candidate.taskId, requestId: candidate.requestId, status, head, changed: segmentChanged.length, baseHead: from },
		read: { requestStatus: status, message, segmentStat: stat || "(no deliverable change since the last break point)", segmentChanged, uncommitted },
		notices,
	};
}

/** The payload one delivered transition reports. */
function payloadOf(prepared: Prepared, joined: Joined, waitedMs: number, notices: string[]): JoinPayload {
	return {
		outcome: "joined",
		entryId: joined.entry.entryId,
		taskId: joined.entry.taskId,
		workerId: joined.entry.workerId,
		workdir: joined.entry.workdir,
		branch: joined.task.branch,
		baseline: joined.task.baseline,
		requestStatus: prepared.read.requestStatus,
		message: prepared.read.message,
		segmentStat: prepared.read.segmentStat,
		segmentChanged: prepared.read.segmentChanged,
		uncommitted: prepared.read.uncommitted,
		waitedMs,
		notices,
	};
}

/** Deliver one break point: one prepared candidate, one transition, one payload. */
async function deliver(run: JoinRun, prepared: Prepared, waitedMs: number, notices: string[], wait: JoinWait): Promise<JoinPayload> {
	const result = await run.join(prepared.params);
	const payload = payloadOf(prepared, result.data, waitedMs, [...notices, ...prepared.notices]);
	wait.onJoin?.(payload);
	return payload;
}

/**
 * Deliver a whole pool: every candidate is read first, then one
 * transition carries all of them. The caller applies that transition
 * under one lock, so the batch records, schedules, and triggers together
 * or not at all (I11). A refusal of any task of the pool is a refusal of
 * the batch, and the wait re-scans the whole pool (I1).
 */
async function deliverPool(run: JoinRun, prepared: Prepared[], waitedMs: number, notices: string[], wait: JoinWait): Promise<PoolJoinedResult> {
	const result = await run.joinAll(prepared.map((p) => p.params));
	if (result.data.length !== prepared.length) {
		// A batch returns one delivery per task of the pool; a face that
		// answers with another count has no payload to pair with, which is
		// a defect here rather than a caller's mistake.
		throw new TaskQueueError("state-corrupt", `the batch transition delivered ${result.data.length} break points for a pool of ${prepared.length}`);
	}
	const payloads = prepared.map((p, i) => payloadOf(p, result.data[i], waitedMs, p.notices));
	for (const payload of payloads) wait.onJoin?.(payload);
	return { outcome: "joined", mode: "pool", payloads, notices, waitedMs };
}

/**
 * The pool a caller named, validated before the block, or undefined when
 * the call is not a pool join. A pool that could never deliver is
 * refused at once: an empty list, a repeated task, a task no fork holds,
 * a task the queue has closed to requests, and the two selectors at once.
 * Every one of them would otherwise cost the caller the whole timeout to
 * report nothing.
 */
function poolOf(wait: JoinWait, state: RunState): string[] | undefined {
	if (wait.taskIds === undefined) return undefined;
	if (wait.taskId !== undefined) {
		throw new TaskQueueError(
			"request-invalid",
			`name taskId or taskIds, not both: one call joins one unit, and the selector picks the mode (taskId joins one task, taskIds joins the pool)`,
		);
	}
	if (!Array.isArray(wait.taskIds) || wait.taskIds.length === 0) {
		throw new TaskQueueError("request-invalid", `taskIds must name at least one task, not ${JSON.stringify(wait.taskIds ?? null)}`);
	}
	const seen = new Set<string>();
	for (const taskId of wait.taskIds) {
		if (typeof taskId !== "string" || taskId === "") {
			throw new TaskQueueError("request-invalid", `taskIds must name tasks by id, not ${JSON.stringify(taskId ?? null)}`);
		}
		if (seen.has(taskId)) {
			throw new TaskQueueError("request-invalid", `taskIds names task ${taskId} twice; one task contributes one break point to a batch`);
		}
		seen.add(taskId);
		const task = state.tasks[taskId];
		if (!task) {
			throw new TaskQueueError("task-unknown", `no task with id ${taskId}; the run holds ${Object.keys(state.tasks).join(", ") || "no task"}`);
		}
		if (!canRecord(task)) {
			throw new TaskQueueError("task-phase", phaseRejection(task, "join", "a join"));
		}
	}
	return [...wait.taskIds];
}

/**
 * The candidates this call would deliver now, in the order the caller's
 * selector named them. A pool is complete only when every task of it has
 * a candidate; the scan yields at most one candidate per task, so a
 * complete pool is one candidate per named task.
 */
function selection(scan: ReadyScan, wait: JoinWait, pool: string[] | undefined): ReadyCandidate[] {
	if (pool !== undefined) {
		return pool.map((taskId) => scan.candidates.find((c) => c.taskId === taskId)).filter((c): c is ReadyCandidate => c !== undefined);
	}
	const candidate = scan.candidates.find((c) => !wait.taskId || c.taskId === wait.taskId);
	return candidate ? [candidate] : [];
}

function defaultSleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

/**
 * Block until the selected break points are ready, the hold is reported,
 * the timeout expires, or the caller aborts. Exactly one of the results
 * comes back, and only a "joined" changed the queue. A pool joins when
 * every task of it is ready; a single join needs only its one.
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
	const pool = poolOf(wait, state0);
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
		const selected = selection(scan, wait, pool);
		if (selected.length > 0 && (pool === undefined || selected.length === pool.length)) {
			try {
				const prepared = selected.map((candidate) => prepare(run, state, candidate));
				const waitedMs = now() - started;
				if (pool !== undefined) return await deliverPool(run, prepared, waitedMs, scan.notices, wait);
				return await deliver(run, prepared[0], waitedMs, scan.notices, wait);
			} catch (err) {
				if (err instanceof TaskQueueError && err.code === "join-contended" && contended < CONTENTION_ROUNDS) {
					// A contention anywhere in a batch is a contention of the
					// whole unit: nothing was written, so the pool re-scans
					// as a unit and delivers all of it or none of it (I1).
					contended += 1;
					continue;
				}
				throw err;
			}
		}
		const elapsed = now();
		if (elapsed >= deadline) {
			if (pool !== undefined) {
				// An inert timeout names which tasks of the pool were ready,
				// so the caller can join any of them on its own afterwards.
				const ready = selected.map((c) => c.taskId);
				const missing = pool.filter((taskId) => !ready.includes(taskId));
				return { outcome: "timeout", timeoutMs: wait.timeoutMs, waitedMs: elapsed - started, waiting: scan.joinable, ready, missing, notices: scan.notices };
			}
			return { outcome: "timeout", timeoutMs: wait.timeoutMs, waitedMs: elapsed - started, waiting: scan.joinable, notices: scan.notices };
		}
		await sleep(Math.min(pollMs, deadline - elapsed));
	}
}
