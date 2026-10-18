// Pi's own frontmatter parser, for the lint scanners.
//
// A gate that parses frontmatter with a parser of its own decides by rules the
// product does not share, so it can pass a file pi drops and fail a file pi
// accepts. Pi exports the parser it loads skills, prompts and project context
// with, and the gate calls that function rather than reimplementing it.
//
// The package is resolved from the `pi` on PATH rather than hardcoded, so a
// moved install fails the gate loudly instead of silently skipping it. Same
// resolution shape as `yaml-loader.mjs`, which serves the scanners that read a
// file pi never loads.

import { execFileSync } from "child_process";
import { existsSync, realpathSync } from "fs";
import { dirname, join } from "path";
import { pathToFileURL } from "url";

const PACKAGE = join("@earendil-works", "pi-coding-agent");
const ENTRY = join("dist", "utils", "frontmatter.js");

/**
 * Resolve pi's frontmatter module, or exit 1 when it cannot be found.
 * `gateName` prefixes the error so the failing gate is named.
 */
export async function loadPiFrontmatter(gateName) {
  const attempts = [];
  let bin;
  try {
    bin = execFileSync("sh", ["-c", "command -v pi"], { encoding: "utf8" }).trim();
  } catch {
    attempts.push("pi on PATH");
  }
  if (bin) {
    // `pi` on PATH is a symlink into the package; the walk starts at the real
    // file or it never reaches the node_modules that holds the package.
    let dir = dirname(realpathSync(bin));
    for (let hop = 0; hop < 8; hop++) {
      const module = join(dir, "node_modules", PACKAGE, ENTRY);
      if (existsSync(module)) return import(pathToFileURL(module).href);
      dir = dirname(dir);
    }
    attempts.push("pi install tree");
  }
  if (process.env.PI_PACKAGE_DIR) {
    const module = join(process.env.PI_PACKAGE_DIR, ENTRY);
    if (existsSync(module)) return import(pathToFileURL(module).href);
    attempts.push("PI_PACKAGE_DIR");
  }
  console.error(`${gateName}: pi's frontmatter parser was not found (tried ${attempts.join(", ")}).`);
  console.error("Cannot run the gate. Install pi, or set PI_PACKAGE_DIR.");
  process.exit(1);
}
