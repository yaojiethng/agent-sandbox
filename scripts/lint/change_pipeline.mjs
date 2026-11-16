// scripts/lint/change_pipeline.mjs
// Holds the change pipeline's transition table to its chart: every Mermaid edge
// carries a transition id, every id has one `## The transitions` row, and every
// row names its lane, actor, mechanism, manual flag, subject, invariant, test
// and mutation.
//
// The model is `tests/model/change_pipeline/`: `chart.mmd`, `transitions.md` and
// the TLA+ module. The reference `docs/reference/change_pipeline.md` renders the
// chart and the table and links the TLA+; this scanner reads the home and
// compares the rendered copy. The chart is the diagram in `## The chart`; the
// table is `## The transitions`. This scanner checks the mapping, the lane
// vocabulary, the operator-git and remediation rows, the delivery parameter's
// presence, and the mutation catalog's subject match. It does not run TLC;
// `scripts/check_statechart.sh` owns the state table shape.
//
// Usage: node scripts/lint/change_pipeline.mjs [--model-dir=PATH] [--doc=PATH]
//        [--catalog=PATH] [--tests-dir=PATH] [--write]

import { readFileSync, readdirSync, statSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const usage = "usage: node scripts/lint/change_pipeline.mjs [--model-dir=PATH] [--doc=PATH] [--catalog=PATH] [--tests-dir=PATH] [--write]";
const VALUE_FLAGS = ["--model-dir", "--doc", "--catalog", "--tests-dir"];

const die = (message) => {
  console.error(`change pipeline gate: ${message}`);
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
  if (arg === "--write") continue;
  const eq = arg.indexOf("=");
  if (eq > 0 && VALUE_FLAGS.includes(arg.slice(0, eq))) continue;
  if (VALUE_FLAGS.includes(arg)) die(`${arg} requires a value with '='; ${usage}`);
  die(`unknown argument ${arg}; ${usage}`);
}

const docPath = resolve(valueArg("--doc") ?? resolve(REPO_ROOT, "docs/reference/change_pipeline.md"));
const modelDir = valueArg("--model-dir");
const catalogPath = resolve(valueArg("--catalog") ?? resolve(REPO_ROOT, "tests/mutations/catalog.jsonl"));
const testsDir = resolve(valueArg("--tests-dir") ?? resolve(REPO_ROOT, "tests"));
const write = args.includes("--write");

const stripTicks = (value) => value.replace(/^`|`$/g, "").trim();
const findings = [];

let doc;
try {
  doc = readFileSync(docPath, "utf8");
} catch (error) {
  console.error(`change pipeline gate: cannot read ${docPath}: ${error.message}`);
  process.exit(1);
}

let modelChart;
let modelTransitions;
if (modelDir) {
  try {
    modelChart = readFileSync(join(modelDir, "chart.mmd"), "utf8").replace(/\n+$/, "");
    modelTransitions = readFileSync(join(modelDir, "transitions.md"), "utf8");
  } catch (error) {
    die(`cannot read the model home ${modelDir}: ${error.message}`);
  }
}

const modelTransitionsSection =
  modelTransitions !== undefined
    ? modelTransitions.slice(modelTransitions.indexOf("## The transitions"))
    : undefined;

if (modelChart !== undefined) {
  const rendered = /^```mermaid\n([\s\S]*?)\n```/m.exec(doc)?.[1]?.replace(/\n+$/, "");
  if (rendered !== modelChart) findings.push("the rendered chart does not match the model home; run --write");
}
if (modelTransitions !== undefined) {
  const rendered = /^## The transitions\n[\s\S]*?(?=^## )/m.exec(doc)?.[0]?.replace(/\n+$/, "");
  if (rendered !== modelTransitionsSection.replace(/\n+$/, "")) {
    findings.push("the rendered transition section does not match the model home; run --write");
  }
}

const chartText =
  modelChart !== undefined
    ? modelChart
    : [...doc.matchAll(/^```mermaid\n([\s\S]*?)^```$/gm)].map((block) => block[1]).join("\n");
const chartEdges = [];
for (const line of chartText.split("\n")) {
  const edge = /^\s*(\[\*\]|\w+)\s*-->\s*(\[\*\]|\w+)\s*(?::\s*(.*))?$/.exec(line);
  if (!edge) continue;
  const label = (edge[3] ?? "").trim();
  const id = /^(T\d+)\b/.exec(label)?.[1];
  if (!id) continue;
  chartEdges.push({ id, from: edge[1], to: edge[2], label });
}

const section =
  modelTransitionsSection !== undefined
    ? modelTransitionsSection.replace(/^## The transitions\n/, "").replace(/\n+$/, "")
    : (/^## The transitions\n([\s\S]*?)(?=^## )/m.exec(doc)?.[1] ?? "").replace(/\n+$/, "");
const tableLines = section
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line.startsWith("|"));
if (tableLines.length < 3) findings.push("no `## The transitions` table");
const header = tableLines[0]?.split("|").slice(1, -1).map((cell) => cell.trim()) ?? [];
const expected = [
  "Id",
  "Lane",
  "Actor",
  "Event",
  "Guard",
  "From",
  "To",
  "Mechanism",
  "Manual",
  "Subject",
  "Invariant",
  "Test",
  "Mutation",
];
if (JSON.stringify(header) !== JSON.stringify(expected)) {
  findings.push(`the transition table header is ${header.join(", ")}; expected ${expected.join(", ")}`);
}

const rows = [];
for (const line of tableLines.slice(2)) {
  const cells = line.split("|").slice(1, -1).map((cell) => stripTicks(cell.trim()));
  if (cells.length !== expected.length) {
    findings.push(`a transition row has ${cells.length} cells; expected ${expected.length}: ${line}`);
    continue;
  }
  const row = Object.fromEntries(expected.map((name, index) => [name, cells[index]]));
  rows.push(row);
}

const byId = new Map();
for (const row of rows) {
  if (!/^T\d+$/.test(row.Id)) findings.push(`row id ${row.Id || "(empty)"} is not T<number>`);
  if (byId.has(row.Id)) findings.push(`row id ${row.Id} is duplicated`);
  byId.set(row.Id, row);
  if (!["agent", "host"].includes(row.Lane)) findings.push(`${row.Id}: Lane is ${row.Lane || "(empty)"}; expected agent or host`);
  if (!row.Actor || row.Actor === "-") findings.push(`${row.Id}: Actor is empty`);
  if (!["yes", "no"].includes(row.Manual)) findings.push(`${row.Id}: Manual is ${row.Manual || "(empty)"}; expected yes or no`);
  if (!row.Mechanism) findings.push(`${row.Id}: Mechanism is empty`);
  if (!row.Subject) findings.push(`${row.Id}: Subject is empty`);
  if (!row.Invariant) findings.push(`${row.Id}: Invariant is empty`);
  if (!row.Test) findings.push(`${row.Id}: Test is empty`);
  if (!row.Mutation) findings.push(`${row.Id}: Mutation is empty`);
}

const edgeIds = new Set(chartEdges.map((edge) => edge.id));
for (const edge of chartEdges) {
  if (!byId.has(edge.id)) findings.push(`${edge.id}: the chart edge has no transition row`);
}
for (const row of rows) {
  if (!edgeIds.has(row.Id)) findings.push(`${row.Id}: the transition row has no chart edge`);
}

const normalize = (state) =>
  state
    .replace(/^\[\*\]$/, "")
    .replace(/([a-z])([A-Z])/g, "$1-$2")
    .toLowerCase();
for (const edge of chartEdges) {
  const row = byId.get(edge.id);
  if (!row) continue;
  if (normalize(edge.from) !== row.From) {
    findings.push(`${edge.id}: chart from ${edge.from} does not match row from ${row.From}`);
  }
  if (normalize(edge.to) !== row.To) {
    findings.push(`${edge.id}: chart to ${edge.to} does not match row to ${row.To}`);
  }
}

for (const required of ["operator git", "reject and redraft"]) {
  const row = rows.find((candidate) => candidate.Event === required);
  if (!row) findings.push(`no transition row for ${required}`);
  else if (row.Manual !== "yes") findings.push(`${row.Id}: ${required} is a manual host action and must be Manual yes`);
}
if (!rows.some((row) => row.Event === "reject and redraft" && row.Mechanism.includes("make reject") && row.Mechanism.includes("make draft"))) {
  findings.push("the reject-and-redraft row does not name make reject then make draft");
}

for (const word of ["copy", "mount", "full", "flatten"]) {
  if (!new RegExp(`\\b${word}\\b`, "i").test(doc)) findings.push(`the model does not name ${word}`);
}

const catalog = new Map();
try {
  for (const line of readFileSync(catalogPath, "utf8").split("\n")) {
    if (!line.trim()) continue;
    const parsed = JSON.parse(line);
    if (typeof parsed.id === "number") catalog.set(parsed.id, parsed);
  }
} catch (error) {
  console.error(`change pipeline gate: cannot read ${catalogPath}: ${error.message}`);
  process.exit(1);
}

const testNames = new Set();
const walk = (directory) => {
  for (const entry of readdirSync(directory)) {
    const path = join(directory, entry);
    if (statSync(path).isDirectory()) walk(path);
    else if (entry.endsWith(".sh") || entry.endsWith(".mjs") || entry.endsWith(".ts")) {
      const text = readFileSync(path, "utf8");
      for (const match of text.matchAll(/\b(test_[a-zA-Z0-9_]+)\s*\(/g)) testNames.add(match[1]);
    }
  }
};
walk(testsDir);

for (const row of rows) {
  if (!row.Test.startsWith("none:") && !testNames.has(row.Test)) {
    findings.push(`${row.Id}: test ${row.Test} is not a test function under tests/`);
  }
  if (row.Mutation.startsWith("none:")) continue;
  const ids = [...row.Mutation.matchAll(/\b\d+\b/g)].map((match) => Number(match[0]));
  if (ids.length === 0) findings.push(`${row.Id}: Mutation names no catalog id`);
  for (const id of ids) {
    const mutation = catalog.get(id);
    if (!mutation) findings.push(`${row.Id}: mutation ${id} is not in the catalog`);
    else if (mutation.subject !== row.Subject) {
      findings.push(`${row.Id}: mutation ${id} mutates ${mutation.subject}, expected ${row.Subject}`);
    }
  }
}

if (write) {
  if (modelChart === undefined || modelTransitions === undefined) {
    die("--write needs --model-dir so there is a model to write from");
  }
  let nextDoc = doc.replace(
    /^```mermaid\n[\s\S]*?\n```/m,
    "```mermaid\n" + modelChart + "\n```",
  );
  nextDoc = nextDoc.replace(
    /^## The transitions\n[\s\S]*?(?=^## )/m,
    modelTransitionsSection.replace(/\n+$/, "") + "\n\n",
  );
  writeFileSync(docPath, nextDoc);
  console.log(`change pipeline: wrote the chart and the transitions to ${docPath}`);
  process.exit(0);
}

if (findings.length > 0) {
  for (const finding of findings) console.error(`- ${finding}`);
  process.exit(1);
}
console.log(`change pipeline: clean across ${rows.length} transition(s)`);
