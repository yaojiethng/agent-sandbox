/**
 * The ownership lock: the file-level mutual exclusion between the writers
 * of one state directory. The suite covers the acquire itself, the owner
 * metadata a crashed writer leaves behind, the break of a stale lock, and
 * the two-process case - one process holds the lock and delivers a break
 * point, the other tries to write from a stale load and is refused, so the
 * delivery survives exactly once (F1).
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import {
	LOCK_FILE,
	LOCK_SPIN_MS,
	LOCK_STALE_MS,
	acquireLock,
	beat,
	lockPathOf,
	ownerOf,
	pidAlive,
	readLockOwner,
	releaseLock,
	withOwnershipLock,
	type LockOwner,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/lock.ts";
import { Run } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { forkOp, joinOp } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { entryIdOf } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { readJournal } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { tmpdir, rmrf } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

/** A pid the kernel does not have, for the dead-owner fixture. */
function deadPid(): number {
	for (let pid = 40_000; pid < 42_000; pid++) {
		if (!pidAlive(pid)) return pid;
	}
	throw new Error("no free pid found for the stale-lock fixture");
}

function withTmp<T>(fn: (dir: string) => T): T {
	const dir = tmpdir();
	try {
		return fn(dir);
	} finally {
		rmrf(dir);
	}
}

function lockHeld(e: unknown): boolean {
	return e instanceof TaskQueueError && e.code === "lock-held";
}

/**
 * Resolve true once the child wrote the ready file, false if it died
 * without it. A child that writes the file and exits in the same tick -
 * the crash mode, which never releases its lock - still counts: the file
 * is read once more before the exit is called a failure.
 */
function waitForFile(file: string, child: ReturnType<typeof spawn>): Promise<boolean> {
	return new Promise<boolean>((resolve) => {
		const done = (ok: boolean): void => {
			clearTimeout(timer);
			clearInterval(poll);
			child.off("exit", gone);
			resolve(ok);
		};
		const gone = (): void => done(fs.existsSync(file));
		const timer = setTimeout(gone, 20_000);
		const poll = setInterval(() => {
			if (fs.existsSync(file)) done(true);
		}, 25);
		child.on("exit", gone);
	});
}

/** Resolve true once the child process has exited. */
function waitForExit(child: ReturnType<typeof spawn>): Promise<boolean> {
	return new Promise<boolean>((resolve) => {
		if (child.exitCode !== null) {
			resolve(true);
			return;
		}
		const timer = setTimeout(() => resolve(false), 20_000);
		child.on("exit", () => {
			clearTimeout(timer);
			resolve(true);
		});
	});
}

function holdLock(stateDir: string, ready: string, mode: "hold" | "crash"): ReturnType<typeof spawn> {
	const child = spawn(process.execPath, [path.join(import.meta.dirname, "fixtures", "lock-holder.ts"), stateDir, ready, mode], {
		stdio: ["ignore", "pipe", "pipe"],
	});
	// The child's output is collected, not dropped: a failure has to name
	// what the other writer said and how it ended.
	const log: string[] = [];
	child.stdout?.on("data", (d: Buffer) => log.push(String(d)));
	child.stderr?.on("data", (d: Buffer) => log.push(String(d)));
	child.on("exit", (code, signal) => {
		fs.writeFileSync(`${ready}.log`, `exit ${String(code)} ${String(signal)}\n${log.join("")}`, "utf8");
	});
	return child;
}

/** The child log, for a failure message. */
function childLog(ready: string): string {
	try {
		return fs.readFileSync(`${ready}.log`, "utf8");
	} catch {
		return "the child wrote nothing";
	}
}

