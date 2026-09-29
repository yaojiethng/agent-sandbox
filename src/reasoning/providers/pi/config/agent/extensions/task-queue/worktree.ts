/**
 * The worktree mechanics: per-task worktrees and branches cut from one
 * baseline commit, the rollback a re-queue needs, and their removal at a
 * bring-back and at a clean close.
 *
 * The single-writer rule is structural here: every command in this module
 * runs either in the worker's own worktree (reads and the worker's own
 * commits) or against the worktree registry of the main repository. No
 * command writes files into the main tree. The only module that writes the
 * main tree is the bring-back's write-back module, and only with the file
 * set the primary named.
 *
 * The worktree location is derived, not supplied. One run owns one
 * worktree root, named from the run's state directory, and one task owns
 * one worktree inside it. The caller names a task; the path follows. A
 * derived location keeps the worktrees out of the main tree (the
 * single-writer rule above), keeps two runs of the same repository off
 * each other's paths, and leaves no room for a hand-cut worktree to
 * collide with a fork.
 */

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import { PROTOCOL_DIR } from "./protocol.ts";

export interface GitResult {
	status: number;
	stdout: string;
	stderr: string;
}

export function git(args: string[], opts: { cwd?: string; input?: string } = {}): GitResult {
	const res = spawnSync("git", args, {
		cwd: opts.cwd,
		input: opts.input,
		encoding: "utf8",
		maxBuffer: 64 * 1024 * 1024,
	});
	if (res.error) {
		throw new TaskQueueError("git", `git ${args.join(" ")} failed to start: ${res.error.message}`);
	}
	return { status: res.status ?? -1, stdout: res.stdout ?? "", stderr: res.stderr ?? "" };
}

function must(args: string[], opts: { cwd?: string; input?: string; code?: string } = {}): GitResult {
	const res = git(args, opts);
	if (res.status !== 0) {
		throw new TaskQueueError(opts.code ?? "git", `git ${args.join(" ")} failed: ${res.stderr.trim()}`);
	}
	return res;
}

/** The repository root of a working directory. */
export function gitRoot(cwd: string): string {
	const res = git(["rev-parse", "--show-toplevel"], { cwd });
	if (res.status !== 0) {
		throw new TaskQueueError("not-a-git-repo", `${cwd} is not inside a git repository`);
	}
	return res.stdout.trim();
}

/** Resolve a revision; HEAD when omitted. */
export function resolveRev(cwd: string, rev?: string): string {
	return must(["rev-parse", "--verify", `${rev ?? "HEAD"}^{commit}`], { cwd }).stdout.trim();
}

export interface WorktreeSpec {
	branch: string;
	path: string;
	baseline: string;
}

/**
 * The run id: a short digest of the run's state directory. One state
 * directory serves one run of one main tree, so the digest is the run's
 * identity for the paths it owns, and two runs never share them.
 */
export function runIdOf(stateDir: string): string {
	return createHash("sha256").update(path.resolve(stateDir)).digest("hex").slice(0, 8);
}

/**
 * The root that holds every worktree of one run: a sibling of the main
 * repository, named from the repository and scoped by the run id. It
 * sits beside the repository because a worktree inside the main tree
 * would dirty the tree the merge gate reads.
 */
export function worktreeRootOf(mainRoot: string, stateDir: string): string {
	const root = path.resolve(mainRoot);
	return path.join(path.dirname(root), `.taskq-worktrees-${path.basename(root)}`, runIdOf(stateDir));
}

/**
 * The one worktree path a task owns in a run. The task id is one path
 * segment and nothing else: a `..` in a task id would walk out of the run's
 * worktree root, and two runs would then share the path it reached.
 */
export function canonicalWorkdir(mainRoot: string, stateDir: string, taskId: string): string {
	const root = worktreeRootOf(mainRoot, stateDir);
	const workdir = path.resolve(root, taskId);
	if (taskId !== path.basename(taskId) || workdir === path.resolve(root) || !workdir.startsWith(root + path.sep)) {
		throw new TaskQueueError(
			"worktree-occupied",
			`task id ${taskId} is not one worktree name under ${root}; a task id names a segment, not a path`,
		);
	}
	return workdir;
}

/**
 * Refuse a fork whose canonical location is already taken. A leftover
 * worktree, a leftover branch, or a directory on disk all fail the same
 * way and name the path: fork owns the location, so the caller clears the
 * leftover by hand and forks again (I10).
 */
