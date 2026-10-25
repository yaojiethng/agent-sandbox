/**
 * Fixtures for the model-failover suite: a fixed clock, chain and outcome
 * builders, and a ledger path that never touches the repository tree.
 */

import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { Chain, FailureScope, Outcome, Route, ThinkingLevelName } from "../../../../src/reasoning/providers/pi/config/agent/extensions/model-failover/types.ts";

/** The fixed clock every test reads: 2023-11-14T22:13:20Z, as epoch milliseconds. */
export const NOW = 1_700_000_000_000;

export const COOLDOWNS = { transient: 120000, limited: 3600000 } as const;

/** The default threshold the shipped declarations file carries. */
export const THRESHOLD = 3;

export function route(provider: string, model: string, thinkingLevel?: ThinkingLevelName): Route {
	return thinkingLevel === undefined ? { provider, model } : { provider, model, thinkingLevel };
}

/** A chain over the given routes, with the shipped defaults. */
export function chain(id: string, routes: readonly Route[]): Chain {
	return { id, routes, transientFailuresBeforeCooldown: THRESHOLD, cooldownMs: COOLDOWNS };
}

/** A transient failure outcome, as the classifier reports one. */
export function transient(): Outcome {
	return { ok: false, class: "transient", scope: "none" };
}

/** A quota-class failure outcome. */
export function limited(scope: FailureScope = "none"): Outcome {
	return { ok: false, class: "limited", scope };
}

/** A success outcome. */
export function ok(): Outcome {
	return { ok: true };
}

/** A ledger path under the system temp directory, removed before it is returned. */
export function tempLedgerPath(): string {
	const target = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "mff-ledger-")), "ledger.json");
	fs.rmSync(target, { force: true });
	return target;
}
