/**
 * The invariant report: one named case per invariant, over the real tool
 * surface, plus the index the renderer prints.
 *
 * The conformance suite holds each invariant with a deep test. This file is
 * the layer that answers the question a red suite asks: which invariant, and
 * therefore which review-finding class, is the finding about. Each case is
 * named for its invariant and reads its expectation from the transition
 * table or from a `taskq_status` snapshot rather than from a list written
 * here, and the renderer prints the whole index with a verdict per
 * invariant.
 *
 * The lifecycle cases are derived from `transitions.ts`, never listed: a
 * phase the table names is a phase this report asserts, and one it does not
 * name is one this report is silent about. The J4 case speaks of one held
 * join-unit, a single join or one pool batch, because that is the unit the
 * hold covers whatever a join delivers.
 *
 * There is no test framework here beyond `node:test` and no feature file:
 * the naming and the index are the whole mechanism.
 */

import { after, describe, it } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
import * as fs from "node:fs";
import * as path from "node:path";
import { ENTRY_TRANSITIONS, TASK_PHASES, TASK_TRANSITIONS, type TaskPhase } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/transitions.ts";
import { bringBackOp, closeOp, forkOp, proposalOp, recordOp, scheduleOp, triggerOp, verifyOp } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/ops.ts";
import { freshState, loadState, saveState, statePathOf, type RunState } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/state.ts";
import { entryIdOf, transitionTrigger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/queue.ts";
import { acquireLock, lockPathOf, ownerOf, readLockOwner, releaseLock, type LockOwner } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/lock.ts";
import { bringBackIntentPathOf, readBringBackIntent } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/record.ts";
import { statusPorcelain, worktreeRootOf } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { TOOL_SURFACE, buildCatalog, renderReport, stepInto, tableActions, triggeredStates, type CaseResult } from "./invariants.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, writeFile } from "./helpers.ts";

const EXTENSION_ENTRY = path.resolve(import.meta.dirname, "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts");
const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;

/** A join bound: generous enough for a busy host, short enough for a suite. */
const JOIN_TIMEOUT_MS = 30_000;
/** A timeout with nothing ready: short, because it is the wait under test. */
const SHORT_TIMEOUT_MS = 300;

interface WiredTool {
	name: string;
	description: string;
	parameters?: { properties?: Record<string, unknown> };
	execute: (...args: unknown[]) => Promise<{ details?: unknown; content?: unknown }>;
}

interface ToolCtx {
	cwd: string;
}

const suite = fs.existsSync(PI_PACKAGE_ENTRY) ? {} : { skip: "pi installation not present" };

/** The tools, loaded once: the report is an index, not a loader benchmark. */
let toolsPromise: Promise<Record<string, WiredTool>> | undefined;
function loadTools(): Promise<Record<string, WiredTool>> {
	toolsPromise ??= (async () => {
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
	})();
	return toolsPromise;
}

/** The tools this report drove, for the written-loop closure case. */
const driven = new Set<string>();

async function callTool(tools: Record<string, WiredTool>, name: string, params: object, ctx: ToolCtx): Promise<Record<string, unknown>> {
	const tool = tools[name];
	assert.ok(tool, `tool ${name} is registered`);
	driven.add(name);
	const result = await tool.execute("invariant-1", params, undefined, undefined, { cwd: ctx.cwd, mode: "print", hasUI: false, ui: {} });
	assert.ok(result && typeof result === "object" && "details" in result, `${name} returned details`);
	return result.details as Record<string, unknown>;
}

async function statusOf(tools: Record<string, WiredTool>, ctx: ToolCtx): Promise<Record<string, unknown>> {
	return callTool(tools, "taskq_status", {}, ctx);
}

/** The error code of a tool failure, matched across the jiti module graphs. */
function errorCode(e: unknown): string | undefined {
	if (typeof e !== "object" || e === null) return undefined;
	const code = (e as { code?: unknown }).code;
	return typeof code === "string" ? code : undefined;
}

/** The message of a tool failure, for the cases that assert on its wording. */
function errorMessage(e: unknown): string {
	return e instanceof Error ? e.message : String(e);
}

interface Fixture {
	dir: string;
	root: string;
	baseline: string;
	ctx: ToolCtx;
	stateDir: string;
	worktreeRoot: string;
}

/** A main repository and the run's own default state directory beside it. */
function freshRun(): Fixture {
	delete process.env.TASKQ_STATE_DIR;
	const dir = tmpdir();
	const repo = makeMainRepo(dir);
	const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
	return { dir, root: repo.root, baseline: repo.baseline, ctx: { cwd: repo.root }, stateDir, worktreeRoot: worktreeRootOf(repo.root, stateDir) };
}

/** One worker segment: write the files, commit them, request a break point. */
async function segment(tools: Record<string, WiredTool>, workdir: string, taskId: string, status: "running" | "done", files: Record<string, string>): Promise<void> {
	for (const [name, content] of Object.entries(files)) writeFile(workdir, name, content);
	commitAll(workdir, `segment ${status}`);
	await callTool(tools, "taskq_worker_request", { taskId, message: `${status} segment`, status }, { cwd: workdir });
}

// --- the scenarios the cases read from ------------------------------------
// Each scenario is built once, on first use, and torn down at the end of the
// file. A case reads snapshots out of a scenario; it does not drive the
// tools itself, so a case that fails names its invariant rather than a step
// of the walk that reached it.

const teardown: (() => Promise<void>)[] = [];
function keep<T extends { dir: string }>(build: () => Promise<T>): Promise<T> {
	const made = build();
	teardown.push(async () => rmrf((await made).dir));
	return made;
}

interface Snapshot {
	/** The registered tool whose call the snapshot follows. */
	after: string;
	status: Record<string, unknown>;
}

interface Lifecycle extends Fixture {
	workdir: string;
	/** The cut left a git worktree at the derived path, and the main tree clean. */
	gitFileAtFork: boolean;
	porcelainAfterFork: string;
	snapshots: Snapshot[];
	/** The join that reported the undecided break point, and the hold it read. */
	held: { result: Record<string, unknown>; status: Record<string, unknown> };
	entryIds: string[];
}

/** The whole written loop: three segments, the hold between them, then the bring-back. */
const lifecycle = (): Promise<Lifecycle> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		const snapshots: Snapshot[] = [];
		const workdir = (await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx)).workdir as string;
		const gitFileAtFork = fs.existsSync(path.join(workdir, ".git"));
		const porcelainAfterFork = statusPorcelain(f.root);
		snapshots.push({ after: "taskq_fork", status: await statusOf(tools, f.ctx) });
		// Two regular break points, then the terminal one. The middle
		// delivery is the hold: the next join reports it undecided.
		await segment(tools, workdir, "t1", "running", { "a.ts": "one\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		await segment(tools, workdir, "t1", "running", { "b.ts": "two\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		const heldResult = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		const heldStatus = await statusOf(tools, f.ctx);
		await segment(tools, workdir, "t1", "done", { "c.ts": "three\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		snapshots.push({ after: "taskq_join", status: await statusOf(tools, f.ctx) });
		await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "the report landed" }, f.ctx);
		snapshots.push({ after: "taskq_verify", status: await statusOf(tools, f.ctx) });
		await callTool(tools, "taskq_proposal", { taskId: "t1", description: "three files" }, f.ctx);
		snapshots.push({ after: "taskq_proposal", status: await statusOf(tools, f.ctx) });
		await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts", "c.ts"] }, f.ctx);
		snapshots.push({ after: "taskq_merge", status: await statusOf(tools, f.ctx) });
		await callTool(tools, "taskq_close", {}, f.ctx);
		return {
			...f,
			workdir,
			gitFileAtFork,
			porcelainAfterFork,
			snapshots,
			held: { result: heldResult, status: heldStatus },
			entryIds: (snapshots[1].status.entries as { entryId: string }[]).map((e) => e.entryId),
		};
	});

