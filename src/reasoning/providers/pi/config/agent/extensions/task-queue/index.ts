/**
 * task-queue: the general sequencing primitive as a pi extension.
 *
 * The extension gives the primary a fork and a join. The fork cuts a
 * worker worktree and branch at a location the tool owns. The join is
 * the one blocking call through which break points are waited for and
 * handled: one call records, schedules, and triggers them as one atomic
 * transition and returns the join payload, so the operator's decision is
 * the only thing the primary drives. The join has three modes and the
 * selector picks one: any task, one named task, or a whole pool of tasks
 * in one batch. Around the join sit the termination audit, the two
 * re-queue routes, the write-back proposal, the bring-back, and the clean
 * close. The worker side gets one tool that writes its break-point
 * requests into its own worktree; the request protocol is plain files, so
 * any worker can participate.
 *
 * The queue and the gates are pure modules (queue.ts, tasks.ts, ops.ts,
 * join.ts, transitions.ts); persistence, the ownership lock, git, and
 * the main-tree write are separate modules. This file wires them to pi as
 * tools.
 *
 * One primary writes one state directory. Every state-mutating tool runs
 * its whole load-derive-save under the state directory's ownership lock,
 * and the git work it must not interleave with another writer's runs in
 * the same critical section: the fork's cut, the re-queue's rollback, and
 * the bring-back's write each sit inside the transaction that records
 * them. A second process on the same state directory is refused with its
 * owner named, not raced.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { Type, type Static, type TSchema } from "typebox";
import { defineTool, withFileMutationQueue, type ExtensionAPI, type ExtensionContext } from "@earendil-works/pi-coding-agent";
import { TaskQueueError, type TaskQueueErrorCode } from "./errors.ts";
import { assertFileSet, canBringBack, canClose, canPropose, canRequeue, type TaskRecord } from "./tasks.ts";
import type { RequeueRoute } from "./transitions.ts";
import { bringBackOp, closeOp, forkOp, integrityCounts, joinAllOp, joinOp, nowIso, proposalOp, requeueOp, verifyOp, type JoinParams, type OpResult } from "./ops.ts";
import { heldBreakPoint, heldUnit, scanReady, waitForBreakPoint, type HeldResult, type JoinResult, type PoolJoinedResult } from "./join.ts";
import { Run } from "./run.ts";
import { loadState, statePathOf, type RunState } from "./state.ts";
import type { LockScope, SectionLive } from "./lock.ts";
import { previousSeq } from "./queue.ts";
import {
	addWorktree,
	assertPrunable,
	assertWorkdirFree,
	canonicalWorkdir,
	currentBranch,
	gitRoot,
	isPruned,
	listBranches,
	listWorktrees,
	pruneWorktree,
	resolveRev,
	rollbackWorktree,
	statusPorcelain,
	worktreeHead,
	worktreeRootOf,
} from "./worktree.ts";
import { proposalPaths } from "./proposal.ts";
import { applyBringBack, archiveTrack } from "./merge.ts";
import { archiveDiffPathOf, bringBackIntentPathOf, clearBringBackIntent, markBringBackWritten, readBringBackIntent, writeBringBackIntent } from "./record.ts";
import { nextRequestId, writeWorkerRequest, writeWorkerState } from "./protocol.ts";

const STATE_DIR_ENV = "TASKQ_STATE_DIR";

function stateDirOf(root: string): string {
	const given = process.env[STATE_DIR_ENV];
	if (given) return given;
	// Production default: a sibling of the repo root. The state directory
	// must never live inside the main tree: the bring-back needs the main
	// tree clean on the paths it writes, and the journal, the archives, and
	// the state file would permanently dirty it.
	return path.join(path.dirname(root), `.taskq-${path.basename(root)}`);
}

/** The pi session writing this state directory, for the lock metadata. */
function sessionIdOf(ctx: ExtensionContext): string {
	return ctx.sessionManager?.getSessionId?.() ?? "unknown";
}

function openRunAt(root: string, sessionId: string): Run {
	return Run.open(stateDirOf(root), root, undefined, undefined, {
		sessionId,
		// A fresh run records the worktrees and branches that predate it; the
		// close sweep treats those as the repository's own, not leftovers.
		// The snapshot is read inside the lock, and only when the run is new.
		snapshotBaseline: () => ({ worktrees: listWorktrees(root), branches: listBranches(root) }),
	});
}

