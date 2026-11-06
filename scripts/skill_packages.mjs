#!/usr/bin/env node
// scripts/skill_packages.mjs
//
// The package list a project expects, and the difference between it and the
// session's configured packages. The manifest is
// `.agents/registry/packages.json`: one entry per package, holding the pin in
// the form the operator wrote it and one line saying why.
//
// This tracks and checks. It installs nothing, resolves nothing and repairs
// nothing: the provider's package manager owns that, and a pin it cannot read is
// its finding to make. The difference is a report, so it changes no bytes and
// fails nothing.
//
// CLI:
//   node scripts/skill_packages.mjs [--root DIR] [--agent-dir DIR] [--json]
//
// Exit: 0 when the manifest is readable, 1 when it is not.

import { existsSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

import { piModuleEntry } from "./skill_layers.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
export const MANIFEST_REL = ".agents/registry/packages.json";

// The session's agent directory when the caller names none: the image sets
// AGENT_HOME, and pi's own default falls back to the config home.
export function agentDirFor(agentDir) {
  if (agentDir) return resolve(agentDir);
  if (process.env.AGENT_HOME) return join(resolve(process.env.AGENT_HOME), "agent");
  return undefined;
}

// configuredPackages ROOT AGENT_DIR -- the packages the session is configured
// with, each with the installed path pi resolves, whether it is present, and
// whether it is a local path.
// pi's settings and package manager answer both questions.
export async function configuredPackages({ root = REPO, agentDir } = {}) {
  const resolvedRoot = resolve(root);
  const resolvedAgentDir = agentDirFor(agentDir);
  const pi = await import(pathToFileURL(piModuleEntry()).href);
  const settings = pi.SettingsManager.create(resolvedRoot, resolvedAgentDir);
  const packages = new pi.DefaultPackageManager({
    cwd: resolvedRoot,
    agentDir: resolvedAgentDir,
    settingsManager: settings,
  });
  const configured = packages.listConfiguredPackages().map((entry) => {
    const installedPath = entry.installedPath || null;
    let type = "unknown";
    try {
      type = packages.parseSource(entry.source).type;
    } catch {
      type = "unknown";
    }
    return {
      source: entry.source,
      scope: entry.scope,
      type,
      installedPath,
      present: Boolean(installedPath && existsSync(installedPath)),
    };
  });
  return { configured, parses: (source) => packages.parseSource(source), resolvedAgentDir };
}

// readManifest ROOT -- the manifest's entries, or the reason it cannot be read.
export function readManifest(root = REPO) {
  const file = join(resolve(root), MANIFEST_REL);
  if (!existsSync(file)) return { file, entries: [], error: `${MANIFEST_REL}: missing` };
  let parsed;
  try {
    parsed = JSON.parse(readFileSync(file, "utf8"));
  } catch (error) {
    return { file, entries: [], error: `${MANIFEST_REL}: does not parse (${error.message})` };
  }
  if (!Array.isArray(parsed.packages)) {
    return { file, entries: [], error: `${MANIFEST_REL}: 'packages' must be an array` };
  }
  return { file, entries: parsed.packages, error: null };
}

// drift ROOT AGENT_DIR -- what the manifest names that is not installed, and
// what is installed that the manifest does not name.
export async function drift({ root = REPO, agentDir } = {}) {
  const { file, entries, error } = readManifest(root);
  if (error) return { file, error, missing: [], unlisted: [] };
  const { configured } = await configuredPackages({ root, agentDir });
  const named = new Set(entries.map((entry) => entry.source));
  const installed = new Set(configured.map((entry) => entry.source));
  return {
    file,
    error: null,
    missing: entries.filter((entry) => !installed.has(entry.source)).map((entry) => entry.source),
    // A local source is a machine path. The manifest states what a project
    // expects, so a path under one sandbox is never its business.
    unlisted: configured
      .filter((entry) => entry.type !== "local" && !named.has(entry.source))
      .map((entry) => entry.source),
    // A configured package whose path is gone loads nothing and says nothing,
    // which is the state a fresh sandbox starts in.
    absent: configured
      .filter((entry) => !entry.present)
      .map((entry) => ({ source: entry.source, installedPath: entry.installedPath })),
  };
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
      console.log("usage: node scripts/skill_packages.mjs [--root DIR] [--agent-dir DIR] [--json]");
      return 0;
    } else {
      console.error(`skill packages: unknown argument '${args[index]}'`);
      return 2;
    }
  }

  const result = await drift({ root, agentDir });
  if (json) {
    console.log(JSON.stringify(result, null, 2));
    return 0;
  }
  if (result.error) {
    console.error(result.error);
    return 1;
  }
  for (const source of result.missing) {
    console.error(`package missing: '${source}' is named in ${MANIFEST_REL} and is not configured`);
  }
  for (const entry of result.absent) {
    console.error(
      `package absent: '${entry.source}' resolves to ${entry.installedPath ?? "no path"}, which does not exist`
    );
  }
  for (const source of result.unlisted) {
    console.error(`package unlisted: '${source}' is configured and ${MANIFEST_REL} does not name it`);
  }
  return 0;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  process.exit(await main());
}
