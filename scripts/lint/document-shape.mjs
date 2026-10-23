// The instruction documents carry one shape.
//
// Three claims over the same file set, because the same walk, the same roots and
// the same parser serve all three:
//
//   1. Every prompt, skill and policy block parses. Pi drops a prompt whose
//      frontmatter does not parse, with no message in the session.
//   2. Every shipping document declares the reader it serves, because the ship
//      set is a decision rather than a property of the folder.
//   3. Every skill whose name carries `principle-` carries the corpus shape: a
//      sentence-case title, `**The pattern.**`, `**Why.**`, any named part, then
//      `**The test.**`, and a claim from the authoring convention's table.
//
// Enforces docs/development/prompt-authoring-conventions.md `## Structure of a
// workflow document`, `## The principle shape` and `## The principle claims`,
// `.agents/skills/docs/SKILL.md` `## How a document opens`, and the
// decision in docs/adr/principle_skill_shape.md.
//
// Every set is derived. The instruction roots come from the manifest's cells, so
// a new surface enters with the declaration. The claim set comes from the
// authoring convention, so widening it is one edit to the document a writer
// already opens. A principle is named by its directory, so it enters the gate
// the day it exists.
//
// Test seams: DOCUMENT_SHAPE_SCAN_ROOT points the tree scan at a fixture,
// DOCUMENT_SHAPE_MANIFEST_ROOT points the declaration read elsewhere, and
// DOCUMENT_SHAPE_SHIPPED_ROOTS names the shipping folders instead of deriving
// them, so the fail-closed branch is reachable.
//
// Options: `--map` prints the principle corpus grouped by claim, which is a
// derived view; a written map would restate the skills and go out of date.
//
// Exit codes: 0 = no findings, 1 = findings or the gate could not run. The
// finding count is printed, never encoded in the exit code.

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { join, dirname, resolve } from "path";
import { fileURLToPath } from "url";
import { load_manifest, manifest_rows } from "../../src/build/container-interface.mjs";
import { loadPiFrontmatter } from "./pi-frontmatter.mjs";

const MODULE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");

const REPO_ROOT = process.env.DOCUMENT_SHAPE_SCAN_ROOT
  ? resolve(process.env.DOCUMENT_SHAPE_SCAN_ROOT)
  : MODULE_ROOT;

// The declaration is read from the module root, not the scan root, so a fixture
// tree is scanned against the real declaration unless the seam says otherwise.
const MANIFEST_ROOT = process.env.DOCUMENT_SHAPE_MANIFEST_ROOT
  ? resolve(process.env.DOCUMENT_SHAPE_MANIFEST_ROOT)
  : MODULE_ROOT;

const manifest = load_manifest(MANIFEST_ROOT);
if (manifest === undefined) {
  console.error(
    "document shape: " + join(MANIFEST_ROOT, "src/build/container-interface.json") +
      " is missing or does not parse; cannot derive the instruction roots.",
  );
  process.exit(1);
}

/**
 * Roots holding a prompt or a skill. `.agents/skills` is the project's own
 * convention tree, which ships nowhere and so is declared by no cell. Its
 * sibling `.agents/prompts` is a declared cell, and it stays listed here so a
 * project whose manifest predates that cell is still scanned. A draft is not a
 * live prompt or skill, so `.agents/drafts` and `src/reasoning/agent/drafts` are
 * deliberately absent from the declaration.
 */
const ROOTS = [
  ...new Set([
    ...manifest_rows(manifest, "cells").flatMap((cell) => cell.sources ?? []),
    ".agents/skills",
    ".agents/prompts",
  ]),
];

const POLICY_ROOT = "docs";
const POLICY_SUFFIX = "_policy.md";
const NAME_SEGMENT = "principle-";

/** Every file under a root with the given suffix, or nothing when it is absent. */
function collect(root, suffix = ".md") {
  const out = [];
  const walk = (dir) => {
    for (const entry of readdirSync(dir)) {
      const full = join(dir, entry);
      if (statSync(full).isDirectory()) {
        walk(full);
      } else if (entry.endsWith(suffix)) {
        out.push(full);
      }
    }
  };
  if (existsSync(root)) walk(root);
  return out;
}

