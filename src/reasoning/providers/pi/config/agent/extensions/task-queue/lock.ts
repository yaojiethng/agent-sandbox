/**
 * The ownership lock: the file-level mutual exclusion between the writers of
 * one state directory.
 *
 * The state file is written by a load-derive-save cycle. An in-process
 * mutation queue serializes the tool calls of one turn, but nothing
 * serialized two *processes* on one state directory: a second primary could
 * read the state, make its own derivation, and write it back over the
 * first one's write, losing a break point. The lock closes that window
 * across processes, which is the only place the gap was.
 *
 * The lock is one file, `ownership.lock`, taken with O_EXCL: the create is
 * the test, so two acquirers cannot both win. A writer that finds the file
 * spins for a bounded budget and then reports the contention instead of
 * blocking forever, so a live owner is visible rather than waited out.
 *
 * The file carries its owner's metadata: pid, session id, task, worktree,
 * start time, and heartbeat. That is the crash-debug surface - it says
 * which process the directory expects to be working on it, so a lock left
 * behind by a crash can be read before it is broken, and a lock held by a
 * live process can be attributed. A lock whose owner is dead, or whose
 * heartbeat is stale, is broken and taken over; a close that was
 * interrupted therefore resumes rather than deadlocking (I13).
 *
 * Scoping: one primary per state directory. The lock serializes writers;
 * it does not make two primaries on one state directory a supported
 * configuration. A section nested inside another one in the same process
 * re-enters the lock rather than waiting for it: the process runs one
 * synchronous section at a time, so there is nothing to interleave with.
 *
 * A section body is synchronous by construction. The `finally` below runs
 * when the body returns, so an async body would release the lock at its
 * first await and the rest of the section would run on an unlocked state
 * directory. The body type forbids a promise, and `requireSync` refuses
 * one at runtime: the extension loads through jiti, where `any` erases the
 * type and the runtime guard is the one that holds.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";

/** The lock file inside the state directory. */
export const LOCK_FILE = "ownership.lock";

/** The bounded spin a writer spends on a held lock before it reports it. */
export const LOCK_SPIN_MS = 2_000;

/** The interval between two acquisition attempts inside the spin. */
export const LOCK_SPIN_INTERVAL_MS = 25;

/**
 * A lock with no readable owner, or with a heartbeat older than this, is
 * broken and taken over. The window is generous because the sections that
 * hold the lock are milliseconds long - but a bring-back also runs git,
 * and git is not bounded, so the window is a bound and not a promise. The
 * owner beats at every git step (`beat`), which is what keeps a long but
 * live section from being taken from it.
 */
export const LOCK_STALE_MS = 30_000;

export interface LockOwner {
	/** The operating-system process that holds the lock. */
	pid: number;
	/** The pi session of that process, when it has one. */
	sessionId: string;
	/** The task the writer is driving, when it drives one. */
	taskId: string;
	/** The worktree the writer is working on, when it has one. */
	worktree: string;
	startedAt: string;
	heartbeatAt: string;
}

export interface LockScope {
	sessionId?: string;
	taskId?: string;
	worktree?: string;
}

export interface LockOptions {
	/** The spin budget. Tests shorten it; production uses the constant. */
	spinMs?: number;
	/** The spin sleep. A seam so a test need not spend real milliseconds. */
	sleep?: (ms: number) => void;
}

export function lockPathOf(stateDir: string): string {
	return path.join(stateDir, LOCK_FILE);
}

/** True when a process exists; EPERM means it exists under another user. */
export function pidAlive(pid: number): boolean {
	if (!Number.isInteger(pid) || pid < 1) return false;
	try {
		process.kill(pid, 0);
		return true;
	} catch (err) {
		return (err as NodeJS.ErrnoException).code === "EPERM";
	}
}

/** The owner the lock file names, or undefined when it names none. */
export function readLockOwner(stateDir: string): LockOwner | undefined {
	let raw: string;
	try {
		raw = fs.readFileSync(lockPathOf(stateDir), "utf8");
	} catch {
		return undefined;
	}
	return parseOwner(raw);
}