/** A run with one task and no request yet: a join here can only time out. */
const timedOut = (): Promise<Fixture & { before: Record<string, unknown>; result: Record<string, unknown>; after: Record<string, unknown> }> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx);
		const before = await statusOf(tools, f.ctx);
		const result = await callTool(tools, "taskq_join", { timeoutMs: SHORT_TIMEOUT_MS }, f.ctx);
		return { ...f, before, result, after: await statusOf(tools, f.ctx) };
	});

/** A bring-back stopped at the prune gate by an uncommitted deliverable. */
const refusedBringBack = (): Promise<Fixture & { code: string | undefined; porcelain: string; state: RunState }> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		const workdir = (await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx)).workdir as string;
		await segment(tools, workdir, "t1", "done", { "a.ts": "v1\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "ok" }, f.ctx);
		await callTool(tools, "taskq_proposal", { taskId: "t1", description: "one file" }, f.ctx);
		writeFile(workdir, "precious.txt", "an uncommitted deliverable\n");
		const porcelain = statusPorcelain(f.root);
		let code: string | undefined;
		try {
			await callTool(tools, "taskq_merge", { taskId: "t1", paths: ["a.ts"] }, f.ctx);
		} catch (e) {
			code = errorCode(e);
		}
		return { ...f, code, porcelain, state: loadState(f.stateDir)! };
	});

