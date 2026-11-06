// The source store gate.
//
// The store at `.agents/registry/sources/` is the record of what a bump reads:
// an edge carries its source, the local artifact, the upstream path and the
// revision the next merge starts from. This gate holds it valid - the schema,
// every edge's path and passage anchor, the uniqueness of an edge's address, and
// each file's canonical form - so a bump cannot start from a broken record.
//
// It is not a registry and it checks no completeness: a path with no edge is a
// path nobody bumps. It checks no hash and no revision, and it never fetches, so
// a pinned store is not a drift alarm.
//
// Test seams: SKILL_SOURCE_ROOT points the tree at a fixture, and
// SKILL_SOURCE_STORE points the store at a fixture.
//
// Exit codes: 0 = clean, 1 = findings or the store cannot be read.

import { resolve } from "path";
import { dirname } from "path";
import { fileURLToPath } from "url";

import { STORE_REL, collectFindings, readStore } from "../skill_store.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ROOT = process.env.SKILL_SOURCE_ROOT
  ? resolve(process.env.SKILL_SOURCE_ROOT)
  : MODULE_ROOT;
const STORE = process.env.SKILL_SOURCE_STORE
  ? resolve(process.env.SKILL_SOURCE_STORE)
  : join_root();

function join_root() {
  return resolve(ROOT, STORE_REL);
}

const { entries, findings } = readStore(STORE);
const FINDINGS = [...findings, ...collectFindings(entries, { root: ROOT })];

if (FINDINGS.length > 0) {
  for (const entry of FINDINGS) console.error(entry);
  console.error(`skill sources: ${FINDINGS.length} finding(s)`);
  process.exit(1);
}

const artifacts = entries.reduce(
  (total, entry) => total + (Array.isArray(entry.source?.artifacts) ? entry.source.artifacts.length : 0),
  0,
);
console.log(`skill sources: clean across ${entries.length} source(s) and ${artifacts} artifact(s)`);