/** The owner a lock file's bytes name, or undefined when they name none. */
function parseOwner(raw: string): LockOwner | undefined {
	try {
		const parsed = JSON.parse(raw) as Partial<LockOwner>;
		if (typeof parsed.pid !== "number") return undefined;
		return {
			pid: parsed.pid,
			sessionId: text(parsed.sessionId),
			taskId: text(parsed.taskId),
			worktree: text(parsed.worktree),
			startedAt: text(parsed.startedAt),
			heartbeatAt: text(parsed.heartbeatAt),
		};
	} catch {
		return undefined;
	}
}

function text(v: unknown): string {
	return typeof v === "string" ? v : "";
}

/** The owner a lock file is, rendered for a refusal the primary reads. */
export function describeOwner(owner: LockOwner | undefined): string {
	if (!owner) return "a process that left no readable metadata";
	const where = owner.worktree === "" ? "the run" : owner.worktree;
	const task = owner.taskId === "" ? "" : ` on task ${owner.taskId}`;
	return `pid ${owner.pid}${owner.sessionId === "" ? "" : ` session ${owner.sessionId}`}${task} in ${where} since ${owner.startedAt}`;
}

/** The metadata a writer stamps on the lock it takes. */
export function ownerOf(scope: LockScope): LockOwner {
	const at = new Date().toISOString();
	return {
		pid: process.pid,
		sessionId: scope.sessionId ?? "unknown",
		taskId: scope.taskId ?? "",
		worktree: scope.worktree ?? "",
		startedAt: at,
		heartbeatAt: at,
	};
}

/**
 * A lock nobody can account for: its owner is dead, or its heartbeat is
 * older than the stale window. An unreadable lock falls back to the file's
 * own modification time, so a crash between the create and the metadata
 * write is breakable once the window passes.
 */
function isStale(stateDir: string, owner: LockOwner | undefined, now: number): boolean {
	if (owner) {
		if (!pidAlive(owner.pid)) return true;
		const beat = Date.parse(owner.heartbeatAt);
		return Number.isFinite(beat) && now - beat > LOCK_STALE_MS;
	}
	try {
		return now - fs.statSync(lockPathOf(stateDir)).mtimeMs > LOCK_STALE_MS;
	} catch {
		// The file vanished between the failed create and this read: the
		// next attempt takes it.
		return true;
	}
}

/** Sleep without yielding the event loop; the critical section is sync. */
function syncSleep(ms: number): void {
	try {
		Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
	} catch {
		// A runtime without Atomics.wait: spin the clock out.
		const until = Date.now() + ms;
		while (Date.now() < until) {
			/* wait */
		}
	}
}

/**
 * Take the lock, or report the contention. The create is the test (O_EXCL),
 * so two acquirers cannot both win; a lock that is stale is broken and
 * taken over, which is what makes an interrupted writer recoverable.
 */
export function acquireLock(stateDir: string, owner: LockOwner, opts: LockOptions = {}): void {
	fs.mkdirSync(stateDir, { recursive: true });
	const lockPath = lockPathOf(stateDir);
	const spinMs = opts.spinMs ?? LOCK_SPIN_MS;
	const sleep = opts.sleep ?? syncSleep;
	const started = Date.now();
	for (;;) {
		try {
			const fd = fs.openSync(lockPath, "wx");
			try {
				fs.writeSync(fd, `${JSON.stringify({ ...owner, heartbeatAt: new Date().toISOString() }, null, 2)}\n`, "utf8");
			} finally {
				fs.closeSync(fd);
			}
			return;
		} catch (err) {
			if ((err as NodeJS.ErrnoException).code !== "EEXIST") {
				throw new TaskQueueError("lock-held", `cannot take the ownership lock ${lockPath}: ${String(err)}`);
			}
		}
		const held = readLockOwner(stateDir);
		if (isStale(stateDir, held, Date.now())) {
			// A crashed owner's lock survives for inspection until the next
			// acquirer reads it; this acquirer has read it and breaks it.
			try {
				fs.unlinkSync(lockPath);
			} catch {
				// Another acquirer broke it first: the retry below takes it.
			}
			continue;
		}
		if (Date.now() - started >= spinMs) {
			throw new TaskQueueError(
				"lock-held",
				`the state directory ${stateDir} is owned by ${describeOwner(held)}; one primary writes one state directory, and a live owner's lock is reported rather than broken. Wait for the owner, or inspect ${lockPath} and remove it by hand if the owner is gone`,
			);
		}
		sleep(LOCK_SPIN_INTERVAL_MS);
	}
}

