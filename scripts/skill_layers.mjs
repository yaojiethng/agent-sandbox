#!/usr/bin/env node
// scripts/skill_layers.mjs
//
// The skill layers and the primitives every reader of them shares.
//
// `LAYERS` is the one declaration of which directory is a layer, in what
// precedence. A layer's image path is not restated
// here: `layerRoots` reads it from the container manifest's image and provision
// rows, which own every destination, so a moved destination moves the graph with
// it; a shipped layer no row reaches is reported rather than skipped.
//
// The primitives are the ones four callers used to carry a copy of each: pi's
// no-recurse discovery rule, the Markdown link grammar, the containment test,
// which layer owns a path, the file walk, and the resolution of pi's own package
// entry.
//
// Usage:
//   node scripts/skill_layers.mjs [--list] [--root DIR]
//
// --list prints one row per layer as NAME<TAB>SOURCE<TAB>IMAGE_PATH, so a shell
// test builds its fixture from the table instead of restating the paths.

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, realpathSync, statSync } from "node:fs";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import {
  MANIFEST_REL,
  home_of,
  load_manifest,
  manifest_rows,
  resolve_home,
} from "../src/build/container-interface.mjs";

// Precedence is highest first. It is the order pi's package manager resolves:
// project auto-discovery, then user auto-discovery, then package resources.
// The two package roots are one rank; the settings list orders them, and the
// agent root comes before the module root.
export const LAYERS = [
  {
    name: "project",
    source: ".agents/skills",
    shipped: false,
  },
  {
    name: "provider",
    source: "src/reasoning/agent-runtime/pi/config/agent/skills",
    shipped: true,
  },
  {
    name: "agent-sandbox",
    source: "src/reasoning/agent/skills",
    shipped: true,
  },
  {
    name: "workflow",
    source: "workflow/coding-agent/skills",
    shipped: true,
  },
];

export const IGNORE = new Set([".git", "node_modules", ".scratchpad"]);

const PACKAGE = join("@earendil-works", "pi-coding-agent");
const ENTRY = join("dist", "index.js");
const LINK = /\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g;

export function inside(path, root) {
  const rel = relative(resolve(root), resolve(path));
  return rel === "" || (rel !== ".." && !rel.startsWith(`..${sep}`) && !rel.startsWith(sep));
}

// layerOf -- the layer whose source directory holds a path, or null.
export function layerOf(path, root) {
  for (const layer of LAYERS) {
    if (inside(path, resolve(root, layer.source))) return layer;
  }
  return null;
}

export function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function entriesOf(dir) {
  try {
    return readdirSync(dir, { withFileTypes: true });
  } catch {
    return [];
  }
}

// discoverSkillDirs -- pi's no-recurse rule: a directory holding SKILL.md is a
// skill root, and discovery stops there.
export function discoverSkillDirs(dir, out = []) {
  if (!isDirectory(dir)) return out;
  const entries = entriesOf(dir);
  if (entries.some((entry) => entry.isFile() && entry.name === "SKILL.md")) {
    out.push(dir);
    return out;
  }
  for (const entry of entries) {
    if (entry.isDirectory() && !IGNORE.has(entry.name)) discoverSkillDirs(join(dir, entry.name), out);
  }
  return out;
}

export function walkFiles(dir, out = []) {
  if (!isDirectory(dir)) return out;
  for (const entry of entriesOf(dir)) {
    if (IGNORE.has(entry.name)) continue;
    const path = join(dir, entry.name);
    if (entry.isDirectory()) walkFiles(path, out);
    else if (entry.isFile()) out.push(path);
  }
  return out;
}

export function markdownFiles(dir, out = []) {
  for (const path of walkFiles(dir)) {
    if (path.endsWith(".md")) out.push(path);
  }
  return out;
}