export function assertWorkdirFree(root: string, spec: WorktreeSpec): void {
	const registered = listWorktrees(root).some((p) => path.resolve(p) === path.resolve(spec.path));
	const branchTaken = listBranches(root).includes(spec.branch);
	const onDisk = fs.existsSync(spec.path);
	if (!registered && !branchTaken && !onDisk) return;
	const because = [
		registered ? "a worktree is registered there" : undefined,
		branchTaken ? `the branch ${spec.branch} exists` : undefined,
		onDisk ? "the directory exists" : undefined,
	].filter((s): s is string => s !== undefined);
	throw new TaskQueueError(
		"worktree-occupied",
		`the canonical worktree ${spec.path} is taken: ${because.join(", ")}. Fork owns the location and never writes in the main tree; clear the leftover with 'git worktree remove --force ${spec.path}' and 'git branch -D ${spec.branch}', then fork again`,
	);
}

/** Cut one worker worktree and branch from the baseline commit. */
export function addWorktree(root: string, spec: WorktreeSpec): void {
	must(["worktree", "add", "-b", spec.branch, spec.path, spec.baseline], { cwd: root, code: "git" });
}

/** The commit a branch points at. */
export function branchHead(root: string, branch: string): string {
	return must(["rev-parse", "--verify", `refs/heads/${branch}^{commit}`], { cwd: root, code: "git" }).stdout.trim();
}

/**
 * The commit the worker's checkout is at.
 */
export function worktreeHead(workdir: string): string {
	return must(["rev-parse", "HEAD"], { cwd: workdir, code: "git" }).stdout.trim();
}

/**
 * Roll a worktree back to a commit the queue knows about: the in-place
 * re-queue route. Tracked files return to that commit and untracked files
 * outside the protocol directory are removed, so the next segment starts
 * from the recorded state instead of from the wreckage of the last one.
 *
 * The protocol directory is carried across the rollback: the worker's
 * request counter and its request documents are the queue's own
 * bookkeeping. `git clean` spares only untracked files, and a worker that
 * committed its own protocol directory would have it restored to the
 * target commit, so the files are read before the reset and written back
 * after it. Without this the request sequence would restart over ids the
 * run already recorded, and the next request would collide with a
 * triggered entry.
 */
export function rollbackWorktree(workdir: string, head: string): void {
	const protocol = readProtocolFiles(workdir);
	must(["reset", "--hard", head], { cwd: workdir, code: "git" });
	must(["clean", "-fdq", "-e", `/${PROTOCOL_DIR}/`], { cwd: workdir, code: "git" });
	writeProtocolFiles(workdir, protocol);
}

/** The protocol directory's files, by path relative to the worktree. */
function readProtocolFiles(workdir: string): Map<string, Buffer> {
	const files = new Map<string, Buffer>();
	const root = path.join(workdir, PROTOCOL_DIR);
	const walk = (dir: string): void => {
		for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
			const full = path.join(dir, entry.name);
			if (entry.isDirectory()) walk(full);
			else if (entry.isFile()) files.set(path.relative(workdir, full), fs.readFileSync(full));
		}
	};
	if (fs.existsSync(root)) walk(root);
	return files;
}

/**
 * Write the protocol files back, and remove any the rollback restored to
 * a state the run has already moved past.
 */
function writeProtocolFiles(workdir: string, files: Map<string, Buffer>): void {
	const restored = new Set<string>();
	for (const [rel, content] of files) {
		const full = path.join(workdir, rel);
		fs.mkdirSync(path.dirname(full), { recursive: true });
		fs.writeFileSync(full, content);
		restored.add(rel);
	}
	for (const rel of readProtocolFiles(workdir).keys()) {
		if (!restored.has(rel)) fs.rmSync(path.join(workdir, rel), { force: true });
	}
}

export interface SegmentInfo {
	stat: string;
	changed: string[];
}

/**
 * What the worker changed since the previous break point, for the join.
 * The caller may narrow the stat to the paths it judged worth reporting;
 * the changed list always names every path the segment touched.
 */
export function segmentInfo(workdir: string, from: string, to: string, paths?: readonly string[]): SegmentInfo {
	const narrow = paths && paths.length > 0 ? ["--", ...paths] : [];
	const stat = git(["diff", "--stat", "--no-color", `${from}..${to}`, ...narrow], { cwd: workdir }).stdout.trim();
	const changed = git(["diff", "--name-only", `${from}..${to}`], { cwd: workdir }).stdout
		.split("\n")
		.map((s) => s.trim())
		.filter((s) => s !== "");
	return { stat, changed };
}

