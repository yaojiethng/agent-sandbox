/**
 * The transition table as the single source of truth (R12): the suite walks
 * the table instead of a list of conditionals. Every row is legal, every
 * phase is reachable, every non-terminal phase can reach a terminal one,
 * and every edge the table does not carry is refused by the gate that owns
 * it, so an illegal edge is not expressible.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TaskQueueError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { entryIdOf, transitionSchedule, transitionTrigger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { freshState, type RunState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import {
	ENTRY_TRANSITIONS,
	RUN_TRANSITIONS,
	TASK_PHASES,
	TASK_TRANSITIONS,
	canTask,
	entryTo,
	isTerminalPhase,
	legalFrom,
	runTo,
	taskActions,
	nextPhase,
	taskTo,
	type EntryAction,
	type RunAction,
	type TaskAction,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/transitions.ts";
import {
	canBringBack,
	canClose,
	canPropose,
	canRequeue,
	canRecord,
	canVerify,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/tasks.ts";
import { bringBackOp, closeOp, forkOp, proposalOp, requeueOp, recordOp, scheduleOp, triggerOp, verifyOp } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";

const AT = "2026-01-01T00:00:00.000Z";
const MAIN = "/repo/main";

/** A task in a phase, with the entries and records that phase implies. */
function taskIn(phase: string): RunState {
	let s = freshState(MAIN, `${MAIN}/.taskq`, AT);
	s = forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: MAIN }, AT).state;
	if (phase === "forked") return s;
	s = recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, AT).state;
	s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
	s = triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, AT).state;
	if (phase === "active") return s;
	s = verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT).state;
	// A terminated task in practice carries its proposal: the bring-back the
	// primary takes next needs one.
	s = proposalOp(s, { taskId: "t1", description: "", paths: ["a.txt"] }, AT).state;
	if (phase === "terminated") return s;
	return bringBackOp(s, { taskId: "t1", paths: ["a.txt"], applied: ["a.txt"], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT).state;
}

/** The task in the phase a not-usable audit leaves it in. */
function notUsableAudit(): RunState {
	let s = freshState(MAIN, `${MAIN}/.taskq`, AT);
	s = forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: MAIN }, AT).state;
	s = recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, AT).state;
	s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
	s = triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, AT).state;
	return verifyOp(s, { taskId: "t1", outcome: "not-usable", notes: "no report" }, AT).state;
}

