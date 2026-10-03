/**
 * Knowledge test: the request shape pi puts on the wire for a thinking level.
 *
 * The seam is pi-ai's request builder, an external library this repository does
 * not maintain, so these are knowledge assertions under the Test Placement rule
 * rather than acceptance criteria for our own code. The file sits with the
 * suite for locality and is excluded from `make test` because the whole
 * `tests/extensions/` tree is unwired; the roadmap row owns that wiring.
 *
 * It is also the assumption most likely to stop being true. A pi release that
 * changes the thinking-format handling changes every assertion here, which is
 * why the extension README's assumption table names the code each row rests on.
 *
 * The payload is read through `onPayload`, the hook pi already provides for
 * inspecting a request before it is sent, and the request is then handed to a
 * `fetch` stub that refuses. So no socket is opened, no port is bound, no
 * background process runs, and no API key is needed: the assertions are about
 * the params object pi built, not about what a server did with it. Both
 * guards matter -- the stub is what makes "no network" a property of the test
 * rather than a consequence of the callback ordering.
 *
 * What it documents:
 *   a) An absent thinkingLevelMap key counts as SUPPORTED, except that `xhigh`
 *      and `max` are advertised only when the map names them, and an
 *      unsupported level is clamped to the nearest supported one, upward
 *      first. A null off mapping therefore does not send nothing: it raises the
 *      requested level to the next one the model does advertise, which turns
 *      thinking on.
 *   b) thinkingFormat "deepseek" sends `thinking: {type: ...}` and puts the
 *      level in `reasoning_effort`; the disabled case sends the disabled toggle
 *      rather than an effort, and only when the off mapping is not null.
 *   c) The default (openai) format puts the level in `reasoning_effort`; the
 *      disabled case sends the map's off value.
 *   d) compat.supportsReasoningEffort false discards `reasoning_effort` at
 *      every level while leaving the deepseek toggle in place.
 *
 * Reference:
 *   pi-ai dist/api/openai-completions.js -- the request builder under test.
 *   The catalog data the shapes come from is in dist/providers/data/
 *     opencode-go.json and opencode.json.
 *   src/reasoning/providers/pi/config/agent/extensions/model-refresh/README.md
 *     -- the dated findings, each naming the method that produced it.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";
import * as fs from "node:fs";

const PI_AI_ROOT = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/node_modules/@earendil-works/pi-ai";
const STREAM_MODULE = `${PI_AI_ROOT}/dist/api/openai-completions.js`;

const piAiAvailable = () => fs.existsSync(STREAM_MODULE);
const skip = () => (piAiAvailable() ? false : "pi-ai installation not present");

const CHAT_COMPAT = { supportsStore: false, supportsDeveloperRole: false, maxTokensField: "max_tokens" };
const DEEPSEEK_COMPAT = { ...CHAT_COMPAT, thinkingFormat: "deepseek", requiresReasoningContentOnAssistantMessages: true };
const SUPPRESSED_EFFORT_COMPAT = { ...DEEPSEEK_COMPAT, supportsReasoningEffort: false };

type LevelMap = Record<string, string | null>;

/** Drive pi's own builder and return the thinking-related fields of the payload. */
async function thinkingFields(options: { compat: Record<string, unknown>; levelMap?: LevelMap; level: string }): Promise<Record<string, unknown>> {
	const { streamSimple } = await import(STREAM_MODULE);
	const model = {
		id: "probe",
		name: "probe",
		api: "openai-completions",
		provider: "opencode-go",
		baseUrl: "https://opencode.ai/zen/go/v1",
		reasoning: true,
		input: ["text"],
		cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
		contextWindow: 200_000,
		maxTokens: 32_000,
		thinkingLevelMap: options.levelMap,
		compat: options.compat,
	};
	const context = { messages: [{ role: "user", content: "probe" }] };

	let payload: Record<string, unknown> | undefined;
	// pi hands this straight to the HTTP client, so the request cannot leave the
	// process no matter what the builder does.
	const refuseRequest = async () => {
		throw new Error("the probe refuses to send");
	};
	const stream = streamSimple(model, context, {
		apiKey: "placeholder",
		reasoning: options.level,
		fetch: refuseRequest,
		onPayload: (built: unknown) => {
			payload = built as Record<string, unknown>;
			return undefined;
		},
	});
	// The refusal is the expected outcome; only the payload matters here.
	await stream.result().catch(() => undefined);

	assert.ok(payload, "pi built a payload for the probe");
	return Object.fromEntries(Object.entries(payload).filter(([key]) => /reason|think|budget|effort/i.test(key)));
}

