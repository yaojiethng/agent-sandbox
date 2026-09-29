/**
 * task-queue: the general sequencing primitive as a pi extension.
 *
 * The extension gives the primary agent a queue of worker-requested break
 * points with an exactly-once state machine (request -> scheduled ->
 * triggered), the fork/join/re-queue mechanics, the final verification
 * gates, the write-back proposal, the verdict-scoped merge, and the
 * clean-close retirement of worktrees and branches. The worker side gets
 * one tool that writes its break-point requests into its own worktree; the
 * request protocol is plain files, so any worker can participate.
 *
 * The queue and the gates are pure modules (queue.ts, tasks.ts, ops.ts);
 * persistence, git, and the merge are separate modules. This file wires
 * them to pi as tools.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { Type, type Static, type TSchema } from "typebox";
import { defineTool, withFileMutationQueue, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { TaskQueueError, type TaskQueueErrorCode } from "./errors.ts";
import { getEntry, pendingForTask } from "./queue.ts";
import { canMerge, canPropose, canRetire, type TaskRecord, type Verdict } from "./tasks.ts";
import { nowIso, forkOp, recordOp, scheduleOp, triggerOp, verifyOp, proposalOp, mergeOp, retireOp, closeOp, integrityCounts } from "./ops.ts";
import { archiveRequest, readArchivedRequest, type JournalEvent } from "./record.ts";
import { Run } from "./run.ts";
import { loadState, statePathOf } from "./state.ts";
import { gitRoot, resolveRev, addWorktree, worktreeHead, segmentInfo, pruneWorktree, isPruned, statusPorcelain, listWorktrees, listBranches, currentBranch } from "./worktree.ts";
import { proposalPaths } from "./proposal.ts";
import { applyVerdict, archiveDiscardedTrack } from "./merge.ts";
import { REQUESTS_DIR, listWorkerRequests, nextRequestId, parseWorkerRequest, writeWorkerRequest, type WorkerStatus } from "./protocol.ts";

const STATE_DIR_ENV = "TASKQ_STATE_DIR";

function stateDirOf(root: string): string {
	const given = process.env[STATE_DIR_ENV];
	if (given) return given;
	// Production default: a sibling of the repo root. The state directory
	// must never live inside the main tree: the merge gate requires a clean
	// tree, and the journal, the archives, and the state file would
	// permanently dirty it.
	return path.join(path.dirname(root), `.taskq-${path.basename(root)}`);
}

function openRunAt(root: string): Run {
	const stateDir = stateDirOf(root);
	if (!fs.existsSync(statePathOf(stateDir))) {
		// A fresh run records the worktrees and branches that predate it; the
		// close sweep treats those as the repository's own, not leftovers.
		return Run.open(stateDir, root, new Date().toISOString(), {
			worktrees: listWorktrees(root),
			branches: listBranches(root),
		});
	}
	return Run.open(stateDir, root);
}

function openRun(ctx: ExtensionContext): Run {
	return openRunAt(gitRoot(ctx.cwd));
}

/**
 * Run one state-mutating operation: the complete read-modify-write of the
 * state file is serialized against other tool calls of the same turn.
 */
async function runTool<D>(
	ctx: ExtensionContext,
	fn: (run: Run) => { data: D; events: JournalEvent[]; journalError?: string },
): Promise<{ data: D; journalError?: string }> {
	const root = gitRoot(ctx.cwd);
	const statePath = statePathOf(stateDirOf(root));
	const result = await withFileMutationQueue(statePath, async () => fn(openRunAt(root)));
	return { data: result.data, journalError: result.journalError };
}

function requireTaskPhase(run: Run, taskId: string, ok: (t: TaskRecord) => boolean, code: TaskQueueErrorCode): TaskRecord {
	const task = run.current().tasks[taskId];
	if (!task) throw new TaskQueueError("task-unknown", `no task with id ${taskId}`);
	if (!ok(task)) {
		throw new TaskQueueError(code, `task ${taskId} is ${task.phase}`);
	}
	return task;
}

