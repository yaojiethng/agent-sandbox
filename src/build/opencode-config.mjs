import { load_manifest, manifest_rows } from "./container-interface.mjs";
import { pathToFileURL } from "node:url";
import path from "node:path";
import process from "node:process";

function parse_args(argv) {
  const args = { root: process.cwd() };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--root") {
      args.root = argv[i + 1];
      i += 1;
    }
  }
  return args;
}

const ROOT = path.resolve(parse_args(process.argv.slice(2)).root);

const manifest = load_manifest(ROOT);
const cells = manifest ? manifest_rows(manifest, "cells") : [];

const skills = [];
for (const cell of cells) {
  for (const source of cell.sources || []) {
    if (typeof source === "string" && source.endsWith("skills/")) {
      skills.push(path.resolve(ROOT, source) + "/");
    }
  }
}
skills.push(path.resolve(ROOT, ".agents/skills/") + "/");

const instructions = [
  path.resolve(ROOT, "AGENTS.md"),
  path.resolve(ROOT, "src/reasoning/providers/pi/config/agent/AGENTS.md"),
];

const config = { instructions, skills };
process.stdout.write(JSON.stringify(config, null, 2) + "\n");
