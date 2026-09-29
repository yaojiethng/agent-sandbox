/**
 * Per-operation cost, measured on this host: the queue transitions in
 * memory, the persisted round trip (state file plus journal), and the
 * git-backed operations. The numbers print as a table; the assertions only
 * guard against a pathological regression, so the suite stays stable on a
 * loaded host.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as path from "node:path";
import { performance } from "node:perf_hooks";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { freshState } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import {
	bringBackOp,
	forkOp,
	joinOp,
	proposalOp,
	verifyOp,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { addWorktree } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyBringBack } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, workerRequest, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

function time<T>(fn: () => T): { ms: number; value: T } {
	const t0 = performance.now();
	const value = fn();
	return { ms: performance.now() - t0, value };
}

describe("per-operation cost", () => {
	it("measures the join, verify, proposal, and bring-back", () => {
		const rows: string[] = [];

		// Pure in-memory transitions on a single task: the join, the
		// three-state transition it subsumes, one segment at a time.
		const N = 2000;
		let s = freshState("/repo/main", "/repo/main/.taskq", AT);
		s = forkOp(s, { taskId: "t", workdir: "/wt/t", branch: "exp/t", baseline: "b0", mainRoot: "/repo/main" }, AT).state;
		let joinMs = 0;
		for (let i = 1; i <= N; i++) {
			joinMs += time(() => {
				s = joinOp(s, { taskId: "t", requestId: `t-${i}`, status: "running", head: `h${i}`, changed: 1 }, AT).state;
			}).ms;
		}
		rows.push(`join (pure)           ${(joinMs / N * 1000).toFixed(2)} us/op`);

		const dir = tmpdir();
		try {
			// Persisted segment cycle through the Run facade: one join per
			// segment, the whole load-derive-save under the ownership lock.
			const run = Run.open(path.join(dir, ".taskq"), "/repo/main", AT);
			run.handle((st) => forkOp(st, { taskId: "t", workdir: "/wt/t", branch: "exp/t", baseline: "b0", mainRoot: "/repo/main" }, AT));
			const M = 200;
			const pers = time(() => {
				for (let i = 1; i <= M; i++) {
					run.handle((st) => joinOp(st, { taskId: "t", requestId: `t-${i}`, status: "running", head: `h${i}`, changed: 1 }, AT));
				}
			});
			rows.push(`join (persisted)      ${(pers.ms / M).toFixed(2)} ms/op`);
			assert.ok(pers.ms / M < 25, `persisted op too slow: ${(pers.ms / M).toFixed(2)} ms`);

			// Git-backed end-to-end tail: verify, proposal, bring-back.
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-b");
			const branch = "exp/b";
			addWorktree(root, { branch, path: wt, baseline });
			for (let i = 0; i < 20; i++) {
				writeFile(wt, `files/f${i}.txt`, `content ${i}\n`);
			}
			commitAll(wt, "twenty files");
			const req = workerRequest(wt, "b", "done", "terminal");
			const runB = Run.open(path.join(dir, ".taskq-b"), root, AT);
			runB.handle((st) => forkOp(st, { taskId: "b", workdir: wt, branch, baseline, mainRoot: root }, AT));
			runB.handle((st) => joinOp(st, { taskId: "b", requestId: req, status: "done", head: "h", changed: 20 }, AT));
			const tail = time(() => {
				runB.handle((st) => verifyOp(st, { taskId: "b", outcome: "usable", notes: "ok" }, AT));
			});
			rows.push(`verify (persisted)    ${tail.ms.toFixed(1)} ms/op`);
			const props = time(() => proposalPaths(root, baseline, branch));
			rows.push(`proposal (20 files)  ${props.ms.toFixed(1)} ms`);
			const proposal = { paths: props.value, description: "", at: AT };
			const back = time(() => applyBringBack(root, { baseline, branch, proposal, paths: props.value }));
			rows.push(`bring-back (20 files) ${back.ms.toFixed(1)} ms`);
			assert.ok(back.ms < 2000, `bring-back too slow: ${back.ms.toFixed(1)} ms`);
			const final = time(() => {
				runB.handle((st) => proposalOp(st, { taskId: "b", description: "", paths: props.value }, AT));
				runB.handle((st) => bringBackOp(st, { taskId: "b", paths: props.value, applied: props.value, archived: false, removedWorktree: wt, prunedBranch: branch, resumed: false }, AT));
			});
			rows.push(`proposal+bring-back (persisted) ${(final.ms / 2).toFixed(1)} ms/op`);
		} finally {
			rmrf(dir);
		}
		console.log("\nbench table (host: node " + process.version + "):\n" + rows.map((r) => "  " + r).join("\n") + "\n");
	});
});