// src/build/record-layout.mjs
// The work-log record layout, declared once and served to every check and every
// workflow prompt that needs it.
//
// `src/build/record-layout.json` is the declaration. This module is its only
// reader: the gates and the CLI call it rather than restating a root, an
// archive rule or an id rule. The CLI answers the derived reads the prompts
// used to compute by hand (`ls | sort | tail -1`, `grep -l "Status: Active"`),
// so order comes from git and identity comes from the record.
//
// CLI:
//   node record-layout.mjs trees
//   node record-layout.mjs path <kind> [--root DIR]
//   node record-layout.mjs list [--track T] [--root DIR]
//   node record-layout.mjs latest [--track T] [--root DIR]
//   node record-layout.mjs active [--track T] [--root DIR]
//   node record-layout.mjs track [--root DIR]
//   node record-layout.mjs reserve-id --track T [--date YYYYMMDD] [--root DIR]

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const LAYOUT_REL = "src/build/record-layout.json";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

/** Read the one declaration. */
export function load_layout(root = REPO_ROOT) {
  return JSON.parse(readFileSync(join(root, LAYOUT_REL), "utf8"));
}

/** The trees the lint rules exempt, read from the declaration. */
export function record_trees(layout) {
  return Array.isArray(layout.recordTrees) ? layout.recordTrees : [];
}

function spec(layout, kind) {
  const found = (layout.kinds || {})[kind];
  if (!found || !found.root) throw new Error(`record-layout: no root for kind ${kind}`);
  return found;
}

/** The absolute root of one record kind. */
export function kind_root(root, layout, kind) {
  return join(root, spec(layout, kind).root);
}

/** The absolute archive root of one record kind, or null. */
export function kind_archive(root, layout, kind) {
  const found = (layout.kinds || {})[kind];
  return found && found.archive ? join(root, found.archive) : null;
}

/** Every record of one kind, recursively, with the archive skipped. */
export function walk_kind(root, layout, kind) {
  const base = kind_root(root, layout, kind);
  const archive = kind_archive(root, layout, kind);
  const pattern = spec(layout, kind).filename ? new RegExp(spec(layout, kind).filename) : null;
  const out = [];
  if (!existsSync(base)) return out;
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const path = join(dir, entry.name);
      if (entry.isDirectory()) {
        if (archive && resolve(path) === resolve(archive)) continue;
        walk(path);
      } else if (entry.name.endsWith(".md") && (!pattern || pattern.test(entry.name))) {
        out.push(path);
      }
    }
  };
  walk(base);
  return out.sort();
}

