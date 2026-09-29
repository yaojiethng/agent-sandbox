/**
 * The full run: a two-task fork/join/re-queue lifecycle against a real git
 * repository, driven through the Run facade and the worker protocol -
 * poll, record, schedule, trigger, re-dispatch, terminal request, verify,
 * proposal, verdict, merge, retire, close - with the invariant checks at
 * every stage.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { entryIdOf, getEntry } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import {
	closeOp,
	forkOp,
	mergeOp,
	proposalOp,
	recordOp,
	retireOp,
	scheduleOp,
	triggerOp,
	verifyOp,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { readJournal } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { addWorktree, listBranches, listWorktrees, pruneWorktree, statusPorcelain } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyVerdict } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { listWorkerRequests } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/protocol.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, workerRequest, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

function workerSegment(wt: string, files: Record<string, string>, msg: string): void {
	for (const [name, content] of Object.entries(files)) {
		writeFile(wt, name, content);
	}
	commitAll(wt, msg);
}

describe("full two-task lifecycle", () => {
	it("holds I1-I10 across fork, re-queue, verification, verdicts, and close", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const stateDir = path.join(dir, ".taskq");
			const wt1 = path.join(dir, "wt-t1");
			const wt2 = path.join(dir, "wt-t2");

			// --- fork: one worktree and branch per task, one baseline. ---
			const run = Run.open(stateDir, root, AT);
			run.handle((s) => forkOp(s, { taskId: "t1", workdir: wt1, branch: "exp/t1", baseline, mainRoot: root }, AT));
			run.handle((s) => forkOp(s, { taskId: "t2", workdir: wt2, branch: "exp/t2", baseline, mainRoot: root }, AT));
			addWorktree(root, { branch: "exp/t1", path: wt1, baseline });
			addWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			// I10 starts true: the branches exist, registered by the tasks.
			assert.ok(listBranches(root).includes("exp/t1"));

			// --- task t1, segment 1. ---
			workerSegment(wt1, { "src/alpha.ts": "v1\n" }, "t1 seg1");
			const req1 = workerRequest(wt1, "t1", "running", "alpha ready, review the approach");
			const req1Id = path.basename(req1, ".json");
			// The primary polls, records, schedules, and triggers.
			assert.deepEqual(listWorkerRequests(wt1).map((r) => r.requestId), [path.basename(req1, ".json")]);
			run.handle((s) => recordOp(s, { taskId: "t1", requestId: path.basename(req1, ".json"), status: "running", workdir: wt1 }, AT));

			// A second request while one is still pending is rejected; the
			// worker holds until the break point is cleared.
			assert.throws(
				() => run.handle((s) => recordOp(s, { taskId: "t1", requestId: "t1-race", status: "running", workdir: wt1 }, AT)),
				(e) => e instanceof TaskQueueError && e.code === "request-pending-task",
			);

			run.handle((s) => scheduleOp(s, entryIdOf("t1", 1), AT));
			run.handle((s) => triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, AT));
			// I6: nothing of the worker's landed in the main tree.
			assert.equal(statusPorcelain(root), "");
			assert.equal(fs.existsSync(path.join(root, "src", "alpha.ts")), false);

			// --- re-queue: cleared break point, same worker, next segment. ---
			workerSegment(wt1, { "src/alpha.ts": "v2\n", "src/beta.ts": "b\n" }, "t1 seg2");
			const req2 = workerRequest(wt1, "t1", "done", "terminal: report written");
			run.handle((s) => recordOp(s, { taskId: "t1", requestId: path.basename(req2, ".json"), status: "done", workdir: wt1 }, AT));
			run.handle((s) => scheduleOp(s, entryIdOf("t1", 2), AT));
			run.handle((s) => triggerOp(s, { entryId: entryIdOf("t1", 2), head: "h2", changed: 2 }, AT));

			// --- task t2: single segment, terminal straight after fork. ---
			workerSegment(wt2, { "docs/design.md": "d\n" }, "t2 seg1");
			const req3 = workerRequest(wt2, "t2", "done", "terminal");
			run.handle((s) => recordOp(s, { taskId: "t2", requestId: path.basename(req3, ".json"), status: "done", workdir: wt2 }, AT));
			run.handle((s) => scheduleOp(s, entryIdOf("t2", 1), AT));
			run.handle((s) => triggerOp(s, { entryId: entryIdOf("t2", 1), head: "h2b", changed: 1 }, AT));

			// --- restart survival: a fresh Run sees the same queue. ---
			const run2 = Run.open(stateDir, root, AT);
			assert.equal(run2.current().entries.length, 3);
			assert.equal(run2.current().entries.every((e) => e.state === "triggered"), true);

			// --- verification (I8): terminal break points triggered, no pending. ---
			run2.handle((s) => verifyOp(s, { taskId: "t1", outcome: "passed", notes: "report and output landed" }, AT));
			run2.handle((s) => verifyOp(s, { taskId: "t2", outcome: "passed", notes: "report landed" }, AT));
			assert.equal(run2.current().tasks.t1.phase, "verified");

			// --- proposal: distilled, protocol dir excluded. ---
			const t1ForProposal = run2.current().tasks.t1;
			const t1Paths = proposalPaths(root, t1ForProposal.baseline, t1ForProposal.branch);
			assert.ok(t1Paths.includes("src/alpha.ts"));
			assert.ok(!t1Paths.some((p) => p.startsWith("taskq/")));
			// The primary excludes src/beta.ts from the offer.
			const distilled = t1Paths.filter((p) => p !== "src/beta.ts");
			run2.handle((s) => proposalOp(s, { taskId: "t1", description: "alpha only", paths: distilled }, AT));
			run2.handle((s) => proposalOp(s, { taskId: "t2", description: "the doc", paths: ["docs/design.md"] }, AT));

			// --- verdicts: t1 partial, t2 none. The apply runs before the
			// state transition, exactly as the merge tool does. ---
			const t1 = run2.current().tasks.t1;
			const applied = applyVerdict(root, { baseline: t1.baseline, branch: t1.branch, proposal: t1.proposal!, verdict: { scope: "partial", paths: ["src/alpha.ts"] } });
			run2.handle((s) => mergeOp(s, { taskId: "t1", verdict: { scope: "partial", paths: ["src/alpha.ts"] }, applied: applied.applied, archived: false }, AT));
			assert.equal(fs.readFileSync(path.join(root, "src", "alpha.ts"), "utf8"), "v2\n");
			assert.equal(fs.existsSync(path.join(root, "src", "beta.ts")), false, "partial brought back exactly the named subset (I7)");
			run2.handle((s) => mergeOp(s, { taskId: "t2", verdict: { scope: "none" }, applied: [], archived: true }, AT));
			assert.equal(statusPorcelain(root).includes("docs/design.md"), false, "verdict none lands nothing (I7)");

			// --- retire and close. The retire tool prunes the worktree and
			// the branch first, then records the retired phase; a failed
			// prune leaves the state and the journal untouched (wired tests
			// exercise both). ---
			run2.handle((s) => retireOp(s, "t1", AT));
			pruneWorktree(root, { branch: "exp/t1", path: wt1, baseline });
			run2.handle((s) => retireOp(s, "t2", AT));
			pruneWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			const close = run2.handle((s) => closeOp(s, AT));
			assert.deepEqual(close.data.counts, { tasks: 2, entries: 3, triggered: 3, pending: 0, requests: 3 });
			// I10: no registered worktree and no worker branch survive.
			assert.deepEqual(listWorktrees(root).map((p) => path.resolve(p)), [path.resolve(root)]);
			assert.deepEqual(listBranches(root), ["main"]);
			// The journal tells the whole story in order.
			const types = readJournal(stateDir).map((e) => e.type);
			assert.deepEqual(types, [
				"run:open",
				"task:fork",
				"task:fork",
				"request:record",
				"entry:schedule",
				"entry:trigger",
				"request:record",
				"entry:schedule",
				"entry:trigger",
				"request:record",
				"entry:schedule",
				"entry:trigger",
				"verify",
				"verify",
				"proposal",
				"proposal",
				"merge",
				"merge",
				"retire",
				"retire",
				"run:close",
			]);
			// I1: three requests recorded, three entries, three triggers; no
			// duplicate and no orphan in the whole run.
			assert.deepEqual(close.data.counts.requests, 3);
			assert.equal(getEntry(run2.current().entries, entryIdOf("t1", 1))?.state, "triggered");
		} finally {
			rmrf(dir);
		}
	});

	it("a rejected merge leaves the main tree untouched (I9 ordering failure)", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const stateDir = path.join(dir, ".taskq");
			const wt = path.join(dir, "wt-t1");
			const run = Run.open(stateDir, root, AT);
			run.handle((s) => forkOp(s, { taskId: "t1", workdir: wt, branch: "exp/t1", baseline, mainRoot: root }, AT));
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			workerSegment(wt, { "README.md": "worker version\n" }, "seg");
			const req = workerRequest(wt, "t1", "done", "terminal");
			run.handle((s) => recordOp(s, { taskId: "t1", requestId: req, status: "done", workdir: wt }, AT));
			run.handle((s) => scheduleOp(s, entryIdOf("t1", 1), AT));
			run.handle((s) => triggerOp(s, { entryId: entryIdOf("t1", 1), head: "h", changed: 1 }, AT));
			run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "passed", notes: "ok" }, AT));
			run.handle((s) => proposalOp(s, { taskId: "t1", description: "", paths: ["README.md"] }, AT));
			// The operator keeps the main tree dirty on the path the verdict
			// touches (primary mid-edit): the verdict must not apply, and
			// the state must not advance.
			writeFile(root, "README.md", "primary mid-edit\n");
			const t1 = run.current().tasks.t1;
			assert.throws(
				() => applyVerdict(root, { baseline: t1.baseline, branch: t1.branch, proposal: t1.proposal!, verdict: { scope: "all" } }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
			assert.equal(run.current().tasks.t1.phase, "verified", "the failed merge changed no state");
			assert.equal(fs.readFileSync(path.join(root, "README.md"), "utf8"), "primary mid-edit\n", "the worker's version did not overwrite the primary's edit");
		} finally {
			rmrf(dir);
		}
	});
});