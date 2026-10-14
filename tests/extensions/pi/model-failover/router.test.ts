/**
 * The dispatch walk: the three tiers, the sticky guard, and the threshold
 * end to end. The walk is a pure function, so every tier is a case without a
 * pi process.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { Ledger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts";
import { chooseRoute, type WalkInput } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/router.ts";
import { COOLDOWNS, chain, limited, NOW, ok, route, tempLedgerPath, THRESHOLD, transient } from "./helpers.ts";

const A = route("opencode-go", "model-a");
const B = route("opencode-go", "model-b");

/** A walk input where every route resolves and the ledger decides eligibility. */
function walk(two: ReturnType<typeof chain>, ledger: Ledger, previous?: { provider: string; model: string }): WalkInput {
	return {
		chain: two,
		previous,
		resolvable: () => true,
		eligible: (r) => ledger.eligible(r.provider, r.model, NOW),
	};
}

/** Apply one outcome through the ledger, as the observer does. */
function record(ledger: Ledger, target: typeof A, outcome: ReturnType<typeof transient> | ReturnType<typeof limited> | ReturnType<typeof ok>): void {
	ledger.apply(target.provider, target.model, outcome, NOW, THRESHOLD, COOLDOWNS);
}

describe("the dispatch walk", () => {
	it("the sticky tier holds the previous route while it is healthy", () => {
		const ledger = new Ledger(tempLedgerPath());
		const choice = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: B.provider, model: B.model }));
		assert.equal(choice.route.model, "model-b", "the second route serves because it served last");
		assert.equal(choice.tier, "sticky");
	});

	it("G1 the sticky tier hands over when the previous route is not in healthy", () => {
		const ledger = new Ledger(tempLedgerPath());
		record(ledger, B, limited());
		const choice = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: B.provider, model: B.model }));
		assert.equal(choice.route.model, "model-a", "a cooled previous route does not serve");
		assert.equal(choice.tier, "healthy");
	});

	it("the healthy tier takes the first healthy route in declared order", () => {
		const ledger = new Ledger(tempLedgerPath());
		record(ledger, A, limited());
		const choice = chooseRoute(walk(chain("c", [A, B]), ledger));
		assert.equal(choice.route.model, "model-b");
		assert.equal(choice.tier, "healthy");
	});

	it("the degrade tier dispatches the chain head when every route is cooling", () => {
		const ledger = new Ledger(tempLedgerPath());
		record(ledger, A, limited());
		record(ledger, B, limited());
		const choice = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: B.provider, model: B.model }));
		assert.equal(choice.route.model, "model-a", "the head serves, and the turn is not refused");
		assert.equal(choice.tier, "degraded");
	});

	it("an unresolvable route is skipped while another route is healthy", () => {
		const ledger = new Ledger(tempLedgerPath());
		const two = chain("c", [A, B]);
		const choice = chooseRoute({
			chain: two,
			previous: undefined,
			resolvable: (r) => r.model === "model-b",
			eligible: () => true,
		});
		assert.equal(choice.route.model, "model-b");
		assert.equal(choice.tier, "healthy");
	});

	it("the degrade tier dispatches the head even when it is unresolvable", () => {
		const ledger = new Ledger(tempLedgerPath());
		const choice = chooseRoute({
			chain: chain("c", [A, B]),
			previous: undefined,
			resolvable: () => false,
			eligible: () => false,
		});
		assert.equal(choice.route.model, "model-a", "a broken chain surfaces as pi's own error, not a refused turn");
		assert.equal(choice.tier, "degraded");
	});

	describe("the threshold end to end", () => {
		it("one transient failure does not switch the served route", () => {
			const ledger = new Ledger(tempLedgerPath());
			record(ledger, A, transient());
			const choice = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: A.provider, model: A.model }));
			assert.equal(choice.route.model, "model-a", "a blip below the threshold keeps the served route");
		});

		it("the third consecutive transient failure switches to the next route", () => {
			const ledger = new Ledger(tempLedgerPath());
			record(ledger, A, transient());
			record(ledger, A, transient());
			const still = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: A.provider, model: A.model }));
			assert.equal(still.route.model, "model-a", "the second failure still holds the route");
			record(ledger, A, transient());
			const switched = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: A.provider, model: A.model }));
			assert.equal(switched.route.model, "model-b", "the third consecutive failure switches the served route");
			assert.equal(switched.tier, "healthy");
		});

		it("a success between failures resets the count, so no threshold is crossed", () => {
			const ledger = new Ledger(tempLedgerPath());
			record(ledger, A, transient());
			record(ledger, A, transient());
			record(ledger, A, ok());
			record(ledger, A, transient());
			const choice = chooseRoute(walk(chain("c", [A, B]), ledger, { provider: A.provider, model: A.model }));
			assert.equal(choice.route.model, "model-a", "the streak resets on success, so three failures with a gap never cool the route");
		});
	});
});
