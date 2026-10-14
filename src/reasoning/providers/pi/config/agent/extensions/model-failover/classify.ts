/**
 * Error classification: the assistant message's error text becomes one failure
 * class, or a success.
 *
 * The classification is local to this module so the cooldown, the tracking
 * entry and the report all read one answer. pi's own retry machinery draws the
 * same split (its retryable set against its non-retryable provider-limit set),
 * but reading the finalized message here keeps the classes in one place, where
 * a new pattern is one edit.
 *
 * The class patterns come from this deployment's measured errors, not from
 * documentation. Anything unmatched falls to `transient`: it is the class that
 * self-heals on a cooldown, so an unrecognized error is treated as recoverable
 * rather than as an account problem.
 */

import type { FailureClass, Outcome } from "./types.ts";

/**
 * Patterns that name an account-level limit. These persist across the
 * observation window, so a route they hit stays cooled for the long window
 * while the operator acts.
 */
const LIMITED_PATTERNS: readonly RegExp[] = [
	/GoUsageLimitError/i,
	/FreeUsageLimitError/i,
	/FreeTierError/i,
	/monthly usage limit/i,
	/usage limit exceeded/i,
	/available balance/i,
	/quota exceeded/i,
	/insufficient[ _]quota/i,
];

/** Classify one provider error message into a failure class. */
export function classifyError(errorMessage: string): FailureClass {
	for (const pattern of LIMITED_PATTERNS) {
		if (pattern.test(errorMessage)) {
			return "limited";
		}
	}
	return "transient";
}

/**
 * Classify one finalized assistant message. A message that carries no error is
 * a success, whatever its stop reason; an error message carries the class.
 */
export function classifyOutcome(stopReason: string | undefined, errorMessage: string | undefined): Outcome {
	if (stopReason !== "error" || errorMessage === undefined || errorMessage === "") {
		return { ok: true };
	}
	return { ok: false, class: classifyError(errorMessage) };
}
