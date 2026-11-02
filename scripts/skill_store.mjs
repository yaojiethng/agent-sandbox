// scripts/skill_store.mjs
//
// The source store: where it lives, what an entry is called, the checks that
// make an entry addressable, and the checks that make a file valid and
// canonical. One reader, shared by the CLI and the gate that certifies the
// skills pointing at it, so a store one caller accepts cannot be one the other
// rejects.
//
// The store is edited by hand and validated here. `collectFindings` is the one
// rule set; `check` and the gate are its two callers, and `canonicalText` is
// what `source-bump format` writes and what the gate compares a file against.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { basename, isAbsolute, join, resolve } from "node:path";

export const STORE_REL = ".agents/registry/sources";

export const KINDS = ["skill", "runbook", "prompt"];

const SOURCE_KEYS = ["schema", "id", "url", "license", "copyright", "reason", "artifacts"];
const ARTIFACT_KEYS = ["local_path", "kind", "parent", "upstream_path", "origin", "base"];

export const isId = (value) => typeof value === "string" && /^[a-z0-9][a-z0-9._-]*$/.test(value);

export const isCommit = (value) => typeof value === "string" && /^[0-9a-f]{40}$/.test(value);

export const isFileArtifact = (artifact) => artifact?.kind === "prompt";

export function isRelativePath(value) {
  if (typeof value !== "string" || value.trim() === "") return false;
  if (isAbsolute(value)) return false;
  const parts = value.split(/[\\/]/);
  return !parts.includes("..") && !parts.includes("");
}

// readStore STORE -- every parseable entry in the store, in filename order, with
// the findings the read itself produced. A missing or empty store is a finding
// unless the caller is writing one.
export function readStore(store, { allowMissing = false } = {}) {
  if (!existsSync(store)) {
    if (allowMissing) return { entries: [], findings: [] };
    return { entries: [], findings: [`${store}: the tracking store does not exist`] };
  }
  const files = readdirSync(store)
    .filter((file) => file.endsWith(".json"))
    .sort();
  if (files.length === 0 && !allowMissing) {
    return { entries: [], findings: [`${store}: the tracking store holds no source files`] };
  }
  const entries = [];
  const findings = [];
  for (const file of files) {
    const path = join(store, file);
    try {
      const text = readFileSync(path, "utf8");
      entries.push({ file, path, text, source: JSON.parse(text) });
    } catch (error) {
      findings.push(`${path}: ${error.message}`);
    }
  }
  return { entries, findings };
}

// identityFindings ENTRIES -- an id shaped like an id, an id named by its file,
// and no id or file claimed twice.
export function identityFindings(entries) {
  const findings = [];
  const ids = new Map();
  for (const entry of entries) {
    const source = entry.source;
    if (source === null || typeof source !== "object" || Array.isArray(source)) continue;
    if (!isId(source.id)) {
      findings.push(`${entry.path}: id must be a lowercase source id`);
      continue;
    }
    if (source.id !== basename(entry.file, ".json")) {
      findings.push(`${entry.path}: id ${source.id} does not match the filename ${basename(entry.file, ".json")}`);
    }
    if (ids.has(source.id)) {
      findings.push(`${entry.path}: id ${source.id} is already used by ${ids.get(source.id)}`);
      continue;
    }
    ids.set(source.id, entry.path);
  }
  return findings;
}

// storeIds ENTRIES -- the ids the store declares, for a reader that only needs
// to know which names exist.
export function storeIds(entries) {
  const ids = new Set();
  for (const entry of entries) {
    if (entry.source && isId(entry.source.id)) ids.add(entry.source.id);
  }
  return ids;
}

function addFinding(findings, where, message) {
  findings.push(`${where}: ${message}`);
}

function validateArtifact(artifact, where, findings, root) {
  if (artifact === null || typeof artifact !== "object" || Array.isArray(artifact)) {
    addFinding(findings, where, "an artifact must be an object");
    return;
  }
  for (const key of Object.keys(artifact)) {
    if (!ARTIFACT_KEYS.includes(key)) addFinding(findings, where, `unknown artifact field ${key}`);
  }
  const local = artifact.local_path;
  if (!isRelativePath(local)) {
    addFinding(findings, where, "local_path must be a relative path inside the repository");
  } else {
    const absolute = resolve(root, local);
    if (!existsSync(absolute)) {
      addFinding(findings, where, `local_path ${local} does not exist`);
    } else if (isFileArtifact(artifact)) {
      if (!statSync(absolute).isFile()) addFinding(findings, where, `prompt local_path ${local} must be a file`);
    } else {
      if (!statSync(absolute).isDirectory()) {
        addFinding(findings, where, `${artifact.kind} local_path ${local} must be a directory`);
      } else if (!existsSync(join(absolute, "SKILL.md"))) {
        addFinding(findings, where, `${artifact.kind} local_path ${local} has no SKILL.md`);
      }
    }
  }

  if (!KINDS.includes(artifact.kind)) {
    addFinding(findings, where, `kind must be one of ${KINDS.join(", ")}`);
  }
  if (!isRelativePath(artifact.upstream_path)) {
    addFinding(findings, where, "upstream_path must be a relative path");
  }
  for (const field of ["origin", "base"]) {
    if (!isCommit(artifact[field])) {
      addFinding(findings, where, `${field} must be a 40-character commit`);
    }
  }

  if (artifact.kind === "runbook") {
    if (!isRelativePath(artifact.parent)) {
      addFinding(findings, where, "a runbook must name its parent as a relative path");
    } else if (!existsSync(join(root, artifact.parent, "SKILL.md"))) {
      addFinding(findings, where, `runbook parent ${artifact.parent} has no SKILL.md`);
    }
  } else if (artifact.parent !== null) {
    addFinding(findings, where, "parent must be null unless the kind is runbook");
  }
}

