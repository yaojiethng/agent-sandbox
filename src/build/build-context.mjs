// src/build/build-context.mjs
// The build context check: the context is the union of the manifest's declared
// sources and every Dockerfile's COPY sources, and .dockerignore is the
// complement. The dockerfiles and the ignore file always travel to the builder,
// even when a pattern matches them.
//
// The COPY sources are read because more than one build shares the repository
// root as context: a path the reasoning images never copy is still an input to
// the capability image, and the ignore file governs both.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { MANIFEST_REL, load_manifest } from "./container-interface.mjs";

const IGNORE_REL = ".dockerignore";
const GLOB = /[*?[\]]/;
const DOCKERFILE = /(^|\/)(dockerfile|[^/]+\.dockerfile)$/;

function strip(pattern) {
  return pattern.endsWith("/") ? pattern.slice(0, -1) : pattern;
}

export function ignore_patterns(root) {
  try {
    return readFileSync(join(root, IGNORE_REL), "utf8")
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line && !line.startsWith("#"));
  } catch {
    return null;
  }
}

export function is_ignored(rel, patterns) {
  let ignored = false;
  for (const raw of patterns) {
    const negated = raw.startsWith("!");
    const pattern = strip((negated ? raw.slice(1) : raw).replace(/^\//, ""));
    if (GLOB.test(pattern)) continue;
    if (rel === pattern || rel.startsWith(pattern + "/")) ignored = !negated;
  }
  return ignored;
}

// source_roots -- every path the context must carry. The `image` layer is what
// lands in an image; the `build` layer is what the build reads and no image
// copies. The context owns both, because the builder needs both.
export function source_roots(manifest) {
  const roots = [];
  for (const layer of ["image", "build"]) {
    const rows = Array.isArray(manifest?.[layer]) ? manifest[layer] : [];
    for (const row of rows) roots.push(strip(String(row.source || "")));
  }
  return [...new Set(roots.filter(Boolean))];
}

// dockerfile_sources -- the context paths the given Dockerfiles read. A
// `COPY --from=` and an absolute or remote source read another stage or the
// network, not the context. `.` would claim the whole tree, so it is skipped
// rather than silently owning everything.
export function dockerfile_sources(root, files) {
  const found = [];
  for (const rel of files) {
    if (!DOCKERFILE.test(rel)) continue;
    let text;
    try {
      text = readFileSync(join(root, rel), "utf8");
    } catch {
      continue;
    }
    for (const line of text.split("\n")) {
      const match = line.trim().match(/^(COPY|ADD)\s+(.+)$/i);
      if (!match) continue;
      const args = match[2]
        .replace(/\\$/, "")
        .trim()
        .split(/\s+/)
        .filter((arg) => !arg.startsWith("--"));
      for (const arg of args.slice(0, -1)) {
        if (arg === "." || arg.startsWith("/") || /^[a-z]+:\/\//i.test(arg)) continue;
        found.push({ dockerfile: rel, source: strip(arg.replace(/^\.\//, "")) });
      }
    }
  }
  return found;
}

export function walk(root) {
  const files = [];
  (function visit(dir) {
    for (const entry of readdirSync(dir, { withFileTypes: true })) {
      if (dir === root && entry.name === ".git") continue;
      const abs = join(dir, entry.name);
      if (entry.isDirectory()) visit(abs);
      else files.push(relative(root, abs));
    }
  })(root);
  return files;
}

function owns(rel, sources) {
  return sources.some((source) => rel === source || rel.startsWith(source + "/"));
}

export function check(root) {
  const findings = [];
  const manifest = load_manifest(root);
  if (!manifest) {
    findings.push(`the manifest ${MANIFEST_REL} is missing or does not parse`);
    return { findings, files: 0, bytes: 0 };
  }
  const patterns = ignore_patterns(root);
  if (patterns === null) {
    findings.push(`the ignore file ${IGNORE_REL} is missing; the whole tree is the context`);
    return { findings, files: 0, bytes: 0 };
  }
  for (const raw of patterns) {
    const pattern = raw.startsWith("!") ? raw.slice(1) : raw;
    if (GLOB.test(pattern)) findings.push(`the ignore pattern ${raw} is not a path prefix; the gate cannot evaluate it`);
  }
  const files = walk(root);
  const copies = dockerfile_sources(root, files);
  const sources = [...new Set([...source_roots(manifest), ...copies.map((copy) => copy.source)])];
  if (sources.length === 0) findings.push("the manifest declares no image source");

  let included = 0;
  let bytes = 0;
  for (const rel of files) {
    const always = DOCKERFILE.test(rel) || rel === IGNORE_REL;
    if (!always && is_ignored(rel, patterns)) continue;
    if (!always && !owns(rel, sources)) findings.push(`the context includes ${rel}, which no manifest source owns`);
    included += 1;
    bytes += statSync(join(root, rel)).size;
  }
  const present = (source) =>
    files.some((rel) => (rel === source || rel.startsWith(source + "/")) && !is_ignored(rel, patterns));
  for (const source of source_roots(manifest)) {
    if (!present(source)) findings.push(`the context excludes the manifest source ${source}`);
  }
  for (const copy of copies) {
    if (!present(copy.source)) findings.push(`the context excludes ${copy.source}, which ${copy.dockerfile} copies`);
  }
  return { findings, files: included, bytes };
}

export function main(argv) {
  let root = process.cwd();
  let command = "";
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--root") {
      root = argv[i + 1];
      i += 1;
    } else if (!command) {
      command = argv[i];
    }
  }
  if (command !== "check") {
    process.stderr.write("usage: build-context.mjs check [--root DIR]\n");
    return 2;
  }
  const result = check(root);
  for (const finding of result.findings) process.stdout.write(`Finding: ${finding}\n`);
  process.stdout.write(`Context: ${result.files} files, ${result.bytes} bytes\n`);
  return result.findings.length === 0 ? 0 : 1;
}

if (process.argv[1] && process.argv[1].endsWith("build-context.mjs")) {
  process.exit(main(process.argv.slice(2)));
}
