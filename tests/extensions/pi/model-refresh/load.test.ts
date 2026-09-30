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
	const module = await jiti.import<{ default: (pi: unknown) => void }>(EXTENSION_ENTRY);
	module.default({
		registerProvider: (name: string, config: Record<string, unknown>) => registrations.push({ name, config }),
	});
	return registrations;
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
});
