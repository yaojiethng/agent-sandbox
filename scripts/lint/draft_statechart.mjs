// scripts/lint/draft_statechart.mjs
// Holds the draft branch statechart's transitions together: every Mermaid edge
// carries a transition id, and every id has one transition row with a
// subject, guard, invariant, precondition, postcondition, test and mutation.
//
// This is the mapping check for the draft branch model. It does not re-read the
// state declarations; `scripts/lint/statechart.mjs` owns the state table shape. It
// checks the parts the model owes its tests: an id on every edge, a subject
// and invariant on every product row, a real test function for every product
// transition, a catalog row for every mutation whose subject matches, no two
// same-event transitions from one state with an empty guard, one id prefix per
// chart block, and one chart block per prefix.
//
// Usage: node scripts/lint/draft_statechart.mjs [--doc=PATH] [--catalog=PATH]
//        [--tests-dir=PATH]

import { readFileSync, readdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const usage =
  "usage: node scripts/lint/draft_statechart.mjs [--doc=PATH] [--catalog=PATH] [--tests-dir=PATH]";
const VALUE_FLAGS = ["--doc", "--catalog", "--tests-dir"];

const die = (message) => {
  console.error(`draft statechart gate: ${message}`);
  process.exit(1);
};

const valueArg = (flag) => {
  const prefix = `${flag}=`;
  const matches = args.filter((arg) => arg.startsWith(prefix));
  if (matches.length > 1) die(`${flag} given more than once; ${usage}`);
  if (matches.length === 0) return undefined;
  const value = matches[0].slice(prefix.length);
  if (!value) die(`${flag} has an empty value; ${usage}`);
  return value;
};

for (const arg of args) {
  const eq = arg.indexOf("=");
  if (eq > 0 && VALUE_FLAGS.includes(arg.slice(0, eq))) continue;
  if (VALUE_FLAGS.includes(arg)) die(`${arg} requires a value with '='; ${usage}`);
  die(`unknown argument ${arg}; ${usage}`);
}

const docPath = resolve(valueArg("--doc") ?? resolve(REPO_ROOT, "docs/reference/draft_branch_statechart.md"));
const catalogPath = resolve(valueArg("--catalog") ?? resolve(REPO_ROOT, "tests/mutations/catalog.jsonl"));
const testsDir = resolve(valueArg("--tests-dir") ?? resolve(REPO_ROOT, "tests"));

const stripTicks = (value) => value.replace(/^`|`$/g, "").trim();

let doc;
try {
  doc = readFileSync(docPath, "utf8");
} catch (error) {
  console.error(`draft statechart gate: cannot read ${docPath}: ${error.message}`);
  process.exit(1);
}

const edges = [];
const unlabeledEdges = [];
const malformedEdges = [];
let blockIndex = 0;
for (const block of doc.matchAll(/^```mermaid\n([\s\S]*?)^```$/gm)) {
  blockIndex += 1;
  for (const line of block[1].split("\n")) {
    const edge = /^\s*(\[\*\]|\w+)\s*-->\s*(\[\*\]|\w+)\s*(?::\s*(.*))?$/.exec(line);
    if (!edge) {
      if (line.includes("-->")) {
        malformedEdges.push({ block: blockIndex, line: line.trim() });
      }
      continue;
    }
    const from = edge[1];
    const to = edge[2];
    const label = (edge[3] ?? "").trim();
    if (label === "") {
      unlabeledEdges.push({ from, to, reason: "the edge has no transition label" });
      continue;
    }
    const idMatch = /^([A-Z]\d+)\b(.*)$/.exec(label);
    if (!idMatch) {
      unlabeledEdges.push({ from, to, reason: `the label \`${label}\` has no transition id` });
      continue;
    }
    edges.push({ id: idMatch[1], from, to, label: idMatch[2].trim(), block: blockIndex });
  }
}

const rows = [];
for (const line of doc.split("\n")) {
  if (!/^\|\s*`[A-Z]\d+`\s*\|/.test(line)) continue;
  const cells = line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim());
  if (cells.length !== 11) {
    console.error(`draft statechart gate: transition row has ${cells.length} columns, expected 11: ${line}`);
    process.exit(1);
  }
  rows.push({
    id: stripTicks(cells[0]),
    from: stripTicks(cells[1]),
    event: stripTicks(cells[2]),
    guard: stripTicks(cells[3]),
    to: stripTicks(cells[4]),
    subject: stripTicks(cells[5]),
    invariant: cells[6],
    precondition: cells[7],
    postcondition: cells[8],
    tests: cells[9],
    mutation: cells[10],
  });
}
if (rows.length === 0) {
  console.error("draft statechart gate: no transition rows");
  process.exit(1);
}

const testNames = new Set();
for (const entry of readdirSync(testsDir, { recursive: true, withFileTypes: true })) {
  if (!entry.isFile() || !entry.name.endsWith(".sh")) continue;
  const file = join(entry.parentPath ?? testsDir, entry.name);
  for (const match of readFileSync(file, "utf8").matchAll(/^\s*(test_[A-Za-z0-9_]+)\s*\(\)/gm)) {
    testNames.add(match[1]);
  }
}

