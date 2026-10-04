/**
 * Behavioural tests for `report.ts`, the module that decides where and when the
 * catalog transition is announced.
 *
 * The tests drive the reporter through the same surface pi hands an extension
 * (`notify`) and assert against literal expected strings, so a change to the
 * wording is a change a reader sees in the diff rather than a snapshot that
 * silently follows the code.
 *
 * Nothing here touches the console, a terminal, or the network: a fake UI
 * records the calls. That is the whole point of the module under test, so a
 * test that printed would be testing the thing it exists to prevent.
 */

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { createReporter, deltaLine, notices } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts";
import type { CatalogReport } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";

interface Call {
	method: string;
	args: unknown[];
}

/** A stand-in for pi's ExtensionUIContext that records what it was asked to show. */
function fakeUi() {
	const calls: Call[] = [];
	return {
		calls,
		notify: (message: string, type?: "info" | "warning" | "error") => calls.push({ method: "notify", args: [message, type] }),
	};
}

const CHANGED: CatalogReport = { providerId: "opencode-go", changed: true, added: 3, removed: 1, revised: 2, failures: [] };
const UNCHANGED: CatalogReport = { providerId: "opencode-go", changed: false, added: 0, removed: 0, revised: 0, failures: [] };

test("the delta line names the adds, the removes and the revisions", () => {
	assert.equal(deltaLine(CHANGED), "updated catalog: +3 / -1, 2 revised");
});

test("a report that changed renders the delta as info", () => {
	assert.deepEqual(notices(CHANGED), [{ message: "updated catalog: +3 / -1, 2 revised", type: "info" }]);
});

test("a report that did not change renders nothing", () => {
	assert.deepEqual(notices(UNCHANGED), [], "a transition that did not move announces nothing");
});

test("a failed source renders one warning carrying the reason", () => {
	const degraded: CatalogReport = { ...UNCHANGED, failures: ["endpoint fetch failed (HTTP 503)"] };
	assert.deepEqual(notices(degraded), [{ message: "endpoint fetch failed (HTTP 503)", type: "warning" }]);
});

test("a change and a failure render the delta first, then the failure", () => {
	const both: CatalogReport = { ...CHANGED, failures: ["endpoint fetch failed (HTTP 503)"] };
	assert.deepEqual(notices(both), [
		{ message: "updated catalog: +3 / -1, 2 revised", type: "info" },
		{ message: "endpoint fetch failed (HTTP 503)", type: "warning" },
	]);
});

test("a report recorded before any UI is held, not dropped", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.record(CHANGED);
	assert.deepEqual(ui.calls, [], "nothing is shown before a UI exists");
	assert.deepEqual(reporter.current(), CHANGED, "the report is still held");

	reporter.attach(ui);
	assert.deepEqual(ui.calls, [{ method: "notify", args: ["updated catalog: +3 / -1, 2 revised", "info"] }]);
});

test("a report recorded after the UI is attached is shown at once", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.record(CHANGED);
	assert.deepEqual(ui.calls, [{ method: "notify", args: ["updated catalog: +3 / -1, 2 revised", "info"] }]);
});

test("an unchanged report after an attached UI shows nothing at all", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.record(UNCHANGED);
	assert.deepEqual(ui.calls, []);
});

test("a second report replaces the held one rather than stacking an announcement", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.record(CHANGED);
	ui.calls.length = 0;
	reporter.record({ ...CHANGED, added: 4 });
	assert.deepEqual(ui.calls, [{ method: "notify", args: ["updated catalog: +4 / -1, 2 revised", "info"] }]);
});

test("attaching a UI with no report held shows nothing", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	assert.deepEqual(ui.calls, []);
});

test("the reporter never writes to the console", () => {
	// The reported defect: the extension logged to `console.warn`, the TUI owns
	// the terminal, and the raw line landed inside the rendered frame. The
	// regression is the console write, so the test asserts there is none.
	const written: string[] = [];
	const real = { log: console.log, warn: console.warn, error: console.error };
	console.log = (...a: unknown[]) => written.push(a.join(" "));
	console.warn = (...a: unknown[]) => written.push(a.join(" "));
	console.error = (...a: unknown[]) => written.push(a.join(" "));
	try {
		const reporter = createReporter();
		const ui = fakeUi();
		reporter.record({ ...CHANGED, failures: ["endpoint fetch failed (HTTP 503)"] });
		reporter.attach(ui);
		reporter.record(UNCHANGED);
	} finally {
		Object.assign(console, real);
	}
	assert.deepEqual(written, [], "the reporter writes nothing to the terminal");
});
