/**
 * The wired tool surface: the extension's real tool executions against a
 * real repository, in the production default configuration (state directory
 * beside the repo root, not inside it) and the crash-window recovery paths
 * the pure layers cannot exercise. The extension loads under jiti with pi's
 * package aliases, exactly as the pi runtime loads it.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";
import { Run } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { retireOp } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { applyVerdict } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { readJournal } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { git, pruneWorktree, statusPorcelain } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, writeFile } from "./helpers.ts";

const EXTENSION_ENTRY = path.resolve(
	import.meta.dirname,
	"../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts",
);

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;

function piAvailable(): boolean {
	return fs.existsSync(PI_PACKAGE_ENTRY);
}

interface WiredTool {
	name: string;
	execute: (...args: unknown[]) => Promise<{ details?: unknown; content?: unknown }>;
}

interface ToolCtx {
	cwd: string;
}

/** Load the extension factory and capture the registered tools. */
async function loadTools(): Promise<Record<string, WiredTool>> {
	const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
	const { createJiti } = await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"));
	const jiti = createJiti(EXTENSION_ENTRY, {
		alias: {
			"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
			"typebox": requireFromPi.resolve("typebox"),
			"@sinclair/typebox": requireFromPi.resolve("typebox"),
		},
	});
	const tools: Record<string, WiredTool> = {};
	const mod = (await jiti.import(EXTENSION_ENTRY)) as { default: (pi: { registerTool: (t: WiredTool) => void }) => void };
	mod.default({
		registerTool: (t) => {
			tools[t.name] = t;
		},
	});
	return tools;
}

/**
 * Execute one registered tool with a minimal primary/worker context. The
 * tool runs in its own jiti module graph, so its TaskQueueError does not
 * satisfy instanceof against the test's own import; errors are matched by
 * their code and name fields.
 */
function errorCode(e: unknown): string | undefined {
	if (typeof e !== "object" || e === null) return undefined;
	const code = (e as { code?: unknown }).code;
	return typeof code === "string" ? code : undefined;
}

async function callTool(tools: Record<string, WiredTool>, name: string, params: object, ctx: ToolCtx): Promise<Record<string, unknown>> {
	const tool = tools[name];
	assert.ok(tool, `tool ${name} is registered`);
	const result = await tool.execute("wired-1", params, undefined, undefined, {
		cwd: ctx.cwd,
		mode: "print",
		hasUI: false,
		ui: {},
	});
	assert.ok(result && typeof result === "object" && "details" in result, `${name} returned details`);
	return result.details as Record<string, unknown>;
}

const AT = "2026-01-01T00:00:00.000Z";

interface Fixture {
	dir: string;
	root: string;
	baseline: string;
	wt: string;
	stateDir: string;
	ctx: ToolCtx;
}

/**
 * Fork one task, push one terminal worker segment through record, schedule,
 * trigger, verify, and proposal. The run uses the production default state
 * directory: a sibling of the repo root, never inside the main tree.
 */
async function setupRun(tools: Record<string, WiredTool>): Promise<Fixture> {
	delete process.env.TASKQ_STATE_DIR;
	const dir = tmpdir();
	const repo = makeMainRepo(dir);
	const wt = path.join(dir, "wt-t1");
	const ctx = { cwd: repo.root };
	await callTool(tools, "taskq_fork", { taskId: "t1", workdir: wt, baseline: repo.baseline }, ctx);
	// A root-level file: porcelain reports new files in new directories as
	// the directory, so the assertion stays exact on the applied set.
	writeFile(wt, "a.ts", "v1\n");
	commitAll(wt, "seg");
	const req = await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "review the segment", status: "done" }, { cwd: wt });
	await callTool(tools, "taskq_record", { taskId: "t1", requestPath: req.file }, ctx);
	await callTool(tools, "taskq_schedule", { entryId: "t1#1" }, ctx);
	await callTool(tools, "taskq_trigger", { entryId: "t1#1" }, ctx);
	await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "passed", notes: "ok" }, ctx);
	await callTool(tools, "taskq_proposal", { taskId: "t1", description: "the segment" }, ctx);
	return { dir, root: repo.root, baseline: repo.baseline, wt, stateDir: path.join(dir, `.taskq-${path.basename(repo.root)}`), ctx };
}

function currentPhase(f: Fixture): string {
	return Run.open(f.stateDir, f.root).current().tasks.t1.phase;
}

const suite = piAvailable() ? {} : { skip: "pi installation not present" };

