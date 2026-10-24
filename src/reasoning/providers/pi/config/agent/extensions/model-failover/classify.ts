/**
 * Error classification: one provider error text becomes a verdict, and a
 * verdict becomes the cooldown a route earns.
 *
 * The verdict answers one question about the caller's next move: will this
 * succeed if nothing outside the call changes? `recoverable` says yes, time or
 * another route is enough. `unrecoverable` says no, something outside the call
 * must change, and `scope` names what.
 *
 * The scope is not a label for its own sake. Each value names a different next
 * move: `none` retry, `model` take the next candidate, `provider` abandon the
 * provider, `request` stop rather than fall through, `account` stop and tell the
 * operator. `unclassified` is the default and stops, because a wrong stop costs
 * a second and a wrong retry costs the candidate list.
 *
 * The patterns below come from measurement over the 88 distinct failure texts
 * this deployment has recorded, not from documentation. 28 of those 88 are
 * unrecoverable and were previously treated as transient.
 */

import type { FailureClass, FailureScope, Outcome } from "./types.ts";

export type { FailureScope } from "./types.ts";

export interface Verdict {
	readonly recoverable: boolean;
	readonly scope: FailureScope;
}

/**
 * Unrecoverable families, checked before any recoverable signal, because a
 * provider that says both (402 with a `server_error` type, 429 with an
 * unavailable endpoint) means the unrecoverable half.
 */
const UNRECOVERABLE: readonly { readonly scope: FailureScope; readonly pattern: RegExp }[] = [
	{ scope: "account", pattern: /GoUsageLimitError|FreeUsageLimitError|monthly usage limit|weekly usage limit|5-hour usage limit|usage limit reached|exceeded your current quota|quota exceeded|insufficient[ _]quota/i },
	{ scope: "account", pattern: /AuthError|authentication_error|api_key_expired|invalid api key|api key expired|user not found|authentication fails|insufficient account funds|insufficient balance/i },
	{ scope: "provider", pattern: /FreeTierError|can only be used from within|provider is not configured|<!doctype html/i },
	{ scope: "model", pattern: /model access is disabled|model-ignored-by-guardrail|guardrail|model is unavailable/i },
	{ scope: "request", pattern: /invalid_request_error|failed to deserialize|unknown variant|reasoning_effort|must be passed back|supported api model names|invalid request/i },
];

/** A status that means the same route will work later without a change. */
const TRANSIENT_STATUS: ReadonlySet<number> = new Set([408, 429, 500, 502, 503, 504]);

/** Text that means the same route will work later without a change. */
const TRANSIENT_TEXT =
	/too busy|temporarily unavailable|rate-limited upstream|please try again later|timed out|timeout|network connection lost|connection error|stream ended|no body|endpoint is unavailable|unknown error|terminated|network_error|streaming response failed|provider returned error/i;

/** A cancelled turn is not the route's failure. */
const ABORTED = /operation was aborted|\baborted\b/i;

/** The HTTP status the provider printed, or null where it printed none. */
function statusOf(errorMessage: string): number | null {
	const lead = /^\s*(\d{3})(?=[: ]|$)/.exec(errorMessage);
	if (lead) {
		return Number(lead[1]);
	}
	const paren = /\((\d{3})\)/.exec(errorMessage);
	return paren ? Number(paren[1]) : null;
}

/** Whether the message reports a cancelled turn rather than a failed one. */
export function isAborted(errorMessage: string): boolean {
	return ABORTED.test(errorMessage);
}

/**
 * The verdict for one provider error text. Unrecoverable first, so an
 * entitlement or request failure is never retried; then the recoverable
 * signals; then unrecoverable by default.
 */
export function classifyVerdict(errorMessage: string): Verdict {
	for (const { scope, pattern } of UNRECOVERABLE) {
		if (pattern.test(errorMessage)) {
			return { recoverable: false, scope };
		}
	}
	const status = statusOf(errorMessage);
	if (status !== null && TRANSIENT_STATUS.has(status)) {
		return { recoverable: true, scope: "none" };
	}
	if (TRANSIENT_TEXT.test(errorMessage)) {
		return { recoverable: true, scope: "none" };
	}
	return { recoverable: false, scope: "unclassified" };
}

/**
 * The cooldown class a verdict earns. The ledger keys on the class and the
 * scope together: the class sets the window, and the scope decides whether the
 * route record holds the failure at all.
 */
export function classifyError(errorMessage: string): FailureClass {
	return classifyVerdict(errorMessage).recoverable ? "transient" : "limited";
}

/**
 * Classify one finalized assistant message. A message that carries no error is
 * a success, and so is a cancelled turn, because nothing on the route failed.
 */
export function classifyOutcome(stopReason: string | undefined, errorMessage: string | undefined): Outcome {
	if (stopReason !== "error" || errorMessage === undefined || errorMessage === "" || isAborted(errorMessage)) {
		return { ok: true };
	}
	return { ok: false, class: classifyError(errorMessage), scope: classifyVerdict(errorMessage).scope };
}
