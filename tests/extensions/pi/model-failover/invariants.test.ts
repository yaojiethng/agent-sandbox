/**
 * The invariant report: one named case per invariant of the index, over the
 * real modules. Each case is named `INV <id> -- <statement>` and reads its
 * statement from invariants.ts, so a red line names its invariant and the
 * review-finding class the finding belongs to.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import { applyOutcome, eligibleAt, Ledger, parseLedger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts";
import { classifyError } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts";
import { chooseRoute } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/router.ts";
import { parseDeclarations } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/config.ts";
import { DECLARATIONS_PATH } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/config.ts";
import { INVARIANTS } from "./invariants.ts";
import { chain, COOLDOWNS, limited, NOW, ok, route, tempLedgerPath, THRESHOLD, transient } from "./helpers.ts";

const statement = (id: string): string => INVARIANTS.find((invariant) => invariant.id === id)?.statement ?? "";

describe("the invariant report", () => {
	it(`INV S1 -- ${statement("S1")}`, () => {
		const declarations = parseDeclarations(fs.readFileSync(DECLARATIONS_PATH, "utf8"));
		const path = tempLedgerPath();
		try {
			const ledger = new Ledger(path);
			ledger.load();
			for (const chainOf of declarations.chains) {
				for (const routeOf of chainOf.routes) {
					ledger.apply(routeOf.provider, routeOf.model, transient(), NOW, THRESHOLD, COOLDOWNS);
				}
			}
			const onDisk = parseLedger(fs.readFileSync(path, "utf8"));
			const declared = new Set(declarations.chains.flatMap((chainOf) => chainOf.routes.map((routeOf) => `${routeOf.provider}/${routeOf.model}`)));
			for (const key of onDisk.keys()) {
				assert.ok(declared.has(key), `the key ${key} is a declared route`);
			}
			assert.ok(declared.size > 0, "the shipped file declares at least one route");
		} finally {
			fs.rmSync(path, { force: true });
		}
	});

	it(`INV S2 -- ${statement("S2")}`, () => {
		const cooled = applyOutcome({ state: "eligible", streak: 0 }, limited(), NOW, THRESHOLD, COOLDOWNS);
		assert.ok(cooled.state === "cooling" && typeof cooled.until === "number" && typeof cooled.class === "string");
		const streaked = applyOutcome({ state: "eligible", streak: 1 }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.ok(streaked.state === "eligible" && typeof streaked.streak === "number");
	});

	it(`INV S3 -- ${statement("S3")}`, () => {
		const path = tempLedgerPath();
		try {
			const ledger = new Ledger(path);
			const two = chain("c", [route("p", "m1"), route("p", "m2")]);
			ledger.apply("p", "m1", limited(), NOW, THRESHOLD, COOLDOWNS);
			assert.equal(eligibleAt(ledger.get("p", "m1"), NOW), false);
			const choice = chooseRoute({ chain: two, resolvable: () => true, eligible: (r) => ledger.eligible(r.provider, r.model, NOW) });
			assert.equal(choice.route.model, "m2", "the walk's only admissibility answer is the guard's");
		} finally {
			fs.rmSync(path, { force: true });
		}
	});

	it(`INV TI1 -- ${statement("TI1")}`, () => {
		const below = applyOutcome({ state: "eligible", streak: THRESHOLD - 2 }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(below.state, "eligible", "below N the route does not cool");
		const at = applyOutcome({ state: "eligible", streak: THRESHOLD }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(at.state, "cooling", "at N the route cools");
		const limitedAt = applyOutcome({ state: "eligible", streak: 0 }, limited(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(limitedAt.state, "cooling", "a quota-class failure cools at once");
	});

	it(`INV TI2 -- ${statement("TI2")}`, () => {
		const transientCooling = applyOutcome({ state: "eligible", streak: THRESHOLD }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(transientCooling.state === "cooling" && transientCooling.until, NOW + COOLDOWNS.transient);
		const limitedCooling = applyOutcome({ state: "eligible", streak: 0 }, limited(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(limitedCooling.state === "cooling" && limitedCooling.until, NOW + COOLDOWNS.limited);
	});

	it(`INV TI3 -- ${statement("TI3")}`, () => {
		const cooled = { state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" } as const;
		const cleared = applyOutcome(cooled, ok(), NOW, THRESHOLD, COOLDOWNS);
		assert.equal(cleared.state, "eligible");
		assert.equal(eligibleAt(cleared, NOW), true);
	});

	it(`INV TI4 -- ${statement("TI4")}`, () => {
		// Held by the wiring test, which drives the real observer and counts the
		// appended entries one outcome at a time. This case asserts the ledger
		// side of the same fact: the transition that appends changes the state.
		const before = { state: "eligible", streak: 0 } as const;
		const afterFailure = applyOutcome(before, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.notDeepEqual(afterFailure, before, "the appending transition also changes the state");
		const afterSuccess = applyOutcome(afterFailure, ok(), NOW, THRESHOLD, COOLDOWNS);
		assert.notDeepEqual(afterSuccess, afterFailure);
	});

	it(`INV G1 -- ${statement("G1")}`, () => {
		const two = chain("c", [route("p", "m1"), route("p", "m2")]);
		const path = tempLedgerPath();
		try {
			const ledger = new Ledger(path);
			ledger.apply("p", "m2", limited(), NOW, THRESHOLD, COOLDOWNS);
			const choice = chooseRoute({ chain: two, previous: { provider: "p", model: "m2" }, resolvable: () => true, eligible: (r) => ledger.eligible(r.provider, r.model, NOW) });
			assert.equal(choice.tier, "healthy", "an unhealthy previous route is not chosen");
			const sticky = chooseRoute({ chain: two, previous: { provider: "p", model: "m2" }, resolvable: () => true, eligible: () => true });
			assert.equal(sticky.tier, "sticky", "a healthy previous route is chosen");
		} finally {
			fs.rmSync(path, { force: true });
		}
	});

	it(`INV G2 -- ${statement("G2")}`, () => {
		const cooled = applyOutcome({ state: "eligible", streak: THRESHOLD }, transient(), NOW, THRESHOLD, COOLDOWNS);
		const lapsed = cooled.state === "cooling" && cooled.until <= NOW + COOLDOWNS.transient;
		assert.ok(lapsed, "the deadline is set");
		const afterLapse = applyOutcome(cooled, transient(), NOW + COOLDOWNS.transient + 1, THRESHOLD, COOLDOWNS);
		assert.equal(afterLapse.state, "cooling", "a failure after the lapse re-cools at once: the streak never lapsed");
		const afterSuccess = applyOutcome(cooled, ok(), NOW + COOLDOWNS.transient + 1, THRESHOLD, COOLDOWNS);
		assert.equal(afterSuccess.state, "eligible", "only a success clears the state");
	});

	it(`INV C1 -- ${statement("C1")}`, () => {
		assert.equal(classifyError("GoUsageLimitError: Go usage limit exceeded"), "limited");
		assert.equal(classifyError("429: Endpoint is unavailable"), "transient");
		assert.equal(classifyError("a failure nobody has seen"), "limited", "an unmatched text is unrecoverable, the loud direction");
	});
});
