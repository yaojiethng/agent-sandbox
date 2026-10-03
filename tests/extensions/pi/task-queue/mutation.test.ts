/**
 * The mutation gate: every row of the catalog is a deliberate break of the
 * extension, and the gate fails unless the suite turns red against it.
 *
 * The round-2 lesson this gate exists for: the conformance suite was green
 * (202/202) while two invariants were false. Green proved nothing because
 * nothing in the suite asked whether a broken extension would also be green.
 * This file asks that question once per catalog row, before any review
 * subagent fires, so the class of defect that reaches a reviewer is the
 * class a machine cannot enumerate.
 *
 * The gate is one `it` per row, so a red line names the row, the invariant
 * it attacks, and the break it stands for. The rows run concurrently
 * because each one is a throwaway mirror and a child process, and the slow
 * rows are the ones that must run the wired suite.
 *
 * The gate never edits the repository. The runner copies the extension and
 * the suite into a temp mirror, breaks the copy, and runs the named suites
 * there, so a replayed row cannot leave the working tree broken.
 */

import { after, describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { MUTATIONS } from "./mutation/catalog.ts";
import { REPO_ROOT, piAvailable, renderMutations, runMutation, type MutationOutcome } from "./mutation/runner.ts";

/** Concurrent rows: each is a child process and a temp mirror of its own. */
const CONCURRENCY = 2;

const suite = piAvailable() ? {} : { skip: "pi installation not present" };
const outcomes: MutationOutcome[] = [];

describe("the mutation gate", { concurrency: CONCURRENCY }, () => {
	after(() => {
		if (outcomes.length === MUTATIONS.length) process.stdout.write(`\n${renderMutations(outcomes)}\n`);
	});

	it("the catalog is well formed: unique ids, real subjects, and named suites", () => {
		const ids = MUTATIONS.map((m) => m.id);
		assert.equal(new Set(ids).size, ids.length, "no two rows share an id");
		for (const m of MUTATIONS) {
			assert.ok(fs.existsSync(path.join(REPO_ROOT, m.subject)), `${m.id}: the subject ${m.subject} exists`);
			assert.ok(m.tests.length > 0, `${m.id}: the row names the suites that must turn red`);
			for (const t of m.tests) {
				assert.ok(fs.existsSync(path.join(REPO_ROOT, "tests/extensions/pi/task-queue", t)), `${m.id}: the suite ${t} exists`);
			}
			assert.ok(m.breaks.length > 0, `${m.id}: the row names the defect it stands for`);
		}
	});

	for (const row of MUTATIONS) {
		it(`${row.invariant} ${row.id}`, suite, async () => {
			const outcome = runMutation(row);
			outcomes.push(outcome);
			assert.equal(
				outcome.verdict,
				"proven",
				`the break was not proven: ${outcome.verdict} -- ${outcome.detail}. The break: ${outcome.breaks}`,
			);
		});
	}
});