/** Every directory under a declared root that holds a `SKILL.md`. */
function skillDirs() {
  const out = [];
  for (const root of ROOTS) {
    const full = join(REPO_ROOT, root);
    if (!existsSync(full)) continue;
    for (const entry of readdirSync(full)) {
      const dir = join(full, entry);
      if (!statSync(dir).isDirectory()) continue;
      if (existsSync(join(dir, "SKILL.md"))) {
        out.push({ name: entry, rel: join(root, entry, "SKILL.md"), path: join(dir, "SKILL.md") });
      }
    }
  }
  return out;
}

/** The frontmatter block, or null when the file does not open with one. */
function frontmatterOf(text) {
  if (!text.startsWith("---\n") && text !== "---") return null;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return null;
  return { body: text.slice(4, end), offset: text.slice(0, 4).split("\n").length - 1 };
}

/** The path shown in a finding: relative to the scan root when it is under it. */
const display = (file) => (file.startsWith(REPO_ROOT + "/") ? file.slice(REPO_ROOT.length + 1) : file);

// The claim set is declared once, in the authoring convention's table. Reading it
// from there keeps a claim name out of this file.
const CLAIMS_DOC = join(MODULE_ROOT, "docs/development/prompt-authoring-conventions.md");
const CLAIMS_HEADING = "## The principle claims";

