// src/build/surface_table.mjs
// The destination table, generated from the manifest and checked where it is
// stated.
//
// `src/build/container-interface.json` declares where each source lands in the
// container. This module is the one writer of the block that a reference
// document carries, so the mapping is stated once and a document cites it
// rather than restating it.
//
// Two rules hold a `docs/reference/*.md` file to the model:
//
//   1. A generated block is the manifest's own output. Whatever sits between
//      the markers must equal what this module renders, so a hand edit inside
//      the block is a finding rather than a quiet divergence.
//   2. Outside the block, a document may not restate the mapping. A table row
//      that names a manifest source and its destination is the mapping in
//      table form, and a backticked repository file path that does not resolve
//      is a claim about where a file lives that the tree contradicts. A
//      `<placeholder>` segment resolves against each provider's directory,
//      because `src/reasoning/agent-runtime/<n>/...` is how a reference names a
//      per-provider file.
//
// CLI:
//   node surface_table.mjs write [--root DIR]  rewrite every block in place
//   node surface_table.mjs check [--root DIR]  findings, one per line; exit 1 on any
//
// A missing manifest, a missing reference folder, a marker without its pair and
// a tree that states no block are findings rather than empty results, so a
// broken input never reads as a clean run.

import { readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { join } from "node:path";

import { MANIFEST_REL, load_manifest, manifest_rows, provider_names } from "./container-interface.mjs";

export const BLOCK_BEGIN = "<!-- BEGIN GENERATED: surface-table -->";
export const BLOCK_END = "<!-- END GENERATED: surface-table -->";
export const REFERENCE_REL = "docs/reference";

const FILE_LIKE = /\.(?:md|sh|mjs|json|ts|yml)$/;
const REPO_PREFIX = /^(?:src|workflow|docs|scripts|tests|\.agents)\//;

// image_rows MANIFEST -- the declared placement of each source, one row per
// source and destination, with the providers that place it there joined.
function image_rows(manifest) {
  const seen = new Map();
  for (const row of manifest_rows(manifest, "image")) {
    const key = `${row.source}\t${row.destination}`;
    if (!seen.has(key)) seen.set(key, { source: row.source, destination: row.destination, providers: [] });
    seen.get(key).providers.push(row.provider);
  }
  return [...seen.values()]
    .map((row) => ({ ...row, providers: [...new Set(row.providers)].sort() }))
    .sort((a, b) => (a.destination + a.source).localeCompare(b.destination + b.source));
}

// render ROOT -- the block's lines, markers included. This is the only
// definition of the table's shape; the writer and the check both read it.
export function render(root) {
  const manifest = load_manifest(root);
  if (!manifest) return null;
  const lines = [BLOCK_BEGIN, "| Source | Destination | Provider |", "|---|---|---|"];
  for (const row of image_rows(manifest)) {
    lines.push(`| \`${row.source}\` | \`${row.destination}\` | ${row.providers.join(", ")} |`);
  }
  lines.push(BLOCK_END);
  return lines;
}

// split_block TEXT -- the body between the markers, and the inclusive line
// numbers those markers occupy, so a finding outside the block keeps the line
// number the reader sees.
export function split_block(text) {
  const start = text.indexOf(BLOCK_BEGIN);
  if (start === -1) return null;
  const bodyStart = start + BLOCK_BEGIN.length;
  const end = text.indexOf(BLOCK_END, bodyStart);
  if (end === -1) return { unterminated: true, start };
  return {
    body: text.slice(bodyStart, end).trim(),
    firstLine: text.slice(0, start).split("\n").length,
    lastLine: text.slice(0, end + BLOCK_END.length).split("\n").length,
  };
}

// normalise VALUE -- the text with the Markdown escape for a pipe resolved and
// a trailing slash dropped, so a cell that spells `skills|prompts/` compares
// with the manifest's own rows.
function normalise(value) {
  return value.replace(/&#124;/g, "|").replace(/\/$/, "");
}

// restates_mapping LINE ROWS -- whether a table row names a declared source and
// its destination. Only a table row states a mapping in this corpus: a sentence
// that names an image path is talking about the environment or about one file's
// copy, and moving it into the block would cost the reader the sentence.
function restates_mapping(line, rows) {
  if (!/^\s*\|/.test(line)) return false;
  const text = normalise(line);
  return rows.some((row) => text.includes(normalise(row.source)) && text.includes(normalise(row.destination)));
}

// resolves ROOT TOKEN PROVIDERS -- whether a backticked repository path names
// something the tree holds. A `<placeholder>` segment is substituted with each
// provider's directory name, so a per-provider path is checkable.
export function resolves(root, token, providers) {
  const candidates = [token];
  if (token.includes("<")) {
    for (const name of providers) candidates.push(token.replace(/<[^>]+>/g, name));
  }
  return candidates.some((candidate) => existsSync(join(root, candidate)));
}

// check ROOT -- the findings, one per line, empty when the tree agrees with the
// manifest.
export function check(root) {
  const manifest = load_manifest(root);
  if (!manifest) return [`${MANIFEST_REL} is missing or does not parse; the surface table has no source`];
  const expected = render(root).slice(1, -1).join("\n");
  const rows = image_rows(manifest);
  const providers = provider_names(root);

  const dir = join(root, REFERENCE_REL);
  if (!existsSync(dir)) return [`${REFERENCE_REL}/ is missing; no reference document can cite the model`];

  const findings = [];
  let blocks = 0;
  for (const name of readdirSync(dir).filter((entry) => entry.endsWith(".md")).sort()) {
    const path = `${REFERENCE_REL}/${name}`;
    const text = readFileSync(join(root, path), "utf8");
    const split = split_block(text);
    if (split && split.unterminated) {
      findings.push(`${path}: ${BLOCK_BEGIN} has no matching ${BLOCK_END}`);
      continue;
    }
    if (split) {
      blocks += 1;
      if (split.body !== expected) {
        findings.push(`${path}: the generated block differs from the manifest; run node src/build/surface_table.mjs write`);
      }
    }
    if (text.includes(BLOCK_END) && !split) findings.push(`${path}: ${BLOCK_END} has no ${BLOCK_BEGIN}`);

    const firstLine = split ? split.firstLine : 0;
    const lastLine = split ? split.lastLine : 0;
    text.split("\n").forEach((line, index) => {
      const lineNo = index + 1;
      if (lineNo >= firstLine && lineNo <= lastLine) return;
      if (restates_mapping(line, rows)) {
        findings.push(`${path}:${lineNo}: restates the mapping outside the generated block`);
      }
      for (const match of line.matchAll(/`([^`\s]+)`/g)) {
        const token = match[1];
        if (!REPO_PREFIX.test(token) || !FILE_LIKE.test(token) || /[|*]/.test(token)) continue;
        if (!resolves(root, token, providers)) {
          findings.push(`${path}:${lineNo}: \`${token}\` does not resolve in the tree`);
        }
      }
    });
  }
  if (blocks === 0) findings.push(`${REFERENCE_REL}/: no reference document carries a ${BLOCK_BEGIN} block`);
  return findings;
}

