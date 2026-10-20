// Handover format gate.
//
// Enforces the work-log convention's record shape over handovers: the
// frontmatter fields (date, milestone, type, status) and the section set (the
// required sections present, the forbidden ones absent).
//
// Scope: the default scan reads the live handover folder, which the archive
// keeps free of every record written before the cutover; a record there that
// lacks the frontmatter block is a finding. A file list without `--force` (the
// `--staged` mode) still honours the cutover, so a correction to a record in
// the archive is not blocked. `--force` drops the cutover for the file list it
// is given, which is the on-demand audit mode handover-maintenance uses.
//
// Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
// finding count is printed, never encoded in the exit code.

import { readFileSync, readdirSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { loadYaml } from "./yaml-loader.mjs";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const DEFAULT_CUTOVER = "20261001";

/** The frontmatter type vocabulary, from the project's work-log convention. */
const TYPES = [
  "Implementation", "Discussion", "Design", "Plan", "Documentation",
  "Workflow", "Housekeeping", "Audit",
];

/** The status vocabulary, from the project's work-log convention. */
const STATUSES = ["Open", "Active", "Closed"];

/** The required sections, in the order the project's work-log convention lists them. */
const REQUIRED_SECTIONS = [
  "Objective", "Scope", "Acceptance criteria",
  "Decisions", "Decisions pending", "Findings", "Completed",
];

/** The body lines of a section, from after its heading to the next `## ` heading. */
function sectionBody(text, name) {
  const lines = text.split("\n");
  const start = lines.findIndex((l) => l.trim() === `## ${name}`);
  if (start < 0) return null;
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((l) => /^## /.test(l));
  return { line: start + 1, lines: end < 0 ? rest : rest.slice(0, end) };
}

/** The sections the policy forbids. */
const FORBIDDEN_SECTIONS = ["Deferred", "Carried forward", "What's Next"];

function argValue(args, name) {
  const hit = args.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : null;
}

const args = process.argv.slice(2);
const cutover = (argValue(args, "cutover") || DEFAULT_CUTOVER).replace(/-/g, "");
const root = argValue(args, "root") ? resolve(argValue(args, "root")) : REPO_ROOT;
const named = args.filter((a) => !a.startsWith("--"));
const force = args.includes("--force");
// The default scan reads the live handover folder, which the archive keeps free
// of every record written before the frontmatter rule, so an absent block there
// is a finding rather than history. A named file list keeps the cutover.
const defaultScan = named.length === 0;

const { parse } = loadYaml("Handover format gate");

/** The frontmatter block, or null when the file does not open with one. */
function frontmatterOf(text) {
  if (!text.startsWith("---\n")) return null;
  const end = text.indexOf("\n---", 4);
  if (end < 0) return null;
  return { body: text.slice(4, end), offset: 1 };
}

/** Top-level section headings, ignoring fenced code blocks. */
function headings(text) {
  const out = [];
  let fence = false;
  text.split("\n").forEach((line, i) => {
    if (/^\s*```/.test(line)) {
      fence = !fence;
      return;
    }
    if (fence) return;
    const match = /^## (.+?)\s*$/.exec(line);
    if (match) out.push({ name: match[1], line: i + 1 });
  });
  return out;
}

/** The path shown in a finding: relative to the scan root when it is under it. */
function display(file) {
  const abs = resolve(file);
  return abs.startsWith(root + "/") ? abs.slice(root.length + 1) : file;
}

const findings = [];
const files = [];

if (named.length > 0) {
  files.push(...named);
} else {
  const dir = join(root, "devlog", "handovers");
  if (existsSync(dir)) {
    for (const entry of readdirSync(dir).sort()) {
      if (entry.endsWith(".md")) files.push(join(dir, entry));
    }
  }
}

let checked = 0;
for (const file of files) {
  if (!existsSync(file)) {
    findings.push({ rel: display(file), line: 1, msg: "file does not exist" });
    continue;
  }
  const text = readFileSync(file, "utf8");
  const block = frontmatterOf(text);
  const rel = display(file);

  if (block === null) {
    // An absent block is the old bold-header form. The default scan reads the
    // live folder, where the archive boundary leaves only records that must
    // carry the block, so its absence is a finding; a named file list keeps the
    // cutover, so a correction to a record in the archive is not blocked.
    if (force || defaultScan) {
      checked += 1;
      findings.push({ rel, line: 1, msg: "no YAML frontmatter block; the header fields must be frontmatter" });
    }
    continue;
  }

  let fields;
  try {
    fields = parse(block.body) || {};
  } catch (error) {
    checked += 1;
    findings.push({ rel, line: 1, msg: `frontmatter does not parse: ${String(error.message).split("\n")[0]}` });
    continue;
  }

  const date = fields.date === undefined ? "" : String(fields.date);
  if (!force && date.replace(/-/g, "") < cutover) continue;
  checked += 1;

  for (const key of ["date", "milestone", "type", "status"]) {
    const value = fields[key];
    if (value === undefined || value === null || String(value).trim() === "") {
      findings.push({ rel, line: 1, msg: `frontmatter is missing a non-empty \`${key}\`` });
    }
  }
  if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    findings.push({ rel, line: 1, msg: `\`date\` is not YYYY-MM-DD: ${date}` });
  }
  if (fields.type !== undefined && !TYPES.includes(String(fields.type))) {
    findings.push({ rel, line: 1, msg: `\`type\` is not one of ${TYPES.join(", ")}: ${fields.type}` });
  }
  if (fields.status !== undefined && !STATUSES.includes(String(fields.status))) {
    findings.push({ rel, line: 1, msg: `\`status\` is not one of ${STATUSES.join(", ")}: ${fields.status}` });
  }  if (String(fields.status) === "Closed") {
    const section = sectionBody(text, "Findings");
    if (section) {
      const rows = section.lines
        .map((line, i) => ({ text: line, line: section.line + 1 + i }))
        .filter((r) => /^\s*\|/.test(r.text) && !/^\s*\|[\s:|-]+\|\s*$/.test(r.text));
      const header = rows[0];
      if (header) {
        const cells = header.text.split("|").slice(1, -1).map((c) => c.trim().toLowerCase());
        const index = cells.indexOf("triaged to");
        if (index < 0) {
          findings.push({ rel, line: header.line, msg: "Findings table has no `Triaged to` column; every finding carries a destination" });
        } else {
          for (const row of rows.slice(1)) {
            const cell = (row.text.split("|").slice(1, -1)[index] || "").trim();
            if (cell === "") {
              const label = (row.text.split("|")[1] || "").trim().slice(0, 60);
              findings.push({ rel, line: row.line, msg: `Findings row has no \`Triaged to\` destination: ${label}` });
            }
          }
        }
      }
    }
  }


  const found = headings(text);
  const names = found.map((h) => h.name);
  for (const section of REQUIRED_SECTIONS) {
    if (!names.includes(section)) {
      findings.push({ rel, line: 1, msg: `missing required section \`## ${section}\`` });
    }
  }
  for (const heading of found) {
    if (FORBIDDEN_SECTIONS.some((f) => heading.name === f || heading.name.startsWith(f + " "))) {
      findings.push({ rel, line: heading.line, msg: `forbidden section \`## ${heading.name}\`; deferred items go to the roadmap` });
    }
  }
}

for (const finding of findings) {
  console.log(`${finding.rel}:${finding.line} ${finding.msg}`);
}

if (findings.length === 0) {
  console.log(`Handover format gate: clean across ${checked} handover(s)`);
} else {
  console.error(`Blocking gate: ${findings.length} finding(s) across ${checked} handover(s).`);
}
process.exit(findings.length === 0 ? 0 : 1);