/** One request document as the poll tool reports it. */
interface PollEntry {
	taskId: string;
	requestId: string;
	file: string;
	recorded: boolean;
	status: WorkerStatus | undefined;
	message: string | undefined;
	invalid: boolean;
	warning: string | undefined;
}

// ---------------------------------------------------------------------------
// Tool schemas
// ---------------------------------------------------------------------------

const forkSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	workerId: Type.Optional(Type.String({ minLength: 1 })),
	workdir: Type.String({ minLength: 1 }),
	branch: Type.Optional(Type.String({ minLength: 1 })),
	baseline: Type.Optional(Type.String({ minLength: 1 })),
});

const recordSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	requestPath: Type.String({ minLength: 1 }),
});

const entrySchema = Type.Object({
	entryId: Type.String({ minLength: 1 }),
});

const verifySchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	outcome: Type.Union([Type.Literal("passed"), Type.Literal("failed")]),
	notes: Type.String({ default: "" }),
});

const proposalSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	description: Type.Optional(Type.String()),
	excludePaths: Type.Optional(Type.Array(Type.String({ minLength: 1 }))),
});

// The verdict schema mirrors the Verdict union exactly: "all" and "none"
// carry no paths, "partial" requires a non-empty path list. A scope with a
// mismatched paths field is rejected at the tool boundary.
const verdictSchema = Type.Union([
	Type.Object({ scope: Type.Literal("all") }),
	Type.Object({ scope: Type.Literal("partial"), paths: Type.Array(Type.String({ minLength: 1 })) }),
	Type.Object({ scope: Type.Literal("none") }),
]);

const mergeSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	verdict: verdictSchema,
});

const retireSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
});

const workerRequestSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	message: Type.String({ minLength: 1 }),
	status: Type.Union([Type.Literal("running"), Type.Literal("done")]),
});

// ---------------------------------------------------------------------------
// Tool definitions
// ---------------------------------------------------------------------------

function define<P extends TSchema, D>(
	name: string,
	label: string,
	description: string,
	parameters: P,
	execute: (params: Static<P>, ctx: ExtensionContext) => Promise<D>,
	opts: { snippet?: string; sequential?: boolean } = {},
) {
	return defineTool({
		name,
		label,
		description,
		promptSnippet: opts.snippet,
		parameters,
		executionMode: opts.sequential ? "sequential" : "parallel",
		execute: async (_callId, params, _signal, _onUpdate, ctx) => {
			const data = await execute(params as Static<P>, ctx);
			return { content: [{ type: "text", text: JSON.stringify(data) }], details: data };
		},
	});
}

