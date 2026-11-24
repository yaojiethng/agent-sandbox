/**
 * The title format: `π - <run id>`, or nothing.
 *
 * The case set covers the four inputs the builder can see: an id, a missing id,
 * an id carrying control bytes, and an id that is only whitespace.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { APP_MARK, sanitizeRunId, sessionTitle } from "../../../../src/reasoning/agent-runtime/pi/config/agent/extensions/session-title/title.ts";

describe("sessionTitle", () => {
	it("emits the app mark and the run id, and no other segment", () => {
		assert.equal(sessionTitle("f6e5d4"), `${APP_MARK} - f6e5d4`);
		assert.equal(sessionTitle("f6e5d4"), "π - f6e5d4");
	});

	it("returns undefined when there is no run id, so pi's title stands", () => {
		assert.equal(sessionTitle(undefined), undefined);
		assert.equal(sessionTitle(""), undefined);
	});

	it("drops control bytes rather than ending the title sequence early", () => {
		assert.equal(sessionTitle("f6e\u001b5d4"), `${APP_MARK} - f6e5d4`);
		assert.equal(sessionTitle("\u0007f6e5d4\u007f"), `${APP_MARK} - f6e5d4`);
	});

	it("treats a whitespace-only id as absent", () => {
		assert.equal(sessionTitle("   "), undefined);
	});
});

describe("sanitizeRunId", () => {
	it("returns the empty string for a missing value", () => {
		assert.equal(sanitizeRunId(undefined), "");
		assert.equal(sanitizeRunId(""), "");
	});

	it("keeps printable characters unchanged", () => {
		assert.equal(sanitizeRunId("f6e5d4"), "f6e5d4");
	});
});
