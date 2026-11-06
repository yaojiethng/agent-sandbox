// tests/skill_layer_loader.mjs
// Probe pi's skill resolver with the four layer roots in precedence order.
//
// The probe is the knowledge test's oracle: it calls pi's own `loadSkills`
// with project, provider, agent-sandbox and workflow roots, so a collision
// shows which layer wins and which layers are shadowed. The roots and the pi
// entry are `scripts/skill_layers.mjs`'s, so the probe cannot drift from the
// map and the graph.
//
// Usage: node tests/skill_layer_loader.mjs <fixture-root>

import { join, resolve } from "node:path";
import { pathToFileURL } from "node:url";

import { LAYERS, layerOf as layerOwning, piModuleEntry } from "../scripts/skill_layers.mjs";

const root = resolve(process.argv[2] || "");
if (!process.argv[2]) {
  console.error("usage: node tests/skill_layer_loader.mjs <fixture-root>");
  process.exit(2);
}

const layers = LAYERS.map((layer) => ({ name: layer.name, path: resolve(root, layer.source) }));
const layerOf = (file) => layerOwning(file, root)?.name || "unknown";

const { loadSkills } = await import(pathToFileURL(piModuleEntry()).href);
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
