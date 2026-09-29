/**
 * The pool join: the third mode of the join selector. One call blocks
 * until every task of a named pool has a break point ready, then
 * records, schedules, and triggers the whole set in one transition and
 * returns one payload per task.
 *
 * The suite holds the pool contract against real repositories and the
 * real worker protocol: the batch is one atomic write (I11), every break
 * point of the batch enters and triggers exactly once (I1, I5), a
 * contention anywhere in the batch holds the whole batch back and
 * re-scans it as a unit, a pool timeout triggers nothing (I12), and a
 * delivered pool is one held join-unit the operator clears (J4). The
 * mode adds no transition row: the batch is the join transition run
 * once per task, which the pure op test at the end pins down.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as path from "node:path";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { forkOp, joinAllOp, joinOp, verifyOp } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { heldUnit, scanReady, waitForBreakPoint, type JoinResult, type JoinRun, type PoolJoinedResult } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/join.ts";
import { readJournal } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { addWorktree, canonicalWorkdir } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { makeMainRepo, rmrf, tmpdir, workerRequest, workerSegment, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

/** The persisted face the join drives, backed by the real Run facade. */
function joiner(run: Run): JoinRun {
	return {
		stateDir: run.stateDir,
		current: () => run.current(),
		join: (p) => run.handle((s) => joinOp(s, p, AT)),
		joinAll: async (ps) => {
			const { data } = await run.handle((s) => joinAllOp(s, ps, AT));
			return { data: data.joins };
		},
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
	addWorktree(f.root, { branch: `exp/${taskId}`, path: workdir, baseline: f.baseline });
	f.run.handle((s) => forkOp(s, { taskId, workdir, branch: `exp/${taskId}`, baseline: f.baseline, mainRoot: f.root }, AT));
	return workdir;
}

/** One worker segment per task: a file, a commit, and a break-point request. */
function segments(workdirs: Record<string, string>): void {
	for (const [taskId, workdir] of Object.entries(workdirs)) {
		workerSegment(workdir, taskId, { [`src/${taskId}.ts`]: "v1\n" }, "running", `${taskId} ready`);
	}
}

function pool(result: JoinResult): PoolJoinedResult {
	assert.equal(result.outcome, "joined", `expected a pool delivery, got ${result.outcome}: ${JSON.stringify(result)}`);
	assert.equal((result as PoolJoinedResult).mode, "pool", "the result is a pool, not a single delivery");
	return result as PoolJoinedResult;
}

function journalTypes(f: Fixture): string[] {
	return readJournal(f.run.stateDir).map((e) => e.type);
}

function sleep(ms: number): Promise<void> {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

describe("pool join: one atomic batch (I11)", () => {
	it("delivers a pool of two tasks as one transition and returns one payload per task", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const result = pool(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			assert.deepEqual(
				result.payloads.map((p) => [p.entryId, p.taskId, p.requestStatus, p.message, p.segmentChanged]),
				[
					["t1#1", "t1", "running", "t1 ready", ["src/t1.ts"]],
					["t2#1", "t2", "running", "t2 ready", ["src/t2.ts"]],
				],
			);
			assert.deepEqual(
				result.payloads.map((p) => p.workdir),
				[workdirs.t1, workdirs.t2],
				"each payload names its own worktree",
			);
			// The batch is the join transition once per task, in one write:
			// six events, and the queue rests only in triggered.
			assert.deepEqual(journalTypes(f).slice(3), [
				"request:record",
				"entry:schedule",
				"entry:trigger",
				"request:record",
				"entry:schedule",
				"entry:trigger",
			]);
			assert.deepEqual(
				f.run.current().entries.map((e) => [e.entryId, e.state]),
				[
					["t1#1", "triggered"],
					["t2#1", "triggered"],
				],
			);
			assert.equal(Object.keys(f.run.current().requests).length, 2, "each request of the batch entered once (I1)");
		} finally {
			rmrf(f.dir);
		}
	});

	it("returns the payloads in the order the pool named them", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2"), t3: forkTask(f, "t3") };
			segments(workdirs);
			const result = pool(await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000, pollMs: 10, taskIds: ["t3", "t1", "t2"] }));
			assert.deepEqual(
				result.payloads.map((p) => p.taskId),
				["t3", "t1", "t2"],
			);
		} finally {
			rmrf(f.dir);
		}
	});

	it("blocks until every task of the pool is ready", async () => {
		const f = fixture();
		try {
			const wt1 = forkTask(f, "t1");
			const wt2 = forkTask(f, "t2");
			workerSegment(wt1, "t1", { "src/t1.ts": "v1\n" }, "running", "t1 ready");
			const pending = waitForBreakPoint(joiner(f.run), { timeoutMs: 10_000, pollMs: 10, taskIds: ["t1", "t2"] });
			// The second worker lands while the pool is still waiting on it.
			await sleep(150);
			workerSegment(wt2, "t2", { "src/t2.ts": "v1\n" }, "running", "t2 ready");
			const result = pool(await pending);
			assert.deepEqual(
				result.payloads.map((p) => p.entryId),
				["t1#1", "t2#1"],
			);
			assert.ok(result.waitedMs >= 100, `the call waited for the slow task: ${result.waitedMs}ms`);
		} finally {
			rmrf(f.dir);
		}
	});

	it("names the uncommitted paths per task and keeps the scan's notices on the batch", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const run = joiner(f.run);
			pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			// t1 leaves a file uncommitted; t2 requests again with a protocol
			// change only, so its segment has no deliverable; a hand-written
			// document that does not parse is a notice for the whole batch.
			writeFile(workdirs.t1, "src/wip.ts", "wip\n");
			workerRequest(workdirs.t1, "t1", "running", "t1 with a wip file");
			workerRequest(workdirs.t2, "t2", "running", "t2 protocol only");
			writeFile(workdirs.t2, "taskq/requests/t2-9.json", "{ not json");
			const result = pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			const [first, second] = result.payloads;
			assert.deepEqual(
				first.uncommitted,
				["src/wip.ts"],
				"the payload names the paths its own worktree holds",
			);
			assert.equal(first.segmentStat, "(no deliverable change since the last break point)");
			assert.equal(
				first.notices.some((n) => n.includes("uncommitted path(s)")),
				true,
				"the uncommitted notice belongs to the task that owns it",
			);
			assert.deepEqual(second.notices, [], "a task with nothing to say says nothing");
			assert.equal(
				second.notices.some((n) => n.includes("not a valid worker request")),
				false,
				"the batch does not repeat a scan notice on every payload",
			);
			assert.equal(
				result.notices.some((n) => n.includes("t2-9") && n.includes("not a valid worker request")),
				true,
				"the batch carries the scan's notices once",
			);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("pool join: exactly-once over the batch (I1, I5)", () => {
	it("a contention in the batch re-scans the pool and delivers it whole", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const base = joiner(f.run);
			// One task of the batch moved between the scan and the write.
			// The refusal is the batch's, and the batch is not written.
			let attempts = 0;
			const loads: number[] = [];
			const flaky: JoinRun = {
				...base,
				joinAll: async (ps) => {
					loads.push(f.run.current().entries.length);
					attempts += 1;
					if (attempts === 1) throw new TaskQueueError("join-contended", "another join moved one task of this pool");
					return base.joinAll(ps);
				},
			};
			const result = pool(await waitForBreakPoint(flaky, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			assert.equal(attempts, 2, "the contended batch was retried, not surfaced");
			assert.equal(loads[1], 0, `the refused batch wrote nothing: the re-scan loaded ${loads[1]} entries`);
			assert.deepEqual(
				result.payloads.map((p) => p.entryId),
				["t1#1", "t2#1"],
			);
			const state = f.run.current();
			assert.equal(state.entries.length, 2);
			assert.equal(state.entries.filter((e) => e.state === "triggered").length, 2);
			assert.equal(journalTypes(f).filter((t) => t === "entry:trigger").length, 2, "each break point triggered once (I5)");
			assert.equal(journalTypes(f).filter((t) => t === "request:record").length, 2, "each request recorded once (I1)");
		} finally {
			rmrf(f.dir);
		}
	});

	it("a break point another join took leaves the rest of the pool unrecorded", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const base = joiner(f.run);
			// The racing join wins t2 between the pool's scan and its write.
			let raced = false;
			const racer: JoinRun = {
				...base,
				joinAll: async (ps) => {
					if (!raced) {
						raced = true;
						await base.join(ps[1]);
					}
					throw new TaskQueueError("join-contended", "task t2 moved under this pool");
				},
			};
			const result = await waitForBreakPoint(racer, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] });
			// The batch was not delivered, and the break point the racing join
			// took is the hold the pool now reports. Nothing is delivered
			// beside an undecided break point.
			assert.equal(result.outcome, "held");
			assert.equal((result as { hold: { taskId: string } }).hold.taskId, "t2");
			assert.deepEqual(
				f.run.current().entries.map((e) => e.entryId),
				["t2#1"],
				"the refused batch recorded no entry for the task that was still ready",
			);
			// t1's break point was not lost: it is still a candidate, waiting
			// behind the hold the racing join opened.
			const single = await waitForBreakPoint(base, { timeoutMs: 1000, pollMs: 10, taskId: "t1" });
			assert.equal(single.outcome, "held", "t1 waits behind the hold (J4)");
			assert.equal(f.run.current().entries.length, 1, "nothing was delivered beside that hold");
			// The operator clears t2, and the identity that never entered the
			// queue enters it exactly once.
			workerRequest(workdirs.t2, "t2", "running", "t2 cleared");
			const later = await waitForBreakPoint(base, { timeoutMs: 1000, pollMs: 10, taskId: "t1" });
			assert.equal(later.outcome, "joined");
			assert.equal((later as { entryId: string }).entryId, "t1#1", "t1's break point entered once, after the hold cleared");
			assert.deepEqual(
				f.run.current().entries.map((e) => e.entryId),
				["t2#1", "t1#1"],
			);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a pool that keeps contending surfaces the code instead of spinning", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const base = joiner(f.run);
			let attempts = 0;
			const wedged: JoinRun = {
				...base,
				joinAll: async () => {
					attempts += 1;
					throw new TaskQueueError("join-contended", "another join moved one task of this pool");
				},
			};
			await assert.rejects(
				waitForBreakPoint(wedged, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }),
				(e) => e instanceof TaskQueueError && e.code === "join-contended",
			);
			assert.equal(attempts, 4, "three re-scans of the whole pool, then the code reaches the caller");
			// The refused batches changed nothing (I12).
			assert.equal(f.run.current().entries.length, 0);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("pool join: inert timeout and the held unit (J3, J4, J12)", () => {
	it("a pool timeout triggers nothing and names the task that was missing", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			workerSegment(workdirs.t1, "t1", { "src/t1.ts": "v1\n" }, "running", "t1 ready");
			const result = await waitForBreakPoint(joiner(f.run), { timeoutMs: 200, pollMs: 10, taskIds: ["t1", "t2"] });
			assert.equal(result.outcome, "timeout");
			const timed = result as { ready?: string[]; missing?: string[]; waiting: string[] };
			assert.deepEqual(timed.ready, ["t1"], "the timeout names what was ready");
			assert.deepEqual(timed.missing, ["t2"], "and what kept the pool open");
			assert.deepEqual(timed.waiting, ["t1", "t2"]);
			// Inert: the ready task's break point is still a candidate, not an
			// entry (I12).
			assert.equal(f.run.current().entries.length, 0);
			assert.equal(journalTypes(f).includes("entry:trigger"), false);
			// After the timeout the caller may join the ready task on its own.
			const single = await waitForBreakPoint(joiner(f.run), { timeoutMs: 1000, pollMs: 10, taskId: "t1" });
			assert.equal(single.outcome, "joined");
			assert.equal((single as { entryId: string }).entryId, "t1#1");
		} finally {
			rmrf(f.dir);
		}
	});

	it("a delivered pool is one held join-unit: the next join holds and delivers nothing", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const run = joiner(f.run);
			pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			const state = f.run.current();
			assert.deepEqual(heldUnit(state, scanReady(state)), ["t1", "t2"], "the whole batch is the held unit");

			// Pool mode, any mode: the undecided batch holds the join.
			for (const wait of [{ taskIds: ["t1", "t2"] }, { taskId: "t1" }, {}]) {
				const result = await waitForBreakPoint(run, { timeoutMs: 200, pollMs: 10, ...wait });
				assert.equal(result.outcome, "held", `a held batch holds the join: ${JSON.stringify(wait)}`);
			}
			assert.equal(f.run.current().entries.length, 2, "a held batch triggers nothing (J4)");

			// The operator clears both break points by re-dispatching the
			// workers; the pool then delivers the next batch.
			for (const [taskId, workdir] of Object.entries(workdirs)) workerRequest(workdir, taskId, "running", `${taskId} second`);
			const second = pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			assert.deepEqual(
				second.payloads.map((p) => p.entryId),
				["t1#2", "t2#2"],
			);
			assert.deepEqual(heldUnit(f.run.current(), scanReady(f.run.current())), ["t1", "t2"]);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a terminal pool batch holds every task at the audit", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			for (const [taskId, workdir] of Object.entries(workdirs)) {
				workerSegment(workdir, taskId, { [`src/${taskId}.ts`]: "v1\n" }, "done", `${taskId} done`);
			}
			const run = joiner(f.run);
			const result = pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t1", "t2"] }));
			assert.deepEqual(
				result.payloads.map((p) => p.requestStatus),
				["done", "done"],
			);
			assert.equal(f.run.current().tasks.t1.workerDone, true);
			assert.equal(f.run.current().tasks.t2.workerDone, true);
			// The hold names the first of the batch and what clears it.
			const held = await waitForBreakPoint(run, { timeoutMs: 200, pollMs: 10, taskIds: ["t1", "t2"] });
			assert.equal(held.outcome, "held");
			assert.equal((held as { hold: { clearsBy: string } }).hold.clearsBy.includes("taskq_verify"), true);
			assert.deepEqual(heldUnit(f.run.current(), scanReady(f.run.current())), ["t1", "t2"], "the audit is owed on every task of the batch");
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("pool join: the selector refuses a pool that could never deliver", () => {
	it("refuses an empty pool, a repeated task, both selectors, and an unknown task", async () => {
		const f = fixture();
		try {
			forkTask(f, "t1");
			const run = joiner(f.run);
			const cases: Array<[string, unknown, string]> = [
				["empty", { taskIds: [] }, "request-invalid"],
				["repeated", { taskIds: ["t1", "t1"] }, "request-invalid"],
				["both selectors", { taskId: "t1", taskIds: ["t1"] }, "request-invalid"],
				["unknown", { taskIds: ["t1", "nope"] }, "task-unknown"],
			];
			for (const [name, taskIds, code] of cases) {
				const started = Date.now();
				await assert.rejects(
					waitForBreakPoint(run, { timeoutMs: 30_000, pollMs: 10, ...(taskIds as object) }),
					(e) => e instanceof TaskQueueError && e.code === code,
					`${name} is refused as ${code}`,
				);
				assert.ok(Date.now() - started < 2000, `${name} is refused at once, not at the end of the timeout`);
			}
			assert.equal(f.run.current().entries.length, 0);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a pool that names a task the queue has closed to requests", async () => {
		const f = fixture();
		try {
			const wt1 = forkTask(f, "t1");
			forkTask(f, "t2");
			workerSegment(wt1, "t1", { "src/t1.ts": "v1\n" }, "done", "done");
			const run = joiner(f.run);
			await waitForBreakPoint(run, { timeoutMs: 1000, taskId: "t1" });
			f.run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT));
			assert.equal(f.run.current().tasks.t1.phase, "terminated");
			await assert.rejects(
				waitForBreakPoint(run, { timeoutMs: 30_000, pollMs: 10, taskIds: ["t1", "t2"] }),
				(e) => e instanceof TaskQueueError && e.code === "task-phase" && String(e.message).includes("terminated"),
			);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a pool of one is a delivery, and the single mode is not a batch", async () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const run = joiner(f.run);
			const single = await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskId: "t1" });
			assert.equal(single.outcome, "joined");
			assert.equal("mode" in single, false, "a single delivery is not a batch");
			// The delivered break point holds the queue, so the pool of one
			// waits behind it rather than delivering beside it (J4).
			const held = await waitForBreakPoint(run, { timeoutMs: 200, pollMs: 10, taskIds: ["t2"] });
			assert.equal(held.outcome, "held");
			assert.equal((held as { hold: { taskId: string } }).hold.taskId, "t1");
			// The operator clears t1, and the pool of one delivers t2 as a
			// batch of one.
			workerRequest(workdirs.t1, "t1", "running", "t1 again");
			const one = pool(await waitForBreakPoint(run, { timeoutMs: 1000, pollMs: 10, taskIds: ["t2"] }));
			assert.deepEqual(
				one.payloads.map((p) => [p.entryId, p.taskId]),
				[["t2#1", "t2"]],
			);
		} finally {
			rmrf(f.dir);
		}
	});
});