function declaredClaims() {
  const text = readFileSync(CLAIMS_DOC, "utf8");
  const start = text.indexOf(CLAIMS_HEADING);
  if (start < 0) return [];
  const rest = text.slice(start + CLAIMS_HEADING.length);
  const end = rest.search(/\n## /);
  const body = end < 0 ? rest : rest.slice(0, end);
  const claims = [];
  for (const line of body.split("\n")) {
    const m = line.match(/^\| `([a-z][a-z-]*)` \|/);
    if (m) claims.push(m[1]);
  }
  return claims;
}

const CLAIMS = declaredClaims();
if (CLAIMS.length === 0) {
  console.error("document shape: " + CLAIMS_DOC + " carries no table under `" + CLAIMS_HEADING + "`; the claim set has no home.");
  process.exit(1);
}

const MAP = process.argv.includes("--map");

// Pi's own parser, so the gate accepts exactly the files pi accepts.
const { parseFrontmatter } = await loadPiFrontmatter("Document shape gate");

const findings = [];
const finding = (rel, line, msg, extra) => findings.push({ rel, line, msg, ...extra });

// ---------------------------------------------------------------------------
// Every block parses. A policy file's block holds nothing the runtime consumes,
// so its parse is the one thing a reader cannot check by eye; this is it.
//
// A cell source may contain another cell source -- the pi config home holds its
// own prompt and skill folders -- so the collected list is de-duplicated by path.
// ---------------------------------------------------------------------------
const files = [
  ...new Set([
    ...ROOTS.flatMap((root) => collect(join(REPO_ROOT, root))),
    ...collect(join(REPO_ROOT, POLICY_ROOT), POLICY_SUFFIX),
  ]),
];

for (const file of files) {
  const text = readFileSync(file, "utf8");
  const block = frontmatterOf(text);
  if (block === null) continue;
  try {
    parseFrontmatter(text);
  } catch (error) {
    const at = error.linePos ? error.linePos[0] : null;
    // The parser sees the block body, so its line numbers start at the second
    // line of the file; the offset is where the body began.
    const offending = at ? text.split("\n")[block.offset + at.line - 1] : undefined;
    finding(display(file), at ? block.offset + at.line : 0, "frontmatter does not parse: " + String(error.message).split("\n")[0], {
      kind: "parse",
      offending,
    });
  }
}

// A skill hides itself from the model with `disable-model-invocation: true`.
// Pi's loader tests the value with `=== true`, so a string such as `yes` leaves
// the skill visible, the opposite of what the author wrote.
const NON_BOOLEAN_FLAG = "disable-model-invocation";
for (const file of files) {
  const text = readFileSync(file, "utf8");
  if (frontmatterOf(text) === null) continue;
  let fm;
  try {
    fm = parseFrontmatter(text).frontmatter;
  } catch {
    continue; // the parse finding above already covers this file
  }
  if (!fm || !(NON_BOOLEAN_FLAG in fm)) continue;
  const value = fm[NON_BOOLEAN_FLAG];
  if (typeof value !== "boolean") {
    finding(display(file), 0, NON_BOOLEAN_FLAG + " is " + JSON.stringify(value) + "; use true or false", { kind: "frontmatter" });
  }
}

// A document that ships declares the reader it serves. The shipping folders are
// the manifest's `docs/` rows. A document serving only the maintainer does not
// ship, so such a declaration inside a shipping folder is a finding.
const READERS = new Set(["agent", "operator", "maintainer"]);
const shippedRoots =
  process.env.DOCUMENT_SHAPE_SHIPPED_ROOTS !== undefined
    ? process.env.DOCUMENT_SHAPE_SHIPPED_ROOTS.split(",").map((s) => s.trim()).filter(Boolean)
    : [
        ...new Set(
          manifest_rows(manifest, "image")
            .map((row) => row.source)
            .filter((source) => typeof source === "string" && source.startsWith("docs/")),
        ),
      ];
const shippedFiles = shippedRoots.flatMap((root) => collect(join(REPO_ROOT, root)));
for (const file of shippedFiles) {
  const rel = display(file);
  const text = readFileSync(file, "utf8");
  if (frontmatterOf(text) === null) {
    finding(rel, 0, "no frontmatter; a shipping document declares its reader", { kind: "frontmatter" });
    continue;
  }
  let declared;
  try {
    declared = parseFrontmatter(text).frontmatter;
  } catch {
    continue; // the parse finding above already covers this file
  }
  const value = declared ? declared.reader : undefined;
  const list = Array.isArray(value) ? value : typeof value === "string" ? [value] : [];
  if (!list.length) {
    finding(rel, 0, "no reader declared; name agent, operator or maintainer", { kind: "frontmatter" });
    continue;
  }
  const unknown = list.filter((reader) => !READERS.has(reader));
  if (unknown.length) finding(rel, 0, "unknown reader " + unknown.join(", ") + "; use agent, operator or maintainer", { kind: "frontmatter" });
  if (list.every((reader) => reader === "maintainer")) {
    finding(rel, 0, "declares the maintainer only, so it does not ship; move it out of the shipping folder or name an in-container reader", { kind: "frontmatter" });
  }
}

// ---------------------------------------------------------------------------
// A principle carries the corpus shape and one claim from the table.
// ---------------------------------------------------------------------------
const PATTERN = "**The pattern.**";
const WHY = "**Why.**";
const TEST = "**The test.**";
// A named part carries its label in bold, and the label ends on a period so a
// reader scanning the file sees the parts as one set.
const NAMED_PART = /^\*\*[^*]+\.\*\*/;

/** A title-case word: an uppercase letter opening a word that is not all caps. */
const titleCaseWord = (word) => /^[A-Z][a-z]/.test(word);

/** Findings for one principle skill file. */
function inspect(rel, text) {
  const out = [];
  const lines = text.split("\n");
  const at = (i) => i + 1;
  const titles = [];
  let phase = 0; // 0 before the pattern, 1 before the why, 2 between the why and the test, 3 after it
  const seen = new Set();

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];

    if (/^## /.test(line)) {
      out.push({ rel, line: at(i), msg: "a `##` heading below the title; a part is a bold lead-in" });
      continue;
    }
    if (/^# /.test(line)) {
      titles.push({ i, text: line.slice(2) });
      continue;
    }
    if (!line.startsWith("**")) continue;

    if (line.startsWith(PATTERN)) {
      if (seen.has(PATTERN)) out.push({ rel, line: at(i), msg: "a second `**The pattern.**`" });
      else if (phase > 0) out.push({ rel, line: at(i), msg: "`**The pattern.**` after a part that must follow it" });
      seen.add(PATTERN);
      phase = Math.max(phase, 1);
      continue;
    }
    if (line.startsWith(WHY)) {
      if (seen.has(WHY)) out.push({ rel, line: at(i), msg: "a second `**Why.**`" });
      else if (phase !== 1) out.push({ rel, line: at(i), msg: "`**Why.**` must follow `**The pattern.**`" });
      seen.add(WHY);
      phase = Math.max(phase, 2);
      continue;
    }
    if (line.startsWith(TEST)) {
      if (seen.has(TEST)) out.push({ rel, line: at(i), msg: "a second `**The test.**`" });
      else if (phase !== 2) out.push({ rel, line: at(i), msg: "`**The test.**` must follow `**Why.**` and the where parts" });
      seen.add(TEST);
      phase = 3;
      continue;
    }
    if (NAMED_PART.test(line)) {
      if (phase !== 2) out.push({ rel, line: at(i), msg: "a named part belongs between `**Why.**` and `**The test.**`" });
      continue;
    }
    out.push({ rel, line: at(i), msg: "a bold lead-in with no closing period; a part wraps its label as `**Label.**`" });
  }

  if (titles.length === 0) out.push({ rel, line: 1, msg: "no `# ` title" });
  if (titles.length > 1) out.push({ rel, line: at(titles[1].i), msg: "a second `# ` title; the file has one" });
  if (titles.length > 0) {
    const words = titles[0].text.split(/\s+/).slice(1);
    for (const word of words) {
      if (titleCaseWord(word)) {
        out.push({ rel, line: at(titles[0].i), msg: `the title is not sentence case: \`${word}\` begins uppercase` });
        break;
      }
    }
  }
  for (const [part, name] of [[PATTERN, "the pattern"], [WHY, "the why"], [TEST, "the test"]]) {
    if (!seen.has(part)) out.push({ rel, line: 1, msg: `missing \`${part}\`, ${name}` });
  }
  return out;
}

