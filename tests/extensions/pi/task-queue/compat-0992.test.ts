/**
 * The task-queue extension against a second pi release. `extension-load.test.ts`
 * pins the wiring against the installed pi; this file proves the same module
 * graph resolves and the same factory runs against pi 0.99.2, held in a separate
 * install. The value is in the second release being a different build: an
 * extension that survives it does not pin an internal shape of the installed one.
 *
 * Each target is aliased wholesale. `@earendil-works/pi-coding-agent` resolves
 * to that release's own `dist/index.js` and `typebox` to that release's own copy,
 * so nothing in the graph leaks back to the installed pi. jiti itself is the
 * loader, not a pi package, so it is taken from the installed pi in both runs.
 *
 * The real pi runtime is not booted here, because that needs a model. What is
 * asserted is what a break shows up in: the module graph resolving, and the
 * factory reaching `registerTool` with the full tool surface.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";

const EXTENSION_ENTRY = path.resolve(
	import.meta.dirname,
	"../../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts",
);

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const JITI_LIB = path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs");

/** A pi install the extension is loaded against. */
type Target = {
	/** How the target is named in the test output. */
	label: string;
	/** The package entry the extension's pi import is aliased to. */
	entry: string;
	/** Why the target cannot run, or null when it can. */
	unavailable: string | null;
};

/** Build a target, and name the reason it cannot run when it is not usable. */
function targetFor(label: string, packageRoot: string, expectedVersion: string | null): Target {
	const entry = path.join(packageRoot, "dist", "index.js");
	const unavailable = (reason: string): Target => ({ label, entry, unavailable: reason });
	if (!fs.existsSync(entry)) return unavailable(`${label} is not installed at ${packageRoot}`);
	if (!fs.existsSync(JITI_LIB)) return unavailable("jiti is not present in the installed pi");
	if (expectedVersion !== null) {
		const reported: unknown = JSON.parse(fs.readFileSync(path.join(packageRoot, "package.json"), "utf8")).version;
		if (reported !== expectedVersion) return unavailable(`${label} reports version ${reported}, not ${expectedVersion}`);
	}
	return { label, entry, unavailable: null };
}

const INSTALLED = targetFor("the installed pi", PI_PACKAGE_GLOBAL, null);
const PROBE_ROOT = "/tmp/picheck/probe99/node_modules/@earendil-works/pi-coding-agent";
const PROBE_099 = targetFor("pi 0.99.2", PROBE_ROOT, "0.99.2");

const TARGETS = [INSTALLED, PROBE_099];

const EXPECTED_TOOLS = [
	"taskq_fork",
	"taskq_join",
	"taskq_verify",
	"taskq_proposal",
	"taskq_merge",
	"taskq_requeue",
	"taskq_close",
	"taskq_status",
	"taskq_worker_request",
];

/** Load the extension against one target and run its factory on a stub. */
async function loadAndRegister(target: Target) {
	const requireFromTarget = createRequire(target.entry);
	const { createJiti } = await import(JITI_LIB);
	const jiti = createJiti(EXTENSION_ENTRY, {
		alias: {
			"@earendil-works/pi-coding-agent": target.entry,
			"typebox": requireFromTarget.resolve("typebox"),
			"@sinclair/typebox": requireFromTarget.resolve("typebox"),
		},
	});
	const registered: { name: string; description: string }[] = [];
	const module = await jiti.import<{ default: (pi: unknown) => void }>(EXTENSION_ENTRY);
	assert.equal(typeof module.default, "function", `${target.label}: the extension entry resolves to a factory`);
	module.default({
		registerTool: (tool: { name: string; description: string }) => registered.push(tool),
	});
	return registered;
}

describe("task-queue compatibility across pi releases", () => {
	for (const target of TARGETS) {
		const skip = target.unavailable === null ? false : target.unavailable;

		it(`resolves the module graph against ${target.label}`, { skip }, async () => {
			const registered = await loadAndRegister(target);
			assert.ok(Array.isArray(registered));
		});

		it(`runs the factory and registers the full tool surface against ${target.label}`, { skip }, async () => {
			const registered = await loadAndRegister(target);
			assert.deepEqual(
				registered.map((tool) => tool.name),
				EXPECTED_TOOLS,
				`${target.label}: a release that drops or renames a tool breaks the extension's contract with the model`,
			);
		});

		it(`builds a usable schema for every tool against ${target.label}`, { skip }, async () => {
			const registered = await loadAndRegister(target);
			for (const tool of registered) {
				assert.equal(typeof tool.description, "string", `${tool.name} carries a description`);
				assert.ok(tool.description.length > 0, `${tool.name} carries a non-empty description`);
			}
		});
	}
});