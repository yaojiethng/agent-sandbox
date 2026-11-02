#!/usr/bin/env node
// scripts/skill_collisions.mjs
//
// Report a skill name an added package holds that a shipped layer also holds.
// pi keeps the first skill it reaches for a name and records the loser as a
// diagnostic nobody reads, so an added package can stop a shipped skill from
// being the one the session loads, with no line of output.
//
// The report is a fact about the project's package list: it names both paths,
// changes no bytes and fails nothing. pi's loader decides every name and the
// installed packages are pi's own settings, so this reads both from pi rather
// than resolving either a second time.
//
// CLI:
//   node scripts/skill_collisions.mjs [--root DIR] [--agent-dir DIR] [--json]
//
// Exit: 0 always. A collision is not a failure a reader can fix in the tree; the
// fix is the operator's package list.

import { existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { LAYERS, layerOf, layerRoots, piModuleEntry } from "./skill_layers.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// The session's agent directory, when the caller names none: the image sets
// AGENT_HOME, and pi's own default falls back to the config home.
function agentDirFor(agentDir) {
  if (agentDir) return resolve(agentDir);
  if (process.env.AGENT_HOME) return join(resolve(process.env.AGENT_HOME), "agent");
  return undefined;
}

// findCollisions ROOT AGENT_DIR -- the shipped skills a configured package also
// holds, each naming the shipped path and the added one.
export async function findCollisions({ root = REPO, agentDir } = {}) {
  const resolvedRoot = resolve(root);
  const resolvedAgentDir = agentDirFor(agentDir);
  const pi = await import(pathToFileURL(piModuleEntry()).href);

  const settings = pi.SettingsManager.create(resolvedRoot, resolvedAgentDir);
  const packages = new pi.DefaultPackageManager({
    cwd: resolvedRoot,
    agentDir: resolvedAgentDir,
    settingsManager: settings,
  });
  const addedPaths = packages
    .listConfiguredPackages()
    .map((entry) => entry.installedPath)
    .filter(Boolean);
  if (addedPaths.length === 0) return { collisions: [], addedPackages: 0 };

  const shippedPaths = LAYERS.filter((layer) => layer.shipped)
    .map((layer) => resolve(resolvedRoot, layer.source))
    .filter((path) => existsSync(path));
  if (shippedPaths.length === 0) return { collisions: [], addedPackages: addedPaths.length };

  const load = { cwd: resolvedRoot, agentDir: resolvedAgentDir, includeDefaults: false };
  const shipped = pi.loadSkills({ ...load, skillPaths: shippedPaths });
  const added = pi.loadSkills({ ...load, skillPaths: addedPaths });
  const byName = new Map(shipped.skills.map((skill) => [skill.name, skill]));

  // The image and the provider home hold a copy of the same shipped payload, and
  // a session configures them as packages. That pair is one artifact in two
  // places, not a collision: a name is only displaced when the added copy is
  // something other than the declared copy of the shipped one.
  const { image, host } = layerRoots(resolvedRoot);
  const copies = new Map();
  for (const layer of LAYERS) {
    const paths = [image.get(layer.name)?.path, host.get(layer.name)?.path].filter(Boolean);
    if (paths.length > 0) copies.set(layer.name, paths);
  }
  const sameArtifact = (shippedPath, addedPath) => {
    const layer = layerOf(shippedPath, resolvedRoot);
    if (!layer) return false;
    const rel = shippedPath.slice(resolve(resolvedRoot, layer.source).length).replace(/^\/+/, "");
    return (copies.get(layer.name) || []).some((root) => join(root, rel) === addedPath);
  };

  const collisions = added.skills
    .filter((skill) => byName.has(skill.name))
    .map((skill) => ({ skill, shipped: byName.get(skill.name) }))
    .filter(({ skill, shipped }) => !sameArtifact(shipped.filePath, skill.filePath))
    .map(({ skill, shipped }) => ({
      name: skill.name,
      shippedPath: shipped.filePath,
      addedPath: skill.filePath,
    }));
  return { collisions, addedPackages: addedPaths.length };
}

function line(collision) {
  return `skill collision: '${collision.name}' is shipped at ${collision.shippedPath} and an added package also holds it at ${collision.addedPath} -- pi keeps the first it reaches, so one of the two is not loaded`;
}

async function main() {
  const args = process.argv.slice(2);
  let root = REPO;
  let agentDir;
  let json = false;
  for (let index = 0; index < args.length; index++) {
    if (args[index] === "--root") root = args[++index] || "";
    else if (args[index] === "--agent-dir") agentDir = args[++index] || "";
    else if (args[index] === "--json") json = true;
    else if (args[index] === "--help" || args[index] === "-h") {
      console.log("usage: node scripts/skill_collisions.mjs [--root DIR] [--agent-dir DIR] [--json]");
      return 0;
    } else {
      console.error(`skill collisions: unknown argument '${args[index]}'`);
      return 2;
    }
  }

  const { collisions } = await findCollisions({ root, agentDir });
  if (json) {
    console.log(JSON.stringify({ collisions }, null, 2));
    return 0;
  }
  for (const collision of collisions) console.error(line(collision));
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(await main());
}
