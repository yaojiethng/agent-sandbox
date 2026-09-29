/**
 * The fork and retirement mechanics against a real git repository (I6 and
 * I10 evidence): worktrees and branches are cut from one baseline, worker
 * commits never touch the main tree, and retirement removes both.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import {
	addWorktree,
	assertPrunable,
	git,
	gitRoot,
	isPruned,
	listBranches,
	listWorktrees,
	pruneWorktree,
	resolveRev,
	segmentInfo,
	statusPorcelain,
	strayPaths,
	worktreeHead,
} from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { commitAll, gitInit, makeMainRepo, rmrf, tmpdir, writeFile } from "./helpers.ts";

describe("fork", () => {
	it("cuts one worktree and branch per task from one baseline commit", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt1 = path.join(dir, "wt-t1");
			const wt2 = path.join(dir, "wt-t2");
			addWorktree(root, { branch: "exp/t1", path: wt1, baseline });
			addWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			assert.ok(listWorktrees(root).includes(wt1));
			assert.ok(listWorktrees(root).includes(wt2));
			assert.ok(listBranches(root).includes("exp/t1"));
			assert.ok(listBranches(root).includes("exp/t2"));
			assert.equal(worktreeHead(wt1), baseline);
			assert.equal(worktreeHead(wt2), baseline);
		} finally {
			rmrf(dir);
		}
	});

	it("resolves HEAD as the baseline when none is given", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			assert.equal(resolveRev(root), baseline);
			const other = commitAll(root, "second");
			assert.equal(resolveRev(root, "HEAD"), other);
		} finally {
			rmrf(dir);
		}
	});

	it("resolves the top level of any checkout, main tree or worktree", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			// The primary resolves the queue's main root from its own cwd; a
			// linked worktree's top level is the worktree itself.
			assert.equal(gitRoot(root), root);
			assert.equal(gitRoot(wt), wt);
		} finally {
			rmrf(dir);
		}
	});
});

describe("single writer (I6)", () => {
	it("worker commits never land in the main tree", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			// The worker works only in its own worktree.
			writeFile(wt, "src/change.txt", "worker change\n");
			writeFile(wt, "new.txt", "new file\n");
			commitAll(wt, "segment 1");
			commitAll(wt, "segment 2");
			// The main tree is untouched: no status entries, HEAD still the baseline.
			assert.equal(statusPorcelain(root), "");
			assert.equal(gitRoot(root), root);
			assert.equal(git(["rev-parse", "HEAD"], { cwd: root }).stdout.trim(), baseline);
			assert.equal(fs.existsSync(path.join(root, "src", "change.txt")), false);
		} finally {
			rmrf(dir);
		}
	});

	it("segment info reports exactly what the worker changed since the last break point", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			writeFile(wt, "a.txt", "one\n");
			const h1 = commitAll(wt, "seg1");
			writeFile(wt, "a.txt", "one\ntwo\n");
			writeFile(wt, "b.txt", "b\n");
			const h2 = commitAll(wt, "seg2");
			const seg1 = segmentInfo(wt, baseline, h1);
			assert.deepEqual(seg1.changed, ["a.txt"]);
			const seg2 = segmentInfo(wt, h1, h2);
			assert.deepEqual(seg2.changed, ["a.txt", "b.txt"]);
		} finally {
			rmrf(dir);
		}
	});
});

describe("retire (I10)", () => {
	it("removes the worktree and prunes the branch of a decided task", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			writeFile(wt, "work.txt", "committed\n");
			commitAll(wt, "work");
			// Only taskq protocol files may remain uncommitted.
			writeFile(wt, "taskq/requests/t1-1.json", "{}");
			pruneWorktree(root, { branch: "exp/t1", path: wt, baseline });
			assert.equal(fs.existsSync(wt), false);
			assert.ok(!listBranches(root).includes("exp/t1"));
			assert.ok(isPruned(root, { branch: "exp/t1", path: wt, baseline }));
		} finally {
			rmrf(dir);
		}
	});

	it("refuses to force-remove a worktree holding non-protocol uncommitted files", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			writeFile(wt, "precious.txt", "uncommitted deliverable\n");
			assert.throws(() => pruneWorktree(root, { branch: "exp/t1", path: wt, baseline }), (e) => e instanceof TaskQueueError && e.code === "prune-failed");
			assert.equal(fs.existsSync(wt), true);
			assert.ok(listBranches(root).includes("exp/t1"));
		} finally {
			rmrf(dir);
		}
	});

	it("asks the prune's refusal without removing anything", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const spec = { branch: "exp/t1", path: path.join(dir, "wt-t1"), baseline };
			addWorktree(root, spec);
			// The worker's own protocol files are bookkeeping, not content.
			writeFile(spec.path, "taskq/requests/t1-1.json", "{}");
			assert.deepEqual(strayPaths(spec), []);
			assertPrunable(spec);
			// A deliverable the worker never committed is the refusal, and
			// asking leaves the worktree and the branch in place.
			writeFile(spec.path, "precious.txt", "uncommitted deliverable\n");
			assert.deepEqual(strayPaths(spec), ["precious.txt"]);
			assert.throws(() => assertPrunable(spec), (e) => e instanceof TaskQueueError && e.code === "prune-failed" && String((e as Error).message).includes("precious.txt"));
			assert.equal(fs.existsSync(spec.path), true);
			assert.ok(listBranches(root).includes("exp/t1"));
			// The fresh re-queue route asks about a poisoned worktree it will
			// force-remove, and the forced answer is the one that proceeds.
			assertPrunable(spec, { force: true });
			// A worktree that is gone holds nothing to refuse.
			assert.deepEqual(strayPaths({ ...spec, path: path.join(dir, "gone") }), []);
			assertPrunable({ ...spec, path: path.join(dir, "gone") });
		} finally {
			rmrf(dir);
		}
	});

	it("a partial removal retries cleanly: prunes the branch of a gone worktree", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			writeFile(wt, "taskq/requests/t1-1.json", "{}");
			pruneWorktree(root, { branch: "exp/t1", path: wt, baseline });
			assert.equal(fs.existsSync(wt), false);
			assert.ok(!listBranches(root).includes("exp/t1"));
			assert.ok(isPruned(root, { branch: "exp/t1", path: wt, baseline }));
			// The retry of the same prune completes as a no-op.
			pruneWorktree(root, { branch: "exp/t1", path: wt, baseline });
			assert.ok(isPruned(root, { branch: "exp/t1", path: wt, baseline }));
		} finally {
			rmrf(dir);
		}
	});

	it("a re-run prunes the branch when only the worktree directory is gone", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			// Partial removal: the directory disappears but the registry entry
			// and the branch survive (an interrupted prune or operator cleanup).
			rmrf(wt);
			assert.ok(listWorktrees(root).includes(wt));
			assert.ok(listBranches(root).includes("exp/t1"));
			pruneWorktree(root, { branch: "exp/t1", path: wt, baseline });
			assert.ok(isPruned(root, { branch: "exp/t1", path: wt, baseline }));
		} finally {
			rmrf(dir);
		}
	});

	it("a closed run leaves no registered worktree and no branch (I10)", () => {
		const dir = tmpdir();
		try {
			const { root, baseline } = makeMainRepo(dir);
			const wt = path.join(dir, "wt-t1");
			addWorktree(root, { branch: "exp/t1", path: wt, baseline });
			commitAll(wt, "work");
			pruneWorktree(root, { branch: "exp/t1", path: wt, baseline });
			const wt2 = path.join(dir, "wt-t2");
			addWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			commitAll(wt2, "work");
			pruneWorktree(root, { branch: "exp/t2", path: wt2, baseline });
			// The registry holds only the main tree; no worker branch survives.
			assert.deepEqual(listWorktrees(root).map((p) => path.resolve(p)), [path.resolve(root)]);
			assert.deepEqual(listBranches(root), ["main"]);
		} finally {
			rmrf(dir);
		}
	});
});

describe("miscellaneous", () => {
	it("gitInit produces a repo usable by every helper", () => {
		const dir = tmpdir();
		try {
			const repo = path.join(dir, "r");
			fs.mkdirSync(repo);
			gitInit(repo);
			assert.equal(statusPorcelain(repo), "");
			writeFile(repo, "x.txt", "x");
			commitAll(repo, "x");
			assert.equal(statusPorcelain(repo), "");
		} finally {
			rmrf(dir);
		}
	});
});