// The source-bump tracking store.
//
// The store is one JSON file per upstream source at
// `.agents/registry/sources/<source-id>.json`. A source file holds the source
// facts and the artifact edges; it holds no hashes, no patch and no adaptation
// prose. `origin` is the revision the artifact was first taken from, and
// `base` is the upstream revision the next merge reviews.
//
// The command is the only writer of the tracking file. The merge agent writes
// the local artifact and the design doc; it never transcribes the store.
//
// Commands:
//   check   -- validate every source file and every edge; writes nothing
//   add     -- create a source, create an empty source, or append one edge
//   diff    -- print the stored base -> local change from a local clone
//   prepare -- create a temporary base/ours/theirs workspace for the merge
//   record  -- move one edge's base; the origin never changes
//
// `diff` and `prepare` read a local upstream clone and never fetch. Conflict
// resolution stays with the merge agent. `check` never fetches, so it stays
// deterministic and runnable offline.
//
// Test seams: SOURCE_BUMP_ROOT points local-path resolution at a fixture, and
// SOURCE_BUMP_STORE points the store at a fixture. Every command also accepts
// --store.
//
// Exit codes: 0 = clean, written, or a diff printed; 1 = findings or refused
// write; 2 = usage.

import {
  copyFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "fs";
import { spawnSync } from "child_process";
import { tmpdir } from "os";
import { basename, dirname, isAbsolute, join, relative, resolve, sep } from "path";
import { fileURLToPath } from "url";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ROOT = process.env.SOURCE_BUMP_ROOT
  ? resolve(process.env.SOURCE_BUMP_ROOT)
  : MODULE_ROOT;
const DEFAULT_STORE = process.env.SOURCE_BUMP_STORE
  ? resolve(process.env.SOURCE_BUMP_STORE)
  : join(ROOT, ".agents", "registry", "sources");

const SOURCE_KEYS = ["schema", "id", "url", "license", "copyright", "reason", "artifacts"];
const ARTIFACT_KEYS = ["local_path", "kind", "parent", "upstream_path", "origin", "base"];
const KINDS = ["skill", "runbook", "prompt"];
const MAX_BUFFER = 64 * 1024 * 1024;
const isFileArtifact = (artifact) => artifact.kind === "prompt";

const USAGE = `Usage:
  source-bump check [--store <dir>]
  source-bump add --source <id> --url <url> --license <text> --copyright <text> \\
    --local <path> --kind <skill|runbook|prompt> --upstream <path> \\
    --origin <commit> --base <commit> [--parent <path>] [--store <dir>]
  source-bump add --source <id> --url <url> --license <text> --copyright <text> \\
    --empty --reason <text> [--store <dir>]
  source-bump diff --source <id> --local <path> --clone <dir> [--store <dir>]
  source-bump prepare --source <id> --local <path> --clone <dir> \\
    --revision <commit> [--store <dir>]
  source-bump record --source <id> --local <path> --base <commit> [--store <dir>]
  source-bump --help

The store is one JSON file per source at .agents/registry/sources/<id>.json.
The command is the only writer. diff and prepare read a local clone and never fetch.`;

function usageError(message) {
  console.error(`source-bump: ${message}`);
  console.error(USAGE);
  process.exit(2);
}

function error(message) {
  console.error(`source-bump: ${message}`);
  process.exit(1);
}

const isCommit = (value) => typeof value === "string" && /^[0-9a-f]{40}$/.test(value);
const isId = (value) => typeof value === "string" && /^[a-z0-9][a-z0-9._-]*$/.test(value);

function isRelativePath(value) {
  if (typeof value !== "string" || value.trim() === "") return false;
  if (isAbsolute(value)) return false;
  const parts = value.split(/[\\/]/);
  return !parts.includes("..") && !parts.includes("");
}

function isInsideRoot(path) {
  const rel = relative(ROOT, resolve(ROOT, path));
  return rel === "" || (!rel.startsWith("..") && !rel.split(sep).includes(".."));
}

function parseArgs(argv) {
  const args = { _: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      args._.push(token);
      continue;
    }
    const key = token.slice(2);
    if (key === "help") {
      args.help = true;
      continue;
    }
    if (key === "empty") {
      args.empty = true;
      continue;
    }
    const value = argv[index + 1];
    if (value === undefined || value.startsWith("--")) {
      usageError(`--${key} requires a value`);
    }
    args[key] = value;
    index += 1;
  }
  return args;
}

