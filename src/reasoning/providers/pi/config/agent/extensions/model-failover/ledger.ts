/**
 * The route health ledger: the state machine of README.md, plus its file.
 *
 * Two states per route, `eligible` and `cooling`, with transitions T1-T6. The
 * machine is a pure function here (`applyOutcome`), so the transitions are
 * testable without a process; the `Ledger` class around it owns the in-memory
 * dispatch view and the merged write.
 *
 * Why the write is a read-merge-write: subagent fan-out runs several pi
 * processes against one container, and each process dispatches through this
 * ledger. A process that rewrote the file from its own map alone would clobber
 * the keys another process had just cooled. Merging keeps that window to one
 * route key, and a rare lost update self-heals at the next outcome on that
 * route, because every outcome rewrites the key it touches.
 *
 * The file holds one entry per declared route, so it is bounded by the
 * configuration and never grows with traffic. A missing or corrupt file starts
 * an empty ledger: runtime state is not configuration, and a damaged sidecar
 * costs re-learning a cooldown, not a refused session.
 */

import { mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { FailureClass, LedgerFile, Outcome, RouteState } from "./types.ts";
import { routeKey } from "./types.ts";

/** The ledger path, beside this module so it travels with the extension. */
export const LEDGER_PATH = fileURLToPath(new URL("./ledger.json", import.meta.url));

/** The initial state: eligible, no consecutive failures. */
export function initialRouteState(): RouteState {
	return { state: "eligible", streak: 0 };
}

/**
 * The eligibility guard, and the only admissibility test a dispatch performs.
 * A cooling route is eligible once its deadline has passed: the lapse is
 * derived at read time, so no timer and no sweep exists.
 */
export function eligibleAt(entry: RouteState, now: number): boolean {
	return entry.state === "eligible" || entry.until <= now;
}

/**
 * The machine: apply one classified outcome to one route's state.
 *
 * T1, T5   `outcome.received` from either state: the route is healthy, so the
 *          streak resets and any cooldown clears.
 * T2       a transient failure below the declared threshold: an internal
 *          transition that counts the streak and cools nothing.
 * T3, T4   a transient failure at the threshold, or any quota-class failure:
 *          cooling, with the deadline set from the class that fired.
 * T6       a failure on an already cooling route: the deadline refreshes from
 *          the current failure's class, so a quota error landing during a
 *          transient cooldown extends it to the long window.
 */
export function applyOutcome(entry: RouteState, outcome: Outcome, now: number, threshold: number, cooldownMs: Readonly<Record<FailureClass, number>>): RouteState {
	if (outcome.ok) {
		return initialRouteState();
	}
	const cooling = (failureClass: FailureClass): RouteState => ({ state: "cooling", until: now + cooldownMs[failureClass], class: failureClass });
	if (outcome.class === "limited") {
		return cooling("limited");
	}
	if (entry.state === "cooling") {
		// T6: a transient failure on an already cooling route refreshes the deadline.
		return cooling("transient");
	}
	const streak = entry.streak + 1;
	if (streak >= threshold) {
		// T3: the threshold is crossed.
		return cooling("transient");
	}
	// T2: below the threshold, the route stays eligible and counts the streak.
	return { state: "eligible", streak };
}

/** Read the ledger file, or an empty map when it is absent, unreadable, or another version. */
export function parseLedger(text: string): ReadonlyMap<string, RouteState> {
	let raw: unknown;
	try {
		raw = JSON.parse(text);
	} catch {
		return new Map();
	}
	if (typeof raw !== "object" || raw === null || !("routes" in raw)) {
		return new Map();
	}
	// A file another version wrote is not this version's shape, even when the
	// keys look familiar: reading it as version 1 would act on state this
	// version cannot interpret. Another version reads as empty and re-learns.
	if ((raw as { version?: unknown }).version !== 1) {
		return new Map();
	}
	const routes = (raw as { routes?: unknown }).routes;
	if (typeof routes !== "object" || routes === null) {
		return new Map();
	}
	const entries = new Map<string, RouteState>();
	for (const [key, value] of Object.entries(routes as Record<string, unknown>)) {
		const entry = parseEntry(value);
		if (entry !== undefined) {
			entries.set(key, entry);
		}
	}
	return entries;
}

/** Parse one stored entry, or undefined when the shape is not one this version writes. */
function parseEntry(value: unknown): RouteState | undefined {
	if (typeof value !== "object" || value === null) {
		return undefined;
	}
	const raw = value as { state?: unknown; streak?: unknown; until?: unknown; class?: unknown };
	if (raw.state === "eligible" && typeof raw.streak === "number" && Number.isInteger(raw.streak) && raw.streak >= 0) {
		return { state: "eligible", streak: raw.streak };
	}
	if (raw.state === "cooling" && typeof raw.until === "number" && (raw.class === "transient" || raw.class === "limited")) {
		return { state: "cooling", until: raw.until, class: raw.class };
	}
	return undefined;
}

/**
 * The ledger: the dispatch view in memory, the merged file on disk.
 *
 * The in-memory map is authoritative for dispatch. Each outcome updates the
 * map first, then merges that one key into whatever the file holds, so a
 * concurrent process's other keys survive. The write is a temp file and a
 * rename, so a crash mid-write cannot leave a torn file.
 */
export class Ledger {
	private readonly entries = new Map<string, RouteState>();
	private readonly path: string;

	constructor(path: string = LEDGER_PATH) {
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
		for (const [key, entry] of parseLedger(text)) {
			this.entries.set(key, entry);
		}
	}

	/** The current state of one route, or the initial state when it has none. */
	get(provider: string, model: string): RouteState {
		return this.entries.get(routeKey(provider, model)) ?? initialRouteState();
	}

	/** The eligibility guard against the dispatch view. */
	eligible(provider: string, model: string, now: number): boolean {
		return eligibleAt(this.get(provider, model), now);
	}

	/**
	 * Apply one outcome: update the dispatch view, then merge the changed key
	 * into the file. Returns the state the route now rests in.
	 */
	apply(provider: string, model: string, outcome: Outcome, now: number, threshold: number, cooldownMs: Readonly<Record<FailureClass, number>>): RouteState {
		const next = applyOutcome(this.get(provider, model), outcome, now, threshold, cooldownMs);
		this.entries.set(routeKey(provider, model), next);
		this.persist(provider, model, next);
		return next;
	}

	/** Merge the one changed key into the file on disk, atomically. */
	private persist(provider: string, model: string, next: RouteState): void {
		const onDisk = new Map(parseLedger(this.read()));
		onDisk.set(routeKey(provider, model), next);
		const file: LedgerFile = { version: 1, routes: Object.fromEntries(onDisk) };
		mkdirSync(dirname(this.path), { recursive: true });
		const temp = `${this.path}.${process.pid}.tmp`;
		writeFileSync(temp, `${JSON.stringify(file, null, 2)}\n`, "utf8");
		renameSync(temp, this.path);
	}

	/** The file's text, or an empty object's text when it is absent. */
	private read(): string {
		try {
			return readFileSync(this.path, "utf8");
		} catch {
			return JSON.stringify({ version: 1, routes: {} });
		}
	}
}
