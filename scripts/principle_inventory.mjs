#!/usr/bin/env node
// scripts/principle_inventory.mjs
//
// The principle inventory: what each principle declares as its nearest
// principles, and which principles its prose already points at.
//
// The design record is devlog/discussions/20261114-design-concluded-principle_corpus_admission.md.
// This is the lever, not the gate: it reports structural facts and exits zero,
// so it can run before the corpus is complete. The gate row imports inventory()
// and decides whether a finding fails.
//
// Usage:
//   node scripts/principle_inventory.mjs [--root DIR] [--json]
//
// A principle is a skill under the provider root whose name starts with
// `principle-` or `<type>-principle-`. The root is the repository by
// default, so a caller from any directory reads the same corpus.

import { existsSync, readFileSync, statSync } from "node:fs";
import { basename, dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import { discoverSkillDirs, inside, markdownFiles, markdownLinks } from "./skill_layers.mjs";
import { loadPiFrontmatter } from "./lint/pi-frontmatter.mjs";

const REPO = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const SKILLS = join("src", "reasoning", "agent-runtime", "pi", "config", "agent", "skills");
const PRINCIPLE = /^(?:[a-z][a-z0-9]*-)?principle-/;
const LINK_OUTSIDE = /^(?:[a-z][a-z0-9+.-]*:|\/|#|\$)/i;

function isDirectory(path) {
  try {
    return statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function isFile(path) {
  try {
    return statSync(path).isFile();
  } catch {
    return false;
  }
}

/** The declared neighbours, or a state and a finding for a malformed value. */
function readNeighbours(frontmatter, skill, findings) {
  const metadata = frontmatter.metadata;
  if (!metadata || !Object.prototype.hasOwnProperty.call(metadata, "neighbours")) {
    return { state: "missing", neighbours: [] };
  }
  const value = metadata.neighbours;
  if (!Array.isArray(value)) {
    findings.push({
      skill,
      kind: "malformed-neighbours",
      detail: "metadata.neighbours is not a list",
    });
    return { state: "malformed", neighbours: [] };
  }
  if (value.length === 0) return { state: "empty", neighbours: [] };
  const neighbours = [];
  for (const entry of value) {
    if (typeof entry !== "string" || entry.trim() === "") {
      findings.push({
        skill,
        kind: "malformed-neighbours",
        detail: "metadata.neighbours carries a non-string entry",
      });
      continue;
    }
    neighbours.push(entry.trim());
  }
  return { state: neighbours.length === 0 ? "empty" : "declared", neighbours };
}

/** The other frontmatter fields the principle gate reads, as declared. */
function readDeclaration(frontmatter) {
  const metadata = frontmatter.metadata;
  const field = (key) => (metadata && typeof metadata === "object" ? metadata[key] : undefined);
  return {
    declaredName: frontmatter.name,
    description: frontmatter.description,
    leitwort: field("leitwort"),
    intent: field("intent"),
    mechanism: field("mechanism"),
    disableModelInvocation: frontmatter["disable-model-invocation"],
  };
}

/** Every principle a skill's Markdown links to, deduplicated and sorted. */
function crossLinks(skillDir, principleDirs) {
  const names = new Set();
  for (const file of markdownFiles(skillDir)) {
    for (const link of markdownLinks(file)) {
      if (!link.target || LINK_OUTSIDE.test(link.target)) continue;
      const target = resolve(dirname(file), link.target);
      for (const [name, dir] of principleDirs) {
        if (name === basename(skillDir)) continue;
        if (inside(target, dir)) {
          names.add(name);
          break;
        }
      }
    }
  }
  return [...names].sort();
}

function compareFindings(a, b) {
  return (
    a.skill.localeCompare(b.skill) ||
    a.kind.localeCompare(b.kind) ||
    a.detail.localeCompare(b.detail)
  );
}

/**
 * Read the principle corpus under `root`. `parseFrontmatter` is pi's own
 * parser, so the lever reads the block a skill loader reads. Throws when the
 * skills root is unreadable, because that is a failed run, not an empty corpus.
 */
export function inventory(root = REPO, parseFrontmatter) {
  if (typeof parseFrontmatter !== "function") {
    throw new Error("inventory(root, parseFrontmatter) needs pi's frontmatter parser");
  }
  const skillsRoot = join(resolve(root), SKILLS);
  if (!isDirectory(skillsRoot)) {
    throw new Error(`no skills root at ${relative(process.cwd(), skillsRoot) || skillsRoot}`);
  }

  const dirs = discoverSkillDirs(skillsRoot)
    .filter((dir) => PRINCIPLE.test(basename(dir)))
    .sort((a, b) => basename(a).localeCompare(basename(b)));
  const principleDirs = dirs.map((dir) => [basename(dir), dir]);
  const principleNames = new Set(principleDirs.map(([name]) => name));
  const findings = [];
  const principles = [];

  for (const [name, dir] of principleDirs) {
    const skillFile = join(dir, "SKILL.md");
    if (!isFile(skillFile)) {
      findings.push({ skill: name, kind: "missing-skill-file", detail: "SKILL.md is absent" });
      continue;
    }
    const frontmatter = parseFrontmatter(readFileSync(skillFile, "utf8")).frontmatter || {};
    const { state, neighbours } = readNeighbours(frontmatter, name, findings);

    if (state === "missing") {
      findings.push({
        skill: name,
        kind: "missing-field",
        detail: "metadata.neighbours is absent",
      });
    }

    const seen = new Set();
    for (const neighbour of neighbours) {
      if (seen.has(neighbour)) {
        findings.push({
          skill: name,
          kind: "duplicate-neighbour",
          detail: `${neighbour} is declared more than once`,
        });
      }
      seen.add(neighbour);
      if (neighbour === name) {
        findings.push({
          skill: name,
          kind: "self-neighbour",
          detail: `${name} names itself`,
        });
      } else if (!principleNames.has(neighbour)) {
        findings.push({
          skill: name,
          kind: "unresolved-neighbour",
          detail: `${neighbour} is not a principle in the provider root`,
        });
      }
    }

    principles.push({
      name,
      state,
      neighbours,
      ...readDeclaration(frontmatter),
      crossLinks: crossLinks(dir, principleDirs),
    });
  }

  findings.sort(compareFindings);
  return { principles, findings };
}

function printPlain(result) {
  const findings = result.findings.length;
  console.log(
    `principle-inventory: ${result.principles.length} principle(s), ${findings} finding(s)`,
  );
  for (const principle of result.principles) {
    console.log(`principle ${principle.name}`);
    const declared =
      principle.state === "declared"
        ? principle.neighbours.join(", ")
        : principle.state === "missing"
          ? "undeclared"
          : principle.state === "empty"
            ? "[]"
            : "malformed";
    console.log(`  neighbours: ${declared}`);
    if (principle.crossLinks.length > 0) {
      console.log(`  cross-links: ${principle.crossLinks.join(", ")}`);
    }
  }
  for (const finding of result.findings) {
    console.log(`finding: ${finding.skill} ${finding.kind} -- ${finding.detail}`);
  }
}

async function main(argv) {
  let root = REPO;
  let json = false;

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--root") {
      root = resolve(argv[++i] || "");
    } else if (arg === "--json") {
      json = true;
    } else if (arg === "--help" || arg === "-h") {
      console.log("usage: node scripts/principle_inventory.mjs [--root DIR] [--json]");
      return 0;
    } else {
      console.error(`principle inventory: unknown argument '${arg}'`);
      return 2;
    }
  }

  const { parseFrontmatter } = await loadPiFrontmatter("Principle inventory");

  let result;
  try {
    result = inventory(root, parseFrontmatter);
  } catch (error) {
    console.error(`principle inventory: ${error.message}`);
    return 2;
  }

  if (json) console.log(JSON.stringify(result, null, 2));
  else printPlain(result);
  return 0;
}

// Only run when invoked, so the next row's gate can import inventory() without
// the module reading process.argv or printing.
if (process.argv[1] && resolve(process.argv[1]) === resolve(fileURLToPath(import.meta.url))) {
  process.exitCode = await main(process.argv.slice(2));
}

// Exported for the CLI and for a caller that has already loaded pi's parser.
export { REPO, SKILLS };