/** A not-usable audit answered by the in-place re-queue, then a new segment. */
const requeued = (): Promise<Fixture & { workdir: string; notUsable: { phase: string; outcome: string | undefined } }> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		const workdir = (await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx)).workdir as string;
		await segment(tools, workdir, "t1", "done", { "a.ts": "v1\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "not-usable", notes: "the report is missing" }, f.ctx);
		const audited = loadState(f.stateDir)!.tasks.t1;
		const notUsable = { phase: audited.phase, outcome: audited.verification?.outcome };
		await callTool(tools, "taskq_requeue", { taskId: "t1", route: "in-place" }, f.ctx);
		await segment(tools, workdir, "t1", "done", { "a.ts": "v2\n" });
		await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx);
		await callTool(tools, "taskq_verify", { taskId: "t1", outcome: "usable", notes: "the report landed" }, f.ctx);
		return { ...f, workdir, notUsable };
	});

/** A leftover directory at the canonical worktree path of the next task. */
const leftover = (): Promise<Fixture> =>
	keep(async () => {
		const f = freshRun();
		fs.mkdirSync(path.join(f.worktreeRoot, "t1"), { recursive: true });
		return f;
	});

/** Two joins on one worker request, started together. */
const raced = (): Promise<Fixture & { results: (Record<string, unknown> | string)[]; counts: unknown }> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		const workdir = (await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx)).workdir as string;
		await segment(tools, workdir, "t1", "done", { "a.ts": "v1\n" });
		const join = (): Promise<Record<string, unknown> | string> =>
			callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS }, f.ctx).catch((e: unknown) => errorCode(e) ?? "error");
		const results = await Promise.all([join(), join()]);
		return { ...f, results, counts: (await statusOf(tools, f.ctx)).counts };
	});

/** A state directory a live writer holds, read by a second writer. */
const locked = (): Promise<Fixture & { message: string; holder: LockOwner | undefined }> =>
	keep(async () => {
		const tools = await loadTools();
		const f = freshRun();
		await callTool(tools, "taskq_fork", { taskId: "t0" }, f.ctx);
		const owner = ownerOf({ sessionId: "the-other-primary", taskId: "t9" });
		acquireLock(f.stateDir, owner);
		let message = "";
		let holder: LockOwner | undefined;
		try {
			await callTool(tools, "taskq_fork", { taskId: "t1" }, f.ctx);
		} catch (e) {
			message = errorMessage(e);
		} finally {
			holder = readLockOwner(f.stateDir);
			releaseLock(f.stateDir, owner);
		}
		return { ...f, message, holder };
	});

/** The scenario memo, so a case that needs one builds it once. */
const memo = new Map<string, Promise<unknown>>();
function once<T>(key: string, build: () => Promise<T>): Promise<T> {
	if (!memo.has(key)) memo.set(key, build());
	return memo.get(key) as Promise<T>;
}

// --- the report ------------------------------------------------------------

const results: CaseResult[] = [];
const catalog = buildCatalog();

/** Run one case, name it for its invariant, and keep the verdict for the index. */
async function check(id: string, name: string, body: () => Promise<void> | void): Promise<void> {
	const entry = catalog.find((c) => c.id === id && c.name === name);
	assert.ok(entry, `the catalog carries a case for ${id} ${name}`);
	try {
		await body();
		results.push({ ...entry, outcome: "pass" });
	} catch (e) {
		results.push({ ...entry, outcome: "fail", detail: errorMessage(e).split("\n")[0] });
		throw e;
	}
}

/** The phases a status snapshot reports, as plain strings. */
function phasesOf(snap: Record<string, unknown>): string[] {
	return (snap.tasks as { phase: string }[]).map((t) => t.phase);
}

/** The one task a single-task snapshot reports. */
function taskOf(snap: Record<string, unknown>): Record<string, unknown> {
	return (snap.tasks as Record<string, unknown>[])[0];
}

