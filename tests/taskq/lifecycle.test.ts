/**
 * The full run: a two-task fork/join/verify/bring-back lifecycle against a
 * real git repository, driven through the Run facade and the worker
 * protocol - fork, join, a not-usable audit, a re-queue, the terminal
 * request, the usable audit, the proposal, the bring-back, close - with the
 * invariant checks at every stage.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { entryIdOf, getEntry } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { bringBackOp, closeOp, forkOp, joinOp, proposalOp, requeueOp, verifyOp } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { readJournal } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { addWorktree, listBranches, listWorktrees, pruneWorktree, statusPorcelain } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyBringBack, archiveTrack } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
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
	it("holds I1-I10 across fork, re-queue, verification, bring-back, and close", () => {
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
			// The primary joins: one call records, schedules, and triggers.
			assert.deepEqual(listWorkerRequests(wt1).map((r) => r.requestId), [req1Id]);
			run.handle((s) => joinOp(s, { taskId: "t1", requestId: req1Id, status: "running", head: "h1", changed: 1 }, AT));

			// A request that lands before the operator clears the first one
			// is not lost: it waits for its turn (J4, J5), and the join test
			// drives that race.
			// I6: nothing of the worker's landed in the main tree.
			assert.equal(statusPorcelain(root), "");
			assert.equal(fs.existsSync(path.join(root, "src", "alpha.ts")), false);

			// --- re-queue: a not-usable audit, the same worker, the next
			// segment in the same worktree. ---
			workerSegment(wt1, { "src/alpha.ts": "v2\n", "src/beta.ts": "b\n" }, "t1 seg2");
			const req2 = workerRequest(wt1, "t1", "done", "terminal: report missing");
			run.handle((s) => joinOp(s, { taskId: "t1", requestId: path.basename(req2, ".json"), status: "done", head: "h2", changed: 2 }, AT));
			run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "not-usable", notes: "the report is missing" }, AT));
			run.handle((s) => requeueOp(s, { taskId: "t1", route: "in-place", head: "h2" }, AT));
			assert.equal(run.current().tasks.t1.phase, "active", "the in-place route keeps the task in the queue");
			// The queue entries survive the re-queue: the next segment is a
			// new entry, not a second run (I1).
			assert.deepEqual(run.current().entries.map((e) => e.entryId), ["t1#1", "t1#2"]);

			// --- task t2: single segment, terminal straight after fork. ---
			workerSegment(wt2, { "docs/design.md": "d\n" }, "t2 seg1");
			const req3 = workerRequest(wt2, "t2", "done", "terminal");
			run.handle((s) => joinOp(s, { taskId: "t2", requestId: path.basename(req3, ".json"), status: "done", head: "h2b", changed: 1 }, AT));

			// --- the repair segment: the worker's third segment, in the same
			// worktree, entered through the same join. ---
			workerSegment(wt1, { "src/alpha.ts": "v3\n", "src/beta.ts": "b\n" }, "t1 seg3");
			const req4 = workerRequest(wt1, "t1", "done", "terminal: report written");
			run.handle((s) => joinOp(s, { taskId: "t1", requestId: path.basename(req4, ".json"), status: "done", head: "h3", changed: 2 }, AT));

			// --- restart survival: a fresh Run sees the same queue. ---
			const run2 = Run.open(stateDir, root, AT);
			assert.equal(run2.current().entries.length, 4);
			assert.equal(run2.current().entries.every((e) => e.state === "triggered"), true);

			// --- verification (I8): terminal break points triggered, none pending.
			run2.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "report and output landed" }, AT));
			run2.handle((s) => verifyOp(s, { taskId: "t2", outcome: "usable", notes: "report landed" }, AT));
			assert.equal(run2.current().tasks.t1.phase, "terminated");
			assert.equal(run2.current().tasks.t1.verification?.outcome, "usable");

			// --- proposal: distilled, protocol dir excluded. ---
			const t1ForProposal = run2.current().tasks.t1;
			const t1Paths = proposalPaths(root, t1ForProposal.baseline, t1ForProposal.branch);
			assert.ok(t1Paths.includes("src/alpha.ts"));
			assert.ok(!t1Paths.some((p) => p.startsWith("taskq/")));
			// The primary excludes src/beta.ts from the offer.
			const distilled = t1Paths.filter((p) => p !== "src/beta.ts");
			run2.handle((s) => proposalOp(s, { taskId: "t1", description: "alpha only", paths: distilled }, AT));
			run2.handle((s) => proposalOp(s, { taskId: "t2", description: "the doc", paths: ["docs/design.md"] }, AT));

			// --- bring-back: t1 writes its named file set, t2 writes none.
			// The write and the prune both precede the record, exactly as the
			// tool does (I12). ---
			const t1 = run2.current().tasks.t1;
			const applied = applyBringBack(root, { baseline: t1.baseline, branch: t1.branch, proposal: t1.proposal!, paths: ["src/alpha.ts"] });
			pruneWorktree(root, { branch: "exp/t1", path: wt1, baseline });
			run2.handle((s) =>
				bringBackOp(s, { taskId: "t1", paths: ["src/alpha.ts"], applied: applied.applied, archived: false, removedWorktree: wt1, prunedBranch: "exp/t1", resumed: false }, AT),
			);
			assert.equal(fs.readFileSync(path.join(root, "src", "alpha.ts"), "utf8"), "v3\n");
			assert.equal(fs.existsSync(path.join(root, "src", "beta.ts")), false, "the bring-back wrote exactly the named subset (I7)");
			archiveTrack(stateDir, "t2", root, run2.current().tasks.t2.baseline, run2.current().tasks.t2.branch);
			pruneWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			run2.handle((s) => bringBackOp(s, { taskId: "t2", paths: [], applied: [], archived: true, removedWorktree: wt2, prunedBranch: "exp/t2", resumed: false }, AT));
			assert.equal(statusPorcelain(root).includes("docs/design.md"), false, "an empty file set lands nothing (I7)");
			assert.ok(fs.existsSync(path.join(stateDir, "archive", "t2.diff")), "the empty file set archived the branch diff");

			// --- close. Every task retired through its own bring-back, so the
			// close is the only call left.
			const close = run2.handle((s) => closeOp(s, AT));
			assert.deepEqual(close.data.counts, { tasks: 2, entries: 4, triggered: 4, pending: 0, requests: 4 });
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
				"verify",
				"task:requeue",
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
				"bringback",
				"bringback",
				"run:close",
			]);
			// I1: four requests recorded, four entries, four triggers; no
			// duplicate and no orphan in the whole run.
			assert.equal(close.data.counts.requests, 4);
			assert.equal(getEntry(run2.current().entries, entryIdOf("t1", 1))?.state, "triggered");
		} finally {
			rmrf(dir);
		}
	});

	it("a rejected bring-back leaves the main tree untouched (I9 ordering failure)", () => {
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
			run.handle((s) => joinOp(s, { taskId: "t1", requestId: req, status: "done", head: "h", changed: 1 }, AT));
			run.handle((s) => verifyOp(s, { taskId: "t1", outcome: "usable", notes: "ok" }, AT));
			run.handle((s) => proposalOp(s, { taskId: "t1", description: "", paths: ["README.md"] }, AT));
			// The operator keeps the main tree dirty on the path the file set
			// touches (primary mid-edit): the write must not apply, and the
			// state must not advance.
			writeFile(root, "README.md", "primary mid-edit\n");
			const t1 = run.current().tasks.t1;
			assert.throws(
				() => applyBringBack(root, { baseline: t1.baseline, branch: t1.branch, proposal: t1.proposal!, paths: ["README.md"] }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
			assert.equal(run.current().tasks.t1.phase, "terminated", "the failed bring-back changed no state");
			assert.equal(fs.readFileSync(path.join(root, "README.md"), "utf8"), "primary mid-edit\n", "the worker's version did not overwrite the primary's edit");
		} finally {
			rmrf(dir);
		}
	});
});
