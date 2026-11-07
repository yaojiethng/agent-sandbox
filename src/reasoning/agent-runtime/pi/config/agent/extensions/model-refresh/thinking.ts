/**
 * Thinking-level derivation.
 *
 * Three rules drive everything here. The first two are read from pi-ai's
 * `dist/models.js`, the third from `dist/api/openai-completions.js` (see
 * README.md, "Thinking levels"):
 *
 *  1. A `thinkingLevelMap` key that is absent counts as SUPPORTED, except for
 *     `xhigh` and `max`, which pi advertises only when the map names them:
 *     `getSupportedThinkingLevels` tests those two for `mapped !== undefined`
 *     and every other level only for `mapped !== null`. Only an explicit
 *     `null` marks a level unsupported. A model that advertises no "off"
 *     effort must therefore carry an explicit `off: null`, or pi offers
 *     "off" and sends no disable signal at all.
 *
 *  2. A level pi does not advertise is clamped to the nearest one it does,
 *     searching upward first and then downward, rather than dropped. A ladder
 *     that skips a level therefore answers a request for the skipped level
 *     with the next level above it.
 *
 *  3. A level maps to a string that becomes `reasoning_effort` on the wire.
 *     When `compat.supportsReasoningEffort` is false the field is dropped for
 *     every level, so a level that maps to a string the provider never receives
 *     is a level pi offers and cannot honour.
 *
 * The provider's own naming -- which effort string means "off", and what to
 * offer when the endpoint names no effort at all -- arrives as a declaration
 * (see `sources.json`), because it is a fact about the provider, not about pi.
 */

/** The seven levels pi knows, in pi's own order. */
export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

export type ThinkingLevel = (typeof THINKING_LEVELS)[number];
export type ThinkingLevelMap = Record<string, string | null>;

/** The effort string a provider names its disabled state with, and the ladder to offer when it names none. */
export interface ThinkingNames {
	offEffort?: string;
	fallbackEfforts?: Record<string, string>;
}

/** The disabled-state name used when the declaration states none. */
export const DEFAULT_OFF_EFFORT = "none";

/**
 * The range a model advertises when its endpoint names no effort at all, used
 * when the declaration states none.
 *
 * It stops at `high` on purpose. pi clamps an unsupported level to the nearest
 * supported one, searching upward first, so a ladder that advertises `max`
 * without `xhigh` answers a request for `xhigh` with `max`, which is more than
 * the caller asked for and a value the endpoint never named. The ladder still
 * has a hole at `medium`, which a request for `medium` is answered with `high`
 * for.
 */
export const DEFAULT_FALLBACK_EFFORTS: Record<string, string> = { low: "low", high: "high" };

/**
 * Build a thinking-level map from a provider's advertised effort list.
 *
 * Every one of the seven levels gets an explicit entry. A level the provider
 * does not advertise is `null`, which pi reads as unsupported. The effort the
 * declaration names as the disabled state maps onto `off`.
 */
export function thinkingLevelMapFromEfforts(efforts: readonly string[], names: ThinkingNames = {}): ThinkingLevelMap {
	const offEffort = names.offEffort ?? DEFAULT_OFF_EFFORT;
	const fallback = names.fallbackEfforts ?? DEFAULT_FALLBACK_EFFORTS;
	const map: ThinkingLevelMap = {};
	for (const level of THINKING_LEVELS) {
		map[level] = null;
	}
	if (efforts.length === 0) {
		return { ...map, ...fallback };
	}
	for (const effort of efforts) {
		const level = effort === offEffort ? "off" : effort;
		if ((THINKING_LEVELS as readonly string[]).includes(level)) {
			map[level] = effort;
		}
	}
	return map;
}

/** The level map to serve for a model, given what the provider advertises and how it names the levels. */
export function levelMapFor(advertised: readonly string[] | undefined, names: ThinkingNames = {}): ThinkingLevelMap {
	if (advertised?.length) {
		return thinkingLevelMapFromEfforts(advertised, names);
	}
	return {
		...Object.fromEntries(THINKING_LEVELS.map((level) => [level, null])),
		...(names.fallbackEfforts ?? DEFAULT_FALLBACK_EFFORTS),
	};
}

/** True when the map names the disabled state with a string pi would send. */
export function offSendsAnEffort(map: ThinkingLevelMap | undefined): boolean {
	return typeof map?.off === "string";
}