// write ROOT -- replace every block's body with the rendered table. Returns the
// paths it changed.
export function write(root) {
  const rendered = render(root);
  if (!rendered) return [];
  const body = rendered.slice(1, -1).join("\n");
  const changed = [];
  const dir = join(root, REFERENCE_REL);
  for (const name of readdirSync(dir).filter((entry) => entry.endsWith(".md")).sort()) {
    const path = join(dir, name);
    const text = readFileSync(path, "utf8");
    const split = split_block(text);
    if (!split || split.unterminated || split.body === body) continue;
    const next = text.replace(
      new RegExp(`${BLOCK_BEGIN.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}[\\s\\S]*?${BLOCK_END.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}`),
      `${BLOCK_BEGIN}\n${body}\n${BLOCK_END}`,
    );
    writeFileSync(path, next);
    changed.push(`${REFERENCE_REL}/${name}`);
  }
  return changed;
}

function parse_args(argv) {
  const args = { command: "", root: process.cwd() };
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--root") {
      args.root = argv[i + 1];
      i += 1;
    } else if (!args.command) {
      args.command = argv[i];
    }
  }
  return args;
}

function main(argv) {
  const args = parse_args(argv);
  if (args.command === "write") {
    const changed = write(args.root);
    for (const path of changed) process.stdout.write(`rewrote ${path}\n`);
    return 0;
  }
  if (args.command === "check") {
    const findings = check(args.root);
    for (const finding of findings) process.stdout.write(`${finding}\n`);
    return findings.length === 0 ? 0 : 1;
  }
  process.stderr.write("usage: surface_table.mjs write|check [--root DIR]\n");
  return 2;
}

if (process.argv[1] && process.argv[1].endsWith("surface_table.mjs")) {
  process.exit(main(process.argv.slice(2)));
}
