// scripts/skill_store.mjs
//
// The source store: where it lives, what an entry is called, and the checks that
// make an entry addressable. One reader, shared by the CLI that writes the store
// and the gate that certifies the skills pointing at it, so a store the writer
// accepts cannot be one the gate rejects.
//
// The store's schema, its artifact rules and its hashes are the CLI's; this
// module holds only the identity every reader has to agree on.

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { basename, join } from "node:path";

export const STORE_REL = ".agents/registry/sources";

export const isId = (value) => typeof value === "string" && /^[a-z0-9][a-z0-9._-]*$/.test(value);

// readStore STORE -- every parseable entry in the store, in filename order, with
// the findings the read itself produced. A missing or empty store is a finding
// unless the caller is writing one.
export function readStore(store, { allowMissing = false } = {}) {
  if (!existsSync(store)) {
    if (allowMissing) return { entries: [], findings: [] };
    return { entries: [], findings: [`${store}: the tracking store does not exist`] };
  }
  const files = readdirSync(store)
    .filter((file) => file.endsWith(".json"))
    .sort();
  if (files.length === 0 && !allowMissing) {
    return { entries: [], findings: [`${store}: the tracking store holds no source files`] };
  }
  const entries = [];
  const findings = [];
  for (const file of files) {
    const path = join(store, file);
    try {
      entries.push({ file, path, source: JSON.parse(readFileSync(path, "utf8")) });
    } catch (error) {
      findings.push(`${path}: ${error.message}`);
    }
  }
  return { entries, findings };
}

// identityFindings ENTRIES -- an id shaped like an id, an id named by its file,
// and no id or file claimed twice.
export function identityFindings(entries) {
  const findings = [];
  const ids = new Map();
  for (const entry of entries) {
    const source = entry.source;
    if (source === null || typeof source !== "object" || Array.isArray(source)) continue;
    if (!isId(source.id)) {
      findings.push(`${entry.path}: id must be a lowercase source id`);
      continue;
    }
    if (source.id !== basename(entry.file, ".json")) {
      findings.push(`${entry.path}: id ${source.id} does not match the filename ${basename(entry.file, ".json")}`);
    }
    if (ids.has(source.id)) {
      findings.push(`${entry.path}: id ${source.id} is already used by ${ids.get(source.id)}`);
      continue;
    }
    ids.set(source.id, entry.path);
  }
  return findings;
}

// storeIds ENTRIES -- the ids the store declares, for a reader that only needs
// to know which names exist.
export function storeIds(entries) {
  const ids = new Set();
  for (const entry of entries) {
    if (entry.source && isId(entry.source.id)) ids.add(entry.source.id);
  }
  return ids;
}
