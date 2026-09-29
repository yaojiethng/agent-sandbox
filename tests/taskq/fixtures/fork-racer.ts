/**
 * The second fork of the two-process fork race: a separate process that
 * loads the extension exactly as the pi runtime loads it and calls the
 * fork tool once, writing its outcome to its own file in the directory the
 * test names. Each racer owns one file - the result is never a shared
 * read-modify-write - so two racers reporting at once cannot lose one
 * outcome. The test drives the race; this file only plays the second
 * writer.
 */

import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";

const EXTENSION_ENTRY = path.resolve(import.meta.dirname, "../../../src/reasoning/providers/pi/config/agent/extensions/task-queue/index.ts");
const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;

const [cwd, taskId, outDir] = process.argv.slice(2);

const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
const { createJiti } = await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"));
const jiti = createJiti(EXTENSION_ENTRY, {
	alias: {
		"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
		"typebox": requireFromPi.resolve("typebox"),
		"@sinclair/typebox": requireFromPi.resolve("typebox"),
	},
});

const tools: Record<string, { execute: (...args: unknown[]) => Promise<{ details?: unknown }> }> = {};
const mod = (await jiti.import(EXTENSION_ENTRY)) as { default: (pi: { registerTool: (t: { name: string; execute: (...args: unknown[]) => Promise<{ details?: unknown }> }) => void }) => void };
mod.default({
	registerTool: (t) => {
		tools[t.name] = t;
	},
});

// The barrier: both racers are loaded and ready before either calls the
// tool, so the state directory's lock, not the load time, decides the
// winner.
const ready = path.join(outDir, `ready.${process.pid}`);
fs.writeFileSync(ready, "ready", "utf8");
const deadline = Date.now() + 30_000;
while (Date.now() < deadline && fs.readdirSync(outDir).filter((n) => n.startsWith("ready.")).length < 2) {
	// wait for the other racer
}

const outcome: { pid: number; ok: boolean; code?: string; message?: string } = { pid: process.pid, ok: false };
try {
	await tools.taskq_fork.execute("racer", { taskId }, undefined, undefined, { cwd, mode: "print", hasUI: false, ui: {} });
	outcome.ok = true;
} catch (err) {
	outcome.code = (err as { code?: string }).code;
	outcome.message = (err as { message?: string }).message;
}
// One file per racer: a shared file would need a read-modify-write, and two
// racers writing it at once lose one outcome.
fs.writeFileSync(path.join(outDir, `result.${process.pid}.json`), JSON.stringify(outcome), "utf8");
fs.rmSync(ready, { force: true });
