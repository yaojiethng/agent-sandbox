/**
 * The network adaptor: one fetch wrapper that routes a managed host's
 * inference requests to a chosen edge address.
 *
 * It is the only network seam the extension owns. It does not touch the model
 * catalog, the provider registry, or `models.json`; it reads the request URL
 * and body and pins the connection below them. A host is managed only once the
 * extension has been told about it, and every other request is delegated to
 * the original fetch untouched.
 *
 * The adaptor holds both edge submachines in memory: the address set per host
 * (from edges.ts, refreshed on a ttl) and the edge health (the persisted edge
 * ledger). The choice is the pure `nextEdge`. The chosen edge is remembered
 * per `(host, model)` so the outcome observer can charge the right edge.
 */

import type { AddressSet, SelectionConfig } from "./types.ts";
import { EdgeLedger } from "./edge-ledger.ts";
import { applyResolution, needsRefresh, nextEdge, resolveAddresses, unresolvedAddressSet, usable, type ResolveFn } from "./edges.ts";
import { canPinBody, pinnedFetch } from "./pinned-fetch.ts";

/** The resolution refresh guard, in milliseconds. */
export const ADDRESS_TTL_MS = 60_000;

/** The model id a request names, read from a JSON body; empty when absent. */
export function modelOfRequest(init: RequestInit | undefined): string {
	if (!init?.body || typeof init.body !== "string") {
		return "";
	}
	try {
		const parsed = JSON.parse(init.body) as { model?: unknown };
		return typeof parsed.model === "string" ? parsed.model : "";
	} catch {
		return "";
	}
}

function urlOf(input: RequestInfo | URL): string {
	if (typeof input === "string") {
		return input;
	}
	if (input instanceof URL) {
		return input.href;
	}
	return input.url;
}

export interface AdaptorOptions {
	readonly originalFetch?: typeof globalThis.fetch;
	readonly edges: EdgeLedger;
	readonly config: SelectionConfig;
	readonly resolve?: ResolveFn;
	readonly rand?: () => number;
	readonly now?: () => number;
	readonly ttlMs?: number;
}

export class NetworkAdaptor {
	private readonly originalFetch: typeof globalThis.fetch;
	private readonly edges: EdgeLedger;
	private readonly config: SelectionConfig;
	private readonly resolveFn: ResolveFn;
	private readonly rand: () => number;
	private readonly now: () => number;
	private readonly ttlMs: number;
	private readonly managed = new Set<string>();
	private readonly sets = new Map<string, AddressSet>();
	private readonly lastEdgeByKey = new Map<string, string>();
	private readonly inflight = new Map<string, Promise<void>>();

	constructor(options: AdaptorOptions) {
		this.originalFetch = options.originalFetch ?? globalThis.fetch;
		this.edges = options.edges;
		this.config = options.config;
		this.resolveFn = options.resolve ?? ((hostname) => resolveAddresses(hostname));
		this.rand = options.rand ?? Math.random;
		this.now = options.now ?? Date.now;
		this.ttlMs = options.ttlMs ?? ADDRESS_TTL_MS;
	}

	/** Mark a host as managed; its requests are pinned, all others are untouched. */
	manage(host: string): void {
		if (host !== "") {
			this.managed.add(host);
		}
	}

	/** Whether a host is managed. */
	manages(host: string): boolean {
		return this.managed.has(host);
	}

	/** The edge address chosen for the last request of a `(host, model)`. */
	edgeUsed(host: string, model: string): string | undefined {
		return this.lastEdgeByKey.get(`${host}/${model}`);
	}

	/** The current address set for a host, or empty when unresolved. */
	addresses(host: string): readonly string[] {
		return this.setOf(host).addresses;
	}

	private setOf(host: string): AddressSet {
		return this.sets.get(host) ?? unresolvedAddressSet();
	}

	/** Resolve the host when its set is missing or past its ttl; a failure keeps the old set. */
	private async ensureResolved(host: string, now: number): Promise<readonly string[]> {
		if (!needsRefresh(this.setOf(host), now, this.ttlMs)) {
			return this.setOf(host).addresses;
		}
		const existing = this.inflight.get(host);
		if (existing !== undefined) {
			await existing;
			return this.setOf(host).addresses;
		}
		const attempt = (async () => {
			try {
				const addresses = await this.resolveFn(host);
				this.sets.set(host, applyResolution(this.setOf(host), addresses, this.now()));
			} catch {
				// A failed refresh keeps the previous set, or stays unresolved when there is none.
			}
		})();
		this.inflight.set(host, attempt);
		try {
			await attempt;
		} finally {
			this.inflight.delete(host);
		}
		return this.setOf(host).addresses;
	}

	/** The selected address for a request, or undefined when no address set is usable. */
	select(host: string, model: string, now: number): string | undefined {
		const set = this.setOf(host);
		if (!usable(set)) {
			return undefined;
		}
		const address = nextEdge(set.addresses, (candidate) => this.edges.get(host, model, candidate), now, this.rand(), this.config);
		if (address !== undefined) {
			this.lastEdgeByKey.set(`${host}/${model}`, address);
		}
		return address;
	}

	/** The fetch wrapper. Replace `globalThis.fetch` with this at extension load. */
	fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
		let host: string;
		try {
			host = new URL(urlOf(input)).hostname;
		} catch {
			return this.originalFetch(input, init);
		}
		if (!this.managed.has(host) || !canPinBody(init?.body)) {
			return this.originalFetch(input, init);
		}
		const now = this.now();
		const addresses = await this.ensureResolved(host, now);
		if (addresses.length === 0) {
			return this.originalFetch(input, init);
		}
		const model = modelOfRequest(init);
		const address = this.select(host, model, now) ?? addresses[0];
		return pinnedFetch(urlOf(input), init ?? {}, address);
	};
}