describe("pool join: the pure op", () => {
	it("the batch is the join transition run once per task, and refuses an empty pool", () => {
		const f = fixture();
		try {
			const workdirs = { t1: forkTask(f, "t1"), t2: forkTask(f, "t2") };
			segments(workdirs);
			const scanned = scanReady(f.run.current());
			const params = ["t1", "t2"].map((taskId) => {
				const candidate = scanned.candidates.find((c) => c.taskId === taskId)!;
				const task = f.run.current().tasks[taskId];
				return { taskId, requestId: candidate.requestId, status: candidate.request!.status, head: "HEAD", changed: 1, baseHead: task.baseline };
			});
			const result = joinAllOp(f.run.current(), params, AT);
			assert.deepEqual(
				result.data.joins.map((j) => [j.entry.entryId, j.entry.state, j.recorded]),
				[
					["t1#1", "triggered", true],
					["t2#1", "triggered", true],
				],
			);
			assert.deepEqual(
				result.events.map((e) => e.type),
				["request:record", "entry:schedule", "entry:trigger", "request:record", "entry:schedule", "entry:trigger"],
				"the batch carries every task's three events, in order",
			);
			// A refusal in the middle of the fold stops the fold, so the
			// derivation the caller saves is the whole batch or none of it.
			assert.throws(
				() => joinAllOp(f.run.current(), [{ ...params[0], requestId: "t1-1", taskId: "t1" }, { ...params[1], taskId: "nope" }], AT),
				(e) => e instanceof TaskQueueError && e.code === "task-unknown",
			);
			assert.throws(() => joinAllOp(f.run.current(), [], AT), (e) => e instanceof TaskQueueError && e.code === "request-invalid");
			// The op added no row to the table: the phases it reaches are the
			// ones the join rows reach.
			assert.equal(result.state.tasks.t1.phase, "active");
			assert.equal(result.state.tasks.t2.phase, "active");
		} finally {
			rmrf(f.dir);
		}
	});
});
