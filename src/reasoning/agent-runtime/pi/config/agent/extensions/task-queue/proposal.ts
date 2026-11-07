/**
 * The write-back proposal: the distilled, presentable shape of a worker's
 * track. The proposal is the unit the operator judges at the final break
 * point. The primary distills it further by excluding paths; the protocol
 * directory of the worker's worktree is always excluded.
 */

import { TaskQueueError } from "./errors.ts";
import { git } from "./worktree.ts";
import { PROTOCOL_DIR } from "./protocol.ts";

const PROTOCOL_PREFIXES = [`${PROTOCOL_DIR}/`, ".taskq/"];

export function isProtocolPath(p: string): boolean {
	return PROTOCOL_PREFIXES.some((prefix) => p.startsWith(prefix));
}

/**
 * The changed paths of a worker branch against the baseline, excluding the
 * worker's protocol files and any path the primary excluded. Renames count
 * once, under the destination name.
 */
export function proposalPaths(root: string, baseline: string, branch: string, exclude: readonly string[] = []): string[] {
	const res = git(["diff", "--name-status", "-M", `${baseline}..${branch}`], { cwd: root });
	if (res.status !== 0) {
		throw new TaskQueueError("git", `cannot diff ${baseline}..${branch}: ${res.stderr.trim()}`);
	}
	const excluded = new Set(exclude);
	const paths: string[] = [];
	for (const line of res.stdout.split("\n")) {
		const parts = line.split("\t");
		if (parts.length < 2) continue;
		const status = parts[0];
		let p: string;
		if (status.startsWith("R")) {
			p = parts[2];
		} else {
			p = parts[1];
		}
		if (isProtocolPath(p) || excluded.has(p)) continue;
		if (!paths.includes(p)) paths.push(p);
	}
	return paths;
}