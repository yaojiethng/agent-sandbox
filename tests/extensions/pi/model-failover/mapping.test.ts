/**
 * The mapping check: the diagram, the invariant index and the suite cannot
 * drift apart. One direction asserts every transition id in the diagram has a
 * case in the suite; the other asserts every invariant case carries its id.
 *
 * The suite is read as text because the check is about names, not behaviour:
 * a transition the code holds but no case names is a transition the suite only
 * appears to cover, and an invariant case that carries no id is a red line
 * that names no review-finding class.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { TRANSITIONS } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/transitions.ts";
import { INVARIANTS } from "./invariants.ts";

const SUITE_DIR = import.meta.dirname;

/** The `it("...")` names of one test file, plain-string and template-literal forms. */
function testNames(file: string): readonly string[] {
	const text = fs.readFileSync(file, "utf8");
	const plain = [...text.matchAll(/\bit\(\s*"([^"]+)"/g)].map((match) => match[1]);
	const templated = [...text.matchAll(/\bit\(\s*`([^`]*)`/g)].map((match) => match[1]);
	return [...plain, ...templated];
}

/** Every test name in the suite, by file. */
function suiteNames(): Map<string, readonly string[]> {
	const names = new Map<string, readonly string[]>();
	for (const entry of fs.readdirSync(SUITE_DIR, { withFileTypes: true })) {
		if (!entry.isFile() || !entry.name.endsWith(".test.ts")) {
			continue;
		}
		names.set(entry.name, testNames(path.join(SUITE_DIR, entry.name)));
	}
	return names;
}

describe("the mapping check", () => {
	it("every transition of the diagram has a case in the suite", () => {
		const names = [...suiteNames().values()].flat();
		for (const transition of TRANSITIONS) {
			const covered = names.some((name) => name.includes(transition.id));
			assert.ok(covered, `${transition.id} (${transition.from} --${transition.event}--> ${transition.to}) has no case`);
		}
	});

	it("every invariant of the index has a case in the suite", () => {
		const names = [...suiteNames().values()].flat();
		for (const invariant of INVARIANTS) {
			const covered = names.some((name) => name.includes(invariant.id));
			assert.ok(covered, `${invariant.id} -- ${invariant.statement} has no case`);
		}
	});

	it("every case in the invariant report carries its id", () => {
		for (const [file, names] of suiteNames()) {
			if (file !== "invariants.test.ts") {
				continue;
			}
			for (const name of names) {
				const carries = INVARIANTS.some((invariant) => name.includes(invariant.id));
				assert.ok(carries, `the case "${name}" names no invariant id`);
			}
		}
	});
});
