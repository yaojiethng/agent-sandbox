/**
 * The saved-default announcement: the notice for a saved default the model
 * scope discarded.
 *
 * The guard is pi's own resolver test, so the truth table mirrors
 * `findInitialModel`: a default the scope outranks is announced only when the
 * default resolves to a model with configured auth, and an empty scope or a
 * broken default is silent. The cases below are that truth table.
 */

import { describe, it } from "node:test";
import assert from "node:assert/strict";

import { discardedDefault } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-refresh/default-model.ts";

const DEFAULT = { provider: "openrouter", id: "z-ai/glm-4.5" };
const SELECTED = { provider: "opencode-go", id: "space-bunny-free" };

interface CtxOptions {
	model?: { provider: string; id: string } | undefined;
	scopedModels?: readonly unknown[];
	defaultProvider?: string;
	defaultModel?: string;
	found?: unknown;
	missing?: true;
	noModel?: true;
	authed?: boolean;
}

function ctx(options: CtxOptions = {}) {
	return {
		model: options.noModel === true ? undefined : options.model ?? SELECTED,
		scopedModels: options.scopedModels ?? [{}],
		getSettings: () => ({ defaultProvider: options.defaultProvider ?? DEFAULT.provider, defaultModel: options.defaultModel ?? DEFAULT.id }),
		modelRegistry: {
			find: () => (options.missing === true ? undefined : options.found ?? { ...DEFAULT }),
			hasConfiguredAuth: () => options.authed ?? true,
		},
	};
}

describe("the discarded saved default", () => {
	it("announces a default the scope outranks, naming both models", () => {
		assert.equal(
			discardedDefault(ctx()),
			"saved default openrouter/z-ai/glm-4.5 is outside the model scope; started on opencode-go/space-bunny-free",
		);
	});

	it("stays silent with an empty scope, where the resolver consults the default", () => {
		assert.equal(discardedDefault(ctx({ scopedModels: [] })), undefined);
	});

	it("stays silent when the default has no configured auth", () => {
		assert.equal(discardedDefault(ctx({ authed: false })), undefined);
	});

	it("stays silent when the default id is not in the catalog", () => {
		assert.equal(discardedDefault(ctx({ missing: true, defaultModel: "absent" })), undefined);
	});

	it("stays silent when the selected model is the default", () => {
		assert.equal(discardedDefault(ctx({ model: { ...DEFAULT } })), undefined);
	});

	it("stays silent when no saved default is set", () => {
		assert.equal(discardedDefault(ctx({ defaultProvider: "", defaultModel: "" })), undefined);
	});

	it("stays silent when the session has no model", () => {
		assert.equal(discardedDefault(ctx({ noModel: true })), undefined);
	});
});
