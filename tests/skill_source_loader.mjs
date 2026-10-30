// tests/skill_source_loader.mjs
// Probe pi's skill discovery for the nested-skill rule the ADR relies on.
//
// The loader's rule is: a directory containing SKILL.md is a skill root, and
// discovery does not recurse further. This script loads a fixture directory
// through pi's own `loadSkillsFromDir` and prints the discovered skill names.
//
// Usage: node tests/skill_source_loader.mjs <fixture-dir>

import { execFileSync } from "child_process";
import { existsSync, realpathSync } from "fs";
import { dirname, join } from "path";
import { pathToFileURL } from "url";

const PACKAGE = join("@earendil-works", "pi-coding-agent");
const ENTRY = join("dist", "index.js");

function packageEntry() {
  try {
    const bin = execFileSync("sh", ["-c", "command -v pi"], { encoding: "utf8" }).trim();
    let dir = dirname(realpathSync(bin));
    for (let hop = 0; hop < 8; hop++) {
      const module = join(dir, "node_modules", PACKAGE, ENTRY);
      if (existsSync(module)) return module;
      dir = dirname(dir);
    }
  } catch {
    // Fall through to PI_PACKAGE_DIR.
  }
  if (process.env.PI_PACKAGE_DIR) {
    const module = join(process.env.PI_PACKAGE_DIR, ENTRY);
    if (existsSync(module)) return module;
  }
  throw new Error("pi's package could not be resolved; set PI_PACKAGE_DIR");
}

const dir = process.argv[2];
if (!dir) {
  console.error("usage: node tests/skill_source_loader.mjs <fixture-dir>");
  process.exit(2);
}

const { loadSkillsFromDir } = await import(pathToFileURL(packageEntry()).href);
const { skills } = loadSkillsFromDir({ dir, source: "project" });
console.log(skills.map((skill) => skill.name).join(","));
