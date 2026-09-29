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
import { entryIdOf } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { freshState } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import {
	forkOp,
	mergeOp,
	proposalOp,
	recordOp,
	scheduleOp,
	triggerOp,
	verifyOp,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { addWorktree } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyVerdict } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, workerRequest, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

function time<T>(fn: () => T): { ms: number; value: T } {
	const t0 = performance.now();
	const value = fn();
	return { ms: performance.now() - t0, value };
}

describe("per-operation cost", () => {
	it("measures enqueue, schedule, trigger, verify, proposal, and merge", () => {
		const rows: string[] = [];

		// Pure in-memory transitions on a single task: one segment at a time
		// (record, then schedule, then trigger), which is the queue's
		// serialized per-task shape.
		const N = 2000;
		let s = freshState("/repo/main", "/repo/main/.taskq", AT);
		s = forkOp(s, { taskId: "t", workdir: "/wt/t", branch: "exp/t", baseline: "b0", mainRoot: "/repo/main" }, AT).state;
		let recMs = 0;
		let schMs = 0;
		let trigMs = 0;
		for (let i = 1; i <= N; i++) {
			recMs += time(() => {
				s = recordOp(s, { taskId: "t", requestId: `t-${i}`, status: "running", workdir: "/wt/t" }, AT).state;
			}).ms;
			schMs += time(() => {
				s = scheduleOp(s, entryIdOf("t", i), AT).state;
			}).ms;
			trigMs += time(() => {
				s = triggerOp(s, { entryId: entryIdOf("t", i), head: `h${i}`, changed: 1 }, AT).state;
			}).ms;
		}
		rows.push(`record (pure)        ${(recMs / N * 1000).toFixed(2)} us/op`);
		rows.push(`schedule (pure)      ${(schMs / N * 1000).toFixed(2)} us/op`);
		rows.push(`trigger (pure)       ${(trigMs / N * 1000).toFixed(2)} us/op`);

		const dir = tmpdir();
		try {
			// Persisted segment cycle through the Run facade: record, schedule,
			// and trigger of one segment each.
			const run = Run.open(path.join(dir, ".taskq"), "/repo/main", AT);
			run.handle((st) => forkOp(st, { taskId: "t", workdir: "/wt/t", branch: "exp/t", baseline: "b0", mainRoot: "/repo/main" }, AT));
			const M = 200;
			const pers = time(() => {
				for (let i = 1; i <= M; i++) {
					run.handle((st) => recordOp(st, { taskId: "t", requestId: `t-${i}`, status: "running", workdir: "/wt/t" }, AT));
					run.handle((st) => scheduleOp(st, entryIdOf("t", i), AT));
					run.handle((st) => triggerOp(st, { entryId: entryIdOf("t", i), head: `h${i}`, changed: 1 }, AT));
				}
			});
			rows.push(`segment cycle (persisted) ${(pers.ms / (M * 3)).toFixed(2)} ms/op`);
			assert.ok(pers.ms / (M * 3) < 25, `persisted op too slow: ${(pers.ms / (M * 3)).toFixed(2)} ms`);

			// Git-backed end-to-end tail: verify, proposal, merge.
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
			runB.handle((st) => recordOp(st, { taskId: "b", requestId: req, status: "done", workdir: wt }, AT));
			const e1 = entryIdOf("b", 1);
			const tail = time(() => {
				runB.handle((st) => scheduleOp(st, e1, AT));
				runB.handle((st) => triggerOp(st, { entryId: e1, head: "h", changed: 20 }, AT));
				runB.handle((st) => verifyOp(st, { taskId: "b", outcome: "passed", notes: "ok" }, AT));
			});
			rows.push(`schedule+trigger+verify (persisted) ${(tail.ms / 3).toFixed(1)} ms/op`);
			const props = time(() => proposalPaths(root, baseline, branch));
			rows.push(`proposal (20 files)  ${props.ms.toFixed(1)} ms`);
			const proposal = { paths: props.value, description: "", at: AT };
			const merge = time(() => applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } }));
			rows.push(`merge all (20 files) ${merge.ms.toFixed(1)} ms`);
			assert.ok(merge.ms < 2000, `merge too slow: ${merge.ms.toFixed(1)} ms`);
			const final = time(() => {
				runB.handle((st) => proposalOp(st, { taskId: "b", description: "", paths: props.value }, AT));
				runB.handle((st) => mergeOp(st, { taskId: "b", verdict: { scope: "all" }, applied: props.value, archived: false }, AT));
			});
			rows.push(`proposal+merge op (persisted) ${(final.ms / 2).toFixed(1)} ms/op`);
		} finally {
			rmrf(dir);
		}
		console.log("\nbench table (host: node " + process.version + "):\n" + rows.map((r) => "  " + r).join("\n") + "\n");
	});
});