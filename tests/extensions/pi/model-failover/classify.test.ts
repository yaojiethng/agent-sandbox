/**
 * The classification: the measured error texts of this deployment become
 * classes, and everything unmatched falls to the transient class, the one
 * that self-heals.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { classifyError, classifyOutcome } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts";

describe("the error classification", () => {
	const TRANSIENT = [
		'429: {"type":"server_error","message":"Upstream request failed: Endpoint is unavailable."}',
		'400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}',
		"Connection error.",
		"terminated",
		"Request timed out.",
		"Stream ended without finish_reason",
		"429: something nobody has seen before",
	];
	const LIMITED = [
		'429: {"type":"error","error":{"type":"GoUsageLimitError","message":"Go usage limit exceeded"}}',
		'429: {"type":"error","error":{"type":"FreeUsageLimitError","message":"Free usage limit exceeded"}}',
		'403: {"type":"FreeTierError","message":"OpenCode\'s free tier can only be used from within OpenCode"}',
		"Monthly usage limit reached",
		"available balance is too low",
		"quota exceeded",
		"insufficient_quota",
	];

	it("classifies every measured transient text as transient", () => {
		for (const text of TRANSIENT) {
			assert.equal(classifyError(text), "transient", text.slice(0, 60));
		}
	});

	it("classifies every measured limit text as limited", () => {
		for (const text of LIMITED) {
			assert.equal(classifyError(text), "limited", text.slice(0, 60));
		}
	});

	it("an unmatched error text falls to the transient class", () => {
		assert.equal(classifyError("a brand new failure mode"), "transient");
	});

	it("a finalized message with an error carries its class", () => {
		assert.deepEqual(classifyOutcome("error", "GoUsageLimitError"), { ok: false, class: "limited" });
		assert.deepEqual(classifyOutcome("error", "Endpoint is unavailable"), { ok: false, class: "transient" });
	});

	it("a finalized message with no error is a success, whatever its stop reason", () => {
		assert.deepEqual(classifyOutcome("stop", undefined), { ok: true });
		assert.deepEqual(classifyOutcome("toolUse", undefined), { ok: true });
		assert.deepEqual(classifyOutcome("stop", ""), { ok: true });
	});
});