describe("wire shape: the default format", { skip: skip() }, () => {
	it("carries the level in reasoning_effort", async () => {
		const fields = await thinkingFields({ compat: CHAT_COMPAT, levelMap: { low: "low", high: "high", max: "max" }, level: "high" });
		assert.deepEqual(fields, { reasoning_effort: "high" });
	});

	it("sends nothing for a level whose key is absent", async () => {
		const fields = await thinkingFields({ compat: CHAT_COMPAT, levelMap: { low: "low", high: "high" }, level: "off" });
		assert.deepEqual(fields, {}, "an absent off key reaches the wire as no field at all");
	});

	it("carries an off mapping as the disabled effort", async () => {
		const fields = await thinkingFields({ compat: CHAT_COMPAT, levelMap: { off: "none", low: "low", high: "high" }, level: "off" });
		assert.deepEqual(fields, { reasoning_effort: "none" });
	});

	it("clamps a null off up to the nearest supported level, so thinking is not disabled", async () => {
		// minimal is absent from the map, so it is supported; off is null, so the
		// request is raised to minimal rather than dropped.
		const fields = await thinkingFields({ compat: CHAT_COMPAT, levelMap: { off: null, low: "low", high: "high" }, level: "off" });
		assert.deepEqual(fields, { reasoning_effort: "minimal" });
	});
});

describe("wire shape: the deepseek format", { skip: skip() }, () => {
	it("sends the disabled toggle and no effort at the disabled level", async () => {
		const fields = await thinkingFields({ compat: DEEPSEEK_COMPAT, levelMap: { minimal: null, low: "low", medium: null, high: "high", max: "max" }, level: "off" });
		assert.deepEqual(fields, { thinking: { type: "disabled" } });
	});

	it("sends the enabled toggle and the effort when a level is on", async () => {
		const fields = await thinkingFields({ compat: DEEPSEEK_COMPAT, levelMap: { minimal: null, low: "low", medium: null, high: "high", max: "max" }, level: "high" });
		assert.deepEqual(fields, { thinking: { type: "enabled" }, reasoning_effort: "high" });
	});

	it("clamps past a null off to an enabled toggle at the lowest level", async () => {
		const fields = await thinkingFields({ compat: DEEPSEEK_COMPAT, levelMap: { off: null, minimal: null, low: "low", high: "high" }, level: "off" });
		assert.deepEqual(fields, { thinking: { type: "enabled" }, reasoning_effort: "low" });
	});

	it("drops the mapped level at every setting when the effort field is suppressed", async () => {
		const fields = await thinkingFields({ compat: SUPPRESSED_EFFORT_COMPAT, levelMap: { minimal: null, low: null, medium: null, high: "high", max: "max" }, level: "high" });
		assert.deepEqual(fields, { thinking: { type: "enabled" } }, "high maps to an effort that is then discarded");
	});
});

describe("wire shape: the probe reaches the builder", { skip: skip() }, () => {
	it("captures a payload without opening a socket", async () => {
		// The guard for the other cases: if the builder stopped running, they
		// would all fail on the same missing payload rather than on a shape.
		const fields = await thinkingFields({ compat: CHAT_COMPAT, levelMap: { high: "high" }, level: "high" });
		assert.deepEqual(fields, { reasoning_effort: "high" });
	});
});