/** The snapshot the walk reads a phase after, named by the table's own row. */
function snapshotAfter(run: Lifecycle, phase: TaskPhase): Snapshot {
	const snap = run.snapshots.find((s) => s.after === stepInto(phase));
	assert.ok(snap, `the walk takes a snapshot after ${stepInto(phase)}, the step the table reaches ${phase} from`);
	return snap!;
}

describe("invariant report", () => {
	after(async () => {
		process.stdout.write(`\n${renderReport(results)}\n`);
		for (const fn of teardown.reverse()) await fn();
	});

	// --- the queue identities ---------------------------------------------

	it("INV I1 -- every recorded request produced exactly one entry, and every entry triggered exactly once", suite, async () => {
		await check("I1", "exactly-once identities", async () => {
			const run = await once("lifecycle", lifecycle);
			const snap = snapshotAfter(run, "active");
			const counts = snap.status.counts as { entries: number; requests: number; triggered: number; pending: number };
			assert.equal(counts.entries, run.entryIds.length, "the queue holds one entry per delivered break point");
			assert.equal(counts.requests, counts.entries, "every recorded request produced exactly one entry");
			assert.equal(counts.triggered, counts.entries, "every entry triggered exactly once");
			assert.equal(counts.pending, 0, "no entry is left pending");
			// The close audit is the same identity, and it refuses a run that
			// does not hold it. Nothing drives a run into that shape, which is
			// the point: the audit is the check for it.
			const { state } = withPendingEntry();
			assert.throws(() => closeOp(state, "2026-01-01T00:00:00.000Z"), /pending/, "the close audit refuses a run with a pending entry");
		});
	});

	it("INV I5 -- a triggered entry has no outgoing edge, and a second trigger of it is refused", suite, async () => {
		await check("I5", "single trigger", async () => {
			assert.deepEqual(triggeredStates(), [], "the entry table carries no row out of triggered");
			const run = await once("lifecycle", lifecycle);
			const state = loadState(run.stateDir)!;
			const triggered = state.entries.find((e) => e.state === "triggered")!;
			assert.throws(() => transitionTrigger(state.entries, triggered.entryId), /already triggered/, `entry ${triggered.entryId} triggers at most once`);
		});
	});

	it("INV I7 -- the bring-back writes exactly the file set the primary names, and leaves its own intent record behind when it stops", suite, async () => {
		await check("I7", "file-set bring-back", async () => {
			const run = await once("lifecycle", lifecycle);
			const bringBack = taskOf(snapshotAfter(run, "retired").status).bringBack as { paths: string[] };
			assert.deepEqual(bringBack.paths, ["a.ts", "c.ts"], "the record names the file set the primary named, and no other path");
			// The evidence covers only the window it has to cover: the record
			// is durable, so the intent it replaced is gone.
			assert.equal(fs.existsSync(bringBackIntentPathOf(run.stateDir, "t1")), false, "the intent never outlives the record that replaced it");
			// A bring-back that stops at the prune gate leaves the run's own
			// evidence behind, because the write it names is what a resume has
			// to prove.
			const stopped = await once("refused", refusedBringBack);
			assert.equal(stopped.code, "prune-failed", "the prune refusal stops the call");
			const intent = readBringBackIntent(stopped.stateDir, "t1");
			assert.ok(intent, "a bring-back that stops leaves this run's own intent record");
			assert.deepEqual(intent?.paths, ["a.ts"], "the intent names the file set the call named");
		});
	});

	it("INV I11 -- one join is one write: the queue rests only in triggered, and the state file lands by one rename", suite, async () => {
		await check("I11", "atomic join transition", async () => {
			const run = await once("lifecycle", lifecycle);
			for (const snap of run.snapshots) {
				const states = (snap.status.entries as { state: string }[]).map((e) => e.state);
				assert.deepEqual([...new Set(states)], states.length === 0 ? [] : ["triggered"], `after ${snap.after} the queue rests only in triggered`);
				assert.deepEqual(snap.status.pending, [], `after ${snap.after} nothing is pending`);
			}
			// The state write is one rename, not an in-place rewrite: the file
			// the write lands on is the one the writer created, so a reader
			// sees either the whole prior state or the whole next one.
			const dir = tmpdir("taskq-inode-");
			try {
				const stateDir = path.join(dir, "state");
				const at = "2026-01-01T00:00:00.000Z";
				saveState(freshState("/repo/main", stateDir, at));
				const first = fs.statSync(statePathOf(stateDir)).ino;
				saveState({ ...loadState(stateDir)!, openedAt: "2026-01-02T00:00:00.000Z" });
				assert.notEqual(fs.statSync(statePathOf(stateDir)).ino, first, "the state file is replaced by a rename, not truncated in place");
			} finally {
				rmrf(dir);
			}
		});
	});

	it("INV I12 -- an operation that stops spends nothing", suite, async () => {
		await check("I12", "inert timeout", async () => {
			const stopped = await once("refused", refusedBringBack);
			assert.equal(stopped.code, "prune-failed", "the prune refusal stops the bring-back");
			assert.equal(statusPorcelain(stopped.root), stopped.porcelain, "the main tree is exactly as it was when the call arrived");
			assert.equal(fs.existsSync(path.join(stopped.root, "a.ts")), false, "the file set was never written");
			assert.equal(stopped.state.tasks.t1.phase, "terminated", "a stopped bring-back records nothing");
			const waited = await once("timeout", timedOut);
			assert.equal(waited.result.outcome, "timeout", "a join with nothing ready times out");
			assert.deepEqual(waited.after.counts, waited.before.counts, "a timed-out join consumes nothing");
			assert.deepEqual(waited.after.entries, waited.before.entries, "a timed-out join triggers nothing");
		});
	});

	// --- the join contract ------------------------------------------------

	it("INV J1 -- the join subsumes record, schedule, and trigger as one transition", suite, async () => {
		await check("J1", "atomic subsume", async () => {
			const run = await once("lifecycle", lifecycle);
			const entries = snapshotAfter(run, "active").status.entries as { state: string }[];
			assert.deepEqual([...new Set(entries.map((e) => e.state))], ["triggered"], "the queue never rests in requested or scheduled");
			assert.equal(entries.length, run.entryIds.length, "every delivery produced one entry, not three");
		});
	});

	it("INV J2 -- two joins on one worker request deliver it once", suite, async () => {
		await check("J2", "exactly-once delivery", async () => {
			const run = await once("raced", raced);
			const outcomes = run.results.map((r) => (typeof r === "object" ? (r as { outcome: string }).outcome : r));
			assert.equal(outcomes.filter((o) => o === "joined").length, 1, "one of the two joins delivered the break point");
			assert.equal(outcomes.filter((o) => o === "joined" || o === "held").length, 2, "the other reports the undecided break point, never a second delivery");
			const counts = run.counts as { entries: number; requests: number };
			assert.equal(counts.entries, 1, "the queue holds one entry for the one request");
			assert.equal(counts.requests, 1, "the request was recorded once");
		});
	});

	it("INV J3 -- the join refuses a timeout it cannot honour at once, and a timed-out join consumes nothing", suite, async () => {
		await check("J3", "blocking and inert wait", async () => {
			const tools = await loadTools();
			const run = await once("timeout", timedOut);
			let code: string | undefined;
			try {
				await callTool(tools, "taskq_join", { timeoutMs: 0 }, run.ctx);
			} catch (e) {
				code = errorCode(e);
			}
			assert.equal(code, "request-invalid", "a timeout the join cannot honour is refused at once, not at the end of a wait");
			assert.equal(run.result.outcome, "timeout", "the join with nothing ready is a timed wait");
		});
	});

	it("INV J4 -- one held join-unit (a single join or one pool batch) waits on the operator, and taskq_status names the step that clears it", suite, async () => {
		await check("J4", "one held join-unit", async () => {
			const run = await once("lifecycle", lifecycle);
			const held = run.held.result as { outcome: string; hold: { entryId: string; clearsBy: string } };
			assert.equal(held.outcome, "held", "the undecided break point is reported instead of a second payload");
			assert.ok(held.hold.clearsBy.length > 0, "the hold names the step that clears it");
			// The observer and the driver read the queue the same way.
			const reported = run.held.status.hold as { entryId: string; clearsBy: string };
			assert.equal(reported.entryId, held.hold.entryId, "taskq_status reports the same held break point the join did");
			assert.equal(reported.clearsBy, held.hold.clearsBy, "taskq_status names the same step that clears it");
		});
	});

	it("INV J5 -- break points trigger in request order per task", suite, async () => {
		await check("J5", "order-safe selection", async () => {
			const run = await once("lifecycle", lifecycle);
			const entries = snapshotAfter(run, "active").status.entries as { entryId: string; taskId: string }[];
			assert.deepEqual(entries.map((e) => e.entryId), entries.map((_, i) => entryIdOf("t1", i + 1)), "the entries trigger in request order per task");
			assert.ok(entries.every((e) => e.taskId === "t1"), "the join delivered one task's break points");
		});
	});

	// --- the fork contract ------------------------------------------------

	it("INV W1 -- the fork takes no path, and a worktree inside the main tree is refused", suite, async () => {
		await check("W1", "the fork owns the location", async () => {
			const tools = await loadTools();
			const properties = tools.taskq_fork.parameters?.properties ?? {};
			assert.ok(!("workdir" in properties), "the fork takes no workdir parameter: the tool owns the location");
			assert.ok("taskId" in properties, "the fork takes the task the path is derived from");
			const run = await once("lifecycle", lifecycle);
			assert.equal(run.workdir, path.join(run.worktreeRoot, "t1"), "the worktree path follows from the run and the task");
		});
	});

	it("INV W2 -- a leftover at the canonical path is refused and the path is named", suite, async () => {
		await check("W2", "one canonical location", async () => {
			const tools = await loadTools();
			const run = await once("leftover", leftover);
			let code: string | undefined;
			let message = "";
			try {
				await callTool(tools, "taskq_fork", { taskId: "t1" }, run.ctx);
			} catch (e) {
				code = errorCode(e);
				message = errorMessage(e);
			}
			assert.equal(code, "worktree-occupied", "a leftover at the canonical path stops the fork");
			assert.ok(message.includes(path.join(run.worktreeRoot, "t1")), "the refusal names the canonical path");
		});
	});

	it("INV W3 -- the cut worktree sits outside the main tree, and the cut writes nothing into it", suite, async () => {
		await check("W3", "outside the main tree", async () => {
			const run = await once("lifecycle", lifecycle);
			assert.ok(path.relative(run.root, run.workdir).startsWith(".."), `the worktree ${run.workdir} is outside the main tree ${run.root}`);
			assert.equal(run.porcelainAfterFork, "", "the cut leaves the main tree clean");
			assert.equal(run.gitFileAtFork, true, "the derived path holds a git worktree of the main repository");
		});
	});

	// --- the written surface ----------------------------------------------

	it("INV S1 -- the tool surface drives the whole loop, from the fork to the close", suite, async () => {
		await check("S1", "the written loop closes", async () => {
			await once("lifecycle", lifecycle);
			await once("requeued", requeued);
			assert.deepEqual([...driven].sort(), [...TOOL_SURFACE].sort(), "every tool in the surface ran in this report");
		});
	});

	it("INV S3 -- no registered tool exposes an intermediate break-point state to drive", suite, async () => {
		await check("S3", "no intermediate break-point surface", async () => {
			const names = Object.keys(await loadTools()).sort();
			assert.deepEqual(names, [...TOOL_SURFACE].sort(), "the surface is exactly the nine tools");
			for (const gone of ["taskq_poll", "taskq_record", "taskq_schedule", "taskq_trigger", "taskq_retire"]) {
				assert.ok(!names.includes(gone), `${gone} is not a tool`);
			}
		});
	});

	it("INV T1 -- the phases and the audit outcomes are a structural finding, and the bring-back's decision is a file set", suite, async () => {
		await check("T1", "no value judgement", async () => {
			// The phase vocabulary is the table's own, and it carries no grade.
			assert.deepEqual(new Set(TASK_PHASES), new Set(TASK_TRANSITIONS.map((t) => t.to)), "the phases are the phases the table names");
			for (const phase of TASK_PHASES) {
				assert.doesNotMatch(phase, /good|bad|pass|fail|score|grade|quality/i, `the phase ${phase} carries no grade`);
			}
			const run = await once("lifecycle", lifecycle);
			const decided = taskOf(snapshotAfter(run, "retired").status);
			assert.deepEqual(Object.keys(decided.bringBack as Record<string, unknown>).sort(), ["archived", "at", "paths"], "the bring-back record's decision is a file set");
			assert.equal((decided.verification as { outcome: string }).outcome, "usable", "the audit records the outcome it was given, and no other field");
			// The other outcome leaves the task in the queue, and the next
			// segment's audit is the live one.
			const other = await once("requeued", requeued);
			assert.deepEqual(other.notUsable, { phase: "active", outcome: "not-usable" }, "a not-usable audit records its outcome and leaves the task in the queue");
			const live = loadState(other.stateDir)!.tasks.t1;
			assert.equal(live.verification?.outcome, "usable", "the second segment's audit replaced the not-usable one");
			assert.equal(live.phase, "terminated", "the second segment's usable audit terminates the task");
		});
	});

	// --- the table, the lifecycle, and the single primary ------------------

	it("INV R12 -- the report's lifecycle cases are the table's own phases, and every action the table names is one this report indexes", suite, async () => {
		await check("R12", "the transition-table walk", async () => {
			const derived = catalog.filter((c) => c.id === "R14").map((c) => c.name.replace("phase ", ""));
			assert.deepEqual(derived, [...TASK_PHASES], "the lifecycle cases are derived from the table, not listed here");
			const named = TASK_TRANSITIONS.map((t) => `${String(t.from)}/${t.action}`);
			assert.equal(named.length, new Set(named).size, "no action is named twice from one phase");
			assert.deepEqual([...new Set(named.map((n) => n.split("/")[1]))].sort(), [...tableActions()].sort(), "every action the table names is in the report's index");
			// The entry table is the same kind of source: the report reads its
			// states rather than listing them, and a state nothing moves out
			// of is the single-trigger rule stated structurally.
			assert.deepEqual([...new Set(ENTRY_TRANSITIONS.flatMap((t) => [t.from, t.to]))], ["requested", "scheduled", "triggered"], "the entry states come from the table");
			assert.deepEqual([...new Set(ENTRY_TRANSITIONS.map((t) => t.from))], ["requested", "scheduled"], "no row leaves the terminal entry state");
		});
	});

	it("INV R13 -- a second writer on a state directory a live process owns is refused, and the refusal names that owner", suite, async () => {
		await check("R13", "one primary per state directory", async () => {
			const run = await once("locked", locked);
			assert.match(run.message, /ownership\.lock|one primary writes one state directory/, "the refusal names the lock and the rule");
			// The refusal reports the live owner instead of racing it, and the
			// lock file is the metadata that names it.
			assert.equal(run.holder?.sessionId, "the-other-primary", "the lock names the writer that holds it");
			assert.equal(run.holder?.taskId, "t9", "the lock names the task that writer drives");
			assert.equal(fs.existsSync(lockPathOf(run.stateDir)), false, "the live owner's lock is released, not broken");
		});
	});

	for (const phase of TASK_PHASES) {
		it(`INV R14 -- the wired tools report a task as ${phase}`, suite, async () => {
			await check("R14", `phase ${phase}`, async () => {
				const run = await once("lifecycle", lifecycle);
				// The snapshot is read after the step the table names, so the
				// case cannot drift from the table's order.
				assert.deepEqual(phasesOf(snapshotAfter(run, phase).status), [phase], `taskq_status reports the task as ${phase}`);
			});
		});
	}
});

