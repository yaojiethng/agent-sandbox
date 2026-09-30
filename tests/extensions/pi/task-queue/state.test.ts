/**
 * Persistence: the atomic state file, the journal, restart survival, and
 * the corruption guards.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { freshState, loadState, saveState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import { appendJournal, readJournal } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { Run } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { lockPathOf } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/lock.ts";
import { forkOp, recordOp, triggerOp, scheduleOp } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { entryIdOf } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { withTmp } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

describe("state file", () => {
	it("round-trips every field", () => {
		withTmp((dir) => {
			let s = freshState("/repo/main", path.join(dir, ".taskq"), AT);
			s = forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT).state;
			s = recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, AT).state;
			s = scheduleOp(s, entryIdOf("t1", 1), AT).state;
			s = triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, AT).state;
			saveState(s);
			const loaded = loadState(path.join(dir, ".taskq"));
			assert.ok(loaded);
			assert.equal(loaded.tasks.t1.workerId, "t1");
			assert.equal(loaded.requests["t1-1"], "t1#1");
			assert.equal(loaded.entries[0].state, "triggered");
			assert.equal(loaded.entries[0].workdir, "/wt/t1");
		});
	});

	it("returns undefined for a missing state and throws for a corrupt one", () => {
		withTmp((dir) => {
			assert.equal(loadState(path.join(dir, ".taskq")), undefined);
			fs.mkdirSync(path.join(dir, ".taskq"));
			fs.writeFileSync(path.join(dir, ".taskq", "state.json"), "{not json", "utf8");
			assert.throws(() => loadState(path.join(dir, ".taskq")), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
		});
	});

	it("the shape guard rejects tasks as an array and malformed entries", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			fs.mkdirSync(stateDir);
			const write = (state: unknown) => fs.writeFileSync(path.join(stateDir, "state.json"), JSON.stringify(state), "utf8");
			const base = { mainRoot: "/repo/main", stateDir, openedAt: AT, closed: false, entries: [], tasks: {}, requests: {} };
			write({ ...base, version: 3, tasks: [] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 3, requests: [] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 3, entries: [{ entryId: "t1#1", taskId: "t1", requestId: 7, requestSeq: 1, state: "requested" }] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 3, entries: [{ entryId: "t1#1", taskId: "t1", workerId: "t1", workdir: "/wt/t1", requestId: "t1-1", requestSeq: 1, state: "triggering" }] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
		});
	});

	it("rejects a task phase the transition table does not name", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			fs.mkdirSync(stateDir);
			const base = { mainRoot: "/repo/main", stateDir, openedAt: AT, closed: false, entries: [], requests: {} };
			// A phase from the pre-consolidation phase set, on a current
			// version: a state that loads as valid would fail every gate with
			// a message about the phase, so it is refused as corruption.
			fs.writeFileSync(path.join(stateDir, "state.json"), JSON.stringify({ ...base, version: 3, tasks: { t1: { taskId: "t1", phase: "verified" } } }), "utf8");
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			// The current phase set loads.
			fs.writeFileSync(path.join(stateDir, "state.json"), JSON.stringify({ ...base, version: 3, tasks: { t1: { taskId: "t1", phase: "terminated" } } }), "utf8");
			assert.equal(loadState(stateDir)?.tasks.t1.phase, "terminated");
		});
	});

	it("loads the current version and refuses every earlier one", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			fs.mkdirSync(stateDir);
			const base = { mainRoot: "/repo/main", stateDir, openedAt: AT, closed: false, entries: [], tasks: {}, requests: {} };
			const file = path.join(stateDir, "state.json");
			fs.writeFileSync(file, JSON.stringify({ ...base, version: 3 }), "utf8");
			assert.equal(loadState(stateDir)?.version, 3);
			// Version 2 carries the pre-consolidation phase set, version 1 no
			// baseline capture, and 99 is unknown: none of them is a run this
			// extension can drive, so each is one loud refusal.
			for (const version of [1, 2, 99]) {
				fs.writeFileSync(file, JSON.stringify({ ...base, version }), "utf8");
				assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt", `version ${String(version)} is refused`);
			}
		});
	});

	it("leaves no temp file behind", () => {
		withTmp((dir) => {
			const s = freshState("/repo/main", path.join(dir, ".taskq"), AT);
			saveState(s);
			const files = fs.readdirSync(path.join(dir, ".taskq")).sort();
			assert.deepEqual(files, ["state.json"]);
		});
	});

	it("I11: a crash between the temp write and the rename leaves the prior state intact", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			let s = freshState("/repo/main", stateDir, AT);
			s = forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT).state;
			saveState(s);
			// A crash between writeFileSync(tmp) and rename leaves a torn temp
			// file; the transition never partially lands in the state file.
			fs.writeFileSync(path.join(stateDir, "state.json.tmp"), "{torn", "utf8");
			const loaded = loadState(stateDir);
			assert.ok(loaded);
			assert.equal(loaded.tasks.t1.phase, "forked");
		});
	});
});

describe("journal", () => {
	it("appends and replays events in order", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			appendJournal(stateDir, [
				{ type: "run:open", at: AT, mainRoot: "/repo/main" },
				{ type: "task:fork", at: AT, taskId: "t1", workerId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0" },
			]);
			appendJournal(stateDir, [{ type: "entry:schedule", at: AT, entryId: "t1#1", taskId: "t1" }]);
			const events = readJournal(stateDir);
			assert.equal(events.length, 3);
			assert.equal(events[0].type, "run:open");
			assert.equal(events[1].type, "task:fork");
			assert.equal(events[2].type, "entry:schedule");
		});
	});

	it("returns an empty list when no journal exists", () => {
		withTmp((dir) => {
			assert.deepEqual(readJournal(path.join(dir, ".taskq")), []);
		});
	});
});

describe("Run facade", () => {
	it("starts a fresh run, persists per operation, and survives a restart", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			const run1 = Run.open(stateDir, "/repo/main", AT);
			assert.deepEqual(run1.current().entries, []);
			run1.handle((s) => forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT));
			run1.handle((s) => recordOp(s, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, AT));
			// A fresh process would open a new Run on the same directory.
			const run2 = Run.open(stateDir, "/repo/main", AT);
			assert.equal(run2.current().tasks.t1.phase, "active");
			assert.equal(run2.current().requests["t1-1"], "t1#1");
			// The journal carries the same transitions the state does.
			const journal = readJournal(stateDir);
			assert.deepEqual(
				journal.map((e) => e.type),
				["run:open", "task:fork", "request:record"],
			);
		});
	});

	it("refuses a state directory opened for another main tree", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			Run.open(stateDir, "/repo/a", AT);
			assert.throws(() => Run.open(stateDir, "/repo/b", AT), (e) => e instanceof TaskQueueError && e.code === "run-state-mismatch");
		});
	});

	it("surfaces a journal failure without failing the operation", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			const run = Run.open(stateDir, "/repo/main", AT);
			// Make the journal unwritable by replacing the journal file with a
			// directory of the same name.
			const journal = path.join(run.stateDir, "journal.jsonl");
			fs.rmSync(journal);
			fs.mkdirSync(journal);
			const res = run.handle((s) => forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT));
			assert.ok(res.journalError);
			assert.equal(run.current().tasks.t1.phase, "forked", "the op still persisted despite the journal failure");
		});
	});

	it("refuses an asynchronous derive, and writes nothing when it does", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			const run = Run.open(stateDir, "/repo/main", AT);
			// A derive that awaits would release the ownership lock at the
			// await and keep writing past it. The derive body is synchronous
			// by contract, so this call does not type-check; the cast stands
			// for what the extension gets when jiti erases the type.
			const derive = async () => forkOp(run.current(), { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT);
			const transact = (fn: unknown): unknown => run.transact(fn as never);
			assert.throws(
				() => transact(derive),
				(e) => e instanceof TaskQueueError && e.code === "state-corrupt" && /a derive must be synchronous/.test(e.message),
			);
			assert.equal(run.current().tasks.t1, undefined, "the refused derive wrote no state");
			assert.ok(!readJournal(stateDir).some((e) => e.type === "task:fork"), "the refused derive wrote no journal event");
			assert.equal(fs.existsSync(lockPathOf(stateDir)), false, "the refused transaction released the lock");
		});
	});

	it("runs a transition's post-record step after the state write, under the lock", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			const run = Run.open(stateDir, "/repo/main", AT);
			const order: string[] = [];
			run.handle((s) => ({
				...forkOp(s, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: "/repo/main" }, AT),
				commit: () => {
					order.push("commit");
					order.push(`lock:${fs.existsSync(lockPathOf(stateDir))}`);
					order.push(`state:${run.current().tasks.t1?.phase ?? "none"}`);
				},
			}));
			assert.deepEqual(order, ["commit", "lock:true", "state:forked"], "the post-record step runs last, with the record durable and the lock held");
		});
	});
});