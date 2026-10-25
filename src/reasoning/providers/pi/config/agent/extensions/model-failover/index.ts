/**
 * model-failover: keeps a pi session on a working model.
 *
 * The operator declares chains in routes.json beside this module. Each chain
 * protects one model with an ordered list of routes; the extension registers
 * one virtual model per chain, so `/model` and `settings.json` select the
 * chain name and pi dispatches a physical route underneath.
 *
 * The design record is README.md beside this module: the measured gateway
 * behaviour, the configuration surface, the state machine (states `eligible`
 * and `cooling`, transitions T1-T6), the dispatch walk, the complexity, and
 * the invariants. This module wires that record into pi:
 *
 *   - `route()`       the dispatch walk, before every request (router.ts)
 *   - `message_end`   the outcome observer, which classifies each finalized
 *                     assistant message and applies it to the ledger
 *                     (classify.ts, ledger.ts)
 *   - `session_start` the ledger load and the report (report.ts)
 *
 * Two house rules this module keeps, both learned from the model-refresh
 * extension beside it: nothing writes to the console in TUI mode, because the
 * TUI owns the terminal; and every session-scoped resource starts from
 * `session_start` or later, never from the factory, because some invocations
 * load extensions without starting a session.
 */

import type { ExtensionAPI, ModelThinkingLevel } from "@earendil-works/pi-coding-agent";
import { classifyOutcome } from "./classify.ts";
import { DeclarationsError, EDGE_THRESHOLD, EDGE_WINDOW_MS, loadDeclarations } from "./config.ts";
import { NetworkAdaptor } from "./adaptor.ts";
import { EdgeLedger, edgesPathFromEnv } from "./edge-ledger.ts";
import { Ledger, LEDGER_PATH } from "./ledger.ts";
import { buildEdgeReport, buildReport } from "./report.ts";
import { chooseRoute } from "./router.ts";
import type { Route } from "./types.ts";
import { routeKey } from "./types.ts";

/** The provider id the virtual models are listed under. No physical provider uses it. */
export const VIRTUAL_PROVIDER = "failover";

/** The custom entry type each classified outcome appends to the session log. */
const OUTCOME_ENTRY = "model-failover/outcome";

/** The thinking levels offered for selection on a chain's virtual model. */
const THINKING_LEVELS: readonly ModelThinkingLevel[] = ["off", "minimal", "low", "medium", "high", "max"];
/** The environment override for the ledger path, so a test never writes the tree. */
export function ledgerPathFromEnv(env: NodeJS.ProcessEnv = process.env): string {
	return env.MODEL_FAILOVER_LEDGER ?? LEDGER_PATH;
}

/**
 * The enable flag. The extension is inert unless `MODEL_FAILOVER_ENABLED` names
 * a truthy value, so the off state is the default and the on/off comparison is
 * one environment variable.
 */
export function failoverEnabled(env: NodeJS.ProcessEnv = process.env): boolean {
	const value = (env.MODEL_FAILOVER_ENABLED ?? "").trim().toLowerCase();
	return value === "1" || value === "true" || value === "on" || value === "yes";
}

/** The process-global guard, so a reload does not nest one adaptor inside another. */
const ADAPTOR_INSTALLED = Symbol.for("model-failover.adaptor");
type GlobalWithAdaptor = typeof globalThis & { [ADAPTOR_INSTALLED]?: true };

/** Replace the process fetch with the adaptor once; every later load reuses it. */
export function installAdaptor(adaptor: NetworkAdaptor): void {
	const global = globalThis as GlobalWithAdaptor;
	if (global[ADAPTOR_INSTALLED] === true) {
		return;
	}
	globalThis.fetch = adaptor.fetch;
	global[ADAPTOR_INSTALLED] = true;
}

