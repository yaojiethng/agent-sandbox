/**
 * The pi wiring: the factory registers one virtual model per chain, the
 * observer classifies each finalized assistant message, and every classified
 * outcome appends exactly one tracking entry to the session log (TI4, R7).
 *
 * The pi surface is a small fake here: the factory touches only
 * `registerVirtualModel` and `on`, so the fake captures both and the test
 * drives the handlers the way the runtime does.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import factory from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/index.ts";
import { parseLedger } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/ledger.ts";
import { tempLedgerPath } from "./helpers.ts";

/** The captured virtual model registration. */
export interface Captured {
	route: (request: unknown, ctx: unknown) => unknown;
}

/** The minimal pi surface the factory uses. */
function fakePi() {
	const virtuals: Captured[] = [];
	const entries: { customType: string; data: unknown }[] = [];
	const handlers = new Map<string, ((event: unknown, ctx: unknown) => void)[]>();
	return {
		virtuals,
		entries,
		handlers,
		pi: {
			registerVirtualModel: (definition: { route: Captured["route"] }) => virtuals.push(definition),
			on: (event: string, handler: (event: unknown, ctx: unknown) => void) => {
				const list = handlers.get(event) ?? [];
				list.push(handler);
				handlers.set(event, list);
			},
			// The tracking entries pi persists beside the transcript.
			appendEntry: (customType: string, data: unknown) => entries.push({ customType, data }),
		},
	};
}

/** A finalized assistant message, as pi hands one to message_end. */
function assistantMessage(overrides: Record<string, unknown>): Record<string, unknown> {
	return { role: "assistant", provider: "opencode-go", model: "step-5-preview-free", api: "openai-completions", stopReason: "stop", ...overrides };
}


/** The ctx a message_end handler receives; the observer reads only the event. */
function ctxStub(): unknown {
	return {};
}

/** A ctx whose registry resolves every pair to a stub model. */
function registryCtx() {
	return { modelRegistry: { find: (provider: string, model: string) => ({ provider, id: model, api: "openai-completions" }) } };
}

/** A route request for the chain's virtual model. */
function routeRequest(reason: string, previous?: { provider: string; id: string }): Record<string, unknown> {
	return { model: { provider: "failover", id: "step-5-preview-free" }, thinkingLevel: "medium", reason, messages: [], signal: undefined, ...(previous === undefined ? {} : { previous: { model: previous } }) };
}

describe("the pi wiring", () => {
	it("the factory registers one virtual model per declared chain", () => {
		const ledgerPath = tempLedgerPath();
		process.env.MODEL_FAILOVER_LEDGER = ledgerPath;
		try {
			const fake = fakePi();
			factory(fake.pi as never);
			assert.equal(fake.virtuals.length, 1, "the shipped declarations file carries one chain");
			assert.ok(fake.handlers.has("session_start"), "the ledger loads at session start");
			assert.ok(fake.handlers.has("message_end"), "the outcome observer is wired");
		} finally {
			delete process.env.MODEL_FAILOVER_LEDGER;
			fs.rmSync(ledgerPath, { force: true });
		}
	});

	it("the route callback dispatches the chain's route as a physical model", () => {
		const ledgerPath = tempLedgerPath();
		process.env.MODEL_FAILOVER_LEDGER = ledgerPath;
		try {
			const fake = fakePi();
			factory(fake.pi as never);
			const choice = fake.virtuals[0].route(routeRequest("user"), registryCtx());
			assert.deepEqual(choice, { model: { provider: "opencode-go", id: "step-5-preview-free", api: "openai-completions" }, thinkingLevel: "medium" });
		} finally {
			delete process.env.MODEL_FAILOVER_LEDGER;
			fs.rmSync(ledgerPath, { force: true });
		}
	});

	it("TI4 every classified outcome appends exactly one tracking entry", () => {
		const ledgerPath = tempLedgerPath();
		process.env.MODEL_FAILOVER_LEDGER = ledgerPath;
		try {
			const fake = fakePi();
			factory(fake.pi as never);
			const [observer] = fake.handlers.get("message_end") ?? [];
			observer({ type: "message_end", message: assistantMessage({ stopReason: "error", errorMessage: '429: {"type":"server_error","message":"Upstream request failed: Endpoint is unavailable."}' }) }, ctxStub());
			assert.equal(fake.entries.length, 1, "one outcome, one entry");
			const [entry] = fake.entries;
			assert.equal(entry.customType, "model-failover/outcome");
			assert.deepEqual(entry.data, {
				chainId: "step-5-preview-free",
				provider: "opencode-go",
				model: "step-5-preview-free",
				ok: false,
				class: "transient",
				state: "eligible",
				streak: 1,
				ts: (entry.data as { ts: number }).ts,
			});
			const onDisk = parseLedger(fs.readFileSync(ledgerPath, "utf8"));
			assert.deepEqual(onDisk.get("opencode-go/step-5-preview-free"), { state: "eligible", streak: 1 }, "the first failure is below the threshold, so the route is still eligible");
		} finally {
			delete process.env.MODEL_FAILOVER_LEDGER;
			fs.rmSync(ledgerPath, { force: true });
		}
	});

	it("an outcome for a physical pair no chain declares is not recorded", () => {
		const ledgerPath = tempLedgerPath();
		process.env.MODEL_FAILOVER_LEDGER = ledgerPath;
		try {
			const fake = fakePi();
			factory(fake.pi as never);
			const [observer] = fake.handlers.get("message_end") ?? [];
			observer({ type: "message_end", message: assistantMessage({ model: "some-other-model", stopReason: "error", errorMessage: "429 Endpoint is unavailable" }) }, ctxStub());
			assert.equal(fake.entries.length, 0, "a manual model selection stays outside the ledger (S1)");
		} finally {
			delete process.env.MODEL_FAILOVER_LEDGER;
			fs.rmSync(ledgerPath, { force: true });
		}
	});

	it("a success appends its entry and the ledger returns the route to eligible", () => {
		const ledgerPath = tempLedgerPath();
		process.env.MODEL_FAILOVER_LEDGER = ledgerPath;
		try {
			const fake = fakePi();
			factory(fake.pi as never);
			const [observer] = fake.handlers.get("message_end") ?? [];
			observer({ type: "message_end", message: assistantMessage({ stopReason: "error", errorMessage: "GoUsageLimitError: Go usage limit exceeded" }) }, ctxStub());
			observer({ type: "message_end", message: assistantMessage({ stopReason: "stop" }) }, ctxStub());
			assert.equal(fake.entries.length, 2);
			assert.deepEqual(fake.entries[1].data, {
				chainId: "step-5-preview-free",
				provider: "opencode-go",
				model: "step-5-preview-free",
				ok: true,
				state: "eligible",
				streak: 0,
				ts: (fake.entries[1].data as { ts: number }).ts,
			});
		} finally {
			delete process.env.MODEL_FAILOVER_LEDGER;
			fs.rmSync(ledgerPath, { force: true });
		}
	});
});
