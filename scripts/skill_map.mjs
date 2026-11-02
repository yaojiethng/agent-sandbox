#!/usr/bin/env node
// scripts/skill_map.mjs
// The generated skill-layer map. It reads the four skill layers, resolves a
// name with pi's own loader (first wins), and holds the layer rules:
//
//   - every discovered SKILL.md is loaded, or is a reported name collision;
//   - a name collision is a hard finding, because the winner is a runtime
//     accident until the layers model says which one should win;
//   - a shipped layer is self-contained: a relative link in the provider,
//     agent-sandbox or workflow layer must stay inside that layer's source
//     root. The project layer may link anywhere in the project tree, because
//     the project tree is where it is read.
//
// The map is printed, never committed. The source facts stay in the provenance
// lockfile; the resolution stays a view. The layer table and the discovery rule
// are `scripts/skill_layers.mjs`, shared with the graph.
//
// Usage:
//   node scripts/skill_map.mjs [--root DIR] [--json]
//
// Exit: 0 = no hard finding, 1 = a hard finding or the gate could not run.

import { existsSync, statSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import {
  LAYERS,
  discoverSkillDirs,
  inside,
  layerOf,
  markdownFiles,
  markdownLinks,
  piModuleEntry,
} from "./skill_layers.mjs";

// A link the map judges is a relative file target: a scheme, an absolute path,
// an in-page fragment and a home-relative path are all somebody else's.
function judgedLinks(file) {
  return markdownLinks(file).filter(
    (link) => !/^(?:[a-z][a-z0-9+.-]*:|\/|#|\$)/i.test(link.raw),
  );
}

async function main() {
  const args = process.argv.slice(2);
  let root = process.cwd();
  let json = false;
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "--root") root = resolve(args[++i] || "");
    else if (args[i] === "--json") json = true;
    else if (args[i] === "--help" || args[i] === "-h") {
      console.log("usage: node scripts/skill_map.mjs [--root DIR] [--json]");
      return 0;
    } else {
      console.error(`skill map: unknown argument '${args[i]}'`);
      return 2;
    }
  }

  const findings = [];
  const warnings = [];
  const discovered = [];
  for (const layer of LAYERS) {
    const source = resolve(root, layer.source);
    if (!existsSync(source) || !statSync(source).isDirectory()) {
      findings.push(`layer ${layer.name}: source '${layer.source}' is missing`);
      continue;
    }
    discovered.push(...discoverSkillDirs(source));
  }

  let loadSkills;
  try {
    ({ loadSkills } = await import(pathToFileURL(piModuleEntry()).href));
  } catch (error) {
    console.error(`skill map: cannot load pi's loader: ${error.message}`);
    return 1;
  }

  const skillPaths = LAYERS.map((layer) => resolve(root, layer.source));
  const result = loadSkills({
    cwd: root,
    agentDir: join(root, ".scratchpad", "agent"),
    skillPaths,
    includeDefaults: false,
  });

  for (const diagnostic of result.diagnostics) {
    if (diagnostic.type === "collision") {
      const winner = layerOf(diagnostic.collision.winnerPath, root);
      const loser = layerOf(diagnostic.collision.loserPath, root);
      findings.push(
        `collision: '${diagnostic.collision.name}' is held by ${winner?.name ?? "unknown"} (${relative(root, diagnostic.collision.winnerPath)}) and ${loser?.name ?? "unknown"} (${relative(root, diagnostic.collision.loserPath)})`,
      );
    } else {
      findings.push(`loader: ${diagnostic.message}${diagnostic.path ? ` (${relative(root, diagnostic.path)})` : ""}`);
    }
  }

  const loaded = new Map(result.skills.map((skill) => [skill.filePath, skill]));
  const loserPaths = new Set(
    result.diagnostics
      .filter((diagnostic) => diagnostic.type === "collision")
      .map((diagnostic) => diagnostic.collision.loserPath),
  );
  for (const dir of discovered) {
    const file = join(dir, "SKILL.md");
    if (loaded.has(file) || loserPaths.has(file)) continue;
    findings.push(`loader: ${relative(root, file)} was discovered but not loaded`);
  }

  const byLayer = new Map(LAYERS.map((layer) => [layer.name, []]));
  for (const [file, skill] of loaded) {
    const layer = layerOf(file, root);
    if (!layer) {
      findings.push(`layer: ${relative(root, file)} is outside every declared layer`);
      continue;
    }
    byLayer.get(layer.name).push(skill);
  }

  let allowedCrossLayer = 0;
  for (const [file, skill] of loaded) {
    const layer = layerOf(file, root);
    if (!layer) continue;
    const dir = dirname(file);
    const dirName = dir.split(sep).pop();
    if (skill.name !== dirName) {
      warnings.push(`${layer.name}: '${skill.name}' resolves from '${relative(root, file)}' but its directory is '${dirName}'`);
    }
    if (layer.name === "agent-sandbox" && !existsSync(join(dir, "MAINTENANCE.md"))) {
      warnings.push(`${layer.name}: '${skill.name}' has no MAINTENANCE.md`);
    }
    for (const md of markdownFiles(dir)) {
      for (const link of judgedLinks(md)) {
        const target = resolve(dirname(md), link.target);
        if (!existsSync(target)) {
          findings.push(`link: ${relative(root, md)} -> '${link.raw}' does not resolve`);
          continue;
        }
        const targetLayer = layerOf(target, root);
        if (layer.name === "project") {
          if (!inside(target, root)) {
            findings.push(`link: ${relative(root, md)} -> '${link.raw}' leaves the project tree`);
          } else if (targetLayer && targetLayer.name !== layer.name) {
            allowedCrossLayer++;
          }
          continue;
        }
        if (!inside(target, resolve(root, layer.source))) {
          findings.push(
            `forbidden link: ${layer.name} '${relative(root, md)}' -> '${link.raw}' leaves its layer root (${layer.source})`,
          );
        }
      }
    }
  }

  const total = loaded.size;
  if (total === 0) findings.push("map: the declared layers hold no skill");
  const summary = {
    layers: LAYERS.map((layer) => ({
      name: layer.name,
      source: layer.source,
      skills: byLayer.get(layer.name)?.length ?? 0,
    })),
    skills: total,
    collisions: result.diagnostics.filter((diagnostic) => diagnostic.type === "collision").length,
    allowedCrossLayer,
    warnings: warnings.length,
    findings: findings.length,
  };

  if (json) {
    console.log(JSON.stringify({ summary, layers: summary.layers, findings, warnings }, null, 2));
  } else {
    console.log(`Skill layer map (generated, not committed)`);
    console.log(`${"layer".padEnd(14)} ${"rank".padEnd(5)} ${"skills".padEnd(7)} source`);
    for (const [index, layer] of LAYERS.entries()) {
      console.log(
        `${layer.name.padEnd(14)} ${String(index + 1).padEnd(5)} ${String(byLayer.get(layer.name)?.length ?? 0).padEnd(7)} ${layer.source}`,
      );
    }
    console.log("");
    console.log(`resolved ${total} skill(s) across ${LAYERS.length} layer(s); ${summary.allowedCrossLayer} project-to-shipped link(s) allowed`);
    for (const warning of warnings) console.log(`warning: ${warning}`);
    for (const finding of findings) console.log(`finding: ${finding}`);
    if (findings.length === 0) console.log(`clean across ${LAYERS.length} layer(s) and ${total} skill(s)`);
  }

  return findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(await main());
}
