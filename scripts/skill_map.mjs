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
// lockfile; the resolution stays a view.
//
// Usage:
//   node scripts/skill_map.mjs [--root DIR] [--json]
//
// Exit: 0 = no hard finding, 1 = a hard finding or the gate could not run.

import { existsSync, readFileSync, readdirSync, realpathSync, statSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { dirname, join, relative, resolve, sep } from "node:path";
import { pathToFileURL } from "node:url";

// Precedence is highest first. It is the order pi's package manager resolves:
// project auto-discovery, then user auto-discovery, then package resources.
// The two package roots are one rank; the settings list orders them, and the
// agent root comes before the module root.
const LAYERS = [
  {
    name: "project",
    source: ".agents/skills",
    runtime: "/home/agentuser/sandbox/.agents/skills/",
    linkRoot: ".",
  },
  {
    name: "provider",
    source: "src/reasoning/providers/pi/config/agent/skills",
    runtime: "$AGENT_HOME/agent/skills/",
    linkRoot: "src/reasoning/providers/pi/config/agent/skills",
  },
  {
    name: "agent-sandbox",
    source: "src/reasoning/agent/skills",
    runtime: "/opt/workflow/agent/skills/",
    linkRoot: "src/reasoning/agent/skills",
  },
  {
    name: "workflow",
    source: "workflow/coding-agent/skills",
    runtime: "/opt/workflow/agent/modules/coding-agent/skills/",
    linkRoot: "workflow/coding-agent/skills",
  },
];

const PACKAGE = join("@earendil-works", "pi-coding-agent");
const ENTRY = join("dist", "index.js");

function piEntry() {
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

function inside(path, root) {
  const rel = relative(resolve(root), resolve(path));
  return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !rel.startsWith(sep));
}

function layerOf(path, root) {
  for (const layer of LAYERS) {
    const source = resolve(root, layer.source);
    if (inside(path, source)) return layer;
  }
  return null;
}

function discoverSkills(dir, out) {
  if (!existsSync(dir)) return;
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  if (entries.some((entry) => entry.isFile() && entry.name === "SKILL.md")) {
    out.push(dir);
    return;
  }
  for (const entry of entries) {
    if (entry.isDirectory() && entry.name !== "node_modules") {
      discoverSkills(join(dir, entry.name), out);
    }
  }
}

function markdownFiles(dir, out) {
  let entries;
  try {
    entries = readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const entry of entries) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) markdownFiles(path, out);
    else if (entry.isFile() && entry.name.endsWith(".md")) out.push(path);
  }
}

const LINK = /\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;

function linksIn(file) {
  const links = [];
  const text = readFileSync(file, "utf8")
    .replace(/```[\s\S]*?```/g, "")
    .replace(/~~~[\s\S]*?~~~/g, "")
    .replace(/`[^`]*`/g, "");
  for (const match of text.matchAll(LINK)) {
    const target = match[1];
    if (/^(?:[a-z][a-z0-9+.-]*:|\/|#|\$)/i.test(target)) continue;
    links.push({ target: target.split("#")[0], raw: target });
  }
  return links;
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
  const layerForDir = new Map();
  for (const layer of LAYERS) {
    const source = resolve(root, layer.source);
    if (!existsSync(source) || !statSync(source).isDirectory()) {
      findings.push(`layer ${layer.name}: source '${layer.source}' is missing`);
      continue;
    }
    const dirs = [];
    discoverSkills(source, dirs);
    for (const dir of dirs) {
      discovered.push(dir);
      layerForDir.set(dir, layer);
    }
  }

  let loadSkills;
  try {
    ({ loadSkills } = await import(pathToFileURL(piEntry()).href));
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
    const files = [];
    markdownFiles(dir, files);
    for (const md of files) {
      for (const link of linksIn(md)) {
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
        if (!inside(target, resolve(root, layer.linkRoot))) {
          findings.push(
            `forbidden link: ${layer.name} '${relative(root, md)}' -> '${link.raw}' leaves its layer root (${layer.source})`,
          );
        } else if (targetLayer && targetLayer.name !== layer.name) {
          findings.push(
            `forbidden link: ${layer.name} '${relative(root, md)}' -> '${link.raw}' reaches ${targetLayer.name}`,
          );
        }
      }
    }
  }

  const total = loaded.size;
  const summary = {
    layers: LAYERS.map((layer) => ({
      name: layer.name,
      source: layer.source,
      runtime: layer.runtime,
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

process.exit(await main());
