/**
 * The worker protocol: the files a worker writes in its own worktree to
 * request break points. The protocol is plain files so any worker - a pi
 * subagent, a bash harness, any provider - can participate without loading
 * this extension. The extension's own worker tool writes exactly these
 * files.
 *
 * Layout (all inside the worker's worktree, never in the primary tree):
 *   taskq/requests/<requestId>.json   one immutable document per request
 *   taskq/state.json                  the worker's request sequence counter
 *
 * A request document carries the worker's disposition: status "running"
 * means the worker pauses for the operator and continues after clearing;
 * status "done" means the terminal break point, after which the primary
 * runs the final verification. The queue entry never stores the status; the
 * primary reads the archived document when it handles the entry.
 *
 * The primary never writes into a worker's worktree. It reads the request
 * documents during poll, archives a copy into the run record, and the
 * protocol directory is always excluded from write-back proposals.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";

export const PROTOCOL_DIR = "taskq";
export const REQUESTS_DIR = "taskq/requests";
export const WORKER_STATE_FILE = "taskq/state.json";

export type WorkerStatus = "running" | "done";

export interface WorkerRequest {
	taskId: string;
	requestId: string;
	status: WorkerStatus;
	message: string;
	at: string;
}

export interface WorkerState {
	seq: number;
}

export function workerRequestsDir(workdir: string): string {
	return path.join(workdir, REQUESTS_DIR);
}

export function workerStatePath(workdir: string): string {
	return path.join(workdir, WORKER_STATE_FILE);
}

export function readWorkerState(workdir: string): WorkerState {
	const p = workerStatePath(workdir);
	if (!fs.existsSync(p)) return { seq: 0 };
	const raw = fs.readFileSync(p, "utf8");
	let parsed: unknown;
	try {
		parsed = JSON.parse(raw);
	} catch {
		throw new TaskQueueError("worker-proto", `worker state ${p} is not valid JSON`);
	}
	const seq = (parsed as WorkerState | null)?.seq;
	if (typeof parsed !== "object" || parsed === null || !Number.isInteger(seq) || (seq as number) < 0) {
		throw new TaskQueueError("worker-proto", `worker state ${p} is not a valid worker state`);
	}
	return { seq: seq as number };
}

export function writeWorkerState(workdir: string, state: WorkerState): void {
	const p = workerStatePath(workdir);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	// Atomic like the main state file: a torn counter write must never be
	// readable as a request sequence.
	const tmp = `${p}.tmp`;
	fs.writeFileSync(tmp, JSON.stringify(state, null, 2), "utf8");
	fs.renameSync(tmp, p);
}

/** Allocate the next request id for a task and persist the counter. */
export function nextRequestId(workdir: string, taskId: string): string {
	const state = readWorkerState(workdir);
	const seq = state.seq + 1;
	writeWorkerState(workdir, { seq });
	return `${taskId}-${seq}`;
}

export function writeWorkerRequest(workdir: string, request: WorkerRequest): string {
	const dir = workerRequestsDir(workdir);
	fs.mkdirSync(dir, { recursive: true });
	const file = path.join(dir, `${request.requestId}.json`);
	if (fs.existsSync(file)) {
		throw new TaskQueueError("worker-proto", `request document already exists: ${file}`);
	}
	fs.writeFileSync(file, JSON.stringify(request, null, 2), "utf8");
	return file;
}

/**
 * Parse and validate the raw bytes of one request document. The caller
 * reads the file once and passes the same bytes it archives, so the
 * validated document and the archived copy can never diverge.
 */
export function parseWorkerRequest(raw: string, file: string): WorkerRequest {
	let parsed: unknown;
	try {
		parsed = JSON.parse(raw);
	} catch {
		throw new TaskQueueError("request-invalid", `request document ${file} is not valid JSON`);
	}
	if (typeof parsed !== "object" || parsed === null) {
		throw new TaskQueueError("request-invalid", `request document ${file} is not a JSON object`);
	}
	const doc = parsed as Partial<WorkerRequest>;
	if (typeof doc.taskId !== "string" || typeof doc.requestId !== "string") {
		throw new TaskQueueError("request-invalid", `request document ${file} lacks taskId or requestId`);
	}
	if (doc.status !== "running" && doc.status !== "done") {
		throw new TaskQueueError("request-invalid", `request document ${file} has an invalid status`);
	}
	if (typeof doc.message !== "string") {
		throw new TaskQueueError("request-invalid", `request document ${file} lacks a message`);
	}
	return { taskId: doc.taskId, requestId: doc.requestId, status: doc.status, message: doc.message, at: doc.at ?? "" };
}

/** Read and validate one request document. */
export function readWorkerRequest(workdir: string, requestId: string): WorkerRequest {
	const file = path.join(workerRequestsDir(workdir), `${requestId}.json`);
	if (!fs.existsSync(file)) {
		throw new TaskQueueError("request-file-missing", `no request document at ${file}`);
	}
	return parseWorkerRequest(fs.readFileSync(file, "utf8"), file);
}

/** The numeric request sequence a request id carries after its last dash. */
function requestSeqOf(requestId: string): number {
	const seq = Number(requestId.slice(requestId.lastIndexOf("-") + 1));
	return Number.isInteger(seq) && seq > 0 ? seq : Number.MAX_SAFE_INTEGER;
}

/**
 * List the request documents of a worktree in request order. Returns the
 * request id and the parsed document; documents that do not parse are
 * reported as invalid so the primary (not the worker's own process) decides
 * what to do with a broken protocol file.
 */
export function listWorkerRequests(workdir: string): { requestId: string; request: WorkerRequest | undefined; invalid: boolean }[] {
	const dir = workerRequestsDir(workdir);
	if (!fs.existsSync(dir)) return [];
	const out: { requestId: string; request: WorkerRequest | undefined; invalid: boolean }[] = [];
	// Numeric request order, not lexicographic: t1-10 follows t1-2.
	const names = fs.readdirSync(dir).filter((n) => n.endsWith(".json"));
	names.sort((a, b) => requestSeqOf(a.slice(0, -".json".length)) - requestSeqOf(b.slice(0, -".json".length)));
	for (const name of names) {
		const requestId = name.slice(0, -".json".length);
		try {
			out.push({ requestId, request: readWorkerRequest(workdir, requestId), invalid: false });
		} catch {
			out.push({ requestId, request: undefined, invalid: true });
		}
	}
	return out;
}