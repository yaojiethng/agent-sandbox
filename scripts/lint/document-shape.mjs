// The instruction documents carry one frontmatter contract.
//
// Two claims over the same file set, because the same walk, the same roots and
// the same parser serve both:
//
//   1. Every prompt, skill and policy block parses, and a skill's
//      `disable-model-invocation` is a boolean. Pi drops a prompt whose
//      frontmatter does not parse, with no message in the session, and tests the
//      flag with `=== true`.
//   2. Every shipping document declares the reader it serves.
//
// Enforces .agents/skills/instruction-authoring/references/skill-conventions.md
// `## Frontmatter`, its `prompt-conventions.md` `## Frontmatter`,
// `.agents/skills/project-documentation/SKILL.md` `## How a document opens`, and
// the decision in docs/adr/principle_skill_shape.md.
//
// Every set is derived. The instruction roots come from the manifest's cells, so
// a new surface enters with the declaration.
//
// Test seams: DOCUMENT_SHAPE_SCAN_ROOT points the tree scan at a fixture,
// DOCUMENT_SHAPE_MANIFEST_ROOT points the declaration read elsewhere, and
// DOCUMENT_SHAPE_SHIPPED_ROOTS names the shipping folders instead of deriving
// them, so the fail-closed branch is reachable.
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

/** The frontmatter block, or null when the file does not open with one. */
function frontmatterOf(text) {
  if (!text.startsWith("---\n") && text !== "---") return null;
  const end = text.indexOf("\n---", 3);
  if (end < 0) return null;
  return { body: text.slice(4, end), offset: text.slice(0, 4).split("\n").length - 1 };
}

/** The path shown in a finding: relative to the scan root when it is under it. */
const display = (file) => (file.startsWith(REPO_ROOT + "/") ? file.slice(REPO_ROOT.length + 1) : file);

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
// One report, one exit.
// ---------------------------------------------------------------------------
for (const f of findings) {
  if (f.kind === "frontmatter") console.log(`${f.rel} frontmatter: ${f.msg}`);
  else console.log(f.line ? `${f.rel}:${f.line} ${f.msg}` : `${f.rel}: ${f.msg}`);
  if (f.offending) console.log("  offending line: " + f.offending.trim().slice(0, 100));
}

const summary = `${files.length} instruction file(s) and ${shippedFiles.length} shipping document(s)`;
if (findings.length === 0) {
  console.log(`document shape: clean across ${summary}`);
} else {
  console.error(`Blocking gate: ${findings.length} finding(s) across ${summary}.`);
}
process.exit(findings.length === 0 ? 0 : 1);
