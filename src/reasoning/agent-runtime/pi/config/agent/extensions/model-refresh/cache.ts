/**
 * The extension's own cache file.
 *
 * The cache holds the ids the provider's endpoint returned on its last
 * successful answer, with the entry each id was served as, so an offline start
 * can serve them before pi's network refresh. It is a file the folder owns,
 * beside `sources.json`, and it is not pi's store: pi's `models-store.json` is
 * a separate source this module never touches.
 *
 * The file is `{ version, writtenAt, endpoints }`, and each key in `endpoints`
 * maps an endpoint URL to its `{ retrievedAt, entries }` record. The declared
 * endpoint must be a key for the file to be read, so re-pointing the
 * declaration discards the old cache rather than serving another endpoint's
 * entries. The dates are bookkeeping; nothing gates on them, so a cache does
 * not expire.
 *
 * The file is data on disk, like the declaration, so a missing, malformed or
 * unrecognised file is no source rather than a startup failure. The write is
 * atomic - a temporary file then a rename - so a failed write leaves the old
 * content in place.
 */

import { mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { fileURLToPath } from "node:url";
import type { ModelDefinition } from "./types.ts";

/** The cache path, resolved beside this module so it travels with the extension. */
export const CACHE_PATH = fileURLToPath(new URL("./cache.json", import.meta.url));

/**
 * The cache path in force. An environment override lets the suite drive a
 * temporary file, so a test that exercises the write-back never writes into the
 * extension folder.
 */
export function cachePath(): string {
	return process.env.MODEL_REFRESH_CACHE ?? CACHE_PATH;
}

/** The schema version this module reads and writes. An unknown version is no source. */
export const CACHE_VERSION = 1;

/** One endpoint's record: when it was retrieved, and the entries it returned. */
export interface CacheRecord {
	retrievedAt: string;
	entries: ModelDefinition[];
}

/** The envelope the cache file carries. */
export interface CacheFile {
	version: number;
	writtenAt: string;
	endpoints: Record<string, CacheRecord>;
}

/** The result of a write: `ok`, or the reason the file could not be written. */
export type CacheWrite = { ok: true } | { ok: false; reason: string };

/** A usable entry: an id the union can key on. */
function isUsableEntry(entry: unknown): entry is ModelDefinition {
	return typeof entry === "object" && entry !== null && typeof (entry as { id?: unknown }).id === "string" && (entry as { id: string }).id.length > 0;
}

/**
 * Parse a cache document and return the declared endpoint's entries.
 *
 * Returns undefined - the `absent` event - when the document is not an object,
 * carries another version, has no `endpoints` map, does not name the declared
 * endpoint, or holds no entries array. A record with a malformed entry drops
 * that entry rather than the file, the same rule `storeEntriesFor` applies.
 */
export function parseCache(raw: unknown, endpoint: string | undefined): ModelDefinition[] | undefined {
	if (typeof raw !== "object" || raw === null) return undefined;
	if (typeof endpoint !== "string" || endpoint.length === 0) return undefined;
	const file = raw as { version?: unknown; endpoints?: unknown };
	if (file.version !== CACHE_VERSION) return undefined;
	if (typeof file.endpoints !== "object" || file.endpoints === null) return undefined;
	const record = (file.endpoints as Record<string, unknown>)[endpoint];
	if (typeof record !== "object" || record === null) return undefined;
	const entries = (record as { entries?: unknown }).entries;
	if (!Array.isArray(entries)) return undefined;
	return entries.filter(isUsableEntry);
}

/** Read the cache file for the declared endpoint, or undefined when it has no usable record. */
export function readCache(path: string, endpoint: string | undefined): ModelDefinition[] | undefined {
	try {
		return parseCache(JSON.parse(readFileSync(path, "utf-8")), endpoint);
	} catch {
		return undefined;
	}
}

/** The document a successful answer writes: the declared endpoint's record, replaced wholesale. */
export function serializeCache(endpoint: string, entries: readonly ModelDefinition[], now: Date): CacheFile {
	const stamp = now.toISOString();
	return { version: CACHE_VERSION, writtenAt: stamp, endpoints: { [endpoint]: { retrievedAt: stamp, entries: [...entries] } } };
}

/**
 * Write the cache atomically, replacing the file for the declared endpoint.
 *
 * The write lands a temporary file first, then renames it over the target, so a
 * failure leaves the previous content and a reader never sees a half file.
 */
export function writeCache(path: string, endpoint: string, entries: readonly ModelDefinition[], now: Date = new Date()): CacheWrite {
	const temporary = `${path}.tmp`;
	try {
		mkdirSync(dirname(path), { recursive: true });
		writeFileSync(temporary, `${JSON.stringify(serializeCache(endpoint, entries, now), null, 2)}\n`, "utf-8");
		renameSync(temporary, path);
		return { ok: true };
	} catch (error) {
		try {
			rmSync(temporary, { force: true });
		} catch {
			// The temporary file is already gone or unwritable; the write has still failed.
		}
		return { ok: false, reason: (error as Error)?.message ?? String(error) };
	}
}
