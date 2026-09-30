/**
 * The thinking-level map: what pi offers, and what it can actually send.
 *
 * The rules under test come from two places in pi-ai. `dist/models.js` decides
 * which levels a model advertises and how a requested level is clamped: an
 * absent map key counts as supported except for `xhigh` and `max`, which pi
 * advertises only when the map names them, and an unsupported level is clamped
 * to the nearest supported one, upward first. `dist/api/openai-completions.js`
 * decides what reaches the wire, where `compat.supportsReasoningEffort:
 * false` discards `reasoning_effort` at every level. A map that violates any of
 * them makes pi offer a level it cannot honour.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import {
	levelMapFor,
	offSendsAnEffort,
	thinkingLevelMapFromEfforts,
	THINKING_LEVELS,
} from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import { liveOnlyModelConfig } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/catalog.ts";

describe("thinkingLevelMapFromEfforts", () => {
	it("spells out every level pi knows, so an absent key is never ambiguous", () => {
		const map = thinkingLevelMapFromEfforts(["low", "high", "max"]);
		for (const level of THINKING_LEVELS) {
			assert.ok(level in map, `level ${level} has an explicit entry`);
		}
	});

	it("marks a level the provider does not advertise as unsupported, not as a hole", () => {
		const map = thinkingLevelMapFromEfforts(["low", "high", "max"]);
		assert.equal(map.low, "low");
		assert.equal(map.high, "high");
		assert.equal(map.max, "max");
		assert.equal(map.medium, null, "medium is explicitly unsupported");
		assert.equal(map.xhigh, null, "xhigh is explicitly unsupported");
		assert.equal(map.off, null, "off is explicitly unsupported: no none effort advertised");
	});

	it("maps a provider's none effort onto off", () => {
		const map = thinkingLevelMapFromEfforts(["none", "low", "high"]);
		assert.equal(map.off, "none");
		assert.equal(map.low, "low");
		assert.equal(map.medium, null);
	});

	it("keeps a usable range when the provider advertises no efforts at all", () => {
		const map = thinkingLevelMapFromEfforts([]);
		assert.equal(map.low, "low");
		assert.equal(map.high, "high");
		assert.equal(map.max, null, "the fallback stops at high, so a request for max is clamped down to high rather than answered with a level the endpoint never named");
		assert.equal(map.xhigh, null, "the fallback is contiguous, so xhigh is not skipped in favour of max");
		assert.equal(map.off, null, "no efforts means no off effort, so off stays unsupported");
	});

	it("ignores an effort name pi has no level for rather than inventing one", () => {
		const map = thinkingLevelMapFromEfforts(["low", "ultra-turbo"]);
		assert.equal(map.low, "low");
		assert.deepEqual(Object.keys(map).sort(), [...THINKING_LEVELS].sort(), "no extra level key appears");
	});
});

describe("offSendsAnEffort", () => {
	it("reports that an off mapping reaches the wire", () => {
		assert.equal(offSendsAnEffort({ off: "none" }), true);
	});

	it("reports that a null or absent off mapping sends no disable signal at all", () => {
		assert.equal(offSendsAnEffort({ off: null }), false);
		assert.equal(offSendsAnEffort({ low: "low" }), false, "an absent off key sends nothing");
		assert.equal(offSendsAnEffort(undefined), false);
	});
});

describe("levelMapFor", () => {
	it("uses the advertised list when there is one", () => {
		assert.equal(levelMapFor(["low", "high"], true).medium, null);
	});

	it("falls back to a usable range when the advertised list is empty or absent", () => {
		assert.equal(levelMapFor([], true).high, "high");
		assert.equal(levelMapFor(undefined, true).max, null, "the fallback range stops at high, so max is not advertised");
		assert.equal(levelMapFor(undefined, true).off, null);
	});
});

describe("liveOnlyModelConfig", () => {
	it("omits supportsReasoningEffort so pi auto-detects it from the endpoint", () => {
		const model = liveOnlyModelConfig("some-new-model", { reasoning_options: [{ type: "effort", values: ["low", "high"] }] });
		assert.ok(model.compat, "compat is present");
		assert.equal("supportsReasoningEffort" in (model.compat as object), false, "the flag is not set: it would suppress every level");
	});

	it("leaves thinkingFormat off the default path so a disabled level sends an effort", () => {
		const model = liveOnlyModelConfig("some-new-model", { reasoning_options: [{ type: "effort", values: ["none", "low"] }] });
		assert.equal((model.compat as { thinkingFormat?: string }).thinkingFormat, undefined, "not deepseek: off must not become thinking.disabled");
		assert.equal(model.thinkingLevelMap?.off, "none");
	});

	it("keeps the deepseek transport for a deepseek-family id with no advertised efforts", () => {
		const model = liveOnlyModelConfig("deepseek-v9-flash", undefined);
		assert.equal((model.compat as { thinkingFormat?: string }).thinkingFormat, "deepseek");
		assert.equal(model.api, "openai-completions");
		assert.equal(model.baseUrl, "https://opencode.ai/zen/go/v1");
	});

	it("stays reasoning-capable and usable when no catalog describes the model", () => {
		const model = liveOnlyModelConfig("unheard-of", undefined);
		assert.equal(model.reasoning, true, "reasoning defaults on: a null would hide the level picker");
		assert.equal(model.name, "unheard-of");
		assert.equal(model.contextWindow, 1_000_000);
		assert.equal(model.maxTokens, 131_072);
		assert.deepEqual(model.cost, { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 });
		assert.equal(model.thinkingLevelMap?.high, "high", "a usable level range survives");
	});
});
