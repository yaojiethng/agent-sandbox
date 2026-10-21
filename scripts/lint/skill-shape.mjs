// The principle corpus carries one shape.
//
// Enforces docs/development/prompt-authoring-conventions.md `## The principle
// shape` and the decision in docs/adr/principle_skill_shape.md: every skill whose
// name carries `principle-` opens on a sentence-case title, states its judgement
// in one sentence, and then carries `**The pattern.**`, `**Why.**`, any
// `**Where ... .**` parts, and `**The test.**`, in that order. The title is the
// file's only heading.
//
// The subject is derived from the name, never listed: a new principle enters the
// gate the day its directory exists. A skill whose subject is a procedure rather
// than a judgement keeps the runbook shape and does not carry the segment.
//
// The gate exists because the corpus held two shapes for the same parts. A
// statement with no observer is a model, and the drift returned once already; see
// docs/adr/policy_declarative_framing.md for that test.
//
// Test seam: SKILL_SHAPE_SCAN_ROOT points the scan at a fixture root that
// mirrors the repository layout, while the declaration is always read from the
// module root, so a fixture tree is scanned against the real declaration.
//
// Exit codes: 0 = every principle carries the shape, 1 = a finding or the gate
// could not run. The finding count is printed, never encoded in the exit code.

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { load_manifest, manifest_rows } from "../../src/build/container-interface.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const REPO_ROOT = process.env.SKILL_SHAPE_SCAN_ROOT
  ? resolve(process.env.SKILL_SHAPE_SCAN_ROOT)
  : MODULE_ROOT;

// A principle is named by its directory, so the name is the whole declaration of
// what this gate reads. `.agents/skills` is the project's own convention tree,
// which ships nowhere and so is declared by no cell.
const NAME_SEGMENT = "principle-";
const EXTRA_SKILL_ROOT = ".agents/skills";

const manifest = load_manifest(MODULE_ROOT);
if (manifest === undefined) {
  console.error(
    "skill shape: " + join(MODULE_ROOT, "src/build/container-interface.json") +
      " is missing or does not parse; cannot derive the skill roots.",
  );
  process.exit(1);
}

const ROOTS = [
  ...new Set([
    ...manifest_rows(manifest, "cells").flatMap((cell) => cell.sources ?? []),
    EXTRA_SKILL_ROOT,
  ]),
];

/** Every directory under a declared root that holds a `SKILL.md`. */
function skillDirs() {
  const out = [];
  for (const root of ROOTS) {
    const full = join(REPO_ROOT, root);
    if (!existsSync(full)) continue;
    for (const entry of readdirSync(full)) {
      const dir = join(full, entry);
      if (!statSync(dir).isDirectory()) continue;
      if (existsSync(join(dir, "SKILL.md"))) out.push({ name: entry, rel: join(root, entry, "SKILL.md"), path: join(dir, "SKILL.md") });
    }
  }
  return out;
}

const PATTERN = "**The pattern.**";
const WHY = "**Why.**";
const TEST = "**The test.**";
// A named part carries its label in bold, and the label ends on a period so a
// reader scanning the file sees the parts as one set.
const NAMED_PART = /^\*\*[^*]+\.\*\*/;

/** A title-case word: an uppercase letter opening a word that is not all caps. */
function titleCaseWord(word) {
  return /^[A-Z][a-z]/.test(word);
}

/** Findings for one principle skill file. */
function inspect(rel, text) {
  const findings = [];
  const lines = text.split("\n");
  const at = (i) => i + 1;

  const titles = [];
  let phase = 0; // 0 before the pattern, 1 before the why, 2 between the why and the test, 3 after it
  const seen = new Set();

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (/^## /.test(line)) {
      findings.push({ rel, line: at(i), msg: "a `##` heading below the title; a part is a bold lead-in" });
      continue;
    }
    if (/^# /.test(line)) {
      titles.push({ i, text: line.slice(2) });
      continue;
    }
    if (!line.startsWith("**")) continue;

    if (line.startsWith(PATTERN)) {
      if (seen.has(PATTERN)) findings.push({ rel, line: at(i), msg: "a second `**The pattern.**`" });
      else if (phase > 0) findings.push({ rel, line: at(i), msg: "`**The pattern.**` after a part that must follow it" });
      seen.add(PATTERN);
      phase = Math.max(phase, 1);
      continue;
    }
    if (line.startsWith(WHY)) {
      if (seen.has(WHY)) findings.push({ rel, line: at(i), msg: "a second `**Why.**`" });
      else if (phase !== 1) findings.push({ rel, line: at(i), msg: "`**Why.**` must follow `**The pattern.**`" });
      seen.add(WHY);
      phase = Math.max(phase, 2);
      continue;
    }
    if (line.startsWith(TEST)) {
      if (seen.has(TEST)) findings.push({ rel, line: at(i), msg: "a second `**The test.**`" });
      else if (phase !== 2) findings.push({ rel, line: at(i), msg: "`**The test.**` must follow `**Why.**` and the where parts" });
      seen.add(TEST);
      phase = 3;
      continue;
    }
    if (NAMED_PART.test(line)) {
      if (phase !== 2) findings.push({ rel, line: at(i), msg: "a named part belongs between `**Why.**` and `**The test.**`" });
      continue;
    }
    findings.push({ rel, line: at(i), msg: "a bold lead-in with no closing period; a part wraps its label as `**Label.**`" });
  }

  if (titles.length === 0) findings.push({ rel, line: 1, msg: "no `# ` title" });
  if (titles.length > 1) findings.push({ rel, line: at(titles[1].i), msg: "a second `# ` title; the file has one" });
  if (titles.length > 0) {
    const words = titles[0].text.split(/\s+/).slice(1);
    for (const word of words) {
      if (titleCaseWord(word)) {
        findings.push({ rel, line: at(titles[0].i), msg: `the title is not sentence case: \`${word}\` begins uppercase` });
        break;
      }
    }
  }
  for (const [part, name] of [[PATTERN, "the pattern"], [WHY, "the why"], [TEST, "the test"]]) {
    if (!seen.has(part)) findings.push({ rel, line: 1, msg: `missing \`${part}\`, ${name}` });
  }
  return findings;
}

const targets = skillDirs().filter((d) => d.name.includes(NAME_SEGMENT));
if (targets.length === 0) {
  console.error("skill shape: no skill directory carries `" + NAME_SEGMENT + "`; the gate would pass over nothing.");
  process.exit(1);
}

const findings = [];
for (const { rel, path } of targets) {
  findings.push(...inspect(rel, readFileSync(path, "utf8")));
}

for (const finding of findings) {
  console.log(`${finding.rel}:${finding.line} ${finding.msg}`);
}

if (findings.length === 0) {
  console.log(`skill shape: clean across ${targets.length} skill(s)`);
} else {
  console.error(`Blocking gate: ${findings.length} finding(s) across ${targets.length} skill(s).`);
}
process.exit(findings.length === 0 ? 0 : 1);
