// src/build/record-layout.mjs
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

export const LAYOUT_REL = "src/build/record-layout.json";
const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../..");

export function load_layout(root = REPO_ROOT) {
  return JSON.parse(readFileSync(join(root, LAYOUT_REL), "utf8"));
}

export function record_trees(layout) {
  return Array.isArray(layout.recordTrees) ? layout.recordTrees : [];
}

export function record_archives(layout) {
  const out = [];
  for (const kind of Object.values(layout.kinds || {})) {
    if (kind.archive) out.push(kind.archive.endsWith("/") ? kind.archive : `${kind.archive}/`);
  }
  return out;
}

function spec(layout, kind) {
  const found = (layout.kinds || {})[kind];
  if (!found || !found.root) {
    throw new Error(`kind ${kind} has no root in ${LAYOUT_REL}; the kinds are: ${Object.keys(layout.kinds || {}).join(", ")}`);
  }
  return found;
}

export function kind_root(root, layout, kind) {
  return join(root, spec(layout, kind).root);
}

export function kind_archive(root, layout, kind) {
  const found = (layout.kinds || {})[kind];
  return found && found.archive ? join(root, found.archive) : null;
}

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

export function latest_handover(root, layout, track = null) {
  const files = walk_kind(root, layout, "handover").filter(
    (file) => !track || in_track(root, layout, file, track),
  );
  if (files.length === 0) return null;
  const scored = files.map((file) => ({ file, time: git_time(root, file) }));
  scored.sort((a, b) => b.time - a.time || b.file.localeCompare(a.file));
  return scored[0].file;
}

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
  for (const file of walk_kind(root, layout, "handover")) {
    const match = /(\d{8})-(\d{2})-/.exec(file);
    if (match && match[1] === ymd) used.add(Number(match[2]));
  }
  let n = 1;
  while (used.has(n)) n += 1;
  return `${ymd}-${String(n).padStart(2, "0")}`;
}

function branch_track(root) {
  try {
    const branch = execFileSync("git", ["-C", root, "branch", "--show-current"], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    }).trim();
    const match = /(M\d+(?:[._]\d+)*)/.exec(branch);
    return match ? match[1].replace(/_/g, ".") : null;
  } catch {
    return null;
  }
}

export function current_track(root) {
  const marker = join(root, ".scratchpad", "worklog-track");
  if (existsSync(marker)) return readFileSync(marker, "utf8").trim();
  const fromBranch = branch_track(root);
  if (fromBranch) return fromBranch;
  const layout = load_layout(root);
  const latest = latest_handover(root, layout);
  if (!latest) return null;
  const id = read_milestone(latest).split(" - ")[0];
  return id || null;
}

function parse(argv) {
  const opts = { root: REPO_ROOT, track: null, date: null, command: null, kind: null, all: false };
  const rest = [];
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === "--root") opts.root = resolve(argv[(i += 1)]);
    else if (arg.startsWith("--root=")) opts.root = resolve(arg.slice("--root=".length));
    else if (arg === "--track") opts.track = argv[(i += 1)];
    else if (arg.startsWith("--track=")) opts.track = arg.slice("--track=".length);
    else if (arg === "--all") opts.all = true;
    else if (arg === "--help" || arg === "-h") opts.command = "help";
    else if (arg === "--date") opts.date = argv[(i += 1)];
    else if (arg.startsWith("--date=")) opts.date = arg.slice("--date=".length);
    else rest.push(arg);
  }
  [opts.command, opts.kind] = rest;
  return opts;
}

const USAGE = `Usage: worklog.sh <command> [options]

  trees                          the record trees the lint rules exempt
  path <kind>                    the root of one record kind
  list [--track T]               every handover record, or one track's, oldest first
  latest [--track T | --all]     the tip record of a track, or of the tree
  active [--track T | --all]     the one record whose status is Active
  track                          the track the branch or the marker names
  reserve-id --track T [--date YYYYMMDD]
                                 the next free id in the track's block

A track is a folder under devlog/handovers/ and is named by \
M<number> (M3.5.1), T<number> (T12) or the track's own folder name.

latest and active answer on the caller's track unless --track names one or
--all asks for every track. The caller's track comes from
.scratchpad/worklog-track, then the branch name, then the newest record's
milestone. A track whose folder is gone has retired: pass --track <T> for the
track you mean, or --all when the answer may come from any of them.

list always enumerates, so it needs no track. Every command takes
--root <dir>, which points the reads at another checkout.`;