function validateSource(source, where, findings, root) {
  if (source === null || typeof source !== "object" || Array.isArray(source)) {
    addFinding(findings, where, "a source file must hold a JSON object");
    return;
  }
  for (const key of Object.keys(source)) {
    if (!SOURCE_KEYS.includes(key)) addFinding(findings, where, `unknown field ${key}`);
  }
  if (source.schema !== 1) addFinding(findings, where, "schema must be 1");
  if (typeof source.url !== "string" || !source.url.startsWith("https://")) {
    addFinding(findings, where, "url must be an https URL");
  }
  for (const field of ["license", "copyright"]) {
    if (typeof source[field] !== "string" || source[field].trim() === "") {
      addFinding(findings, where, `${field} is required`);
    }
  }
  if (!Array.isArray(source.artifacts)) {
    addFinding(findings, where, "artifacts must be an array");
    return;
  }
  if (source.artifacts.length === 0) {
    if (typeof source.reason !== "string" || source.reason.trim() === "") {
      addFinding(findings, where, "an empty source requires a reason");
    }
  } else if (Object.hasOwn(source, "reason")) {
    addFinding(findings, where, "a non-empty source must not carry a reason");
  }

  const seen = new Set();
  for (const artifact of source.artifacts) {
    validateArtifact(artifact, where, findings, root);
    if (artifact && typeof artifact.local_path === "string") {
      if (seen.has(artifact.local_path)) {
        addFinding(findings, where, `artifact ${artifact.local_path} is listed twice`);
      }
      seen.add(artifact.local_path);
    }
  }
}

// collectFindings ENTRIES -- every finding the store holds, over one root. The
// root is a parameter rather than a constant so a fixture can point the same
// rules at another tree. `form` is false for the one caller that is about to
// write the canonical form, which would otherwise refuse the file it repairs.
export function collectFindings(entries, { root, form = true }) {
  const findings = identityFindings(entries);
  const locals = new Map();
  for (const entry of entries) {
    const source = entry.source;
    validateSource(source, entry.path, findings, root);
    if (!source || typeof source !== "object") continue;
    if (form && typeof entry.text === "string" && entry.text !== canonicalText(source)) {
      addFinding(
        findings,
        entry.path,
        "is not in canonical form; run `node scripts/source_bump.mjs format`",
      );
    }

    for (const artifact of Array.isArray(source.artifacts) ? source.artifacts : []) {
      if (!artifact || typeof artifact.local_path !== "string") continue;
      if (locals.has(artifact.local_path)) {
        addFinding(
          findings,
          entry.path,
          `local_path ${artifact.local_path} is already used by source ${locals.get(artifact.local_path)}`,
        );
      } else {
        locals.set(artifact.local_path, source.id ?? "(no id)");
      }
    }
  }
  return findings;
}

function normalizeArtifact(artifact) {
  return {
    local_path: artifact.local_path,
    kind: artifact.kind,
    parent: artifact.parent ?? null,
    upstream_path: artifact.upstream_path,
    origin: artifact.origin,
    base: artifact.base,
  };
}

function normalizeSource(source) {
  const normalized = {
    schema: 1,
    id: source.id,
    url: source.url,
    license: source.license,
    copyright: source.copyright,
  };
  if (source.artifacts.length === 0) normalized.reason = source.reason;
  normalized.artifacts = source.artifacts
    .slice()
    .sort((left, right) => (left.local_path < right.local_path ? -1 : left.local_path > right.local_path ? 1 : 0))
    .map(normalizeArtifact);
  return normalized;
}

// canonicalText SOURCE -- the file text the store's canonical form is. `format`
// writes it; the gate compares a file against it. It derives order, key order
// and indentation, and sets no field value.
export function canonicalText(source) {
  return `${JSON.stringify(normalizeSource(source), null, 2)}\n`;
}
