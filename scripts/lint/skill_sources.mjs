// The source-keyed skill maintenance catalog.
//
// The catalog has two levels. `source-catalog.json` holds the source facts:
// the upstream URL, the resolved revision, the license, the file hashes and the
// skills forked from it. Each skill's `MAINTENANCE.md` holds the adaptation and
// the name, and points at the source by id.
//
// --check (the default) verifies the source fields, the skill set, and every
// local file hash. --write refreshes the local hashes and drops a skill whose
// record is gone. Both modes print one line per finding and exit 1 on any.
//
// Test seams: SKILL_SOURCE_ROOT points the tree at a fixture, and
// SKILL_SOURCE_CATALOG points the manifest read elsewhere.
//
// Exit codes: 0 = clean, 1 = findings or the catalog cannot be read.

import { createHash } from "crypto";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "fs";
import { basename, dirname, join, relative, resolve, sep } from "path";
import { fileURLToPath } from "url";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const ROOT = process.env.SKILL_SOURCE_ROOT
  ? resolve(process.env.SKILL_SOURCE_ROOT)
  : MODULE_ROOT;
const CATALOG = process.env.SKILL_SOURCE_CATALOG
  ? resolve(process.env.SKILL_SOURCE_CATALOG)
  : join(ROOT, "src", "reasoning", "agent", "skills", "source-catalog.json");
const SKILLS_ROOT = join(ROOT, "src", "reasoning", "agent", "skills");
const WRITE = process.argv.includes("--write");
const FINDINGS = [];

const finding = (path, message) => FINDINGS.push(`${path}: ${message}`);
const isCommit = (value) => typeof value === "string" && /^[0-9a-f]{40}$/.test(value);
const isHash = (value) => typeof value === "string" && /^[0-9a-f]{64}$/.test(value);
const isDate = (value) => typeof value === "string" && /^\d{4}-\d{2}-\d{2}$/.test(value);

function sha256(file) {
  return createHash("sha256").update(readFileSync(file)).digest("hex");
}

