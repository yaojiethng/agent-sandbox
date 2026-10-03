/**
 * The bring-back's main-tree write. The bring-back is the operation; the
 * merge is the write it performs, and this module is that write. It
 * applies exactly the file set the primary named - a subset of the
 * proposal, possibly empty - and nothing else. This is the single path by
 * which worker content lands in the main tree (I6), and its scope
 * discipline is the write-back scope discipline (I7).
 *
 * The main tree must be clean on the paths the file set names before the
 * write applies: a dirty target path would mix worker content with the
 * primary's own edits of the same file (I6/I7). Dirtiness elsewhere - the
 * accumulated result of an earlier bring-back, a primary edit of an
 * unrelated file - does not block: consecutive file sets land in the
 * working tree over exactly what the earlier ones wrote. The write is
 * atomic: `git apply` fails without touching the tree, so a rejected
 * bring-back leaves the main tree untouched.
 *
 * The write is idempotent: a bring-back interrupted between the write and
 * the state record leaves its changes in the working tree with no journal
 * evidence. The retry must recognize the already-applied file set instead
 * of refusing to re-apply it; `git apply --reverse --check` succeeds
 * exactly when the working tree already carries the patch result.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import { assertFileSet, type Proposal } from "./tasks.ts";
import { archiveDiff } from "./record.ts";
import { git } from "./worktree.ts";

export interface ApplyResult {
	/** The paths this bring-back wrote into the main tree. */
	applied: string[];
	/** True when the worker branch diff was archived into the run record. */
	archived: boolean;
}

export function diffContent(root: string, baseline: string, branch: string, paths?: readonly string[]): string {
	const args = ["diff", `${baseline}..${branch}`];
	if (paths && paths.length > 0) args.push("--", ...paths);
	const res = git(args, { cwd: root });
	if (res.status !== 0) {
		throw new TaskQueueError("git", `cannot diff ${baseline}..${branch}: ${res.stderr.trim()}`);
	}
	return res.stdout;
}

/**
 * Write the file set into the main tree. The set must already have passed
 * validation; this module re-checks the subset rule so the scope
 * discipline holds at the point of write-back. The empty set writes
 * nothing and is not an error: the primary may decide to bring back
 * nothing at all.
 */
export function applyBringBack(
	root: string,
	params: { baseline: string; branch: string; proposal: Proposal; paths: readonly string[] },
): ApplyResult {
	const { baseline, branch, proposal, paths } = params;
	if (paths.length === 0) {
		return { applied: [], archived: false };
	}
	try {
		assertFileSet(paths, proposal);
	} catch (err) {
		throw new TaskQueueError("file-set-invalid", String(err instanceof Error ? err.message : err));
	}
	const diff = diffContent(root, baseline, branch, paths);
	if (diff.trim() === "") {
		// The file set named paths with no actual delta; nothing to write.
		return { applied: [], archived: false };
	}
	const reverse = git(["apply", "--reverse", "--check", "--whitespace=nowarn", "-"], { cwd: root, input: diff });
	if (reverse.status === 0) {
		// The file set is already in the working tree: an earlier attempt
		// wrote it and crashed before recording. Treat the already-written
		// set as applied so the retry completes.
		return { applied: [...paths], archived: false };
	}
	const dirty = dirtyPaths(root);
	const hit = paths.filter((p) => dirty.has(p));
	if (hit.length > 0) {
		throw new TaskQueueError(
			"merge-dirty-main",
			`the main tree is dirty on ${hit.join(", ")}; refusing to write back over content this file set names`,
		);
	}
	const res = git(["apply", "--whitespace=nowarn", "-"], { cwd: root, input: diff });
	if (res.status !== 0) {
		throw new TaskQueueError(
			"merge-apply-failed",
			`the file set did not apply cleanly: ${res.stderr.trim()}. The main tree is unchanged; resolve the conflict at the proposal level`,
		);
	}
	return { applied: [...paths], archived: false };
}

/**
 * The dirty paths of the main tree: tracked changes against HEAD plus
 * untracked files. The merge gate is scoped to these paths; `git apply`
 * itself rejects an application whose context no longer matches, so an
 * overlapping edit is caught either way.
 */
function dirtyPaths(root: string): Set<string> {
	const changed = git(["diff", "--name-only", "HEAD"], { cwd: root }).stdout.split("\n").map((s) => s.trim()).filter((s) => s !== "");
	const untracked = git(["ls-files", "--others", "--exclude-standard"], { cwd: root }).stdout.split("\n").map((s) => s.trim()).filter((s) => s !== "");
	return new Set([...changed, ...untracked]);
}

/**
 * Park a track whose bring-back wrote nothing back: archive its full
 * branch diff into the run record, so the work the primary declined to
 * write into the main tree is still readable after the worktree is gone.
 */
export function archiveTrack(stateDir: string, taskId: string, root: string, baseline: string, branch: string): void {
	const diff = diffContent(root, baseline, branch);
	archiveDiff(stateDir, taskId, diff);
	fs.writeFileSync(
		path.join(stateDir, "archive", `${taskId}.note`),
		`file set: none\nbranch: ${branch}\nbaseline: ${baseline}\n`,
		"utf8",
	);
}