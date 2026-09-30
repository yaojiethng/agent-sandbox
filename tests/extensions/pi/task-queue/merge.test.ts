/**
 * The write-back proposal and the file-set bring-back against a real git
 * repository: what the bring-back writes into the main tree is exactly the
 * file set (I7), nothing lands before the bring-back (I6), and the main
 * tree must be clean on the paths the file set names.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { assertFileSet } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/tasks.ts";
import { addWorktree, statusPorcelain } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyBringBack, archiveTrack } from "../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
import { commitAll, makeMainRepo, rmrf, tmpdir, writeFile } from "./helpers.ts";

const AT = "2026-01-01T00:00:00.000Z";

interface Fixture {
	dir: string;
	root: string;
	baseline: string;
	wt: string;
	branch: string;
}

function makeFixture(workerCommits: (wt: string) => void): Fixture {
	const dir = tmpdir();
	const { root, baseline } = makeMainRepo(dir);
	const wt = path.join(dir, "wt-t1");
	const branch = "exp/t1";
	addWorktree(root, { branch, path: wt, baseline });
	workerCommits(wt);
	writeFile(wt, "taskq/requests/t1-1.json", "{}"); // protocol file, never offered
	return { dir, root, baseline, wt, branch };
}

function cleanup(f: Fixture): void {
	rmrf(f.dir);
}

function proposalFor(f: Fixture, exclude: string[] = []): ReturnType<typeof proposalPaths> {
	return proposalPaths(f.root, f.baseline, f.branch, exclude);
}

describe("proposalPaths", () => {
	it("lists adds, modifications, and deletions, in proposal order", () => {
		const f = makeFixture((wt) => {
			writeFile(wt, "mod.txt", "v2\n");
			writeFile(wt, "add.txt", "new\n");
			fs.rmSync(path.join(wt, "README.md"));
			commitAll(wt, "seg");
		});
		try {
			const paths = proposalFor(f);
			assert.ok(paths.includes("mod.txt"));
			assert.ok(paths.includes("add.txt"));
			assert.ok(paths.includes("README.md"));
			assert.ok(!paths.includes("taskq/requests/t1-1.json"), "protocol files never join a proposal");
			assert.ok(!paths.some((p) => p.startsWith("taskq/")), "no protocol path in the proposal");
		} finally {
			cleanup(f);
		}
	});

	it("counts a rename once, under the destination name", () => {
		const f = makeFixture((wt) => {
			fs.renameSync(path.join(wt, "README.md"), path.join(wt, "RENAMED.md"));
			commitAll(wt, "rename");
		});
		try {
			const paths = proposalFor(f);
			assert.ok(paths.includes("RENAMED.md"));
			assert.ok(!paths.includes("README.md"));
		} finally {
			cleanup(f);
		}
	});

	it("honors the primary's exclude list", () => {
		const f = makeFixture((wt) => {
			writeFile(wt, "keep.txt", "k\n");
			writeFile(wt, "scratch.txt", "s\n");
			commitAll(wt, "seg");
		});
		try {
			assert.deepEqual(proposalFor(f, ["scratch.txt"]), ["keep.txt"]);
		} finally {
			cleanup(f);
		}
	});
});

describe("assertFileSet", () => {
	it("accepts a subset of the proposal, the whole proposal, and the empty set", () => {
		const proposal = { paths: ["a.txt", "b.txt"], description: "", at: AT };
		assert.doesNotThrow(() => assertFileSet(["a.txt"], proposal));
		assert.doesNotThrow(() => assertFileSet(["a.txt", "b.txt"], proposal));
		assert.doesNotThrow(() => assertFileSet([], proposal));
	});

	it("refuses a path the proposal does not name, and names it", () => {
		const proposal = { paths: ["a.txt"], description: "", at: AT };
		assert.throws(() => assertFileSet(["a.txt", "z.txt"], proposal), (e) => e instanceof Error && e.message.includes("z.txt"));
	});

	it("refuses a duplicate path, so the file set is a set", () => {
		const proposal = { paths: ["a.txt"], description: "", at: AT };
		assert.throws(() => assertFileSet(["a.txt", "a.txt"], proposal), (e) => e instanceof Error && e.message.includes("twice"));
	});
});

describe("applyBringBack", () => {
	function baseFixture(): Fixture {
		return makeFixture((wt) => {
			writeFile(wt, "a.txt", "a2\n");
			writeFile(wt, "b.txt", "b2\n");
			writeFile(wt, "c.txt", "c2\n");
			fs.rmSync(path.join(wt, "README.md"));
			commitAll(wt, "seg");
		});
	}

	it("the whole proposal writes exactly the proposal paths and nothing else (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "all of it", at: AT };
			const res = applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			assert.deepEqual(res.applied, proposal.paths);
			// Main tree now shows exactly the proposed changes.
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, [...proposal.paths].sort());
		} finally {
			cleanup(f);
		}
	});

	it("a named subset writes exactly that subset (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyBringBack(root, { baseline, branch, proposal, paths: ["b.txt", "c.txt"] });
			assert.deepEqual(res.applied, ["b.txt", "c.txt"]);
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, ["b.txt", "c.txt"].sort());
		} finally {
			cleanup(f);
		}
	});

	it("refuses a path outside the proposal even at the apply boundary (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f).filter((p) => p !== "a.txt"), description: "", at: AT };
			assert.throws(
				() => applyBringBack(root, { baseline, branch, proposal, paths: ["a.txt"] }),
				(e) => e instanceof TaskQueueError && e.code === "file-set-invalid",
			);
			assert.equal(statusPorcelain(root), "", "a rejected bring-back leaves the main tree untouched");
		} finally {
			cleanup(f);
		}
	});

	it("the empty file set writes nothing (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyBringBack(root, { baseline, branch, proposal, paths: [] });
			assert.deepEqual(res.applied, []);
			assert.equal(statusPorcelain(root), "");
		} finally {
			cleanup(f);
		}
	});

	it("refuses when a path the file set names is dirty (single-writer rule)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			// The primary is mid-edit of a file the file set brings back.
			writeFile(root, "a.txt", "primary edit over a file-set path\n");
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			assert.throws(
				() => applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
			assert.equal(fs.readFileSync(path.join(root, "a.txt"), "utf8"), "primary edit over a file-set path\n", "no worker content landed");
		} finally {
			cleanup(f);
		}
	});

	it("applies over an unrelated dirty path (consecutive file sets accumulate)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			// The main tree stays dirty from the primary's own edit and from
			// earlier bring-backs; only the paths this file set names are gated.
			writeFile(root, "primary-edit.txt", "the primary is mid-edit\n");
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			assert.deepEqual(res.applied, proposal.paths);
			assert.equal(fs.readFileSync(path.join(root, "a.txt"), "utf8"), "a2\n");
			assert.equal(fs.readFileSync(path.join(root, "primary-edit.txt"), "utf8"), "the primary is mid-edit\n", "unrelated primary content survives");
		} finally {
			cleanup(f);
		}
	});

	it("applies deletions too", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			assert.equal(fs.existsSync(path.join(root, "README.md")), false);
		} finally {
			cleanup(f);
		}
	});

	it("treats an already-applied file set as applied (crash-window retry)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			// First attempt: the apply lands, the state record never does.
			const first = applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			assert.deepEqual(first.applied, proposal.paths);
			// The retry must not refuse the already-written file set: it
			// reports the same applied set, so the bring-back can record and
			// the run can still close.
			const retry = applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			assert.deepEqual(retry.applied, proposal.paths);
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, [...proposal.paths].sort());
		} finally {
			cleanup(f);
		}
	});

	it("an already-written file set still refuses once its patch no longer matches", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths });
			// The primary edits one written file: the reverse check fails, and
			// the dirty tree refuses the bring-back instead of clobbering the
			// edit.
			writeFile(root, "a.txt", "primary edit over worker content\n");
			assert.throws(
				() => applyBringBack(root, { baseline, branch, proposal, paths: proposal.paths }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
		} finally {
			cleanup(f);
		}
	});
});

describe("archiveTrack", () => {
	it("parks the full branch diff for a track the bring-back wrote nothing from", () => {
		const f = makeFixture((wt) => {
			writeFile(wt, "parked.txt", "p\n");
			commitAll(wt, "seg");
		});
		try {
			const stateDir = path.join(f.dir, "state");
			archiveTrack(stateDir, "t1", f.root, f.baseline, f.branch);
			const diff = fs.readFileSync(path.join(stateDir, "archive", "t1.diff"), "utf8");
			assert.ok(diff.includes("parked.txt"));
			assert.ok(fs.existsSync(path.join(stateDir, "archive", "t1.note")));
		} finally {
			cleanup(f);
		}
	});
});
