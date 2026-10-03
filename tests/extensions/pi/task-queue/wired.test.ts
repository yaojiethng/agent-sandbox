/**
 * The wired tool surface: the extension's real tool executions against a
 * real repository, in the production default configuration (state
 * directory beside the repo root, not inside it) and the crash-window
 * recovery paths the pure layers cannot exercise. The extension loads
 * under jiti with pi's package aliases, exactly as the pi runtime loads
 * it. The driver loop runs through the join: fork, join, verify,
 * proposal, bring-back, close, with the re-queue routes between the
 * not-usable audit and the next segment.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";
import { Run } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
import { bringBackOp } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { applyBringBack } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { readJournal, bringBackIntentPathOf, readBringBackIntent, writeBringBackIntent } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { loadState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import { canonicalWorkdir, git, listBranches, listWorktrees, pruneWorktree, statusPorcelain, worktreeHead, worktreeRootOf } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { readWorkerState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/protocol.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, writeFile } from "./helpers.ts";

const EXTENSION_ENTRY = path.resolve(
	import.meta.dirname,
	"../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts",
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

/** A join bound: generous enough for a busy host, short enough for a suite. */
const JOIN_TIMEOUT_MS = 30_000;

interface Fixture {
	dir: string;
	root: string;
	baseline: string;
	wt: string;
	stateDir: string;
	ctx: ToolCtx;
}

/**
 * Fork one task, run one terminal worker segment through the join, and
 * build the write-back proposal. The run uses the production default state
 * directory: a sibling of the repo root, never inside the main tree. The
 * worktree path comes from the fork: the caller passes no path.
 */
async function setupRun(tools: Record<string, WiredTool>, files: Record<string, string> = { "a.ts": "v1\n" }): Promise<Fixture> {
	delete process.env.TASKQ_STATE_DIR;
	const dir = tmpdir();
	const repo = makeMainRepo(dir);
	const ctx = { cwd: repo.root };
	const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
	const wt = forked.workdir as string;
	// A root-level file: porcelain reports new files in new directories as
	// the directory, so the assertion stays exact on the applied set.
	for (const [name, content] of Object.entries(files)) writeFile(wt, name, content);
	commitAll(wt, "seg");
	await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "review the segment", status: "done" }, { cwd: wt });
	await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
	await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "ok" }, ctx);
	await callTool(tools, "taskq_proposal", { taskId: "t1", description: "the segment" }, ctx);
	return { dir, root: repo.root, baseline: repo.baseline, wt, stateDir: path.join(dir, `.taskq-${path.basename(repo.root)}`), ctx };
}

/**
 * The crash window the bring-back intent record exists for: the main-tree
 * write completed, the prune completed, and the state record did not. The
 * record is written the way the tool writes it, so the resumed path under
 * test is the one production runs.
 */
function interruptAfterPrune(f: Fixture, paths: string[]): void {
	const task = Run.open(f.stateDir, f.root).current().tasks.t1;
	applyBringBack(f.root, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths });
	writeBringBackIntent(f.stateDir, "t1", { paths: [...paths], at: AT, writtenAt: AT });
	pruneWorktree(f.root, { branch: task.branch, path: task.workdir, baseline: task.baseline });
	assert.equal(currentPhase(f), "terminated", "the interrupted attempt recorded nothing");
}

function currentPhase(f: Fixture): string {
	return Run.open(f.stateDir, f.root).current().tasks.t1.phase;
}

const suite = piAvailable() ? {} : { skip: "pi installation not present" };

/** Resolve true once a file exists, false if the child dies first. */
function waitForFile(file: string, child: ReturnType<typeof spawn>, ms = 20_000): Promise<boolean> {
	return new Promise<boolean>((resolve) => {
		const done = (ok: boolean): void => {
			clearTimeout(timer);
			clearInterval(poll);
			child.off("exit", gone);
			resolve(ok);
		};
		const gone = (): void => done(fs.existsSync(file));
		const timer = setTimeout(gone, ms);
		const poll = setInterval(() => {
			if (fs.existsSync(file)) done(true);
		}, 25);
		child.on("exit", gone);
	});
}

/** The outcome of one racer: one file per racer, read from the directory. */
interface RacerOutcome {
	pid: number;
	ok: boolean;
	code?: string;
	message?: string;
}