/**
 * A run state whose task is retired and whose queue still holds an entry the
 * primary never triggered. Nothing drives a run into this shape, which is
 * the point: the close audit is the check that refuses it.
 */
function withPendingEntry(): { state: RunState } {
	const at = "2026-01-01T00:00:00.000Z";
	const main = "/repo/main";
	let state = freshState(main, "/repo/main/.taskq", at);
	state = forkOp(state, { taskId: "t1", workdir: "/wt/t1", branch: "exp/t1", baseline: "b0", mainRoot: main }, at).state;
	state = recordOp(state, { taskId: "t1", requestId: "t1-1", status: "done", workdir: "/wt/t1" }, at).state;
	state = scheduleOp(state, entryIdOf("t1", 1), at).state;
	state = triggerOp(state, { entryId: entryIdOf("t1", 1), head: "h1", changed: 1 }, at).state;
	state = verifyOp(state, { taskId: "t1", outcome: "usable", notes: "ok" }, at).state;
	state = proposalOp(state, { taskId: "t1", description: "", paths: ["a.txt"] }, at).state;
	state = bringBackOp(state, { taskId: "t1", paths: ["a.txt"], applied: ["a.txt"], archived: false, removedWorktree: "/wt/t1", prunedBranch: "exp/t1", resumed: false }, at).state;
	const stranded = { ...state.entries[0], entryId: entryIdOf("t1", 2), requestId: "t1-2", requestSeq: 2, state: "requested" as const };
	return { state: { ...state, entries: [...state.entries, stranded], requests: { ...state.requests, "t1-2": stranded.entryId } } };
}
