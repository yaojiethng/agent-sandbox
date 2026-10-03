/**
 * The pi wiring: the extension factory loads under jiti with pi's package
 * aliases and registers the full tool surface: the fork, the join, the
 * bring-back gates, the close, the observability, and the worker side. The
 * real pi runtime is not booted here (that needs a model); this test proves
 * the module graph, the schema construction, and the registration surface.
 * It skips when the pi installation is not resolvable from this environment.
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
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;

function piAvailable(): boolean {
	return fs.existsSync(PI_PACKAGE_ENTRY);
}

describe("extension load under jiti", () => {
	it("registers the full task-queue tool surface", { skip: !piAvailable() && "pi installation not present" }, async () => {
		const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
		const { createJiti } = await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"));
		const jiti = createJiti(EXTENSION_ENTRY, {
			alias: {
				"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
				"typebox": requireFromPi.resolve("typebox"),
				"@sinclair/typebox": requireFromPi.resolve("typebox"),
			},
		});
		const registered: string[] = [];
		const mockPi = {
			registerTool: (tool: { name: string }) => {
				registered.push(tool.name);
			},
		};
		const mod = (await jiti.import(EXTENSION_ENTRY)) as { default: (pi: unknown) => void };
		mod.default(mockPi);
		const expected = [
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
		assert.deepEqual(registered, expected);
	});

	it("registers no intermediate break-point tool: the join is the only path", { skip: !piAvailable() && "pi installation not present" }, async () => {
		const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
		const { createJiti } = await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"));
		const jiti = createJiti(EXTENSION_ENTRY, {
			alias: {
				"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
				"typebox": requireFromPi.resolve("typebox"),
				"@sinclair/typebox": requireFromPi.resolve("typebox"),
			},
		});
		const registered: { name: string; description: string; snippet?: string }[] = [];
		const mod = (await jiti.import(EXTENSION_ENTRY)) as { default: (pi: unknown) => void };
		mod.default({ registerTool: (tool: { name: string; description: string; promptSnippet?: string }) => registered.push(tool) });
		// The four-call driver chain is subsumed by the join, so no tool
		// exposes an intermediate break-point state to drive (S3).
		for (const gone of ["taskq_poll", "taskq_record", "taskq_schedule", "taskq_trigger", "taskq_retire"]) {
			assert.ok(!registered.some((t) => t.name === gone), `${gone} must not be registered`);
		}
		// The fork takes no workdir: the tool owns the location (W1, W3).
		const fork = registered.find((t) => t.name === "taskq_fork");
		assert.ok(fork, "taskq_fork is registered");
		assert.ok(fork.description.includes("owns the location"), "the fork description states that the tool owns the location");
		// The join states its contract in the description the model reads.
		const join = registered.find((t) => t.name === "taskq_join");
		assert.ok(join, "taskq_join is registered");
		for (const term of ["Block until", "timeoutMs", "inert", "fork(2)/wait(2)"]) {
			assert.ok(join.description.includes(term), `the join description states "${term}"`);
		}
	});
});