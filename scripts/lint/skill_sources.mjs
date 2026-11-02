// The workflow skill record gate.
//
// Every skill directory under `src/reasoning/agent/skills/` carries a
// `MAINTENANCE.md`. The record holds `## Source`, `## Adapted` and `## Name`;
// a forked record names a source id from the per-source store at
// `.agents/registry/sources/`, and a home-grown record says `Source: home-grown.`
//
// The gate checks the records and the source ids. It does not check the store
// schema, a hash or a revision; the `source-bump` CLI is the store's writer and
// validator, and a bump runs only when the operator directs it.
//
// Test seams: SKILL_SOURCE_ROOT points the tree at a fixture, and
// SKILL_SOURCE_STORE points the store at a fixture.
//
// Exit codes: 0 = clean, 1 = findings or the store cannot be read.

import { existsSync, readFileSync } from "fs";
import { dirname, join, resolve, basename } from "path";
import { fileURLToPath } from "url";

import { LAYERS, discoverSkillDirs } from "../skill_layers.mjs";
import { STORE_REL, identityFindings, readStore, storeIds } from "../skill_store.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ROOT = process.env.SKILL_SOURCE_ROOT
  ? resolve(process.env.SKILL_SOURCE_ROOT)
  : MODULE_ROOT;
const SKILLS_ROOT = join(ROOT, LAYERS.find((layer) => layer.name === "agent-sandbox").source);
const STORE = process.env.SKILL_SOURCE_STORE
  ? resolve(process.env.SKILL_SOURCE_STORE)
  : join(ROOT, STORE_REL);
const FINDINGS = [];

const finding = (path, message) => FINDINGS.push(`${path}: ${message}`);

/** Every skill directory under the agent layer, by pi's no-recurse rule. */
function skillDirs() {
  return discoverSkillDirs(SKILLS_ROOT).sort();
}

/** The source ids the per-source store declares. The store's schema is the CLI's;
 * its path, its read and its identity rules are `scripts/skill_store.mjs`'s. */
function sourceIds() {
  const { entries, findings } = readStore(STORE);
  for (const entry of findings) FINDINGS.push(entry);
  for (const entry of identityFindings(entries)) FINDINGS.push(entry);
  return storeIds(entries);
}

function checkRecords(ids) {
  const dirs = skillDirs();
  if (dirs.length === 0) {
    finding(SKILLS_ROOT, "the agent skill layer holds no skill directory");
    return;
  }
  for (const dir of dirs) {
    const name = basename(dir);
    const record = join(dir, "MAINTENANCE.md");
    if (!existsSync(record)) {
      finding(record, `skill ${name} has no MAINTENANCE.md record`);
      continue;
    }
    const text = readFileSync(record, "utf8");
    const lines = text.split("\n");
    for (const heading of ["## Source", "## Adapted", "## Name"]) {
      if (!lines.includes(heading)) {
        finding(record, `skill ${name} record is missing '${heading}'`);
      }
    }
    if (!/^Source:/m.test(text)) {
      finding(record, `skill ${name} record is missing its Source line`);
      continue;
    }
    if (/^Source:\s*home-grown\b/m.test(text)) continue;
    const match = text.match(/^Source:\s*`([^`]+)`/m);
    if (!match) {
      finding(record, `skill ${name} record must name a source id or state home-grown`);
      continue;
    }
    if (!ids.has(match[1])) {
      finding(record, `skill ${name} record names source ${match[1]}, which is not in the store`);
    }
  }
}

const ids = sourceIds();
checkRecords(ids);

if (FINDINGS.length > 0) {
  for (const entry of FINDINGS) console.error(entry);
  console.error(`skill sources: ${FINDINGS.length} finding(s)`);
  process.exit(1);
}

console.log(
  `skill sources: clean across ${skillDirs().length} skill record(s) and ${ids.size} source(s)`,
);
