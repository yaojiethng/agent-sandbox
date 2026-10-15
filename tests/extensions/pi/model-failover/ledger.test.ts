/**
 * The state machine: one deep test per transition of the diagram, plus the
 * eligibility guard, the ledger file, and the machine's interaction with the
 * threshold. Each test is named after the transition it holds, so the mapping
 * check can assert the diagram is covered.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import { applyOutcome, eligibleAt, Ledger, parseLedger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts";
import { COOLDOWNS, chain, limited, NOW, ok, route, tempLedgerPath, THRESHOLD, transient } from "./helpers.ts";

const OTHER = route("opencode-go", "other-model");

describe("the route health ledger", () => {
	it("T2 a transient failure below the threshold counts the streak and cools nothing", () => {
		const first = applyOutcome({ state: "eligible", streak: 0 }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(first, { state: "eligible", streak: 1 });
		const second = applyOutcome(first, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(second, { state: "eligible", streak: 2 });
		assert.equal(eligibleAt(second, NOW + 1), true, "the route stays dispatchable below the threshold");
	});

	it("T3 the transient failure at the threshold cools the route for the transient window", () => {
		const at = applyOutcome({ state: "eligible", streak: THRESHOLD - 1 }, transient(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(at, { state: "cooling", until: NOW + COOLDOWNS.transient, class: "transient" });
		assert.equal(eligibleAt(at, NOW + COOLDOWNS.transient - 1), false, "the route is skipped inside the window");
	});

	it("T4 a quota-class failure cools on the first occurrence, whatever the streak", () => {
		const zero = applyOutcome({ state: "eligible", streak: 0 }, limited(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(zero, { state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" });
		const many = applyOutcome({ state: "eligible", streak: 99 }, limited(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(many, { state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" });
	});

	it("T1 a success on an eligible route resets the streak", () => {
		const next = applyOutcome({ state: "eligible", streak: 2 }, ok(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(next, { state: "eligible", streak: 0 });
	});

	it("T5 a success on a cooling route clears the cooldown and the class", () => {
		const next = applyOutcome({ state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" }, ok(), NOW, THRESHOLD, COOLDOWNS);
		assert.deepEqual(next, { state: "eligible", streak: 0 });
		assert.equal(eligibleAt(next, NOW), true, "the route is dispatchable at once");
	});

	it("T6 a failure on a cooling route refreshes the deadline from the current class", () => {
		const transientCooling = { state: "cooling", until: NOW + 1000, class: "transient" } as const;
		const refreshed = applyOutcome(transientCooling, transient(), NOW + 5000, THRESHOLD, COOLDOWNS);
		assert.deepEqual(refreshed, { state: "cooling", until: NOW + 5000 + COOLDOWNS.transient, class: "transient" });
		const escalated = applyOutcome(transientCooling, limited(), NOW + 5000, THRESHOLD, COOLDOWNS);
		assert.deepEqual(escalated, { state: "cooling", until: NOW + 5000 + COOLDOWNS.limited, class: "limited" }, "a quota error extends a transient cooldown to the long window");
	});

	it("the eligibility guard derives a lapsed deadline at read time", () => {
		const cooling = { state: "cooling", until: NOW + 1000, class: "transient" } as const;
		assert.equal(eligibleAt(cooling, NOW + 999), false);
		assert.equal(eligibleAt(cooling, NOW + 1000), true, "the deadline lapsing is a read, not an event");
		assert.equal(eligibleAt(cooling, NOW + 100_000), true);
	});

	describe("the ledger file", () => {
		it("round-trips a cooling entry through the file", () => {
			const path = tempLedgerPath();
			try {
				const ledger = new Ledger(path);
				ledger.apply("opencode-go", "step-5-preview-free", limited(), NOW, THRESHOLD, COOLDOWNS);
				const onDisk = parseLedger(fs.readFileSync(path, "utf8"));
				assert.deepEqual(onDisk.get("opencode-go/step-5-preview-free"), { state: "cooling", until: NOW + COOLDOWNS.limited, class: "limited" });
			} finally {
				fs.rmSync(path, { force: true });
			}
		});

		it("keeps another writer's keys when one route's outcome merges", () => {
			const path = tempLedgerPath();
			try {
				fs.writeFileSync(path, `${JSON.stringify({ version: 1, routes: { "opencode-go/other-model": { state: "cooling", until: NOW + 5000, class: "transient" } } })}\n`, "utf8");
				const ledger = new Ledger(path);
				ledger.load();
				ledger.apply("opencode-go", "step-5-preview-free", ok(), NOW, THRESHOLD, COOLDOWNS);
				const onDisk = parseLedger(fs.readFileSync(path, "utf8"));
				assert.deepEqual(onDisk.get("opencode-go/other-model"), { state: "cooling", until: NOW + 5000, class: "transient" }, "the concurrent writer's key survives");
				assert.deepEqual(onDisk.get("opencode-go/step-5-preview-free"), { state: "eligible", streak: 0 });
			} finally {
				fs.rmSync(path, { force: true });
			}
		});

		it("a missing or corrupt file reads as an empty ledger", () => {
			const path = tempLedgerPath();
			try {
				fs.writeFileSync(path, "not json at all", "utf8");
				const ledger = new Ledger(path);
				ledger.load();
				assert.equal(ledger.eligible("opencode-go", "step-5-preview-free", NOW), true, "a damaged sidecar costs re-learning, not a refused session");
			} finally {
				fs.rmSync(path, { force: true });
			}
		});

		it("a file another version wrote reads as an empty ledger", () => {
			const path = tempLedgerPath();
			try {
				fs.writeFileSync(path, `${JSON.stringify({ version: 2, routes: { "opencode-go/step-5-preview-free": { state: "cooling", until: NOW + 9_999_999, class: "limited" } } })}\n`, "utf8");
				const ledger = new Ledger(path);
				ledger.load();
				assert.equal(ledger.eligible("opencode-go", "step-5-preview-free", NOW), true, "another version's state is not this version's shape, so it is re-learned");
			} finally {
				fs.rmSync(path, { force: true });
			}
		});
	});
});
