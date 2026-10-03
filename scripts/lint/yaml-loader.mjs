// Shared YAML loader for the lint scanners.
//
// The `yaml` package pi ships is not a dependency of this repository, so it is
// resolved from pi's own install tree, which the repository pins. The path is
// derived from the `pi` on PATH rather than hardcoded, so a moved install does
// not silently skip a gate. One loader, so the resolution order has one home.

import { execFileSync } from "child_process";
import { existsSync, realpathSync } from "fs";
import { createRequire } from "module";
import { dirname, join } from "path";

/**
 * Load the `yaml` package, or exit 1 when it cannot be found.
 * `gateName` prefixes the error so the failing gate is named.
 */
export function loadYaml(gateName) {
  const attempts = [];
  try {
    return createRequire(import.meta.url)("yaml");
  } catch (error) {
    attempts.push("repository node_modules");
  }
  try {
    const bin = execFileSync("sh", ["-c", "command -v pi"], { encoding: "utf8" }).trim();
    // `pi` on PATH is a symlink into the package; the walk has to start at the
    // real file or it never reaches the node_modules that holds the package.
    let dir = dirname(realpathSync(bin));
    for (let hop = 0; hop < 8; hop++) {
      const candidate = join(dir, "node_modules", "yaml", "package.json");
      if (existsSync(candidate)) return createRequire(candidate)("yaml");
      dir = dirname(dir);
    }
    attempts.push("pi install tree");
  } catch {
    attempts.push("pi on PATH");
  }
  console.error(`${gateName}: the yaml parser was not found (tried ${attempts.join(", ")}).`);
  console.error("Cannot run the gate. Install pi, or add yaml to the repository.");
  process.exit(1);
}
