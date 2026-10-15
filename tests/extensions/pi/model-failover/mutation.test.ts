/**
 * The mutation gate: every break row of the catalog is a deliberate break of
 * the extension, and the gate fails unless the suite turns red against it.
 * The control row is proven by the suite staying green.
 *
 * The gate exists because a green suite once proved nothing: two invariants
 * of a sibling extension shipped green while false, and only a reviewer
 * caught them. This file asks whether a broken extension would also be green
 * once per catalog row, before any review subagent fires.
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

	it("the catalog is well formed: unique ids, real subjects, named suites, and one control row", () => {
		const ids = MUTATIONS.map((m) => m.id);
		assert.equal(new Set(ids).size, ids.length, "no two rows share an id");
		for (const m of MUTATIONS) {
			assert.ok(fs.existsSync(path.join(REPO_ROOT, m.subject)), `${m.id}: the subject ${m.subject} exists`);
			assert.ok(m.tests.length > 0, `${m.id}: the row names the suites that must turn red`);
			for (const t of m.tests) {
				assert.ok(fs.existsSync(path.join(REPO_ROOT, "tests/extensions/pi/model-failover", t)), `${m.id}: the suite ${t} exists`);
			}
			assert.ok(m.breaks.length > 0, `${m.id}: the row names the defect it stands for`);
		}
		const controls = MUTATIONS.filter((m) => m.control === true);
		assert.equal(controls.length, 1, `the gate carries exactly one control row, found ${controls.length}`);
	});

	for (const row of MUTATIONS) {
		it(`${row.invariant} ${row.id}`, suite, async () => {
			const outcome = runMutation(row);
			outcomes.push(outcome);
			const expected = row.control === true ? "survived" : "proven";
			assert.equal(
				outcome.verdict,
				expected,
				`the break was not ${expected}: ${outcome.verdict} -- ${outcome.detail}. The break: ${outcome.breaks}`,
			);
		});
	}
});
