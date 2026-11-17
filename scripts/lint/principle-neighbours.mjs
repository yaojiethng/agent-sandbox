#!/usr/bin/env node
// scripts/lint/principle-neighbours.mjs
//
// The principle-neighbour gate: every principle skill declares
// `metadata.neighbours`, and every declared name resolves to a live principle.
// The admission pattern is
// .agents/skills/instruction-authoring/patterns/admission.md; the design record
// is devlog/discussions/20261114-design-concluded-principle_corpus_admission.md.
//
// There is no baseline. A missing field fails, every principle carries the
// field, and the existing corpus declares `[]` ("none declared"). A principle
// the survey finds with no neighbour is recorded on the survey map.
//
// Usage:
//   node scripts/lint/principle-neighbours.mjs [--root DIR]
//
// Exit:  0 = clean, 1 = a finding, 2 = the root could not be read.

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { inventory, REPO } from "../principle_inventory.mjs";
import { loadPiFrontmatter } from "./pi-frontmatter.mjs";

function printFindings(findings) {
  for (const finding of findings) {
    console.log(`finding: ${finding.skill} ${finding.kind} -- ${finding.detail}`);
  }
}

function compareFindings(a, b) {
  return a.skill.localeCompare(b.skill) || a.kind.localeCompare(b.kind);
}

async function main(argv) {
  let root = REPO;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--root") {
      root = resolve(argv[++i] || "");
    } else if (arg === "--help" || arg === "-h") {
      console.log("usage: node scripts/lint/principle-neighbours.mjs [--root DIR]");
      return 0;
    } else {
      console.error(`principle-neighbours: unknown argument '${arg}'`);
      return 2;
    }
  }

  const { parseFrontmatter } = await loadPiFrontmatter("Principle neighbours");

  let result;
  try {
    result = inventory(root, parseFrontmatter);
  } catch (error) {
    console.error(`principle-neighbours: ${error.message}`);
    return 2;
  }

  const findings = [...result.findings].sort(compareFindings);
  printFindings(findings);
  console.log(
    `principle-neighbours: ${result.principles.length} principle(s), ${findings.length} finding(s)`,
  );
  return findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  process.exitCode = await main(process.argv.slice(2));
}