export default function modelFailover(pi: ExtensionAPI) {
	// The extension is inert unless the enable flag is set. Its value is
	// unmeasured: no session carries a `model-failover/outcome` entry and the
	// only shipped chain declares one route, so failover has never run. The
	// flag makes the off state the default and the on/off comparison a
	// one-variable change.
	if (!failoverEnabled()) {
		return;
	}
	// A malformed declarations file throws here, and the extension fails to
	// load loudly: a chain that half-parsed would route to nothing and read as
	// healthy (R8).
	const declarations = loadDeclarations();
	const ledger = new Ledger(ledgerPathFromEnv());
	const edgeLedger = new EdgeLedger(edgesPathFromEnv());
	const adaptor = new NetworkAdaptor({ edges: edgeLedger, config: declarations.selection });
	installAdaptor(adaptor);
	/** The host resolved for each declared provider, so an outcome finds its edge. */
	const providerHost = new Map<string, string>();

	/** Every declared route, keyed by the provider and the model it names. */
	const declared = new Map<string, { chainId: string; route: Route; threshold: number }>();
	for (const chain of declarations.chains) {
		for (const route of chain.routes) {
			declared.set(routeKey(route.provider, route.model), { chainId: chain.id, route, threshold: chain.transientFailuresBeforeCooldown });
		}
	}
	const chainById = new Map(declarations.chains.map((chain) => [chain.id, chain] as const));

	for (const chain of declarations.chains) {
		pi.registerVirtualModel({
			provider: VIRTUAL_PROVIDER,
			id: chain.id,
			name: `${chain.id} (chain)`,
			thinkingLevels: [...THINKING_LEVELS],
			route: (request, ctx) => {
				const previous =
					request.previous === undefined
						? undefined
						: { provider: request.previous.model.provider, model: request.previous.model.id };
				const choice = chooseRoute({
					chain,
					previous,
					resolvable: (route) => ctx.modelRegistry.find(route.provider, route.model) !== undefined,
					eligible: (route) => ledger.eligible(route.provider, route.model, Date.now()),
				});
				const physical = ctx.modelRegistry.find(choice.route.provider, choice.route.model);
				if (physical === undefined) {
					// The walk degraded deliberately onto an unresolvable head so
					// the misconfiguration surfaces as pi's own error.
					throw new Error(`model-failover: chain '${chain.id}' resolved no credentialed model for route '${choice.route.provider}/${choice.route.model}'`);
				}
				return {
					model: physical,
					thinkingLevel: choice.route.thinkingLevel ?? request.thinkingLevel,
				};
			},
		});
	}

	pi.on("session_start", (_event, ctx) => {
		ledger.load();
		edgeLedger.load();
		for (const chain of declarations.chains) {
			for (const route of chain.routes) {
				const physical = ctx.modelRegistry.find(route.provider, route.model);
				if (physical === undefined || physical.baseUrl === "") {
					continue;
				}
				try {
					const host = new URL(physical.baseUrl).hostname;
					adaptor.manage(host);
					providerHost.set(route.provider, host);
				} catch {
					// A malformed baseUrl is not a host this extension can manage.
				}
			}
		}
		const now = Date.now();
		// One report per session start: the strings for the sink and the notices
		// for the operator both read the rows this one build produced.
		const rows = [
			...buildReport(declarations.chains, (provider, model) => ledger.get(provider, model), now),
			...buildEdgeReport(declarations.chains, (provider) => providerHost.get(provider), (host) => adaptor.addresses(host), (host, model, address) => edgeLedger.get(host, model, address), now),
		];
		if (ctx.mode !== "tui") {
			for (const row of rows) {
				console.warn(`[model-failover] ${row.text}`);
			}
			return;
		}
		if (rows.length > 0) {
			ctx.ui.notify(`[model-failover]\n${rows.map((row) => row.text).join("\n")}`, "info");
		}
		for (const notice of rows.filter((row) => row.notice)) {
			ctx.ui.notify(`[model-failover] ${notice.text}`, "warning");
		}
	});

	pi.on("message_end", (event, ctx) => {
		const message = event.message;
		if (message.role !== "assistant") {
			return;
		}
		const key = routeKey(message.provider, message.model);
		const owner = declared.get(key);
		if (owner === undefined) {
			// The physical provider and model are not a declared route of any chain, so its
			// outcome says nothing about one. A manual model selection stays
			// outside the ledger (S1).
			return;
		}
		const chain = chainById.get(owner.chainId);
		if (chain === undefined) {
			return;
		}
		const outcome = classifyOutcome(message.stopReason, message.errorMessage);
		const now = Date.now();
		const next = ledger.apply(message.provider, message.model, outcome, now, chain.transientFailuresBeforeCooldown, chain.cooldownMs);
		const host = providerHost.get(message.provider);
		const address = host === undefined ? undefined : adaptor.edgeUsed(host, message.model);
		if (host !== undefined && address !== undefined) {
			// One outcome reaches both layers: the route machine and the edge under it.
			edgeLedger.apply(host, message.model, address, outcome, now, EDGE_THRESHOLD, EDGE_WINDOW_MS);
		}
		pi.appendEntry(OUTCOME_ENTRY, {
			chainId: chain.id,
			provider: message.provider,
			model: message.model,
			ok: outcome.ok,
			...(outcome.ok ? {} : { class: outcome.class }),
			state: next.state,
			...(next.state === "cooling" ? { until: next.until } : { streak: next.streak }),
			ts: now,
		});
	});
}

export { DeclarationsError, DEFAULT_SELECTION, EDGE_THRESHOLD, EDGE_WINDOW_MS, loadDeclarations } from "./config.ts";
export { NetworkAdaptor, modelOfRequest } from "./adaptor.ts";
export { EdgeLedger, EDGES_PATH, edgeKey, edgesPathFromEnv, parseEdgeLedger } from "./edge-ledger.ts";
export { applyEdgeOutcome, edgeRate, edgeStreak, eligibleEdgeAt, initialEdgeHealth, nextEdge, resolveAddresses, unresolvedAddressSet } from "./edges.ts";
export { pinnedFetch } from "./pinned-fetch.ts";
export { Ledger, LEDGER_PATH, applyOutcome, eligibleAt, initialRouteState, parseLedger } from "./ledger.ts";
export { classifyError, classifyOutcome } from "./classify.ts";
export { chooseRoute } from "./router.ts";
export { buildEdgeReport, buildReport, edgeLine, formatDuration, routeLine } from "./report.ts";
export { routeKey } from "./types.ts";
export type { AddressSet, Chain, Declarations, EdgeHealth, FailureClass, LedgerFile, Outcome, Route, RouteState, SelectionConfig } from "./types.ts";
