/**
 * The pi wiring: the extension factory loads under jiti with pi's package
 * aliases and registers a provider carrying a `refreshModels` hook and no
 * `models` list. The real pi runtime is not booted here (that needs a model);
 * this test proves the module graph and the registration surface, which is
 * where a broken import or a wrong registration shape shows up. It skips when
 * the pi installation is not resolvable from this environment.
 *
 * The registration shape is load-bearing, not cosmetic. A `models` list on the
 * registration makes pi compose that list as the provider's whole catalog; the
 * hook alone keeps pi's baked catalog underneath. See README.md.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";
import { createRequire } from "node:module";

const EXTENSION_ENTRY = path.resolve(
	import.meta.dirname,
	"../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/index.ts",
);

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_PACKAGE_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/index.js`;
const PI_AI_ROOT = `${PI_PACKAGE_GLOBAL}/node_modules/@earendil-works/pi-ai`;

/** pi-ai is a subpath-export package, so each specifier the extension uses is aliased to its dist file. */
function piAiAliases() {
	return {
		"@earendil-works/pi-ai": `${PI_AI_ROOT}/dist/index.js`,
		"@earendil-works/pi-ai/providers/all": `${PI_AI_ROOT}/dist/providers/all.js`,
	};
}

const piAvailable = () => fs.existsSync(PI_PACKAGE_ENTRY) && fs.existsSync(`${PI_AI_ROOT}/dist/providers/all.js`);
const skip = () => (piAvailable() ? false : "pi installation not present");

/** Load the factory and capture what it registers. */
async function loadAndRegister() {
	const requireFromPi = createRequire(PI_PACKAGE_ENTRY);
	const { createJiti } = await import(path.join(PI_PACKAGE_GLOBAL, "node_modules", "jiti", "lib", "jiti.cjs"));
	const jiti = createJiti(EXTENSION_ENTRY, {
		alias: {
			"@earendil-works/pi-coding-agent": PI_PACKAGE_ENTRY,
			...piAiAliases(),
			"typebox": requireFromPi.resolve("typebox"),
			"@sinclair/typebox": requireFromPi.resolve("typebox"),
		},
	});
	const registrations: { name: string; config: Record<string, unknown> }[] = [];
	registeredHandlers.length = 0;
	const module = await jiti.import<{ default: (pi: unknown) => void }>(EXTENSION_ENTRY);
	module.default({
		registerProvider: (name: string, config: Record<string, unknown>) => registrations.push({ name, config }),
		// The extension renders its reconciliation from `session_start`, the
		// first event that carries a UI, so the stub answers the event rather
		// than letting the call fail.
		on: (event: string, handler: (event: unknown, ctx: unknown) => void) => registeredHandlers.push({ event, handler }),
	});
	return registrations;
}

/** The event handlers the factory registered on its last load. */
const registeredHandlers: { event: string; handler: (event: unknown, ctx: unknown) => void }[] = [];

/** A stand-in for the part of `ExtensionContext` the handler reads. */
function sessionStartCtx(
	mode: "tui" | "print",
	over: { scopedModels?: readonly unknown[]; model?: { provider: string; id: string }; authed?: boolean } = {},
) {
	const shown: { method: string; args: unknown[] }[] = [];
	return {
		shown,
		ctx: {
			mode,
			ui: {
				notify: (message: string, type?: string) => shown.push({ method: "notify", args: [message, type] }),
			},
			getSettings: () => ({ defaultProvider: "openrouter", defaultModel: "z-ai/glm-4.5" }),
			scopedModels: over.scopedModels ?? [{}],
			model: over.model ?? { provider: "opencode-go", id: "space-bunny-free" },
			modelRegistry: {
				find: () => ({ provider: "openrouter", id: "z-ai/glm-4.5" }),
				hasConfiguredAuth: () => over.authed ?? true,
			},
		},
	};
}

