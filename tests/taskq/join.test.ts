/**
 * The join: the primary's one blocking call through which a break point is
 * waited for and delivered, against real repositories and the real worker
 * protocol. The suite holds the join's contract (J1-J5), the fork's
 * worktree contract (W1-W3), and the written-loop closure (S1): the loop
 * drives from fork to close through the join, and the queue invariants hold
 * at every stage.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { forkOp, joinOp, recordOp, verifyOp, proposalOp, bringBackOp, requeueOp, closeOp } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { heldBreakPoint, scanReady, waitForBreakPoint, type JoinPayload, type JoinResult, type JoinRun } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/join.ts";
import { readJournal, archiveRequest, archiveRequestPathOf } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { addWorktree, assertWorkdirFree, canonicalWorkdir, listBranches, listWorktrees, pruneWorktree, runIdOf, statusPorcelain, worktreeHead, worktreeRootOf } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyBringBack, archiveTrack } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { makeMainRepo, rmrf, tmpdir, commitAll, workerRequest, workerSegment, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

/** The persisted face the join drives, backed by the real Run facade. */
function joiner(run: Run): JoinRun {
	return {
		stateDir: run.stateDir,
		current: () => run.current(),
		join: (p) => run.handle((s) => joinOp(s, p, AT)),
	};
}

interface Fixture {
	dir: string;
	root: string;
	baseline: string;
	run: Run;
}

function fixture(): Fixture {
	const dir = tmpdir();
	const { root, baseline } = makeMainRepo(dir);
	const run = Run.open(path.join(dir, ".taskq-test"), root, AT);
	return { dir, root, baseline, run };
}

/** Fork one task the way the fork tool does: canonical path, default branch. */
function forkTask(f: Fixture, taskId: string): string {
	const workdir = canonicalWorkdir(f.root, f.run.stateDir, taskId);
	const branch = `exp/${taskId}`;
	addWorktree(f.root, { branch, path: workdir, baseline: f.baseline });
	f.run.handle((s) => forkOp(s, { taskId, workdir, branch, baseline: f.baseline, mainRoot: f.root }, AT));
	return workdir;
}

function joined(result: JoinResult): JoinPayload {
	assert.equal(result.outcome, "joined", `expected a delivery, got ${result.outcome}: ${JSON.stringify(result)}`);
	return result as JoinPayload;
}

function journalTypes(f: Fixture): string[] {
	return readJournal(f.run.stateDir).map((e) => e.type);
}

