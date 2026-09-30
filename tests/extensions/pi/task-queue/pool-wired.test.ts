/**
 * The pool join through the registered tools: the real tool executions
 * against a real repository, in the production default state-directory
 * layout. The extension loads under jiti with pi's package aliases,
 * exactly as the pi runtime loads it, and the pool is driven the way a
 * primary drives it - fork, two workers, one call, two payloads.
 *
 * The suite holds what only the wired surface can show: the pool
 * delivers through the same tool a single join uses, a pool timeout
 * consumes nothing and leaves every task joinable on its own, and two
 * pool calls racing one pool deliver the batch exactly once.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";
import { Run } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/run.ts";
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

async function callTool(tools: Record<string, WiredTool>, name: string, params: object, ctx: ToolCtx): Promise<Record<string, unknown>> {
	const tool = tools[name];
	assert.ok(tool, `tool ${name} is registered`);
	const result = await tool.execute("pool-wired-1", params, undefined, undefined, {
		cwd: ctx.cwd,
		mode: "print",
		hasUI: false,
		ui: {},
	});
	assert.ok(result && typeof result === "object" && "details" in result, `${name} returned details`);
	return result.details as Record<string, unknown>;
}

interface Payload {
	entryId: string;
	taskId: string;
	message: string;
	segmentChanged: string[];
}

const suite = piAvailable() ? {} : { skip: "pi installation not present" };

/** A join bound: generous enough for a busy host, short enough for a suite. */
const JOIN_TIMEOUT_MS = 30_000;

interface Fixture {
	dir: string;
	root: string;
	ctx: ToolCtx;
	stateDir: string;
	workdirs: Record<string, string>;
}

/** Fork the named tasks and let each worker commit one segment and request. */
async function setup(tools: Record<string, WiredTool>, taskIds: string[]): Promise<Fixture> {
	delete process.env.TASKQ_STATE_DIR;
	const dir = tmpdir();
	const repo = makeMainRepo(dir);
	const ctx = { cwd: repo.root };
	const workdirs: Record<string, string> = {};
	for (const taskId of taskIds) {
		const forked = await callTool(tools, "taskq_fork", { taskId, baseline: repo.baseline }, ctx);
		const workdir = forked.workdir as string;
		workdirs[taskId] = workdir;
		writeFile(workdir, `src/${taskId}.ts`, "v1\n");
		commitAll(workdir, `segment of ${taskId}`);
		await callTool(tools, "taskq_worker_request", { taskId, message: `${taskId} ready for review`, status: "running" }, { cwd: workdir });
	}
	return { dir, root: repo.root, ctx, stateDir: path.join(dir, `.taskq-${path.basename(repo.root)}`), workdirs };
}

function payloads(result: Record<string, unknown>): Payload[] {
	assert.equal(result.outcome, "joined", `expected a pool delivery: ${JSON.stringify(result)}`);
	assert.equal(result.mode, "pool", `expected pool mode: ${JSON.stringify(result)}`);
	return result.payloads as Payload[];
}

describe("wired pool join", () => {
	it("one call joins a pool of two tasks and returns both payloads", suite, async () => {
		const tools = await loadTools();
		const f = await setup(tools, ["t1", "t2"]);
		try {
			const joined = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS, taskIds: ["t1", "t2"] }, f.ctx);
			const delivered = payloads(joined);
			assert.deepEqual(
				delivered.map((p) => [p.entryId, p.taskId, p.message, p.segmentChanged]),
				[
					["t1#1", "t1", "t1 ready for review", ["src/t1.ts"]],
					["t2#1", "t2", "t2 ready for review", ["src/t2.ts"]],
				],
			);
			// One call, one transition: the queue rests only in triggered, and
			// the operator holds the whole batch.
			const status = await callTool(tools, "taskq_status", {}, f.ctx);
			assert.deepEqual(
				(status.entries as Array<{ entryId: string; state: string }>).map((e) => [e.entryId, e.state]),
				[
					["t1#1", "triggered"],
					["t2#1", "triggered"],
				],
			);
			assert.deepEqual(status.holdTasks, ["t1", "t2"], "the held unit is the batch");
			assert.deepEqual(status.pending, []);
			assert.deepEqual(
				(status.counts as { requests: number; entries: number }).requests,
				(status.counts as { requests: number; entries: number }).entries,
				"each request of the batch entered once (I1)",
			);
			// A second pool call holds the delivered batch and delivers
			// nothing beside it (J4).
			const again = await callTool(tools, "taskq_join", { timeoutMs: 500, taskIds: ["t1", "t2"] }, f.ctx);
			assert.equal(again.outcome, "held");
			assert.equal(Run.open(f.stateDir, f.root).current().entries.length, 2);
		} finally {
			rmrf(f.dir);
		}
	});

	it("a pool timeout consumes nothing, and the ready task joins on its own", suite, async () => {
		const tools = await loadTools();
		const dir = tmpdir();
		try {
			delete process.env.TASKQ_STATE_DIR;
			const repo = makeMainRepo(dir);
			const ctx = { cwd: repo.root };
			const wt1 = (await callTool(tools, "taskq_fork", { taskId: "t1", baseline: repo.baseline }, ctx)).workdir as string;
			await callTool(tools, "taskq_fork", { taskId: "t2", baseline: repo.baseline }, ctx);
			writeFile(wt1, "a.ts", "v1\n");
			commitAll(wt1, "segment");
			await callTool(tools, "taskq_worker_request", { taskId: "t1", message: "t1 ready", status: "running" }, { cwd: wt1 });
			// t2 is still running its segment: the pool cannot complete.
			const timed = await callTool(tools, "taskq_join", { timeoutMs: 500, taskIds: ["t1", "t2"] }, ctx);
			assert.equal(timed.outcome, "timeout");
			assert.deepEqual(timed.ready, ["t1"]);
			assert.deepEqual(timed.missing, ["t2"]);
			assert.equal(String(timed.note).includes("t2"), true, "the timeout names what the caller can do next");
			const stateDir = path.join(dir, `.taskq-${path.basename(repo.root)}`);
			assert.equal(Run.open(stateDir, repo.root).current().entries.length, 0, "the timeout triggered nothing (I12)");
			// After the timeout the caller joins the ready task on its own.
			const single = await callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS, taskId: "t1" }, ctx);
			assert.equal(single.outcome, "joined");
			assert.equal(single.entryId, "t1#1");
			assert.equal(Run.open(stateDir, repo.root).current().entries.length, 1, "only the ready task was delivered");
		} finally {
			rmrf(dir);
		}
	});

	it("two pool calls racing one pool deliver the batch exactly once", suite, async () => {
		const tools = await loadTools();
		const f = await setup(tools, ["t1", "t2"]);
		try {
			const [first, second] = await Promise.all([
				callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS, taskIds: ["t1", "t2"] }, f.ctx),
				callTool(tools, "taskq_join", { timeoutMs: JOIN_TIMEOUT_MS, taskIds: ["t2", "t1"] }, f.ctx),
			]);
			const outcomes = [first.outcome, second.outcome].sort();
			// One call delivered the batch; the other reported the hold the
			// delivery opened, and no task of the pool triggered twice.
			assert.deepEqual(outcomes, ["held", "joined"]);
			const state = Run.open(f.stateDir, f.root).current();
			assert.equal(state.entries.length, 2);
			assert.equal(state.entries.filter((e) => e.state === "triggered").length, 2);
			assert.equal(Object.keys(state.requests).length, 2);
		} finally {
			rmrf(f.dir);
		}
	});
});
