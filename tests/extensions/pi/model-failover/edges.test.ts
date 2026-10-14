/**
 * The edge layer: the health machine of edges.ts (B1 to B5), the selection
 * guard nextEdge, and address resolution.
 *
 * Pure functions, so every case drives the state directly. `nextEdge` takes
 * its random sample as an argument, so a fixed sample gives a fixed answer.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
	applyEdgeOutcome,
	applyResolution,
	edgeRate,
	edgeStreak,
	eligibleEdgeAt,
	initialEdgeHealth,
	needsRefresh,
	nextEdge,
	resolveAddresses,
	unresolvedAddressSet,
	usable,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/edges.ts";
import type { EdgeHealth, Outcome, SelectionConfig } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts";

const NOW = 1_700_000_000_000;
const THRESHOLD = 3;
const WINDOW = 180_000;

const success: Outcome = { ok: true };
const transient: Outcome = { ok: false, class: "transient" };
const limited: Outcome = { ok: false, class: "limited" };

const RATE: SelectionConfig = { policy: "rate", epsilon: 0 };
const EPSILON: SelectionConfig = { policy: "epsilon", epsilon: 0.2 };

/** Apply a run of outcomes at one-millisecond intervals from NOW. */
function run(health: EdgeHealth, outcomes: readonly Outcome[], start: number): EdgeHealth {
	let next = health;
	outcomes.forEach((outcome, index) => {
		next = applyEdgeOutcome(next, outcome, start + index, THRESHOLD, WINDOW);
	});
	return next;
}

describe("the edge health machine", () => {
	it("B1: a success leaves the edge eligible and records the success", () => {
		const health = applyEdgeOutcome(initialEdgeHealth(), success, NOW, THRESHOLD, WINDOW);
		assert.equal(health.state, "eligible");
		assert.deepEqual(health.window, [{ ok: true, at: NOW }]);
	});

	it("B2: a transient failure below the threshold keeps the edge eligible and counts the streak", () => {
		const health = run(initialEdgeHealth(), [transient, transient], NOW);
		assert.equal(health.state, "eligible");
		assert.equal(edgeStreak(health), 2);
	});

	it("B3: the threshold transient failure cools the edge for the window", () => {
		const health = run(initialEdgeHealth(), [transient, transient, transient], NOW);
		assert.equal(health.state, "cooling");
		if (health.state === "cooling") {
			assert.equal(health.until, NOW + 2 + WINDOW);
		}
	});

	it("B4: a success while cooling returns the edge to eligible", () => {
		const cooling = run(initialEdgeHealth(), [transient, transient, transient], NOW);
		const health = applyEdgeOutcome(cooling, success, NOW + 10, THRESHOLD, WINDOW);
		assert.equal(health.state, "eligible");
		assert.equal(edgeStreak(health), 0);
	});

	it("B5: a failure while cooling refreshes the deadline", () => {
		const cooling = run(initialEdgeHealth(), [transient, transient, transient], NOW);
		const health = applyEdgeOutcome(cooling, transient, NOW + 1000, THRESHOLD, WINDOW);
		assert.equal(health.state, "cooling");
		if (health.state === "cooling") {
			assert.equal(health.until, NOW + 1000 + WINDOW);
		}
	});

	it("a limited outcome is an ignored event and changes nothing", () => {
		const health = run(initialEdgeHealth(), [transient, transient], NOW);
		const after = applyEdgeOutcome(health, limited, NOW + 5, THRESHOLD, WINDOW);
		assert.equal(after, health);
	});

	it("a success does not erase the failure evidence, so a flapping edge keeps a low rate", () => {
		const health = run(initialEdgeHealth(), [transient, success, transient, success], NOW);
		assert.equal(health.state, "eligible");
		assert.ok(edgeRate(health) < 0.6, `rate ${edgeRate(health)} should reflect the failures`);
	});

	it("a failure older than the window ages out of the streak", () => {
		const health = run(initialEdgeHealth(), [transient, transient], NOW);
		const later = applyEdgeOutcome(health, transient, NOW + WINDOW + 1, THRESHOLD, WINDOW);
		assert.equal(later.state, "eligible", "the two old failures have aged out");
		assert.equal(edgeStreak(later), 1);
	});

	it("the admissibility guard derives a lapsed deadline at read time", () => {
		const cooling = run(initialEdgeHealth(), [transient, transient, transient], NOW);
		assert.equal(eligibleEdgeAt(cooling, NOW), false);
		assert.equal(eligibleEdgeAt(cooling, NOW + WINDOW + 2), true);
	});
});

