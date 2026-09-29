/**
 * The operation gates: referential integrity (I3), exactly-once request ids
 * (I1), one pending break point per task, the verification gate (I8), the
 * re-queue routes, the proposal gate, the bring-back gate (I9), the file
 * set's scope discipline (I7), and the four lifecycle phases. Pure unit
 * tests over the state transition functions.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { entryIdOf, getEntry } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { freshState, type RunState } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import {
	bringBackOp,
	closeOp,
	forkOp,
	integrityCounts,
	joinOp,
	proposalOp,
	requeueOp,
	recordOp,
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

/** Deliver n segments of a task; the last one carries the given status. */
function through(state: RunState, taskId: string, n = 1, status: "running" | "done" = "running", heads?: string[]): RunState {
	let s = state;
	for (let i = 1; i <= n; i++) {
		s = record(s, taskId, `${taskId}-${i}`, i === n ? status : "running");
		s = scheduleOp(s, entryIdOf(taskId, i), AT).state;
		s = triggerOp(s, { entryId: entryIdOf(taskId, i), head: heads?.[i - 1] ?? `h${i}`, changed: i }, AT).state;
	}
	return s;
}

/** One terminal segment: the task is active and waiting for its audit. */
function terminal(state: RunState, taskId: string, heads?: string[]): RunState {
	return through(state, taskId, 1, "done", heads);
}

/** The usable audit: the only state a bring-back runs from. */
function usable(state: RunState, taskId: string): RunState {
	return verifyOp(state, { taskId, outcome: "usable", notes: "report landed" }, AT).state;
}

/** The not-usable audit: the state a re-queue runs from. */
function notUsable(state: RunState, taskId: string): RunState {
	return verifyOp(state, { taskId, outcome: "not-usable", notes: "no report" }, AT).state;
}

function proposed(state: RunState, taskId: string, paths = ["a.txt", "b.txt"]): RunState {
	return proposalOp(state, { taskId, description: "the distilled change", paths }, AT).state;
}

function broughtBack(state: RunState, taskId: string, paths = ["a.txt", "b.txt"]): RunState {
	return bringBackOp(
		state,
		{ taskId, paths, applied: paths, archived: paths.length === 0, removedWorktree: `/wt/${taskId}`, prunedBranch: `exp/${taskId}`, resumed: false },
		AT,
	).state;
}

/** A second terminal segment, by hand: the re-queue kept the first entry. */
function nextTerminalSegment(state: RunState, taskId: string, head: string): RunState {
	let s = record(state, taskId, `${taskId}-${previousSeqOf(state, taskId) + 1}`, "done");
	s = scheduleOp(s, entryIdOf(taskId, previousSeqOf(state, taskId) + 1), AT).state;
	return triggerOp(s, { entryId: entryIdOf(taskId, previousSeqOf(state, taskId) + 1), head, changed: 1 }, AT).state;
}

function previousSeqOf(state: RunState, taskId: string): number {
	return state.entries.filter((e) => e.taskId === taskId).length;
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

	it("rejects a request for a terminated or retired task", () => {
		const forked = fork(base(), "t1");
		assert.throws(() => record(usable(terminal(forked, "t1"), "t1"), "t1", "t1-2"), expects("task-phase"));
		const retired = broughtBack(proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1"), "t1");
		assert.throws(() => record(retired, "t1", "t1-2"), expects("task-phase"));
	});

	it("accepts another segment after a not-usable audit", () => {
		// The audit leaves the task active; the re-queue is what the primary
		// does next, and the segment that follows it re-enters through the
		// same join.
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.equal(s.tasks.t1.phase, "active");
		assert.doesNotThrow(() => recordOp(s, { taskId: "t1", requestId: "t1-2", status: "running", workdir: "/wt/t1" }, AT));
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
		assert.throws(() => verifyOp(fork(base(), "t1"), { taskId: "t1", outcome: "usable", notes: "" }, AT), expects("verify-gate"));
	});

	it("rejects while a segment's break point is pending (mid-segment)", () => {
		let s = record(fork(base(), "t1"), "t1", "t1-1");
		s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "" }, AT), expects("verify-gate"));
	});

	it("rejects when the latest break point is triggered but the worker did not request its terminal break point", () => {
		const s = through(fork(base(), "t1"), "t1");
		assert.equal(s.tasks.t1.workerDone, false);
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "" }, AT), expects("verify-gate"));
	});

	it("terminates the task on a usable audit and records the break point it decided", () => {
		const r = verifyOp(terminal(fork(base(), "t1"), "t1"), { taskId: "t1", outcome: "usable", notes: "report landed" }, AT);
		assert.equal(r.data.task.phase, "terminated");
		assert.equal(r.data.task.verification?.outcome, "usable");
		assert.equal(r.data.task.verification?.entryId, "t1#1");
	});

	it("leaves the task active on a not-usable audit, and records why", () => {
		const r = verifyOp(terminal(fork(base(), "t1"), "t1"), { taskId: "t1", outcome: "not-usable", notes: "no report" }, AT);
		assert.equal(r.data.task.phase, "active", "a not-usable audit never terminates the task");
		assert.equal(r.data.task.verification?.outcome, "not-usable");
		assert.equal(r.data.task.verification?.entryId, "t1#1");
	});

	it("refuses a second audit of the same terminal break point", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "now landed" }, AT), expects("verify-gate"));
	});

	it("refuses a second audit after a usable audit, because the task is terminated", () => {
		const s = usable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(() => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "again" }, AT), expects("verify-gate"));
	});

	it("audits the new terminal break point after a re-queued segment", () => {
		let s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		s = requeueOp(s, { taskId: "t1", route: "in-place", head: "h1" }, AT).state;
		s = nextTerminalSegment(s, "t1", "h2");
		s = verifyOp(s, { taskId: "t1", outcome: "usable", notes: "now landed" }, AT).state;
		assert.equal(s.tasks.t1.phase, "terminated");
		assert.equal(s.tasks.t1.verification?.entryId, "t1#2");
	});
});