function allow(args, allowed) {
  for (const key of Object.keys(args)) {
    if (key === "_" || key === "help") continue;
    if (!allowed.includes(key)) usageError(`unknown option --${key}`);
  }
}

function required(args, key) {
  const value = args[key];
  if (typeof value !== "string" || value.trim() === "") {
    usageError(`--${key} is required`);
  }
  return value;
}

function storeOf(args) {
  return args.store ? resolve(args.store) : DEFAULT_STORE;
}

function addFinding(findings, where, message) {
  findings.push(`${where}: ${message}`);
}

function validateArtifact(artifact, where, findings) {
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
  } else if (!isInsideRoot(local)) {
    addFinding(findings, where, `local_path ${local} is outside the repository`);
  } else {
    const absolute = resolve(ROOT, local);
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
    } else if (!existsSync(join(ROOT, artifact.parent, "SKILL.md"))) {
      addFinding(findings, where, `runbook parent ${artifact.parent} has no SKILL.md`);
    }
  } else if (artifact.parent !== null) {
    addFinding(findings, where, "parent must be null unless the kind is runbook");
  }
}

function validateSource(source, where, findings) {
  if (source === null || typeof source !== "object" || Array.isArray(source)) {
    addFinding(findings, where, "a source file must hold a JSON object");
    return;
  }
  for (const key of Object.keys(source)) {
    if (!SOURCE_KEYS.includes(key)) addFinding(findings, where, `unknown field ${key}`);
  }
  if (source.schema !== 1) addFinding(findings, where, "schema must be 1");
  if (!isId(source.id)) addFinding(findings, where, "id must be a lowercase source id");
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
    validateArtifact(artifact, where, findings);
    if (artifact && typeof artifact.local_path === "string") {
      if (seen.has(artifact.local_path)) {
        addFinding(findings, where, `artifact ${artifact.local_path} is listed twice`);
      }
      seen.add(artifact.local_path);
    }
  }

  const sorted = source.artifacts
    .filter((artifact) => artifact && typeof artifact.local_path === "string")
    .map((artifact) => artifact.local_path);
  const expected = [...sorted].sort();
  if (sorted.join("\n") !== expected.join("\n")) {
    addFinding(findings, where, "artifacts must be sorted by local_path");
  }
}

