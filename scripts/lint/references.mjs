// scripts/lint/references.mjs
// Every reference a declared file makes resolves where its reader is.
//
// Two rules, each decidable from the tree with no judgement:
//
//   1. A skill invocation names a skill the tree provides. The form is a
//      backticked token adjacent to the word "skill", on either side. The form
//      is broad on purpose: a sentence naming an absent skill reports something
//      broken whether it reads as an instruction or as a remark, so it fails
//      closed. `poteto-mode` and the upstream `codebase-design` were both found
//      this way.
//   2. An absolute path in a backticked token lands inside a root the manifest
//      declares. The roots are derived from the manifest, never listed here:
//      every `image` destination, the provisioning template and home, every
//      mount target, every `env` value that is a path, and every `session` path.
//      A token may also be an ancestor of a root, so `/opt/sandbox/docs/` passes
//      while `/etc/passwd` does not.
//
// A repository-relative mention is not checked. It is not broken when read: the
// session's working directory is the project root, so the token resolves for the
// reader that has it. The rule for links from a shipped file is the same rule,
// and `scripts/lint/linking.mjs` applies it in the path space the file is read.
//
// The corpus is two derived sets, not a list. The files are every Markdown file
// under a cell's `sources`, read by a directory walk rather than from
// `git ls-files`, because a file added in the same commit must count. The skill
// names are every `*/SKILL.md` directory under a cell whose runtime path is a
// skill root.
//
// Fenced code blocks are skipped: a block quotes a document rather than making a
// reference from it.
//
// Usage: node scripts/lint/references.mjs [--root PATH] [--manifest PATH]
// Exit:  0 = no findings, 1 = a finding or the manifest could not be read.

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const root = resolve(argOf("--root", REPO_ROOT));
const manifestPath = resolve(argOf("--manifest", join(root, "src/build/container-interface.json")));

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`references: cannot read ${manifestPath}: ${error.message}`);
  process.exit(1);
}

const rows = (key) => (Array.isArray(manifest[key]) ? manifest[key] : []);
const cells = rows("cells");
const findings = [];

// walk DIRECTORY -- every file under it, in a stable order. A missing directory
// yields nothing rather than an error: the cells are declared for the image, and
// a fixture may declare a folder it does not carry.
function walk(directory, out = []) {
  const absolute = join(root, directory);
  if (!existsSync(absolute) || !statSync(absolute).isDirectory()) return out;
  for (const entry of readdirSync(absolute, { withFileTypes: true }).sort((a, b) => (a.name < b.name ? -1 : 1))) {
    const child = join(directory, entry.name);
    if (entry.isDirectory()) walk(child, out);
    else out.push(child);
  }
  return out;
}

// The files a cell declares, Markdown only: the reference rules are about prose.
const files = [...new Set(cells.flatMap((cell) => cell.sources || []).flatMap((source) => walk(source)))].filter(
  (file) => file.endsWith(".md"),
);

// The skill corpus: every directory carrying a `SKILL.md`, found by walking the
// tree. It is not derived from the cells: a project-scope skill loads from the
// working tree rather than from an image root, and `pi` discovers it there, so a
// cell-declared corpus would report every project-scope name as absent.
const SKIP = new Set([".git", "node_modules", ".scratchpad"]);
function skillDirs(directory, out = []) {
  const absolute = join(root, directory);
  if (!existsSync(absolute) || !statSync(absolute).isDirectory()) return out;
  for (const entry of readdirSync(absolute, { withFileTypes: true })) {
    if (!entry.isDirectory() || SKIP.has(entry.name)) continue;
    const child = join(directory, entry.name);
    if (existsSync(join(root, child, "SKILL.md"))) out.push(entry.name);
    skillDirs(child, out);
  }
  return out;
}
const skillNames = new Set(skillDirs("."));

// The declared roots, derived from the manifest. `$AGENT_HOME` is a variable, so
// it is also expanded with each provider's home: a file may write either form.
const homes = rows("env")
  .filter((row) => row.name === "AGENT_HOME" && typeof row.value === "string")
  .map((row) => row.value);
const roots = [
  ...rows("image").map((row) => row.destination),
  ...rows("provision").flatMap((row) => [row.template, row.home]),
  ...rows("mounts").map((row) => row.target),
  ...rows("env").map((row) => row.value),
  ...rows("session").map((row) => row.path),
]
  .filter((path) => typeof path === "string" && (path.startsWith("/") || path.startsWith("$AGENT_HOME/")))
  .flatMap((path) => [path, ...homes.map((home) => path.replace(/^\$AGENT_HOME/, home))]);

// The zones the manifest works in, derived as the two leading segments of every
// declared root: `/opt/sandbox/lib/` contributes `/opt/sandbox`, and
// `$AGENT_HOME/` contributes itself. A path outside every zone is not this
// rule's subject: `/dev/null`, `/bin/sh` and an API endpoint are not zones the
// image builds, so nothing here can be wrong about them.
const zones = [
  ...new Set(
    roots
      .map((declaredRoot) => (declaredRoot.startsWith("$AGENT_HOME/") ? declaredRoot : declaredRoot.split("/").slice(0, 3).join("/") + "/"))
      .filter((zone) => zone !== "/"),
  ),
];
const inZone = (token) => zones.some((zone) => token.startsWith(zone));
// A token is reachable when it is a declared root, sits inside one, or is an
// ancestor of one. The last case is what lets a document name `/opt/sandbox/docs/`
// rather than a file beneath it.
const declared = (token) =>
  roots.some((declaredRoot) => token.startsWith(declaredRoot) || declaredRoot.startsWith(token));

const INVOCATION = /`([a-z0-9][a-z0-9-]{2,})`\s+skill\b|skill\s+`([a-z0-9][a-z0-9-]{2,})`/g;
const CODE_SPAN = /`([^`\n]+)`/g;

for (const file of files) {
  let inFence = false;
  readFileSync(join(root, file), "utf8")
    .split("\n")
    .forEach((line, index) => {
      if (/^[ \t]*(```|~~~)/.test(line)) {
        inFence = !inFence;
        return;
      }
      if (inFence) return;
      const where = `${file}:${index + 1}`;

      for (const match of line.matchAll(INVOCATION)) {
        const name = match[1] || match[2];
        if (!skillNames.has(name)) {
          findings.push(`${where}: names \`${name}\` as a skill, and no \`*/SKILL.md\` in the tree provides it`);
        }
      }

      for (const match of line.matchAll(CODE_SPAN)) {
        const token = match[1].trim().split(/\s+/)[0];
        if (token.length < 2 || !(token.startsWith("/") || token.startsWith("$AGENT_HOME/"))) continue;
        // A one-segment absolute token is a command name (`/iter`, `/reload`),
        // not a path: it carries no slash beyond the one that introduces it.
        if (/^\/[a-z0-9][a-z0-9-]*$/.test(token)) continue;
        if (!inZone(token)) continue;
        if (!declared(token)) {
          findings.push(`${where}: names '${token}', inside a zone the manifest declares and under no root it names`);
        }
      }
    });
}

const report = (line) => console.log(line);
report(
  `## ${files.length} declared file(s), ${skillNames.size} skill name(s), ${roots.length} declared root(s) in ${zones.length} zone(s)`,
);
for (const finding of findings) report(finding);
report(
  findings.length === 0
    ? `references: clean across ${files.length} file(s) and ${skillNames.size} skill name(s)`
    : `references: ${findings.length} finding(s)`,
);
process.exit(findings.length === 0 ? 0 : 1);