describe("requeue (both routes; the primary chooses)", () => {
	it("rolls the worktree back in place and keeps the task active", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		const r = requeueOp(s, { taskId: "t1", route: "in-place", head: "h1" }, AT);
		assert.equal(r.data.task.phase, "active");
		assert.equal(r.data.task.lastSegmentHead, "h1");
		assert.equal(r.data.task.workerDone, false, "the worker has another segment to run");
		assert.equal(r.data.requestSeq, 1, "the next request continues the sequence the queue reached");
	});

	it("a fresh re-queue returns the task to forked at the baseline", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		const r = requeueOp(s, { taskId: "t1", route: "fresh", head: "b0" }, AT);
		assert.equal(r.data.task.phase, "forked");
		assert.equal(r.data.task.lastSegmentHead, "b0");
		assert.equal(r.data.task.workerDone, false);
		assert.equal(r.data.requestSeq, 1);
	});

	it("refuses a head the route did not put the worktree at", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(() => requeueOp(s, { taskId: "t1", route: "in-place", head: "b0" }, AT), expects("requeue-gate"));
		assert.throws(() => requeueOp(s, { taskId: "t1", route: "fresh", head: "h1" }, AT), expects("requeue-gate"));
	});

	it("refuses a re-queue before a terminal break point and after termination", () => {
		assert.throws(() => requeueOp(fork(base(), "t1"), { taskId: "t1", route: "in-place", head: "b0" }, AT), expects("requeue-gate"));
		assert.throws(() => requeueOp(usable(terminal(fork(base(), "t1"), "t1"), "t1"), { taskId: "t1", route: "in-place", head: "h1" }, AT), expects("requeue-gate"));
	});

	it("refuses a re-queue while a break point is pending", () => {
		const s = record(fork(base(), "t1"), "t1", "t1-1");
		assert.throws(() => requeueOp(s, { taskId: "t1", route: "in-place", head: "b0" }, AT), expects("requeue-gate"));
	});

	it("keeps the queue entries across a re-queue, so the run holds no duplicate (I1)", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		const after = requeueOp(s, { taskId: "t1", route: "fresh", head: "b0" }, AT).state;
		assert.deepEqual(after.entries.map((e) => e.entryId), ["t1#1"]);
		assert.deepEqual(Object.keys(after.requests), ["t1-1"]);
	});
});

describe("proposal (I9 ordering: distilled from terminated state)", () => {
	it("rejects a proposal before the termination audit", () => {
		const s = terminal(fork(base(), "t1"), "t1");
		assert.throws(() => proposalOp(s, { taskId: "t1", description: "", paths: ["a.txt"] }, AT), expects("proposal-gate"));
	});

	it("rejects a proposal for a not-usable task: the primary judges a usable return", () => {
		const s = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(() => proposalOp(s, { taskId: "t1", description: "", paths: ["a.txt"] }, AT), expects("proposal-gate"));
	});

	it("stores the proposal on a terminated task", () => {
		const s = usable(terminal(fork(base(), "t1"), "t1"), "t1");
		const r = proposalOp(s, { taskId: "t1", description: "the change", paths: ["a.txt"] }, AT);
		assert.deepEqual(r.data.proposal.paths, ["a.txt"]);
	});
});