function collectFindings(entries) {
  const findings = [];
  const ids = new Map();
  const locals = new Map();
  for (const entry of entries) {
    const source = entry.source;
    validateSource(source, entry.path, findings);
    if (!source || typeof source !== "object") continue;

    if (typeof source.id === "string") {
      if (ids.has(source.id)) {
        addFinding(findings, entry.path, `id ${source.id} is already used by ${ids.get(source.id)}`);
      } else {
        ids.set(source.id, entry.path);
      }
      const expectedId = basename(entry.file, ".json");
      if (source.id !== expectedId) {
        addFinding(findings, entry.path, `id ${source.id} does not match the filename ${expectedId}`);
      }
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

function loadEntries(store, allowMissing) {
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
      const source = JSON.parse(readFileSync(path, "utf8"));
      entries.push({ file, path, source });
    } catch (readError) {
      findings.push(`${path}: ${readError.message}`);
    }
  }
  return { entries, findings };
}

function printFindings(findings) {
  for (const finding of findings) console.error(finding);
  console.error(`source-bump: ${findings.length} finding(s)`);
}

function writeAtomic(path, text) {
  const temp = `${path}.tmp-${process.pid}`;
  try {
    writeFileSync(temp, text);
    renameSync(temp, path);
  } catch (writeError) {
    try {
      unlinkSync(temp);
    } catch {
      // The temporary file may not exist; the original is untouched.
    }
    throw writeError;
  }
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

function writeSource(path, source) {
  writeAtomic(path, `${JSON.stringify(normalizeSource(source), null, 2)}\n`);
}

function sourceFacts(args) {
  return {
    schema: 1,
    id: required(args, "source"),
    url: required(args, "url"),
    license: required(args, "license"),
    copyright: required(args, "copyright"),
    artifacts: [],
  };
}

function commandCheck(args) {
  allow(args, ["store"]);
  const store = storeOf(args);
  const loaded = loadEntries(store, false);
  const findings = [...loaded.findings, ...collectFindings(loaded.entries)];
  if (findings.length > 0) {
    printFindings(findings);
    process.exit(1);
  }
  const artifacts = loaded.entries.reduce(
    (count, entry) => count + entry.source.artifacts.length,
    0,
  );
  console.log(
    `source-bump: clean across ${loaded.entries.length} source(s) and ${artifacts} artifact(s)`,
  );
}

function commandAdd(args) {
  allow(args, [
    "store",
    "source",
    "url",
    "license",
    "copyright",
    "local",
    "kind",
    "parent",
    "upstream",
    "origin",
    "base",
    "reason",
    "empty",
  ]);
  const store = storeOf(args);
  const id = required(args, "source");
  if (!isId(id)) usageError("--source must be a lowercase source id");

  const loaded = loadEntries(store, true);
  if (loaded.findings.length > 0) {
    printFindings(loaded.findings);
    process.exit(1);
  }
  const findings = collectFindings(loaded.entries);
  if (findings.length > 0) {
    printFindings(findings);
    process.exit(1);
  }

  const existing = loaded.entries.find((entry) => entry.source.id === id);
  let entry = existing;
  let source;

  if (args.empty) {
    if (existing) usageError(`source ${id} already exists`);
    if (args.local || args.kind || args.upstream || args.origin || args.base || args.parent) {
      usageError("--empty cannot carry an artifact");
    }
    if (args.reason === undefined) usageError("--empty requires --reason");
    source = sourceFacts(args);
    source.reason = required(args, "reason");
    entry = { file: `${id}.json`, path: join(store, `${id}.json`), source };
  } else {
    const local = required(args, "local");
    const kind = required(args, "kind");
    const upstream = required(args, "upstream");
    const origin = required(args, "origin");
    const base = required(args, "base");
    if (!KINDS.includes(kind)) usageError(`--kind must be one of ${KINDS.join(", ")}`);
    if (kind === "runbook" && args.parent === undefined) usageError("a runbook requires --parent");
    if (kind !== "runbook" && args.parent !== undefined) usageError("--parent is only valid for a runbook");
    if (args.reason !== undefined) usageError("--reason is only valid with --empty");

    const artifact = {
      local_path: local,
      kind,
      parent: args.parent ?? null,
      upstream_path: upstream,
      origin,
      base,
    };

    if (existing) {
      for (const field of ["url", "license", "copyright"]) {
        if (args[field] !== undefined) usageError(`source ${id} already exists; --${field} would change it`);
      }
      source = { ...existing.source, artifacts: [...existing.source.artifacts, artifact] };
      if (source.artifacts.length > 0) delete source.reason;
      entry = { ...existing, source };
    } else {
      source = sourceFacts(args);
      source.artifacts = [artifact];
      entry = { file: `${id}.json`, path: join(store, `${id}.json`), source };
    }
  }

  source = normalizeSource(source);
  entry = { ...entry, source };

  const next = existing
    ? loaded.entries.map((candidate) => (candidate.path === entry.path ? entry : candidate))
    : [...loaded.entries, entry];
  const nextFindings = collectFindings(next);
  if (nextFindings.length > 0) {
    printFindings(nextFindings);
    process.exit(1);
  }

  if (!existsSync(store)) mkdirSync(store, { recursive: true });
  writeSource(entry.path, source);
  if (args.empty) {
    console.log(`source-bump: created empty source ${id}`);
  } else {
    console.log(`source-bump: added ${required(args, "local")} to ${id}`);
  }
}

function resolveEdge(args) {
  const store = storeOf(args);
  const id = required(args, "source");
  const local = required(args, "local");
  const loaded = loadEntries(store, false);
  if (loaded.findings.length > 0) {
    printFindings(loaded.findings);
    process.exit(1);
  }
  const findings = collectFindings(loaded.entries);
  if (findings.length > 0) {
    printFindings(findings);
    process.exit(1);
  }
  const entry = loaded.entries.find((candidate) => candidate.source.id === id);
  if (!entry) error(`source ${id} has no tracking file`);
  const artifact = entry.source.artifacts.find((candidate) => candidate.local_path === local);
  if (!artifact) error(`source ${id} has no artifact ${local}`);
  return { store, id, local, entry, artifact, entries: loaded.entries };
}

function upstreamOf(args) {
  const upstream = resolve(required(args, "clone"));
  if (!existsSync(upstream) || !statSync(upstream).isDirectory()) {
    error(`--clone ${args.clone} is not a local directory`);
  }
  const check = spawnSync("git", ["-C", upstream, "rev-parse", "--git-dir"], {
    encoding: "utf8",
  });
  if (check.status !== 0) error(`--clone ${args.clone} is not a git repository`);
  return upstream;
}

function verifyCommit(upstream, commit, label) {
  const result = spawnSync("git", ["-C", upstream, "cat-file", "-e", `${commit}^{commit}`], {
    encoding: "utf8",
  });
  if (result.status !== 0) error(`upstream ${upstream} has no ${label} ${commit}`);
}

function verifyUpstreamPath(upstream, commit, artifact, label) {
  const path = `${commit}:${artifact.upstream_path}`;
  const result = spawnSync("git", ["-C", upstream, "cat-file", "-t", path], {
    encoding: "utf8",
  });
  if (result.status !== 0) {
    error(`upstream ${commit} has no ${artifact.upstream_path} at ${label}`);
  }
  const expected = isFileArtifact(artifact) ? "blob" : "tree";
  const actual = (result.stdout ?? "").trim();
  if (actual !== expected) {
    error(`upstream ${path} is ${actual}, expected ${expected} at ${label}`);
  }
}

function materialize(upstream, artifact, commit, dest) {
  if (isFileArtifact(artifact)) {
    const show = spawnSync("git", ["-C", upstream, "show", `${commit}:${artifact.upstream_path}`], {
      encoding: null,
      maxBuffer: MAX_BUFFER,
    });
    if (show.status !== 0) {
      throw new Error(`git show ${commit}:${artifact.upstream_path} failed`);
    }
    writeFileSync(join(dest, basename(artifact.local_path)), show.stdout);
    return;
  }

  const archive = spawnSync(
    "git",
    ["-C", upstream, "archive", "--format=tar", `${commit}:${artifact.upstream_path}`],
    { encoding: null, maxBuffer: MAX_BUFFER },
  );
  if (archive.status !== 0) {
    throw new Error(`git archive ${commit}:${artifact.upstream_path} failed`);
  }
  const extract = spawnSync("tar", ["-x", "-C", dest], { input: archive.stdout });
  if (extract.status !== 0) {
    throw new Error(`tar could not extract ${commit}:${artifact.upstream_path}`);
  }
}

function copyLocal(artifact, dest) {
  const local = resolve(ROOT, artifact.local_path);
  if (isFileArtifact(artifact)) {
    copyFileSync(local, join(dest, basename(artifact.local_path)));
  } else {
    cpSync(local, dest, { recursive: true });
  }
}

function buildBaseAndOurs(upstream, artifact) {
  const workspace = mkdtempSync(join(tmpdir(), "source-bump-"));
  try {
    const base = join(workspace, "base");
    const ours = join(workspace, "ours");
    mkdirSync(base);
    mkdirSync(ours);
    materialize(upstream, artifact, artifact.base, base);
    copyLocal(artifact, ours);
    return { workspace, base, ours };
  } catch (failure) {
    rmSync(workspace, { recursive: true, force: true });
    throw failure;
  }
}

function buildTheirs(workspace, upstream, artifact, revision) {
  const theirs = join(workspace, "theirs");
  try {
    mkdirSync(theirs);
    materialize(upstream, artifact, revision, theirs);
    return theirs;
  } catch (failure) {
    rmSync(theirs, { recursive: true, force: true });
    throw failure;
  }
}

function resolveBase(args) {
  const { artifact } = resolveEdge(args);
  const upstream = upstreamOf(args);
  verifyCommit(upstream, artifact.base, "base");
  verifyUpstreamPath(upstream, artifact.base, artifact, "base");
  return { artifact, upstream };
}

function commandDiff(args) {
  allow(args, ["store", "source", "local", "clone"]);
  const { artifact, upstream } = resolveBase(args);

  const workspace = buildBaseAndOurs(upstream, artifact);
  let failure = null;
  try {
    const result = spawnSync(
      "git",
      [
        "diff",
        "--no-index",
        "--no-ext-diff",
        "--no-textconv",
        "--src-prefix=a/",
        "--dst-prefix=b/",
        "--",
        "base",
        "ours",
      ],
      { cwd: workspace.workspace, encoding: "utf8", maxBuffer: MAX_BUFFER },
    );
    if (result.error) failure = `git diff failed: ${result.error.message}`;
    else if (result.status === 0) {
      console.log("source-bump: no local changes");
      return;
    } else if (result.status !== 1) failure = `git diff failed: ${(result.stderr ?? "").trim()}`;
    else process.stdout.write(result.stdout);
  } finally {
    rmSync(workspace.workspace, { recursive: true, force: true });
  }
  if (failure) error(failure);
}

function commandPrepare(args) {
  allow(args, ["store", "source", "local", "clone", "revision"]);
  const { artifact, upstream } = resolveBase(args);
  const revision = required(args, "revision");
  if (!isCommit(revision)) usageError("--revision must be a 40-character commit");
  if (revision === artifact.base) usageError("--revision must differ from the stored base");
  verifyCommit(upstream, revision, "revision");
  verifyUpstreamPath(upstream, revision, artifact, "revision");

  const workspace = buildBaseAndOurs(upstream, artifact);
  try {
    const theirs = buildTheirs(workspace.workspace, upstream, artifact, revision);
    console.log(`source-bump: prepared ${workspace.workspace}`);
    console.log(`  base: ${workspace.base}`);
    console.log(`  ours: ${workspace.ours}`);
    console.log(`  theirs: ${theirs}`);
  } catch (failure) {
    rmSync(workspace.workspace, { recursive: true, force: true });
    throw failure;
  }
}

function commandRecord(args) {
  allow(args, ["store", "source", "local", "base"]);
  const { entry, id, local, entries } = resolveEdge(args);
  const base = required(args, "base");

  const source = {
    ...entry.source,
    artifacts: entry.source.artifacts.map((candidate) =>
      candidate.local_path === local ? { ...candidate, base } : candidate,
    ),
  };
  const next = entries.map((candidate) =>
    candidate.path === entry.path ? { ...entry, source } : candidate,
  );
  const nextFindings = collectFindings(next);
  if (nextFindings.length > 0) {
    printFindings(nextFindings);
    process.exit(1);
  }

  writeSource(entry.path, source);
  console.log(`source-bump: moved ${local} base to ${base} in ${id}`);
}

const args = parseArgs(process.argv.slice(2));
if (args.help) {
  console.log(USAGE);
  process.exit(0);
}
if (args._.length === 0) usageError("a command is required");
if (args._.length > 1) usageError(`unexpected argument ${args._[1]}`);

try {
  switch (args._[0]) {
    case "check":
      commandCheck(args);
      break;
    case "add":
      commandAdd(args);
      break;
    case "diff":
      commandDiff(args);
      break;
    case "prepare":
      commandPrepare(args);
      break;
    case "record":
      commandRecord(args);
      break;
    default:
      usageError(`unknown command ${args._[0]}`);
  }
} catch (failure) {
  console.error(`source-bump: ${failure.message ?? failure}`);
  process.exit(1);
}
