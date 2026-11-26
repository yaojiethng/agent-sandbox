// Exploration-record lifecycle gate.
//
// Enforces three rules the work-log convention states about a record under
// devlog/discussions/ and the roadmap rows that own it:
//
//   A closed roadmap row names no record. The row is what owns the record, so
//   when the row closes the record is deleted, or re-pointed to an open row
//   before the row closes. A link left in a closed row names a file the rule
//   removes.
//
//   A record that no open row names is a deletion the cleanup has not run. The
//   record's task has ended, so the file is a second source beside the ADR or
//   handover that holds its result.
//
//   An open row names no record that is not there. A row names the evidence it
//   has, so a name that resolves to nothing is a row with no source, and the
//   row states what now carries it.
//
//   A working document under .agents/drafts/ is owned the way a record is: a
//   roadmap line outside a closed row names it, with its folder, while the task
//   it belongs to is open. Tenancy is stated with the path, because a bare file
//   name in this repository is ambiguous.
//
// Tenancy is read from devlog/roadmap.md and devlog/roadmap_future.md, and
// `- [ ]` rows and `- [x]` rows are told apart by their checkbox, at any
// indent. The enquiry's state does not decide the deletion: a row that closes
// re-points the record or deletes it.
//
// Scope: both rules read every live record, and archive/ is not walked.
//
// Exit codes: 0 = no findings, 1 = findings or the scan could not run. The
// finding count is printed, never encoded in the exit code.

import { readdirSync, existsSync, readFileSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

/** An open row: a checklist entry whose box is unchecked, at any indent. */
const OPEN_ROW = /^\s*- \[ \] /;

/** A closed row: a checklist entry whose box is checked, at any indent. */
const CLOSED_ROW = /^\s*- \[x\] /;

/** A discussion record's name, wherever a row spells it. */
const RECORD_NAME = /\b\d{8}-(?:story|study|design|report)-[a-z]+-[a-z0-9][a-z0-9._-]*\.md\b/g;

function parseArgs(argv) {
  const opts = { root: REPO_ROOT };
  for (const arg of argv) {
    if (arg.startsWith("--root=")) opts.root = arg.slice("--root=".length);
  }
  return opts;
}

/** The state field of a record name, or null when the name is not that shape. */
function stateOf(name) {
  const match = /^\d{8}-[a-z]+-([a-z]+)-/.exec(name);
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
  const roadmaps = ["roadmap.md", "roadmap_future.md"]
    .map((name) => join(opts.root, "devlog", name))
    .filter((file) => existsSync(file));

  if (!existsSync(dir)) {
    console.error(`Record lifecycle gate: ${dir} is missing; cannot scan.`);
    return 1;
  }

  const names = readdirSync(dir).filter((entry) => entry.endsWith(".md"));
  const rows = roadmaps.flatMap((file) => readFileSync(file, "utf8").split("\n"));
  const openRows = rows.filter((row) => OPEN_ROW.test(row));
  const closedRows = rows.filter((row) => CLOSED_ROW.test(row));

  const subjects = names;

  const findings = [];
  const draftsDir = join(opts.root, ".agents", "drafts");
  const drafts = existsSync(draftsDir) ? readdirSync(draftsDir).filter((entry) => !entry.startsWith(".")) : [];
  const openText = rows.filter((row) => !CLOSED_ROW.test(row)).join("\n");

  for (const name of drafts) {
    if (openText.includes(`.agents/drafts/${name}`)) continue;
    findings.push(
      `${name}: no roadmap line outside a closed row names .agents/drafts/${name}. A working document is ` +
        `cleaned up with the task it belongs to, so the file is a deletion that has not run`,
    );
  }

  for (const row of closedRows) {
    for (const name of drafts) {
      if (!row.includes(`.agents/drafts/${name}`)) continue;
      findings.push(
        `${clip(row)}: a closed row names the working document ${name}. A closed row carries no working ` +
          `document link; delete it with the task that closed, or name it on the row that now uses it`,
      );
    }
  }
  const owned = new Set();
  for (const row of openRows) {
    for (const name of names) if (row.includes(name)) owned.add(name);
  }

  for (const name of subjects) {
    if (owned.has(name)) continue;
    findings.push(
      `${name}: no open roadmap row names it. A row that closes re-points the record ` +
        `to another open row or deletes it, so the file is a deletion that has not run`,
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

  for (const row of openRows) {
    for (const token of new Set(row.match(RECORD_NAME) ?? [])) {
      if (names.includes(token)) continue;
      findings.push(
        `${clip(row)}: an open row names ${token}, which is not in the record directory. ` +
          `A row names the evidence it has, so say what carries it now, or delete the name`,
      );
    }
  }

  for (const finding of findings) console.log(finding);
  if (findings.length > 0) {
    console.log(`Record lifecycle gate: ${findings.length} finding(s)`);
    return 1;
  }
  console.log(
    `Record lifecycles: clean across ${subjects.length} record(s), ${drafts.length} working document(s) ` +
      `and ${openRows.length + closedRows.length} roadmap row(s)`,
  );
  return 0;
}

process.exit(main());
