/**
 * The shipped pi config check: every model override in `models.json` names a
 * model pi's baked catalog carries, and every level the override names reaches
 * the wire.
 *
 * The defect this exists for. Three override keys named ids pi does not bake:
 * `deepseek-v4-flash` under `deepseek`, where the baked id is `deepseek-flash`,
 * and the two unprefixed ids under `openrouter`, where pi bakes
 * `deepseek/deepseek-v4-flash` and `deepseek/deepseek-v4-pro`. A stale key is
 * silent. pi applies no override, the baked map's `null` stands, and a request
 * for `low` clamps up to `high`, so the level the operator picked is not the
 * level the API receives. The key check catches that class; the printed table
 * shows what each level puts on the wire.
 *
 * Offline and inert. It reads pi's baked catalogs and drives pi's own request
 * builder with a `fetch` that refuses, so no key and no request are needed. It
 * reads the config beside the extension, so it skips in the mutation gate's
 * mirror, which copies the extension alone.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";
import * as path from "node:path";

import { THINKING_LEVELS } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/thinking.ts";
import type { ModelDefinition } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/types.ts";

const PI_PACKAGE_GLOBAL = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent";
const PI_AI = `${PI_PACKAGE_GLOBAL}/node_modules/@earendil-works/pi-ai`;
const BAKED_CATALOG = `${PI_AI}/dist/providers/all.js`;
const COMPOSER_ENTRY = `${PI_PACKAGE_GLOBAL}/dist/core/provider-composer.js`;
const COMPLETIONS_ENTRY = `${PI_AI}/dist/api/openai-completions.js`;
const EXTENSION_DIR = "src/reasoning/providers/pi/config/agent/extensions/model-refresh";
const MODELS_JSON = path.resolve(`${EXTENSION_DIR}/../../models.json`);

const available = fs.existsSync(BAKED_CATALOG) && fs.existsSync(COMPOSER_ENTRY) && fs.existsSync(MODELS_JSON);
const suite = available ? {} : { skip: "the pi installation or the shipped models.json is not present" };

/** One provider block of `models.json`, as pi reads it. */
interface ProviderConfig {
	modelOverrides?: Record<string, { thinkingLevelMap?: Record<string, string | null> }>;
}

interface ShippedConfig {
	providers: Record<string, ProviderConfig>;
}

async function loadPiModule<T>(entry: string): Promise<T> {
	return (await import(entry)) as T;
}

/** The effort a built payload carries, whichever field its transport uses. */
function wireEffort(payload: Record<string, unknown>): string | undefined {
	if (typeof payload.reasoning_effort === "string") return payload.reasoning_effort;
	const reasoning = payload.reasoning as { effort?: unknown } | undefined;
	if (reasoning && typeof reasoning.effort === "string") return reasoning.effort;
	return undefined;
}

/** The payload pi builds for one effective model at one level. */
async function builtPayload(model: ModelDefinition, level: string): Promise<Record<string, unknown>> {
	const { streamSimple } = await loadPiModule<{ streamSimple: (m: unknown, c: unknown, o: unknown) => { result: () => Promise<unknown> } }>(COMPLETIONS_ENTRY);
	let payload: Record<string, unknown> | undefined;
	const stream = streamSimple(model, { messages: [{ role: "user", content: "probe" }] }, {
		apiKey: "placeholder",
		reasoning: level,
		fetch: async () => {
			throw new Error("the config check refuses to send");
		},
		onPayload: (built: unknown) => {
			payload = built as Record<string, unknown>;
			return undefined;
		},
	});
	await stream.result().catch(() => undefined);
	assert.ok(payload, `pi built no payload for ${model.id} at level ${level}`);
	return payload!;
}

describe("the shipped pi model config", suite, () => {
	it("every override key names a model pi bakes, and every named level reaches the wire", async () => {
		const shipped = JSON.parse(fs.readFileSync(MODELS_JSON, "utf8")) as ShippedConfig;
		const { getBuiltinModels } = await loadPiModule<{ getBuiltinModels: (provider: string) => ModelDefinition[] }>(BAKED_CATALOG);
		const { composeModelProvider } = await loadPiModule<{ composeModelProvider: (id: string, base: unknown, config: unknown, ext: unknown) => { getModels: () => ModelDefinition[] } }>(COMPOSER_ENTRY);

		const rows: string[] = [];
		let checked = 0;
		for (const [providerId, providerConfig] of Object.entries(shipped.providers)) {
			const overrides = providerConfig.modelOverrides ?? {};
			const baked = getBuiltinModels(providerId);
			const bakedIds = new Set(baked.map((model) => model.id));
			for (const key of Object.keys(overrides)) {
				assert.ok(bakedIds.has(key), `${providerId}: the override key ${key} names no model pi bakes; it is a stale key, so nothing applies it`);
			}
			for (const [id, override] of Object.entries(overrides)) {
				const base = { id: providerId, name: providerId, auth: { apiKey: {} }, getModels: () => baked };
				const config = { getProvider: () => providerConfig, getProviderIds: () => [providerId] };
				const effective = composeModelProvider(providerId, base, config, undefined).getModels().find((model) => model.id === id);
				assert.ok(effective, `${providerId}: the effective model ${id} is served`);
				for (const [level, value] of Object.entries(override.thinkingLevelMap ?? {})) {
					assert.equal(effective!.thinkingLevelMap?.[level], value, `${providerId}/${id}: the override for ${level} reached the effective map`);
				}
				for (const level of THINKING_LEVELS) {
					if (level === "off") continue;
					const mapped = effective!.thinkingLevelMap?.[level];
					rows.push(`  ${providerId}/${id} ${level.padEnd(7)} -> ${mapped === undefined ? "(absent)" : JSON.stringify(mapped)}`);
					if (typeof mapped !== "string") continue;
					const payload = await builtPayload(effective!, level);
					checked++;
					assert.equal(wireEffort(payload), mapped, `${providerId}/${id}: level ${level} sends the mapped effort ${mapped} on the wire, not a clamp`);
				}
			}
		}
		assert.ok(checked > 0, "the shipped config names at least one level to check");
		process.stdout.write(`\nshipped pi config: the wire effort per level\n${rows.join("\n")}\n`);
	});
});
