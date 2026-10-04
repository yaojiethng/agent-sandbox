/**
 * model-refresh: adds secondary model-catalog sources for a declared provider.
 *
 * pi's baked catalog and its persisted pi.dev overlay are pi's primary model
 * sources. This extension adds secondary ones: the provider's own `/models`
 * endpoint, which is the better authority for that provider's catalog, and
 * models.dev, which is metadata. Which sources a provider uses, and how they
 * rank, is the `sources.json` declaration beside this module.
 *
 * It registers through pi's legacy `ProviderConfig` form, and that form has one
 * consequence every other module here is shaped around: whatever
 * `refreshModels` returns REPLACES the provider's whole model list. A returned
 * list that omitted the primary would delete the pi.dev overlay on every start,
 * so the union reproduces the primary rather than replacing it.
 * README.md records the evidence.
 *
 * On where the output goes: nothing in this extension writes to the console in
 * TUI mode. The TUI owns the terminal, and a line written behind its back
 * corrupts every line drawn after it. `refreshModels` records what the served
 * catalog gained, lost and revised, and `report.ts` renders that delta into
 * pi's UI on `session_start`, the first event that carries one. In `print`,
 * `json` and `rpc` mode there is no frame to corrupt, so the console remains
 * the sink there.
 */

import type { ExtensionAPI, ProviderConfig } from "@earendil-works/pi-coding-agent";
import { getBuiltinModels, getBuiltinModelDataGeneratedAt } from "@earendil-works/pi-ai/providers/all";
import { loadDeclarations } from "./config.ts";
import { CACHE_PATH, cachePath, readCache, writeCache } from "./cache.ts";
import { discardedDefault } from "./default-model.ts";
import { fetchJson, gatherAndBuild } from "./refresh.ts";
import { createReporter, notices } from "./report.ts";
import type { ModelDefinition, StoredCatalog } from "./types.ts";

export { DECLARATIONS_PATH, loadDeclarations, parseDeclarations } from "./config.ts";
export { discardedDefault } from "./default-model.ts";
export { gatherAndBuild, fetchJson, MODELS_DEV_URL } from "./refresh.ts";
export { createReporter, deltaLine, notices } from "./report.ts";
export { CACHE_PATH, cachePath, parseCache, readCache, serializeCache, writeCache } from "./cache.ts";
export { buildUnion, diffCatalogs, unionFirstWins, fillMissing } from "./catalog.ts";

const iso = (timestamp: number | undefined): string => (timestamp === undefined ? "unknown" : new Date(timestamp).toISOString());

export default function modelRefresh(pi: ExtensionAPI) {
	const declarations = loadDeclarations();
	const reporters = new Map<string, ReturnType<typeof createReporter>>();
	/** The catalog each provider is serving, so the next refresh diffs against it. */
	const served = new Map<string, readonly ModelDefinition[]>();

	for (const [providerId, decl] of Object.entries(declarations)) {
		const reporter = createReporter();
		reporters.set(providerId, reporter);
		const baked = () => getBuiltinModels(providerId) as unknown as ModelDefinition[];
		const endpoint = decl.endpoint;

		// The config carries no `models`, so pi keeps the baked catalog and adds
		// only the `refreshModels` hook. Its return value is the whole catalog, so
		// it must be the union -- see the module comment.
		const config: ProviderConfig = {
			async refreshModels(context) {
				const models = await gatherAndBuild({
					providerId,
					decl,
					signal: context.signal,
					allowNetwork: context.allowNetwork,
					stored: context.stored as StoredCatalog | undefined,
					generatedAt: getBuiltinModelDataGeneratedAt(),
					baked: baked(),
					// The cache is read here, in the offline phase, so its entries are
					// available before any network source is consulted.
					cache: readCache(cachePath(), endpoint),
					writeCache: endpoint ? (entries) => writeCache(cachePath(), endpoint, entries) : undefined,
					// The first refresh diffs against the offline union, which is what the
					// extension serves with no live source; a later one diffs against the
					// union the last refresh returned.
					previous: served.get(providerId),
					fetcher: fetchJson,
					// No `log`. The console is the sink only in a mode with no TUI, and
					// the decision belongs to the session_start handler below, which is
					// the first place a run mode is known.
					onReport: (report) => reporter.record(report),
				});
				served.set(providerId, models);
				return models;
			},
		};
		pi.registerProvider(providerId, config);
	}

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") {
			const generatedAt = getBuiltinModelDataGeneratedAt();
			for (const [providerId, reporter] of reporters) {
				console.warn(`[model-refresh] registered ${providerId} (baked base: ${getBuiltinModels(providerId).length} models, baked data generated ${iso(generatedAt)})`);
				const report = reporter.current();
				if (report) {
					for (const notice of notices(report)) {
						console.warn(`[model-refresh] ${notice.message}`);
					}
				}
			}
			return;
		}
		for (const reporter of reporters.values()) {
			reporter.attach(ctx.ui);
		}
		const discarded = discardedDefault({
			model: ctx.model,
			scopedModels: ctx.scopedModels,
			settings: pi.getSettings(),
			modelRegistry: ctx.modelRegistry,
		});
		if (discarded !== undefined) {
			ctx.ui.notify(discarded, "info");
		}
	});
}