/** The skills whose record points at `id`, keyed by directory name. */
function recordsFor(id) {
  const records = new Map();
  if (!existsSync(SKILLS_ROOT)) return records;
  for (const entry of readdirSync(SKILLS_ROOT, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const record = join(SKILLS_ROOT, entry.name, "MAINTENANCE.md");
    if (!existsSync(record)) continue;
    const text = readFileSync(record, "utf8");
    const match = text.match(/^Source: `([^`]+)`/m);
    if (match && match[1] === id) records.set(entry.name, record);
  }
  return records;
}

function checkSource(source) {
  const id = source.id ?? "(no id)";
  const where = `source ${JSON.stringify(id)}`;
  if (!source.id) finding(CATALOG, `${where}: id is required`);
  if (typeof source.url !== "string" || !source.url.startsWith("https://")) {
    finding(CATALOG, `${where}: url must be an https URL`);
  }
  if (!isCommit(source.revision)) {
    finding(CATALOG, `${where}: revision must be a 40-character commit`);
  }
  if (!isDate(source.revision_date)) {
    finding(CATALOG, `${where}: revision_date must be YYYY-MM-DD`);
  }
  if (typeof source.license !== "string" || source.license.trim() === "") {
    finding(CATALOG, `${where}: license is required`);
  }
  if (typeof source.copyright !== "string" || source.copyright.trim() === "") {
    finding(CATALOG, `${where}: copyright is required`);
  }
  if (!Array.isArray(source.skills)) {
    finding(CATALOG, `${where}: skills must be an array`);
    return;
  }
  if (source.skills.length === 0) {
    if (typeof source.reason !== "string" || source.reason.trim() === "") {
      finding(CATALOG, `${where}: an empty source requires a reason`);
    }
    if (source.import_commit !== null) {
      finding(CATALOG, `${where}: an empty source import_commit must be null`);
    }
    for (const name of recordsFor(id).keys()) {
      finding(CATALOG, `${where}: record ${name} belongs to a forked source`);
    }
    return;
  }
  if (!isCommit(source.import_commit)) {
    finding(CATALOG, `${where}: import_commit must be a 40-character commit`);
  }

  const records = recordsFor(id);
  const manifestNames = new Set(source.skills.map((skill) => skill.name));
  for (const name of records.keys()) {
    if (!manifestNames.has(name)) {
      finding(CATALOG, `${where}: record ${name} is not in the manifest`);
    }
  }
  for (const skill of source.skills) {
    const name = skill.name ?? "(no name)";
    const localPath = skill.local_path ?? "";
    const localDir = resolve(ROOT, localPath);
    if (basename(localDir) !== name) {
      finding(CATALOG, `${where}: skill ${name} local_path does not end in the skill name`);
    }
    const rel = relative(SKILLS_ROOT, localDir);
    if (rel.startsWith("..") || rel.includes(`..${sep}`)) {
      finding(CATALOG, `${where}: skill ${name} local_path is outside the skills tree`);
    }
    if (!existsSync(localDir)) {
      finding(CATALOG, `${where}: skill ${name} local_path does not exist`);
      continue;
    }
    if (typeof skill.upstream_path !== "string" || skill.upstream_path.trim() === "") {
      finding(CATALOG, `${where}: skill ${name} upstream_path is required`);
    }
    if (!records.has(name) && !WRITE) {
      finding(CATALOG, `${where}: skill ${name} has no MAINTENANCE.md record`);
    }
    const files = Array.isArray(skill.files) ? skill.files : [];
    if (files.length === 0) {
      finding(CATALOG, `${where}: skill ${name} has no files`);
    }
    const seen = new Set();
    for (const file of files) {
      const filePath = file.path ?? "";
      if (filePath === "" || filePath.startsWith("/") || filePath.split("/").includes("..")) {
        finding(CATALOG, `${where}: skill ${name} has an invalid file path ${JSON.stringify(filePath)}`);
        continue;
      }
      if (seen.has(filePath)) {
        finding(CATALOG, `${where}: skill ${name} lists ${filePath} twice`);
      }
      seen.add(filePath);
      if (!isHash(file.upstream_sha256)) {
        finding(CATALOG, `${where}: skill ${name} ${filePath} upstream_sha256 is not a sha256`);
      }
      const disk = join(localDir, filePath);
      if (!existsSync(disk)) {
        finding(CATALOG, `${where}: skill ${name} ${filePath} is missing on disk`);
        continue;
      }
      const hash = sha256(disk);
      if (file.local_sha256 !== hash) {
        if (WRITE) {
          file.local_sha256 = hash;
        } else {
          finding(
            CATALOG,
            `${where}: skill ${name} ${filePath} hash mismatch (recorded ${file.local_sha256 ?? "(none)"}, disk ${hash})`,
          );
        }
      }
    }
  }
}

let catalog;
try {
  catalog = JSON.parse(readFileSync(CATALOG, "utf8"));
} catch (error) {
  console.error(`skill sources: cannot read ${CATALOG}: ${error.message}`);
  process.exit(1);
}

if (!Array.isArray(catalog.sources) || catalog.sources.length === 0) {
  console.error("skill sources: the catalog holds no sources");
  process.exit(1);
}

for (const source of catalog.sources) {
  checkSource(source);
  if (WRITE) {
    const records = recordsFor(source.id);
    source.skills = source.skills.filter((skill) => records.has(skill.name));
  }
}

if (WRITE && FINDINGS.length === 0) {
  writeFileSync(CATALOG, `${JSON.stringify(catalog, null, 2)}\n`);
  console.log(
    `skill sources: wrote ${catalog.sources.length} source(s) and ` +
      `${catalog.sources.reduce((count, source) => count + source.skills.length, 0)} skill(s)`,
  );
  process.exit(0);
}

if (FINDINGS.length > 0) {
  for (const entry of FINDINGS) console.error(entry);
  console.error(`skill sources: ${FINDINGS.length} finding(s)`);
  process.exit(1);
}

const skills = catalog.sources.reduce((count, source) => count + source.skills.length, 0);
console.log(`skill sources: clean across ${catalog.sources.length} source(s) and ${skills} skill(s)`);