// markdownLinks -- every relative-target link in a Markdown file, with the line
// it is written on. Fenced blocks and inline code spans are masked rather than
// deleted, so a match index still maps to the line of the original text.
export function markdownLinks(file) {
  const text = readFileSync(file, "utf8")
    .replace(/```[\s\S]*?```/g, mask)
    .replace(/~~~[\s\S]*?~~~/g, mask)
    .replace(/`[^`]*`/g, mask);
  const links = [];
  for (const match of text.matchAll(LINK)) {
    const raw = match[1];
    links.push({
      target: raw.split("#")[0],
      raw,
      line: text.slice(0, match.index).split("\n").length,
    });
  }
  return links;
}

function mask(match) {
  return match.replace(/[^\n]/g, " ");
}

// piModuleEntry -- the file path of pi's package entry, from `pi` on PATH and
// then from PI_PACKAGE_DIR. `pi` on PATH is a symlink into the package, so the
// walk starts at the real file or it never reaches the node_modules holding it.
export function piModuleEntry() {
  let bin = "";
  try {
    bin = execFileSync("sh", ["-c", "command -v pi"], { encoding: "utf8" }).trim();
  } catch {
    bin = "";
  }
  if (bin) {
    let dir = dirname(realpathSync(bin));
    for (let hop = 0; hop < 8; hop++) {
      const module = join(dir, "node_modules", PACKAGE, ENTRY);
      if (existsSync(module)) return module;
      dir = dirname(dir);
    }
  }
  if (process.env.PI_PACKAGE_DIR) {
    const module = join(process.env.PI_PACKAGE_DIR, ENTRY);
    if (existsSync(module)) return module;
  }
  throw new Error("pi's package could not be resolved; set PI_PACKAGE_DIR");
}

// layerRoots -- the manifest's declaration of where each layer's payload lives,
// in the image and in the session's provider home, in one pass. A row that
// reaches a layer yields that layer's root and travels with it, so a caller can
// name the row that decided it. A layer no image row reaches, two rows that
// reach one layer, a provision row with no resolvable home and two provision
// rows that reach one layer are each a finding here, because the alternative is
// a graph that gets quieter as its declaration gets worse.
export function layerRoots(root) {
  const image = new Map();
  const host = new Map();
  const findings = [];
  const manifest = load_manifest(root);
  if (!manifest) {
    findings.push(`root: ${MANIFEST_REL}: missing or does not parse`);
    return { image, host, agentHome: "", findings };
  }
  if (manifest_rows(manifest, "provision").length === 0) {
    findings.push("root: the manifest declares no provision row, so no provider home is seeded");
  }
  const reaches = (rowSource, layerSource) =>
    layerSource === rowSource || layerSource.startsWith(`${rowSource}/`);
  const remainder = (rowSource, layerSource) => layerSource.slice(rowSource.length).replace(/^\/+/, "");

  for (const layer of LAYERS) {
    const source = stripSlash(layer.source);
    const rows = manifest_rows(manifest, "image").filter(
      (row) => typeof row.source === "string" && reaches(stripSlash(row.source), source),
    );
    if (rows.length > 1) {
      findings.push(`root: ${rows.length} image rows reach ${layer.name} (${rows.map((row) => row.provider).join(", ")})`);
    }
    if (rows.length === 0) {
      if (layer.shipped) findings.push(`root: ${layer.name} has no image row in the container manifest`);
    } else {
      const row = rows[0];
      image.set(layer.name, {
        path: stripSlash(join(row.destination, remainder(stripSlash(row.source), source))),
        row,
      });
    }

    for (const row of manifest_rows(manifest, "provision")) {
      if (typeof row.source !== "string" || !reaches(stripSlash(row.source), source)) continue;
      const destination = resolve_home(manifest, row.provider, row.home);
      if (!destination) {
        findings.push(`root: the provision row for ${row.provider} names no resolvable home`);
        continue;
      }
      if (host.has(layer.name)) {
        findings.push(`root: more than one provision row reaches ${layer.name}`);
        continue;
      }
      host.set(layer.name, {
        path: stripSlash(join(destination, remainder(stripSlash(row.source), source))),
        row,
      });
    }
  }

  const hostRow = [...host.values()][0]?.row;
  return { image, host, agentHome: hostRow ? home_of(manifest, hostRow.provider) : "", findings };
}

function stripSlash(path) {
  return String(path).replace(/\/+$/, "");
}

function main(args) {
  let root = process.cwd();
  let list = false;
  for (let index = 0; index < args.length; index++) {
    if (args[index] === "--list") list = true;
    else if (args[index] === "--root") root = resolve(args[++index] || "");
    else {
      console.error(`skill layers: unknown argument '${args[index]}'`);
      return 2;
    }
  }
  if (list) {
    const { image } = layerRoots(root);
    for (const layer of LAYERS) {
      console.log(`${layer.name}\t${layer.source}\t${image.get(layer.name)?.path || ""}`);
    }
    return 0;
  }
  console.log("usage: node scripts/skill_layers.mjs [--list] [--root DIR]");
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(main(process.argv.slice(2)));
}
