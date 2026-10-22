// scripts/lint/reach.mjs
// Holds the two statements of the reach axis together: the roots
// `docs/reference/documentation_taxonomy.md` `## Reach` names by delivery route,
// and the roots `src/build/container-interface.json` mounts.
//
// Neither artifact copies the other's list. The taxonomy says which mount points
// the image uses and which folders it does not deliver, and the manifest says
// what it mounts. A root added to one and not the other is the drift this
// scanner refuses, and it derives both sides rather than holding a list.
//
// A folder the taxonomy names is classified by the manifest, not by the scanner:
// a folder under an image source is a shipped subtree and must exist on disk,
// and a folder under no image source is stated repository-only and must appear
// in no manifest path.
//
// Usage: node scripts/lint/reach.mjs [--manifest PATH] [--taxonomy PATH] [--root PATH]

import { readFileSync, existsSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
const args = process.argv.slice(2);
const argOf = (flag, fallback) => {
  const i = args.indexOf(flag);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};
const manifestPath = argOf("--manifest", resolve(REPO_ROOT, "src/build/container-interface.json"));
const taxonomyPath = argOf("--taxonomy", resolve(REPO_ROOT, "docs/reference/documentation_taxonomy.md"));
const root = resolve(argOf("--root", REPO_ROOT));

const findings = [];
const finding = (subject, message) => findings.push({ subject, message });

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
} catch (error) {
  console.error(`reach gate: cannot read ${manifestPath}: ${error.message}`);
  process.exit(1);
}

const imageRows = Array.isArray(manifest.image) ? manifest.image : [];
const destinations = imageRows
  .map((row) => row.destination)
  .filter((d) => typeof d === "string" && d.startsWith("/"));
const sources = imageRows
  .map((row) => row.source)
  .filter((s) => typeof s === "string" && !s.startsWith("/"))
  .map((s) => s.replace(/\/?$/, "/"));

const taxonomy = readFileSync(taxonomyPath, "utf8");
const sectionStart = taxonomy.search(/^## Reach$/m);
if (sectionStart < 0) {
  console.error(`reach gate: ${taxonomyPath} has no \`## Reach\` section`);
  process.exit(1);
}
const rest = taxonomy.slice(sectionStart + "## Reach".length);
const nextHeading = rest.search(/^## /m);
const section = nextHeading < 0 ? rest : rest.slice(0, nextHeading);

// A root is a code span ending in a slash. A template such as
// `.agents/skills/<name>/` is a form rather than a root, so it is skipped. The
// table's own two columns classify it: a row delivered by `nothing` states
// folders the manifest must not reach, and any other row states roots the
// manifest must deliver.
const spans = (text) => [...text.matchAll(/`([^`\n]+)`/g)].map((m) => m[1].trim()).filter((s) => s.endsWith("/") && !s.includes("<"));

const rows = section
  .split("\n")
  .filter((line) => line.trim().startsWith("|") && !/^\|[\s|:-]+\|$/.test(line.trim()))
  .map((line) => line.trim().replace(/^\||\|$/g, "").split("|").map((cell) => cell.trim()))
  .filter((cells) => cells.length >= 3);

const mountPoints = [...new Set(rows.flatMap((cells) => spans(cells[1] ?? "").filter((s) => s.startsWith("/"))))];
const repositoryOnly = [...new Set(rows.filter((cells) => /^nothing$/i.test(cells[0] ?? "")).flatMap((cells) => spans(cells[1] ?? "")))];
const delivered = [...new Set(rows.filter((cells) => !/^nothing$/i.test(cells[0] ?? "")).flatMap((cells) => spans(cells[1] ?? "").filter((s) => !s.startsWith("/"))))];

if (mountPoints.length === 0) finding("## Reach", "names no mount point, so no image route is stated");
if (repositoryOnly.length === 0) finding("## Reach", "states no repository-only folder, so the hand route is unstated");

// 1. Every root the manifest mounts is one the taxonomy states a route to.
for (const destination of destinations) {
  if (!mountPoints.some((mount) => destination.startsWith(mount))) {
    finding(destination, "the manifest mounts it and `## Reach` states no route to a root that covers it");
  }
}

// 2. Every mount point the taxonomy names carries something.
for (const mount of mountPoints) {
  if (!destinations.some((destination) => destination.startsWith(mount))) {
    finding(mount, "`## Reach` names it and the manifest mounts nothing there");
  }
}

// 3. A folder the taxonomy states repository-only is reached by no manifest path.
const shippedPaths = [...destinations, ...sources];
for (const folder of repositoryOnly) {
  const shipped = shippedPaths.find((path) => path.startsWith(folder) || folder.startsWith(path));
  if (shipped) {
    finding(folder, `\`## Reach\` states it is repository-only and the manifest reaches it through ${shipped}`);
  }
}

// 4. A folder the taxonomy states delivered exists in the tree.
for (const folder of delivered) {
  if (!existsSync(resolve(root, folder)) || !statSync(resolve(root, folder)).isDirectory()) {
    finding(folder, "`## Reach` names it as a delivered folder and the tree has no such directory");
  }
}

const folderCount = repositoryOnly.length + delivered.length;
const report = (line) => console.log(line);
report(`## Reach, ${mountPoints.length} mount point(s) and ${folderCount} folder(s) named`);
report(`## The manifest, ${destinations.length} mount destination(s)`);
for (const f of findings) report(`${f.subject}: ${f.message}`);
report(
  findings.length === 0
    ? `reach: clean across ${mountPoints.length} mount point(s) and ${folderCount} folder(s)`
    : `reach: ${findings.length} finding(s)`,
);
process.exit(findings.length === 0 ? 0 : 1);
