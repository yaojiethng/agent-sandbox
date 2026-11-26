// Exploration-record name gate.
//
// Enforces the work-log convention's name for a record under
// devlog/discussions/: YYYYMMDD-{type}-{status}-{description}.md.
//
// The failure this gate exists for: the handover name carries a per-day index
// (YYYYMMDD-NN-<shortform>-<slug>.md) and the exploration record's name does
// not. Copy the index into a discussion name and the date carries two sequences
// with nothing in common, so "the day's max plus one" reads as a handover
// number that is not one, and a reader sorting the folder cannot tell which
// kind of record the number belongs to.
//
// Scope: the default scan reads the live discussions folder. `archive/` is not
// walked, and every live record is held to the shape: no date exempts one.
//
// Exit codes: 0 = no findings, 1 = findings or the scan could not run. The
// finding count is printed, never encoded in the exit code.

import { readdirSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** The exploration-record type vocabulary, from the work-log convention. */
const TYPES = ["story", "study", "design", "report"];

/** The state vocabulary, shared by all four types. */
const STATUSES = ["open", "concluded", "rejected"];

/** The conforming name: date, type, state, description. */
const CONFORMING = /^(\d{8})-([a-z]+)-([a-z]+)-([a-z0-9][a-z0-9._-]*)\.md$/;

/** The handover name: date, per-day index, shortform, slug. */
const HANDOVER_SHAPE = /^(\d{8})-(\d{2})-(.+)$/;

function parseArgs(argv) {
  const opts = { root: REPO_ROOT, files: [] };
  for (const arg of argv) {
    if (arg.startsWith("--root=")) opts.root = arg.slice("--root=".length);
    else opts.files.push(arg);
  }
  return opts;
}

/** The leading date of a record name, or null when the name carries none. */
/** Every finding for one filename. */
function checkName(name) {
  const indexed = HANDOVER_SHAPE.exec(name);
  if (indexed) {
    return [
      `${name}: carries the per-day index "${indexed[2]}", which belongs to the handover record. ` +
        `An exploration record is named YYYYMMDD-{type}-{status}-{description}.md`,
    ];
  }
  const match = CONFORMING.exec(name);
  if (!match) {
    return [
      `${name}: does not match YYYYMMDD-{type}-{status}-{description}.md. ` +
        `The description allows lowercase letters, digits, period, underscore and hyphen`,
    ];
  }
  const [, , type, status] = match;
  const findings = [];
  if (!TYPES.includes(type)) {
    findings.push(`${name}: "${type}" is not one of ${TYPES.join(", ")}`);
  }
  if (!STATUSES.includes(status)) {
    findings.push(`${name}: "${status}" is not one of ${STATUSES.join(", ")}`);
  }
  return findings;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const dir = join(opts.root, "devlog", "discussions");

  let names = opts.files;
  if (names.length === 0) {
    if (!existsSync(dir)) {
      console.error(`Record name gate: ${dir} is missing; cannot scan.`);
      return 1;
    }
    names = readdirSync(dir)
      .filter((entry) => entry.endsWith(".md"))
      .map((entry) => join("devlog", "discussions", entry));
  }

  const findings = [];
  for (const name of names) {
    const base = name.split("/").pop();
    findings.push(...checkName(base));
  }

  for (const finding of findings) console.log(finding);
  if (findings.length > 0) {
    console.log(`Record name gate: ${findings.length} finding(s)`);
    return 1;
  }
  console.log(`Record names: clean across ${names.length} record(s)`);
  return 0;
}

process.exit(main());