describe("the ownership lock", () => {
	it("creates the lock with O_EXCL and removes it on release", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			const scope = { sessionId: "s1", taskId: "t1", worktree: path.join(dir, "wt") };
			withOwnershipLock(stateDir, scope, () => {
				assert.ok(fs.existsSync(lockPathOf(stateDir)), "the lock exists inside the critical section");
				const owner = readLockOwner(stateDir);
				assert.equal(owner?.pid, process.pid);
				assert.equal(owner?.sessionId, "s1");
				assert.equal(owner?.taskId, "t1");
				assert.equal(owner?.worktree, path.join(dir, "wt"));
				assert.ok(Date.parse(owner!.heartbeatAt) > 0);
				assert.ok(Date.parse(owner!.startedAt) > 0);
			});
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "the lock is released when the section ends");
		});
	});

	it("releases the lock when the critical section throws", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			assert.throws(() =>
				withOwnershipLock(stateDir, {}, () => {
					throw new Error("the derivation failed");
				}),
			);
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "a failed write does not leave the lock held");
		});
	});

	it("refuses a second acquisition while the owner is alive, and names it", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			const owner = ownerOf({ sessionId: "s1", taskId: "t1" });
			acquireLock(stateDir, owner, { spinMs: 30, sleep: () => {} });
			try {
				// A second acquirer in this process: its own pid is alive, so
				// the lock is reported rather than broken.
				assert.throws(() => acquireLock(stateDir, ownerOf({ sessionId: "s2" }), { spinMs: 30, sleep: () => {} }), (e) => {
					if (!lockHeld(e)) return false;
					const message = String((e as Error).message);
					return message.includes(`pid ${process.pid}`) && message.includes("one primary writes one state directory");
				});
			} finally {
				releaseLock(stateDir, owner);
			}
		});
	});

	it("breaks a lock whose owner is dead, and takes it over", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			fs.mkdirSync(stateDir, { recursive: true });
			const dead = deadPid();
			assert.equal(pidAlive(dead), false, "the fixture pid is not running");
			// The crashed owner's lock survives for inspection, then the next
			// acquirer breaks it.
			fs.writeFileSync(
				lockPathOf(stateDir),
				JSON.stringify({ pid: dead, sessionId: "s-dead", taskId: "t1", workdir: "/wt/t1", startedAt: AT, heartbeatAt: AT }, null, 2),
				"utf8",
			);
			assert.equal(readLockOwner(stateDir)?.sessionId, "s-dead", "the crashed owner's metadata is readable");
			withOwnershipLock(stateDir, { sessionId: "s-new" }, () => {
				assert.equal(readLockOwner(stateDir)?.sessionId, "s-new", "the takeover wrote its own metadata");
				assert.equal(readLockOwner(stateDir)?.pid, process.pid);
			});
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false);
		});
	});

	it("refuses to break a lock whose owner is alive and fresh", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			fs.mkdirSync(stateDir, { recursive: true });
			const at = new Date().toISOString();
			fs.writeFileSync(
				lockPathOf(stateDir),
				JSON.stringify({ pid: process.pid, sessionId: "s-live", taskId: "t1", workdir: "/wt/t1", startedAt: at, heartbeatAt: at }, null, 2),
				"utf8",
			);
			assert.throws(() => acquireLock(stateDir, ownerOf({ sessionId: "other" }), { spinMs: 30, sleep: () => {} }), lockHeld);
			assert.equal(readLockOwner(stateDir)?.sessionId, "s-live", "the live owner's lock is untouched");
		});
	});

	it("does not release a lock it no longer owns", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			const mine = ownerOf({ sessionId: "s1" });
			acquireLock(stateDir, mine);
			// Another writer took the directory over: this one must not delete
			// the new owner's lock on its way out.
			fs.writeFileSync(lockPathOf(stateDir), JSON.stringify({ pid: process.pid, sessionId: "s2", taskId: "", worktree: "", startedAt: "2026-01-01T00:00:00.000Z", heartbeatAt: "2026-01-01T00:00:00.000Z" }), "utf8");
			releaseLock(stateDir, mine);
			assert.equal(readLockOwner(stateDir)?.sessionId, "s2");
		});
	});

	it("the default spin budget bounds the wait instead of blocking forever", () => {
		assert.ok(LOCK_SPIN_MS > 0 && LOCK_SPIN_MS < 30_000, `spin budget out of range: ${LOCK_SPIN_MS}`);
		assert.equal(LOCK_FILE, "ownership.lock");
	});
});