function openRun(ctx: ExtensionContext): Run {
	return openRunAt(gitRoot(ctx.cwd), sessionIdOf(ctx));
}

/**
 * Run one state-mutating operation as one locked transaction: the
 * derivation, the git work it needs, the atomic state write, and the
 * journal entry are one unit no other process on this state directory can
 * interleave with. The scope names the task and worktree the call drives,
 * so a lock left behind by a crash says which worktree its owner held.
 * The derive also receives the lock's liveness refresh and beats at each
 * git step, because a bring-back that runs longer than the stale window
 * would otherwise have its live lock taken from it.
 */
async function runTool<D>(
	ctx: ExtensionContext,
	scope: LockScope | undefined,
	derive: (state: RunState, live: SectionLive) => OpResult<D>,
): Promise<D> {
	const root = gitRoot(ctx.cwd);
	const statePath = statePathOf(stateDirOf(root));
	const sessionId = sessionIdOf(ctx);
	const result = await withFileMutationQueue(statePath, async () => openRunAt(root, sessionId).transact(derive, scope));
	if (result.journalError) {
		// The state file is durable even when the audit trail is not; say so
		// rather than failing an operation that already committed.
		process.stderr.write(`task-queue: the journal could not be appended: ${result.journalError}\n`);
	}
	return result.data;
}

function requireTaskPhase(run: Run, taskId: string, ok: (t: TaskRecord) => boolean, code: TaskQueueErrorCode): TaskRecord {
	const task = run.current().tasks[taskId];
	if (!task) throw new TaskQueueError("task-unknown", `no task with id ${taskId}`);
	if (!ok(task)) {
		throw new TaskQueueError(code, `task ${taskId} is ${task.phase}`);
	}
	return task;
}

/** True when a registered task owns the worktree path and the branch. */
function registeredOwns(root: string, workdir: string, branch: string): boolean {
	try {
		const state = loadState(stateDirOf(root));
		if (!state) return false;
		return Object.values(state.tasks).some((t) => t.branch === branch && path.resolve(t.workdir) === path.resolve(workdir));
	} catch {
		// The state is unreadable; an undo cannot prove ownership and leaves
		// the worktree for the close sweep to name (I10).
		return true;
	}
}

/** Two file sets name the same paths, in whatever order they were named. */
function sameFileSet(a: readonly string[], b: readonly string[]): boolean {
	const left = [...a].sort();
	const right = [...b].sort();
	return left.length === right.length && left.every((p, i) => p === right[i]);
}

// ---------------------------------------------------------------------------
// Tool schemas
// ---------------------------------------------------------------------------

const forkSchema = Type.Object({
	// One path segment, nothing else: the worktree path is derived from it.
	taskId: Type.String({ minLength: 1, pattern: "^[A-Za-z0-9][A-Za-z0-9._-]*$" }),
	workerId: Type.Optional(Type.String({ minLength: 1 })),
	branch: Type.Optional(Type.String({ minLength: 1 })),
	baseline: Type.Optional(Type.String({ minLength: 1 })),
});

const joinSchema = Type.Object({
	timeoutMs: Type.Integer({ minimum: 100, maximum: 3_600_000 }),
	taskId: Type.Optional(Type.String({ minLength: 1 })),
	// Pool mode: the model reads the task list from taskq_status.
	taskIds: Type.Optional(Type.Array(Type.String({ minLength: 1 }), { minItems: 1 })),
});

const verifySchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	outcome: Type.Union([Type.Literal("usable"), Type.Literal("not-usable")]),
	notes: Type.String({ default: "" }),
});

const proposalSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	description: Type.Optional(Type.String()),
	excludePaths: Type.Optional(Type.Array(Type.String({ minLength: 1 }))),
});

// The file set the bring-back writes: what lands in the main tree. An
// empty set is legal and means "write nothing back"; a named path the
// proposal does not contain is rejected at the tool boundary and again at
// the write.
const bringBackSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	paths: Type.Array(Type.String({ minLength: 1 })),
});