describe("wired tool surface", () => {
	it("runs a full merge in the production default state-directory layout", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The state directory is a sibling of the repo root: the merge's
			// clean-main gate passes in the documented configuration.
			assert.ok(fs.existsSync(path.join(f.stateDir, "state.json")));
			assert.ok(!fs.existsSync(path.join(f.root, ".taskq")));
			const merged = await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			assert.equal(merged.phase, "merged");
			assert.deepEqual(merged.applied, ["a.ts"]);
			assert.equal(fs.readFileSync(path.join(f.root, "a.ts"), "utf8"), "v1\n");
			// The state directory never shows up in the main tree's porcelain.
			const status = statusPorcelain(f.root).split("\n").filter((l) => l !== "").map((l) => l.slice(3));
			assert.deepEqual(status, ["a.ts"]);
			const retired = await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			assert.equal(retired.phase, "retired");
			assert.equal(fs.existsSync(f.wt), false);
			// The re-run on an already-retired task is a success, not a gate
			// error: the target is already absent (I13).
			const retireReplay = await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			assert.equal(retireReplay.phase, "retired");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
			// A close re-run after the commit reports the same counts (I13).
			const replay = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(replay.closed, true);
			assert.deepEqual(replay.counts, closed.counts);
		} finally {
			rmrf(f.dir);
		}
	});

	it("merges two applied all-verdicts in sequence (fan-out core, N>1)", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const wt1 = path.join(dir, "wt-t1");
			const wt2 = path.join(dir, "wt-t2");
			await callTool(tools, "taskq_fork", { taskId: "t1", workdir: wt1, baseline: repo.baseline }, ctx);
			await callTool(tools, "taskq_fork", { taskId: "t2", workdir: wt2, baseline: repo.baseline }, ctx);
			async function terminal(taskId: string, wt: string, file: string): Promise<void> {
				writeFile(wt, file, `${file} v1\n`);
				commitAll(wt, `${taskId} seg`);
				const req = await callTool(tools, "taskq_worker_request", { taskId, message: "done", status: "done" }, { cwd: wt });
				await callTool(tools, "taskq_record", { taskId, requestPath: req.file }, ctx);
				await callTool(tools, "taskq_schedule", { entryId: `${taskId}#1` }, ctx);
				await callTool(tools, "taskq_trigger", { entryId: `${taskId}#1` }, ctx);
				await callTool(tools, "taskq_verify", { taskId, outcome: "passed", notes: "ok" }, ctx);
				await callTool(tools, "taskq_proposal", { taskId, description: "the segment" }, ctx);
			}
			await terminal("t1", wt1, "a.ts");
			await terminal("t2", wt2, "b.ts");
			// The first verdict lands uncommitted in the main tree; the
			// second merge must not refuse the dirty tree - only the paths
			// the second verdict touches are gated.
			const m1 = await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, ctx);
			assert.equal(m1.phase, "merged");
			assert.deepEqual(m1.applied, ["a.ts"]);
			const m2 = await callTool(tools, "taskq_merge", { taskId: "t2", verdict: { scope: "all" } }, ctx);
			assert.equal(m2.phase, "merged");
			assert.deepEqual(m2.applied, ["b.ts"]);
			// Both verdicts' content sits in the working tree, uncommitted,
			// exactly as each verdict brought it back.
			assert.equal(fs.readFileSync(path.join(repo.root, "a.ts"), "utf8"), "a.ts v1\n");
			assert.equal(fs.readFileSync(path.join(repo.root, "b.ts"), "utf8"), "b.ts v1\n");
			// The run closes cleanly after both retire.
			await callTool(tools, "taskq_retire", { taskId: "t1" }, ctx);
			await callTool(tools, "taskq_retire", { taskId: "t2" }, ctx);
			const closed = await callTool(tools, "taskq_close", {}, ctx);
			assert.equal(closed.closed, true);
			assert.deepEqual(closed.counts, { tasks: 2, entries: 2, triggered: 2, pending: 0, requests: 2 });
		} finally {
			rmrf(dir);
		}
	});

	it("recovers a merge interrupted between the apply and the record", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The crash window: the verdict's changes landed in the main tree,
			// the state still says verified.
			const task = Run.open(f.stateDir, f.root).current().tasks.t1;
			applyVerdict(f.root, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, verdict: { scope: "all" } });
			assert.equal(currentPhase(f), "verified");
			assert.equal(fs.existsSync(path.join(f.root, "a.ts")), true);
			// The retry records the merge: the idempotent apply recognizes the
			// already-applied verdict, and the run can still close.
			const merged = await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			assert.equal(merged.phase, "merged");
			assert.deepEqual(merged.applied, ["a.ts"]);
			await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("recovers a retire interrupted between the prune and the record", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			// The crash window: the worktree and the branch are gone, the
			// state still says merged.
			pruneWorktree(f.root, { branch: "exp/t1", path: f.wt, baseline: f.baseline });
			assert.equal(currentPhase(f), "merged");
			assert.equal(fs.existsSync(f.wt), false);
			// The retry completes the record instead of refusing the phase.
			const retired = await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			assert.equal(retired.phase, "retired");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("completes a retire recorded with the worktree still present (pre-repair states)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			// A state written by the record-first ordering: the retired phase
			// is recorded, the worktree and the branch still exist.
			Run.open(f.stateDir, f.root, AT).handle((s) => retireOp(s, "t1", AT));
			assert.equal(currentPhase(f), "retired");
			assert.equal(fs.existsSync(f.wt), true);
			// The retry completes the removal instead of refusing the phase.
			const retired = await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			assert.equal(retired.phase, "retired");
			assert.equal(fs.existsSync(f.wt), false);
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a failed prune leaves the run unchanged and a re-run completes", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			// The worker left a deliverable uncommitted: the prune refuses.
			writeFile(f.wt, "precious.txt", "uncommitted deliverable\n");
			await assert.rejects(
				callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx),
				(e) => errorCode(e) === "prune-failed",
			);
			// The failed call advanced nothing: the task is still merged and
			// the worktree still exists.
			assert.equal(currentPhase(f), "merged");
			assert.equal(fs.existsSync(f.wt), true);
			// Export the deliverable, then the re-run completes.
			fs.rmSync(path.join(f.wt, "precious.txt"));
			const retired = await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			assert.equal(retired.phase, "retired");
			assert.equal(fs.existsSync(f.wt), false);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a failed prune leaves no retire event in the journal (I12)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			// The worker left a deliverable uncommitted: the prune refuses.
			writeFile(f.wt, "precious.txt", "uncommitted deliverable\n");
			await assert.rejects(
				callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx),
				(e) => errorCode(e) === "prune-failed",
			);
			// The journal replays the run with no retire: the state says
			// merged, and the audit agrees (I12).
			const before = readJournal(f.stateDir).map((e) => e.type);
			assert.ok(!before.includes("retire"), `journal must hold no retire for the failed prune: ${before.join(", ")}`);
			assert.equal(currentPhase(f), "merged");
			// Clear the blocker; the successful retire then records its event.
			fs.rmSync(path.join(f.wt, "precious.txt"));
			await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			const after = readJournal(f.stateDir).map((e) => e.type);
			assert.equal(after.filter((t) => t === "retire").length, 1, "exactly one retire event after the successful prune");
		} finally {
			rmrf(f.dir);
		}
	});

	it("close refuses unregistered worktrees and branches (I10)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, f.ctx);
			await callTool(tools, "taskq_retire", { taskId: "t1" }, f.ctx);
			// A fork that crashed between cutting and registering left this
			// worktree and branch behind, after the run opened.
			const orphan = path.join(f.dir, "wt-orphan");
			git(["worktree", "add", "-q", "-b", "exp/orphan", orphan, f.baseline], { cwd: f.root });
			await assert.rejects(
				callTool(tools, "taskq_close", {}, f.ctx),
				(e) => errorCode(e) === "close-gate" && String((e as { message?: unknown }).message).includes("exp/orphan"),
			);
			// Remove the leftover, and the close completes.
			git(["worktree", "remove", "--force", orphan], { cwd: f.root });
			git(["branch", "-D", "exp/orphan"], { cwd: f.root });
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("close ignores worktrees and branches that predate the run", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const foreign = path.join(dir, "wt-foreign");
			git(["worktree", "add", "-q", "-b", "exp/foreign", foreign, repo.baseline], { cwd: repo.root });
			const wt = path.join(dir, "wt-t1");
			const ctx = { cwd: repo.root };
			await callTool(tools, "taskq_fork", { taskId: "t1", workdir: wt, baseline: repo.baseline }, ctx);
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg");
			const req = await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "done", status: "done" }, { cwd: wt });
			await callTool(tools, "taskq_record", { taskId: "t1", requestPath: req.file }, ctx);
			await callTool(tools, "taskq_schedule", { entryId: "t1#1" }, ctx);
			await callTool(tools, "taskq_trigger", { entryId: "t1#1" }, ctx);
			await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "passed", notes: "ok" }, ctx);
			await callTool(tools, "taskq_proposal", { taskId: "t1", description: "the segment" }, ctx);
			await callTool(tools, "taskq_merge", { taskId: "t1", verdict: { scope: "all" } }, ctx);
			await callTool(tools, "taskq_retire", { taskId: "t1" }, ctx);
			// The foreign worktree and branch predate the run and are the
			// repository's own; the close sweep ignores them.
			const closed = await callTool(tools, "taskq_close", {}, ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(dir);
		}
	});
});