describe("bring-back (I9, I7)", () => {
	it("rejects a bring-back before the termination audit is usable (I9)", () => {
		const pending = terminal(fork(base(), "t1"), "t1");
		assert.throws(
			() => bringBackOp(pending, { taskId: "t1", paths: [], applied: [], archived: true, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("bring-back-gate"),
		);
		const rejected = notUsable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(
			() => bringBackOp(rejected, { taskId: "t1", paths: [], applied: [], archived: true, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("bring-back-gate"),
		);
	});

	it("rejects a bring-back without a proposal", () => {
		const s = usable(terminal(fork(base(), "t1"), "t1"), "t1");
		assert.throws(
			() => bringBackOp(s, { taskId: "t1", paths: [], applied: [], archived: true, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("bring-back-gate"),
		);
	});

	it("rejects a file set naming a path outside the proposal (I7)", () => {
		const s = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1", ["a.txt"]);
		assert.throws(
			() => bringBackOp(s, { taskId: "t1", paths: ["b.txt"], applied: [], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("file-set-invalid"),
		);
	});

	it("rejects a file set that names a path twice", () => {
		const s = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1", ["a.txt"]);
		assert.throws(
			() => bringBackOp(s, { taskId: "t1", paths: ["a.txt", "a.txt"], applied: [], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("file-set-invalid"),
		);
	});

	it("retires the task and records the file set it wrote", () => {
		const open = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1");
		const s = bringBackOp(open, { taskId: "t1", paths: ["a.txt"], applied: ["a.txt"], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT).state;
		assert.equal(s.tasks.t1.phase, "retired");
		assert.deepEqual(s.tasks.t1.bringBack?.paths, ["a.txt"]);
		assert.equal(s.tasks.t1.bringBack?.archived, false);
	});

	it("the empty file set is legal: nothing written back, the task still retires", () => {
		const open = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1");
		const s = bringBackOp(open, { taskId: "t1", paths: [], applied: [], archived: true, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT).state;
		assert.equal(s.tasks.t1.phase, "retired");
		assert.deepEqual(s.tasks.t1.bringBack?.paths, []);
		assert.equal(s.tasks.t1.bringBack?.archived, true, "the branch diff is archived into the run record");
	});

	it("refuses a bring-back while a break point is pending", () => {
		const open = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1");
		const pending = { ...open, entries: [{ ...open.entries[0], state: "scheduled" as const }] };
		assert.throws(
			() => bringBackOp(pending, { taskId: "t1", paths: ["a.txt"], applied: [], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT),
			expects("bring-back-gate"),
		);
	});
});

describe("join (one derivation, one delivery)", () => {
	it("records, schedules, and triggers as one transition", () => {
		const r = joinOp(fork(base(), "t1"), { taskId: "t1", requestId: "t1-1", status: "running", head: "h1", changed: 1 }, AT);
		assert.equal(r.data.recorded, true);
		assert.equal(r.state.entries[0].state, "triggered");
		assert.equal(r.state.tasks.t1.phase, "active");
		assert.equal(r.state.tasks.t1.lastSegmentHead, "h1");
		assert.deepEqual(r.events.map((e) => e.type), ["request:record", "entry:schedule", "entry:trigger"]);
	});
});

describe("close (I10, I1 close audit)", () => {
	it("closes only when every task is retired", () => {
		const open = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1");
		assert.throws(() => closeOp(open, AT), expects("close-gate"));
		const r = closeOp(broughtBack(open, "t1"), AT);
		assert.equal(r.data.counts.entries, 1);
		assert.equal(r.data.counts.requests, 1);
		assert.equal(r.data.counts.triggered, 1);
	});

	it("rejects transitions on a closed run", () => {
		const open = proposed(usable(terminal(fork(base(), "t1"), "t1"), "t1"), "t1", []);
		const s = closeOp(broughtBack(open, "t1", []), AT).state;
		assert.equal(s.closed, true);
		assert.throws(() => forkOp(s, { taskId: "t2", workdir: "/wt/t2", branch: "exp/t2", baseline: "b0", mainRoot: MAIN }, AT), expects("run-closed"));
	});

	it("close audit counts hold over a mixed run (I1 identity)", () => {
		let s = fork(base(), "t1");
		s = fork(s, "t2");
		// t1: a not-usable audit, an in-place re-queue, a second terminal
		// segment, and a usable return brought back as the empty file set;
		// t2: one terminal segment whose file set is one path.
		s = notUsable(terminal(s, "t1", ["h1"]), "t1");
		s = requeueOp(s, { taskId: "t1", route: "in-place", head: "h1" }, AT).state;
		s = nextTerminalSegment(s, "t1", "h2");
		s = broughtBack(proposed(usable(s, "t1"), "t1", []), "t1", []);
		s = broughtBack(proposed(usable(terminal(s, "t2"), "t2"), "t2", ["a.txt"]), "t2", ["a.txt"]);
		const before = integrityCounts(s);
		assert.deepEqual(before, { tasks: 2, entries: 3, triggered: 3, pending: 0, requests: 3 });
		const r = closeOp(s, AT);
		assert.deepEqual(r.data.counts, before);
	});
});