const catalogRows = new Map();
for (const line of readFileSync(catalogPath, "utf8").split("\n")) {
  if (!line.trim()) continue;
  let parsed;
  try {
    parsed = JSON.parse(line);
  } catch {
    continue;
  }
  if (typeof parsed.id === "number") catalogRows.set(parsed.id, parsed);
}
const catalogIds = new Set(catalogRows.keys());

const findings = [];
const prefixesByBlock = new Map();
for (const edge of edges) {
  if (!prefixesByBlock.has(edge.block)) prefixesByBlock.set(edge.block, new Set());
  prefixesByBlock.get(edge.block).add(edge.id[0]);
}
const blocksByPrefix = new Map();
for (const [block, prefixes] of prefixesByBlock) {
  if (prefixes.size > 1) {
    findings.push(
      `chart block ${block} mixes transition prefixes: ${[...prefixes].sort().join(", ")}`,
    );
  }
  for (const prefix of prefixes) {
    if (!blocksByPrefix.has(prefix)) blocksByPrefix.set(prefix, new Set());
    blocksByPrefix.get(prefix).add(block);
  }
}
for (const [prefix, blocks] of blocksByPrefix) {
  if (blocks.size > 1) {
    findings.push(
      `transition prefix \`${prefix}\` appears in chart blocks ${[...blocks].sort((a, b) => a - b).join(", ")}`,
    );
  }
}
for (const edge of malformedEdges) {
  findings.push(
    `chart block ${edge.block}: the edge is not in the canonical form: \`${edge.line}\``,
  );
}
for (const edge of unlabeledEdges) {
  findings.push(`${edge.from} -> ${edge.to}: ${edge.reason}`);
}
const rowsById = new Map();
for (const row of rows) {
  if (rowsById.has(row.id)) findings.push(`${row.id}: the transition table declares the id twice`);
  rowsById.set(row.id, row);
}
const edgesById = new Map();
for (const edge of edges) {
  if (edgesById.has(edge.id)) findings.push(`${edge.id}: the chart declares the transition id twice`);
  edgesById.set(edge.id, edge);
}

for (const edge of edges) {
  const row = rowsById.get(edge.id);
  if (!row) {
    findings.push(`${edge.id}: the chart has the edge and \`## Transitions\` has no row`);
    continue;
  }
  if (row.from !== edge.from || row.to !== edge.to) {
    findings.push(`${edge.id}: the chart says ${edge.from} -> ${edge.to}, the table says ${row.from} -> ${row.to}`);
  }
}
for (const row of rows) {
  if (!edgesById.has(row.id)) findings.push(`${row.id}: \`## Transitions\` has the row and the chart has no edge`);
  if (!row.precondition || row.precondition === "-") findings.push(`${row.id}: no precondition`);
  if (!row.postcondition || row.postcondition === "-") findings.push(`${row.id}: no postcondition`);
  const noInvariant = row.invariant.startsWith("none:");
  const modelOnly = row.subject === "-" || row.subject.startsWith("none:");
  if (!noInvariant && modelOnly) {
    findings.push(`${row.id}: names an invariant and no subject`);
  }
  if (!noInvariant && row.tests.startsWith("none:")) {
    findings.push(`${row.id}: names an invariant and no test`);
  }
  if (!noInvariant && row.mutation.startsWith("none:")) {
    findings.push(`${row.id}: names an invariant and no mutation`);
  }
  if (!row.tests.startsWith("none:")) {
    const names = [...row.tests.matchAll(/`([^`]+)`/g)].map((match) => match[1]);
    if (names.length === 0) findings.push(`${row.id}: the Tests cell names no test function`);
    for (const name of names) {
      if (!testNames.has(name)) findings.push(`${row.id}: test \`${name}\` is not defined in tests/`);
    }
  }
  if (!row.mutation.startsWith("none:")) {
    const ids = [...row.mutation.matchAll(/\b\d+\b/g)].map((match) => Number(match[0]));
    if (ids.length === 0) findings.push(`${row.id}: the Mutation cell names no catalog id`);
    for (const id of ids) {
      if (!catalogIds.has(id)) {
        findings.push(`${row.id}: mutation ${id} is not in the catalog`);
        continue;
      }
      if (!modelOnly) {
        const mutation = catalogRows.get(id);
        if (mutation.subject !== row.subject) {
          findings.push(`${row.id}: mutation ${id} mutates ${mutation.subject}, expected ${row.subject}`);
        }
      }
    }
  }
}

const byStateAndEvent = new Map();
for (const row of rows) {
  const key = `${row.id[0]}\u0000${row.from}\u0000${row.event}`;
  if (!byStateAndEvent.has(key)) byStateAndEvent.set(key, []);
  byStateAndEvent.get(key).push(row);
}
for (const group of byStateAndEvent.values()) {
  if (group.length > 1 && group.every((row) => row.guard === "-")) {
    findings.push(`${group[0].from}: ${group.length} transitions share the event \`${group[0].event}\` and none has a guard`);
  }
}

for (const finding of findings) console.log(finding);
console.log(
  findings.length === 0
    ? `draft statechart: clean across ${rows.length} transition(s)`
    : `draft statechart: ${findings.length} finding(s)`,
);
process.exit(findings.length === 0 ? 0 : 1);
