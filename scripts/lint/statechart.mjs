// scripts/lint/statechart.mjs
// Holds the statechart's two statements of the state set together: the state
// declarations in `docs/reference/workflow_statechart.md`'s Mermaid chart, and
// the `## States` table.
//
// The unit is the column, not the table. The id and region columns restate the
// chart, so they are derived from it and compared here; the gloss column is
// authored prose and is never compared. `--write` rebuilds the two derived
// columns and keeps every existing gloss, seeding a newly declared state's gloss
// from its chart label.
//
// Usage: node scripts/lint/statechart.mjs [--doc PATH] [--write]

import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const docPath = resolve(argOf("--doc", resolve(REPO_ROOT, "docs/reference/workflow_statechart.md")));
const write = args.includes("--write");

const die = (message) => {
  console.error(`statechart gate: ${message}`);
  process.exit(1);
};

let doc;
try {
  doc = readFileSync(docPath, "utf8");
} catch (error) {
  die(`cannot read ${docPath}: ${error.message}`);
}

// The chart's declarations. A composite state opens a region; a plain state
// declaration belongs to the innermost open region.
const fence = /^```mermaid\n([\s\S]*?)\n```/m.exec(doc);
if (!fence) die(`${docPath} has no \`\`\`mermaid block`);

const declared = [];
const seen = new Set();
const regions = [];
for (const line of fence[1].split("\n")) {
  if (/^\s*}\s*$/.test(line)) {
    regions.pop();
    continue;
  }
  const composite = /^\s*state\s+"((?:[^"\\]|\\.)*)"\s+as\s+([A-Za-z0-9_]+)\s*\{\s*$/.exec(line);
  if (composite) {
    regions.push(composite[2]);
    continue;
  }
  const decl = /^\s*state\s+"((?:[^"\\]|\\.)*)"\s+as\s+([A-Za-z0-9_]+)\s*$/.exec(line);
  if (!decl) continue;
  const [, label, id] = decl;
  if (seen.has(id)) die(`the chart declares \`${id}\` twice`);
  seen.add(id);
  const prefix = `${id} -- `;
  declared.push({
    id,
    region: regions[regions.length - 1] ?? "",
    label: label.startsWith(prefix) ? label.slice(prefix.length) : label,
  });
}
if (declared.length === 0) die("the chart declares no state");

// The `## States` table.
const heading = /^## States$/m.exec(doc);
if (!heading) die(`${docPath} has no \`## States\` section`);
const sectionStart = heading.index + heading[0].length;
const rest = doc.slice(sectionStart);
const nextHeading = /^## /m.exec(rest);
const sectionEnd = nextHeading ? sectionStart + nextHeading.index : doc.length;
const lines = doc.slice(sectionStart, sectionEnd).split("\n");

const headerAt = lines.findIndex((line) => /^\|\s*Id\s*\|/.test(line));
if (headerAt < 0) die("`## States` has no table header");
const separatorAt = lines.findIndex((line, i) => i > headerAt && /^\|[\s|:-]+\|$/.test(line.trim()));
if (separatorAt < 0) die("`## States` has no table separator");

let tableEnd = separatorAt + 1;
while (tableEnd < lines.length && lines[tableEnd].trim().startsWith("|")) tableEnd++;

const rows = lines.slice(separatorAt + 1, tableEnd).map((line) => {
  const cells = line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim());
  return { id: cells[0].replace(/^`|`$/g, ""), region: cells[1] ?? "", gloss: cells[2] ?? "" };
});

const byId = new Map(rows.map((row) => [row.id, row]));
const declaredIds = new Set(declared.map((entry) => entry.id));
const findings = [];

for (const entry of declared) {
  const row = byId.get(entry.id);
  if (!row) findings.push({ subject: entry.id, message: "the chart declares it and `## States` lists no row" });
  else if (row.region !== entry.region) {
    findings.push({
      subject: entry.id,
      message: `the chart places it in \`${entry.region}\` and the table in \`${row.region}\``,
    });
  }
}
for (const row of rows) {
  if (!declaredIds.has(row.id)) findings.push({ subject: row.id, message: "`## States` lists it and the chart declares no such state" });
}
const declaredOrder = declared.map((entry) => entry.id).filter((id) => byId.has(id));
const tableOrder = rows.map((row) => row.id).filter((id) => declaredIds.has(id));
if (declaredOrder.join(",") !== tableOrder.join(",")) {
  findings.push({ subject: "## States", message: "the rows are not in the chart's declaration order" });
}

const generatedRows = declared.map((entry) => {
  const existing = byId.get(entry.id);
  const gloss = existing ? existing.gloss : entry.label;
  return `| \`${entry.id}\` | ${entry.region} | ${gloss} |`;
});

if (write) {
  const nextLines = [...lines.slice(0, separatorAt + 1), ...generatedRows, ...lines.slice(tableEnd)];
  writeFileSync(docPath, doc.slice(0, sectionStart) + nextLines.join("\n") + doc.slice(sectionEnd));
  console.log(`statechart: wrote ${generatedRows.length} row(s) to ${docPath}`);
  process.exit(0);
}

for (const finding of findings) console.log(`${finding.subject}: ${finding.message}`);
console.log(
  findings.length === 0
    ? `statechart: clean across ${declared.length} state(s)`
    : `statechart: ${findings.length} finding(s)`,
);
process.exit(findings.length === 0 ? 0 : 1);
