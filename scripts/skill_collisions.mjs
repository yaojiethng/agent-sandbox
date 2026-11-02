#!/usr/bin/env node
// scripts/skill_collisions.mjs
//
// Report a skill name an added package holds that a shipped copy also holds, in
// the set the session actually loads.
//
// The load set is the thing that can race for a name: pi's user root, the
// project root, then each configured package, first-wins. The repository's own
// source tree is not in it - the image carries its payload, and a session loads
// that copy - so comparing a committed path against a loaded path compares a
// build input with a build output. Those two differ by a build, not by a
// configuration, and that difference is drift, which the provenance graph owns.
//
// A name held twice inside the load set is a real race, and pi resolves it
// silently: it keeps the first path and records the loser as a diagnostic nobody
// reads. Two of ours is our own seeding (the home is provisioned from the image
// payload, which is also configured as a package), so the report keeps only the
// mixed case, where a package the project added displaces a copy we ship or is
// displaced by it. Ours is a path the container manifest declares: an image
// destination or a provision home.
//
// The report names both paths, changes no bytes and fails nothing.
//
// CLI:
//   node scripts/skill_collisions.mjs [--root DIR] [--agent-dir DIR] [--json]
//
// Exit: 0 always. A collision is not a failure a reader can fix in the tree; the
// fix is the operator's package list.

import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { agentDirFor, configuredPackages } from "./skill_packages.mjs";
import { inside, layerRoots, piModuleEntry } from "./skill_layers.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// ours ROOT -- the directories the container manifest declares as ours: each
// shipped layer's image destination and its provision home. Everything else in
// the load set was added by the project.
async function ourRoots(root) {
  const { image, host } = await layerRoots(root);
  return [...image.values(), ...host.values()].map((entry) => entry.path).filter(Boolean);
}

// findCollisions ROOT AGENT_DIR -- the mixed collisions of the session's load
// set, each naming the shipped path and the added one.
export async function findCollisions({ root = REPO, agentDir } = {}) {
  const resolvedRoot = resolve(root);
  const resolvedAgentDir = agentDirFor(agentDir);
  const pi = await import(pathToFileURL(piModuleEntry()).href);

  const { configured } = await configuredPackages({ root: resolvedRoot, agentDir: resolvedAgentDir });
  const packagePaths = configured.map((entry) => entry.installedPath).filter(Boolean);
  const load = pi.loadSkills({
    cwd: resolvedRoot,
    agentDir: resolvedAgentDir,
    skillPaths: packagePaths,
    includeDefaults: true,
  });

  const ours = await ourRoots(resolvedRoot);
  const isOurs = (path) => ours.some((dir) => inside(path, dir));
  const exists = packagePaths.filter((path) => existsSync(path)).length;

  const collisions = load.diagnostics
    .filter((diagnostic) => diagnostic.type === "collision")
    .map((diagnostic) => diagnostic.collision)
    .filter((collision) => isOurs(collision.winnerPath) !== isOurs(collision.loserPath))
    .map((collision) => ({
      name: collision.name,
      shippedPath: isOurs(collision.winnerPath) ? collision.winnerPath : collision.loserPath,
      addedPath: isOurs(collision.winnerPath) ? collision.loserPath : collision.winnerPath,
    }));

  return { collisions, loaded: load.skills.length, packages: exists };
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