/**
 * Refresh this writer's heartbeat: rewrite `heartbeatAt` on the lock it
 * holds, so a long section that outlives the stale window is not taken
 * from a live owner. The rewrite happens only while the file still names
 * this writer - same pid and same start - so a writer whose lock was
 * broken and taken over never stamps the new owner's lock with its own
 * liveness. A file that disappeared, or names another owner, is left
 * alone.
 */
export function beat(stateDir: string, owner: LockOwner): void {
	let fd: number;
	try {
		fd = fs.openSync(lockPathOf(stateDir), "r+");
	} catch {
		// The lock file is gone or unreadable: the next acquirer takes a
		// free directory, and the release is what reports the takeover.
		return;
	}
	try {
		// The ownership test reads the bytes of the file this descriptor
		// opened, and the write goes back to that same descriptor. A
		// takeover that unlinks and recreates the lock between the two
		// therefore cannot have this beat stamp the new owner's file: the
		// write lands on the unlinked inode.
		const held = parseOwner(fs.readFileSync(fd, "utf8"));
		if (!held || held.pid !== owner.pid || held.startedAt !== owner.startedAt) return;
		const text = `${JSON.stringify({ ...held, heartbeatAt: new Date().toISOString() }, null, 2)}\n`;
		fs.ftruncateSync(fd, fs.writeSync(fd, text, 0, "utf8"));
	} catch {
		// The lock bytes are not readable as an owner: the acquirer's own
		// read decides what the file says.
	} finally {
		fs.closeSync(fd);
	}
}

/** Release the lock, but only when this writer is the owner it names. */
export function releaseLock(stateDir: string, owner: LockOwner): void {
	const held = readLockOwner(stateDir);
	if (held && (held.pid !== owner.pid || held.startedAt !== owner.startedAt)) return;
	try {
		fs.unlinkSync(lockPathOf(stateDir));
	} catch {
		// Already gone: nothing to release.
	}
}

/**
 * The critical sections this process currently holds, by state directory,
 * each with the owner whose heartbeat `beat` refreshes. A section nested
 * inside another one in the same process needs no second file lock: the
 * sections are synchronous and the process runs one of them at a time, so
 * there is no interleaving to prevent. Only the outermost section takes
 * and releases the file; the inner one beats under the outer one's owner.
 */
const heldSections = new Map<string, LockOwner>();

/** What a critical section hands its body: the liveness refresh. */
export interface SectionLive {
	/** Rewrite this writer's heartbeat; call it at every long git step. */
	beat: () => void;
}

/**
 * The return type of a section body, with a promise removed. A section
 * holds the lock across a synchronous body, so a body that answers with a
 * promise is not a body this lock can hold. The body type takes this as an
 * intersection with the plain `T` rather than as `fn: () => SyncResult<T>`
 * alone: the naked `T` keeps the inference site, and the conditional stays
 * a check applied to the inferred type.
 */
export type SyncResult<T> = T extends PromiseLike<unknown> ? never : T;

/**
 * The refusal an async body gets, at the point the lock is released. The
 * parameter is a plain `T`: the type-level check is the body type's, and
 * this is the runtime half, which the extension needs because jiti erases
 * that type.
 */
export function requireSync<T>(result: T): T {
	if (result instanceof Promise) {
		throw new TaskQueueError(
			"state-corrupt",
			"a derive must be synchronous: the ownership lock is held across a synchronous section, and a promise releases the lock at its first await",
		);
	}
	return result;
}

/**
 * Run one critical section under the lock: the complete load-derive-save of
 * a state-mutating tool call, and any git work the call must not
 * interleave with another writer's. The body receives the heartbeat it
 * refreshes between its git steps, because a section that outlives
 * `LOCK_STALE_MS` would otherwise have its live lock taken from it.
 */
export function withOwnershipLock<T>(stateDir: string, scope: LockScope, fn: (live: SectionLive) => T & SyncResult<T>, opts: LockOptions = {}): T {
	const key = path.resolve(stateDir);
	const outer = heldSections.get(key);
	if (outer) {
		return requireSync(fn({ beat: () => beat(stateDir, outer) }));
	}
	const owner = ownerOf(scope);
	acquireLock(stateDir, owner, opts);
	heldSections.set(key, owner);
	try {
		return requireSync(fn({ beat: () => beat(stateDir, owner) }));
	} finally {
		heldSections.delete(key);
		releaseLock(stateDir, owner);
	}
}
