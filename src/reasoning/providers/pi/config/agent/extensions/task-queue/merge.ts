/**
 * The bring-back merge: applies exactly the operator's verdict over the
 * write-back proposal - all, partial, or none - and nothing else. This is
 * the single path by which worker content lands in the main tree (I6), and
 * its scope discipline is the write-back scope discipline (I7).
 *
 * The main tree must be clean on the paths a verdict touches before the
 * merge applies: a dirty target path would mix worker content with the
 * primary's own edits of the same file (I6/I7). Dirtiness elsewhere - the
 * accumulated result of an earlier verdict, a primary edit of an unrelated
 * file - does not block: consecutive verdicts land in the working tree
 * over exactly what the earlier verdicts brought back. The apply is
 * atomic: `git apply` fails without touching the tree, so a rejected merge
 * leaves the main tree untouched.
 *
 * The apply is idempotent: a verdict interrupted between the apply and the
 * state record leaves its changes in the working tree with no journal
 * evidence. The retry must recognize the already-applied verdict instead of
 * refusing to re-apply it; `git apply --reverse --check` succeeds exactly
 * when the working tree already carries the patch result.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "./errors.ts";
import type { Proposal, Verdict } from "./tasks.ts";
import { archiveDiff } from "./record.ts";
import { git } from "./worktree.ts";

export interface ApplyResult {
	/** The paths this merge brought into the main tree. */
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
 * Apply the verdict over the proposal into the main tree. The verdict must
 * already have passed validation; this module re-checks the subset rule so
 * the scope discipline holds at the point of write-back.
 */
export function applyVerdict(
	root: string,
	params: { baseline: string; branch: string; proposal: Proposal; verdict: Verdict },
): ApplyResult {
	const { baseline, branch, proposal, verdict } = params;
	if (verdict.scope === "none") {
		return { applied: [], archived: false };
	}
	let paths: string[];
	if (verdict.scope === "all") {
		paths = proposal.paths;
	} else {
		for (const p of verdict.paths) {
			if (!proposal.paths.includes(p)) {
				throw new TaskQueueError(
					"verdict-invalid",
					`a partial verdict names ${p}, which the proposal does not contain`,
				);
			}
		}
		paths = verdict.paths;
	}
	if (paths.length === 0) {
		return { applied: [], archived: false };
	}
	const diff = diffContent(root, baseline, branch, paths);
	if (diff.trim() === "") {
		// The proposal named paths with no actual delta; nothing to bring back.
		return { applied: [], archived: false };
	}
	const reverse = git(["apply", "--reverse", "--check", "--whitespace=nowarn", "-"], { cwd: root, input: diff });
	if (reverse.status === 0) {
		// The verdict's changes are already in the working tree: an earlier
		// attempt applied them and crashed before recording. Treat the
		// already-applied verdict as applied so the retry completes.
		return { applied: paths, archived: false };
	}
	const dirty = dirtyPaths(root);
	const hit = paths.filter((p) => dirty.has(p));
	if (hit.length > 0) {
		throw new TaskQueueError(
			"merge-dirty-main",
			`the main tree is dirty on ${hit.join(", ")}; refusing to merge over content this verdict touches`,
		);
	}
	const res = git(["apply", "--whitespace=nowarn", "-"], { cwd: root, input: diff });
	if (res.status !== 0) {
		throw new TaskQueueError(
			"merge-apply-failed",
			`the verdict ${verdict.scope} did not apply cleanly: ${res.stderr.trim()}. The main tree is unchanged; resolve the conflict at the proposal level`,
		);
	}
	return { applied: paths, archived: false };
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

/** Park a discarded track: archive its full branch diff into the run record. */
export function archiveDiscardedTrack(stateDir: string, taskId: string, root: string, baseline: string, branch: string): void {
	const diff = diffContent(root, baseline, branch);
	archiveDiff(stateDir, taskId, diff);
	fs.writeFileSync(
		path.join(stateDir, "archive", `${taskId}.note`),
		`verdict: none\nbranch: ${branch}\nbaseline: ${baseline}\n`,
		"utf8",
	);
}