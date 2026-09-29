/**
 * The write-back proposal and the verdict-scoped merge against a real git
 * repository: what the merge brings into the main tree is exactly the
 * verdict (I7), nothing lands before the merge (I6), and the main tree
 * must be clean when a merge applies.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TaskQueueError } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/errors.ts";
import { addWorktree, statusPorcelain } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/worktree.ts";
import { proposalPaths } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/proposal.ts";
import { applyVerdict, archiveDiscardedTrack } from "../../src/reasoning/providers/pi/config/agent/extensions/task-queue/merge.ts";
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

describe("applyVerdict", () => {
	function baseFixture(): Fixture {
		return makeFixture((wt) => {
			writeFile(wt, "a.txt", "a2\n");
			writeFile(wt, "b.txt", "b2\n");
			writeFile(wt, "c.txt", "c2\n");
			fs.rmSync(path.join(wt, "README.md"));
			commitAll(wt, "seg");
		});
	}

	it("scope all brings back exactly the proposal paths and nothing else (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "all of it", at: AT };
			const res = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
			assert.deepEqual(res.applied, proposal.paths);
			// Main tree now shows exactly the proposed changes.
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, [...proposal.paths].sort());
		} finally {
			cleanup(f);
		}
	});

	it("scope partial brings back exactly the named subset (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "partial", paths: ["b.txt", "c.txt"] } });
			assert.deepEqual(res.applied, ["b.txt", "c.txt"]);
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, ["b.txt", "c.txt"].sort());
		} finally {
			cleanup(f);
		}
	});

	it("scope partial refuses a path outside the proposal even at the apply boundary (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f).filter((p) => p !== "a.txt"), description: "", at: AT };
			assert.throws(
				() => applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "partial", paths: ["a.txt"] } }),
				(e) => e instanceof TaskQueueError && e.code === "verdict-invalid",
			);
			assert.equal(statusPorcelain(root), "", "a rejected merge leaves the main tree untouched");
		} finally {
			cleanup(f);
		}
	});

	it("scope none brings back nothing (I7)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "none" } });
			assert.deepEqual(res.applied, []);
			assert.equal(statusPorcelain(root), "");
		} finally {
			cleanup(f);
		}
	});

	it("refuses when a path the verdict touches is dirty (single-writer rule)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			// The primary is mid-edit of a file the verdict brings back.
			writeFile(root, "a.txt", "primary edit over a verdict path\n");
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			assert.throws(
				() => applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
			assert.equal(fs.readFileSync(path.join(root, "a.txt"), "utf8"), "primary edit over a verdict path\n", "no worker content landed");
		} finally {
			cleanup(f);
		}
	});

	it("applies over an unrelated dirty path (consecutive verdicts accumulate)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			// The main tree stays dirty from the primary's own edit and from
			// earlier verdicts; only the paths this verdict touches are gated.
			writeFile(root, "primary-edit.txt", "the primary is mid-edit\n");
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			const res = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
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
			applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
			assert.equal(fs.existsSync(path.join(root, "README.md")), false);
		} finally {
			cleanup(f);
		}
	});

	it("treats an already-applied verdict as applied (crash-window retry)", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			// First attempt: the apply lands, the state record never does.
			const first = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
			assert.deepEqual(first.applied, proposal.paths);
			// The retry must not refuse the already-applied patch: it reports
			// the same applied set, so the merge tool can record and the run
			// can still close.
			const retry = applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
			assert.deepEqual(retry.applied, proposal.paths);
			const status = statusPorcelain(root).split("\n").filter(Boolean).map((l) => l.slice(3)).sort();
			assert.deepEqual(status, [...proposal.paths].sort());
		} finally {
			cleanup(f);
		}
	});

	it("an already-applied verdict still refuses once its patch no longer matches", () => {
		const f = baseFixture();
		try {
			const { root, baseline, branch } = f;
			const proposal = { paths: proposalFor(f), description: "", at: AT };
			applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } });
			// The primary edits one merged file: the reverse check fails, and
			// the dirty tree refuses the merge instead of clobbering the edit.
			writeFile(root, "a.txt", "primary edit over worker content\n");
			assert.throws(
				() => applyVerdict(root, { baseline, branch, proposal, verdict: { scope: "all" } }),
				(e) => e instanceof TaskQueueError && e.code === "merge-dirty-main",
			);
		} finally {
			cleanup(f);
		}
	});
});

describe("archiveDiscardedTrack", () => {
	it("parks the full branch diff for a verdict-none track", () => {
		const f = makeFixture((wt) => {
			writeFile(wt, "parked.txt", "p\n");
			commitAll(wt, "seg");
		});
		try {
			const stateDir = path.join(f.dir, "state");
			archiveDiscardedTrack(stateDir, "t1", f.root, f.baseline, f.branch);
			const diff = fs.readFileSync(path.join(stateDir, "archive", "t1.diff"), "utf8");
			assert.ok(diff.includes("parked.txt"));
			assert.ok(fs.existsSync(path.join(stateDir, "archive", "t1.note")));
		} finally {
			cleanup(f);
		}
	});
});