export default function (pi: ExtensionAPI): void {
	// --- fork -------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_fork",
			"Fork a task",
			"Cut one worker worktree and branch from the baseline commit and register the task in the queue. One fresh subagent per task runs in that worktree on that branch. The primary keeps the main tree free of its own edits for the whole run; the merged verdicts accumulate in the working tree.",
			forkSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				if (run.current().tasks[params.taskId]) {
					throw new TaskQueueError("task-duplicate", `task ${params.taskId} is already forked`);
				}
				const mainRoot = run.mainRoot;
				const workdir = path.resolve(ctx.cwd, params.workdir);
				const normalized = workdir.replace(/\/+$/, "");
				if (normalized === mainRoot || normalized.startsWith(mainRoot + "/")) {
					throw new TaskQueueError(
						"task-workdir-inside-main",
						`workdir ${normalized} must not be the main tree or inside it: workers never write in the main tree`,
					);
				}
				const baseline = resolveRev(mainRoot, params.baseline ?? "HEAD");
				const branch = params.branch ?? `exp/${params.taskId}`;
				addWorktree(mainRoot, { branch, path: workdir, baseline });
				try {
					const result = await runTool(ctx, (r) =>
						r.handle((state) => forkOp(state, { taskId: params.taskId, workerId: params.workerId, workdir: normalized, branch, baseline, mainRoot }, nowIso())),
					);
					return { ...result.data, workdir: normalized, baseline };
				} catch (err) {
					// The worktree was cut but the registration failed; undo the fork.
					// The undo prunes only while no registered task owns the branch or
					// the path: the serialized tool order closes the window, but the
					// guard keeps the undo from removing a worktree a retry owns.
					if (!registeredOwns(mainRoot, workdir, branch)) {
						try {
							pruneWorktree(mainRoot, { branch, path: workdir, baseline });
						} catch {
							// Best effort only; the close sweep refuses while an unregistered
							// worktree or branch survives, so the leftover stays visible.
						}
					}
					throw err;
				}
			},
			{ snippet: "taskq_fork - cut a worker worktree and branch from the baseline", sequential: true },
		),
	);

	/** True when a registered task owns the worktree path and the branch. */
	function registeredOwns(root: string, workdir: string, branch: string): boolean {
		try {
			const state = loadState(stateDirOf(root));
			if (!state) return false;
			return Object.values(state.tasks).some(
				(t) => t.branch === branch && path.resolve(t.workdir) === path.resolve(workdir),
			);
		} catch {
			// The state is unreadable; the undo cannot prove ownership and
			// leaves the worktree for the close sweep to name (I10).
			return true;
		}
	}

	// --- poll -------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_poll",
			"Poll worker requests",
			"Scan every task's worktree for break-point request documents the primary has not recorded yet, plus protocol warnings. Read-only.",
			Type.Object({}),
			async (_params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				const requests: PollEntry[] = [];
				for (const task of Object.values(state.tasks)) {
					if (task.phase === "verified" || task.phase === "merged" || task.phase === "discarded" || task.phase === "retired") continue;
					const pending = pendingForTask(state.entries, task.taskId);
					const latestPendingSeq = pending.reduce((m, e) => Math.max(m, e.requestSeq), 0);
					for (const item of listWorkerRequests(task.workdir)) {
						const recorded = Object.prototype.hasOwnProperty.call(state.requests, item.requestId);
						const seq = Number(item.requestId.slice(item.requestId.lastIndexOf("-") + 1));
						requests.push({
							taskId: task.taskId,
							requestId: item.requestId,
							file: path.join(task.workdir, REQUESTS_DIR, `${item.requestId}.json`),
							recorded,
							status: item.request?.status ?? undefined,
							message: item.request?.message ?? undefined,
							invalid: item.invalid,
							warning: !recorded && latestPendingSeq > 0 && seq > latestPendingSeq ? "request advanced before the pending break point cleared" : undefined,
						});
					}
				}
				return { closed: state.closed, requests };
			},
			{ snippet: "taskq_poll - scan worker worktrees for unrecorded break-point requests" },
		),
	);

	// --- record -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_record",
			"Record a break point",
			"Record a worker's requested break point into the queue (state: requested). The request document must live in the task's own worktree under taskq/requests/. The request id enters the queue exactly once.",
			recordSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				const task = run.current().tasks[params.taskId];
				if (!task) throw new TaskQueueError("task-unknown", `no task with id ${params.taskId}`);
				const dir = path.join(task.workdir, REQUESTS_DIR);
				if (path.dirname(path.resolve(params.requestPath)) !== path.resolve(dir)) {
					throw new TaskQueueError(
						"request-path-mismatch",
						`requestPath must sit in ${dir}, the task's own request directory`,
					);
				}
				// Read once: the queue validates and the archive keeps the same
				// bytes, so a hand-written document that changes between a parse
				// and a re-read cannot diverge from the recorded request.
				let content: string;
				try {
					content = fs.readFileSync(params.requestPath, "utf8");
				} catch {
					throw new TaskQueueError("request-file-missing", `no request document at ${params.requestPath}`);
				}
				const request = parseWorkerRequest(content, params.requestPath);
				if (request.taskId !== params.taskId) {
					throw new TaskQueueError("request-invalid", `request ${request.requestId} names task ${request.taskId}, not ${params.taskId}`);
				}
				archiveRequest(run.stateDir, request.requestId, content);
				const result = await runTool(ctx, (r) =>
					r.handle((state) => recordOp(state, { taskId: params.taskId, requestId: request.requestId, status: request.status, workdir: task.workdir }, nowIso())),
				);
				return { ...result.data.entry, status: request.status, message: request.message };
			},
			{ snippet: "taskq_record - record one requested break point into the queue", sequential: true },
		),
	);

	// --- schedule ---------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_schedule",
			"Schedule a break point",
			"Transition one recorded break point from requested to scheduled. Cross-task scheduling order is the primary's choice; a scheduled break point cannot be re-scheduled.",
			entrySchema,
			async (params, ctx) => {
				const result = await runTool(ctx, (r) => r.handle((state) => scheduleOp(state, params.entryId, nowIso())));
				return { entryId: result.data.entry.entryId, taskId: result.data.entry.taskId, state: result.data.entry.state };
			},
			{ snippet: "taskq_schedule - move one requested break point to scheduled", sequential: true },
		),
	);

	// --- trigger ----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_trigger",
			"Trigger a break point",
			"Trigger one scheduled break point: the dequeue. Returns the join payload - task, worker, worktree, the worker's request message, and the segment the worker changed since the last break point. The primary then holds at this break point, re-orients the operator, and waits.",
			entrySchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				const entry = getEntry(state.entries, params.entryId);
				if (!entry) throw new TaskQueueError("entry-unknown", `no entry with id ${params.entryId}`);
				const task = state.tasks[entry.taskId];
				// Entry refs must equal the task refs at dequeue time (I3).
				if (!task || entry.workerId !== task.workerId || entry.workdir !== task.workdir) {
					throw new TaskQueueError("entry-ref-mismatch", `entry ${entry.entryId} no longer matches its task`);
				}
				const head = worktreeHead(task.workdir);
				const from = task.lastSegmentHead || task.baseline;
				const seg = segmentInfo(task.workdir, from, head);
				// The archive is written before the record, so a recorded entry has
				// an archived document by construction; the re-parse uses the
				// worker protocol validation, and a malformed archive is state
				// corruption, not a display fallback.
				const { status: requestStatus, message } = readArchivedRequest(run.stateDir, entry.requestId);
				const result = await runTool(ctx, (r) => r.handle((state) => triggerOp(state, { entryId: params.entryId, head, changed: seg.changed.length }, nowIso())));
				const join = {
					entryId: result.data.entry.entryId,
					taskId: entry.taskId,
					workerId: entry.workerId,
					workdir: entry.workdir,
					branch: task.branch,
					baseline: task.baseline,
					requestStatus,
					message,
					segmentStat: seg.stat || "(no commits since the last break point)",
					segmentChanged: seg.changed,
				};
				if (ctx.hasUI) {
					ctx.ui.notify(`Break point ${entry.entryId} of task ${entry.taskId}: join the operator`, "info");
				}
				return join;
			},
			{ snippet: "taskq_trigger - trigger one scheduled break point and join the operator", sequential: true },
		),
	);

	// --- verify -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_verify",
			"Run final verification",
			"Record the final verification outcome for a task. Refuses before the worker requested its terminal break point and while any break point is pending. The verification audit itself (reading the report, running the checks) is the primary's run; this tool records its verdict.",
			verifySchema,
			async (params, ctx) => {
				const result = await runTool(ctx, (r) => r.handle((state) => verifyOp(state, { taskId: params.taskId, outcome: params.outcome, notes: params.notes }, nowIso())));
				return { taskId: params.taskId, phase: result.data.task.phase, outcome: params.outcome };
			},
			{ snippet: "taskq_verify - record passed or failed final verification for a task", sequential: true },
		),
	);

	// --- proposal ---------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_proposal",
			"Build the write-back proposal",
			"Build the write-back proposal for a verified task: the changed paths of the worker branch against the baseline, minus the worker's protocol directory and any excluded paths. The primary distills the proposal further with a description; the operator judges this proposal at the final break point.",
			proposalSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				requireTaskPhase(run, params.taskId, canPropose, "proposal-gate");
				const task = run.current().tasks[params.taskId];
				const paths = proposalPaths(run.mainRoot, task.baseline, task.branch, params.excludePaths ?? []);
				const result = await runTool(ctx, (r) => r.handle((state) => proposalOp(state, { taskId: params.taskId, description: params.description ?? "", paths }, nowIso())));
				return { taskId: params.taskId, proposal: result.data.proposal };
			},
			{ snippet: "taskq_proposal - distill a verified task into a write-back proposal", sequential: true },
		),
	);

	// --- merge ------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_merge",
			"Merge by verdict",
			"Apply the operator's bring-back verdict over the write-back proposal: all, partial, or none. Only a verified task merges (never before final verification). Partial must name a subset of the proposal. None archives the branch diff and discards the track. The main tree must be clean on the paths this verdict touches; earlier verdicts' results may stay uncommitted in the working tree.",
			mergeSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				const task = requireTaskPhase(run, params.taskId, canMerge, "merge-gate");
				if (!task.proposal) throw new TaskQueueError("merge-gate", `task ${params.taskId} has no proposal`);
				const verdict: Verdict = params.verdict;
				let applied: string[] = [];
				let archived = false;
				if (verdict.scope === "none") {
					archiveDiscardedTrack(run.stateDir, params.taskId, run.mainRoot, task.baseline, task.branch);
					archived = true;
				} else {
					// The apply is idempotent: a verdict interrupted between the
					// apply and the record re-applies nothing and records normally.
					applied = applyVerdict(run.mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal, verdict }).applied;
				}
				const result = await runTool(ctx, (r) => r.handle((state) => mergeOp(state, { taskId: params.taskId, verdict, applied, archived }, nowIso())));
				return { taskId: params.taskId, phase: result.data.task.phase, verdict, applied };
			},
			{ snippet: "taskq_merge - apply exactly the bring-back verdict over the proposal", sequential: true },
		),
	);

	// --- retire -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_retire",
			"Retire a task",
			"Remove a merged or discarded task's worktree and prune its branch. Refuses while the worktree holds files outside the taskq/ protocol directory. The primary exports anything it wants to keep before retiring.",
			retireSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				// A task interrupted between the prune and the record has phase
				// merged with a removed worktree; the gate admits it so the re-run
				// records the retire and the close completes. A retired phase with
				// a live worktree predates this ordering (record-first) and the
				// re-run completes its removal.
				const task = requireTaskPhase(run, params.taskId, (t) => canRetire(t) || t.phase === "retired", "retire-gate");
				const spec = { branch: task.branch, path: task.workdir, baseline: task.baseline };
				if (task.phase === "retired" && isPruned(run.mainRoot, spec)) {
					// The record and the prune both landed; the replay is a no-op.
					return { taskId: params.taskId, phase: "retired", removedWorktree: task.workdir, prunedBranch: task.branch };
				}
				// Prune first, record second: a failed prune leaves both the state
				// and the journal untouched, so an interrupted retire never leaves
				// a retire event the state does not confirm (I12).
				if (!isPruned(run.mainRoot, spec)) {
					pruneWorktree(run.mainRoot, spec);
				}
				if (task.phase !== "retired") {
					await runTool(ctx, (r) => r.handle((state) => retireOp(state, params.taskId, nowIso())));
				}
				return { taskId: params.taskId, phase: "retired", removedWorktree: task.workdir, prunedBranch: task.branch };
			},
			{ snippet: "taskq_retire - remove a decided task's worktree and prune its branch", sequential: true },
		),
	);

	// --- close ------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_close",
			"Close the run",
			"Close the run: every task must be retired first, every worktree removed, every branch pruned. Runs the exactly-once close audit (every recorded request produced exactly one entry; every entry triggered exactly once) and reports the counts.",
			Type.Object({}),
			async (_params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				if (state.closed) {
					// The close already committed; the replay reports the counts
					// instead of failing on a closed run (I13).
					return { closed: true, counts: integrityCounts(state) };
				}
				const leftovers = Object.values(state.tasks).filter((t) => !isPruned(run.mainRoot, { branch: t.branch, path: t.workdir, baseline: t.baseline }));
				if (leftovers.length > 0) {
					throw new TaskQueueError(
						"close-gate",
						`${leftovers.length} task(s) still have a worktree or branch: ${leftovers.map((t) => t.taskId).join(", ")}; retire them first`,
					);
				}
				// Sweep unregistered leftovers (I10): a fork interrupted between
				// cutting the worktree and registering the task must not survive
				// a clean close. Worktrees and branches that existed when the run
				// opened belong to the repository, not to this run, and are not
				// leftovers.
				if (state.baselineWorktrees !== undefined && state.baselineBranches !== undefined) {
					const ownedWorktrees = new Set(Object.values(state.tasks).map((t) => path.resolve(t.workdir)));
					const openedWorktrees = new Set(state.baselineWorktrees.map((p) => path.resolve(p)));
					const strayWorktrees = listWorktrees(run.mainRoot).filter((p) => {
						const resolved = path.resolve(p);
						return resolved !== path.resolve(run.mainRoot) && !ownedWorktrees.has(resolved) && !openedWorktrees.has(resolved);
					});
					const ownedBranches = new Set(Object.values(state.tasks).map((t) => t.branch));
					const openedBranches = new Set(state.baselineBranches);
					const current = currentBranch(run.mainRoot);
					const strayBranches = listBranches(run.mainRoot).filter((b) => b !== current && !ownedBranches.has(b) && !openedBranches.has(b));
					if (strayWorktrees.length > 0 || strayBranches.length > 0) {
						throw new TaskQueueError(
							"close-gate",
							`close refuses ${strayWorktrees.length} unregistered worktree(s) and ${strayBranches.length} unregistered branch(es) not owned by any task: ${strayWorktrees.join(", ")} / ${strayBranches.join(", ")}. Remove the leftovers of an aborted fork before closing`,
						);
					}
				}
				const result = await runTool(ctx, (r) => r.handle((state) => closeOp(state, nowIso())));
				return { closed: true, counts: result.data.counts };
			},
			{ snippet: "taskq_close - close the run after every task is retired", sequential: true },
		),
	);

	// --- status -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_status",
			"Queue status",
			"Snapshot of the run: tasks with phases, every queue entry with its state, pending entries, and the integrity counts.",
			Type.Object({}),
			async (_params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				return {
					closed: state.closed,
					stateDir: state.stateDir,
					counts: integrityCounts(state),
					tasks: Object.values(state.tasks).map((t) => ({
						taskId: t.taskId,
						workerId: t.workerId,
						workdir: t.workdir,
						branch: t.branch,
						baseline: t.baseline,
						phase: t.phase,
						workerDone: t.workerDone,
						verdict: t.verdict ?? undefined,
						proposalPaths: t.proposal?.paths ?? undefined,
					})),
					pending: state.entries.filter((e) => e.state !== "triggered").map((e) => ({ entryId: e.entryId, taskId: e.taskId, state: e.state })),
					entries: state.entries.map((e) => ({ entryId: e.entryId, taskId: e.taskId, state: e.state })),
				};
			},
			{ snippet: "taskq_status - snapshot of the queue and the tasks" },
		),
	);

	// --- worker side ------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_worker_request",
			"Request a break point",
			"Worker-side: request a break point from your own worktree. status \"running\" pauses for the operator; status \"done\" is the terminal break point, after which the primary runs the final verification. Commit your segment before requesting; the request document is written once and never overwritten.",
			workerRequestSchema,
			async (params, ctx) => {
				const requestId = nextRequestId(ctx.cwd, params.taskId);
				const file = writeWorkerRequest(ctx.cwd, {
					taskId: params.taskId,
					requestId,
					status: params.status,
					message: params.message,
					at: nowIso(),
				});
				let uncommitted = 0;
				try {
					const st = statusPorcelain(ctx.cwd);
					uncommitted = st.split("\n").filter((l) => l.trim() !== "").length;
				} catch {
					// Not a git checkout; the protocol is still usable.
				}
				return { requestId, file, uncommitted };
			},
			{ snippet: "taskq_worker_request - request a break point from your own worktree", sequential: true },
		),
	);
}