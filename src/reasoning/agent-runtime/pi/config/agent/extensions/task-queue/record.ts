/**
 * The run record: an append-only journal of every state transition, plus
 * the archived worker request documents and archived diffs. The journal is
 * the primary's record of the run; tests and audits replay it to verify the
 * exactly-once identities (I1) and the transition ordering. Every event
 * type names a row of the transition table, so the journal is a replay of
 * that table rather than a parallel account of it.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import { parseWorkerRequest, type WorkerRequest } from "./protocol.ts";

export type JournalEvent =
	| { type: "run:open"; at: string; mainRoot: string }
	| { type: "task:fork"; at: string; taskId: string; workerId: string; workdir: string; branch: string; baseline: string }
	| { type: "task:requeue"; at: string; taskId: string; route: "in-place" | "fresh"; workdir: string; branch: string; from: string; to: string; entryId: string }
	| { type: "request:record"; at: string; entryId: string; taskId: string; requestId: string; status: "running" | "done" }
	| { type: "entry:schedule"; at: string; entryId: string; taskId: string }
	| { type: "entry:trigger"; at: string; entryId: string; taskId: string; head: string; changed: number }
	| { type: "verify"; at: string; taskId: string; outcome: "usable" | "not-usable"; entryId: string; notes: string }
	| { type: "proposal"; at: string; taskId: string; paths: string[]; description: string }
	| {
		type: "bringback";
		at: string;
		taskId: string;
		paths: string[];
		applied: string[];
		archived: boolean;
		removedWorktree: string;
		prunedBranch: string;
		/** True when the record infers an earlier attempt's write. */
		resumed: boolean;
	  }
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
			`no archived request document for ${requestId}; the join archives every request before it records it`,
		);
	}
	// The archive holds the same bytes the join validated, so the archived
	// document re-parses with the worker protocol validation; a malformed
	// archive is state corruption, not a worker protocol error.
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

/** Archived branch diff for a track whose bring-back wrote nothing back. */
export function archiveDiffPathOf(stateDir: string, taskId: string): string {
	return path.join(stateDir, "archive", `${taskId}.diff`);
}

export function archiveDiff(stateDir: string, taskId: string, diff: string): void {
	const p = archiveDiffPathOf(stateDir, taskId);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, diff, "utf8");
}

/**
 * The bring-back intent: the one file a bring-back writes before it does
 * any git work, and deletes in the same locked section that writes its
 * record. The prune precedes the record, so an interrupted bring-back is
 * resumable only if something says the write happened. A gone worktree
 * does not: the operator can remove a worktree and a branch by hand with
 * the two commands the fork refusal prints, and a call that refused at
 * the prune gate leaves a gone tree behind with no write either. The
 * intent record is this tool's own outbox, so the resume path reads
 * evidence rather than inferring it (I7, I12).
 */
export interface BringBackIntent {
	/** The file set this attempt wrote, or was about to write. */
	paths: string[];
	/** When the attempt started. */
	at: string;
	/**
	 * When the main-tree write, or the archive, completed. Absent while the
	 * attempt is still pending, and a resume refuses without it: an
	 * interrupted attempt that never reached its write proves nothing.
	 */
	writtenAt?: string;
}

export function bringBackIntentPathOf(stateDir: string, taskId: string): string {
	return path.join(stateDir, "bringback", `${taskId}.json`);
}

/** Record the intent before any git work, replacing an earlier attempt's. */
export function writeBringBackIntent(stateDir: string, taskId: string, intent: BringBackIntent): void {
	const p = bringBackIntentPathOf(stateDir, taskId);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, JSON.stringify(intent, null, 2), "utf8");
}

/** Mark the attempt's write as landed, so a resume can prove it. */
export function markBringBackWritten(stateDir: string, taskId: string, at: string): void {
	const intent = readBringBackIntent(stateDir, taskId);
	if (!intent) return;
	writeBringBackIntent(stateDir, taskId, { ...intent, writtenAt: at });
}

/**
 * The intent this tool wrote for a task, or undefined when there is none
 * to read. Unreadable bytes read as no intent: a resume must fail closed,
 * and the refusal it raises names the evidence that is missing.
 */
export function readBringBackIntent(stateDir: string, taskId: string): BringBackIntent | undefined {
	const p = bringBackIntentPathOf(stateDir, taskId);
	if (!fs.existsSync(p)) return undefined;
	try {
		const parsed = JSON.parse(fs.readFileSync(p, "utf8")) as Partial<BringBackIntent>;
		if (!Array.isArray(parsed.paths) || parsed.paths.some((p) => typeof p !== "string")) return undefined;
		return { paths: parsed.paths as string[], at: typeof parsed.at === "string" ? parsed.at : "", writtenAt: typeof parsed.writtenAt === "string" ? parsed.writtenAt : undefined };
	} catch {
		return undefined;
	}
}

/** Drop the intent once the record that replaces it is durable. */
export function clearBringBackIntent(stateDir: string, taskId: string): void {
	try {
		fs.unlinkSync(bringBackIntentPathOf(stateDir, taskId));
	} catch {
		// Already gone: the record it stood in for is written either way.
	}
}