const targets = skillDirs().filter((d) => d.name.includes(NAME_SEGMENT));
// Fail closed on the module tree: a rename that dropped the segment from every
// directory would otherwise turn the shape check into a pass over nothing. A
// fixture root is pointed at one claim at a time, so a fixture holding no
// principle is a tree with no corpus to check rather than a failed gate.
if (targets.length === 0 && REPO_ROOT === MODULE_ROOT) {
  finding(NAME_SEGMENT, 0, "no skill directory carries `" + NAME_SEGMENT + "`; the gate would pass over nothing", { kind: "corpus" });
}

const groups = new Map(CLAIMS.map((claim) => [claim, []]));
for (const { name, rel, path } of targets) {
  const text = readFileSync(path, "utf8");
  findings.push(...inspect(rel, text));
  const claim = parseFrontmatter(text)?.frontmatter?.metadata?.claim;
  if (claim === undefined || claim === "") {
    finding(rel, 1, "no claim declared; a principle carries `metadata:` then `claim: <name>`");
  } else if (!CLAIMS.includes(claim)) {
    finding(rel, 1, "claim `" + claim + "` is not in the authoring convention's table; the set is " + CLAIMS.join(", "));
  } else {
    groups.get(claim).push(name);
  }
}

// ---------------------------------------------------------------------------
// One report, one exit.
// ---------------------------------------------------------------------------
for (const f of findings) {
  if (f.kind === "frontmatter") console.log(`${f.rel} frontmatter: ${f.msg}`);
  else if (f.kind === "corpus") console.log(`document shape: ${f.msg}`);
  else console.log(f.line ? `${f.rel}:${f.line} ${f.msg}` : `${f.rel}: ${f.msg}`);
  if (f.offending) console.log("  offending line: " + f.offending.trim().slice(0, 100));
}

if (MAP) {
  for (const [claim, skills] of groups) {
    for (const skill of skills.sort()) console.log(claim + "\t" + skill);
  }
  const used = [...groups.values()].filter((list) => list.length > 0);
  const mapped = used.reduce((sum, list) => sum + list.length, 0);
  console.log(`claim map: ${mapped} skill(s) across ${used.length} claim(s) of ${targets.length}`);
  process.exit(findings.length === 0 && mapped === targets.length ? 0 : 1);
}

const summary =
  `${files.length} instruction file(s), ${shippedFiles.length} shipping document(s) ` +
  `and ${targets.length} principle skill(s)`;
if (findings.length === 0) {
  console.log(`document shape: clean across ${summary}`);
} else {
  console.error(`Blocking gate: ${findings.length} finding(s) across ${summary}.`);
}
process.exit(findings.length === 0 ? 0 : 1);
