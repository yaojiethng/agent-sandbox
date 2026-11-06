// tests/skill_source_loader.mjs
// Probe pi's skill discovery for the nested-skill rule the ADR relies on.
//
// The loader's rule is: a directory containing SKILL.md is a skill root, and
// discovery does not recurse further. This script loads a fixture directory
// through pi's own `loadSkillsFromDir` and prints the discovered skill names.
//
// Usage: node tests/skill_source_loader.mjs <fixture-dir>

import { pathToFileURL } from "node:url";

import { piModuleEntry } from "../scripts/skill_layers.mjs";

const dir = process.argv[2];
if (!dir) {
  console.error("usage: node tests/skill_source_loader.mjs <fixture-dir>");
  process.exit(2);
}

const { loadSkillsFromDir } = await import(pathToFileURL(piModuleEntry()).href);
const { skills } = loadSkillsFromDir({ dir, source: "project" });
console.log(skills.map((skill) => skill.name).join(","));