/** The op every task action is driven through, with its legal arguments. */
const DRIVERS: Record<TaskAction, (s: RunState) => RunState> = {
	fork: (s) => forkOp(s, { taskId: "t2", workdir: "/wt/t2", branch: "exp/t2", baseline: "b0", mainRoot: MAIN }, AT).state,
	join: (s) => recordOp(s, { taskId: "t1", requestId: "t1-9", status: "running", workdir: "/wt/t1" }, AT).state,
	"verify-usable": (s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT).state,
	"verify-not-usable": (s) => verifyOp(s, { taskId: "t1", outcome: "not-usable", notes: "no" }, AT).state,
	propose: (s) => proposalOp(s, { taskId: "t1", description: "d", paths: ["a.txt"] }, AT).state,
	"bring-back": (s) => bringBackOp(s, { taskId: "t1", paths: ["a.txt"], applied: ["a.txt"], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT).state,
	"requeue-in-place": (s) => requeueOp(s, { taskId: "t1", route: "in-place", head: "h1" }, AT).state,
	"requeue-fresh": (s) => requeueOp(s, { taskId: "t1", route: "fresh", head: "b0" }, AT).state,
	close: (s) => closeOp(s, AT).state,
};

/** The phase an action leaves a state in, for the table walk. */
function phaseAfter(s: RunState): string {
	return s.tasks.t1?.phase ?? "forked";
}

describe("the task transition table", () => {
	it("names exactly the four phases, in lifecycle order", () => {
		assert.deepEqual([...TASK_PHASES], ["forked", "active", "terminated", "retired"]);
		assert.deepEqual(new Set(TASK_TRANSITIONS.map((t) => t.to)), new Set(TASK_PHASES));
	});

	it("has no duplicate from-state x action row", () => {
		const keys = TASK_TRANSITIONS.map((t) => `${t.from ?? "none"}:${t.action}`);
		assert.deepEqual(keys.length, new Set(keys).size, `duplicate row: ${keys.join(", ")}`);
	});

	it("every row is the transition the op that drives it performs", () => {
		for (const row of TASK_TRANSITIONS) {
			if (row.from === null) {
				// The fork row creates the task: nothing to read first.
				assert.equal(phaseAfter(DRIVERS.fork(freshState(MAIN, `${MAIN}/.taskq`, AT))), row.to);
				continue;
			}
			const before = taskIn(row.from);
			if (row.action === "requeue-in-place" || row.action === "requeue-fresh") {
				// The re-queue rows answer a not-usable audit, so they start
				// from the state that audit leaves.
				assert.equal(taskTo(row.from, row.action), row.to, `${row.from} -- ${row.action} -- ${row.to}`);
				continue;
			}
			assert.equal(phaseAfter(DRIVERS[row.action](before)), row.to, `${row.from} -- ${row.action} -- ${row.to}`);
		}
	});

	it("nextPhase reports a gate and table disagreement instead of freezing the phase", () => {
		assert.equal(nextPhase("active", "join"), "active");
		assert.equal(nextPhase("active", "verify-usable"), "terminated");
		assert.throws(() => nextPhase("retired", "join"), (e) => e instanceof TaskQueueError && e.code === "state-corrupt" && e.message.includes("retired"));
	});

	it("every phase is reachable from no task", () => {
		const seen = new Set<string>();
		const queue: { phase: string }[] = [{ phase: "none" }];
		while (queue.length > 0) {
			const at = queue.shift()!;
			for (const row of TASK_TRANSITIONS) {
				if ((row.from ?? "none") !== at.phase) continue;
				if (!seen.has(row.to)) {
					seen.add(row.to);
					queue.push({ phase: row.to });
				}
			}
		}
		assert.deepEqual([...seen].sort(), [...TASK_PHASES].sort());
	});

	it("every non-terminal phase can reach a terminal one", () => {
		const terminal = TASK_PHASES.filter(isTerminalPhase);
		assert.deepEqual(terminal, ["retired"], "retired is the only phase no action leaves");
		for (const phase of TASK_PHASES) {
			const reachable = new Set<string>();
			const queue: string[] = [phase];
			while (queue.length > 0) {
				const at = queue.shift()!;
				for (const row of TASK_TRANSITIONS) {
					if (row.from !== at) continue;
					if (!reachable.has(row.to)) {
						reachable.add(row.to);
						queue.push(row.to);
					}
				}
			}
			assert.ok(terminal.some((t) => reachable.has(t)), `no path from ${phase} to a terminal phase`);
		}
	});

	it("every gate agrees with the table", () => {
		for (const phase of TASK_PHASES) {
			const task = taskIn(phase).tasks.t1;
			assert.equal(canRecord(task), canTask(phase, "join"), `${phase}: record gate`);
			assert.equal(canVerify(task), canTask(phase, "verify-usable"), `${phase}: verify gate`);
			assert.equal(canPropose(task), canTask(phase, "propose"), `${phase}: proposal gate`);
			assert.equal(canBringBack(task), canTask(phase, "bring-back"), `${phase}: bring-back gate`);
			assert.equal(canRequeue(task), canTask(phase, "requeue-in-place"), `${phase}: re-queue gate`);
			assert.equal(canClose(task), canTask(phase, "close"), `${phase}: close gate`);
		}
	});

	it("every edge the table does not carry is refused by its op", () => {
		for (const phase of TASK_PHASES) {
			const before = taskIn(phase);
			for (const action of TASK_TRANSITIONS.map((t) => t.action)) {
				// The fork row creates a task; a task in any phase cannot stop
				// a second task from being forked, so it is not an edge from a
				// phase. Its own rule is the duplicate id, checked below.
				if (action === "fork") continue;
				if (canTask(phase, action)) continue;
				// The bring-back on a retired task is the replay, not an
				// edge: it is the one call that answers the same request
				// twice. It changes no state, which the next test holds it to.
				if (phase === "retired" && action === "bring-back") continue;
				assert.throws(() => DRIVERS[action](before), (e) => e instanceof TaskQueueError, `${phase} -- ${action} must be refused`);
			}
		}
	});

	it("a refused edge leaves the state it was refused on unchanged", () => {
		for (const phase of TASK_PHASES) {
			const before = taskIn(phase);
			for (const action of TASK_TRANSITIONS.map((t) => t.action)) {
				if (action === "fork" || canTask(phase, action) || (phase === "retired" && action === "bring-back")) continue;
				assert.throws(() => DRIVERS[action](before), (e) => e instanceof TaskQueueError);
				assert.equal(phaseAfter(before), phase, `${phase} -- ${action} must not move the phase`);
			}
		}
	});

	it("the bring-back replay on a retired task is the one call that answers twice", () => {
		const retired = taskIn("retired");
		const replay = bringBackOp(retired, { taskId: "t1", paths: ["a.txt"], applied: [], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT);
		assert.equal(replay.state.tasks.t1.phase, "retired", "the phase does not move");
		assert.deepEqual(replay.events, [], "a replay records no second bring-back");
		assert.deepEqual(replay.state.tasks.t1.bringBack, retired.tasks.t1.bringBack, "the recorded file set is the first one");
		assert.equal(canTask("retired", "bring-back"), false, "the replay is not a table edge");
	});

	it("a fork of an already-forked id is refused, in every phase", () => {
		for (const phase of TASK_PHASES) {
			const before = taskIn(phase);
			assert.throws(
				() => forkOp(before, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: MAIN }, AT),
				(e) => e instanceof TaskQueueError && e.code === "task-duplicate",
				`${phase}: a duplicate task id must be refused`,
			);
		}
	});

	it("names the legal from-phases in the rejection message", () => {
		assert.equal(legalFrom("join"), "forked or active");
		assert.equal(legalFrom("bring-back"), "terminated");
		assert.equal(legalFrom("requeue-in-place"), "active");
		assert.equal(legalFrom("close"), "retired");
	});

	it("lists the actions each phase admits", () => {
		assert.deepEqual(taskActions("forked"), ["join"]);
		assert.deepEqual(taskActions("active"), ["join", "verify-usable", "verify-not-usable", "requeue-in-place", "requeue-fresh"]);
		assert.deepEqual(taskActions("terminated"), ["propose", "bring-back"]);
		assert.deepEqual(taskActions("retired"), ["close"]);
	});

	it("the re-queue rows leave the not-usable audit in the phase they name", () => {
		const audited = notUsableAudit();
		assert.equal(audited.tasks.t1.phase, "active");
		assert.equal(phaseAfter(requeueOp(audited, { taskId: "t1", route: "in-place", head: "h1" }, AT).state), "active");
		assert.equal(phaseAfter(requeueOp(audited, { taskId: "t1", route: "fresh", head: "b0" }, AT).state), "forked");
	});
});

describe("the queue-entry transition table", () => {
	const ENTRY_ACTIONS: EntryAction[] = ["schedule", "trigger"];

	it("carries exactly the three states and the two edges between them", () => {
		assert.deepEqual(ENTRY_TRANSITIONS, [
			{ from: "requested", action: "schedule", to: "scheduled" },
			{ from: "scheduled", action: "trigger", to: "triggered" },
		]);
	});

	it("every row is the transition the queue performs", () => {
		const requested = [{ entryId: "t1#1", taskId: "t1", workerId: "t1", workdir: "/wt/t1", requestId: "t1-1", requestSeq: 1, state: "requested" } as const];
		const scheduled = transitionSchedule(requested, "t1#1").entries;
		assert.equal(entryTo("requested", "schedule"), "scheduled");
		assert.equal(transitionTrigger(scheduled, "t1#1").entry.state, "triggered");
		assert.equal(entryTo("scheduled", "trigger"), "triggered");
	});

	it("a triggered entry has no outgoing edge, so it triggers at most once (I5)", () => {
		assert.deepEqual(ENTRY_TRANSITIONS.filter((t) => t.from === "triggered"), []);
		const triggered = [{ entryId: "t1#1", taskId: "t1", workerId: "t1", workdir: "/wt/t1", requestId: "t1-1", requestSeq: 1, state: "triggered" } as const];
		assert.throws(() => transitionTrigger(triggered, "t1#1"), (e) => e instanceof TaskQueueError && e.code === "entry-already-triggered");
	});

	it("refuses the edges the table does not carry (I4)", () => {
		const requested = [{ entryId: "t1#1", taskId: "t1", workerId: "t1", workdir: "/wt/t1", requestId: "t1-1", requestSeq: 1, state: "requested" } as const];
		// A requested entry cannot trigger before it is scheduled.
		assert.throws(() => transitionTrigger(requested, "t1#1"), (e) => e instanceof TaskQueueError && e.code === "entry-not-scheduled");
		// A scheduled entry cannot be scheduled again.
		const scheduled = transitionSchedule(requested, "t1#1").entries;
		assert.throws(() => transitionSchedule(scheduled, "t1#1"), (e) => e instanceof TaskQueueError && e.code === "entry-not-requested");
		assert.equal(entryTo("requested", "trigger"), undefined);
		assert.equal(entryTo("scheduled", "schedule"), undefined);
	});
});

describe("the run transition table", () => {
	it("closes an open run once, and a closed run has no outgoing edge", () => {
		assert.deepEqual(RUN_TRANSITIONS, [{ from: "open", action: "close", to: "closed" }]);
		assert.equal(runTo("open", "close"), "closed");
		assert.equal(runTo("closed", "close"), undefined);
	});

	it("a closed run refuses every transition", () => {
		const closed = closeOp(broughtBackTask(), AT).state;
		assert.equal(closed.closed, true);
		assert.throws(() => forkOp(closed, { taskId: "t2", workdir: "/wt/t2", branch: "exp/t2", baseline: "b0", mainRoot: MAIN }, AT), (e) => e instanceof TaskQueueError && e.code === "run-closed");
	});
});

/** One task, audited usable, proposed, and brought back. */
function broughtBackTask(): RunState {
	let s = freshState(MAIN, `${MAIN}/.taskq`, AT);
	s = forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: MAIN }, AT).state;
	s = recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, AT).state;
	s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
	s = triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, AT).state;
	s = verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT).state;
	s = proposalOp(s, { taskId: "t1", description: "", paths: ["a.txt"] }, AT).state;
	return bringBackOp(s, { taskId: "t1", paths: ["a.txt"], applied: ["a.txt"], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, AT).state;
}
