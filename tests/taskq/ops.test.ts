/**
 * The operation gates: referential integrity (I3), exactly-once request ids
 * (I1), one pending break point per task, the verification gate (I8), the
 * merge gate (I9), the verdict scope discipline (I7), and the lifecycle
 * phases. Pure unit tests over the state transition functions.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { entryIdOf, getEntry } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { freshState, type RunState } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import {
	closeOp,
	forkOp,
	integrityCounts,
	mergeOp,
	proposalOp,
	recordOp,
	retireOp,
	scheduleOp,
	triggerOp,
	verifyOp,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";

const AT = "2026-01-01T00:00:00.000Z";
const MAIN = "/repo/main";

function base(): RunState {
	return freshState(MAIN, `${MAIN}/.taskq`, AT);
}

function fork(state: RunState, taskId: string, workdir = `/wt/${taskId}`): RunState {
	return forkOp(state, { taskId, workdir, branch: `exp/${taskId}`, baseline: "b0", mainRoot: MAIN }, AT).state;
}

function record(state: RunState, taskId: string, requestId: string, status: "running" | "done" = "running"): RunState {
	return recordOp(state, { taskId, requestId, status, workdir: `/wt/${taskId}` }, AT).state;
}

function through(state: RunState, taskId: string, n = 1, status: "running" | "done" = "running"): RunState {
	let s = state;
	for (let i = 1; i <= n; i++) {
		s = record(s, taskId, `${taskId}-${i}`, i === n ? status : "running");
		s = scheduleOp(s, entryIdOf(taskId, i), AT).state;
		s = triggerOp(s, { entryId: entryIdOf(taskId, i), head: `h${i}`, changed: i }, AT).state;
	}
	return s;
}

function terminal(state: RunState, taskId: string): RunState {
	return through(state, taskId, 1, "done");
}

function verified(state: RunState, taskId: string): RunState {
	let s = terminal(state, taskId);
	s = verifyOp(s, { taskId, outcome: "passed", notes: "ok" }, AT).state;
	return s;
}

function proposed(state: RunState, taskId: string, paths = ["a.txt", "b.txt"]): RunState {
	let s = verified(state, taskId);
	s = proposalOp(s, { taskId, description: "the distilled change", paths }, AT).state;
	return s;
}

function expects(code: string): (e: unknown) => boolean {
	return (e) => e instanceof TaskQueueError && e.code === code;
}

describe("fork", () => {
	it("registers a task with the worker id defaulting to the task id", () => {
		const s = fork(base(), "t1");
		assert.equal(s.tasks.t1.workerId, "t1");
		assert.equal(s.tasks.t1.phase, "forked");
		assert.equal(s.tasks.t1.lastSegmentHead, "b0");
	});

	it("rejects a duplicate task", () => {
		assert.throws(() => fork(fork(base(), "t1"), "t1"), expects("task-duplicate"));
	});

	it("rejects a workdir inside the main tree (I6 structural guard)", () => {
		assert.throws(() => fork(base(), "t1", "/repo/main/inside"), expects("task-workdir-inside-main"));
		assert.throws(() => fork(base(), "t1", "/repo/main"), expects("task-workdir-inside-main"));
	});
});

describe("record (I3, I1, segment serialization)", () => {
	it("rejects a request from outside the task's own worktree (I3)", () => {
		const s = fork(base(), "t1");
		assert.throws(
			() => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "running", workdir: "/somewhere-else" }, AT),
			expects("request-path-mismatch"),
		);
	});

	it("rejects an unknown task", () => {
		assert.throws(() => record(base(), "ghost", "g-1"), expects("task-unknown"));
	});

	it("records a request exactly once: the same request id re-enters never (I1)", () => {
		const s = record(fork(base(), "t1"), "t1", "t1-1");
		assert.throws(() => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "running", workdir: "/wt/t1" }, AT), expects("request-duplicate"));
	});

	it("records a request id once across the whole run, not per task (I1)", () => {
		const s = record(fork(base(), "t1"), "t1", "shared-1");
		const s2 = fork(s, "t2");
		assert.throws(() => record(s2, "t2", "shared-1"), expects("request-duplicate"));
	});

	it("rejects a second pending break point while one is pending", () => {
		const s = record(fork(base(), "t1"), "t1", "t1-1");
		assert.throws(() => record(s, "t1", "t1-2"), expects("request-pending-task"));
	});

	it("accepts the next segment after the previous break point triggered", () => {
		const s = through(fork(base(), "t1"), "t1");
		assert.doesNotThrow(() => recordOp(s, { taskId: "t1", requestId: "t1-2", status: "running", workdir: "/wt/t1" }, AT));
	});

	it("assigns per-task sequences and marks the worker disposition", () => {
		let s = fork(base(), "t1");
		s = record(s, "t1", "t1-1");
		s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
		s = triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 0 }, AT).state;
		s = record(s, "t1", "t1-2", "done");
		assert.equal(s.tasks.t1.workerDone, true);
		assert.equal(getEntry(s.entries, entryIdOf("t1", 2))?.requestSeq, 2);
		// parallel task sequences independently
		s = fork(s, "t2");
		s = record(s, "t2", "t2-1");
		assert.equal(getEntry(s.entries, entryIdOf("t2", 1))?.requestSeq, 1);
	});

	it("rejects a request for a verified, merged, discarded, or retired task", () => {
		assert.throws(() => record(verified(fork(base(), "t1"), "t1"), "t1", "t1-2"), expects("task-phase"));
		let s = proposed(fork(base(), "t1"), "t1");
		s = mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: ["a.txt", "b.txt"], archived: false }, AT).state;
		assert.throws(() => record(s, "t1", "t1-2"), expects("task-phase"));
	});

	it("accepts a repair segment after a failed verification", () => {
		let s = terminal(fork(base(), "t1"), "t1");
		s = verifyOp(s, { taskId: "t1", outcome: "failed", notes: "report missing" }, AT).state;
		assert.equal(s.tasks.t1.phase, "failed");
		s = record(s, "t1", "t1-2", "running");
		assert.equal(s.tasks.t1.phase, "active");
		assert.equal(s.tasks.t1.workerDone, false);
	});
});

describe("trigger (I3 dequeue check)", () => {
	it("rejects when the entry references no longer match the task", () => {
		let s = fork(base(), "t1");
		s = record(s, "t1", "t1-1");
		s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
		const tampered = { ...s, tasks: { ...s.tasks, t1: { ...s.tasks.t1, workerId: "someone-else" } } };
		assert.throws(() => triggerOp(tampered, { entryId: entryIdOf("t1", 1), head: "h1", changed: 0 }, AT), expects("entry-ref-mismatch"));
	});
});

describe("verify (I8: only at the worker's terminal request, never mid-segment)", () => {
	it("rejects when no break point was ever recorded", () => {
		assert.throws(() => verifyOp(fork(base(), "t1"), { taskId: "t1", outcome: "passed", notes: "" }, AT), expects("verify-gate"));
	});

	it("rejects while a segment's break point is pending (mid-segment)", () => {
		let s = record(fork(base(), "t1"), "t1", "t1-1");
		s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "passed", notes: "" }, AT), expects("verify-gate"));
	});

	it("rejects when the latest break point is triggered but the worker did not request its terminal break point", () => {
		const s = through(fork(base(), "t1"), "t1");
		assert.equal(s.tasks.t1.workerDone, false);
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "passed", notes: "" }, AT), expects("verify-gate"));
	});

	it("accepts only after the terminal request triggered and nothing is pending", () => {
		const s = terminal(fork(base(), "t1"), "t1");
		const r = verifyOp(s, { taskId: "t1", outcome: "passed", notes: "report landed" }, AT);
		assert.equal(r.data.task.phase, "verified");
	});

	it("records a failed outcome and allows a repair segment (I8 repair path)", () => {
		let s = terminal(fork(base(), "t1"), "t1");
		s = verifyOp(s, { taskId: "t1", outcome: "failed", notes: "missing report" }, AT).state;
		assert.equal(s.tasks.t1.phase, "failed");
		s = record(s, "t1", "t1-2");
		s = scheduleOp(s, entryIdOf("t1", 2), AT).state;
		s = triggerOp(s, { entryId: entryIdOf("t1", 2), head: "h2", changed: 1 }, AT).state;
		s = record(s, "t1", "t1-3", "done");
		s = scheduleOp(s, entryIdOf("t1", 3), AT).state;
		s = triggerOp(s, { entryId: entryIdOf("t1", 3), head: "h3", changed: 1 }, AT).state;
		s = verifyOp(s, { taskId: "t1", outcome: "passed", notes: "now landed" }, AT).state;
		assert.equal(s.tasks.t1.phase, "verified");
	});
});

describe("proposal (I9 ordering: distilled from verified state)", () => {
	it("rejects a proposal before verification", () => {
		const s = terminal(fork(base(), "t1"), "t1");
		assert.throws(() => proposalOp(s, { taskId: "t1", description: "", paths: ["a.txt"] }, AT), expects("proposal-gate"));
	});

	it("stores the proposal on a verified task", () => {
		const s = verified(fork(base(), "t1"), "t1");
		const r = proposalOp(s, { taskId: "t1", description: "the change", paths: ["a.txt"] }, AT);
		assert.deepEqual(r.data.proposal.paths, ["a.txt"]);
	});
});

describe("merge (I9, I7)", () => {
	it("rejects a merge before final verification (I9)", () => {
		let s = terminal(fork(base(), "t1"), "t1");
		assert.throws(() => mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: [], archived: false }, AT), expects("merge-gate"));
	});

	it("rejects a merge without a proposal", () => {
		const s = verified(fork(base(), "t1"), "t1");
		assert.throws(() => mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: [], archived: false }, AT), expects("merge-gate"));
	});

	it("rejects a partial verdict naming a path outside the proposal (I7)", () => {
		const s = proposed(fork(base(), "t1"), "t1", ["a.txt"]);
		assert.throws(
			() => mergeOp(s, { taskId: "t1", verdict: { scope: "partial", paths: ["b.txt"] }, applied: [], archived: false }, AT),
			expects("verdict-invalid"),
		);
	});

	it("rejects an empty or duplicated partial verdict", () => {
		const s = proposed(fork(base(), "t1"), "t1", ["a.txt"]);
		assert.throws(() => mergeOp(s, { taskId: "t1", verdict: { scope: "partial", paths: [] }, applied: [], archived: false }, AT), expects("verdict-invalid"));
		assert.throws(
			() => mergeOp(s, { taskId: "t1", verdict: { scope: "partial", paths: ["a.txt", "a.txt"] }, applied: [], archived: false }, AT),
			expects("verdict-invalid"),
		);
	});

	it("all marks the task merged, none marks it discarded", () => {
		let s = proposed(fork(base(), "t1"), "t1");
		s = mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: ["a.txt", "b.txt"], archived: false }, AT).state;
		assert.equal(s.tasks.t1.phase, "merged");
		assert.deepEqual(s.tasks.t1.verdict, { scope: "all" });

		let s2 = proposed(fork(base(), "t2"), "t2");
		s2 = mergeOp(s2, { taskId: "t2", verdict: { scope: "none" }, applied: [], archived: true }, AT).state;
		assert.equal(s2.tasks.t2.phase, "discarded");
		assert.deepEqual(s2.tasks.t2.verdict, { scope: "none" });
	});

	it("records exactly the applied paths with a partial verdict (I7)", () => {
		const s = proposed(fork(base(), "t1"), "t1", ["a.txt", "b.txt", "c.txt"]);
		const r = mergeOp(s, { taskId: "t1", verdict: { scope: "partial", paths: ["a.txt", "c.txt"] }, applied: ["a.txt", "c.txt"], archived: false }, AT);
		assert.equal(r.data.task.phase, "merged");
		assert.deepEqual(r.data.task.verdict, { scope: "partial", paths: ["a.txt", "c.txt"] });
	});
});

describe("retire and close (I10, I1 close audit)", () => {
	it("retires only a merged or discarded task", () => {
		assert.throws(() => retireOp(fork(base(), "t1"), "t1", AT), expects("retire-gate"));
		assert.throws(() => retireOp(verified(fork(base(), "t1"), "t1"), "t1", AT), expects("retire-gate"));
	});

	it("closes only when every task retired", () => {
		let s = proposed(fork(base(), "t1"), "t1");
		s = mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: ["a.txt"], archived: false }, AT).state;
		assert.throws(() => closeOp(s, AT), expects("close-gate"));
		s = retireOp(s, "t1", AT).state;
		const r = closeOp(s, AT);
		assert.equal(r.data.counts.entries, 1);
		assert.equal(r.data.counts.requests, 1);
		assert.equal(r.data.counts.triggered, 1);
	});

	it("rejects transitions on a closed run", () => {
		let s = proposed(fork(base(), "t1"), "t1");
		s = mergeOp(s, { taskId: "t1", verdict: { scope: "none" }, applied: [], archived: true }, AT).state;
		s = retireOp(s, "t1", AT).state;
		s = closeOp(s, AT).state;
		assert.equal(s.closed, true);
		assert.throws(() => forkOp(s, { taskId: "t2", workdir: "/wt/t2", branch: "exp/t2", baseline: "b0", mainRoot: MAIN }, AT), expects("run-closed"));
	});

	it("close audit counts hold over a mixed run (I1 identity)", () => {
		let s = fork(base(), "t1");
		s = fork(s, "t2");
		// t1: two segments, terminal; t2: one segment.
		s = through(s, "t1", 2, "done");
		s = verifyOp(s, { taskId: "t1", outcome: "passed", notes: "" }, AT).state;
		s = proposalOp(s, { taskId: "t1", description: "", paths: [] }, AT).state;
		s = mergeOp(s, { taskId: "t1", verdict: { scope: "all" }, applied: [], archived: false }, AT).state;
		s = retireOp(s, "t1", AT).state;
		s = through(s, "t2", 1, "done");
		s = verifyOp(s, { taskId: "t2", outcome: "passed", notes: "" }, AT).state;
		s = proposalOp(s, { taskId: "t2", description: "", paths: [] }, AT).state;
		s = mergeOp(s, { taskId: "t2", verdict: { scope: "none" }, applied: [], archived: true }, AT).state;
		s = retireOp(s, "t2", AT).state;
		const before = integrityCounts(s);
		assert.deepEqual(before, { tasks: 2, entries: 3, triggered: 3, pending: 0, requests: 3 });
		const r = closeOp(s, AT);
		assert.deepEqual(r.data.counts, before);
	});
});