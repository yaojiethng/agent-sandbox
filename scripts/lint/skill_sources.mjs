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

import { existsSync, readFileSync, readdirSync } from "fs";
import { dirname, join, resolve, basename } from "path";
import { fileURLToPath } from "url";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ROOT = process.env.SKILL_SOURCE_ROOT
  ? resolve(process.env.SKILL_SOURCE_ROOT)
  : MODULE_ROOT;
const SKILLS_ROOT = join(ROOT, "src", "reasoning", "agent", "skills");
const STORE = process.env.SKILL_SOURCE_STORE
  ? resolve(process.env.SKILL_SOURCE_STORE)
  : join(ROOT, ".agents", "registry", "sources");
const FINDINGS = [];

const finding = (path, message) => FINDINGS.push(`${path}: ${message}`);
const isId = (value) => typeof value === "string" && /^[a-z0-9][a-z0-9._-]*$/.test(value);

/** Every skill directory under the workflow tree, mirroring pi's no-recurse rule. */
function skillDirs() {
  if (!existsSync(SKILLS_ROOT)) return [];
  return readdirSync(SKILLS_ROOT, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .filter((entry) => existsSync(join(SKILLS_ROOT, entry.name, "SKILL.md")))
    .map((entry) => entry.name)
    .sort();
}

/** The source ids the per-source store declares. The store schema is the CLI's. */
function sourceIds() {
  const ids = new Set();
  if (!existsSync(STORE)) {
    finding(STORE, "the source store does not exist");
    return ids;
  }
  const files = readdirSync(STORE)
    .filter((file) => file.endsWith(".json"))
    .sort();
  if (files.length === 0) {
    finding(STORE, "the source store holds no source files");
    return ids;
  }
  for (const file of files) {
    const path = join(STORE, file);
    let source;
    try {
      source = JSON.parse(readFileSync(path, "utf8"));
    } catch (error) {
      finding(path, `cannot parse the source file: ${error.message}`);
      continue;
    }
    if (!isId(source.id)) {
      finding(path, "the source file has no valid id");
      continue;
    }
    if (source.id !== basename(file, ".json")) {
      finding(path, `id ${source.id} does not match the filename ${basename(file, ".json")}`);
    }
    if (ids.has(source.id)) {
      finding(path, `id ${source.id} is listed twice`);
    }
    ids.add(source.id);
  }
  return ids;
}

function checkRecords(ids) {
  for (const name of skillDirs()) {
    const record = join(SKILLS_ROOT, name, "MAINTENANCE.md");
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