/**
 * Working tree status of a directory, one porcelain line per change.
 * Note: the raw output is returned without trimming; the leading column
 * of the first line is a real status field and trimming eats it.
 */
export function statusPorcelain(cwd: string): string {
	return git(["status", "--porcelain"], { cwd }).stdout;
}

/** The repository's currently checked-out branch; empty when detached. */
export function currentBranch(root: string): string {
	return git(["branch", "--show-current"], { cwd: root }).stdout.trim();
}

/**
 * The worktree's uncommitted paths outside the protocol directory: the
 * content a prune would discard without writing it back. Porcelain v1
 * lines carry the status in columns 0-1 and a space in column 2, so the
 * path starts at offset 3. The lines are not trimmed first: a tracked
 * protocol file shows " M taskq/..." and trimming eats the leading column.
 * A worktree that is gone or not registered holds nothing.
 */
export function strayPaths(spec: WorktreeSpec): string[] {
	if (!fs.existsSync(spec.path)) return [];
	return statusPorcelain(spec.path)
		.split("\n")
		.filter((s) => s !== "")
		.map((s) => s.slice(3))
		.filter((f) => !f.startsWith(`${PROTOCOL_DIR}/`));
}

/**
 * The prune's refusal, evaluated without removing anything: the worktree
 * holds content the primary never wrote back, and a forced removal would
 * discard it. The bring-back calls this before it writes the main tree, so
 * a refused bring-back has mutated nothing at all (I7, I12). The fresh
 * re-queue route passes `force`, because abandoning a poisoned track is
 * the point of that route and the branch is packaged before it.
 */
export function assertPrunable(spec: WorktreeSpec, opts: { force?: boolean } = {}): void {
	if (opts.force === true) return;
	const stray = strayPaths(spec);
	if (stray.length === 0) return;
	throw new TaskQueueError(
		"prune-failed",
		`worktree ${spec.path} still holds ${stray.length} file(s) outside ${PROTOCOL_DIR}/: ${stray.slice(0, 5).join(", ")}; write them back or park them before removing the worktree`,
	);
}

/**
 * Remove a worker's worktree and prune its branch. Refuses when the
 * worktree holds any file outside the task-queue protocol directory: a
 * forced removal would discard worker content the primary never wrote
 * back. The refusal is `assertPrunable`, so a caller that must know before
 * it writes anything can ask the same question first.
 *
 * The removal is idempotent: a worktree whose directory is already gone is
 * swept from the registry, and a branch that no longer exists is left
 * alone, so a re-run after a partial removal completes instead of throwing.
 */
export function pruneWorktree(root: string, spec: WorktreeSpec, opts: { force?: boolean } = {}): void {
	const resolved = path.resolve(spec.path);
	if (listWorktrees(root).includes(resolved)) {
		if (fs.existsSync(spec.path)) {
			assertPrunable(spec, opts);
			must(["worktree", "remove", "--force", spec.path], { cwd: root, code: "prune-failed" });
		} else {
			// The directory is gone but the registry still lists the entry (a
			// partial removal or operator cleanup); sweep the stale entry.
			must(["worktree", "prune"], { cwd: root, code: "prune-failed" });
			if (listWorktrees(root).includes(resolved)) {
				throw new TaskQueueError("prune-failed", `worktree ${spec.path} is still registered`);
			}
		}
	}
	if (listBranches(root).includes(spec.branch)) {
		must(["branch", "-D", spec.branch], { cwd: root, code: "prune-failed" });
	}
}

/** All registered worktree paths of the repository. */
export function listWorktrees(root: string): string[] {
	return git(["worktree", "list", "--porcelain"], { cwd: root })
		.stdout.split("\n")
		.filter((l) => l.startsWith("worktree "))
		.map((l) => l.slice("worktree ".length).trim());
}

/** All local branch names of the repository. */
export function listBranches(root: string): string[] {
	return git(["for-each-ref", "--format=%(refname:short)", "refs/heads"], { cwd: root })
		.stdout.split("\n")
		.map((s) => s.trim())
		.filter((s) => s !== "");
}

/** True when the worktree and the branch no longer exist. */
export function isPruned(root: string, spec: WorktreeSpec): boolean {
	return !listWorktrees(root).includes(path.resolve(spec.path)) && !listBranches(root).includes(spec.branch);
}