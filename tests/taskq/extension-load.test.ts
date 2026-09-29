/**
 * The pi wiring: the extension factory loads under jiti with pi's package
 * aliases and registers the full tool surface. The real pi runtime is not
 * booted here (that needs a model); this test proves the module graph, the
 * schema construction, and the registration surface. It skips when the pi
 * installation is not resolvable from this environment.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";

const EXTENSION_ENTRY = path.resolve(
	import.meta.dirname,
	"../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts",
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
			"taskq_poll",
			"taskq_record",
			"taskq_schedule",
			"taskq_trigger",
			"taskq_verify",
			"taskq_proposal",
			"taskq_merge",
			"taskq_retire",
			"taskq_close",
			"taskq_status",
			"taskq_worker_request",
		];
		assert.deepEqual(registered, expected);
	});
});