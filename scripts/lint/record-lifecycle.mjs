// Exploration-record lifecycle gate.
//
// Enforces two rules the work-log convention states about a record under
// devlog/discussions/ and the roadmap rows that own it:
//
//   A closed roadmap row names no record. The row is what owns the record, so
//   when the row closes the record is deleted, or re-pointed to an open row
//   before the row closes. A link left in a closed row names a file the rule
//   removes.
//
//   A record that has concluded or been rejected and that no open row names is
//   a deletion the cleanup has not run. The record's task has ended, so the
//   file is a second source beside the ADR or handover that holds its result.
//
// Tenancy is read from devlog/roadmap.md and the state from the record's name:
// `- [ ]` rows and `- [x]` rows are told apart by their checkbox, at any indent,
// and the state is the third field of YYYYMMDD-{type}-{state}-{description}.md.
//
// Scope: a record dated before the cutover is exempt from both rules, the same
// exemption the name gate applies, because the corpus predates them; the T5
// cleanup row removes the exemption by bringing the corpus to conformance.
//
// Exit codes: 0 = no findings, 1 = findings or the scan could not run. The
// finding count is printed, never encoded in the exit code.

import { readdirSync, existsSync, readFileSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { RECORD_CUTOVER } from "./record-cutover.mjs";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** The states whose record is a deletion candidate once its row has closed. */
const ENDED = ["concluded", "rejected"];

/** An open row: a checklist entry whose box is unchecked, at any indent. */
const OPEN_ROW = /^\s*- \[ \] /;

/** A closed row: a checklist entry whose box is checked, at any indent. */
const CLOSED_ROW = /^\s*- \[x\] /;

function parseArgs(argv) {
  const opts = { root: REPO_ROOT, cutover: RECORD_CUTOVER, force: false };
  for (const arg of argv) {
    if (arg.startsWith("--root=")) opts.root = arg.slice("--root=".length);
    else if (arg.startsWith("--cutover=")) opts.cutover = arg.slice("--cutover=".length);
    else if (arg === "--force") opts.force = true;
  }
  return opts;
}

/** The state field of a record name, or null when the name is not that shape. */
function stateOf(name) {
  const match = /^\d{8}-[a-z]+-([a-z]+)-/.exec(name);
  return match ? match[1] : null;
}

/** The leading date of a record name, or null. */
function dateOf(name) {
  const match = /^(\d{8})-/.exec(name);
  return match ? match[1] : null;
}

/** A row shortened for a finding, so one long row does not fill the report. */
function clip(text) {
  const trimmed = text.trim();
  return trimmed.length > 100 ? `${trimmed.slice(0, 97)}...` : trimmed;
}

function main() {
  const opts = parseArgs(process.argv.slice(2));
  const dir = join(opts.root, "devlog", "discussions");
  const roadmap = join(opts.root, "devlog", "roadmap.md");

  if (!existsSync(dir)) {
    console.error(`Record lifecycle gate: ${dir} is missing; cannot scan.`);
    return 1;
  }

  const names = readdirSync(dir).filter((entry) => entry.endsWith(".md"));
  const rows = existsSync(roadmap) ? readFileSync(roadmap, "utf8").split("\n") : [];
  const openRows = rows.filter((row) => OPEN_ROW.test(row));
  const closedRows = rows.filter((row) => CLOSED_ROW.test(row));

  const subjects = names.filter((name) => {
    const date = dateOf(name);
    if (opts.force) return true;
    return date !== null && date >= opts.cutover;
  });

  const findings = [];
  const owned = new Set();
  for (const row of openRows) {
    for (const name of names) if (row.includes(name)) owned.add(name);
  }

  for (const name of subjects) {
    const state = stateOf(name);
    if (!ENDED.includes(state)) continue;
    if (owned.has(name)) continue;
    findings.push(
      `${name}: state "${state}", and no open roadmap row names it. ` +
        `The task that owned the record has ended, so the file is a deletion that has not run`,
    );
  }

  for (const row of closedRows) {
    for (const name of subjects) {
      if (!row.includes(name)) continue;
      findings.push(
        `${clip(row)}: a closed row names the record ${name}. A closed row carries no discussion link; ` +
          `re-point the record to an open row before the row closes, or delete it`,
      );
    }
  }

  for (const finding of findings) console.log(finding);
  if (findings.length > 0) {
    console.log(`Record lifecycle gate: ${findings.length} finding(s)`);
    return 1;
  }
  console.log(
    `Record lifecycles: clean across ${subjects.length} record(s) and ${openRows.length + closedRows.length} roadmap row(s)`,
  );
  return 0;
}

process.exit(main());