/** Resolve true once the child process has exited. */
function waitForExit(child: ReturnType<typeof spawn>): Promise<boolean> {
	return new Promise<boolean>((resolve) => {
		if (child.exitCode !== null) {
			resolve(true);
			return;
		}
		const timer = setTimeout(() => resolve(false), 60_000);
		child.on("exit", () => {
			clearTimeout(timer);
			resolve(true);
		});
	});
}

describe("wired tool surface", () => {
	it("cuts the canonical run-scoped worktree with no pre-creation (W1, W3)", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			// The tool owns the location: the path follows from the run and the
			// task, so the caller creates nothing and passes nothing.
			assert.equal(forked.workdir, canonicalWorkdir(repo.root, stateDir, "t1"));
			assert.equal(forked.worktreeRoot, worktreeRootOf(repo.root, stateDir));
			assert.ok(fs.existsSync(path.join(forked.workdir as string, ".git")));
			assert.ok(listBranches(repo.root).includes("exp/t1"));
			// The fork wrote the registry, never the main tree (I6).
			assert.equal(statusPorcelain(repo.root), "");
		} finally {
			rmrf(dir);
		}
	});

	it("fork refuses a pre-created worktree and names the canonical location (W2)", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			const workdir = canonicalWorkdir(repo.root, stateDir, "t1");
			// The ergonomic failure the fork owns away: the caller cut the
			// worktree by hand at the path the fork would have used.
			git(["worktree", "add", "-q", "-b", "exp/t1", workdir, repo.baseline], { cwd: repo.root });
			await assert.rejects(
				callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx),
				(e) => {
					if (errorCode(e) !== "worktree-occupied") return false;
					return String((e as { message?: unknown }).message).includes(workdir);
				},
			);
			// The refusal changed nothing: the state holds no task.
			const state = Run.open(stateDir, repo.root).current();
			assert.deepEqual(Object.keys(state.tasks), []);
		} finally {
			rmrf(dir);
		}
	});

	it("a join with nothing ready times out and consumes nothing (J3)", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const joined = await callTool(tools, "taskq_join", { timeoutMs: 300 }, ctx);
			// A timeout is a result, not an error: nothing became ready.
			assert.equal(joined.outcome, "timeout");
			assert.deepEqual(joined.waiting, ["t1"]);
			const status = await callTool(tools, "taskq_status", {}, ctx);
			assert.deepEqual(status.entries, []);
			assert.equal(status.hold, undefined);
			// The next join still delivers when the worker lands.
			const wt = canonicalWorkdir(repo.root, path.join(dir, `.taskq-${path.basename(repo.root)}`), "t1");
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "done", status: "done" }, { cwd: wt });
			const delivered = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			assert.equal(delivered.outcome, "joined");
			assert.equal(delivered.entryId, "t1#1");
		} finally {
			rmrf(dir);
		}
	});

	it("runs a full bring-back in the production default state-directory layout", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The state directory is a sibling of the repo root: the
			// bring-back's clean-main gate passes in the documented
			// configuration.
			assert.ok(fs.existsSync(path.join(f.stateDir, "state.json")));
			assert.ok(!fs.existsSync(path.join(f.root, ".taskq")));
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			// The bring-back writes and retires in one call: there is no
			// separate retirement step.
			assert.equal(back.phase, "retired");
			assert.deepEqual(back.broughtBack, ["a.ts"]);
			assert.deepEqual(back.applied, ["a.ts"]);
			assert.equal(back.archived, false);
			assert.equal(fs.readFileSync(path.join(f.root, "a.ts"), "utf8"), "v1\n");
			assert.equal(fs.existsSync(f.wt), false, "the worktree is pruned by the same call");
			assert.ok(!listBranches(f.root).includes("exp/t1"), "the branch is pruned by the same call");
			// The state directory never shows up in the main tree's porcelain.
			const status = statusPorcelain(f.root).split("\n").filter((l) => l !== "").map((l) => l.slice(3));
			assert.deepEqual(status, ["a.ts"]);
			// The re-run on an already-retired task is a success, not a gate
			// error: the target is already absent (I13).
			const replay = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(replay.phase, "retired");
			assert.equal(replay.resumed, true, "the re-run recognised the completed write");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
			// A close re-run after the commit reports the same counts (I13).
			const closedAgain = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closedAgain.closed, true);
			assert.deepEqual(closedAgain.counts, closed.counts);
		} finally {
			rmrf(f.dir);
		}
	});

	it("brings back two file sets in sequence (fan-out core, N>1)", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const f1 = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const f2 = await callTool(tools, "taskq_fork", { taskId: "t2", baseline: repo.baseline }, ctx);
			async function terminal(taskId: string, wt: string, file: string): Promise<void> {
				writeFile(wt, file, `${file} v1\n`);
				commitAll(wt, `${taskId} seg`);
				await callTool(tools, "taskq_worker_request", { taskId, message: "done", status: "done" }, { cwd: wt });
				const joined = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
				assert.equal(joined.outcome, "joined");
				assert.equal(joined.taskId, taskId, "the earliest-forked ready task is delivered first");
				await callTool(tools, "taskq_verify", { taskId, outcome: "usable", notes: "ok" }, ctx);
				await callTool(tools, "taskq_proposal", { taskId, description: "the segment" }, ctx);
			}
			await terminal("t1", f1.workdir as string, "a.ts");
			await terminal("t2", f2.workdir as string, "b.ts");
			// The first file set lands uncommitted in the main tree; the
			// second bring-back must not refuse the dirty tree - only the
			// paths the second file set touches are gated.
			const b1 = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, ctx);
			assert.equal(b1.phase, "retired");
			assert.deepEqual(b1.applied, ["a.ts"]);
			const b2 = await callTool(tools, "taskq_merge", { taskId: "t2", paths: ["b.ts"] }, ctx);
			assert.equal(b2.phase, "retired");
			assert.deepEqual(b2.applied, ["b.ts"]);
			// Both file sets' content sits in the working tree, uncommitted,
			// exactly as each bring-back wrote it.
			assert.equal(fs.readFileSync(path.join(repo.root, "a.ts"), "utf8"), "a.ts v1\n");
			assert.equal(fs.readFileSync(path.join(repo.root, "b.ts"), "utf8"), "b.ts v1\n");
			// The run closes cleanly after both bring-backs.
			const closed = await callTool(tools, "taskq_close", {}, ctx);
			assert.equal(closed.closed, true);
			assert.deepEqual(closed.counts, { tasks: 2, entries: 2, triggered: 2, pending: 0, requests: 2 });
		} finally {
			rmrf(dir);
		}
	});

	it("an empty file set writes nothing, archives the branch, and prunes", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: [] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.deepEqual(back.applied, [], "nothing was written into the main tree");
			assert.equal(back.archived, true, "the branch diff is archived in the run record");
			assert.equal(fs.existsSync(path.join(f.root, "a.ts")), false, "the main tree is untouched");
			assert.equal(statusPorcelain(f.root), "", "the main tree stays clean");
			// The archive keeps the segment reachable after the branch is gone.
			const archive = path.join(f.stateDir, "archive", "t1.diff");
			assert.ok(fs.existsSync(archive), "the branch diff is archived in the run record");
			assert.ok(fs.readFileSync(archive, "utf8").includes("a.ts"), "the archive carries the segment content");
			// The worktree and the branch are pruned like any other bring-back.
			assert.equal(fs.existsSync(f.wt), false);
			assert.ok(!listBranches(f.root).includes("exp/t1"));
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a bring-back path the proposal does not name", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await assert.rejects(
				callTool(tools, "taskq_merge", { taskId: "t1", paths: ["b.ts"] }, f.ctx),
				(e) => errorCode(e) === "file-set-invalid" && String((e as { message?: unknown }).message).includes("b.ts"),
			);
			// The refusal left the task terminated and the worktree in place.
			assert.equal(currentPhase(f), "terminated");
			assert.equal(fs.existsSync(f.wt), true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("recovers a bring-back interrupted between the write and the record", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The crash window: the file set's changes landed in the main
			// tree, the state still says terminated.
			const task = Run.open(f.stateDir, f.root).current().tasks.t1;
			applyBringBack(f.root, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: ["a.ts"] });
			assert.equal(currentPhase(f), "terminated");
			assert.equal(fs.existsSync(path.join(f.root, "a.ts")), true);
			// The retry records the bring-back: the idempotent apply
			// recognizes the already-written file set, and the run can still
			// close.
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.deepEqual(back.applied, ["a.ts"]);
			assert.equal(fs.readFileSync(path.join(f.root, "a.ts"), "utf8"), "v1\n");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("resumes a bring-back interrupted between the prune and the record", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The crash window: the main-tree write and the prune completed,
			// the state record did not. The intent record the tool wrote
			// before its write is the only evidence the retry accepts.
			interruptAfterPrune(f, ["a.ts"]);
			assert.equal(fs.existsSync(f.wt), false);
			// The retry completes the record instead of refusing the phase.
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.equal(back.resumed, true, "the intent record proves the interrupted attempt wrote the file set");
			// The record states what happened, not what this call did: the
			// file set was written by the interrupted attempt, and the journal
			// marks the record as inferred.
			assert.deepEqual(back.applied, ["a.ts"], "the resumed record names the file set the earlier attempt wrote");
			assert.equal(back.archived, false);
			// The evidence never outlives the record that replaced it.
			assert.equal(fs.existsSync(bringBackIntentPathOf(f.stateDir, "t1")), false, "the intent record is dropped with the record");
			const events = readJournal(f.stateDir).filter((e) => e.type === "bringback");
			assert.equal(events.length, 1);
			assert.equal((events[0] as { resumed?: boolean }).resumed, true, "the journal tells an inferred record from a performed one");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a bring-back whose worktree is gone with no record of a write (D1a)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The remediation the fork refusal prints, run by hand: the
			// worktree and the branch are gone, and no call of this run ever
			// reached a write. A gone worktree alone is not evidence.
			git(["worktree", "remove", "--force", f.wt], { cwd: f.root });
			git(["branch", "-D", "exp/t1"], { cwd: f.root });
			assert.equal(fs.existsSync(f.wt), false);
			await assert.rejects(
				callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx),
				(e) =>
					errorCode(e) === "bring-back-unprovable" &&
					String((e as { message?: unknown }).message).includes("terminated") &&
					String((e as { message?: unknown }).message).includes(bringBackIntentPathOf(f.stateDir, "t1")),
			);
			// The refusal records nothing and writes nothing (I7).
			assert.equal(currentPhase(f), "terminated", "the task is not retired on an unprovable bring-back");
			assert.equal(fs.existsSync(path.join(f.root, "a.ts")), false, "the file set was never written");
			assert.equal(readBringBackIntent(f.stateDir, "t1"), undefined, "the refused call left no intent record");
			assert.ok(
				!readJournal(f.stateDir).some((e) => e.type === "bringback"),
				"the journal holds no retirement for a write it cannot prove",
			);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a resumed bring-back that names another file set (D1b)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools, { "a.ts": "v1\n", "b.ts": "v1\n" });
		try {
			// The interrupted attempt wrote a.ts; b.ts is in the proposal, so
			// the resumed call can legally name it and must still be refused.
			interruptAfterPrune(f, ["a.ts"]);
			await assert.rejects(
				callTool(tools, "taskq_merge", { taskId: "t1", paths: ["b.ts"] }, f.ctx),
				(e) => errorCode(e) === "bring-back-unprovable" && String((e as { message?: unknown }).message).includes("b.ts"),
			);
			assert.equal(currentPhase(f), "terminated", "a mismatched file set records nothing");
			assert.equal(fs.existsSync(path.join(f.root, "b.ts")), false, "the named file set was not written on the way past");
			// The recorded file set still resumes: the refusal is about the
			// evidence, not about the task.
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.equal(back.resumed, true);
			assert.equal(fs.readFileSync(path.join(f.root, "a.ts"), "utf8"), "v1\n");
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses an empty file set whose archive the interrupted attempt never wrote (D1c)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The evidence claims an archive that the run record does not
			// hold: `archived` is the empty file set's whole deliverable, so
			// the claim rests on the archived diff and not on the intent.
			writeBringBackIntent(f.stateDir, "t1", { paths: [], at: AT, writtenAt: AT });
			pruneWorktree(f.root, { branch: "exp/t1", path: f.wt, baseline: f.baseline });
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: [] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.equal(back.archived, false, "an absent archive is not claimed as written");
			assert.equal(fs.existsSync(path.join(f.stateDir, "archive", "t1.diff")), false, "no branch diff exists for this run");
		} finally {
			rmrf(f.dir);
		}
	});

	it("completes a bring-back recorded with the worktree still present (pre-repair states)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// A state written by the record-first ordering: the retired phase
			// is recorded, the worktree and the branch still exist.
			Run.open(f.stateDir, f.root, AT).handle((s) =>
				bringBackOp(s, { taskId: "t1", paths: ["a.ts"], applied: ["a.ts"], archived: false, removedWorktree: f.wt, prunedBranch: "exp/t1", resumed: false }, AT),
			);
			assert.equal(currentPhase(f), "retired");
			assert.equal(fs.existsSync(f.wt), true);
			// The retry completes the removal instead of refusing the phase.
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.equal(back.resumed, false, "this call performed the write path, it did not infer one");
			assert.equal(fs.existsSync(f.wt), false);
			assert.ok(!listBranches(f.root).includes("exp/t1"));
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
			// The worker left a deliverable uncommitted: the prune refuses.
			writeFile(f.wt, "precious.txt", "uncommitted deliverable\n");
			// The refusal is asked before anything is written, so the main
			// tree is exactly as it was when the call arrived (I7, I12).
			const before = statusPorcelain(f.root);
			await assert.rejects(callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx), (e) => errorCode(e) === "prune-failed");
			assert.equal(statusPorcelain(f.root), before, "a refused bring-back leaves the main tree untouched");
			assert.equal(fs.existsSync(path.join(f.root, "a.ts")), false, "the file set was never written");
			// The failed call advanced nothing: the task is still terminated
			// and the worktree still exists.
			assert.equal(currentPhase(f), "terminated");
			assert.equal(fs.existsSync(f.wt), true);
			// Export the deliverable, then the re-run completes.
			fs.rmSync(path.join(f.wt, "precious.txt"));
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			assert.equal(back.phase, "retired");
			assert.equal(fs.existsSync(f.wt), false);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a refused empty file set archives nothing and leaves the main tree untouched", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// The empty file set writes nothing, so the tree is unchanged
			// either way - but the archive would have landed in the run record
			// before the refusal, and the record is the operator's evidence
			// that nothing came back.
			writeFile(f.wt, "precious.txt", "uncommitted deliverable\n");
			const before = statusPorcelain(f.root);
			await assert.rejects(callTool(tools, "taskq_merge", { taskId: "t1", paths: [] }, f.ctx), (e) => errorCode(e) === "prune-failed");
			assert.equal(statusPorcelain(f.root), before);
			assert.equal(fs.existsSync(path.join(f.stateDir, "archive", "t1.diff")), false, "the refused call archived no branch diff");
			assert.deepEqual(readJournal(f.stateDir).map((e) => e.type), ["run:open", "task:fork", "request:record", "entry:schedule", "entry:trigger", "verify", "proposal"]);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a failed prune leaves no bring-back event in the journal (I12)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			writeFile(f.wt, "precious.txt", "uncommitted deliverable\n");
			await assert.rejects(callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx), (e) => errorCode(e) === "prune-failed");
			// The journal replays the run with no bring-back: the state says
			// terminated, and the audit agrees (I12).
			const before = readJournal(f.stateDir).map((e) => e.type);
			assert.ok(!before.includes("bringback"), `journal must hold no bring-back for the failed prune: ${before.join(", ")}`);
			assert.equal(currentPhase(f), "terminated");
			// Clear the blocker; the successful call then records its event.
			fs.rmSync(path.join(f.wt, "precious.txt"));
			await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			const after = readJournal(f.stateDir).map((e) => e.type);
			assert.equal(after.filter((t) => t === "bringback").length, 1, "exactly one bring-back event after the successful prune");
		} finally {
			rmrf(f.dir);
		}
	});

	it("a not-usable audit keeps the task in the queue and the re-queue in place rolls it back", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const wt = forked.workdir as string;
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg 1");
			const head1 = worktreeHead(wt);
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "first segment", status: "done" }, { cwd: wt });
			await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			// The audit finds the segment unusable: the task stays in the
			// queue, and the phase does not move to terminated.
			const audited = await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "not-usable", notes: "the segment does not hold" }, ctx);
			assert.equal(audited.outcome, "not-usable");
			assert.equal(audited.phase, "active", "a not-usable audit leaves the task in the queue");
			// The worker wrecked the worktree after the break point.
			writeFile(wt, "a.ts", "wrecked\n");
			commitAll(wt, "seg 2");
			writeFile(wt, "untracked.txt", "left behind\n");
			// The in-place route rolls the worktree back to the head the
			// delivered segment reached, in the same worktree and branch.
			const requeued = await callTool(tools, "taskq_requeue", { taskId: "t1", route: "in-place" }, ctx);
			assert.equal(requeued.route, "in-place");
			assert.equal(requeued.phase, "active", "the in-place route stays in the queue");
			assert.equal(requeued.workdir, wt, "the same worktree");
			assert.equal(requeued.branch, "exp/t1", "the same branch");
			assert.equal(worktreeHead(wt), head1, "the worktree is back at the last delivered segment");
			assert.equal(fs.existsSync(path.join(wt, "untracked.txt")), false, "the segment wreckage is gone");
			// The queue entries survive the re-queue: the next segment is a
			// new entry, not a new run.
			const status = await callTool(tools, "taskq_status", {}, ctx);
			assert.deepEqual(status.entries, [{ entryId: "t1#1", taskId: "t1", state: "triggered" }]);
			// The same worker's request sequence continues: the next request
			// is the second one, not the first again.
			const req = await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "second segment", status: "done" }, { cwd: wt });
			assert.equal(req.requestId, "t1-2");
			const joined = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			assert.equal(joined.entryId, "t1#2", "the second segment is the second entry");
			assert.equal(Run.open(stateDir, repo.root).current().tasks.t1.phase, "active");
		} finally {
			rmrf(dir);
		}
	});

	it("the fresh re-queue route cuts a new worktree from the baseline", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const wt = forked.workdir as string;
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg 1");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "first segment", status: "done" }, { cwd: wt });
			await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "not-usable", notes: "the worktree is poisoned" }, ctx);
			// Poison the worktree the way a broken environment does: tracked
			// damage, untracked files, a state file the worker edited by
			// hand. A rollback would carry all of it forward.
			writeFile(wt, "a.ts", "poisoned\n");
			commitAll(wt, "seg 2");
			writeFile(wt, "junk.txt", "junk\n");
			// The fresh route removes the worktree and the branch, cuts a
			// new one from the baseline, and reseeds the request sequence.
			const requeued = await callTool(tools, "taskq_requeue", { taskId: "t1", route: "fresh" }, ctx);
			assert.equal(requeued.route, "fresh");
			assert.equal(requeued.phase, "forked", "the fresh route returns the task to the fork phase");
			assert.equal(requeued.workdir, wt, "the canonical path is reused");
			assert.equal(requeued.branch, "exp/t1", "the canonical branch is reused");
			assert.equal(requeued.head, repo.baseline, "the new worktree starts at the baseline");
			assert.ok(fs.existsSync(path.join(wt, ".git")), "a new worktree is cut");
			assert.equal(fs.existsSync(path.join(wt, "a.ts")), false, "the segment content is gone");
			assert.equal(fs.existsSync(path.join(wt, "junk.txt")), false);
			assert.ok(listBranches(repo.root).includes("exp/t1"), "the branch exists again");
			// The worker's request counter is seeded past the queue's
			// previous entry, so the next request is not one the run already
			// recorded.
			assert.equal(readWorkerState(wt)?.seq, 1);
			assert.equal(requeued.nextRequestSeq, 2);
			// The queue entries survive the re-queue.
			const status = await callTool(tools, "taskq_status", {}, ctx);
			assert.deepEqual(status.entries, [{ entryId: "t1#1", taskId: "t1", state: "triggered" }]);
			// The main tree is untouched by either route (I6).
			assert.equal(statusPorcelain(repo.root), "");
		} finally {
			rmrf(dir);
		}
	});

	it("the re-queue refuses a task that is not active", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			// A usable audit terminated the task: there is nothing to
			// re-queue, and the bring-back is the next step.
			await assert.rejects(callTool(tools, "taskq_requeue", { taskId: "t1", route: "in-place" }, f.ctx), (e) => errorCode(e) === "requeue-gate");
			await assert.rejects(callTool(tools, "taskq_requeue", { taskId: "nope", route: "fresh" }, f.ctx), (e) => errorCode(e) === "task-unknown");
		} finally {
			rmrf(f.dir);
		}
	});

	it("refuses a mid-segment audit, and the re-queued segment ends the run", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const wt = forked.workdir as string;
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg 1");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "first segment", status: "done" }, { cwd: wt });
			await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "not-usable", notes: "the segment does not hold" }, ctx);
			await callTool(tools, "taskq_requeue", { taskId: "t1", route: "in-place" }, ctx);
			// Between segments the worker is running again, so there is no
			// terminal break point to audit.
			await assert.rejects(
				callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "premature" }, ctx),
				(e) => errorCode(e) === "verify-gate" && String((e as { message?: unknown }).message).includes("terminal break point"),
			);
			// The second segment terminates the task, and the bring-back
			// writes what the second segment produced.
			writeFile(wt, "a.ts", "v2\n");
			commitAll(wt, "seg 2");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "second segment", status: "done" }, { cwd: wt });
			const joined = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			assert.equal(joined.entryId, "t1#2");
			const audited = await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "ok now" }, ctx);
			assert.equal(audited.phase, "terminated");
			await callTool(tools, "taskq_proposal", { taskId: "t1", description: "the second segment" }, ctx);
			const back = await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, ctx);
			assert.equal(back.phase, "retired");
			assert.equal(fs.readFileSync(path.join(repo.root, "a.ts"), "utf8"), "v2\n");
			const closed = await callTool(tools, "taskq_close", {}, ctx);
			assert.equal(closed.closed, true);
			assert.deepEqual(closed.counts, { tasks: 1, entries: 2, triggered: 2, pending: 0, requests: 2 });
		} finally {
			rmrf(dir);
		}
	});

	it("close refuses unregistered worktrees and branches (I10)", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
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

	it("the close sweep runs under the state directory's lock", suite, async () => {
		const tools = await loadTools();
		const f = await setupRun(tools);
		let holder: ReturnType<typeof spawn> | undefined;
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
			// The leftover a crashed fork would leave: the sweep's subject.
			const orphan = path.join(f.dir, "wt-orphan");
			git(["worktree", "add", "-q", "-b", "exp/orphan", orphan, f.baseline], { cwd: f.root });
			// A live writer owns the state directory. The sweep, the leftover
			// check, and the close record are one locked derive, so the call
			// reports the owner instead of sweeping outside the lock and
			// racing a cut that lands between the sweep and the record.
			const ready = path.join(f.dir, "held");
			holder = spawn(process.execPath, [path.join(import.meta.dirname, "fixtures", "lock-holder.ts"), f.stateDir, ready, "idle"], {
				stdio: ["ignore", "pipe", "pipe"],
			});
			assert.equal(await waitForFile(ready, holder), true, "the other writer took the lock");
			await assert.rejects(callTool(tools, "taskq_close", {}, f.ctx), (e) => errorCode(e) === "lock-held");
			// The owner is gone, so the same call now answers with the sweep.
			holder.kill("SIGKILL");
			assert.equal(await waitForExit(holder), true, "the lock holder is gone");
			await assert.rejects(
				callTool(tools, "taskq_close", {}, f.ctx),
				(e) => errorCode(e) === "close-gate" && String((e as { message?: unknown }).message).includes("exp/orphan"),
			);
			const status = await callTool(tools, "taskq_status", {}, f.ctx);
			assert.equal(status.closed, false, "the refused close recorded nothing");
			git(["worktree", "remove", "--force", orphan], { cwd: f.root });
			git(["branch", "-D", "exp/orphan"], { cwd: f.root });
			const closed = await callTool(tools, "taskq_close", {}, f.ctx);
			assert.equal(closed.closed, true);
		} finally {
			holder?.kill("SIGKILL");
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
			const ctx = { cwd: repo.root };
			const forked = await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx);
			const wt = forked.workdir as string;
			writeFile(wt, "a.ts", "v1\n");
			commitAll(wt, "seg");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "done", status: "done" }, { cwd: wt });
			await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, ctx);
			await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "ok" }, ctx);
			await callTool(tools, "taskq_proposal", { taskId: "t1", description: "the segment" }, ctx);
			await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, ctx);
			// The foreign worktree and branch predate the run and are the
			// repository's own; the close sweep ignores them.
			const closed = await callTool(tools, "taskq_close", {}, ctx);
			assert.equal(closed.closed, true);
		} finally {
			rmrf(dir);
		}
	});

	it("the fork's cut does not run while another process owns the state directory", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		let holder: ReturnType<typeof spawn> | undefined;
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			Run.open(stateDir, repo.root, AT);
			// A live writer owns the directory. The fork's collision check,
			// its cut, and its registration are one locked transaction, so
			// the call is refused whole: no worktree, no branch.
			const ready = path.join(dir, "held");
			holder = spawn(process.execPath, [path.join(import.meta.dirname, "fixtures", "lock-holder.ts"), stateDir, ready, "idle"], {
				stdio: ["ignore", "pipe", "pipe"],
			});
			assert.equal(await waitForFile(ready, holder), true, "the other writer took the lock");
			await assert.rejects(callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx), (e) => errorCode(e) === "lock-held");
			assert.deepEqual(listWorktrees(repo.root).map((p) => path.resolve(p)), [path.resolve(repo.root)], "no worktree was cut");
			assert.deepEqual(listBranches(repo.root), ["main"], "no branch was cut");
			// The state is read without the lock: the directory is still owned
			// by the other writer, and the assertion only looks.
			assert.deepEqual(Object.keys(loadState(stateDir)?.tasks ?? {}), [], "no task was registered");
		} finally {
			holder?.kill("SIGKILL");
			rmrf(dir);
		}
	});

	it("two forks of one task id on one state directory cut one worktree", suite, async () => {
		const dir = tmpdir();
		const racers: ReturnType<typeof spawn>[] = [];
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const out = path.join(dir, "race");
			fs.mkdirSync(out);
			for (let i = 0; i < 2; i++) {
				racers.push(
					spawn(process.execPath, [path.join(import.meta.dirname, "fixtures", "fork-racer.ts"), repo.root, "t1", out], {
						stdio: ["ignore", "ignore", "pipe"],
					}),
				);
			}
			const exited = await Promise.all(racers.map((c) => waitForExit(c)));
			assert.ok(exited.every(Boolean), "both racers finished");
			// One outcome file per racer, so two racers reporting at once
			// cannot lose one outcome to a shared read-modify-write.
			const outcomes = fs
				.readdirSync(out)
				.filter((n) => n.startsWith("result."))
				.map((n) => JSON.parse(fs.readFileSync(path.join(out, n), "utf8")) as RacerOutcome);
			assert.equal(outcomes.length, 2, `both racers reported: ${JSON.stringify(outcomes)}`);
			// One fork wins; the other is refused by the state directory, and
			// the refusal names the collision rather than racing the cut.
			assert.equal(outcomes.filter((o) => o.ok).length, 1, `exactly one fork succeeds: ${JSON.stringify(outcomes)}`);
			const loser = outcomes.find((o) => !o.ok)!;
			assert.ok(loser.code === "worktree-occupied" || loser.code === "lock-held" || loser.code === "task-duplicate", `the loser is refused: ${JSON.stringify(loser)}`);
			// The run holds one task, and git holds one worktree and one
			// branch: the loser's call left nothing behind.
			const state = Run.open(path.join(dir, `.taskq-${path.basename(repo.root)}`), repo.root).current();
			assert.deepEqual(Object.keys(state.tasks), ["t1"]);
			assert.deepEqual(listWorktrees(repo.root).map((p) => path.resolve(p)).filter((p) => p !== path.resolve(repo.root)), [
				path.resolve(state.tasks.t1.workdir),
			]);
			assert.deepEqual(listBranches(repo.root).sort(), ["exp/t1", "main"]);
			assert.equal(statusPorcelain(repo.root), "", "the main tree is untouched (I6)");
		} finally {
			for (const racer of racers) racer.kill("SIGKILL");
			rmrf(dir);
		}
	});
});
