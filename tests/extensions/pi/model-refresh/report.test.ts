/**
 * Behavioural tests for `report.ts`, the module that decides where the catalog
 * reconciliation is shown.
 *
 * The tests drive the reporter through the same surface pi hands an extension
 * (`setStatus`, `setWorkingMessage`, `notify`) and assert against literal
 * expected strings, so a change to the wording is a change a reader sees in
 * the diff rather than a snapshot that silently follows the code.
 *
 * Nothing here touches the console, a terminal, or the network: a fake UI
 * records the calls. That is the whole point of the module under test, so a
 * test that printed would be testing the thing it exists to prevent.
 */

import { strict as assert } from "node:assert";
import { test } from "node:test";

import { completion, createReporter, STATUS_KEY, WORKING_MESSAGE, summarize } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/report.ts";
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
		setStatus: (key: string, text: string | undefined) => calls.push({ method: "setStatus", args: [key, text] }),
		setWorkingMessage: (message?: string) => calls.push({ method: "setWorkingMessage", args: [message] }),
		notify: (message: string, type?: "info" | "warning" | "error") => calls.push({ method: "notify", args: [message, type] }),
	};
}

const FULL: CatalogReport = {
	providerId: "opencode-go",
	endpoint: 43,
	modelsDev: 33,
	baked: 29,
	stored: 30,
	served: 47,
	failures: [],
};

test("a full reconciliation reads as one line naming every source", () => {
	assert.equal(summarize(FULL), "opencode-go: 47 served, baked 29, store 30, endpoint 43, models.dev 33");
});

test("a source that was not reached is named skipped, not zero", () => {
	const partial: CatalogReport = { ...FULL, endpoint: undefined, modelsDev: undefined };
	assert.equal(
		summarize(partial),
		"opencode-go: 47 served, baked 29, store 30, endpoint skipped, models.dev skipped",
	);
});

test("a failed source is counted on the summary line", () => {
	const degraded: CatalogReport = { ...FULL, endpoint: undefined, failures: ["endpoint fetch failed (HTTP 503)"] };
	assert.equal(
		summarize(degraded),
		"opencode-go: 47 served, baked 29, store 30, endpoint skipped, models.dev 33 (1 source(s) failed)",
	);
});

test("a clean completion notifies as info and repeats the summary", () => {
	assert.deepEqual(completion(FULL), {
		message: "Model catalogs refreshed. opencode-go: 47 served, baked 29, store 30, endpoint 43, models.dev 33",
		type: "info",
	});
});

test("a degraded completion notifies as warning and carries the reason", () => {
	const done = completion({ ...FULL, endpoint: undefined, failures: ["endpoint fetch failed (HTTP 503)"] });
	assert.equal(done.type, "warning");
	assert.equal(
		done.message,
		"Model catalogs refreshed. opencode-go: 47 served, baked 29, store 30, endpoint skipped, models.dev 33 " +
			"(1 source(s) failed). endpoint fetch failed (HTTP 503)",
	);
});

test("a report recorded before any UI is held, not dropped", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.record(FULL);
	assert.deepEqual(ui.calls, [], "nothing is shown before a UI exists");
	assert.deepEqual(reporter.current(), FULL, "the report is still held");

	reporter.attach(ui);
	assert.deepEqual(ui.calls, [
		{ method: "setStatus", args: [STATUS_KEY, "opencode-go: 47 served, baked 29, store 30, endpoint 43, models.dev 33"] },
		{ method: "notify", args: ["Model catalogs refreshed. opencode-go: 47 served, baked 29, store 30, endpoint 43, models.dev 33", "info"] },
	]);
});

test("a report recorded after the UI is attached is shown at once", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.record(FULL);
	assert.equal(ui.calls.length, 2);
	assert.equal(ui.calls[0].method, "setStatus");
	assert.equal(ui.calls[1].method, "notify");
});

test("a second refresh replaces the row rather than stacking one", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.record(FULL);
	ui.calls.length = 0;
	reporter.record({ ...FULL, served: 48, endpoint: 44 });
	assert.deepEqual(ui.calls[0], {
		method: "setStatus",
		args: [STATUS_KEY, "opencode-go: 48 served, baked 29, store 30, endpoint 44, models.dev 33"],
	});
});

test("begin sets the working message and end restores the default", () => {
	const reporter = createReporter();
	const ui = fakeUi();
	reporter.attach(ui);
	reporter.begin();
	assert.deepEqual(ui.calls, [{ method: "setWorkingMessage", args: [WORKING_MESSAGE] }]);
	reporter.end();
	assert.deepEqual(ui.calls[1], { method: "setWorkingMessage", args: [undefined] });
});

test("begin before a UI exists is inert rather than throwing", () => {
	const reporter = createReporter();
	reporter.begin();
	assert.equal(reporter.current(), undefined);
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
		reporter.record({ ...FULL, endpoint: undefined, failures: ["endpoint fetch failed (HTTP 503)"] });
		reporter.begin();
		reporter.attach(ui);
		reporter.record(FULL);
		reporter.end();
	} finally {
		Object.assign(console, real);
	}
	assert.deepEqual(written, [], "the reporter writes nothing to the terminal");
});
