#!/usr/bin/env node
// scripts/lint/principle-neighbours.mjs
//
// The principle-neighbour gate: every principle skill declares
// `metadata.neighbours`, and every declared name resolves to a live principle.
// The admission pattern is
// .agents/skills/instruction-authoring/patterns/admission.md; the design record
// is devlog/discussions/20261114-design-concluded-principle_corpus_admission.md.
//
// The baseline (`principle-neighbours.baseline`) holds the principles that
// predate the field. It may only shrink: a principle absent from the baseline
// fails, and a baseline entry that has gained the field fails until --update
// drops it. The baseline is a gated copy with this gate as its only consumer.
//
// Usage:
//   node scripts/lint/principle-neighbours.mjs [--root DIR] [--baseline FILE] [--update]
//
// Exit:  0 = clean, 1 = a finding, 2 = the baseline is missing or the run failed.

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { inventory, REPO } from "../principle_inventory.mjs";
import { loadPiFrontmatter } from "./pi-frontmatter.mjs";

const HERE = dirname(fileURLToPath(import.meta.url));
const DEFAULT_BASELINE = join(HERE, "principle-neighbours.baseline");
const BASELINE_HEADER = [
  "# scripts/lint/principle-neighbours.baseline",
  "# Principle skills that predate `metadata.neighbours`. The gate fails a",
  "# principle absent from this list, and fails an entry that has gained the",
  "# field until --update drops it. This list only shrinks; never add a name.",
].join("\n");

function readBaseline(path) {
  if (!existsSync(path)) return null;
  return readFileSync(path, "utf8")
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line !== "" && !line.startsWith("#"));
}

function writeBaseline(path, names) {
  const body = names.length === 0 ? "" : `${names.join("\n")}\n`;
  writeFileSync(path, `${BASELINE_HEADER}\n${body}`);
}

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
  let baselinePath = DEFAULT_BASELINE;
  let update = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--root") {
      root = resolve(argv[++i] || "");
    } else if (arg === "--baseline") {
      baselinePath = resolve(argv[++i] || "");
    } else if (arg === "--update") {
      update = true;
    } else if (arg === "--help" || arg === "-h") {
      console.log(
        "usage: node scripts/lint/principle-neighbours.mjs [--root DIR] [--baseline FILE] [--update]",
      );
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

  const missing = result.principles
    .filter((principle) => principle.state === "missing")
    .map((principle) => principle.name)
    .sort();

  if (update) {
    const hard = result.findings
      .filter((finding) => finding.kind !== "missing-field")
      .sort(compareFindings);
    if (hard.length > 0) {
      printFindings(hard);
      console.error("principle-neighbours: refusing --update while a structural finding is open");
      return 1;
    }
    const existing = readBaseline(baselinePath);
    if (existing !== null) {
      const known = new Set(existing);
      const additions = missing.filter((name) => !known.has(name));
      if (additions.length > 0) {
        console.error(
          `principle-neighbours: refusing to add ${additions.join(", ")}; a new principle declares the field`,
        );
        return 1;
      }
    }
    writeBaseline(baselinePath, missing);
    console.log(`principle-neighbours: baseline updated to ${missing.length} principle(s)`);
    return 0;
  }

  const baseline = readBaseline(baselinePath);
  if (baseline === null) {
    console.error(`principle-neighbours: no baseline at ${baselinePath}`);
    return 2;
  }
  const baselineSet = new Set(baseline);
  const findings = [];

  for (const finding of result.findings) {
    if (finding.kind !== "missing-field") {
      findings.push(finding);
    } else if (!baselineSet.has(finding.skill)) {
      findings.push({
        ...finding,
        kind: "unbaselined-missing",
        detail: "metadata.neighbours is absent and the principle is not in the baseline",
      });
    }
  }

  for (const name of baseline) {
    const principle = result.principles.find((candidate) => candidate.name === name);
    if (!principle) {
      findings.push({
        skill: name,
        kind: "stale-baseline",
        detail: "the baseline names a principle the provider root does not hold",
      });
    } else if (principle.state !== "missing") {
      findings.push({
        skill: name,
        kind: "stale-baseline",
        detail: "the principle now declares a field; run --update to drop the entry",
      });
    }
  }

  findings.sort(compareFindings);
  printFindings(findings);
  console.log(
    `principle-neighbours: ${result.principles.length} principle(s), ${baseline.length} baselined, ${findings.length} finding(s)`,
  );
  return findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  process.exitCode = await main(process.argv.slice(2));
}
