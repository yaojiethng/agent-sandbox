// tests/skill_layer_loader.mjs
// Probe pi's skill resolver with the four layer roots in precedence order.
//
// The probe is the knowledge test's oracle: it calls pi's own `loadSkills`
// with project, provider, agent-sandbox and workflow roots, so a collision
// shows which layer wins and which layers are shadowed.
//
// Usage: node tests/skill_layer_loader.mjs <fixture-root>

import { execFileSync } from "node:child_process";
import { existsSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

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

const root = resolve(process.argv[2] || "");
if (!process.argv[2]) {
  console.error("usage: node tests/skill_layer_loader.mjs <fixture-root>");
  process.exit(2);
}

const layers = [
  { name: "project", path: resolve(root, ".agents/skills") },
  {
    name: "provider",
    path: resolve(root, "src/reasoning/providers/pi/config/agent/skills"),
  },
  { name: "agent-sandbox", path: resolve(root, "src/reasoning/agent/skills") },
  { name: "workflow", path: resolve(root, "workflow/coding-agent/skills") },
];

const layerOf = (file) => {
  for (const layer of layers) {
    if (file === layer.path || file.startsWith(`${layer.path}/`)) return layer.name;
  }
  return "unknown";
};

const { loadSkills } = await import(pathToFileURL(packageEntry()).href);
const result = loadSkills({
  cwd: root,
  agentDir: join(root, ".scratchpad", "agent"),
  skillPaths: layers.map((layer) => layer.path),
  includeDefaults: false,
});

for (const skill of result.skills) {
  console.log(`winner ${layerOf(skill.filePath)} ${skill.name}`);
}
for (const diagnostic of result.diagnostics) {
  if (diagnostic.type === "collision") {
    console.log(`loser ${layerOf(diagnostic.collision.loserPath)} ${diagnostic.collision.name}`);
  } else {
    console.log(`warning ${diagnostic.message}`);
  }
}
