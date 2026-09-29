/**
 * Run state persistence. The state file is the load-bearing queue: every
 * operation loads it, mutates it, and writes it back atomically. A crash
 * between load and write loses at most the operation in flight; the next
 * call starts from the last persisted state. A write is atomic (temp file
 * plus rename), so a reader never observes a half-written state.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import type { QueueEntry } from "./queue.ts";
import { TASK_PHASES } from "./transitions.ts";
import type { TaskRecord } from "./tasks.ts";

export interface RunBaseline {
	/** Worktree paths registered when the run opened. */
	worktrees: string[];
	/** Local branch names present when the run opened. */
	branches: string[];
}

export interface RunState {
	version: 3; // 1: pre-baseline-capture; 2: the pre-consolidation phase set
	mainRoot: string;
	stateDir: string;
	openedAt: string;
	closed: boolean;
	tasks: Record<string, TaskRecord>;
	/** The queue: every entry ever enqueued, in request order per task. */
	entries: QueueEntry[];
	/** requestId -> entryId. The exactly-once gate for request documents. */
	requests: Record<string, string>;
	/**
	 * Worktrees and branches that existed when the run opened. The close
	 * sweep ignores them: they belong to the repository, not to this run.
	 * Absent in states written by older versions; the close tool skips the
	 * sweep for those.
	 */
	baselineWorktrees?: string[];
	baselineBranches?: string[];
}

export function freshState(mainRoot: string, stateDir: string, openedAt: string, baseline?: RunBaseline): RunState {
	return {
		version: 3,
		mainRoot,
		stateDir,
		openedAt,
		closed: false,
		tasks: {},
		entries: [],
		requests: {},
		baselineWorktrees: baseline?.worktrees,
		baselineBranches: baseline?.branches,
	};
}

export function statePathOf(stateDir: string): string {
	return path.join(stateDir, "state.json");
}

export function saveState(state: RunState): void {
	fs.mkdirSync(state.stateDir, { recursive: true });
	const file = statePathOf(state.stateDir);
	const tmp = `${file}.tmp`;
	fs.writeFileSync(tmp, JSON.stringify(state, null, 2), "utf8");
	fs.renameSync(tmp, file);
}

export function loadState(stateDir: string): RunState | undefined {
	const file = statePathOf(stateDir);
	if (!fs.existsSync(file)) return undefined;
	let raw: string;
	try {
		raw = fs.readFileSync(file, "utf8");
	} catch (err) {
		throw new TaskQueueError("state-corrupt", `cannot read ${file}: ${String(err)}`);
	}
	try {
		const state = JSON.parse(raw) as unknown;
		if (!validShape(state)) {
			throw new Error("unexpected shape");
		}
		return state;
	} catch {
		throw new TaskQueueError("state-corrupt", `state file ${file} is not a valid run state`);
	}
}

const ENTRY_STATES = new Set(["requested", "scheduled", "triggered"]);

function isRecord(v: unknown): v is Record<string, unknown> {
	return typeof v === "object" && v !== null && !Array.isArray(v);
}

/**
 * The shape guard: a state whose core fields are missing, mistyped, or
 * malformed is corruption, not a run. Only version 3 loads. The earlier
 * versions carry a different task record - version 2 the seven-phase set -
 * so a state written before the four phases loads as a record no gate
 * admits and every call fails with a misleading phase message; it is
 * refused here instead, as one loud corruption (I13). The baseline fields
 * stay optional, so a hand-written run without them loads with the close
 * sweep skipped.
 */
function validShape(v: unknown): v is RunState {
	if (!isRecord(v)) return false;
	if (v.version !== 3) return false;
	if (!Array.isArray(v.entries)) return false;
	for (const entry of v.entries) {
		if (!isRecord(entry)) return false;
		const e = entry as Record<string, unknown>;
		if (
			typeof e.entryId !== "string" ||
			typeof e.taskId !== "string" ||
			typeof e.workerId !== "string" ||
			typeof e.workdir !== "string" ||
			typeof e.requestId !== "string" ||
			!Number.isInteger(e.requestSeq) ||
			(e.requestSeq as number) < 1 ||
			!ENTRY_STATES.has(e.state as string)
		) {
			return false;
		}
	}
	if (!isRecord(v.tasks)) return false;
	for (const task of Object.values(v.tasks)) {
		if (!isRecord(task) || typeof task.taskId !== "string" || typeof task.phase !== "string") {
			return false;
		}
		// A phase the transition table does not name is a state no gate
		// admits: the run would fail every call with a message about the
		// phase instead of about the record.
		if (!TASK_PHASES.includes(task.phase as TaskRecord["phase"])) return false;
	}
	if (!isRecord(v.requests)) return false;
	return true;
}
