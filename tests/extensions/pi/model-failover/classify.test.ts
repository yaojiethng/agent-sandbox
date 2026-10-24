/**
 * The classification: the measured error texts of this deployment become a
 * verdict, and the verdict becomes the cooldown a route earns.
 *
 * The recoverable texts are the ones a retry can fix. The unrecoverable ones
 * name something outside the call that has to change first, and they are the
 * 28 rows of the measured corpus that the previous two-value classifier called
 * recoverable.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { classifyError, classifyOutcome, classifyVerdict, isAborted } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/classify.ts";

describe("the error classification", () => {
	const TRANSIENT = [
		'429: {"type":"server_error","message":"Upstream request failed: Endpoint is unavailable."}',
		"Connection error.",
		"terminated",
		"Request timed out.",
		"Stream ended without finish_reason",
		"429: something nobody has seen before",
		"503 status code (no body)",
		"Provider finish_reason: network_error",
	];
	const ACCOUNT = [
		'429: {"type":"error","error":{"type":"GoUsageLimitError","message":"Go usage limit exceeded"}}',
		'429: {"type":"error","error":{"type":"FreeUsageLimitError","message":"Free usage limit exceeded"}}',
		"Monthly usage limit reached",
		"quota exceeded",
		"insufficient_quota",
		'401: {"type":"AuthError","message":"Invalid API key."}',
		"401 Authentication Fails, Your api key: ****_KEY is invalid",
		'402: {"type":"server_error","message":"Upstream request failed: Insufficient account funds"}',
	];
	const PROVIDER = [
		'403: {"type":"FreeTierError","message":"OpenCode\'s free tier can only be used from within OpenCode"}',
		"Provider is not configured: opencode-go",
		"404 <!DOCTYPE html><html><title>Not Found</title></html>",
	];
	const MODEL = [
		'403 {"type":"error","error":{"type":"api_error","message":"Upstream request failed: Model access is disabled"}}',
		'400: {"type":"server_error","message":"Upstream request failed: Model is unavailable."}',
	];
	const REQUEST = [
		"400 Failed to deserialize the JSON body into the target type: reasoning_effort: unknown variant `minimal`",
		'400: {"type":"invalid_request_error","message":"Upstream request failed: [invalid_request_error] invalid request"}',
		"400 The `reasoning_content` in the thinking mode must be passed back to the API.",
	];

	it("classifies every measured transient text as recoverable", () => {
		for (const text of TRANSIENT) {
			assert.equal(classifyVerdict(text).recoverable, true, text.slice(0, 60));
			assert.equal(classifyError(text), "transient", text.slice(0, 60));
		}
	});

	it("names the scope that has to change before a retry can succeed", () => {
		for (const [texts, scope] of [[ACCOUNT, "account"], [PROVIDER, "provider"], [MODEL, "model"], [REQUEST, "request"]]) {
			for (const text of texts) {
				assert.equal(classifyVerdict(text).scope, scope, text.slice(0, 60));
				assert.equal(classifyError(text), "limited", text.slice(0, 60));
			}
		}
	});

	it("an unmatched error text is unrecoverable, the loud direction", () => {
		assert.deepEqual(classifyVerdict("a brand new failure mode"), { recoverable: false, scope: "unclassified" });
	});

	it("a cancelled turn is not the route's failure", () => {
		assert.equal(isAborted("This operation was aborted"), true);
		assert.equal(isAborted("Operation aborted"), true);
		assert.equal(isAborted("Stream ended without finish_reason"), false);
	});

	it("an unfunded balance is the account's, even when the body carries a request error code", () => {
		const balance = '402: {"message":"Insufficient Balance (request_id: 9cf76f00)","type":"unknown_error","code":"invalid_request_error"}';
		assert.deepEqual(classifyOutcome("error", balance), { ok: false, class: "limited", scope: "account" });
		assert.equal(classifyVerdict(balance).recoverable, false, "an unfunded account is never retried");
	});

	it("a finalized message with an error carries its class and the scope that says what must change", () => {
		assert.deepEqual(classifyOutcome("error", "GoUsageLimitError"), { ok: false, class: "limited", scope: "account" });
		assert.deepEqual(classifyOutcome("error", "Endpoint is unavailable"), { ok: false, class: "transient", scope: "none" });
		assert.deepEqual(classifyOutcome("error", "400 invalid_request_error: reasoning_effort: unknown variant `minimal`"), { ok: false, class: "limited", scope: "request" });
		assert.deepEqual(classifyOutcome("error", "something no pattern knows"), { ok: false, class: "limited", scope: "unclassified" });
	});

	it("a cancelled turn recorded as an error is a success, because nothing failed", () => {
		assert.deepEqual(classifyOutcome("error", "This operation was aborted"), { ok: true });
	});

	it("a finalized message with no error is a success, whatever its stop reason", () => {
		assert.deepEqual(classifyOutcome("stop", undefined), { ok: true });
		assert.deepEqual(classifyOutcome("toolUse", undefined), { ok: true });
		assert.deepEqual(classifyOutcome("stop", ""), { ok: true });
	});
});
