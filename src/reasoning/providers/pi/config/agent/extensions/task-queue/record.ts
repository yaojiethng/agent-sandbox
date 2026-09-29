/**
 * The run record: an append-only journal of every state transition, plus
 * the archived worker request documents and archived diffs. The journal is
 * the primary's record of the run; tests and audits replay it to verify the
 * exactly-once identities (I1) and the transition ordering.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import { parseWorkerRequest, type WorkerRequest } from "./protocol.ts";

export type JournalEvent =
	| { type: "run:open"; at: string; mainRoot: string }
	| { type: "task:fork"; at: string; taskId: string; workerId: string; workdir: string; branch: string; baseline: string }
	| { type: "request:record"; at: string; entryId: string; taskId: string; requestId: string; status: "running" | "done" }
	| { type: "entry:schedule"; at: string; entryId: string; taskId: string }
	| { type: "entry:trigger"; at: string; entryId: string; taskId: string; head: string; changed: number }
	| { type: "verify"; at: string; taskId: string; outcome: "passed" | "failed"; notes: string }
	| { type: "proposal"; at: string; taskId: string; paths: string[]; description: string }
	| { type: "merge"; at: string; taskId: string; scope: "all" | "partial" | "none"; applied: string[]; archived: boolean }
	| { type: "retire"; at: string; taskId: string; removedWorktree: string; prunedBranch: string }
	| { type: "run:close"; at: string; tasks: number; entries: number; triggered: number; pending: number; requests: number };

export interface IntegrityCounts {
	tasks: number;
	entries: number;
	triggered: number;
	pending: number;
	requests: number;
}

export function journalPathOf(stateDir: string): string {
	return path.join(stateDir, "journal.jsonl");
}

export function appendJournal(stateDir: string, events: readonly JournalEvent[]): void {
	if (events.length === 0) return;
	fs.mkdirSync(stateDir, { recursive: true });
	const line = events.map((e) => JSON.stringify(e)).join("\n") + "\n";
	fs.appendFileSync(journalPathOf(stateDir), line, "utf8");
}

export function readJournal(stateDir: string): JournalEvent[] {
	const file = journalPathOf(stateDir);
	if (!fs.existsSync(file)) return [];
	const events: JournalEvent[] = [];
	for (const raw of fs.readFileSync(file, "utf8").split("\n")) {
		if (raw.trim() === "") continue;
		try {
			events.push(JSON.parse(raw) as JournalEvent);
		} catch {
			throw new TaskQueueError("state-corrupt", `journal line is not valid JSON: ${raw.slice(0, 80)}`);
		}
	}
	return events;
}

/** Archived copy of a worker's request document, kept with the record. */
export function archiveRequestPathOf(stateDir: string, requestId: string): string {
	return path.join(stateDir, "requests", `${requestId}.json`);
}

export function archiveRequest(stateDir: string, requestId: string, content: string): void {
	const p = archiveRequestPathOf(stateDir, requestId);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, content, "utf8");
}

export function readArchivedRequest(stateDir: string, requestId: string): WorkerRequest {
	const p = archiveRequestPathOf(stateDir, requestId);
	if (!fs.existsSync(p)) {
		throw new TaskQueueError(
			"state-corrupt",
			`no archived request document for ${requestId}; taskq_record archives every request before recording it`,
		);
	}
	// The archive holds the same bytes taskq_record validated, so the
	// archived document re-parses with the worker protocol validation; a
	// malformed archive is state corruption, not a worker protocol error.
	const raw = fs.readFileSync(p, "utf8");
	try {
		return parseWorkerRequest(raw, p);
	} catch (err) {
		throw new TaskQueueError(
			"state-corrupt",
			`the archived request ${requestId} is not a valid worker request: ${err instanceof Error ? err.message : String(err)}`,
		);
	}
}

/** Archived branch diff for a discarded track (verdict none). */
export function archiveDiffPathOf(stateDir: string, taskId: string): string {
	return path.join(stateDir, "archive", `${taskId}.diff`);
}

export function archiveDiff(stateDir: string, taskId: string, diff: string): void {
	const p = archiveDiffPathOf(stateDir, taskId);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, diff, "utf8");
}