function git_time(root, file) {
  try {
    const out = execFileSync(
      "git",
      ["-C", root, "log", "-1", "--format=%ct", "--", relative(root, file)],
      { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
    ).trim();
    return out ? Number(out) : 0;
  } catch {
    return 0;
  }
}

function frontmatter(text) {
  const match = /^---\n([\s\S]*?)\n---/.exec(text);
  return match ? match[1] : "";
}

function field(block, name) {
  const match = new RegExp(`^${name}:\\s*(.+)$`, "m").exec(block);
  return match ? match[1].trim() : "";
}

export function read_status(file) {
  return field(frontmatter(readFileSync(file, "utf8")), "status");
}

export function read_milestone(file) {
  return field(frontmatter(readFileSync(file, "utf8")), "milestone");
}

function track_of(root, layout, file) {
  const rel = relative(kind_root(root, layout, "handover"), file).replace(/\\/g, "/");
  if (rel.includes("/")) return rel.split("/")[0];
  const milestone = read_milestone(file);
  return milestone ? milestone.split(" - ")[0] : null;
}

function in_track(root, layout, file, track) {
  return track_of(root, layout, file) === track;
}

/** The latest handover on a track, by git commit order; the filename is the fallback. */
export function latest_handover(root, layout, track = null) {
  const files = walk_kind(root, layout, "handover").filter(
    (file) => !track || in_track(root, layout, file, track),
  );
  if (files.length === 0) return null;
  const scored = files.map((file) => ({ file, time: git_time(root, file) }));
  scored.sort((a, b) => b.time - a.time || b.file.localeCompare(a.file));
  return scored[0].file;
}

/** The one record on a track whose status is Active. More than one is an error. */
export function active_handover(root, layout, track = null) {
  const files = walk_kind(root, layout, "handover").filter(
    (file) => !track || in_track(root, layout, file, track),
  );
  const active = files.filter((file) => read_status(file) === "Active");
  if (active.length > 1) {
    throw new Error(`more than one Active handover on ${track || "the tree"}: ${active.map((f) => relative(root, f)).join(", ")}`);
  }
  return active[0] || null;
}

/** The next free id in a track's reserved block, or the global per-day fallback. */
export function reserve_id(root, layout, track, date = new Date()) {
  const ymd = date.toISOString().slice(0, 10).replace(/-/g, "");
  const dir = join(kind_root(root, layout, "handover"), track);
  const used = new Set();
  if (existsSync(dir)) {
    for (const entry of readdirSync(dir)) {
      const match = /^(\d{8})-(\d{2})-/.exec(entry);
      if (match && match[1] === ymd) used.add(Number(match[2]));
    }
  }
  const readme = join(dir, "README.md");
  if (existsSync(readme)) {
    const match = /ids:\s*(\d{2})\s*-\s*(\d{2})/.exec(readFileSync(readme, "utf8"));
    if (match) {
      const start = Number(match[1]);
      const end = Number(match[2]);
      for (let n = start; n <= end; n += 1) {
        if (!used.has(n)) return `${ymd}-${String(n).padStart(2, "0")}`;
      }
      throw new Error(`the block ${match[1]}-${match[2]} is exhausted for ${ymd}`);
    }
  }
  // A track without a reserved block falls back to the global per-day rule,
  // which is what the flat records use until the migration runs.
  for (const file of walk_kind(root, layout, "handover")) {
    const match = /(\d{8})-(\d{2})-/.exec(file);
    if (match && match[1] === ymd) used.add(Number(match[2]));
  }
  let n = 1;
  while (used.has(n)) n += 1;
  return `${ymd}-${String(n).padStart(2, "0")}`;
}

/** The track the caller is in: the marker, the branch, or the latest record's milestone. */
export function current_track(root) {
  const marker = join(root, ".scratchpad", "worklog-track");
  if (existsSync(marker)) return readFileSync(marker, "utf8").trim();
  try {
    const branch = execFileSync("git", ["-C", root, "branch", "--show-current"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const match = /(M\d+(?:[._]\d+)*)/.exec(branch);
    if (match) return match[1].replace(/_/g, ".");
  } catch {
    // Not a git repository: fall through to the latest record's milestone.
  }
  const layout = load_layout(root);
  const latest = latest_handover(root, layout);
  if (!latest) return null;
  const id = read_milestone(latest).split(" - ")[0];
  return id || null;
}

function parse(argv) {
  const opts = { root: REPO_ROOT, track: null, date: null, command: null, kind: null };
  const rest = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--root") opts.root = resolve(argv[(i += 1)]);
    else if (arg.startsWith("--root=")) opts.root = resolve(arg.slice("--root=".length));
    else if (arg === "--track") opts.track = argv[(i += 1)];
    else if (arg.startsWith("--track=")) opts.track = arg.slice("--track=".length);
    else if (arg === "--date") opts.date = argv[(i += 1)];
    else if (arg.startsWith("--date=")) opts.date = arg.slice("--date=".length);
    else rest.push(arg);
  }
  [opts.command, opts.kind] = rest;
  return opts;
}

function usage() {
  console.log(`Usage: worklog.sh <command> [options]
  trees
  path <kind> [--root DIR]
  list [--track T] [--root DIR]
  latest [--track T] [--root DIR]
  active [--track T] [--root DIR]
  track [--root DIR]
  reserve-id --track T [--date YYYYMMDD] [--root DIR]`);
}

function main() {
  const opts = parse(process.argv.slice(2));
  const layout = load_layout(opts.root);
  const track = opts.track || current_track(opts.root);
  switch (opts.command) {
    case "trees":
      for (const tree of record_trees(layout)) console.log(tree);
      break;
    case "path":
      if (!opts.kind) throw new Error("path needs a kind");
      console.log(relative(opts.root, kind_root(opts.root, layout, opts.kind)));
      break;
    case "list":
      for (const file of walk_kind(opts.root, layout, "handover")) {
        if (!track || in_track(opts.root, layout, file, track)) console.log(relative(opts.root, file));
      }
      break;
    case "latest": {
      const file = latest_handover(opts.root, layout, track);
      if (file) console.log(relative(opts.root, file));
      break;
    }
    case "active": {
      const file = active_handover(opts.root, layout, track);
      if (file) console.log(relative(opts.root, file));
      break;
    }
    case "track":
      if (track) console.log(track);
      break;
    case "reserve-id": {
      if (!track) throw new Error("reserve-id needs --track");
      const date = opts.date
        ? new Date(`${opts.date.slice(0, 4)}-${opts.date.slice(4, 6)}-${opts.date.slice(6, 8)}T00:00:00Z`)
        : new Date();
      console.log(reserve_id(opts.root, layout, track, date));
      break;
    }
    default:
      usage();
      if (opts.command) process.exit(1);
  }
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    main();
  } catch (error) {
    console.error(`worklog: ${error.message}`);
    process.exit(1);
  }
}