describe("the selection guard", () => {
	const clean = (at?: number): EdgeHealth => (at === undefined ? initialEdgeHealth() : { state: "eligible", window: [{ ok: true, at }] });
	const failed = (at: number, streak = 1): EdgeHealth => ({
		state: "eligible",
		window: [...Array.from({ length: streak }, (_, i) => ({ ok: false, at: at - i }))].reverse(),
	});
	const cooling = (until: number): EdgeHealth => ({ state: "cooling", window: [], until });

	it("no candidates yields undefined", () => {
		assert.equal(nextEdge([], () => initialEdgeHealth(), NOW, 0, RATE), undefined);
	});

	it("sticky: the last-used edge serves again after a success", () => {
		const health: Record<string, EdgeHealth> = { a: clean(NOW), b: clean(NOW - 100) };
		assert.equal(nextEdge(["a", "b"], (e) => health[e], NOW, 0.9, RATE), "a");
	});

	it("reselect: after a failure the policy picks, and the flapping edge can still be chosen", () => {
		const health: Record<string, EdgeHealth> = { a: failed(NOW), b: clean(NOW - 100) };
		const first = nextEdge(["a", "b"], (e) => health[e], NOW, 0, RATE);
		assert.equal(first, "a", "the low sample lands on the first clean edge");
	});

	it("all cooling: the soonest-to-recover edge is the probe", () => {
		const health: Record<string, EdgeHealth> = { a: cooling(NOW + 100), b: cooling(NOW + 50) };
		assert.equal(nextEdge(["a", "b"], (e) => health[e], NOW, 0, RATE), "b");
	});

	it("epsilon greedy explores on a low sample and exploits on a high one", () => {
		const health: Record<string, EdgeHealth> = { a: failed(NOW), b: clean(NOW - 100) };
		assert.equal(nextEdge(["a", "b"], (e) => health[e], NOW, 0.05, EPSILON), "a");
		assert.equal(nextEdge(["a", "b"], (e) => health[e], NOW, 0.9, EPSILON), "b");
	});
});

describe("address resolution and the address set", () => {
	it("a resolver answer is deduplicated", async () => {
		const addresses = await resolveAddresses("example.test", async () => ["1.1.1.1", "2.2.2.2", "1.1.1.1"]);
		assert.deepEqual(addresses, ["1.1.1.1", "2.2.2.2"]);
	});

	it("a non-empty answer resolves the set and a failed or empty answer leaves it", () => {
		const empty = unresolvedAddressSet();
		assert.equal(usable(empty), false);
		const resolved = applyResolution(empty, ["1.1.1.1"], NOW);
		assert.equal(usable(resolved), true);
		assert.equal(applyResolution(resolved, [], NOW + 10), resolved, "an empty answer is ignored");
	});

	it("a never-resolved set and a set past its ttl both need a refresh", () => {
		const empty = unresolvedAddressSet();
		assert.equal(needsRefresh(empty, NOW, 60_000), true);
		const resolved = applyResolution(empty, ["1.1.1.1"], NOW);
		assert.equal(needsRefresh(resolved, NOW + 59_999, 60_000), false);
		assert.equal(needsRefresh(resolved, NOW + 60_001, 60_000), true);
	});
});
