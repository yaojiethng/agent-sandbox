#!/usr/bin/env node
// scripts/render_skill_graph.mjs
//
// The thin renderer. It asks the graph builder for a graph, asks it for Mermaid,
// then calls Pele. There is no artifact or resolution logic here.
//
// Usage:
//   node scripts/render_skill_graph.mjs
//   node scripts/render_skill_graph.mjs --evidence FILE --out DIR
//
// Defaults: live evidence from the repository, output in the workspace output
// mount. Pele defaults to <out>/vendor/pele.js; set PELE_MODULE to override.
//
// Exit: 0 on a rendered graph, even when the graph contains drift. A structural
// graph finding is exit 1; the graph is not rendered.

import { copyFileSync, existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import {
  buildGraph,
  checkGraph,
  collectEvidence,
  toMermaid,
} from "./skill_graph.mjs";

const ROOT = resolve(join(new URL(".", import.meta.url).pathname, ".."));
const args = process.argv.slice(2);
let evidenceFile = null;
let out = "/home/agentuser/workspace/output";
for (let index = 0; index < args.length; index++) {
  if (args[index] === "--evidence") evidenceFile = args[++index] || "";
  else if (args[index] === "--out") out = args[++index] || out;
  else if (args[index] === "--help" || args[index] === "-h") {
    console.log("usage: node scripts/render_skill_graph.mjs [--evidence FILE] [--out DIR]");
    process.exit(0);
  } else {
    console.error(`render_skill_graph: unknown argument '${args[index]}'`);
    process.exit(2);
  }
}

const evidence = evidenceFile
  ? JSON.parse(readFileSync(evidenceFile, "utf8"))
  : collectEvidence(ROOT);
const graph = buildGraph(evidence);
const checked = checkGraph(graph, { allowDrift: true });
for (const warning of checked.warnings) console.log(`warning: ${warning}`);
for (const drift of checked.drifts) console.log(`drift: ${drift.from} -> ${drift.to}`);
for (const finding of checked.findings) console.error(`finding: ${finding}`);
if (checked.findings.length > 0) {
  console.error(`render_skill_graph: ${checked.findings.length} structural finding(s)`);
  process.exit(1);
}

const mermaid = toMermaid(graph);
const pelePath = process.env.PELE_MODULE || join(out, "vendor", "pele.js");
if (!existsSync(pelePath)) {
  console.error(`render_skill_graph: Pele is missing at ${pelePath}`);
  process.exit(1);
}
if (!existsSync(join(out, "vendor"))) mkdirSync(join(out, "vendor"), { recursive: true });

const { render } = await import(pathToFileURL(pelePath).href);
const result = render(mermaid, { responsive: false });
if (!result || typeof result.svg !== "string") {
  console.error("render_skill_graph: Pele returned no SVG");
  process.exit(1);
}

mkdirSync(out, { recursive: true });
writeFileSync(join(out, "skill-provenance.json"), `${JSON.stringify(graph, null, 2)}\n`);
writeFileSync(join(out, "skill-provenance.mmd"), mermaid);
writeFileSync(join(out, "skill-provenance.svg"), result.svg);

// Keep the vendored Pele notice beside the generated artifact.
const license = join(ROOT, ".scratchpad", "pele-render", "node_modules", "pele", "LICENSE");
if (existsSync(license) && !existsSync(join(out, "vendor", "pele-LICENSE"))) {
  copyFileSync(license, join(out, "vendor", "pele-LICENSE"));
}

console.log(
  `wrote ${join(out, "skill-provenance.svg")} (${result.width}x${result.height}) ` +
    `from ${graph.summary.nodes} nodes, ${graph.summary.links} links, ` +
    `${graph.summary.drift} drift`,
);
console.log(`wrote ${join(out, "skill-provenance.json")}`);
console.log(`wrote ${join(out, "skill-provenance.mmd")}`);