const requeueSchema = Type.Object({
	taskId: Type.String({ minLength: 1 }),
	route: Type.Union([Type.Literal("in-place"), Type.Literal("fresh")]),
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
	execute: (params: Static<P>, ctx: ExtensionContext, signal: AbortSignal | undefined) => Promise<D>,
	opts: { snippet?: string; sequential?: boolean } = {},
) {
	return defineTool({
		name,
		label,
		description,
		promptSnippet: opts.snippet,
		parameters,
		executionMode: opts.sequential ? "sequential" : "parallel",
		execute: async (_callId, params, signal, _onUpdate, ctx) => {
			const data = await execute(params as Static<P>, ctx, signal);
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
			"Cut one worker worktree and branch from the baseline commit and register the task in the queue. The call owns the location: it cuts the worktree at the run-scoped canonical path and returns it, so the caller creates no worktree and passes no path. The worktree is cut outside the main tree, which this call never writes to, and the cut, the collision check, and the registration are one serialized transaction: two forks on one state directory cannot interleave, and one fork's undo cannot remove another's worktree. One fresh subagent per task runs in that worktree on that branch; the primary keeps the main tree free of its own edits for the whole run, and the brought-back file sets accumulate in the working tree. A leftover worktree, branch, or directory at the canonical path is refused with that path named: clear it by hand and fork again. One primary writes one state directory; a call against a directory a live process owns is refused with that owner's lock named.",
			forkSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				if (run.current().tasks[params.taskId]) {
					throw new TaskQueueError("task-duplicate", `task ${params.taskId} is already forked`);
				}
				const mainRoot = run.mainRoot;
				const workdir = canonicalWorkdir(mainRoot, run.stateDir, params.taskId);
				const branch = params.branch ?? `exp/${params.taskId}`;
				const baseline = resolveRev(mainRoot, params.baseline ?? "HEAD");
				const spec = { branch, path: workdir, baseline };
				const task = await runTool(ctx, { taskId: params.taskId, workdir }, (state, live) => {
					// The fork owns the location, so a leftover is refused
					// before anything is cut: the operator clears it, never a
					// second path.
					assertWorkdirFree(mainRoot, spec);
					live.beat();
					addWorktree(mainRoot, spec);
					live.beat();
					try {
						return forkOp(state, { taskId: params.taskId, workerId: params.workerId, workdir, branch, baseline, mainRoot }, nowIso());
					} catch (err) {
						// The worktree was cut but the registration failed; undo
						// the fork. The undo prunes only while no registered task
						// owns the branch or the path, and it runs inside the same
						// lock as the cut and the record, so nothing else can claim
						// the worktree in between.
						if (!registeredOwns(mainRoot, workdir, branch)) {
							try {
								live.beat();
								pruneWorktree(mainRoot, spec);
							} catch {
								// Best effort only; the close sweep refuses while an
								// unregistered worktree or branch survives, so the
								// leftover stays visible.
							}
						}
						throw err;
					}
				});
				return { ...task, workdir, branch, baseline, worktreeRoot: worktreeRootOf(mainRoot, run.stateDir) };
			},
			{ snippet: "taskq_fork - cut a worker worktree and branch at the run-scoped canonical path", sequential: true },
		),
	);

	// --- join -------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_join",
			"Join a worker break point",
			"Block until worker break points are ready, then deliver them: one call scans the task worktrees, records the worker requests into the queue, schedules them, and triggers them as one atomic transition, and returns the join payload - task, worker, worktree, the worker message, the segment the worker changed since the last break point, and any uncommitted path left in its worktree. This is the queue fork(2)/wait(2): it is the only way a break point is deployed, so the call cannot be made out of order and there is nothing to drive in between. Set timeoutMs to bound the block and prefer it to any sleep; a timeout return is inert (nothing was recorded, scheduled, or triggered) and is normal while a worker runs its segment. Never sleep and re-poll: this call is the wait. The selector picks one of three modes: name taskIds to join a pool, name taskId to join that one task, and name neither to join any task. Pool mode blocks until every named task has a break point ready, then records, schedules, and triggers the whole set in one transition - the batch moves as one, so a task that moved under it holds the whole batch back - and returns one payload per task, in the order the pool named them; read the task list from taskq_status. A pool timeout is inert like any other and names the tasks of the pool that had a break point, so the caller can join any of them on its own, or the whole pool again. One join-unit waits on the operator at a time, and a join-unit is a single break point or one pool batch: while the operator has not decided it, the call returns that hold and the step that clears it instead of another payload. A taskId no task holds, a taskIds list that names no task or the same task twice, a task the queue has closed to requests, and naming both selectors are all refused at once instead of at the end of the timeout.",
			joinSchema,
			async (params, ctx, signal) => {
				const run = openRun(ctx);
				const result = await waitForBreakPoint(
					{
						stateDir: run.stateDir,
						current: () => run.current(),
						join: async (p) => {
							const data = await runTool(ctx, { taskId: p.taskId }, (state, live) => {
								assertHeadUnmoved(state, live, p, "join");
								return joinOp(state, p, nowIso());
							});
							return { data };
						},
						joinAll: async (ps) => {
							// One locked transaction for the whole pool: the
							// batch records, schedules, and triggers together
							// or not at all (I11). The lock names no single
							// task, because the section drives them all.
							const data = await runTool(ctx, undefined, (state, live) => {
								for (const p of ps) assertHeadUnmoved(state, live, p, "pool");
								return joinAllOp(state, ps, nowIso());
							});
							return { data: data.joins };
						},
					},
					{
						timeoutMs: params.timeoutMs,
						taskId: params.taskId,
						taskIds: params.taskIds,
						signal,
						onJoin: (payload) => {
							if (ctx.hasUI) {
								ctx.ui.notify(`Break point ${payload.entryId} of task ${payload.taskId}: join the operator`, "info");
							}
						},
					},
				);
				return joinResultOf(result);
			},
			{ snippet: "taskq_join - block until a worker break point is ready, then deliver it", sequential: true },
		),
	);

	/**
	 * The head the payload's segment was measured from is read again here,
	 * under the lock. A worker that committed since is a contention:
	 * recording the older head would make the re-queue roll back past a
	 * commit the operator never saw, so the delivery is refused and the
	 * join re-scans.
	 */
	function assertHeadUnmoved(state: RunState, live: SectionLive, p: JoinParams, subject: string): void {
		const task = state.tasks[p.taskId];
		if (p.baseHead === undefined || !task) return;
		live.beat();
		const head = worktreeHead(task.workdir);
		if (head !== p.head) {
			throw new TaskQueueError(
				"join-contended",
				`task ${p.taskId} is at ${head}, not ${p.head}; the worker committed under this ${subject}, so the segment and the uncommitted notice are read again`,
			);
		}
	}

	/** The join result plus the next step it names for the primary. */
	function joinResultOf(result: JoinResult): Record<string, unknown> {
		switch (result.outcome) {
			case "joined":
				if ("mode" in result) {
					const pool: PoolJoinedResult = result;
					return {
						...pool,
						note:
							`${pool.payloads.length} break point(s) delivered as one pool batch. The operator now holds every break point in it; the next join reports the hold until each is cleared`,
					};
				}
				return result;
			case "held": {
				const hold: HeldResult = result;
				return {
					...hold,
					note:
						`break point ${hold.hold.entryId} of task ${hold.hold.taskId} waits on the operator and the worker asked: ${hold.hold.message}. ` +
						`Clear it with ${hold.hold.clearsBy}`,
				};
			}
			case "timeout":
				return {
					...result,
					note:
						result.missing === undefined
							? "no break point became ready within the timeout; nothing was consumed. Join again, or call taskq_status"
							: `no break point became ready within the timeout; nothing was consumed. Pool task(s) ${result.missing.join(", ")} had none; join the ready one(s) ${result.ready?.join(", ") || ""} by taskId, join the pool again, or call taskq_status`,
				};
			case "aborted":
				return { ...result, note: "the call was aborted before a break point was ready; nothing was consumed" };
		}
	}

	// --- verify -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_verify",
			"Record the final verification",
			"Record the termination audit for a task: usable or not-usable, with the notes that back the finding. The audit itself is the primary's own run - read the diff, run the checks the brief named, confirm the report landed - and this call records what it found. It refuses before the worker requested its terminal break point, while any break point is pending, and for a second audit of the same terminal break point. A usable audit terminates the task, which is the only state a bring-back runs from; a not-usable one leaves the task in the queue, and the next step is the re-queue. The audit is structural: it records whether the return arrived as directed, never whether the work is good.",
			verifySchema,
			async (params, ctx) => {
				const { task } = await runTool(ctx, { taskId: params.taskId }, (state) =>
					verifyOp(state, { taskId: params.taskId, outcome: params.outcome, notes: params.notes }, nowIso()),
				);
				return { taskId: params.taskId, phase: task.phase, outcome: params.outcome, entryId: task.verification?.entryId };
			},
			{ snippet: "taskq_verify - record the usable or not-usable termination audit for a task", sequential: true },
		),
	);

	// --- proposal ---------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_proposal",
			"Build the write-back proposal",
			"Build the write-back proposal for a terminated task: the changed paths of the worker branch against the baseline, minus the worker's protocol directory and any excluded paths. The primary distills the proposal further with a description; the operator judges this proposal at the terminal break point, and the bring-back writes a subset of it back into the main tree.",
			proposalSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				requireTaskPhase(run, params.taskId, canPropose, "proposal-gate");
				const task = run.current().tasks[params.taskId];
				const paths = proposalPaths(run.mainRoot, task.baseline, task.branch, params.excludePaths ?? []);
				const proposal = await runTool(ctx, { taskId: params.taskId, workdir: task.workdir }, (state) =>
					proposalOp(state, { taskId: params.taskId, description: params.description ?? "", paths }, nowIso()),
				);
				return { taskId: params.taskId, proposal: proposal.proposal };
			},
			{ snippet: "taskq_proposal - distill a terminated task into a write-back proposal", sequential: true },
		),
	);

	// --- bring-back -------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_merge",
			"Write back a file set",
			"The bring-back: write a file set into the main tree and end the task, in one call. The file set is the verdict - a subset of the write-back proposal, possibly the empty set - and the call then removes the worktree and prunes the branch, which is why there is no separate retirement step. An empty file set writes nothing back and still prunes; the branch diff is archived into the run record, and a usable-terminated branch is packaged before this call, so nothing is lost. Only a terminated task comes back: its terminal break point delivered, the audit recorded usable, and the proposal built. A bring-back refused with `bring-back-unprovable` has written nothing: the task is not retired, the main tree is unchanged, and no file set came back. The worktree and the branch are gone, and no record of this tool says it wrote them, so the call refuses to infer a retirement it cannot prove. Restore the worktree and the branch from a branch package and bring back again, or recover the file set by hand. A named path outside the proposal is rejected. The main tree must be clean on the paths the file set names; earlier bring-backs' results and unrelated primary edits never block one. A rejected bring-back leaves the main tree untouched: the prune-refusal is checked before anything is written, and the write itself applies atomically. A worktree that grows content between that check and the prune still refuses after the write, and the re-run resumes that attempt from the record it left. The write is idempotent: a call interrupted after the write completes on a retry, and a re-run on an already-retired task reports the same result.",
			bringBackSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				// A task interrupted between the prune and the record still reads
				// terminated with a removed worktree; the gate admits it so the
				// re-run can resume it from its intent record. A retired
				// task whose worktree still exists predates this ordering
				// (record-first) and the re-run completes its removal.
				const gate = requireTaskPhase(run, params.taskId, (t) => canBringBack(t) || t.phase === "retired", "bring-back-gate");
				if (!gate.proposal) throw new TaskQueueError("bring-back-gate", `task ${params.taskId} has no proposal`);
				try {
					assertFileSet(params.paths, gate.proposal);
				} catch (err) {
					throw new TaskQueueError("file-set-invalid", String(err instanceof Error ? err.message : err));
				}
				const mainRoot = run.mainRoot;
				// The write, the prune, and the record are one transaction: a
				// failed write or a refused prune leaves the state and the
				// journal untouched, so a re-run completes the bring-back (I12).
				const result = await runTool(ctx, { taskId: params.taskId, workdir: gate.workdir }, (state, live) => {
					const task = state.tasks[params.taskId];
					const spec = { branch: task.branch, path: task.workdir, baseline: task.baseline };
					// The prune precedes the record, so an interrupted bring-back
					// is resumable - but only on this tool's own evidence. A gone
					// worktree proves a write on its own only when this call's
					// prune removed it, and nothing else records that: the
					// operator removes a worktree and a branch with the two
					// commands the fork refusal prints, and a call that refused
					// at the prune gate leaves a gone tree behind with no write
					// either. The intent record, written here before any git
					// work, is that evidence (I7, I12).
					const alreadyPruned = isPruned(mainRoot, spec);
					let applied: string[] = [];
					let archived = false;
					if (!alreadyPruned) {
						// Recorded before the prune-refusal is even asked, so no
						// record ever claims a write an attempt did not make: a
						// refusal here leaves a pending intent that no resume
						// accepts, because the write never completed.
						writeBringBackIntent(run.stateDir, params.taskId, { paths: [...params.paths], at: nowIso() });
						// The prune-refusal is asked before the write and before
						// the archive, inside this same locked derive: a worktree
						// holding unwritten content refuses the whole call while
						// the main tree is still exactly as it was (I7, I12).
						live.beat();
						assertPrunable(spec);
						live.beat();
						if (params.paths.length === 0) {
							archiveTrack(run.stateDir, params.taskId, mainRoot, task.baseline, task.branch);
							archived = true;
						} else {
							applied = applyBringBack(mainRoot, { baseline: task.baseline, branch: task.branch, proposal: task.proposal!, paths: params.paths }).applied;
						}
						// The write landed, so the evidence says so; the prune
						// that follows is what a later call reads back.
						markBringBackWritten(run.stateDir, params.taskId, nowIso());
						live.beat();
						pruneWorktree(mainRoot, spec);
					} else if (task.phase === "retired") {
						// The record already exists and the worktree is gone: the
						// call answers twice and changes nothing (I13), so it
						// reports what the record says.
						applied = [...(task.bringBack?.paths ?? [])];
						archived = task.bringBack?.archived ?? false;
					} else {
						// A terminated task with a gone worktree is an attempt
						// interrupted between its prune and its record. It
						// resumes on that attempt's own intent record and on
						// nothing else; a missing or unwritten intent is
						// refused, so the tool never infers a main-tree write it
						// cannot prove (I7).
						const intent = readBringBackIntent(run.stateDir, params.taskId);
						const evidence = bringBackIntentPathOf(run.stateDir, params.taskId);
						if (!intent?.writtenAt) {
							throw new TaskQueueError(
								"bring-back-unprovable",
								`task ${params.taskId} is ${task.phase} and its worktree ${task.workdir} and branch ${task.branch} are gone, but ${evidence} records no completed bring-back of this run. A gone worktree proves a write only when this tool's own prune removed it, and nothing here says one did. Nothing was written into the main tree, nothing was archived, and nothing was recorded. Restore the worktree and the branch from a branch package and bring back again, or recover the file set by hand`,
							);
						}
						if (!sameFileSet(intent.paths, params.paths)) {
							throw new TaskQueueError(
								"bring-back-unprovable",
								`task ${params.taskId} is ${task.phase} and its worktree is gone; ${evidence} records the file set [${intent.paths.join(", ")}] the interrupted attempt wrote, and this call named [${params.paths.join(", ")}]. A resumed bring-back names the file set that attempt wrote. Nothing was written and nothing was recorded: name the recorded file set, or recover the other one by hand`,
							);
						}
						// The record infers the interrupted attempt's write
						// instead of reporting an empty apply. `resumed` on the
						// journal event tells an inferred record from a
						// performed one.
						applied = [...intent.paths];
						// The archived diff is the empty file set's whole
						// deliverable, so the claim rests on that file, not on
						// the intent alone.
						archived = params.paths.length === 0 && fs.existsSync(archiveDiffPathOf(run.stateDir, params.taskId));
					}
					const back = bringBackOp(
						state,
						{ taskId: params.taskId, paths: params.paths, applied, archived, removedWorktree: task.workdir, prunedBranch: task.branch, resumed: alreadyPruned },
						nowIso(),
					);
					return {
						state: back.state,
						events: back.events,
						data: { task: back.data.task, applied, archived, resumed: alreadyPruned },
						// The intent is dropped in the same locked section that
						// writes the record, and only once that record is
						// durable: a crash between the two leaves the evidence
						// a re-run needs, and the evidence never outlives the
						// record that replaced it.
						commit: () => clearBringBackIntent(run.stateDir, params.taskId),
					};
				});
				return {
					taskId: params.taskId,
					phase: result.task.phase,
					broughtBack: result.task.bringBack?.paths ?? [],
					applied: result.applied,
					archived: result.archived,
					removedWorktree: result.task.workdir,
					prunedBranch: result.task.branch,
					resumed: result.resumed,
				};
			},
			{ snippet: "taskq_merge - write back the named file set, then prune the worktree and the branch", sequential: true },
		),
	);

	// --- requeue ----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_requeue",
			"Re-queue a task",
			"The answer to a not-usable verification audit: put the task back in the queue for another segment. The primary chooses the route by where the defect is. Route in-place rolls the worktree back to the branch head the last delivered segment reached, keeps the worktree, the branch, and the same worker's session log, and clears the segment's uncommitted wreckage; use it when the corruption is contained to the segment. Route fresh removes the worktree and the branch, cuts a new one from the baseline, and reseeds the worker's request sequence; use it when the worktree, its git state, or the environment around it is poisoned, so that a rollback would carry the damage forward. The fresh route is a forced removal, so package the branch before calling it. Either way the queue entries stay: the next segment is a new entry, never a second run. Only an active task re-queues, and only between segments.",
			requeueSchema,
			async (params, ctx) => {
				const run = openRun(ctx);
				const gate = requireTaskPhase(run, params.taskId, canRequeue, "requeue-gate");
				const route: RequeueRoute = params.route;
				const mainRoot = run.mainRoot;
				// The worktree move and the record are one transaction, so no
				// other writer on this state directory can observe a worktree
				// at a head no record names.
				const result = await runTool(ctx, { taskId: params.taskId, workdir: gate.workdir }, (state, live) => {
					const task = state.tasks[params.taskId];
					const spec = { branch: task.branch, path: task.workdir, baseline: task.baseline };
					let head: string;
					if (route === "in-place") {
						head = task.lastSegmentHead;
						live.beat();
						rollbackWorktree(task.workdir, head);
					} else {
						head = task.baseline;
						live.beat();
						// Forced: abandoning a poisoned track is the point of this
						// route, and the branch is packaged before the call.
						pruneWorktree(mainRoot, spec, { force: true });
						live.beat();
						addWorktree(mainRoot, spec);
						// The fresh worktree starts with an empty request counter;
						// seed it at the sequence the queue already reached, or
						// the worker's next request would reuse an id this run
						// recorded and the scan would skip it forever.
						writeWorkerState(task.workdir, { seq: previousSeq(state.entries, params.taskId) });
					}
					live.beat();
					return requeueOp(state, { taskId: params.taskId, route, head }, nowIso());
				});
				return {
					taskId: params.taskId,
					route,
					phase: result.task.phase,
					workdir: result.task.workdir,
					branch: result.task.branch,
					head: result.task.lastSegmentHead,
					nextRequestSeq: result.requestSeq + 1,
				};
			},
			{ snippet: "taskq_requeue - roll the worktree back in place, or cut a fresh worktree from the baseline", sequential: true },
		),
	);

	// --- close ------------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_close",
			"Close the run",
			"Close the run: every task must be retired first, every worktree removed, every branch pruned. Runs the exactly-once close audit (every recorded request produced exactly one entry; every entry triggered exactly once) and reports the counts. A close that was interrupted and re-run reports the same counts instead of failing.",
			Type.Object({}),
			async (_params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				if (state.closed) {
					// The close already committed; the replay reports the counts
					// instead of failing on a closed run (I13).
					return { closed: true, counts: integrityCounts(state) };
				}
				// The sweep and the close record are one locked derive: a fork
				// that crashed between cutting a worktree and registering it
				// cannot leave a cut between the sweep and the record and
				// survive a clean close.
				const counts = await runTool(ctx, undefined, (s) => {
					const leftovers = Object.values(s.tasks).filter((t) => !isPruned(run.mainRoot, { branch: t.branch, path: t.workdir, baseline: t.baseline }));
					if (leftovers.length > 0) {
						throw new TaskQueueError(
							"close-gate",
							`${leftovers.length} task(s) still have a worktree or branch: ${leftovers.map((t) => t.taskId).join(", ")}; bring them back first`,
						);
					}
					// Sweep unregistered leftovers (I10): a fork interrupted between
					// cutting the worktree and registering the task must not survive
					// a clean close. Worktrees and branches that existed when the run
					// opened belong to the repository, not to this run, and are not
					// leftovers.
					if (s.baselineWorktrees !== undefined && s.baselineBranches !== undefined) {
						const ownedWorktrees = new Set(Object.values(s.tasks).map((t) => path.resolve(t.workdir)));
						const openedWorktrees = new Set(s.baselineWorktrees.map((p) => path.resolve(p)));
						const strayWorktrees = listWorktrees(run.mainRoot).filter((p) => {
							const resolved = path.resolve(p);
							return resolved !== path.resolve(run.mainRoot) && !ownedWorktrees.has(resolved) && !openedWorktrees.has(resolved);
						});
						const ownedBranches = new Set(Object.values(s.tasks).map((t) => t.branch));
						const openedBranches = new Set(s.baselineBranches);
						const current = currentBranch(run.mainRoot);
						const strayBranches = listBranches(run.mainRoot).filter((b) => b !== current && !ownedBranches.has(b) && !openedBranches.has(b));
						if (strayWorktrees.length > 0 || strayBranches.length > 0) {
							throw new TaskQueueError(
								"close-gate",
								`close refuses ${strayWorktrees.length} unregistered worktree(s) and ${strayBranches.length} unregistered branch(es) not owned by any task: ${strayWorktrees.join(", ")} / ${strayBranches.join(", ")}. Remove the leftovers of an aborted fork before closing`,
							);
						}
					}
					const unclosed = Object.values(s.tasks).filter((t) => !canClose(t));
					if (unclosed.length > 0) {
						throw new TaskQueueError(
							"close-gate",
							`cannot close with ${unclosed.length} task(s) not retired: ${unclosed.map((t) => t.taskId).join(", ")}`,
						);
					}
					return closeOp(s, nowIso());
				});
				return { closed: true, counts: counts.counts };
			},
			{ snippet: "taskq_close - close the run after every task is retired", sequential: true },
		),
	);

	// --- status -----------------------------------------------------------

	pi.registerTool(
		define(
			"taskq_status",
			"Queue status",
			"Snapshot of the run: the tasks with their phases, each task's verification record, its proposal, and the file set its bring-back wrote; every queue entry with its state; the pending entries; the break point the operator holds, with the whole held join-unit; and the integrity counts. Read the task ids from here to name a pool join. One primary writes one state directory.",
			Type.Object({}),
			async (_params, ctx) => {
				const run = openRun(ctx);
				const state = run.current();
				// The hold is what the join would report, so an observer and the
				// driver read the queue the same way.
				const scan = scanReady(state);
				const hold = heldBreakPoint({ stateDir: run.stateDir }, state, scan);
				return {
					closed: state.closed,
					stateDir: state.stateDir,
					worktreeRoot: worktreeRootOf(run.mainRoot, run.stateDir),
					counts: integrityCounts(state),
					tasks: Object.values(state.tasks).map((t) => ({
						taskId: t.taskId,
						workerId: t.workerId,
						workdir: t.workdir,
						branch: t.branch,
						baseline: t.baseline,
						phase: t.phase,
						workerDone: t.workerDone,
						lastSegmentHead: t.lastSegmentHead,
						verification: t.verification ?? undefined,
						bringBack: t.bringBack ?? undefined,
						proposalPaths: t.proposal?.paths ?? undefined,
					})),
					hold: hold ?? undefined,
					holdTasks: heldUnit(state, scan),
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
			"Worker-side: request a break point from your own worktree. status \"running\" pauses for the operator; status \"done\" is the terminal break point, after which the primary runs the termination audit. Commit your segment before requesting; the request document is written once and never overwritten.",
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
