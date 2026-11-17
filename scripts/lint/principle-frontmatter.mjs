#!/usr/bin/env node
// scripts/lint/principle-frontmatter.mjs
//
// The principle-frontmatter gate: every principle under the provider root
// declares the frontmatter a reader and a tool depend on, and every declared
// value is valid. It owns `name`, `description`, `metadata.neighbours`,
// `metadata.leitwort`, `metadata.intent` and `metadata.mechanism`, and it
// rejects `disable-model-invocation` on a principle.
//
// The body shape is a convention, not this gate's subject:
// .agents/skills/instruction-authoring/references/skill-conventions.md
// `## A principle skill`.
//
// The inventory it imports is the lever: it reads the corpus once and reports
// the declared values, and this gate decides whether they fail.
//
// Usage:
//   node scripts/lint/principle-frontmatter.mjs [--root DIR]
//
// Exit:  0 = clean, 1 = a finding, 2 = the root could not be read.

import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { inventory, REPO } from "../principle_inventory.mjs";
import { loadPiFrontmatter } from "./pi-frontmatter.mjs";

const CONDITIONAL = ["leitwort"];
const REQUIRED_TEXT = ["intent", "mechanism"];

function compareFindings(a, b) {
  return a.skill.localeCompare(b.skill) || a.kind.localeCompare(b.kind);
}

function printFindings(findings) {
  for (const finding of findings) {
    console.log(`finding: ${finding.skill} ${finding.kind} -- ${finding.detail}`);
  }
}

/** The findings this gate adds over the inventory's neighbour findings. */
function declarationFindings(principles) {
  const findings = [];
  for (const principle of principles) {
    const { name } = principle;

    if (typeof principle.declaredName !== "string" || principle.declaredName.trim() === "") {
      findings.push({ skill: name, kind: "missing-name", detail: "name is absent" });
    } else if (principle.declaredName.trim() !== name) {
      findings.push({
        skill: name,
        kind: "name-mismatch",
        detail: `name is ${principle.declaredName}`,
      });
    }

    if (typeof principle.description !== "string" || principle.description.trim() === "") {
      findings.push({
        skill: name,
        kind: "missing-description",
        detail: "description is absent or empty",
      });
    }

    for (const field of REQUIRED_TEXT) {
      const value = principle[field];
      if (value === undefined) {
        findings.push({
          skill: name,
          kind: `missing-${field}`,
          detail: `metadata.${field} is absent`,
        });
      } else if (typeof value !== "string" || value.trim() === "") {
        findings.push({
          skill: name,
          kind: `malformed-${field}`,
          detail: `metadata.${field} is not a non-empty string`,
        });
      }
    }

    for (const field of CONDITIONAL) {
      const value = principle[field];
      if (value !== undefined && (typeof value !== "string" || value.trim() === "")) {
        findings.push({
          skill: name,
          kind: `malformed-${field}`,
          detail: `metadata.${field} is not a non-empty string`,
        });
      }
    }

    if (principle.disableModelInvocation !== undefined) {
      findings.push({
        skill: name,
        kind: "disable-model-invocation",
        detail: "a principle does not set disable-model-invocation",
      });
    }
  }
  return findings;
}

async function main(argv) {
  let root = REPO;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--root") {
      root = resolve(argv[++i] || "");
    } else if (arg === "--help" || arg === "-h") {
      console.log("usage: node scripts/lint/principle-frontmatter.mjs [--root DIR]");
      return 0;
    } else {
      console.error(`principle-frontmatter: unknown argument '${arg}'`);
      return 2;
    }
  }

  const { parseFrontmatter } = await loadPiFrontmatter("Principle frontmatter");

  let result;
  try {
    result = inventory(root, parseFrontmatter);
  } catch (error) {
    console.error(`principle-frontmatter: ${error.message}`);
    return 2;
  }

  const findings = [...result.findings, ...declarationFindings(result.principles)].sort(
    compareFindings,
  );
  printFindings(findings);
  console.log(
    `principle-frontmatter: ${result.principles.length} principle(s), ${findings.length} finding(s)`,
  );
  return findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  process.exitCode = await main(process.argv.slice(2));
}