describe("the lock heartbeat", () => {
	/**
	 * Age the heartbeat of a held lock, the way a long section leaves it:
	 * the file still names this process, and its `heartbeatAt` is older than
	 * the stale window.
	 */
	function ageHeartbeat(stateDir: string, ms: number): void {
		const file = lockPathOf(stateDir);
		const held = readLockOwner(stateDir)!;
		fs.writeFileSync(file, JSON.stringify({ ...held, heartbeatAt: new Date(Date.now() - ms).toISOString() }, null, 2), "utf8");
		assert.equal(readLockOwner(stateDir)?.pid, process.pid, "the aged lock is still this writer's");
	}

	it("keeps a long-held live lock from being broken, because the owner beats", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			const owner = ownerOf({ sessionId: "s1", taskId: "t1" });
			acquireLock(stateDir, owner, { spinMs: 30, sleep: () => {} });
			try {
				// A section that ran longer than the stale window without
				// beating: the heartbeat is the only liveness evidence on the
				// file, so a concurrent acquirer may take it.
				ageHeartbeat(stateDir, LOCK_STALE_MS + 1_000);
				acquireLock(stateDir, ownerOf({ sessionId: "s2" }), { spinMs: 30, sleep: () => {} });
				assert.equal(readLockOwner(stateDir)?.sessionId, "s2", "an un-beaten long section loses its lock");
				releaseLock(stateDir, { ...owner, startedAt: readLockOwner(stateDir)!.startedAt });
				// The same long window, the same live owner, one refresh: the
				// acquirer reports the owner instead of breaking the lock.
				acquireLock(stateDir, owner, { spinMs: 30, sleep: () => {} });
				ageHeartbeat(stateDir, LOCK_STALE_MS + 1_000);
				beat(stateDir, owner);
				assert.ok(Date.now() - Date.parse(readLockOwner(stateDir)!.heartbeatAt) < LOCK_STALE_MS, "the beat rewrote the heartbeat");
				assert.throws(
					() => acquireLock(stateDir, ownerOf({ sessionId: "s3" }), { spinMs: 30, sleep: () => {} }),
					lockHeld,
					"a concurrent acquirer reports the live owner",
				);
				assert.equal(readLockOwner(stateDir)?.sessionId, "s1", "the beating owner still holds its lock");
			} finally {
				releaseLock(stateDir, { ...owner, startedAt: readLockOwner(stateDir)?.startedAt ?? owner.startedAt });
			}
		});
	});

	it("beats only the lock this writer owns", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			const owner = ownerOf({ sessionId: "s1" });
			acquireLock(stateDir, owner, { spinMs: 30, sleep: () => {} });
			try {
				ageHeartbeat(stateDir, LOCK_STALE_MS + 1_000);
				// Another owner took the directory over: this writer's beat
				// must not stamp the new owner's liveness.
				const taken: LockOwner = { ...readLockOwner(stateDir)!, sessionId: "s2", startedAt: "2026-01-01T00:00:00.000Z" };
				fs.writeFileSync(lockPathOf(stateDir), JSON.stringify(taken, null, 2), "utf8");
				beat(stateDir, owner);
				assert.deepEqual(readLockOwner(stateDir), taken, "the new owner's lock is untouched");
				// A lock file that is gone is not recreated by a beat.
				fs.rmSync(lockPathOf(stateDir));
				beat(stateDir, owner);
				assert.equal(fs.existsSync(lockPathOf(stateDir)), false);
			} finally {
				fs.rmSync(lockPathOf(stateDir), { force: true });
			}
		});
	});

	it("the section hands its body the refresh, at every nesting level", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			withOwnershipLock(stateDir, { sessionId: "s1" }, () => {
				ageHeartbeat(stateDir, LOCK_STALE_MS + 1_000);
				// A nested section re-enters the lock; its beat belongs to the
				// outer owner, so a long inner step keeps the file alive.
				withOwnershipLock(stateDir, { sessionId: "s1" }, (inner) => inner.beat());
				assert.ok(Date.now() - Date.parse(readLockOwner(stateDir)!.heartbeatAt) < LOCK_STALE_MS, "the nested beat refreshed the outer lock");
			});
		});
	});

	it("refuses an asynchronous body, because the lock is held across a synchronous section", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			// The extension loads through jiti, where `any` erases the body
			// type, so the runtime guard is the one that holds. The cast
			// stands for what jiti hands the call.
			const body = async (): Promise<string> => "written after the lock was released";
			assert.throws(
				() => withOwnershipLock(stateDir, { sessionId: "s1" }, body as unknown as () => string),
				(e) => e instanceof TaskQueueError && e.code === "state-corrupt" && /a derive must be synchronous/.test(e.message),
			);
			// The refused section released the lock, so the directory is not
			// wedged by a body that never finished.
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "the refused section released the lock");
			assert.equal(withOwnershipLock(stateDir, { sessionId: "s1" }, () => "ok"), "ok", "a synchronous section still runs");
		});
	});

	it("refuses an asynchronous body nested inside another section", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, "state");
			assert.throws(
				() =>
					withOwnershipLock(stateDir, { sessionId: "s1" }, () => {
						const body = async (): Promise<string> => "written after the lock was released";
						return withOwnershipLock(stateDir, { sessionId: "s1" }, body as unknown as () => string);
					}),
				(e) => e instanceof TaskQueueError && e.code === "state-corrupt",
			);
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "the outer section released the lock it still held");
		});
	});
});

