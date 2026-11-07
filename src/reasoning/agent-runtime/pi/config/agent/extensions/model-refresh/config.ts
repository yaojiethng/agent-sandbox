/**
 * The extension's source declaration.
 *
 * The declaration sits beside the extension, so the folder owns every input it
 * reads and no host file has to carry an extension-specific key. It is config
 * rather than code so a second provider is a row, not an edit to the union.
 *
 * The shape is validated here because a persisted file is data on disk, not a
 * typed argument: a malformed entry contributes nothing rather than throwing at
 * startup.
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import type { CompatDecl, ProviderDecl, SourceDecl, SourceDeclarations, SourceKind, ThinkingNames } from "./types.ts";

/** The source kinds the union can read. */
export const SOURCE_KINDS: readonly SourceKind[] = ["baked", "pi-dev", "models-dev", "endpoint", "cache"];

/** The declaration path, resolved beside this module so it travels with the extension. */
export const DECLARATIONS_PATH = fileURLToPath(new URL("./sources.json", import.meta.url));

/** Parse one source entry, or undefined when the shape is not one the union can read. */
function parseSource(value: unknown): SourceDecl | undefined {
	if (typeof value !== "object" || value === null) {
		return undefined;
	}
	const raw = value as { kind?: unknown; override?: unknown; metadata?: unknown };
	if (typeof raw.kind !== "string" || !SOURCE_KINDS.includes(raw.kind as SourceKind)) {
		return undefined;
	}
	return {
		kind: raw.kind as SourceKind,
		...(raw.override === true ? { override: true } : {}),
		...(raw.metadata === true ? { metadata: true } : {}),
	};
}

/** Parse the thinking-effort names, dropping any field that is not a string or string map. */
function parseThinking(value: unknown): ThinkingNames | undefined {
	if (typeof value !== "object" || value === null) {
		return undefined;
	}
	const raw = value as { offEffort?: unknown; fallbackEfforts?: unknown };
	const fallbackEfforts =
		typeof raw.fallbackEfforts === "object" && raw.fallbackEfforts !== null
			? Object.fromEntries(
					Object.entries(raw.fallbackEfforts as Record<string, unknown>).filter(
						(entry): entry is [string, string] => typeof entry[1] === "string",
					),
				)
			: undefined;
	const parsed: ThinkingNames = {
		...(typeof raw.offEffort === "string" ? { offEffort: raw.offEffort } : {}),
		...(fallbackEfforts && Object.keys(fallbackEfforts).length > 0 ? { fallbackEfforts } : {}),
	};
	return Object.keys(parsed).length > 0 ? parsed : undefined;
}

function parseProvider(value: unknown): ProviderDecl | undefined {
	if (typeof value !== "object" || value === null) {
		return undefined;
	}
	const raw = value as Record<string, unknown>;
	if (!Array.isArray(raw.sources)) {
		return undefined;
	}
	const sources = raw.sources.map(parseSource).filter((source): source is SourceDecl => source !== undefined);
	if (sources.length === 0) {
		return undefined;
	}
	const baseUrls =
		typeof raw.baseUrls === "object" && raw.baseUrls !== null
			? Object.fromEntries(
					Object.entries(raw.baseUrls as Record<string, unknown>).filter((entry): entry is [string, string] => typeof entry[1] === "string"),
				)
			: {};
	const transports =
		typeof raw.transports === "object" && raw.transports !== null
			? Object.fromEntries(
					Object.entries(raw.transports as Record<string, unknown>)
						.filter((entry): entry is [string, string[]] => Array.isArray(entry[1]))
						.map(([api, ids]) => [api, ids.filter((id): id is string => typeof id === "string")]),
				)
			: {};
	const thinking = parseThinking(raw.thinking);
	const compat = typeof raw.compat === "object" && raw.compat !== null ? (raw.compat as CompatDecl) : undefined;
	return {
		...(typeof raw.endpoint === "string" ? { endpoint: raw.endpoint } : {}),
		baseUrls,
		...(Object.keys(transports).length > 0 ? { transports } : {}),
		...(thinking ? { thinking } : {}),
		...(compat ? { compat } : {}),
		sources,
	};
}

/** Parse a declaration document. An unknown provider or source contributes nothing. */
export function parseDeclarations(raw: unknown): SourceDeclarations {
	if (typeof raw !== "object" || raw === null) {
		return {};
	}
	const parsed: SourceDeclarations = {};
	for (const [providerId, value] of Object.entries(raw as Record<string, unknown>)) {
		const decl = parseProvider(value);
		if (decl) {
			parsed[providerId] = decl;
		}
	}
	return parsed;
}

/** Read and parse the declaration beside the extension. */
export function loadDeclarations(path: string = DECLARATIONS_PATH): SourceDeclarations {
	return parseDeclarations(JSON.parse(readFileSync(path, "utf-8")));
}