describe("join: atomic subsume (J1)", () => {
	it("delivers one break point and leaves the queue resting only in triggered", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "src/alpha.ts": "v1\n" }, "running", "alpha ready");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.equal(result.entryId, "t1#1");
			assert.equal(result.requestStatus, "running");
			assert.equal(result.message, "alpha ready");
			assert.deepEqual(result.segmentChanged, ["src/alpha.ts"]);
			// The delivery is the three transitions in one write: the journal
			// carries them together, and no state file ever rests in the
			// requested or scheduled state.
			assert.deepEqual(journalTypes(f).slice(2), ["request:record", "entry:schedule", "entry:trigger"]);
			assert.deepEqual(
				f.run.current().entries.map((e) => e.state),
				["triggered"],
			);
			// The archive holds the exact bytes the queue admitted.
			assert.ok(fs.existsSync(archiveRequestPathOf(f.run.stateDir, "t1-1")));
		} finally {
			rmrf(f.dir);
		}
	});

	it("heals an entry a prior surface queued: the join finishes the transition", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "src/alpha.ts": "v1\n" }, "done", "terminal");
			// A state written before the join existed: the entry is queued and
			// nothing has scheduled it.
			f.run.handle((s) => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: wt }, AT));
			archiveRequest(f.run.stateDir, "t1-1", JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done", message: "terminal", at: AT }));
			assert.equal(f.run.current().entries[0].state, "requested");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.equal(result.entryId, "t1#1");
			assert.equal(result.message, "terminal");
			assert.equal(f.run.current().entries[0].state, "triggered");
			assert.equal(f.run.current().tasks.t1.workerDone, true);
			// The heal adds no second entry and no second request (I1).
			assert.equal(f.run.current().entries.length, 1);
			assert.equal(Object.keys(f.run.current().requests).length, 1);
		} finally {
			rmrf(f.dir);
		}
	});

	it("reports contention instead of delivering a break point twice (I5)", () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			f.run.handle((s) => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: wt }, AT));
			archiveRequest(f.run.stateDir, "t1-1", JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done", message: "terminal", at: AT }));
			const params = { taskId: "t1", requestId: "t1-1", status: "done" as const, head: "h", changed: 1 };
			f.run.handle((s) => joinOp(s, params, AT));
			// The second delivery of the same break point is not a delivery.
			assert.throws(
				() => f.run.handle((s) => joinOp(s, params, AT)),
				(e) => e instanceof TaskQueueError && e.code === "join-contended",
			);
			// The queue is unchanged by the refused call (I12).
			assert.equal(f.run.current().entries.length, 1);
			assert.equal(f.run.current().entries[0].state, "triggered");
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a break point on a task that is closed to segments", () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			f.run.handle((s) => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: wt }, AT));
			archiveRequest(f.run.stateDir, "t1-1", JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done", message: "terminal", at: AT }));
			// A task verified while an entry of it is still queued: the join
			// must not heal that entry forward.
			f.run.handle((s) => ({
				state: { ...s, tasks: { ...s.tasks, t1: { ...s.tasks.t1, phase: "terminated" as const } } },
				events: [],
				data: undefined,
			}));
			assert.equal(f.run.current().entries[0].state, "requested");
			assert.throws(
				() => f.run.handle((s) => joinOp(s, { taskId: "t1", requestId: "t1-1", status: "done", head: "h", changed: 1 }, AT)),
				(e) => e instanceof TaskQueueError && e.code === "task-phase",
			);
			assert.equal(f.run.current().entries[0].state, "requested");
		} finally {
			rmrf(f.dir);
		}
	});

	it("re-scans a contended delivery and still delivers, then surfaces a state that keeps contending", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			const base = joiner(f.run);
			// A delivery that contends once - another join took the break
			// point between the scan and the write - is a re-scan, not a
			// delivery and not an error.
			let contended = 0;
			const flaky: JoinRun = {
				...base,
				join: async (p) => {
					if (contended === 0) {
						contended += 1;
						throw new TaskQueueError("join-contended", "another join delivered this break point");
					}
					return base.join(p);
				},
			};
			const delivered = joined(await waitForBreakPoint(flaky, { timeoutMs: 1000, pollMs: 10 }));
			assert.equal(contended, 1, "the contended call was retried, not surfaced");
			assert.equal(delivered.entryId, "t1#1");
			// A state that never stops contending surfaces the code instead of
			// spinning: the re-scan is bounded.
			let attempts = 0;
			const wedged: JoinRun = {
				...base,
				join: async () => {
					attempts += 1;
					throw new TaskQueueError("join-contended", "another join delivered this break point");
				},
			};
			workerSegment(wt, "t1", { "b.ts": "v1\n" }, "done", "second");
			await assert.rejects(
				waitForBreakPoint(wedged, { timeoutMs: 1000, pollMs: 10 }),
				(e) => e instanceof TaskQueueError && e.code === "join-contended",
			);
			assert.equal(attempts, 4, "three re-scans, then the code reaches the caller");
			// The refused deliveries changed nothing (I12).
			assert.equal(f.run.current().entries.length, 1);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("join: exactly-once delivery (J2)", () => {
	it("two joins racing one request deliver it once", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			const run = joiner(f.run);
			const [first, second] = await Promise.all([
				waitForBreakPoint(run, { timeoutMs: 2000, pollMs: 10 }),
				waitForBreakPoint(run, { timeoutMs: 2000, pollMs: 10 }),
			]);
			const outcomes = [first.outcome, second.outcome].sort();
			// The loser delivered nothing: the winner's payload is what the
			// operator holds, and the loser reports the hold or the wait.
			assert.deepEqual(outcomes, ["held", "joined"]);
			const state = f.run.current();
			assert.equal(state.entries.length, 1);
			assert.equal(Object.keys(state.requests).length, 1);
			assert.equal(state.entries.filter((e) => e.state === "triggered").length, 1);
			assert.equal(journalTypes(f).filter((t) => t === "entry:trigger").length, 1);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a request that arrives mid-join is neither lost nor doubled", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "running", "first");
			const base = joiner(f.run);
			let landed = false;
			// The second segment lands while the first delivery is in flight.
			const run: JoinRun = {
				...base,
				join: async (p) => {
					if (!landed) {
						landed = true;
						workerSegment(wt, "t1", { "b.ts": "v1\n" }, "done", "second");
					}
					return base.join(p);
				},
			};
			const first = joined(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10 }));
			assert.equal(first.entryId, "t1#1");
			const second = joined(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10 }));
			assert.equal(second.entryId, "t1#2");
			assert.equal(second.requestStatus, "done");
			// Each request entered once and triggered once (I1, I5).
			const state = f.run.current();
			assert.deepEqual(
				state.entries.map((e) => [e.entryId, e.requestId, e.state]),
				[
					["t1#1", "t1-1", "triggered"],
					["t1#2", "t1-2", "triggered"],
				],
			);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("join: blocking, timeout required and inert (J3)", () => {
	it("blocks until a worker request lands, then delivers it", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			// The worker lands its segment after the join is already waiting.
			setTimeout(() => workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal"), 120);
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 10_000, pollMs: 20 }));
			assert.equal(result.entryId, "t1#1");
			assert.ok(result.waitedMs >= 100, `the call waited for the worker: ${result.waitedMs}ms`);
		} finally {
			rmrf(f.dir);
		}
	});

	it("times out with nothing consumed, scheduled, or triggered (I12)", async () => {
		const f = fixture();
		try {
			forkTask(f, "t1");
			forkTask(f, "t2");
			const before = f.run.current();
			const result = await waitForBreakPoint(joiner(f.run), { timeoutMs: 150, pollMs: 20 });
			assert.equal(result.outcome, "timeout");
			if (result.outcome !== "timeout") throw new Error("unreachable");
			assert.equal(result.timeoutMs, 150);
			assert.deepEqual(result.waiting, ["t1", "t2"]);
			assert.ok(result.waitedMs >= 150);
			// Nothing moved: no entry, no request, no journal event.
			const after = f.run.current();
			assert.deepEqual(after.entries, []);
			assert.deepEqual(after.requests, {});
			assert.deepEqual(journalTypes(f), ["run:open", "task:fork", "task:fork"]);
			assert.deepEqual(before.tasks.t1, after.tasks.t1);
		} finally {
			rmrf(f.dir);
		}
	});

	it("an aborted wait returns without consuming anything", async () => {
		const f = fixture();
		try {
			forkTask(f, "t1");
			const controller = new AbortController();
			setTimeout(() => controller.abort(), 60);
			const result = await waitForBreakPoint(joiner(f.run), { timeoutMs: 10_000, pollMs: 20, signal: controller.signal });
			assert.equal(result.outcome, "aborted");
			assert.deepEqual(f.run.current().entries, []);
			assert.deepEqual(journalTypes(f), ["run:open", "task:fork"]);
		} finally {
			rmrf(f.dir);
		}
	});

	it("names the uncommitted paths the segment does not carry", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			// A deliverable the worker never committed: the branch diff misses it.
			writeFile(wt, "uncommitted.txt", "not in the segment\n");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.deepEqual(result.uncommitted, ["uncommitted.txt"]);
			assert.ok(result.notices.some((n) => n.includes("uncommitted path(s)")));
		} finally {
			rmrf(f.dir);
		}
	});

	it("names a request document a task the queue closed can never admit", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			f.run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT));
			// A worker that runs past its terminal break point writes another
			// document. The task is terminated, so no join row admits it, and
			// the document would otherwise sit in the worktree unseen.
			workerRequest(wt, "t1", "running", "one more thing");
			const result = await waitForBreakPoint(joiner(f.run), { timeoutMs: 150, pollMs: 20 });
			assert.equal(result.outcome, "timeout");
			assert.ok(
				result.notices.some((n) => n.includes("t1-2") && n.includes("cannot be admitted") && n.includes("terminated")),
				`the notice names the document and the phase: ${JSON.stringify(result.notices)}`,
			);
			// The document is not admitted, and the queue did not move.
			assert.deepEqual(f.run.current().entries.map((e) => e.requestId), ["t1-1"]);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a delivery whose segment base moved under it, and re-scans", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "first segment");
			const first = worktreeHead(wt);
			// A second commit lands after the request: the join measures the
			// segment from the baseline and reads the newer head.
			writeFile(wt, "b.ts", "v1\n");
			commitAll(wt, "seg 2");
			let attempts = 0;
			const moving: JoinRun = {
				stateDir: f.run.stateDir,
				current: () => f.run.current(),
				join: (p) => {
					attempts += 1;
					if (attempts === 1) {
						// Another writer delivered a segment under this join, so
						// the state the derive loads names a different segment
						// base than the payload was measured from.
						f.run.handle((s) => ({ state: { ...s, tasks: { ...s.tasks, t1: { ...s.tasks.t1, lastSegmentHead: first } } }, events: [], data: undefined }));
					}
					return f.run.handle((s) => joinOp(s, p, AT));
				},
			};
			const result = joined(await waitForBreakPoint(moving, { timeoutMs: 1000 }));
			assert.equal(attempts, 2, "the refused delivery was re-scanned, not re-applied");
			// The payload reports the segment from the base the state names,
			// which is the segment a re-queue rolls back to.
			assert.deepEqual(result.segmentChanged, ["b.ts"]);
			assert.equal(f.run.current().tasks.t1.lastSegmentHead, worktreeHead(wt));
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("join: one held break point (J4)", () => {
	it("reports the undecided break point and names the step that clears it", async () => {
		const f = fixture();
		try {
			const wt1 = forkTask(f, "t1");
			const wt2 = forkTask(f, "t2");
			workerSegment(wt1, "t1", { "a.ts": "v1\n" }, "running", "t1 first segment");
			workerSegment(wt2, "t2", { "b.ts": "v1\n" }, "done", "t2 terminal");
			const run = joiner(f.run);
			const first = joined(await waitForBreakPoint(run, { timeoutMs: 1000 }));
			assert.equal(first.taskId, "t1");
			// t1's break point is undecided and t2's is ready: the join reports
			// the hold instead of delivering a second payload.
			const held = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(held.outcome, "held");
			if (held.outcome !== "held") throw new Error("unreachable");
			assert.equal(held.hold.taskId, "t1");
			assert.equal(held.hold.entryId, "t1#1");
			assert.equal(held.hold.requestStatus, "running");
			assert.ok(held.hold.clearsBy.includes("next request"));
			assert.deepEqual(held.waiting, ["t1", "t2"]);
			// The hold delivered nothing: t2's break point is still queued.
			assert.deepEqual(f.run.current().entries.map((e) => [e.entryId, e.state]), [["t1#1", "triggered"]]);
			// Clearing the hold - the worker re-requests - releases the join.
			workerSegment(wt1, "t1", { "a.ts": "v2\n" }, "done", "t1 terminal");
			const next = joined(await waitForBreakPoint(run, { timeoutMs: 1000 }));
			assert.equal(next.taskId, "t1");
			assert.equal(next.entryId, "t1#2");
			// t1 is terminal now: the hold waits for the verification, and t2
			// waits beside it.
			const heldAgain = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(heldAgain.outcome, "held");
			if (heldAgain.outcome !== "held") throw new Error("unreachable");
			assert.equal(heldAgain.hold.requestStatus, "done");
			assert.ok(heldAgain.hold.clearsBy.includes("taskq_verify"));
			f.run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT));
			const other = joined(await waitForBreakPoint(run, { timeoutMs: 1000 }));
			assert.equal(other.taskId, "t2");
		} finally {
			rmrf(f.dir);
		}
	});

	it("a re-request disarms the hold without a state write", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "running", "first");
			const run = joiner(f.run);
			await waitForBreakPoint(run, { timeoutMs: 1000 });
			workerSegment(wt, "t1", { "a.ts": "v2\n" }, "running", "second");
			const state = f.run.current();
			assert.equal(heldBreakPoint(run, state, scanReady(state)), undefined, "the worker re-requested, so nothing holds");
			const next = joined(await waitForBreakPoint(run, { timeoutMs: 1000 }));
			assert.equal(next.entryId, "t1#2");
		} finally {
			rmrf(f.dir);
		}
	});

	it("a terminal hold carries the worker's message and clears at the verification", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "the report is written, read it");
			const run = joiner(f.run);
			await waitForBreakPoint(run, { timeoutMs: 1000 });
			const held = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(held.outcome, "held");
			if (held.outcome !== "held") throw new Error("unreachable");
			// The operator can be re-oriented from a hold alone: a session that
			// resumes into it never read the request document.
			assert.equal(held.hold.message, "the report is written, read it");
			// A worker that requests again after its terminal request decided
			// the hold; the next break point is the live one.
			workerSegment(wt, "t1", { "a.ts": "v2\n" }, "done", "correction");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).entryId, "t1#2");
		} finally {
			rmrf(f.dir);
		}
	});

	it("the hold after a re-queue waits for the worker's next segment, not the answered audit", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "the segment does not hold");
			const run = joiner(f.run);
			await waitForBreakPoint(run, { timeoutMs: 1000 });
			f.run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "not-usable", notes: "the segment does not hold" }, AT));
			// Before the re-queue, the hold names the re-queue the primary owes.
			const owed = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(owed.outcome, "held");
			if (owed.outcome !== "held") throw new Error("unreachable");
			assert.ok(owed.hold.clearsBy.includes("taskq_requeue"), `the not-usable audit names the re-queue: ${owed.hold.clearsBy}`);
			// The primary takes the re-queue.
			f.run.handle((s) => requeueOp(s, { taskId: "t1", route: "in-place", head: f.run.current().tasks.t1.lastSegmentHead }, AT));
			// The hold now names the next segment. Naming the answered audit
			// again would point the operator gate at a step already taken.
			const after = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(after.outcome, "held", "the re-queued task still holds the join until the worker requests again");
			if (after.outcome !== "held") throw new Error("unreachable");
			assert.equal(after.hold.entryId, "t1#1");
			assert.equal(after.hold.requestStatus, "running");
			assert.ok(after.hold.clearsBy.includes("next request"), `the hold waits for the worker: ${after.hold.clearsBy}`);
			assert.ok(!after.hold.clearsBy.includes("taskq_requeue"), "the answered re-queue is not named again");
			// The audit itself stays on the record; only the branch moved.
			assert.equal(f.run.current().tasks.t1.verification?.outcome, "not-usable", "the audit record is history, not a pending decision");
			assert.equal(f.run.current().tasks.t1.requeuedFromEntryId, "t1#1");
			assert.equal(f.run.current().tasks.t1.phase, "active");
			// The worker's next request clears the hold and delivers the
			// repair segment.
			workerSegment(wt, "t1", { "a.ts": "v2\n" }, "done", "the report is written now");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).entryId, "t1#2");
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("join: order-safe selection (J5)", () => {
	it("delivers a task's break points in request order, racing worker included (I2)", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "running", "first");
			// The worker raced its own hold and wrote a second request.
			workerSegment(wt, "t1", { "b.ts": "v1\n" }, "done", "second");
			const run = joiner(f.run);
			const first = await waitForBreakPoint(run, { timeoutMs: 1000 });
			// The first scan names the race to the operator.
			assert.ok(first.notices.some((n) => n.includes("t1-1, t1-2") && n.includes("requested again")));
			assert.equal(joined(first).entryId, "t1#1");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).entryId, "t1#2");
			// The sequence gate holds: the entries trigger in request order.
			assert.deepEqual(
				f.run.current().entries.map((e) => e.requestSeq),
				[1, 2],
			);
		} finally {
			rmrf(f.dir);
		}
	});

	it("takes the named task across a fan-out and the earliest fork otherwise", async () => {
		const f = fixture();
		try {
			const wt1 = forkTask(f, "t1");
			const wt2 = forkTask(f, "t2");
			workerSegment(wt1, "t1", { "a.ts": "v1\n" }, "done", "t1 terminal");
			workerSegment(wt2, "t2", { "b.ts": "v1\n" }, "done", "t2 terminal");
			const run = joiner(f.run);
			// The default order is the fork order; the named task overrides it.
			assert.deepEqual(scanReady(f.run.current()).candidates.map((c) => c.taskId), ["t1", "t2"]);
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000, taskId: "t2" })).taskId, "t2");
			// Nothing of t1 was consumed by the named join.
			assert.deepEqual(f.run.current().entries.map((e) => [e.entryId, e.state]), [["t2#1", "triggered"]]);
			// t2's terminal break point is now the one that holds the join, so
			// the un-named call above it gets the hold, not a second payload.
			const held = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(held.outcome, "held");
			f.run.handle((s) => verifyOp(s, { taskId: "t2", outcome: "usable", notes: "ok" }, AT));
			// The default is the earliest forked task still ready.
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).taskId, "t1");
			// The fan-out is drained, so the join reports the hold the terminal
			// break point still is: nothing waits, one break point does.
			const drained = await waitForBreakPoint(run, { timeoutMs: 1000 });
			assert.equal(drained.outcome, "held");
			if (drained.outcome !== "held") throw new Error("unreachable");
			assert.equal(drained.hold.taskId, "t1");
		} finally {
			rmrf(f.dir);
		}
	});

	it("skips a broken request document and says so", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			// A hand-written document that does not parse: it must not wedge
			// the join or be admitted.
			writeFile(wt, "taskq/requests/t1-2.json", "{ not json");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.equal(result.entryId, "t1#1");
			assert.ok(result.notices.some((n) => n.includes("t1-2") && n.includes("not a valid worker request")));
			assert.equal(f.run.current().entries.length, 1);
		} finally {
			rmrf(f.dir);
		}
	});
	it("skips a request document whose name and content disagree", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			// The queue keys the request and its archive by one id, so a
			// hand-written document that carries another is not admitted.
			writeFile(wt, "taskq/requests/t1-9.json", JSON.stringify({ taskId: "t1", requestId: "t1-1", status: "done", message: "m", at: AT }));
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.equal(result.entryId, "t1#1");
			assert.ok(result.notices.some((n) => n.includes("t1-9") && n.includes("carries id t1-1")));
			// The archive and the entry agree on one id.
			assert.ok(fs.existsSync(archiveRequestPathOf(f.run.stateDir, "t1-1")));
			assert.equal(f.run.current().entries.length, 1);
		} finally {
			rmrf(f.dir);
		}
	});

	it("leaves the protocol directory out of the segment the operator judges", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			// A worker that committed its request document: the bookkeeping
			// is in the branch diff, and the deliverable is not.
			commitAll(wt, "protocol files");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.deepEqual(result.segmentChanged, ["a.ts"]);
			assert.ok(!result.segmentStat.includes("taskq/"), result.segmentStat);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("join: archived request bytes and argument validation (F4-F7)", () => {
	it("archives the exact bytes of the request document it admitted (F4)", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			workerSegment(wt, "t1", { "a.ts": "v1\n" }, "done", "terminal");
			// A hand-written document with its own spacing and an extra field:
			// the archive must hold these bytes, not a re-serialization of the
			// parsed object.
			const file = path.join(wt, "taskq/requests/t1-1.json");
			fs.rmSync(file, { force: true });
			const raw = '{\n  "taskId": "t1",\n\t"requestId": "t1-1",\n  "status": "done",\n  "message": "the report is written",\n  "at": "2026-01-01T00:00:00.000Z",\n  "workerNote": "kept verbatim"\n}\n';
			fs.writeFileSync(file, raw, "utf8");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.equal(result.message, "the report is written", "the admitted document parsed");
			assert.equal(fs.readFileSync(archiveRequestPathOf(f.run.stateDir, "t1-1"), "utf8"), raw, "the archive holds the validated bytes");
		} finally {
			rmrf(f.dir);
		}
	});

	it("reports no deliverable for a protocol-only segment instead of the protocol diff (F5)", async () => {
		const f = fixture();
		try {
			const wt = forkTask(f, "t1");
			// A worker whose only commit is its own request document: there is
			// nothing to bring back, and the stat must not widen to the whole
			// diff, which would report the protocol files as the segment.
			workerRequest(wt, "t1", "done", "protocol only");
			commitAll(wt, "the request document");
			const result = joined(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000 }));
			assert.deepEqual(result.segmentChanged, []);
			assert.ok(!result.segmentStat.includes("taskq/"), result.segmentStat);
			assert.equal(result.segmentStat, "(no deliverable change since the last break point)");
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses an unknown task id at once, not at the end of the timeout (F6)", async () => {
		const f = fixture();
		try {
			forkTask(f, "t1");
			const started = Date.now();
			await assert.rejects(
				waitForBreakPoint(joiner(f.run), { timeoutMs: 60_000, taskId: "nope" }),
				(e) => e instanceof TaskQueueError && e.code === "task-unknown" && e.message.includes("t1"),
			);
			assert.ok(Date.now() - started < 5_000, `the refusal is immediate: ${Date.now() - started}ms`);
			assert.deepEqual(f.run.current().entries, [], "nothing was consumed");
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a timeout that is not a finite number at once (F7)", async () => {
		const f = fixture();
		try {
			forkTask(f, "t1");
			for (const timeoutMs of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
				const started = Date.now();
				await assert.rejects(
					waitForBreakPoint(joiner(f.run), { timeoutMs }),
					(e) => e instanceof TaskQueueError && e.code === "request-invalid" && e.message.includes("timeoutMs"),
					`timeoutMs ${String(timeoutMs)} must be refused`,
				);
				assert.ok(Date.now() - started < 5_000, `the refusal for ${String(timeoutMs)} is immediate`);
			}
			assert.deepEqual(f.run.current().entries, [], "nothing was consumed");
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("fork worktree contract (W1-W3)", () => {
	it("refuses a task id that is a path, not a name (W1)", () => {
		const f = fixture();
		try {
			// A `..` in a task id would walk out of the run's worktree root,
			// and two runs would share the path it reached.
			for (const taskId of ["../../escaped", "nested/t1", ".", ".."]) {
				assert.throws(() => canonicalWorkdir(f.root, f.run.stateDir, taskId), (e) => {
					if (!(e instanceof TaskQueueError) || e.code !== "worktree-occupied") return false;
					return e.message.includes(worktreeRootOf(f.root, f.run.stateDir));
				});
			}
			// A plain name stays under the run root.
			assert.equal(canonicalWorkdir(f.root, f.run.stateDir, "t1"), path.join(worktreeRootOf(f.root, f.run.stateDir), "t1"));
		} finally {
			rmrf(f.dir);
		}
	});

	it("derives one canonical run-scoped worktree per task, outside the main tree", () => {
		const f = fixture();
		try {
			const root = path.resolve(f.root);
			const workdir = canonicalWorkdir(root, f.run.stateDir, "t1");
			assert.equal(workdir, path.join(worktreeRootOf(root, f.run.stateDir), "t1"));
			assert.ok(workdir.startsWith(`${path.dirname(root)}${path.sep}`), "the worktree is a sibling of the main tree");
			assert.ok(!workdir.startsWith(`${root}${path.sep}`), "the worktree is never inside the main tree");
			assert.match(path.basename(worktreeRootOf(root, f.run.stateDir)), new RegExp(`^${runIdOf(f.run.stateDir)}$`));
			// The path follows from the run and the task: the caller names a
			// task, not a path.
			assert.notEqual(canonicalWorkdir(root, f.run.stateDir, "t1"), canonicalWorkdir(root, f.run.stateDir, "t2"));
		} finally {
			rmrf(f.dir);
		}
	});

	it("gives two runs of one repository disjoint worktrees (I10)", () => {
		const f = fixture();
		try {
			const other = path.join(f.dir, ".taskq-other");
			const a = canonicalWorkdir(f.root, f.run.stateDir, "t1");
			const b = canonicalWorkdir(f.root, other, "t1");
			assert.notEqual(a, b, "two runs never share a worktree path");
			assert.notEqual(runIdOf(f.run.stateDir), runIdOf(other));
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a taken canonical location and names it (W2)", () => {
		const f = fixture();
		try {
			const workdir = canonicalWorkdir(f.root, f.run.stateDir, "t1");
			const spec = { branch: "exp/t1", path: workdir, baseline: f.baseline };
			// A pre-created worktree, the ergonomic failure the fork owns away.
			addWorktree(f.root, spec);
			assert.throws(() => assertWorkdirFree(f.root, spec), (e) => {
				if (!(e instanceof TaskQueueError) || e.code !== "worktree-occupied") return false;
				return e.message.includes(workdir);
			});
			// The same refusal for a leftover branch alone.
			assert.throws(() => assertWorkdirFree(f.root, { ...spec, path: canonicalWorkdir(f.root, f.run.stateDir, "t3") }), (e) => {
				if (!(e instanceof TaskQueueError) || e.code !== "worktree-occupied") return false;
				return e.message.includes("exp/t1");
			});
		} finally {
			rmrf(f.dir);
		}
	});

	it("cuts the worktree at the canonical path and writes nothing into the main tree", () => {
		const f = fixture();
		try {
			const workdir = forkTask(f, "t1");
			assert.equal(workdir, canonicalWorkdir(f.root, f.run.stateDir, "t1"));
			assert.ok(fs.existsSync(path.join(workdir, ".git")));
			assert.ok(listWorktrees(f.root).includes(workdir));
			assert.ok(listBranches(f.root).includes("exp/t1"));
			// Single-writer: the fork touched the registry, not the main tree (I6).
			assert.equal(statusPorcelain(f.root), "");
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("written-loop closure (S1)", () => {
	it("drives fork, join, verify, proposal, bring-back, and close across a re-queue", async () => {
		const f = fixture();
		try {
			const run = joiner(f.run);
			const wt1 = forkTask(f, "t1");
			const wt2 = forkTask(f, "t2");
			const phases = new Set<string>();
			const note = (taskId: string): void => {
				phases.add(f.run.current().tasks[taskId].phase);
			};
			note("t1");
			note("t2");

			// t1: a regular break point, cleared, then a terminal one.
			workerSegment(wt1, "t1", { "alpha.ts": "v1\n" }, "running", "alpha ready");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).taskId, "t1");
			note("t1");
			workerSegment(wt1, "t1", { "alpha.ts": "v2\n" }, "done", "terminal");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000, taskId: "t1" })).entryId, "t1#2");
			note("t1");
			f.run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "report landed" }, AT));
			note("t1");

			// t2: one terminal segment, a not-usable audit, and a repair
			// segment entered through the in-place re-queue.
			workerSegment(wt2, "t2", { "design.md": "d\n" }, "done", "terminal");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000 })).entryId, "t2#1");
			f.run.handle((s) => verifyOp(s, { taskId: "t2", outcome: "not-usable", notes: "no report" }, AT));
			note("t2");
			// The re-queue rolls the worktree back to the head the delivered
			// segment reached, and the queue entries stay.
			const head2 = f.run.current().tasks.t2.lastSegmentHead;
			f.run.handle((s) => requeueOp(s, { taskId: "t2", route: "in-place", head: head2 }, AT));
			note("t2");
			workerSegment(wt2, "t2", { "design.md": "d2\n" }, "done", "terminal, report written");
			assert.equal(joined(await waitForBreakPoint(run, { timeoutMs: 1000, taskId: "t2" })).entryId, "t2#2");
			f.run.handle((s) => verifyOp(s, { taskId: "t2", outcome: "usable", notes: "report written" }, AT));
			note("t2");

			// Bring-back: proposal, file set, write, prune - one call. t1
			// writes its named path; t2's file set is empty, which writes
			// nothing back and still prunes.
			for (const [taskId, paths] of [
				["t1", ["alpha.ts"]],
				["t2", []],
			] as const) {
				const task = f.run.current().tasks[taskId];
				const proposed = proposalPaths(f.root, task.baseline, task.branch, ["taskq/"]);
				f.run.handle((s) => proposalOp(s, { taskId, description: "the segment", paths: proposed }, AT));
				const task2 = f.run.current().tasks[taskId];
				const archived = paths.length === 0;
				const applied =
					archived
						? (archiveTrack(f.run.stateDir, taskId, f.root, task2.baseline, task2.branch), [])
						: applyBringBack(f.root, { baseline: task2.baseline, branch: task2.branch, proposal: task2.proposal!, paths }).applied;
				// The prune precedes the record, so the record is the second
				// half of the bring-back: the tool performs the write and the
				// prune inside one locked section, and this is the op that
				// writes the half the operator reads (I10, I12).
				pruneWorktree(f.root, { branch: task.branch, path: task.workdir, baseline: task.baseline });
				f.run.handle((s) =>
					bringBackOp(s, { taskId, paths: [...paths], applied, archived, removedWorktree: task.workdir, prunedBranch: task.branch, resumed: false }, AT),
				);
				note(taskId);
			}
			assert.equal(fs.readFileSync(path.join(f.root, "alpha.ts"), "utf8"), "v2\n");
			assert.equal(fs.existsSync(path.join(f.root, "design.md")), false, "an empty file set lands nothing (I7)");
			assert.ok(fs.existsSync(path.join(f.run.stateDir, "archive", "t2.diff")), "the empty file set archived the branch diff");
			// No worker write reached the main tree except through the bring-backs (I6, I7).
			assert.deepEqual(
				statusPorcelain(f.root).split("\n").filter((l) => l !== "").map((l) => l.slice(3)),
				["alpha.ts"],
			);

			const close = f.run.handle((s) => closeOp(s, AT));
			// Every phase of the lifecycle was reached through the written loop.
			assert.deepEqual([...phases].sort(), ["active", "forked", "retired", "terminated"]);
			assert.equal(close.data.counts.tasks, 2);
			assert.equal(close.data.counts.entries, 4);
			assert.equal(close.data.counts.requests, 4);
			assert.equal(close.data.counts.pending, 0);
			assert.equal(close.data.counts.triggered, 4);
			// I10: the run left no worktree and no branch behind.
			assert.deepEqual(listWorktrees(f.root).map((p) => path.resolve(p)), [path.resolve(f.root)]);
			assert.deepEqual(listBranches(f.root), ["main"]);
		} finally {
			rmrf(f.dir);
		}
	});
});
