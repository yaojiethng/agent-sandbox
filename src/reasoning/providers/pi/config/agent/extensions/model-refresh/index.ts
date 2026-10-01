/**
 * model-refresh: keeps pi's opencode-go catalog complete.
 *
 * Pi serves a frozen baked catalog for `opencode-go` and overlays a persisted
 * pi.dev catalog on top of it. This extension adds the models OpenCode
 * advertises on its own `/models` endpoint that neither source carries yet.
 *
 * It registers through pi's legacy `ProviderConfig` form, and that form has
 * one consequence every other module here is shaped around: whatever
 * `refreshModels` returns REPLACES the provider's whole model list. Returning
 * only the baked catalog therefore deletes the pi.dev overlay on every start.
 * That regression is what the union in `catalog.ts` exists to prevent.
 * README.md records the evidence.
 *
 * On the network question: pi never calls a provider's `refreshModels` with
 * `allowNetwork: true` outside `pi update --models`, and that command builds
 * its own model runtime without loading extensions. The live fetch is
 * therefore reached only if that changes. It is kept because it is the only
 * source for a model OpenCode ships before pi.dev catalogues it, and it is
 * written to narrow rather than to damage the result when it does not run.
 *
 * On where the output goes: nothing in this extension writes to the console in
 * TUI mode. The TUI owns the terminal, and a line written behind its back
 * corrupts every line drawn after it. `refreshModels` records the per-source
 * counts and `report.ts` renders them into pi's UI on `session_start`, the
 * first event that carries one. In `print`, `json` and `rpc` mode there is no
 * frame to corrupt, so the console remains the sink there.
 */

import type { ExtensionAPI, ProviderConfig } from "@earendil-works/pi-coding-agent";
import { getBuiltinModels, getBuiltinModelDataGeneratedAt } from "@earendil-works/pi-ai/providers/all";
import { fetchJson, gatherAndBuild, PROVIDER_ID } from "./refresh.ts";
import { createReporter } from "./report.ts";
import type { ModelDefinition, StoredCatalog } from "./types.ts";

export { gatherAndBuild, fetchJson, PROVIDER_ID } from "./refresh.ts";
export { createReporter, summarize, completion } from "./report.ts";

export default function modelRefresh(pi: ExtensionAPI) {
	const reporter = createReporter();
	const baked = () => getBuiltinModels(PROVIDER_ID) as unknown as ModelDefinition[];

	// The config carries no `models`, so pi keeps the baked catalog and adds only
	// the `refreshModels` hook. Its return value is the whole catalog, so it must
	// be the union -- see the module comment.
	const config: ProviderConfig = {
		async refreshModels(context) {
			return gatherAndBuild({
				signal: context.signal,
				allowNetwork: context.allowNetwork,
				stored: context.stored as StoredCatalog | undefined,
				generatedAt: getBuiltinModelDataGeneratedAt(),
				baked: baked(),
				fetcher: fetchJson,
				// No `log`. The console is the sink only in a mode with no TUI, and
				// the decision belongs to the session_start handler below, which is
				// the first place a run mode is known.
				onReport: (report) => reporter.record(report),
			});
		},
	};
	pi.registerProvider(PROVIDER_ID, config);

	pi.on("session_start", async (_event, ctx) => {
		if (ctx.mode !== "tui") {
			const generatedAt = getBuiltinModelDataGeneratedAt();
			console.warn(
				`[model-refresh] registered ${PROVIDER_ID} (baked base: ${baked().length} models, baked data generated ${generatedAt === undefined ? "unknown" : new Date(generatedAt).toISOString()})`,
			);
			const report = reporter.current();
			if (report) {
				console.warn(`[model-refresh] model catalogs refreshed. ${report.served} served from ${report.baked} baked, ${report.stored} stored`);
			}
			return;
		}
		reporter.attach(ctx.ui);
	});
}
