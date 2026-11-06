// The source-bump tracking store.
//
// The store is one JSON file per upstream source at
// `.agents/registry/sources/<source-id>.json`. A source file holds the source
// facts and the artifact edges; it holds no hashes, no patch and no adaptation
// prose. `origin` is the revision the artifact was first taken from, and
// `base` is the upstream revision the next merge reviews.
//
// The store is edited by hand and held valid by the gate
// (`scripts/lint/skill_sources.mjs`), through the validator in `skill_store.mjs`.
// merge agent writes the local artifact and the design doc.
//
// Commands:
//   check   -- validate every source file and every edge; writes nothing
//   format  -- rewrite every source file in canonical form; sets no field value
//   diff    -- print the stored base -> local change from a local clone
//   prepare -- create a temporary base/ours/theirs workspace for the merge
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
  renameSync,
  rmSync,
  statSync,
  unlinkSync,
  writeFileSync,
} from "fs";
import { spawnSync } from "child_process";
import { tmpdir } from "os";
import { basename, dirname, join, resolve } from "path";
import { fileURLToPath } from "url";

import {
  STORE_REL,
  canonicalText,
  collectFindings,
  isCommit,
  isFileArtifact,
  isId,
  readStore,
} from "./skill_store.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const ROOT = process.env.SOURCE_BUMP_ROOT
  ? resolve(process.env.SOURCE_BUMP_ROOT)
  : MODULE_ROOT;
const DEFAULT_STORE = process.env.SOURCE_BUMP_STORE
  ? resolve(process.env.SOURCE_BUMP_STORE)
  : join(ROOT, STORE_REL);

const MAX_BUFFER = 64 * 1024 * 1024;

const USAGE = `Usage:
  source-bump check [--store <dir>]
  source-bump format [--store <dir>]
  source-bump diff --source <id> --local <path> --clone <dir> [--store <dir>]
  source-bump prepare --source <id> --local <path> --clone <dir> \\
    --revision <commit> [--store <dir>]
  source-bump --help

The store is one JSON file per source at .agents/registry/sources/<id>.json.
The store is edited by hand; the gate validates it and format canonicalises it.
diff and prepare read a local clone and never fetch.`;

function usageError(message) {
  console.error(`source-bump: ${message}`);
  console.error(USAGE);
  process.exit(2);
}

function error(message) {
  console.error(`source-bump: ${message}`);
  process.exit(1);
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

const loadEntries = (store, allowMissing) => readStore(store, { allowMissing });

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

function commandCheck(args) {
  allow(args, ["store"]);
  const store = storeOf(args);
  const loaded = loadEntries(store, false);
  const findings = [...loaded.findings, ...collectFindings(loaded.entries, { root: ROOT })];
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

function resolveEdge(args) {
  const store = storeOf(args);
  const id = required(args, "source");
  const local = required(args, "local");
  const loaded = loadEntries(store, false);
  if (loaded.findings.length > 0) {
    printFindings(loaded.findings);
    process.exit(1);
  }
  const findings = collectFindings(loaded.entries, { root: ROOT });
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

function commandFormat(args) {
  allow(args, ["store"]);
  const store = storeOf(args);
  const loaded = loadEntries(store, false);
  if (loaded.findings.length > 0) {
    printFindings(loaded.findings);
    process.exit(1);
  }
  const findings = collectFindings(loaded.entries, { root: ROOT, form: false });
  if (findings.length > 0) {
    printFindings(findings);
    process.exit(1);
  }
  let written = 0;
  for (const entry of loaded.entries) {
    const text = canonicalText(entry.source);
    if (readFileSync(entry.path, "utf8") === text) continue;
    writeAtomic(entry.path, text);
    written += 1;
  }
  console.log(`source-bump: formatted ${written} source file(s) in ${store}`);
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
    case "format":
      commandFormat(args);
      break;
    case "diff":
      commandDiff(args);
      break;
    case "prepare":
      commandPrepare(args);
      break;
    default:
      usageError(`unknown command ${args._[0]}`);
  }
} catch (failure) {
  console.error(`source-bump: ${failure.message ?? failure}`);
  process.exit(1);
}
