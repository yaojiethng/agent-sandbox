/**
 * The fork and retirement mechanics: per-task worktrees and branches cut
 * from one baseline commit, and their removal at a clean close.
 *
 * The single-writer rule is structural here: every command in this module
 * runs either in the worker's own worktree (reads and the worker's own
 * commits) or against the worktree registry of the main repository. No
 * command writes files into the main tree. The only module that writes the
 * main tree is the merge module, and only with the verdict's scope.
 */

import { spawnSync } from "node:child_process";
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

/** Cut one worker worktree and branch from the baseline commit. */
export function addWorktree(root: string, spec: WorktreeSpec): void {
	must(["worktree", "add", "-b", spec.branch, spec.path, spec.baseline], { cwd: root, code: "git" });
}

/** The commit a branch points at. */
export function branchHead(root: string, branch: string): string {
	return must(["rev-parse", "--verify", `refs/heads/${branch}^{commit}`], { cwd: root, code: "git" }).stdout.trim();
}

/** The commit the worker's checkout is at. */
export function worktreeHead(workdir: string): string {
	return must(["rev-parse", "HEAD"], { cwd: workdir, code: "git" }).stdout.trim();
}

export interface SegmentInfo {
	stat: string;
	changed: string[];
}

/** What the worker changed since the previous break point, for the join. */
export function segmentInfo(workdir: string, from: string, to: string): SegmentInfo {
	const stat = git(["diff", "--stat", "--no-color", `${from}..${to}`], { cwd: workdir }).stdout.trim();
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
 * Remove a worker's worktree and prune its branch. Refuses when the
 * worktree holds any file outside the task-queue protocol directory: a
 * forced removal would discard worker content the primary never merged.
 *
 * The removal is idempotent: a worktree whose directory is already gone is
 * swept from the registry, and a branch that no longer exists is left
 * alone, so a re-run after a partial removal completes instead of throwing.
 */
export function pruneWorktree(root: string, spec: WorktreeSpec): void {
	const resolved = path.resolve(spec.path);
	if (listWorktrees(root).includes(resolved)) {
		if (fs.existsSync(spec.path)) {
			const status = statusPorcelain(spec.path);
			// Porcelain v1 lines carry the status in columns 0-1 and a space in
			// column 2, so the path starts at offset 3. Do not trim the line
			// first: a tracked-protocol file shows " M taskq/..." and trimming
			// eats the leading column.
			const stray = status
				.split("\n")
				.filter((s) => s !== "")
				.map((s) => s.slice(3))
				.filter((f) => !f.startsWith(`${PROTOCOL_DIR}/`));
			if (stray.length > 0) {
				throw new TaskQueueError(
					"prune-failed",
					`worktree ${spec.path} still holds ${stray.length} file(s) outside ${PROTOCOL_DIR}/: ${stray.slice(0, 5).join(", ")}; merge or park them before retiring`,
				);
			}
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