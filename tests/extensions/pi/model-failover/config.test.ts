/**
 * The declarations loader: the shipped file parses, every malformed shape
 * refuses with a named error (R8), the defaults apply, and an unknown field
 * is ignored so a later version of the file can add a key.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { parseDeclarations, DeclarationsError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/config.ts";

/** Parse a text, asserting the load refuses, and return the message. */
function refusal(text: string): string {
	try {
		parseDeclarations(text);
	} catch (error) {
		assert.ok(error instanceof DeclarationsError, `the refusal is named DeclarationsError, got ${String(error)}`);
		return (error as Error).message;
	}
	assert.fail("the malformed declarations file was accepted");
}

const SHIPPED = fs.readFileSync(path.resolve(import.meta.dirname, "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/routes.json"), "utf8");

describe("the declarations loader", () => {
	it("the shipped file parses to one chain protecting step-5-preview-free", () => {
		const declarations = parseDeclarations(SHIPPED);
		assert.equal(declarations.chains.length, 1);
		const [first] = declarations.chains;
		assert.equal(first.id, "step-5-preview-free");
		assert.deepEqual(first.routes, [{ provider: "opencode-go", model: "step-5-preview-free" }]);
		assert.equal(first.transientFailuresBeforeCooldown, 3, "the shipped threshold");
		assert.deepEqual(first.cooldownMs, { transient: 120000, limited: 3600000 }, "the shipped cooldowns");
	});

	it("the defaults apply when a chain omits the threshold and the cooldowns", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }] })}`);
		assert.equal(declarations.chains[0].transientFailuresBeforeCooldown, 3);
		assert.deepEqual(declarations.chains[0].cooldownMs, { transient: 120000, limited: 3600000 });
	});

	it("a partial cooldowns object fills the missing class from the default", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }], cooldownMs: { limited: 5000 } }] })}`);
		assert.deepEqual(declarations.chains[0].cooldownMs, { transient: 120000, limited: 5000 });
	});

	it("a route may declare a thinking level", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m", thinkingLevel: "high" }] }] })}`);
		assert.deepEqual(declarations.chains[0].routes, [{ provider: "p", model: "m", thinkingLevel: "high" }]);
	});

	it("refuses a thinking level outside the six names", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m", thinkingLevel: "turbo" }] }] })}`), /not one of/);
	});

	it("refuses the same route declared by two chains", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c1", routes: [{ provider: "p", model: "m" }] }, { id: "c2", routes: [{ provider: "p", model: "m" }] }] })}`), /declared by two chains/);
	});

	it("gives every chain its own cooldown object, so one chain cannot alias another's", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c1", routes: [{ provider: "p", model: "m1" }] }, { id: "c2", routes: [{ provider: "p", model: "m2" }] }] })}`);
		const [first, second] = declarations.chains;
		assert.deepEqual(first.cooldownMs, second.cooldownMs, "both carry the defaults");
		assert.notEqual(first.cooldownMs, second.cooldownMs, "but not the same object");
	});

	it("a field the loader does not read is ignored", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m", note: "later key" }] }], future: true })}`);
		assert.equal(declarations.chains[0].routes.length, 1);
	});

	it("refuses text that is not JSON", () => {
		assert.match(refusal("not json"), /not JSON/);
	});

	it("refuses a file with no chains member", () => {
		assert.match(refusal(`${JSON.stringify({ routes: [] })}`), /'chains'/);
	});

	it("refuses an empty chains array", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [] })}`), /non-empty array/);
	});

	it("refuses a chain with no id", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ routes: [{ provider: "p", model: "m" }] }] })}`), /'id'/);
	});

	it("refuses a chain with an empty routes array", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [] }] })}`), /'routes'/);
	});

	it("refuses a route with no model", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p" }] }] })}`), /'model'/);
	});

	it("refuses two chains that share an id", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }, { id: "c", routes: [{ provider: "p", model: "n" }] }] })}`), /share the id/);
	});

	it("refuses one chain that lists a route twice", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }, { provider: "p", model: "m" }] }] })}`), /lists the route/);
	});

	it("refuses a threshold below 1", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }], transientFailuresBeforeCooldown: 0 }] })}`), /integer of at least 1/);
	});

	it("refuses a non-positive cooldown", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }], cooldownMs: { transient: 0 } }] })}`), /positive integer/);
	});

	it("the selection block defaults to epsilon at 0.1", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }] })}`);
		assert.deepEqual(declarations.selection, { policy: "epsilon", epsilon: 0.1 });
	});

	it("the selection block is configurable and fills the missing field from the default", () => {
		const declarations = parseDeclarations(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }], selection: { policy: "rate" } })}`);
		assert.deepEqual(declarations.selection, { policy: "rate", epsilon: 0.1 });
	});

	it("refuses an unknown selection policy", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }], selection: { policy: "greedy" } })}`), /not 'rate' or 'epsilon'/);
	});

	it("refuses an epsilon at or above 1", () => {
		assert.match(refusal(`${JSON.stringify({ chains: [{ id: "c", routes: [{ provider: "p", model: "m" }] }], selection: { epsilon: 1 } })}`), /below 1/);
	});
});