describe("two processes on one state directory", () => {
	it("refuses the second writer while the first holds the lock, and the delivery survives", async () => {
		const dir = tmpdir();
		let child: ReturnType<typeof spawn> | undefined;
		try {
			const stateDir = path.join(dir, "state");
			const ready = path.join(dir, "ready");
			// A forked task whose break point is not yet delivered: the child
			// delivers it, the parent tries to deliver the same one.
			const run = Run.open(stateDir, "/repo/main", AT);
			run.handle((s) => forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT));
			child = holdLock(stateDir, ready, "hold");
			assert.equal(await waitForFile(ready, child), true, `the child took the lock and delivered: ${childLog(ready)}`);

			// The parent's write is refused, not raced: the lock is owned by a
			// live process.
			const params = { taskId: "t1", requestId: "t1-1", status: "done" as const, head: "h1", changed: 1 };
			assert.throws(() => run.transact((s) => joinOp(s, params, AT), { taskId: "t1" }), (e) => {
				if (!lockHeld(e)) return false;
				const owner = readLockOwner(stateDir);
				return owner !== undefined && owner.pid !== process.pid && String((e as Error).message).includes(String(owner.pid));
			});
			// The delivery the child made survives the refused write.
			const state = run.current();
			assert.equal(state.entries.length, 1);
			assert.equal(state.entries[0].entryId, entryIdOf("t1", 1));
			assert.equal(state.entries[0].state, "triggered", "exactly one delivery (I1, I5)");
			assert.equal(state.tasks.t1.phase, "active");
			assert.equal(state.tasks.t1.lastSegmentHead, "h1");
			assert.deepEqual(
				readJournal(stateDir).map((e) => e.type),
				["run:open", "task:fork", "request:record", "entry:schedule", "entry:trigger"],
				"the refused write added no journal entry",
			);
			// With the owner gone, the same break point is still not
			// deliverable: the queue already holds it. The retry takes over
			// the dead owner's lock and reaches the queue, which refuses it
			// (I5).
			child.kill("SIGKILL");
			assert.equal(await waitForExit(child), true, "the lock holder is gone");
			assert.throws(() => run.transact((s) => joinOp(s, params, AT), { taskId: "t1" }), (e) => e instanceof TaskQueueError && e.code === "join-contended");
		} finally {
			child?.kill("SIGKILL");
			rmrf(dir);
		}
	});

	it("a writer takes over after the owner crashes, breaking the lock it left", async () => {
		const dir = tmpdir();
		try {
			const stateDir = path.join(dir, "state");
			const ready = path.join(dir, "ready");
			Run.open(stateDir, "/repo/main", AT);
			// The child delivers and exits without releasing: the lock file
			// survives with a dead owner's metadata, exactly as a killed writer
			// leaves it.
			const child = holdLock(stateDir, ready, "crash");
			assert.equal(await waitForFile(ready, child), true, `the child took the lock and delivered: ${childLog(ready)}`);
			assert.equal(await waitForExit(child), true, "the child exited without releasing the lock");
			const abandoned = readLockOwner(stateDir);
			assert.ok(abandoned, "the crashed owner's lock is on disk for inspection");
			assert.equal(pidAlive(abandoned!.pid), false, "its owner is gone");
			// The next acquirer reads the metadata, breaks the lock, and
			// completes its own write (I13).
			const run = Run.open(stateDir, "/repo/main", AT);
			const written = run.transact((s) => forkOp(s, { taskId: "t9", workdir: "/wt/t9", branch: "exp/t9", baseline: "b0", mainRoot: "/repo/main" }, AT), { taskId: "t9" });
			assert.equal(written.data.taskId, "t9", "the dead owner's lock was broken and the write landed");
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "the takeover released the lock");
			// The delivery the crashed process made is intact.
			assert.equal(run.current().entries[0].state, "triggered");
		} finally {
			rmrf(dir);
		}
	});
});
