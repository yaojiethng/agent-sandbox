/**
 * The mutation gate: every row of the catalog is a deliberate break of the
 * model-refresh extension, and the gate fails unless the suite turns red
 * against it.
 *
 * The lesson this gate exists for: the suite was green while two invariants
 * were false. A catalog mutation that let models.dev set a context window of
 * zero, and one that let an empty baked catalog drop the persisted store, both
 * passed every case that existed. Green proved nothing because nothing asked
 * whether a broken extension would also be green. This file asks that question
 * once per catalog row.
 *
 * The gate reports one verdict per row, and each row has to reach the verdict
 * its own kind requires:
 *
 *   proven     - a break row: the suite failed against the mutant, and at
 *                least one failing test names the invariant the row attacks.
 *   survived   - a control row: the unmutated mirror stayed green. A break
 *                row that survives is a finding about the suite, and the gate
 *                fails on it.
 *   no-op      - the anchor is absent or ambiguous, so the row drifted from
 *                the code.
 *   unloadable - the mutant does not load. A mutant that only fails to parse
 *                turns the suite red for a reason that proves nothing.
 *   timed-out  - the replay hit its deadline. A killed child has no exit
 *                status, and reading the deadline as a failure would prove
 *                every break on a busy host.
 *   not-run    - the pi installation the suite reads is absent. Nothing was
 *                replayed, so the gate says so instead of skipping into a
 *                green report.
 *
 * Attribution is part of the verdict. A break that turns some other test red
 * proves the replay harness works, not that the line is pinned, so a row is
 * only proven when an invariant case is named after the invariant the row
 * declares and that case failed on an assertion. The failure has to be an
 * assertion as well: a mutant that throws turns the whole suite red, and a
 * gate that reads any red line as proof calls it proven against every
 * invariant in the file. The catalog's `invariant` field is therefore checked
 * against the suite on every run: a row that names an invariant nothing holds
 * fails, which is what stops the field from drifting into a claim the suite
 * never makes.
 *
 * The report says two more things, because a verdict alone is thin. It names
 * the invariants no row attacks, which is a fact about the suite rather than a
 * verdict on a row, so the gate prints it and does not fail on it. And it
 * names the case that caught each proven row: a row a coarser case of its own
 * invariant caught reads the same as one the case written for it caught, and
 * the two are not the same claim.
 *
 * The gate never edits the repository. The engine in `mutation/runner.ts`
 * copies the extension and the suite into a temp mirror, breaks the copy, runs
 * the suite there, and removes the mirror whatever the verdict is. The rows run
 * concurrently because each one is a mirror and a child process of its own, so
 * a replayed row cannot leave the working tree broken, and the sibling suites
 * that read the same sources under the folder glob cannot see a mutant. The
 * rendered report is sorted by row id, so the concurrency does not reach it.
 *
 * The engine is a near-duplicate of the task-queue runner at
 * `tests/extensions/pi/task-queue/mutation/runner.ts`; folding the two into
 * one shared helper is follow-up work, not this gate.
 */

import { after, describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { MUTATIONS } from "./mutation/catalog.ts";
import { buildCatalog } from "./invariants.ts";
import { REPO_ROOT, expectedVerdict, renderMutations, runMutation, type GateIndex, type MutationOutcome } from "./mutation/runner.ts";

/** Concurrent rows: each is a child process and a temp mirror of its own. */
const CONCURRENCY = 2;

const outcomes: MutationOutcome[] = [];

/** The suite's own catalog: the cases the replayed tests name, read once. */
const CATALOG = buildCatalog();

/**
 * The suite as the report reads it: the invariant ids the catalog defines, and
 * the case a failing test name belongs to. A test name carries its case's
 * statement, so the lookup is exact, and a name that names no case is printed
 * as it stands rather than dropped.
 */
const GATE_INDEX: GateIndex = {
	invariants: [...new Set(CATALOG.map((entry) => entry.id))],
	caseName: (testName) => {
		const entry = CATALOG.find((candidate) => testName === `INV ${candidate.id} -- ${candidate.statement}`);
		return entry === undefined ? testName : `${entry.id} ${entry.name}`;
	},
};

describe("the model-refresh mutation gate", { concurrency: CONCURRENCY }, () => {
	after(() => {
		if (outcomes.length === MUTATIONS.length) process.stdout.write(`\n${renderMutations(outcomes, GATE_INDEX)}\n`);
	});

	it("the catalog is well formed: unique ids, real subjects, and a stated break", () => {
		const ids = MUTATIONS.map((m) => m.id);
		assert.equal(new Set(ids).size, ids.length, "no two rows share an id");
		// A row that names an invariant the suite does not define reads as
		// coverage of something nobody wrote down.
		const known = new Set(CATALOG.map((entry) => entry.id));
		// A gate without a control row reads green on a mirror the suite cannot
		// run green in, so the control is part of the catalog rather than an
		// optional extra.
		const controls = MUTATIONS.filter((m) => m.control === true);
		assert.equal(controls.length, 1, `the gate carries exactly one control row, found ${controls.length}`);
		for (const m of MUTATIONS) {
			assert.ok(fs.existsSync(path.join(REPO_ROOT, m.subject)), `${m.id}: the subject ${m.subject} exists`);
			assert.ok(m.breaks.length > 0, `${m.id}: the row names the defect it stands for`);
			if (m.control === true) {
				continue;
			}
			assert.ok(known.has(m.invariant), `${m.id}: the invariant ${m.invariant} is one the suite defines`);
			assert.ok(m.old.length > 0, `${m.id}: the row names the text it replaces`);
			assert.ok(m.next.length > 0, `${m.id}: the row names the text it breaks in`);
			assert.ok(m.next !== m.old, `${m.id}: the row breaks something`);
		}
	});

	for (const row of MUTATIONS) {
		// The rows are never skipped: an absent pi installation reaches the
		// engine, comes back as `not-run`, and fails the row that expected a
		// verdict. A host with no pi prints a red gate rather than a green one
		// over a list of skips.
		it(`${row.invariant} ${row.id}`, () => {
			const outcome = runMutation(row);
			outcomes.push(outcome);
			const expected = expectedVerdict(row);
			assert.equal(outcome.verdict, expected, `${row.id}: expected ${expected}, got ${outcome.verdict} -- ${outcome.detail}. The break: ${row.breaks}`);
			if (row.control === true) {
				return;
			}
			// A row is only proven when an invariant case failed on an
			// assertion: a suite that turned red somewhere else, a suite block
			// that names no case, or a suite that turned red because the mutant
			// threw proves the mirror was replayed and not that this line is
			// pinned. The runner keeps only the case names, so a name this
			// filter misses is a suite or a crash, never an unheld case.
			const prefix = `INV ${row.invariant} -- `;
			const attributed = outcome.asserted.filter((name) => name.startsWith(prefix));
			assert.ok(attributed.length > 0, `${row.id}: no assertion failure names ${row.invariant}. Failing tests: ${outcome.failing.join("; ") || "none"}; failed on an assertion: ${outcome.asserted.join("; ") || "none"}`);
		});
	}
});