function usage(text = USAGE) {
  console.log(text);
}

function fail(message) {
  console.error(`worklog: ${message}`);
  process.exitCode = 1;
}

function main() {
  const opts = parse(process.argv.slice(2));
  const layout = load_layout(opts.root);
  const handoverRoot = kind_root(opts.root, layout, "handover");
  const liveTracks = existsSync(handoverRoot)
    ? readdirSync(handoverRoot, { withFileTypes: true })
        .filter((entry) => entry.isDirectory())
        .map((entry) => entry.name)
        .sort()
    : [];

  const trackError = (why) =>
    fail(
      `${why} Live tracks are: ${liveTracks.join(", ") || "none"}. ` +
        "Pass --track <T> for the track you mean, or --all to answer across every track.",
    );

  const track = () => {
    if (opts.track) {
      if (!liveTracks.includes(opts.track)) {
        trackError(`--track ${opts.track} has no folder under ${relative(opts.root, handoverRoot)}.`);
        return null;
      }
      return opts.track;
    }
    if (opts.all) return null;
    const current = current_track(opts.root);
    if (!current) {
      trackError("The caller's track is not known: the branch names no track and no record is filed.");
      return null;
    }
    if (!liveTracks.includes(current)) {
      trackError(
        `The caller's track ${current} has retired: its folder is gone from ` +
          `${relative(opts.root, handoverRoot)}, so a record has nowhere to file and none is the tip.`,
      );
      return null;
    }
    return current;
  };

  switch (opts.command) {
    case "trees":
      for (const tree of record_trees(layout)) console.log(tree);
      return;
    case "path":
      if (!opts.kind) return fail(`path needs a kind; one of: ${Object.keys(layout.kinds || {}).join(", ")}`);
      console.log(relative(opts.root, kind_root(opts.root, layout, opts.kind)));
      return;
    case "list":
      for (const file of walk_kind(opts.root, layout, "handover")) {
        if (opts.track && !in_track(opts.root, layout, file, opts.track)) continue;
        console.log(relative(opts.root, file));
      }
      return;
    case "latest": {
      const on = track();
      if (on === null && !opts.all) return;
      const file = latest_handover(opts.root, layout, on);
      if (!file) return fail(`No handover record is filed on ${on ?? "any track"} under ${relative(opts.root, handoverRoot)}.`);
      console.log(relative(opts.root, file));
      return;
    }
    case "active": {
      const on = track();
      if (on === null && !opts.all) return;
      const file = active_handover(opts.root, layout, on);
      if (!file) return;
      console.log(relative(opts.root, file));
      return;
    }
    case "track": {
      const current = opts.track || current_track(opts.root);
      if (!current) return fail("The branch names no track and no record is filed, so there is no current track.");
      if (!liveTracks.includes(current)) {
        return fail(
          `The current track ${current} has retired: its folder is gone from ${relative(opts.root, handoverRoot)}. ` +
            `Rename the branch or the marker, or pass --track <T>. Live tracks are: ${liveTracks.join(", ") || "none"}.`,
        );
      }
      console.log(current);
      return;
    }
    case "reserve-id": {
      const on = opts.track || current_track(opts.root);
      if (!on) return fail("reserve-id needs --track <T>: the branch names no track and no record is filed.");
      const date = opts.date
        ? new Date(`${opts.date.slice(0, 4)}-${opts.date.slice(4, 6)}-${opts.date.slice(6, 8)}T00:00:00Z`)
        : new Date();
      if (Number.isNaN(date.getTime())) return fail(`--date ${opts.date} is not YYYYMMDD.`);
      console.log(reserve_id(opts.root, layout, on, date));
      return;
    }
    case "help":
      usage();
      return;
    default:
      if (opts.command) {
        usage(`Unknown command ${opts.command}.\n\n${USAGE}`);
        process.exitCode = 1;
        return;
      }
      usage();
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
