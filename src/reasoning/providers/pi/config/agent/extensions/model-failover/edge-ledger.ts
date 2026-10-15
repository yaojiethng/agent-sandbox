/**
 * The edge ledger: the edge health machine of edges.ts, plus its file.
 *
 * One entry per `(host, model, address)`. The file is version 1 and another
 * version reads as empty, the same rule as the route ledger. The write is a
 * read-merge-write of one key and an atomic rename, so concurrent processes
 * keep each other's keys and a crash mid-write cannot leave a torn file.
 *
 * The edge ledger is its own file, not the route ledger. The two have
 * different writers and cadences: the route ledger is written once per
 * assistant message, the edge ledger once per HTTP attempt. Keeping them
 * separate leaves the route ledger's format untouched.
 */

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { EdgeHealth, EdgeLedgerFile, EdgeOutcomeRecord, Outcome } from "./types.ts";
import { applyEdgeOutcome, initialEdgeHealth } from "./edges.ts";

/** The edge ledger path, beside this module so it travels with the extension. */
export const EDGES_PATH = fileURLToPath(new URL("./edges.json", import.meta.url));

/** The environment override for the edge ledger path, so a test never writes the tree. */
export function edgesPathFromEnv(env: NodeJS.ProcessEnv = process.env): string {
	return env.MODEL_FAILOVER_EDGES ?? EDGES_PATH;
}

/** The stable key of one edge: host, model and address. */
export function edgeKey(host: string, model: string, address: string): string {
	return `${host}/${model}/${address}`;
}

function parseWindow(value: unknown): readonly EdgeOutcomeRecord[] | undefined {
	if (!Array.isArray(value)) {
		return undefined;
	}
	const records: EdgeOutcomeRecord[] = [];
	for (const entry of value) {
		if (typeof entry !== "object" || entry === null) {
			return undefined;
		}
		const raw = entry as { ok?: unknown; at?: unknown };
		if (typeof raw.ok !== "boolean" || typeof raw.at !== "number") {
			return undefined;
		}
		records.push({ ok: raw.ok, at: raw.at });
	}
	return records;
}

/** Parse one stored edge entry, or undefined when the shape is not one this version writes. */
export function parseEdgeHealth(value: unknown): EdgeHealth | undefined {
	if (typeof value !== "object" || value === null) {
		return undefined;
	}
	const raw = value as { state?: unknown; window?: unknown; until?: unknown };
	const window = parseWindow(raw.window);
	if (window === undefined) {
		return undefined;
	}
	if (raw.state === "eligible") {
		return { state: "eligible", window };
	}
	if (raw.state === "cooling" && typeof raw.until === "number") {
		return { state: "cooling", window, until: raw.until };
	}
	return undefined;
}

/** Read the edge ledger file, or an empty map when it is absent, unreadable, or another version. */
export function parseEdgeLedger(text: string): ReadonlyMap<string, EdgeHealth> {
	let raw: unknown;
	try {
		raw = JSON.parse(text);
	} catch {
		return new Map();
	}
	if (typeof raw !== "object" || raw === null || !("edges" in raw)) {
		return new Map();
	}
	if ((raw as { version?: unknown }).version !== 1) {
		return new Map();
	}
	const edges = (raw as { edges?: unknown }).edges;
	if (typeof edges !== "object" || edges === null) {
		return new Map();
	}
	const entries = new Map<string, EdgeHealth>();
	for (const [key, value] of Object.entries(edges as Record<string, unknown>)) {
		const health = parseEdgeHealth(value);
		if (health !== undefined) {
			entries.set(key, health);
		}
	}
	return entries;
}

/** The edge ledger: the dispatch view in memory, the merged file on disk. */
export class EdgeLedger {
	private readonly entries = new Map<string, EdgeHealth>();
	private readonly path: string;

	constructor(path: string = EDGES_PATH) {
		this.path = path;
	}

	/** Read the file into the dispatch view. A missing or damaged file starts empty. */
	load(): void {
		let text: string | undefined;
		try {
			text = readFileSync(this.path, "utf8");
		} catch {
			return;
		}
		for (const [key, health] of parseEdgeLedger(text)) {
			this.entries.set(key, health);
		}
	}

	/** The current health of one edge, or the initial health when it has none. */
	get(host: string, model: string, address: string): EdgeHealth {
		return this.entries.get(edgeKey(host, model, address)) ?? initialEdgeHealth();
	}

	/** Apply one outcome to one edge: update the view, then merge the key into the file. */
	apply(host: string, model: string, address: string, outcome: Outcome, now: number, threshold: number, windowMs: number): EdgeHealth {
		const next = applyEdgeOutcome(this.get(host, model, address), outcome, now, threshold, windowMs);
		this.entries.set(edgeKey(host, model, address), next);
		this.persist(host, model, address, next);
		return next;
	}

	/** Merge the one changed key into the file on disk, atomically. */
	private persist(host: string, model: string, address: string, next: EdgeHealth): void {
		const onDisk = new Map(parseEdgeLedger(this.read()));
		onDisk.set(edgeKey(host, model, address), next);
		const file: EdgeLedgerFile = { version: 1, edges: Object.fromEntries(onDisk) };
		mkdirSync(dirname(this.path), { recursive: true });
		const temp = `${this.path}.${process.pid}.tmp`;
		writeFileSync(temp, `${JSON.stringify(file, null, 2)}\n`, "utf8");
		renameSync(temp, this.path);
	}

	/** The file's text, or an empty file's text when it is absent. */
	private read(): string {
		try {
			return readFileSync(this.path, "utf8");
		} catch {
			return JSON.stringify({ version: 1, edges: {} });
		}
	}
}
