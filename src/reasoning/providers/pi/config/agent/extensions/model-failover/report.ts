/**
 * The report: what the session-start operator sees about the chains.
 *
 * The report names each chain, the state of each of its routes, and calls out
 * any route cooling on a quota-class error, because that one needs operator
 * action rather than patience. It is one line per fact so the TUI's notify
 * surface carries it without a frame of its own.
 *
 * Nothing in this extension writes to the console in TUI mode: the TUI owns
 * the terminal, and a line written behind its back corrupts every line drawn
 * after it. In `print`, `json` and `rpc` mode there is no frame to corrupt, so
 * the console is the sink there, exactly as in the model-refresh extension.
 */

import type { Chain } from "./types.ts";
import type { EdgeHealth, RouteState } from "./types.ts";
import { routeKey } from "./types.ts";
import { edgeRate, edgeStreak } from "./edges.ts";

/** One fact the report carries: a chain header, a route state, or a notice. */
export interface ReportLine {
	readonly chainId: string;
	readonly text: string;
	/** Set when the line names something the operator should act on. */
	readonly notice: boolean;
}

/** Milliseconds as a compact duration, for a cooldown deadline. */
export function formatDuration(ms: number): string {
	const totalSeconds = Math.max(0, Math.round(ms / 1000));
	if (totalSeconds < 60) {
		return `${totalSeconds}s`;
	}
	const minutes = Math.floor(totalSeconds / 60);
	const seconds = totalSeconds % 60;
	const minutePart = minutes >= 60 ? `${Math.floor(minutes / 60)}h${minutes % 60 > 0 ? ` ${minutes % 60}m` : ""}` : `${minutes}m`;
	return seconds > 0 ? `${minutePart} ${seconds}s` : minutePart;
}

/** The state of one route, in one line. */
export function routeLine(provider: string, model: string, entry: RouteState, now: number): string {
	const key = routeKey(provider, model);
	if (entry.state === "eligible") {
		return entry.streak > 0 ? `${key} eligible (${entry.streak} consecutive transient failures)` : `${key} eligible`;
	}
	if (entry.until <= now) {
		return `${key} cooling on ${entry.class}, deadline lapsed`;
	}
	return `${key} cooling on ${entry.class} for another ${formatDuration(entry.until - now)}`;
}

/** The report for every chain, read against the ledger's current view. */
export function buildReport(chains: readonly Chain[], ledgerView: (provider: string, model: string) => RouteState, now: number): readonly ReportLine[] {
	const lines: ReportLine[] = [];
	for (const chain of chains) {
		lines.push({ chainId: chain.id, text: `chain ${chain.id}: ${chain.routes.length} route(s), threshold ${chain.transientFailuresBeforeCooldown}`, notice: false });
		for (const route of chain.routes) {
			const entry = ledgerView(route.provider, route.model);
			lines.push({ chainId: chain.id, text: `  ${routeLine(route.provider, route.model, entry, now)}`, notice: entry.state === "cooling" && entry.class === "limited" && entry.until > now });
		}
	}
	return lines;
}

/** The state of one edge, in one line. */
export function edgeLine(address: string, health: EdgeHealth, now: number): string {
	if (health.state === "eligible") {
		const streak = edgeStreak(health);
		const rate = Math.round(edgeRate(health) * 100);
		return `${address} eligible (rate ${rate}%${streak > 0 ? `, streak ${streak}` : ""})`;
	}
	if (health.until <= now) {
		return `${address} cooling, deadline lapsed`;
	}
	return `${address} cooling for another ${formatDuration(health.until - now)}`;
}

/** The edge report for every chain route whose provider host is known. */
export function buildEdgeReport(
	chains: readonly Chain[],
	hostOf: (provider: string) => string | undefined,
	addressesOf: (host: string) => readonly string[],
	healthOf: (host: string, model: string, address: string) => EdgeHealth,
	now: number,
): readonly ReportLine[] {
	const lines: ReportLine[] = [];
	for (const chain of chains) {
		for (const route of chain.routes) {
			const host = hostOf(route.provider);
			if (host === undefined) {
				continue;
			}
			for (const address of addressesOf(host)) {
				const health = healthOf(host, route.model, address);
				lines.push({ chainId: chain.id, text: `  edge ${edgeLine(address, health, now)}`, notice: health.state === "cooling" && health.until > now });
			}
		}
	}
	return lines;
}