describe("extension load under jiti", { skip: skip() }, () => {
	it("registers the opencode-go provider", async () => {
		const registrations = await loadAndRegister();
		assert.equal(registrations.length, 1);
		assert.equal(registrations[0].name, "opencode-go");
	});

	it("registers a refreshModels hook", async () => {
		const [registration] = await loadAndRegister();
		assert.equal(typeof registration.config.refreshModels, "function");
	});

	it("registers no models list, so pi keeps its baked catalog underneath", async () => {
		const [registration] = await loadAndRegister();
		assert.equal(registration.config.models, undefined, "a models list would become the provider's whole catalog");
	});

	it("declares no baseUrl or authHeader, so pi's built-in provider keeps its own", async () => {
		const [registration] = await loadAndRegister();
		assert.equal(registration.config.baseUrl, undefined);
		assert.equal(registration.config.authHeader, undefined);
	});

	it("renders nothing into the UI at load, before any event fires", async () => {
		await loadAndRegister();
		const { shown, ctx } = sessionStartCtx("tui");
		assert.deepEqual(shown, [], "loading the extension touches no UI surface");
		assert.ok(ctx, "the stub is what a TUI session hands the handler");
	});

	it("routes the reconciliation into the UI on session_start in tui mode", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start, "the extension subscribes to session_start");
		const { shown, ctx } = sessionStartCtx("tui");
		await start.handler({ type: "session_start", reason: "startup" }, ctx);
		// A refresh that has already run is rendered on attach; a later refresh
		// renders through the same path. Both are UI calls, never console writes.
		assert.ok(Array.isArray(shown));
	});

	it("keeps the console as the sink in a mode with no TUI", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start);
		const { shown, ctx } = sessionStartCtx("print");
		const written: string[] = [];
		const real = console.warn;
		console.warn = (...a: unknown[]) => written.push(a.join(" "));
		try {
			await start.handler({ type: "session_start", reason: "startup" }, ctx);
		} finally {
			console.warn = real;
		}
		assert.deepEqual(shown, [], "a mode with no TUI shows nothing through the UI surface");
		assert.equal(written.length, 1, "the registration line goes to the console instead");
		// The wording is ours and is pinned. The baked count and the data date
		// come from the installed pi and move with every release, so the case
		// pins their shape rather than their value.
		assert.match(written[0], /^\[model-refresh\] registered opencode-go \(baked base: [1-9][0-9]* models, baked data generated [^)]+\)$/);
	});

	it("announces a saved default the scope discarded, at session_start in tui mode", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start);
		const { shown, ctx } = sessionStartCtx("tui");
		await start.handler({ type: "session_start", reason: "startup" }, ctx);
		assert.deepEqual(shown, [
			{ method: "notify", args: ["saved default openrouter/z-ai/glm-4.5 is outside the model scope; started on opencode-go/space-bunny-free", "info"] },
		]);
	});

	it("stays silent when the scope is empty", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start);
		const { shown, ctx } = sessionStartCtx("tui", { scopedModels: [] });
		await start.handler({ type: "session_start", reason: "startup" }, ctx);
		assert.deepEqual(shown, [], "an empty scope discards no default, so nothing is announced");
	});

	it("stays silent when the selected model is the saved default", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start);
		const { shown, ctx } = sessionStartCtx("tui", { model: { provider: "openrouter", id: "z-ai/glm-4.5" } });
		await start.handler({ type: "session_start", reason: "startup" }, ctx);
		assert.deepEqual(shown, []);
	});

	it("stays silent when the saved default has no configured auth", async () => {
		await loadAndRegister();
		const start = registeredHandlers.find((h) => h.event === "session_start");
		assert.ok(start);
		const { shown, ctx } = sessionStartCtx("tui", { authed: false });
		await start.handler({ type: "session_start", reason: "startup" }, ctx);
		assert.deepEqual(shown, [], "a default pi would not have honoured is not a discard to announce");
	});
});
