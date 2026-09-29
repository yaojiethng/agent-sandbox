/**
 * Persistence: the atomic state file, the journal, restart survival, and
 * the corruption guards.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { freshState, loadState, saveState } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import { appendJournal, readJournal } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { forkOp, recordOp, triggerOp, scheduleOp } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { entryIdOf } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
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
			write({ ...base, version: 2, tasks: [] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 2, requests: [] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 2, entries: [{ entryId: "t1#1", taskId: "t1", requestId: 7, requestSeq: 1, state: "requested" }] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			write({ ...base, version: 2, entries: [{ entryId: "t1#1", taskId: "t1", workerId: "t1", workdir: "/wt/t1", requestId: "t1-1", requestSeq: 1, state: "triggering" }] });
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
		});
	});

	it("rejects an unknown state version and accepts a version-1 state", () => {
		withTmp((dir) => {
			const stateDir = path.join(dir, ".taskq");
			fs.mkdirSync(stateDir);
			const base = { mainRoot: "/repo/main", stateDir, openedAt: AT, closed: false, entries: [], tasks: {}, requests: {} };
			fs.writeFileSync(path.join(stateDir, "state.json"), JSON.stringify({ ...base, version: 99 }), "utf8");
			assert.throws(() => loadState(stateDir), (e) => e instanceof TaskQueueError && e.code === "state-corrupt");
			// A pre-baseline-capture state still loads; the close sweep skips
			// it because the baseline fields are absent.
			fs.writeFileSync(path.join(stateDir, "state.json"), JSON.stringify({ ...base, version: 1 }), "utf8");
			const loaded = loadState(stateDir);
			assert.ok(loaded);
			assert.equal(loaded.baselineWorktrees, undefined);
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
});