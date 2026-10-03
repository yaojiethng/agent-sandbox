// Extension compatibility probe for a pi version bump.
//
// The two extensions under src/reasoning/providers/pi/config/agent/extensions/
// import from pi and from pi-ai. A bump can remove one of those names and the
// extension then fails at load, inside a container, at startup, with a stack
// that points at the extension rather than at the bump. The bump skill's own
// checklist did not look at them, so this probe is what the skill runs instead.
//
// The required surface is read out of the extension sources rather than listed
// here, so an extension that starts importing a new name is covered without
// anyone editing this file. A hand-maintained list is a list that rots.
//
// Usage:
//   node scripts/lint/pi-extension-compat.mjs                    # installed pi
//   node scripts/lint/pi-extension-compat.mjs --target 0.99.2    # a candidate
//
// Exit codes: 0 = every imported name is present, 1 = a name is missing or the
// probe could not run. The finding count is printed, never encoded in the exit
// code.

import { readFileSync, readdirSync, statSync, existsSync, mkdirSync, rmSync } from "fs";
import { join, dirname, resolve } from "path";
import { execFileSync } from "child_process";
import { fileURLToPath } from "url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const EXTENSIONS_DIR = join(REPO_ROOT, "src/reasoning/providers/pi/config/agent/extensions");
const PKG = "@earendil-works/pi-coding-agent";
const AI_PKG = "@earendil-works/pi-ai";

function arg(name) {
  const at = process.argv.indexOf(name);
  return at === -1 ? undefined : process.argv[at + 1];
}

/** The pi install root for a version: the installed one, or a fetched copy. */
function resolveTarget() {
  const target = arg("--target");
  if (!target) {
    const entry = "/usr/local/lib/node_modules/@earendil-works/pi-coding-agent/package.json";
    if (!existsSync(entry)) {
      fail("the installed pi is not at /usr/local/lib/node_modules");
    }
    return { nodeModules: "/usr/local/lib/node_modules", label: "installed" };
  }
  const root = join("/tmp", `pi-compat-${target}`);
  if (!existsSync(join(root, "node_modules", PKG, "package.json"))) {
    mkdirSync(root, { recursive: true });
    try {
      execFileSync("npm", ["install", "--silent", "--no-audit", "--no-fund", "--prefix", root, `${PKG}@${target}`, `${AI_PKG}@${target}`], {
        stdio: "ignore",
      });
    } catch {
      rmSync(root, { recursive: true, force: true });
      fail(`npm could not install ${PKG}@${target}`);
    }
  }
  return { nodeModules: join(root, "node_modules"), label: `${PKG}@${target}` };
}

function fail(message) {
  console.error(`Pi extension compat: ${message}`);
  process.exit(1);
}

/** Every named import the extensions take from pi or pi-ai. */
function requiredSurface() {
  const found = new Map();
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.name.endsWith(".ts")) {
        const text = readFileSync(full, "utf8");
        // `type` binds per specifier, not to the statement: a line can carry a
        // value and two types at once. A type-only specifier is erased before
        // the module runs, so a type that moves is a compile-time break and not
        // a load-time one. Both are checked and the two are told apart below.
        for (const m of text.matchAll(/import\s+\{([^}]*)\}\s+from\s+"([^"]+)"/g)) {
          for (const raw of m[1].split(",")) {
            const spec = raw.trim();
            if (!spec) continue;
            const isTypeOnly = spec.startsWith("type ") || m[0].startsWith("import type ");
            const name = spec.replace(/^type\s+/, "").trim().split(/\s+as\s+/)[0].trim();
            if (!name) continue;
            if (!found.has(m[2])) found.set(m[2], new Set());
            found.get(m[2]).add(`${name}${isTypeOnly ? " (type)" : ""}`);
          }
        }
      }
    }
  };
  walk(EXTENSIONS_DIR);
  return found;
}

/** The runtime export names of a package entry, or null when it will not load. */
async function runtimeExports(entry) {
  try {
    return new Set(Object.keys(await import(entry)));
  } catch {
    return null;
  }
}

/** The names a package's .d.ts files declare, across its whole tree. */
function declaredTypes(packageRoot) {
  const names = new Set();
  const walk = (dir) => {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      const full = join(dir, entry.name);
      if (entry.isDirectory()) walk(full);
      else if (entry.name.endsWith(".d.ts")) names.add(readFileSync(full, "utf8"));
    }
  };
  if (existsSync(packageRoot)) walk(packageRoot);
  return names;
}

/** The pi-ai package root, which is nested under pi on a global install. */
function findAiRoot(nodeModules) {
  const candidates = [
    join(nodeModules, AI_PKG),
    join(nodeModules, PKG, "node_modules", AI_PKG),
  ];
  for (const dir of candidates) if (existsSync(dir)) return dir;
  return null;
}

const { nodeModules, label } = resolveTarget();
const surface = requiredSurface();
const piEntry = join(nodeModules, PKG, "dist/index.js");
const piTypes = declaredTypes(join(nodeModules, PKG, "dist"));
const aiRoot = findAiRoot(nodeModules);
const aiTypes = declaredTypes(aiRoot === null ? "" : join(aiRoot, "dist"));

if (aiRoot === null || aiTypes.size === 0) {
  fail(`${AI_PKG} is not installed under ${nodeModules}; the pi-ai surface cannot be checked`);
}

const runtime = await runtimeExports(piEntry);
if (runtime === null) {
  fail(`${piEntry} could not be loaded; the runtime surface cannot be checked`);}

const missing = [];
const checked = [];

for (const [specifier, names] of [...surface].sort()) {
  const isAi = specifier === AI_PKG || specifier.startsWith(`${AI_PKG}/`);
  const isPi = specifier === PKG;
  if (!isAi && !isPi) continue; // A relative import is this repository's own code.

  const types = isAi ? aiTypes : piTypes;
  for (const entry of names) {
    const isType = entry.endsWith(" (type)");
    const name = isType ? entry.slice(0, -7) : entry;
    checked.push(`${specifier} ${name}${isType ? " (type)" : ""}`);

    if (isType) {
      // A type is declared somewhere in the package's .d.ts, or reachable as a
      // member of a declared one. The member test is what catches a field
      // removed from a context interface, which is the break that hurts most.
      const asMember = [...types].some((t) => t.includes(name) || new RegExp(`\\b${name}\\b`).test(t));
      if (!asMember) missing.push(`${specifier} ${name} (type)`);
      continue;
    }
    if (isPi && !runtime.has(name)) {
      missing.push(`${specifier} ${name} (runtime export)`);
    }
  }
}

for (const m of missing) console.log(`MISSING  ${m}`);
console.log(
  missing.length === 0
    ? `Pi extension compat: clean against ${label}; ${checked.length} imported name(s) checked`
    : `Blocking: ${missing.length} of ${checked.length} imported name(s) absent from ${label}`,
);
process.exit(missing.length === 0 ? 0 : 1);
