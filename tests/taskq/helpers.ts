/**
 * Test helpers: throwaway git repositories, worker-side request simulation,
 * and small assertion conveniences. Every test uses a temp directory and
 * removes it afterwards, so the suite leaves no trace in the worktree.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import { git } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { nextRequestId, writeWorkerRequest, type WorkerStatus } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/protocol.ts";

export const NOW = "2026-01-01T00:00:00.000Z";

export function tmpdir(prefix = "taskq-test-"): string {
	return fs.mkdtempSync(path.join(os.tmpdir(), prefix));
}

export function rmrf(dir: string): void {
	fs.rmSync(dir, { recursive: true, force: true });
}

export function withTmp<T>(fn: (dir: string) => T): T {
	const dir = tmpdir();
	try {
		return fn(dir);
	} finally {
		rmrf(dir);
	}
}

/** Initialize a git repository with a committed baseline. */
export function gitInit(root: string): void {
	git(["init", "-q", "-b", "main"], { cwd: root });
	git(["config", "user.email", "tq-test@example.com"], { cwd: root });
	git(["config", "user.name", "tq-test"], { cwd: root });
}

export function writeFile(root: string, rel: string, content: string): void {
	const p = path.join(root, rel);
	fs.mkdirSync(path.dirname(p), { recursive: true });
	fs.writeFileSync(p, content, "utf8");
}

export function readFile(root: string, rel: string): string {
	return fs.readFileSync(path.join(root, rel), "utf8");
}

/** Commit everything and return the new HEAD. */
export function commitAll(root: string, msg: string): string {
	git(["add", "-A"], { cwd: root });
	git(["commit", "-q", "-m", msg], { cwd: root });
	return git(["rev-parse", "HEAD"], { cwd: root }).stdout.trim();
}

/** A main repository plus a basline commit. */
export interface MainRepo {
	root: string;
	baseline: string;
}

export function makeMainRepo(parent: string): MainRepo {
	const root = path.join(parent, "main");
	fs.mkdirSync(root);
	gitInit(root);
	writeFile(root, "README.md", "main\n");
	const baseline = commitAll(root, "baseline");
	return { root, baseline };
}

/** Simulate the worker's break-point request in its own worktree. */
export function workerRequest(workdir: string, taskId: string, status: WorkerStatus, message: string): string {
	const requestId = nextRequestId(workdir, taskId);
	return writeWorkerRequest(workdir, { taskId, requestId, status, message, at: NOW });
}